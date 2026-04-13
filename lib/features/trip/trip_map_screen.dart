import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/trip_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Trip Map Screen
// ──────────────────────────────────────────────────────────────────────────────

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
    // Load vehicles
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

    // Check location
    final serviceOn = await TripService.isServiceEnabled();
    if (!serviceOn) {
      _showSnack('GPS tidak aktif. Aktifkan lokasi di pengaturan perangkat.');
      return;
    }
    final granted = await TripService.requestPermission();
    if (mounted) setState(() => _locationReady = granted);
    if (!granted) {
      _showSnack('Izin lokasi diperlukan untuk tracking perjalanan.');
      return;
    }

    // Center map on current position
    try {
      final pos = await Geolocator.getCurrentPosition();
      _lastKnownPosition = pos;
      if (mounted) {
        _mapController.move(
          LatLng(pos.latitude, pos.longitude),
          15,
        );
      }
    } catch (_) {}
  }

  // ── Trip control ────────────────────────────────────────────────────────

  Future<void> _startTrip() async {
    if (_selectedVehicle == null) {
      _showSnack('Pilih kendaraan terlebih dahulu.');
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
      _showSnack('Gagal memulai perjalanan: $e');
    }
  }

  Future<void> _stopTrip() async {
    if (_service == null || _stopping) return;
    setState(() => _stopping = true);

    try {
      final finished = await _service!.stopTrip();
      if (mounted && finished != null) {
        _showTripSummaryDialog(finished);
      }
    } catch (e) {
      _showSnack('Gagal mengakhiri perjalanan: $e');
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {
      // Update map to follow latest position
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _showTripSummaryDialog(Trip trip) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final distText = trip.distanceKm != null
            ? '${trip.distanceKm!.toStringAsFixed(2)} km'
            : '—';
        final duration = trip.endedAt != null
            ? trip.endedAt!.difference(trip.startedAt)
            : Duration.zero;
        final durText =
            '${duration.inMinutes}m ${(duration.inSeconds % 60)}s';

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Perjalanan Selesai'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryRow(
                icon: Icons.timeline_rounded,
                label: 'Jarak Tempuh',
                value: distText,
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                icon: Icons.timer_rounded,
                label: 'Durasi',
                value: durText,
              ),
              const SizedBox(height: 8),
              _SummaryRow(
                icon: Icons.schedule_rounded,
                label: 'Mulai',
                value: DateFormat('HH:mm, dd MMM', 'id_ID')
                    .format(trip.startedAt),
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
              child: const Text('Oke'),
            ),
          ],
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTracking = _service?.isTracking ?? false;
    final positions = _service?.positions ?? [];
    final polylinePoints =
        positions.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final distKm = _service?.distanceKm ?? 0.0;
    final distText = distKm < 1
        ? '${(_service?.distanceKm ?? 0.0 * 1000).toStringAsFixed(0)} m'
        : '${distKm.toStringAsFixed(2)} km';

    // Calculate duration
    String durText = '—';
    if (isTracking && _service?.activeTrip != null) {
      final elapsed =
          DateTime.now().difference(_service!.activeTrip!.startedAt);
      durText =
          '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    final initCenter = _lastKnownPosition != null
        ? LatLng(_lastKnownPosition!.latitude, _lastKnownPosition!.longitude)
        : const LatLng(-6.2088, 106.8456); // Jakarta fallback

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initCenter,
              initialZoom: 15,
            ),
            children: [
              // OSM tile layer (free, no API key)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bensinku',
                maxZoom: 19,
              ),
              // Route polyline
              if (polylinePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      color: cs.primary,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              // Current position marker
              if (positions.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: polylinePoints.last,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  cs.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.navigation_rounded,
                          color: cs.onPrimary,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── Top bar ────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Title card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.map_rounded,
                              color: cs.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Trip Tracker',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'OpenStreetMap',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Recenter button
                  _MapButton(
                    icon: Icons.my_location_rounded,
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
                  ),
                ],
              ),
            ),
          ),

          // ── Vehicle selector (only shown when not tracking) ───────────
          if (!isTracking && !_loadingVehicles && _vehicles.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              top: 90,
              child: _VehicleSelector(
                vehicles: _vehicles,
                selected: _selectedVehicle,
                onChanged: (v) => setState(() => _selectedVehicle = v),
              ),
            ),

          // ── Bottom control panel ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              cs: cs,
              isTracking: isTracking,
              stopping: _stopping,
              distText: isTracking ? distText : null,
              durText: isTracking ? durText : null,
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

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
          ],
        ),
        child: Icon(icon, color: cs.primary, size: 20),
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), blurRadius: 12),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Vehicle>(
          value: selected,
          isDense: true,
          isExpanded: true,
          hint: const Text('Pilih kendaraan'),
          icon: Icon(Icons.expand_more_rounded,
              color: cs.onSurfaceVariant, size: 20),
          items: vehicles.map((v) {
            final isMotor = v.type == VehicleType.motor;
            return DropdownMenuItem(
              value: v,
              child: Row(
                children: [
                  Icon(
                    isMotor
                        ? Icons.two_wheeler_rounded
                        : Icons.directions_car_filled_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(v.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => onChanged(v),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.cs,
    required this.isTracking,
    required this.stopping,
    required this.distText,
    required this.durText,
    required this.pointCount,
    required this.onStart,
    required this.onStop,
  });

  final ColorScheme cs;
  final bool isTracking;
  final bool stopping;
  final String? distText;
  final String? durText;
  final int pointCount;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          if (isTracking) ...[
            // Live stats
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.timeline_rounded,
                    label: 'Jarak',
                    value: distText ?? '0 m',
                    color: cs.primaryContainer,
                    iconColor: cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    icon: Icons.timer_rounded,
                    label: 'Durasi',
                    value: durText ?? '00:00',
                    color: cs.secondaryContainer,
                    iconColor: cs.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatChip(
                    icon: Icons.location_on_rounded,
                    label: 'Titik GPS',
                    value: '$pointCount',
                    color: cs.tertiaryContainer,
                    iconColor: cs.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            Text(
              'Rekam Perjalanan',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap mulai untuk merekam rute & jarak secara otomatis',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
          ],

          // Action button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: stopping
                  ? null
                  : (isTracking ? onStop : onStart),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isTracking ? Colors.red.shade600 : cs.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: stopping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(
                      isTracking
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_rounded,
                    ),
              label: Text(
                stopping
                    ? 'Menyimpan...'
                    : (isTracking ? 'Selesai Perjalanan' : 'Mulai Perjalanan'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: iconColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: iconColor),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
