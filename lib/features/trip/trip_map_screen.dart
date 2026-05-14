import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/trip_service.dart';

/// Rute — GPS trip recorder with telemetry overlay.
/// Map is monochrome; overlays are mono LCD-style readouts.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _mapController = MapController();

  TripService? _service;
  Vehicle? _selectedVehicle;
  List<Vehicle> _vehicles = [];
  bool _loadingVehicles = true;
  bool _locationReady = false;
  bool _stopping = false;
  Position? _lastKnownPosition;

  @override
  void initState() {
    super.initState();
    _init();
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
    final granted = await TripService.requestPermission();
    if (mounted) setState(() => _locationReady = granted);
    if (!granted) {
      _showSnack('Izin lokasi diperlukan untuk tracking.');
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      _lastKnownPosition = pos;
      if (mounted) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      }
    } catch (_) {}
  }

  Future<void> _startTrip() async {
    if (_selectedVehicle == null) {
      _showSnack('Pilih kendaraan dulu.');
      return;
    }
    if (!_locationReady) {
      _showSnack('Izin lokasi belum diberikan.');
      return;
    }

    final svc = TripService(
      repo: _repo,
      vehicleId: _selectedVehicle!.id,
    );
    svc.addListener(_onServiceUpdate);

    try {
      await svc.startTrip();
      setState(() => _service = svc);
    } catch (e) {
      svc.removeListener(_onServiceUpdate);
      svc.dispose();
      _showSnack('Gagal mulai: $e');
    }
  }

  Future<void> _stopTrip() async {
    if (_service == null || _stopping) return;
    setState(() => _stopping = true);

    try {
      final finished = await _service!.stopTrip();
      if (mounted && finished != null) {
        _showTripSummary(finished);
      }
    } catch (e) {
      _showSnack('Gagal mengakhiri: $e');
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {
      final positions = _service?.positions ?? [];
      if (positions.isNotEmpty) {
        final last = positions.last;
        _mapController.move(
          LatLng(last.latitude, last.longitude),
          _mapController.camera.zoom,
        );
      }
    });
  }

  @override
  void dispose() {
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

  void _showTripSummary(Trip trip) {
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
            'PERJALANAN SELESAI',
            style: AppEditorial.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                setState(() {
                  _service?.removeListener(_onServiceUpdate);
                  _service?.dispose();
                  _service = null;
                });
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bensinku.bensinku',
                maxZoom: 19,
              ),
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
              if (positions.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: polylinePoints.last,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppEditorial.butter,
                          border: Border.all(
                              color: AppEditorial.ink, width: 2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
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
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppEditorial.canvas,
                      border: Border.all(
                          color: AppEditorial.ink, width: 1),
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rTiny),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isTracking
                                ? AppEditorial.rust
                                : AppEditorial.inkMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTracking ? 'TRACKING ACTIVE' : 'GPS READY',
                          style: AppEditorial.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final pos =
                            await Geolocator.getCurrentPosition();
                        _mapController.move(
                          LatLng(pos.latitude, pos.longitude),
                          16,
                        );
                      } catch (_) {}
                    },
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppEditorial.canvas,
                        border: Border.all(
                            color: AppEditorial.ink, width: 1),
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rTiny),
                      ),
                      child: const Icon(Icons.my_location_rounded,
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
        color: AppEditorial.canvas,
        border: Border.all(color: AppEditorial.ink, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        children: [
          Text('UNIT', style: AppEditorial.eyebrow()),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Vehicle>(
                value: selected,
                isDense: true,
                isExpanded: true,
                hint: Text('Pilih kendaraan',
                    style: AppEditorial.sans(fontSize: 13)),
                icon: const Icon(Icons.expand_more_rounded,
                    color: AppEditorial.ink, size: 18),
                style: AppEditorial.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                dropdownColor: AppEditorial.cream,
                items: vehicles.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(
                      '${v.type.label.toUpperCase()} · ${v.name}',
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
  });

  final bool isTracking;
  final bool stopping;
  final String distText;
  final String durText;
  final int pointCount;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppEditorial.canvas,
        border: Border(
          top: BorderSide(color: AppEditorial.ink, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTracking) ...[
                // Telemetry readout
                Row(
                  children: [
                    Expanded(
                      child: _Telemetry(
                          label: 'JARAK', value: distText),
                    ),
                    Container(
                        width: 1,
                        height: 48,
                        color: AppEditorial.hairline),
                    Expanded(
                      child:
                          _Telemetry(label: 'DURASI', value: durText),
                    ),
                    Container(
                        width: 1,
                        height: 48,
                        color: AppEditorial.hairline),
                    Expanded(
                      child: _Telemetry(
                          label: 'TITIK', value: '$pointCount'),
                    ),
                  ],
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
                      : const Text('■ SELESAI PERJALANAN'),
                ),
              ] else ...[
                Text('REKAM PERJALANAN',
                    style: AppEditorial.eyebrow()),
                const SizedBox(height: 4),
                Text(
                  'Tap mulai untuk merekam rute & jarak via GPS.',
                  style: AppEditorial.sans(
                    fontSize: 13,
                    color: AppEditorial.inkSoft,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onStart,
                  child: const Text('► MULAI PERJALANAN'),
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
