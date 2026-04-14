import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

class TripDetailPage extends StatelessWidget {
  const TripDetailPage({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repo = SupabaseRepository.ofDefaultClient();
    final dateFmt = DateFormat('EEEE, dd MMM yyyy', 'id_ID');
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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Detail Perjalanan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<TripWaypoint>>(
        future: repo.getTripWaypoints(trip.id),
        builder: (context, snap) {
          final waypoints = snap.data ?? [];
          final latLngs = waypoints
              .map((w) => LatLng(w.lat, w.lng))
              .toList();

          // Compute bounds if we have points
          LatLngBounds? bounds;
          if (latLngs.length >= 2) {
            bounds = LatLngBounds.fromPoints(latLngs);
          }

          final startPt = latLngs.isNotEmpty ? latLngs.first : null;
          final endPt = latLngs.length > 1 ? latLngs.last : null;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Map ──────────────────────────────────────────────────
              SizedBox(
                height: 260,
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : latLngs.isEmpty
                        ? Container(
                            color: cs.surfaceContainerHighest,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.map_outlined,
                                      size: 40,
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.4)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tidak ada data rute',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : FlutterMap(
                            options: MapOptions(
                              initialCameraFit: bounds != null
                                  ? CameraFit.bounds(
                                      bounds: bounds,
                                      padding:
                                          const EdgeInsets.all(32))
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
                                    'com.bensinku.bensinku',
                              ),
                              if (latLngs.length >= 2)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: latLngs,
                                      color: cs.primary,
                                      strokeWidth: 4,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  if (startPt != null)
                                    Marker(
                                      point: startPt,
                                      width: 32,
                                      height: 32,
                                      child: _MapPin(
                                          color: Colors.green,
                                          icon: Icons.play_arrow_rounded),
                                    ),
                                  if (endPt != null)
                                    Marker(
                                      point: endPt,
                                      width: 32,
                                      height: 32,
                                      child: _MapPin(
                                          color: cs.error,
                                          icon: Icons.flag_rounded),
                                    ),
                                ],
                              ),
                            ],
                          ),
              ),

              // ── Stats cards ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date/time header
                    Text(
                      dateFmt.format(trip.startedAt),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${timeFmt.format(trip.startedAt)}'
                      '${trip.endedAt != null ? ' — ${timeFmt.format(trip.endedAt!)}' : ' (belum selesai)'}',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.straighten_rounded,
                            label: 'Jarak',
                            value: trip.distanceKm != null
                                ? '${trip.distanceKm!.toStringAsFixed(2)} km'
                                : '—',
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.timer_rounded,
                            label: 'Durasi',
                            value: durText,
                            color: cs.secondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.location_on_rounded,
                            label: 'Titik',
                            value: '${waypoints.length}',
                            color: cs.tertiary,
                          ),
                        ),
                      ],
                    ),

                    if (trip.note != null &&
                        trip.note!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.notes_rounded,
                                color: cs.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(trip.note!)),
                          ],
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
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
