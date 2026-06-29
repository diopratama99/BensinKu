import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/prediction_service.dart';

class TripDetailPage extends StatefulWidget {
  const TripDetailPage({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage>
    with SingleTickerProviderStateMixin {
  final _repo = SupabaseRepository.ofDefaultClient();
  late Trip trip;

  /// Whether anything changed — returned to the caller so the list refreshes.
  bool _changed = false;

  /// Animasi menggambar rute polyline (sekali jalan saat data siap).
  late final AnimationController _route;
  bool _routeStarted = false;

  @override
  void initState() {
    super.initState();
    trip = widget.trip;
    _route = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _route.dispose();
    super.dispose();
  }

  /// Potong path hingga fraksi `t` (0..1) berdasarkan panjang kumulatif,
  /// dengan interpolasi segmen terakhir agar gambarnya mulus.
  List<LatLng> _partialPath(List<LatLng> pts, double t) {
    if (pts.length < 2 || t >= 1) return pts;
    if (t <= 0) return [pts.first];

    const distance = Distance();
    final segLen = <double>[];
    double total = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      final d = distance(pts[i], pts[i + 1]);
      segLen.add(d);
      total += d;
    }
    if (total == 0) return pts;

    final target = total * t;
    double acc = 0;
    final out = <LatLng>[pts.first];
    for (var i = 0; i < segLen.length; i++) {
      if (acc + segLen[i] >= target) {
        final frac = segLen[i] == 0 ? 0.0 : (target - acc) / segLen[i];
        final a = pts[i];
        final b = pts[i + 1];
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * frac,
          a.longitude + (b.longitude - a.longitude) * frac,
        ));
        break;
      }
      acc += segLen[i];
      out.add(pts[i + 1]);
    }
    return out;
  }

  Future<void> _edit() async {
    final result = await showModalBottomSheet<Trip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppEditorial.ink.withValues(alpha: 0.55),
      builder: (_) => _TripEditSheet(trip: trip),
    );
    if (result != null && mounted) {
      setState(() {
        trip = result;
        _changed = true;
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus perjalanan?',
            style: AppEditorial.heading(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
        content: const Text(
            'Perjalanan ini beserta rute GPS-nya akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: AppEditorial.rust),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteTrip(trip.id);
      if (mounted) Navigator.of(context).pop(true); // signal change
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    final dateFmt = DateFormat('EEEE, d MMM yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm', 'id_ID');

    final duration = trip.endedAt?.difference(trip.startedAt);
    String durText = '—';
    if (duration != null) {
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      final s = duration.inSeconds % 60;
      if (h > 0) {
        durText = '${h}j ${m}m ${s}s';
      } else if (m > 0) {
        durText = '${m}m ${s}s';
      } else {
        durText = '${s}s';
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Intercept all back gestures/buttons so we always return whether
        // something changed (so the list refreshes).
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppEditorial.canvas,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            // Return whether something changed so the list can refresh.
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          title: Text(
            'Detail perjalanan',
            style: AppEditorial.heading(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.pencilSimple),
              tooltip: 'Edit',
              onPressed: _edit,
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.trash,
                  color: AppEditorial.rust),
              tooltip: 'Hapus',
              onPressed: _delete,
            ),
          ],
        ),
        body: FutureBuilder<List<TripWaypoint>>(
          future: repo.getTripWaypoints(trip.id),
          builder: (context, snap) {
            final waypoints = snap.data ?? [];
            final latLngs =
                waypoints.map((w) => LatLng(w.lat, w.lng)).toList();

          LatLngBounds? bounds;
          if (latLngs.length >= 2) {
            bounds = LatLngBounds.fromPoints(latLngs);
          }

          final startPt = latLngs.isNotEmpty ? latLngs.first : null;
          final endPt = latLngs.length > 1 ? latLngs.last : null;

          // Mulai animasi gambar rute sekali, setelah data siap.
          if (!_routeStarted &&
              snap.connectionState != ConnectionState.waiting &&
              latLngs.length >= 2) {
            _routeStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _route.forward();
            });
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // Map ────────────────────────────────────────────────
              SizedBox(
                height: 240,
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppEditorial.ink),
                      )
                    : latLngs.isEmpty
                        ? Container(
                            color: AppEditorial.cream,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 140,
                                  child: Image.asset(
                                    'assets/illustrations/empty_rute.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tidak ada data rute.',
                                  style: AppEditorial.sans(
                                    fontSize: 12,
                                    color: AppEditorial.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : FlutterMap(
                            options: MapOptions(
                              initialCameraFit: bounds != null
                                  ? CameraFit.bounds(
                                      bounds: bounds,
                                      padding: const EdgeInsets.all(32))
                                  : null,
                              initialCenter:
                                  startPt ?? const LatLng(0, 0),
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.temanlabs.bensinku',
                              ),
                              if (latLngs.length >= 2)
                                AnimatedBuilder(
                                  animation: _route,
                                  builder: (context, _) {
                                    final pts = _partialPath(
                                        latLngs, _route.value);
                                    return PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: pts,
                                          color: AppEditorial.ink,
                                          strokeWidth: 4,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              AnimatedBuilder(
                                animation: _route,
                                builder: (context, _) {
                                  // Kepala rute berjalan mengikuti gambar.
                                  final head = latLngs.length >= 2
                                      ? _partialPath(latLngs, _route.value)
                                          .last
                                      : endPt;
                                  return MarkerLayer(
                                    markers: [
                                      if (startPt != null)
                                        Marker(
                                          point: startPt,
                                          width: 30,
                                          height: 30,
                                          child: const _Pin(
                                            color: AppEditorial.sage,
                                            icon: PhosphorIconsRegular.circle,
                                          ),
                                        ),
                                      if (head != null)
                                        Marker(
                                          point: head,
                                          width: 30,
                                          height: 30,
                                          child: const _Pin(
                                            color: AppEditorial.rust,
                                            icon: PhosphorIconsRegular.mapPin,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
              ),

              // Stats ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFmt.format(trip.startedAt),
                      style: AppEditorial.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppEditorial.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${timeFmt.format(trip.startedAt)}${trip.endedAt != null ? ' – ${timeFmt.format(trip.endedAt!)}' : ' · aktif'}',
                      style: AppEditorial.heading(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const EditorialSectionHeader(label: 'Telemetri'),
                    const SizedBox(height: 12),
                    EditorialCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 4),
                      child: Column(
                        children: [
                          EditorialDataRow(
                            label: 'Jarak tempuh',
                            value: trip.distanceKm != null
                                ? '${trip.distanceKm!.toStringAsFixed(2)} km'
                                : '—',
                          ),
                          EditorialDataRow(
                            label: 'Durasi',
                            value: durText,
                          ),
                          EditorialDataRow(
                            label: 'Titik GPS',
                            value: '${waypoints.length}',
                          ),

                          // Fuel estimate section
                          _FuelEstimateRows(trip: trip),
                        ],
                      ),
                    ),

                    if (trip.note != null && trip.note!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const EditorialSectionHeader(label: 'Catatan'),
                      const SizedBox(height: 12),
                      EditorialCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          trip.note!,
                          style: AppEditorial.sans(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

/// Fuel consumption estimate for this trip, computed from the vehicle's
/// posterior km/L (Bayesian blend of prior + measured samples).
class _FuelEstimateRows extends StatelessWidget {
  const _FuelEstimateRows({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    if (trip.distanceKm == null || trip.distanceKm! <= 0) {
      return const SizedBox.shrink();
    }

    final repo = SupabaseRepository.ofDefaultClient();
    final meta =
        Supabase.instance.client.auth.currentUser?.userMetadata;
    final usageProfile =
        UsageProfile.tryParse(meta?['usage_profile'] as String?);
    final primaryCity =
        PrimaryCity.tryParse(meta?['primary_city'] as String?);

    return FutureBuilder<(Vehicle?, List<EfficiencySample>)>(
      future: () async {
        final vehicles = await repo.listVehicles();
        final vehicle = vehicles
            .where((v) => v.id == trip.vehicleId)
            .firstOrNull;
        final samples = vehicle != null
            ? await repo.recentEfficiencySamples(
                vehicleId: vehicle.id, limit: 20)
            : <EfficiencySample>[];
        return (vehicle, samples);
      }(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data?.$1 == null) {
          return const SizedBox.shrink();
        }
        final vehicle = snap.data!.$1!;
        final samples = snap.data!.$2;

        final estimate = PredictionService.posteriorKmPerLiter(
          vehicle: vehicle,
          samples: samples,
          primaryCity: primaryCity,
          usageProfile: usageProfile,
        );

        final liters = trip.distanceKm! / estimate.kmPerLiter;
        final rupiah = NumberFormat.currency(
          locale: 'id_ID',
          symbol: '',
          decimalDigits: 0,
        );

        // Try to get latest fuel price for cost estimate.
        return FutureBuilder<FuelPrice?>(
          future: () async {
            final prefFuelId =
                meta?['preferred_fuel_id'] as String?;
            if (prefFuelId == null) return null;
            return repo.getFuelPrice(
              fuelProductId: prefFuelId,
              onDate: trip.startedAt,
            );
          }(),
          builder: (context, priceSnap) {
            final price = priceSnap.data;
            final costRp = price != null
                ? liters * price.pricePerLiter
                : null;

            final sourceLabel = estimate.source == 'PRIOR'
                ? 'profil kendaraan'
                : '${estimate.sampleCount} ukuran';

            return Column(
              children: [
                EditorialDataRow(
                  label: 'Estimasi BBM',
                  value: '${liters.toStringAsFixed(2)} L',
                  valueStyle: AppEditorial.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.butterDeep,
                    tabular: true,
                  ),
                ),
                if (costRp != null)
                  EditorialDataRow(
                    label: 'Estimasi biaya',
                    value: 'Rp ${rupiah.format(costRp).trim()}',
                  ),
                EditorialDataRow(
                  label: 'Sumber efisiensi',
                  value: sourceLabel,
                  isLast: true,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Bottom sheet to edit ONLY distance + duration of a trip. The GPS route
/// and start time are intentionally not editable.
class _TripEditSheet extends StatefulWidget {
  const _TripEditSheet({required this.trip});
  final Trip trip;

  @override
  State<_TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends State<_TripEditSheet> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _distanceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    if (t.distanceKm != null) {
      _distanceCtrl.text = t.distanceKm!.toStringAsFixed(2);
    }
    final dur = t.endedAt?.difference(t.startedAt);
    if (dur != null) _durationCtrl.text = dur.inMinutes.toString();
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final distance = double.tryParse(
          _distanceCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        -1;
    if (distance < 0) {
      _toast('Jarak tidak valid.');
      return;
    }
    final minutes = int.tryParse(_durationCtrl.text.trim()) ?? -1;
    if (minutes < 0) {
      _toast('Durasi tidak valid.');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await _repo.updateTripDistanceDuration(
        tripId: widget.trip.id,
        startedAt: widget.trip.startedAt,
        distanceKm: distance,
        duration: Duration(minutes: minutes),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Gagal simpan: $e');
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppEditorial.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppEditorial.hairline,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rPill),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('Edit perjalanan',
                        style: AppEditorial.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        )),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(PhosphorIconsRegular.x,
                          size: 22, color: AppEditorial.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hanya jarak tempuh & durasi yang bisa diubah. '
                  'Rute GPS tidak berubah.',
                  style: AppEditorial.sans(
                    fontSize: 12,
                    color: AppEditorial.inkSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JARAK', style: AppEditorial.eyebrow()),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _distanceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: AppEditorial.mono(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              suffixText: 'km',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DURASI', style: AppEditorial.eyebrow()),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _durationCtrl,
                            keyboardType: TextInputType.number,
                            style: AppEditorial.mono(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              suffixText: 'menit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppEditorial.canvas,
                          ),
                        )
                      : const Text('Simpan perubahan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppEditorial.cream, width: 3),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppEditorial.ink.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: const Color(0xFFFFFFFF),
        size: 14,
      ),
    );
  }
}
