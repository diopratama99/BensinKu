import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'map_style.dart';
import '../../services/notification_service.dart';
import '../../services/trip_service.dart';
import '../../services/widget_launch_intent.dart';
import 'manual_trip_sheet.dart';
import 'trip_detail_page.dart';

/// Rute — GPS trip recorder with telemetry overlay.
/// Map is monochrome; overlays are mono LCD-style readouts.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen>
    with WidgetsBindingObserver {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _mapController = MapController();

  TripService? _service;
  Vehicle? _selectedVehicle;
  List<Vehicle> _vehicles = [];
  bool _loadingVehicles = true;
  bool _locationReady = false;
  bool _stopping = false;
  Position? _lastKnownPosition;
  LocationPermissionStatus? _permissionStatus;

  /// Lightweight live position stream that runs ONLY when no trip is
  /// active. Used to render the "you are here" dot before a trip starts.
  /// During a trip, [TripService] owns the high-accuracy stream and we
  /// derive the current position from its latest waypoint instead, so
  /// the two streams don't compete.
  StreamSubscription<Position>? _idlePositionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    // Cek pending tap notif auto-stop di frame berikutnya. Harus
    // setelah build pertama supaya Navigator siap di-push ke.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeOpenTripDetailFromNotification();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // User may have toggled the location permission in system Settings
    // and bounced back to the app. Re-check so the warning chip / dialog
    // state stays in sync with reality.
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
      // If a trip is active, re-evaluate idle right away. While the app
      // was backgrounded with the screen off and the device stationary,
      // the periodic idle timer may have been suspended by the OS — so a
      // trip that crossed the 30-min idle threshold while we were asleep
      // gets auto-stopped now (ended_at is backdated, idle tail excluded).
      _service?.checkIdleNow();
      // Prioritas: kalau user tap notif auto-stop, buka detail trip-nya.
      // Harus dicek SEBELUM `_maybeAutoStartFromWidget()` supaya user
      // tidak salah malah memulai trip baru — itu yang dikeluhkan
      // sebelum fix ini.
      _maybeOpenTripDetailFromNotification();
      // App may have been brought to foreground via the widget's
      // "MULAI PERJALANAN" tap. Re-poll to honor that even when warm.
      _maybeAutoStartFromWidget();
    }
  }

  /// Kalau user tap notif "Trip dihentikan otomatis", payload-nya
  /// berisi trip-id. Kita fetch trip-nya, dan navigate ke detail page.
  /// Operasi ini idempotent — pending id di-consume sekali pakai oleh
  /// `NotificationService.consumePendingTripDetail()`.
  Future<void> _maybeOpenTripDetailFromNotification() async {
    final tripId = NotificationService.consumePendingTripDetail();
    if (tripId == null || tripId.isEmpty || !mounted) return;

    // Drain juga flag widget "MULAI PERJALANAN" di siklus ini supaya
    // tidak nyangkut: tap notif ≠ tap widget. Kalau dibiarkan, jalur
    // `_maybeAutoStartFromWidget` berikutnya bisa ngira ini intent
    // widget dan nge-trigger trip baru — tepat bug yang kita fix.
    unawaited(WidgetLaunchIntent.consumePending());

    try {
      final trip = await _repo.getTrip(tripId);
      if (!mounted || trip == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TripDetailPage(trip: trip),
        ),
      );
    } catch (_) {
      _showSnack('Tidak dapat memuat detail perjalanan.');
    }
  }

  Future<void> _maybeAutoStartFromWidget() async {
    if (_service != null) return; // Trip already active.
    final shouldStart = await WidgetLaunchIntent.consumePending();
    if (!shouldStart || !mounted) return;
    if (_locationReady && _selectedVehicle != null) {
      unawaited(_startTrip());
    }
  }

  Future<void> _refreshPermissionStatus() async {
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermissionStatus status;
      if (perm == LocationPermission.deniedForever) {
        status = LocationPermissionStatus.permanentlyDenied;
      } else if (perm == LocationPermission.denied) {
        status = LocationPermissionStatus.denied;
      } else if (perm == LocationPermission.whileInUse) {
        status = LocationPermissionStatus.whileInUseOnly;
      } else if (perm == LocationPermission.always) {
        status = LocationPermissionStatus.alwaysGranted;
      } else {
        status = LocationPermissionStatus.denied;
      }
      if (!mounted) return;
      setState(() {
        _permissionStatus = status;
        _locationReady =
            status == LocationPermissionStatus.alwaysGranted ||
                status == LocationPermissionStatus.whileInUseOnly;
      });
    } catch (_) {
      // Silently ignore — caller will hit the same checks again.
    }
  }

  Future<void> _init() async {
    try {
      final vehicles = await _repo.listVehicles();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _selectedVehicle = vehicles.isNotEmpty ? vehicles.first : null;
          _loadingVehicles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVehicles = false);
    }

    final serviceOn = await TripService.isServiceEnabled();
    if (!serviceOn) {
      _showSnack('GPS tidak aktif. Aktifkan lokasi di pengaturan.');
      return;
    }
    final status = await TripService.requestPermission();
    if (mounted) {
      setState(() {
        _locationReady = status == LocationPermissionStatus.alwaysGranted ||
            status == LocationPermissionStatus.whileInUseOnly;
        _permissionStatus = status;
      });
    }
    switch (status) {
      case LocationPermissionStatus.denied:
        _showSnack('Izin lokasi ditolak. Tracking tidak bisa berjalan.');
        return;
      case LocationPermissionStatus.permanentlyDenied:
        _showPermissionBlockedDialog();
        return;
      case LocationPermissionStatus.whileInUseOnly:
        // Allow tracking to start, but warn that it'll stop when screen
        // is off. User can upgrade to "Always" via settings.
        _showBackgroundUpgradeDialog();
      case LocationPermissionStatus.alwaysGranted:
        // Best case — tracking will keep running with screen off.
        break;
    }

    // First fix: show user where they are immediately.
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _lastKnownPosition = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {}

    // Then keep that dot updated while we're not in a trip.
    _startIdlePositionStream();

    // If app was launched from the home widget's "MULAI PERJALANAN"
    // button, auto-start the trip now (after permission is settled).
    if (mounted && _locationReady && _selectedVehicle != null) {
      final shouldAutoStart =
          await WidgetLaunchIntent.consumePending();
      if (shouldAutoStart && mounted) {
        unawaited(_startTrip());
      }
    }
  }

  /// Subscribe to a low-power position stream so the "you are here" dot
  /// stays current while the user is just looking at the map. This is
  /// disposed before [TripService] starts its high-accuracy stream so
  /// they don't run concurrently.
  void _startIdlePositionStream() {
    _idlePositionSub?.cancel();
    _idlePositionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        // Bigger filter than tracking-mode — we just need rough updates
        // when the user moves around the map view.
        distanceFilter: 25,
      ),
    ).listen(
      (pos) {
        if (!mounted) return;
        setState(() => _lastKnownPosition = pos);
      },
      onError: (_) {
        // Silently ignore — the user might toggle GPS off mid-session.
      },
    );
  }

  void _stopIdlePositionStream() {
    _idlePositionSub?.cancel();
    _idlePositionSub = null;
  }

  /// Opens the manual trip entry sheet — for when the user forgot to record
  /// live tracking. On save, refreshes so the new trip is reflected.
  Future<void> _openManualEntry() async {
    if (_vehicles.isEmpty) {
      _showSnack('Tambah kendaraan dulu di profil.');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppEditorial.ink.withValues(alpha: 0.55),
      builder: (_) => ManualTripSheet(
        vehicles: _vehicles,
        initialVehicleId: _selectedVehicle?.id,
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
      _showSnack('Perjalanan manual tersimpan ✓');
    }
  }

  Future<void> _startTrip() async {
    if (_selectedVehicle == null) {
      _showSnack('Pilih kendaraan dulu.');
      return;
    }

    // Re-check permission live in case the user toggled it in Settings
    // since the page was first loaded.
    final status = await TripService.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      _locationReady = status == LocationPermissionStatus.alwaysGranted ||
          status == LocationPermissionStatus.whileInUseOnly;
    });
    switch (status) {
      case LocationPermissionStatus.denied:
        _showSnack('Izin lokasi ditolak. Tracking tidak bisa berjalan.');
        return;
      case LocationPermissionStatus.permanentlyDenied:
        await _showPermissionBlockedDialog();
        return;
      case LocationPermissionStatus.whileInUseOnly:
        // Re-show the upgrade dialog. If the user dismisses with
        // "Lanjut saja" we still allow the trip to start.
        await _showBackgroundUpgradeDialog();
      case LocationPermissionStatus.alwaysGranted:
        break;
    }

    if (!_locationReady) return;

    final svc = TripService(
      repo: _repo,
      vehicleId: _selectedVehicle!.id,
    );
    svc.addListener(_onServiceUpdate);
    svc.onAutoStopped = _onAutoStopped;

    try {
      // Hand off the GPS stream to the high-accuracy tracking service.
      _stopIdlePositionStream();
      await svc.startTrip();
      setState(() => _service = svc);
    } catch (e) {
      svc.removeListener(_onServiceUpdate);
      svc.dispose();
      // Resume idle dot updates if start failed.
      _startIdlePositionStream();
      _showSnack('Gagal mulai: $e');
    }
  }

  Future<void> _stopTrip() async {
    if (_service == null || _stopping) return;
    setState(() => _stopping = true);

    try {
      final result = await _service!.stopTrip();
      if (!mounted) return;

      // Teardown service FIRST so the widget tree settles into idle state.
      _service!.removeListener(_onServiceUpdate);
      _service!.dispose();
      _service = null;
      _startIdlePositionStream();

      setState(() => _stopping = false);

      // Now show summary from a stable idle state. The dialog won't get
      // killed by a rebuild because the tree is already in its final form.
      if (result != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        if (result.discarded) {
          _showInvalidTripDialog(result.reason);
        } else if (result.trip != null) {
          _showTripSummary(result.trip!);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _stopping = false);
      _showSnack('Gagal mengakhiri: $e');
    }
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {
      final positions = _service?.positions ?? [];
      if (positions.isNotEmpty) {
        final last = positions.last;
        // Mirror the live trip position into _lastKnownPosition so the
        // "you are here" marker keeps updating during a trip too.
        _lastKnownPosition = last;
        _mapController.move(
          LatLng(last.latitude, last.longitude),
          _mapController.camera.zoom,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idlePositionSub?.cancel();
    _service?.removeListener(_onServiceUpdate);
    _service?.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  /// Shown when the user already picked "Don't ask again" — the only path
  /// forward is the OS Settings screen.
  Future<void> _showPermissionBlockedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Izin lokasi diblokir',
          style: AppEditorial.heading(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Buka pengaturan untuk mengaktifkan izin lokasi. Pilih '
          '"Allow all the time" supaya rute tetap tercatat saat layar mati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await TripService.openLocationSettings();
            },
            child: const Text('Buka pengaturan'),
          ),
        ],
      ),
    );
  }

  /// Shown when only "While using the app" was granted. We let the user
  /// proceed but warn that tracking will pause with the screen off, and
  /// offer a one-tap path to upgrade.
  Future<void> _showBackgroundUpgradeDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rute akan berhenti saat layar mati',
          style: AppEditorial.heading(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Untuk perekaman rute yang akurat saat berkendara, izinkan '
          '"Allow all the time" di pengaturan. Tanpa itu, GPS akan berhenti '
          'mencatat begitu layar mati atau aplikasi pindah ke background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Lanjut saja'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await TripService.openLocationSettings();
            },
            child: const Text('Buka pengaturan'),
          ),
        ],
      ),
    );
  }

  void _onAutoStopped(TripStopResult result) {
    if (!mounted) return;
    setState(() {});
    _startIdlePositionStream();
    if (result.discarded) {
      _showInvalidTripDialog(result.reason, autoStopped: true);
    } else if (result.trip != null) {
      _showTripSummary(result.trip!, autoStopped: true);
    }
  }

  void _showTripSummary(Trip trip, {bool autoStopped = false}) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final distText = trip.distanceKm != null
            ? '${trip.distanceKm!.toStringAsFixed(2)} km'
            : '—';
        final duration = trip.endedAt != null
            ? trip.endedAt!.difference(trip.startedAt)
            : Duration.zero;
        final durText =
            '${duration.inMinutes}m ${(duration.inSeconds % 60)}s';

        return AlertDialog(
          title: Text(
            autoStopped
                ? 'Dihentikan otomatis'
                : 'Perjalanan selesai',
            style: AppEditorial.heading(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: autoStopped ? AppEditorial.rust : null,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (autoStopped) ...[
                Text(
                  'Tidak ada pergerakan selama 30 menit. '
                  'Trip dihentikan otomatis dan waktu idle '
                  'tidak dihitung.',
                  style: AppEditorial.sans(
                    fontSize: 12,
                    color: AppEditorial.inkSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              EditorialDataRow(label: 'Jarak tempuh', value: distText),
              EditorialDataRow(label: 'Durasi', value: durText),
              EditorialDataRow(
                label: 'Mulai',
                value: DateFormat('HH:mm, dd MMM', 'id_ID')
                    .format(trip.startedAt),
                isLast: true,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog yang muncul saat rekaman trip dibatalkan karena tidak lulus
  /// validity check (terlalu pendek, tidak ada pergerakan, dll). Trip
  /// row sudah dihapus dari DB jadi tidak akan muncul di history /
  /// dipakai sebagai sample efisiensi.
  void _showInvalidTripDialog(
    TripDiscardReason reason, {
    bool autoStopped = false,
  }) {
    final reasonText = switch (reason) {
      TripDiscardReason.tooShortDuration =>
        'Perjalanan kurang dari 30 detik. Rekaman dianggap tidak '
            'valid dan tidak disimpan.',
      TripDiscardReason.tooShortDistance =>
        'Jarak tempuh kurang dari 100 meter. Rekaman dianggap tidak '
            'valid dan tidak disimpan.',
      TripDiscardReason.tooFewWaypoints =>
        'GPS belum sempat mendapat sinyal yang cukup. Coba lagi '
            'di area dengan langit terbuka.',
      TripDiscardReason.none => '',
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rekaman dibatalkan',
          style: AppEditorial.heading(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppEditorial.rust,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (autoStopped) ...[
              Text(
                'Tidak ada pergerakan terdeteksi setelah perjalanan '
                'dimulai.',
                style: AppEditorial.sans(
                  fontSize: 12,
                  color: AppEditorial.inkSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              reasonText,
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.ink,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = _service?.isTracking ?? false;
    final positions = _service?.positions ?? [];
    final polylinePoints =
        positions.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final distKm = _service?.distanceKm ?? 0.0;
    final distText =
        distKm < 1 ? '${(distKm * 1000).toStringAsFixed(0)} m' : '${distKm.toStringAsFixed(2)} km';

    String durText = '00:00';
    if (isTracking && _service?.activeTrip != null) {
      final elapsed =
          DateTime.now().difference(_service!.activeTrip!.startedAt);
      durText =
          '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    final initCenter = _lastKnownPosition != null
        ? LatLng(_lastKnownPosition!.latitude, _lastKnownPosition!.longitude)
        : const LatLng(-6.2088, 106.8456);

    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: Stack(
        children: [
          // Map ─────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initCenter,
              initialZoom: 15,
            ),
            children: [
              warmMapTiles(),
              if (polylinePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      color: AppEditorial.ink,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // ── "You are here" marker — visible whenever we know
              //    where the user is, even before a trip starts. During
              //    a trip this gets overlaid by the live trip dot below.
              if (_lastKnownPosition != null && !isTracking)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _lastKnownPosition!.latitude,
                        _lastKnownPosition!.longitude,
                      ),
                      width: 32,
                      height: 32,
                      child: const _PulseDot(),
                    ),
                  ],
                ),
              if (isTracking && positions.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: polylinePoints.last,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppEditorial.brand,
                          border: Border.all(
                              color: AppEditorial.cream, width: 3),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppEditorial.ink
                                  .withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              mapAttribution(),
            ],
          ),

          // Top bar — masthead + recenter ──────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppEditorial.cream,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rPill),
                      boxShadow: AppEditorial.softShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isTracking
                                ? AppEditorial.sage
                                : AppEditorial.inkMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTracking ? 'Merekam' : 'GPS siap',
                          style: AppEditorial.sans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppEditorial.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_permissionStatus ==
                      LocationPermissionStatus.whileInUseOnly)
                    GestureDetector(
                      onTap: _showBackgroundUpgradeDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppEditorial.rust
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                              AppEditorial.rPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(PhosphorIconsRegular.warning,
                                size: 13, color: AppEditorial.rust),
                            const SizedBox(width: 5),
                            Text(
                              'Izin lokasi',
                              style: AppEditorial.sans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppEditorial.rust,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      // Optimistic snap if we already know roughly where we
                      // are, then refresh with a fresh fix.
                      final last = _lastKnownPosition;
                      if (last != null) {
                        _mapController.move(
                          LatLng(last.latitude, last.longitude),
                          16,
                        );
                      }
                      try {
                        final pos =
                            await Geolocator.getCurrentPosition();
                        if (!mounted) return;
                        setState(() => _lastKnownPosition = pos);
                        _mapController.move(
                          LatLng(pos.latitude, pos.longitude),
                          16,
                        );
                      } catch (_) {}
                    },
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppEditorial.cream,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rTiny),
                        boxShadow: AppEditorial.softShadow,
                      ),
                      child: const Icon(PhosphorIconsRegular.crosshair,
                          size: 18, color: AppEditorial.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vehicle picker — only when not tracking ────────────────────
          if (!isTracking && !_loadingVehicles && _vehicles.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.of(context).padding.top + 64,
              child: _VehicleSelector(
                vehicles: _vehicles,
                selected: _selectedVehicle,
                onChanged: (v) => setState(() => _selectedVehicle = v),
              ),
            ),

          // Bottom panel — telemetry + start/stop ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              isTracking: isTracking,
              stopping: _stopping,
              distText: distText,
              durText: durText,
              pointCount: positions.length,
              onStart: _startTrip,
              onStop: _stopTrip,
              onManual: _openManualEntry,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({
    required this.vehicles,
    required this.selected,
    required this.onChanged,
  });

  final List<Vehicle> vehicles;
  final Vehicle? selected;
  final ValueChanged<Vehicle?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        children: [
          Text('Unit', style: AppEditorial.eyebrow()),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Vehicle>(
                value: selected,
                isDense: true,
                isExpanded: true,
                hint: Text('Pilih kendaraan',
                    style: AppEditorial.sans(fontSize: 13)),
                icon: const Icon(PhosphorIconsRegular.caretDown,
                    color: AppEditorial.ink, size: 18),
                style: AppEditorial.sans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
                dropdownColor: AppEditorial.cream,
                items: vehicles.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(
                      '${v.type.label} · ${v.name}',
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.isTracking,
    required this.stopping,
    required this.distText,
    required this.durText,
    required this.pointCount,
    required this.onStart,
    required this.onStop,
    required this.onManual,
  });

  final bool isTracking;
  final bool stopping;
  final String distText;
  final String durText;
  final int pointCount;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: AppEditorial.ink.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTracking) ...[
                // Telemetry readout
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppEditorial.canvasSoft,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rTiny),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Telemetry(
                            label: 'JARAK', value: distText),
                      ),
                      Container(
                          width: 1,
                          height: 44,
                          color: AppEditorial.hairline),
                      Expanded(
                        child:
                            _Telemetry(label: 'DURASI', value: durText),
                      ),
                      Container(
                          width: 1,
                          height: 44,
                          color: AppEditorial.hairline),
                      Expanded(
                        child: _Telemetry(
                            label: 'TITIK', value: '$pointCount'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: stopping ? null : onStop,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppEditorial.rust,
                  ),
                  child: stopping
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppEditorial.canvas,
                          ),
                        )
                      : const Text('Selesai perjalanan'),
                ),
              ] else ...[
                Text('Rekam perjalanan',
                    style: AppEditorial.heading(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(
                  'Tap mulai untuk merekam rute & jarak via GPS.',
                  style: AppEditorial.sans(
                    fontSize: 13,
                    color: AppEditorial.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppEditorial.brand,
                    foregroundColor: AppEditorial.ink,
                  ),
                  child: const Text('Mulai perjalanan'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onManual,
                  child: const Text('Catat manual'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Telemetry extends StatelessWidget {
  const _Telemetry({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppEditorial.eyebrow(fontSize: 9.5)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppEditorial.mono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Animated "you are here" dot. A solid butter core with a slowly
/// expanding ink halo so it reads as live position even when stationary.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        // Halo expands 0 → 1 then resets, fading as it grows.
        final haloScale = 0.5 + 0.5 * t;
        final haloOpacity = (1.0 - t).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: haloScale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppEditorial.butter
                      .withValues(alpha: 0.45 * haloOpacity),
                ),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppEditorial.butter,
                border: Border.all(color: AppEditorial.ink, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppEditorial.ink.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
