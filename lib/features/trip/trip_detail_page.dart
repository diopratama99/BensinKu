import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

class TripDetailPage extends StatelessWidget {
  const TripDetailPage({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository.ofDefaultClient();
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

    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'DETAIL PERJALANAN',
          style: AppEditorial.mono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
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
                                const Icon(Icons.map_outlined,
                                    size: 32,
                                    color: AppEditorial.inkMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'tidak ada data rute.',
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
                                    'com.bensinku.bensinku',
                              ),
                              if (latLngs.length >= 2)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: latLngs,
                                      color: AppEditorial.ink,
                                      strokeWidth: 4,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  if (startPt != null)
                                    Marker(
                                      point: startPt,
                                      width: 24,
                                      height: 24,
                                      child: _Pin(
                                        color: AppEditorial.sage,
                                        glyph: '▶',
                                      ),
                                    ),
                                  if (endPt != null)
                                    Marker(
                                      point: endPt,
                                      width: 24,
                                      height: 24,
                                      child: _Pin(
                                        color: AppEditorial.rust,
                                        glyph: '■',
                                      ),
                                    ),
                                ],
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
                    Text(dateFmt.format(trip.startedAt).toUpperCase(),
                        style: AppEditorial.eyebrow()),
                    const SizedBox(height: 6),
                    Text(
                      '${timeFmt.format(trip.startedAt)}${trip.endedAt != null ? ' — ${timeFmt.format(trip.endedAt!)}' : ' — (aktif)'}',
                      style: AppEditorial.mono(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const EditorialSectionHeader(
                        index: '01', label: 'TELEMETRI'),
                    const SizedBox(height: 12),
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
                      isLast: true,
                    ),

                    if (trip.note != null && trip.note!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const EditorialSectionHeader(
                          index: '02', label: 'CATATAN'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppEditorial.cream,
                          border: Border.all(
                              color: AppEditorial.hairlineSoft, width: 1),
                          borderRadius:
                              BorderRadius.circular(AppEditorial.rCard),
                        ),
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
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.glyph});
  final Color color;
  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppEditorial.canvas, width: 2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        glyph,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
