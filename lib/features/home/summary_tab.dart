import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
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

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
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
                  _FuelPredictionBlock(vehicleId: _vehicleId!),
                  const SizedBox(height: 28),

                  // §04 — Garasi
                  EditorialSectionHeader(
                    index: '04',
                    label: 'GARASI',
                    trailing: Text(
                      '${vehicles.length} UNIT',
                      style: AppEditorial.eyebrow(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...vehicles.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _VehicleRow(
                          vehicle: v,
                          isSelected: v.id == _vehicleId,
                          onTap: () =>
                              setState(() => _vehicleId = v.id),
                        ),
                      )),
                  const SizedBox(height: 18),

                  // §05 — Riwayat
                  EditorialSectionHeader(
                    index: '05',
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
  const _FuelPredictionBlock({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository.ofDefaultClient();

    return FutureBuilder<(List<Refuel>, List<Trip>)>(
      future: () async {
        final results = await Future.wait([
          repo.listRefuels(vehicleId: vehicleId),
          repo.listTrips(vehicleId: vehicleId),
        ]);
        return (results[0] as List<Refuel>, results[1] as List<Trip>);
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
        if (refuels.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'belum cukup data untuk memprediksi.',
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
          );
        }

        final meta =
            Supabase.instance.client.auth.currentUser?.userMetadata;

        final totalTripKm =
            trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
        final totalLiters =
            refuels.fold<double>(0, (s, r) => s + r.liters);
        final kmPerLiter = (totalTripKm > 0 && totalLiters > 0)
            ? totalTripKm / totalLiters
            : null;

        final lastRefuel = refuels.first;
        final kmSinceLast = trips
            .where((t) => t.startedAt.isAfter(lastRefuel.refuelDate))
            .fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));

        double remaining = 0;
        double remainingPct = 0;
        if (kmPerLiter != null) {
          final consumed = kmSinceLast / kmPerLiter;
          remaining = (lastRefuel.liters.toDouble() - consumed)
              .clamp(0.0, lastRefuel.liters.toDouble());
          remainingPct =
              (remaining / lastRefuel.liters.toDouble()).clamp(0.0, 1.0);
        } else {
          remainingPct = lastRefuel.isFullTank ? 1.0 : 0.5;
          remaining = lastRefuel.liters.toDouble() * remainingPct;
        }

        double? avgDailyKm;
        String? dailyKmSource;
        if (trips.isNotEmpty) {
          final d30ago = DateTime.now().subtract(const Duration(days: 30));
          final km30 = trips
              .where((t) => t.startedAt.isAfter(d30ago))
              .fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
          if (km30 > 0) {
            avgDailyKm = km30 / 30;
            dailyKmSource = '30 hari';
          }
        }
        final prefWeeklyKm = meta?['weekly_km'];
        if (prefWeeklyKm is num &&
            prefWeeklyKm > 0 &&
            avgDailyKm == null) {
          avgDailyKm = prefWeeklyKm / 7;
          dailyKmSource = 'preferensi';
        }

        double? daysLeft;
        DateTime? predictedDate;
        if (kmPerLiter != null && avgDailyKm != null && avgDailyKm > 0) {
          final dailyCons = avgDailyKm / kmPerLiter;
          if (dailyCons > 0 && remaining > 0) {
            daysLeft = remaining / dailyCons;
            predictedDate = DateTime.now()
                .add(Duration(hours: (daysLeft * 24).round()));
          }
        }

        final hasData = kmPerLiter != null && avgDailyKm != null;
        final isWarning = hasData &&
            (remainingPct < 0.15 || (daysLeft != null && daysLeft < 2));
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
                value: kmPerLiter != null
                    ? '${kmPerLiter.toStringAsFixed(1)} km/L'
                    : '—',
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
              if (dailyKmSource != null) ...[
                const SizedBox(height: 6),
                Text(
                  'sumber data: $dailyKmSource',
                  style: AppEditorial.sans(
                    fontSize: 10.5,
                    color: AppEditorial.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
        const SizedBox(height: 60),
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
