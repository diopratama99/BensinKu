import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/prediction_service.dart';
import '../../widgets/vehicle_cover.dart';

/// Beranda — fuel logbook dashboard.
///
/// Layout:
///   §01 LAPORAN BULAN INI    — pump-LCD reading + 3-col stat
///   §02 PENGISIAN TERAKHIR   — single line entry from log
///   §03 PREDIKSI BENSIN      — gauge + key/value rows
///   §04 GARASI               — vehicle picker, photo cards
///   §05 RIWAYAT              — last few entries with dotted leaders
class SummaryTab extends StatefulWidget {
  const SummaryTab({super.key, this.onGoToHistory, this.onGoToProfile});

  final VoidCallback? onGoToHistory;
  final VoidCallback? onGoToProfile;

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  String? _vehicleId;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  final _date = DateFormat('d MMM yyyy', 'id_ID');

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppEditorial.ink,
      backgroundColor: AppEditorial.canvas,
      child: FutureBuilder<List<Vehicle>>(
        future: _repo.listVehicles(),
        builder: (context, vehiclesSnap) {
          if (vehiclesSnap.hasError) {
            return _CenteredError(vehiclesSnap.error.toString());
          }
          final vehicles = vehiclesSnap.data;
          if (vehicles == null) return const _CenteredLoading();

          if (vehicles.isEmpty) {
            return const _CenteredEmpty(
              title: 'Belum ada kendaraan.',
              subtitle: 'Tambah dulu di tab Profil.',
            );
          }

          _vehicleId ??= vehicles.first.id;

          return FutureBuilder<(List<Refuel>, List<Trip>)>(
            future: () async {
              final now = DateTime.now();
              final monthStart = DateTime(now.year, now.month, 1);
              final results = await Future.wait([
                _repo.listRefuels(vehicleId: _vehicleId),
                _repo.listTrips(vehicleId: _vehicleId, since: monthStart),
              ]);
              return (results[0] as List<Refuel>, results[1] as List<Trip>);
            }(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _CenteredError(snap.error.toString());
              }
              final data = snap.data;
              if (data == null) return const _CenteredLoading();

              final refuels = data.$1;
              final monthTrips = data.$2;

              final now = DateTime.now();
              final monthStart = DateTime(now.year, now.month, 1);
              final nextMonth = now.month == 12
                  ? DateTime(now.year + 1, 1, 1)
                  : DateTime(now.year, now.month + 1, 1);

              final monthRefuels = refuels.where((r) =>
                  !r.refuelDate.isBefore(monthStart) &&
                  r.refuelDate.isBefore(nextMonth)).toList();

              final totalSpend =
                  monthRefuels.fold<num>(0, (sum, r) => sum + r.totalRp);
              final totalLiters =
                  monthRefuels.fold<num>(0, (sum, r) => sum + r.liters);

              final tripDistanceKm = monthTrips.fold<double>(
                  0, (sum, t) => sum + (t.distanceKm ?? 0));

              final monthName =
                  DateFormat('MMMM yyyy', 'id_ID').format(now).toUpperCase();
              final lastRefuel =
                  refuels.isNotEmpty ? refuels.first : null;
              final recentRefuels = refuels.take(4).toList();
              final selectedVehicle = vehicles.firstWhere(
                (v) => v.id == _vehicleId,
                orElse: () => vehicles.first,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                children: [
                  // Greeting + vehicle selector
                  const _GreetingBlock(),
                  const SizedBox(height: 14),
                  _VehicleSelector(
                    vehicle: selectedVehicle,
                    totalCount: vehicles.length,
                    onTap: () => _pickVehicle(vehicles),
                  ),
                  const SizedBox(height: 24),

                  // §01 — Laporan bulan ini
                  EditorialSectionHeader(
                    index: '01',
                    label: 'LAPORAN $monthName',
                  ),
                  const SizedBox(height: 18),
                  _MonthReadout(
                    totalSpend: totalSpend,
                    totalLiters: totalLiters,
                    distanceKm: tripDistanceKm,
                    refuelCount: monthRefuels.length,
                    rupiah: _rupiah,
                  ),
                  const SizedBox(height: 28),

                  // §02 — Pengisian terakhir
                  if (lastRefuel != null) ...[
                    const EditorialSectionHeader(
                      index: '02',
                      label: 'PENGISIAN TERAKHIR',
                    ),
                    const SizedBox(height: 14),
                    _LastRefuelLine(
                      refuel: lastRefuel,
                      rupiah: _rupiah,
                      date: _date,
                    ),
                    const SizedBox(height: 28),
                  ],

                  // §03 — Prediksi
                  const EditorialSectionHeader(
                    index: '03',
                    label: 'PREDIKSI BENSIN',
                  ),
                  const SizedBox(height: 14),
                  _FuelPredictionBlock(vehicle: selectedVehicle),
                  const SizedBox(height: 28),

                  // §04 — Riwayat
                  EditorialSectionHeader(
                    index: '04',
                    label: 'RIWAYAT',
                    trailing: GestureDetector(
                      onTap: widget.onGoToHistory,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('LIHAT SEMUA',
                              style: AppEditorial.eyebrow(
                                  color: AppEditorial.ink)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 12, color: AppEditorial.ink),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (recentRefuels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'belum ada catatan pengisian.',
                        style: AppEditorial.sans(
                          fontSize: 13,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                    )
                  else
                    ...recentRefuels.asMap().entries.map((e) => _LogRow(
                          refuel: e.value,
                          rupiah: _rupiah,
                          date: _date,
                          isLast: e.key == recentRefuels.length - 1,
                        )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppEditorial.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  color: AppEditorial.hairline,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('GARASI', style: AppEditorial.eyebrow()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomPaint(
                      painter: _DottedLine(),
                      child: const SizedBox(height: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${vehicles.length} UNIT',
                      style: AppEditorial.eyebrow()),
                ],
              ),
              const SizedBox(height: 14),
              ...vehicles.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VehicleRow(
                      vehicle: v,
                      isSelected: v.id == _vehicleId,
                      onTap: () => Navigator.of(ctx).pop(v.id),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != _vehicleId) {
      setState(() => _vehicleId = picked);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting + vehicle selector (top of dashboard)
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingBlock extends StatelessWidget {
  const _GreetingBlock();

  String _greetingPrefix(int hour) {
    if (hour >= 4 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final user = Supabase.instance.client.auth.currentUser;
    final raw = user?.userMetadata?['name'];
    var name = raw is String ? raw.trim() : '';
    if (name.isEmpty) {
      final email = user?.email ?? '';
      name = email.contains('@') ? email.split('@').first : 'Pengendara';
    }
    final firstName = name.split(RegExp(r'\s+')).first;
    final greeting = _greetingPrefix(now.hour);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Vertical butter rule
        Container(
          width: 3,
          height: 44,
          color: AppEditorial.butter,
          margin: const EdgeInsets.only(right: 12),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting.toUpperCase(),
                style: AppEditorial.eyebrow(
                  color: AppEditorial.butterDeep,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                style: AppEditorial.mono(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.05,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({
    required this.vehicle,
    required this.totalCount,
    required this.onTap,
  });

  final Vehicle vehicle;
  final int totalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppEditorial.canvas,
          border:
              Border.all(color: AppEditorial.hairline, width: 1),
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
        ),
        child: Row(
          children: [
            // Compact icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppEditorial.butterSoft,
                borderRadius:
                    BorderRadius.circular(AppEditorial.rTiny),
              ),
              alignment: Alignment.center,
              child: Icon(
                vehicle.type.label.toLowerCase().contains('motor')
                    ? Icons.two_wheeler_rounded
                    : Icons.directions_car_rounded,
                size: 16,
                color: AppEditorial.butterDeep,
              ),
            ),
            const SizedBox(width: 10),
            // Eyebrow + name on a single tight line
            Expanded(
              child: Row(
                children: [
                  Text(
                    vehicle.type.label.toUpperCase(),
                    style: AppEditorial.eyebrow(
                      fontSize: 9,
                      color: AppEditorial.butterDeep,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vehicle.name,
                      style: AppEditorial.mono(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$totalCount UNIT',
              style: AppEditorial.eyebrow(
                fontSize: 9,
                color: AppEditorial.inkMuted,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: AppEditorial.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DottedLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppEditorial.hairline
      ..strokeWidth = 1;
    const dotSize = 1.5;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, size.height / 2), dotSize / 2, paint);
      x += dotSize + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// §01 — Month readout (pump-LCD style)
// ─────────────────────────────────────────────────────────────────────────────

class _MonthReadout extends StatelessWidget {
  const _MonthReadout({
    required this.totalSpend,
    required this.totalLiters,
    required this.distanceKm,
    required this.refuelCount,
    required this.rupiah,
  });

  final num totalSpend;
  final num totalLiters;
  final num distanceKm;
  final int refuelCount;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final spendStr = rupiah.format(totalSpend).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pump-display number — rupiah
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: AppEditorial.ink,
            borderRadius:
                BorderRadius.circular(AppEditorial.rCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'TOTAL PENGELUARAN',
                    style: AppEditorial.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppEditorial.butter,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppEditorial.butter,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Rp',
                    style: AppEditorial.mono(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppEditorial.canvas
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        spendStr,
                        style: AppEditorial.mono(
                          fontSize: 48,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1,
                          color: AppEditorial.canvas,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 3-column stat grid
        Row(
          children: [
            Expanded(
              child: _StatCell(
                label: 'LITER',
                value: totalLiters <= 0
                    ? '—'
                    : totalLiters.toStringAsFixed(2),
                unit: 'L',
              ),
            ),
            Container(width: 1, height: 56, color: AppEditorial.hairline),
            Expanded(
              child: _StatCell(
                label: 'JARAK',
                value: distanceKm <= 0
                    ? '—'
                    : distanceKm.toStringAsFixed(0),
                unit: 'km',
              ),
            ),
            Container(width: 1, height: 56, color: AppEditorial.hairline),
            Expanded(
              child: _StatCell(
                label: 'ISI',
                value: refuelCount.toString(),
                unit: '×',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppEditorial.eyebrow(fontSize: 9.5)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppEditorial.mono(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: AppEditorial.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppEditorial.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §02 — Last refuel single line
// ─────────────────────────────────────────────────────────────────────────────

class _LastRefuelLine extends StatelessWidget {
  const _LastRefuelLine({
    required this.refuel,
    required this.rupiah,
    required this.date,
  });

  final Refuel refuel;
  final NumberFormat rupiah;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppEditorial.butter,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 44,
            color: AppEditorial.ink,
            margin: const EdgeInsets.only(right: 14),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${refuel.liters.toStringAsFixed(2)} L',
                      style: AppEditorial.mono(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('·',
                        style: AppEditorial.mono(
                            fontSize: 14, color: AppEditorial.ink)),
                    const SizedBox(width: 8),
                    Text(
                      'Rp ${rupiah.format(refuel.totalRp).trim()}',
                      style: AppEditorial.mono(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  date.format(refuel.refuelDate),
                  style: AppEditorial.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppEditorial.ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (refuel.isFullTank)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppEditorial.ink,
                borderRadius:
                    BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Text(
                'FULL',
                style: AppEditorial.mono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.canvas,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §03 — Prediction block
// ─────────────────────────────────────────────────────────────────────────────

class _FuelPredictionBlock extends StatelessWidget {
  const _FuelPredictionBlock({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository.ofDefaultClient();

    return FutureBuilder<(List<Refuel>, List<Trip>, List<EfficiencySample>)>(
      future: () async {
        final results = await Future.wait([
          repo.listRefuels(vehicleId: vehicle.id),
          repo.listTrips(vehicleId: vehicle.id),
          repo.recentEfficiencySamples(vehicleId: vehicle.id, limit: 20),
        ]);
        return (
          results[0] as List<Refuel>,
          results[1] as List<Trip>,
          results[2] as List<EfficiencySample>,
        );
      }(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snap.hasError || snap.data == null) {
          return const SizedBox.shrink();
        }

        final refuels = snap.data!.$1;
        final trips = snap.data!.$2;
        final samples = snap.data!.$3;

        // User preferences (used by both prior and daily-km estimate).
        final meta =
            Supabase.instance.client.auth.currentUser?.userMetadata;
        final usageProfile =
            UsageProfile.tryParse(meta?['usage_profile'] as String?);
        final primaryCity =
            PrimaryCity.tryParse(meta?['primary_city'] as String?);
        final weeklyKmPref = meta?['weekly_km'] is num
            ? meta!['weekly_km'] as num
            : null;

        // Posterior km/L (Bayesian-blended prior + measured samples).
        final estimate = PredictionService.posteriorKmPerLiter(
          vehicle: vehicle,
          samples: samples,
          primaryCity: primaryCity,
          usageProfile: usageProfile,
        );
        final kmPerLiter = estimate.kmPerLiter;

        // Daily-km estimate, with provenance label for the user.
        final dailyKm = PredictionService.dailyKmEstimate(
          recentTrips: trips,
          weeklyKmPref: weeklyKmPref,
          usageProfile: usageProfile,
        );
        final avgDailyKm = dailyKm.kmPerDay;

        // ── Tank-level estimation ───────────────────────────────────
        // If we have refuels, base "remaining" on the last refuel +
        // distance traveled since. If we have NO refuels at all yet,
        // we still want to render something usable using preferences
        // alone (the whole point of cold-start prior).
        final lastRefuel = refuels.isNotEmpty ? refuels.first : null;

        double remaining;
        double remainingPct;
        if (lastRefuel != null) {
          final kmSinceLast = trips
              .where((t) => t.startedAt.isAfter(lastRefuel.refuelDate))
              .fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
          final consumed = kmSinceLast / kmPerLiter;
          remaining = (lastRefuel.liters.toDouble() - consumed)
              .clamp(0.0, lastRefuel.liters.toDouble());
          remainingPct = (remaining /
                  (lastRefuel.liters == 0
                      ? 1.0
                      : lastRefuel.liters.toDouble()))
              .clamp(0.0, 1.0);
        } else {
          // No data yet — assume tank is roughly full. UI will show
          // PRIOR badge to indicate uncertainty.
          remaining = (vehicle.tankCapacityLiters?.toDouble() ?? 0) * 0.9;
          remainingPct = 0.9;
        }

        // ── Days left until refill ──────────────────────────────────
        double? daysLeft;
        DateTime? predictedDate;
        if (avgDailyKm > 0 && remaining > 0) {
          final dailyCons = avgDailyKm / kmPerLiter;
          if (dailyCons > 0) {
            daysLeft = remaining / dailyCons;
            predictedDate = DateTime.now()
                .add(Duration(hours: (daysLeft * 24).round()));
          }
        }

        final isWarning =
            remainingPct < 0.15 || (daysLeft != null && daysLeft < 2);
        final accent =
            isWarning ? AppEditorial.rust : AppEditorial.butterDeep;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            border:
                Border.all(color: AppEditorial.hairlineSoft, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big % readout + warning state
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (remainingPct * 100).toStringAsFixed(0),
                    style: AppEditorial.mono(
                      fontSize: 56,
                      fontWeight: FontWeight.w500,
                      color: accent,
                      letterSpacing: -2,
                      height: 0.95,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '%',
                      style: AppEditorial.mono(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isWarning ? 'HAMPIR HABIS' : 'NORMAL',
                          style: AppEditorial.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${remaining.toStringAsFixed(1)} L tersisa',
                          style: AppEditorial.mono(
                            fontSize: 11,
                            color: AppEditorial.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Confidence badge — tells the user how grounded the
              // prediction is in their actual data vs the prior.
              _ConfidenceBadge(
                source: estimate.source,
                sampleCount: estimate.sampleCount,
              ),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppEditorial.rPill),
                child: LinearProgressIndicator(
                  value: remainingPct,
                  minHeight: 6,
                  backgroundColor: AppEditorial.hairline,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 12),
              EditorialDataRow(
                label: 'Efisiensi',
                value: '${kmPerLiter.toStringAsFixed(1)} km/L',
              ),
              EditorialDataRow(
                label: 'Sisa hari',
                value: daysLeft != null
                    ? '~${daysLeft.toStringAsFixed(0)} hari'
                    : '—',
                valueStyle: AppEditorial.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isWarning
                      ? AppEditorial.rust
                      : AppEditorial.ink,
                  tabular: true,
                ),
              ),
              EditorialDataRow(
                label: 'Perkiraan isi ulang',
                value: predictedDate != null
                    ? DateFormat('d MMM yyyy', 'id_ID')
                        .format(predictedDate)
                    : '—',
                isLast: true,
              ),
              const SizedBox(height: 6),
              Text(
                'sumber jarak: ${dailyKm.source}',
                style: AppEditorial.sans(
                  fontSize: 10.5,
                  color: AppEditorial.inkMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small badge: "PRIOR · setup awal" / "MIXED · 3 ukuran" / "DATA-DRIVEN · 12 ukuran".
class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({
    required this.source,
    required this.sampleCount,
  });

  final String source;
  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    final color = switch (source) {
      'DATA-DRIVEN' => AppEditorial.sage,
      'MIXED' => AppEditorial.butterDeep,
      _ => AppEditorial.inkMuted,
    };
    final detail = sampleCount == 0
        ? 'belum ada ukuran'
        : '$sampleCount ukuran';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(AppEditorial.rTiny),
          ),
          child: Text(
            source,
            style: AppEditorial.mono(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          detail,
          style: AppEditorial.mono(
            fontSize: 10,
            color: AppEditorial.inkMuted,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §04 — Vehicle row (compact, with photo cover)
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppEditorial.rCard),
      child: Container(
        decoration: BoxDecoration(
          color: AppEditorial.cream,
          border: Border.all(
            color: isSelected
                ? AppEditorial.ink
                : AppEditorial.hairlineSoft,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppEditorial.rCard),
        ),
        child: Row(
          children: [
            // Cover thumbnail (square)
            Padding(
              padding: const EdgeInsets.all(6),
              child: VehicleCover(
                vehicle: vehicle,
                width: 80,
                height: 80,
                borderRadius: AppEditorial.rTiny,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      vehicle.type.label.toUpperCase(),
                      style: AppEditorial.eyebrow(
                          color: AppEditorial.butterDeep,
                          fontSize: 9.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.name,
                      style: AppEditorial.mono(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle.tankCapacityLiters == null
                          ? 'tanki belum diatur'
                          : 'tanki ${vehicle.tankCapacityLiters}L',
                      style: AppEditorial.sans(
                        fontSize: 11.5,
                        color: AppEditorial.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppEditorial.ink
                      : AppEditorial.canvas,
                  border: Border.all(
                    color: isSelected
                        ? AppEditorial.ink
                        : AppEditorial.hairline,
                    width: 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: AppEditorial.canvas)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §05 — Log row (newspaper logbook line)
// ─────────────────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.refuel,
    required this.rupiah,
    required this.date,
    required this.isLast,
  });

  final Refuel refuel;
  final NumberFormat rupiah;
  final DateFormat date;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dayStr = DateFormat('dd').format(refuel.refuelDate);
    final monthStr =
        DateFormat('MMM', 'id_ID').format(refuel.refuelDate).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : AppEditorial.hairline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date — stacked calendar style
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayStr,
                  style: AppEditorial.mono(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monthStr,
                  style: AppEditorial.eyebrow(
                    fontSize: 9,
                    color: AppEditorial.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Liter - rupiah
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rp ${rupiah.format(refuel.totalRp).trim()}',
                  style: AppEditorial.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${refuel.liters.toStringAsFixed(2)} L · ${rupiah.format(refuel.pricePerLiterSnapshot).trim()}/L',
                  style: AppEditorial.mono(
                    fontSize: 11,
                    color: AppEditorial.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (refuel.isFullTank)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppEditorial.butter,
                borderRadius:
                    BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Text(
                'FULL',
                style: AppEditorial.mono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error / Empty
// ─────────────────────────────────────────────────────────────────────────────

class _CenteredLoading extends StatelessWidget {
  const _CenteredLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(
          child: CircularProgressIndicator(color: AppEditorial.ink),
        ),
      ],
    );
  }
}

class _CenteredError extends StatelessWidget {
  const _CenteredError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 40),
        const EditorialEyebrow('ERROR'),
        const SizedBox(height: 10),
        Text(
          'Gagal memuat data.',
          style: AppEditorial.mono(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: AppEditorial.sans(
            fontSize: 13,
            color: AppEditorial.inkSoft,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CenteredEmpty extends StatelessWidget {
  const _CenteredEmpty({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 40),
        // Empty-state illustration
        AspectRatio(
          aspectRatio: 800 / 600,
          child: Image.asset(
            'assets/illustrations/empty_garasi.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        const EditorialEyebrow('PEMBUKAAN'),
        const SizedBox(height: 10),
        Text(
          title,
          style: AppEditorial.mono(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppEditorial.sans(
            fontSize: 13,
            color: AppEditorial.inkSoft,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
