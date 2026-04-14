import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

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
    symbol: 'Rp',
    decimalDigits: 0,
  );

  final _date = DateFormat('dd MMM yyyy', 'id_ID');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: cs.primary,
      backgroundColor: cs.surface,
      child: FutureBuilder<List<Vehicle>>(
        future: _repo.listVehicles(),
        builder: (context, vehiclesSnap) {
          if (vehiclesSnap.hasError) {
            return _CenteredError(vehiclesSnap.error.toString());
          }
          final vehicles = vehiclesSnap.data;
          if (vehicles == null) {
            return const _CenteredLoading('Memuat...');
          }

          if (vehicles.isEmpty) {
            return const _CenteredEmpty(
              title: 'Belum ada kendaraan',
              subtitle: 'Tambah kendaraan dulu di tab Profil.',
            );
          }

          _vehicleId ??= vehicles.first.id;

          return FutureBuilder<(List<Refuel>, List<Trip>)>(
            future: () async {
              final now = DateTime.now();
              final monthStart = DateTime(now.year, now.month, 1);
              final results = await Future.wait([
                _repo.listRefuels(vehicleId: _vehicleId),
                _repo.listTrips(
                  vehicleId: _vehicleId,
                  since: monthStart,
                ),
              ]);
              return (results[0] as List<Refuel>, results[1] as List<Trip>);
            }(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _CenteredError(snap.error.toString());
              }
              final data = snap.data;
              if (data == null) {
                return const _CenteredLoading('Memuat ringkasan...');
              }
              final refuels = data.$1;
              final monthTrips = data.$2;

              final now = DateTime.now();
              final monthStart = DateTime(now.year, now.month, 1);
              final nextMonth = now.month == 12
                  ? DateTime(now.year + 1, 1, 1)
                  : DateTime(now.year, now.month + 1, 1);

              final monthRefuels = refuels
                  .where(
                    (r) =>
                        !r.refuelDate.isBefore(monthStart) &&
                        r.refuelDate.isBefore(nextMonth),
                  )
                  .toList();

              final totalSpend = monthRefuels.fold<num>(
                0,
                (sum, r) => sum + r.totalRp,
              );
              final totalLiters = monthRefuels.fold<num>(
                0,
                (sum, r) => sum + r.liters,
              );

              // GPS trip distance this month (primary)
              final tripDistanceKm = monthTrips.fold<double>(
                0,
                (sum, t) => sum + (t.distanceKm ?? 0),
              );

              // Odometer-based distance (fallback)
              final fullRefuels = refuels
                  .where((r) => r.isFullTank)
                  .toList()
                ..sort((a, b) => a.refuelDate.compareTo(b.refuelDate));

              num odomDistanceSum = 0;
              for (var i = 1; i < fullRefuels.length; i++) {
                final prev = fullRefuels[i - 1];
                final cur = fullRefuels[i];
                final prevOdo = prev.odometerKm;
                final curOdo = cur.odometerKm;
                if (prevOdo == null || curOdo == null) continue;
                final dist = curOdo - prevOdo;
                if (dist <= 0) continue; // abaikan jika odometer salah/mundur
                final inThisMonth = !cur.refuelDate.isBefore(monthStart) &&
                    cur.refuelDate.isBefore(nextMonth);
                if (inThisMonth) odomDistanceSum += dist;
              }

              // Prioritas GPS; fallback odometer jika belum ada trip
              final monthDistanceSum =
                  tripDistanceKm > 0 ? tripDistanceKm : odomDistanceSum;

              final recentRefuels = refuels.take(3).toList();
              final monthName = DateFormat('MMMM yyyy', 'id_ID').format(now);
              final lastRefuel = refuels.isNotEmpty ? refuels.first : null;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [

                  // ─── Hero spending card ─────────────────────────────
                  _HeroSpendingCard(
                    totalSpend: totalSpend,
                    totalLiters: totalLiters,
                    monthDistanceSum: monthDistanceSum,
                    monthName: monthName,
                    rupiah: _rupiah,
                  ),
                  const SizedBox(height: 14),

                  // ─── Fuel prediction card ───────────────────────────
                  _FuelPredictionCard(vehicleId: _vehicleId!),
                  const SizedBox(height: 14),

                  // ─── Vehicle picker (2 kolom sejajar) ──────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kendaraan',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0;
                              i < vehicles.take(2).length;
                              i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _VehicleCard(
                                vehicle: vehicles[i],
                                isSelected: vehicles[i].id == _vehicleId,
                                onTap: () => setState(
                                  () => _vehicleId = vehicles[i].id,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── Quick stats row ────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _QuickStatCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'Isi Bulan Ini',
                          value: '${monthRefuels.length}x',
                          color: cs.primaryContainer,
                          iconColor: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickStatCard(
                          icon: Icons.speed_rounded,
                          label: 'Jarak Tempuh',
                          value: monthDistanceSum <= 0
                              ? '—'
                              : '${monthDistanceSum.toStringAsFixed(0)} km',
                          color: cs.secondaryContainer,
                          iconColor: cs.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Pengisian Terakhir section ─────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pengisian Terakhir',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (recentRefuels.isNotEmpty)
                        TextButton(
                          onPressed: widget.onGoToHistory,
                          style: TextButton.styleFrom(
                            foregroundColor: cs.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          child: const Text(
                            'Lihat semua',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (recentRefuels.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.local_gas_station_outlined,
                              color: cs.onSurfaceVariant, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada riwayat pengisian',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Summary card pengisian terakhir (dengan statistik)
                    if (lastRefuel != null)
                      _LastRefuelSummaryCard(
                        refuel: lastRefuel,
                        rupiah: _rupiah,
                        date: _date,
                      ),
                    const SizedBox(height: 8),
                    // List item pengisian terakhir
                    ...recentRefuels.map(
                      (r) => _RecentRefuelItem(
                        refuel: r,
                        rupiah: _rupiah,
                        date: _date,
                      ),
                    ),
                  ],

                  const SizedBox(height: 90),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Hero Card
// ──────────────────────────────────────────────────────────────────────────────

class _HeroSpendingCard extends StatelessWidget {
  const _HeroSpendingCard({
    required this.totalSpend,
    required this.totalLiters,
    required this.monthDistanceSum,
    required this.monthName,
    required this.rupiah,
  });

  final num totalSpend;
  final num totalLiters;
  final num monthDistanceSum;
  final String monthName;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.secondary,
            const Color(0xFF2A7A65),
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.08,
              child: SvgPicture.asset(
                'assets/illustrations/fuel_hero.svg',
                width: 140,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      monthName,
                      style: TextStyle(
                        color: cs.onPrimary.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: cs.onPrimary.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Total Pengeluaran',
                style: TextStyle(
                  color: cs.onPrimary.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rupiah.format(totalSpend),
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeroStat(
                    label: 'Total Liter',
                    value: totalLiters <= 0
                        ? '—'
                        : '${totalLiters.toStringAsFixed(2)} L',
                    cs: cs,
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  _HeroStat(
                    label: 'Jarak Tempuh',
                    value: monthDistanceSum <= 0
                        ? '—'
                        : '${monthDistanceSum.toStringAsFixed(0)} km',
                    cs: cs,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.cs,
  });

  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onPrimary.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: cs.onPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Vehicle card (single item, used in 2-column row)
// ──────────────────────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMotor = vehicle.type == VehicleType.motor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.14)
                    : isMotor
                        ? cs.primaryContainer
                        : cs.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isMotor
                    ? Icons.two_wheeler_rounded
                    : Icons.directions_car_filled_rounded,
                size: 17,
                color: isSelected
                    ? cs.primary
                    : (isMotor ? cs.primary : cs.secondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    vehicle.type.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 14),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Quick stat card
// ──────────────────────────────────────────────────────────────────────────────

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: iconColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Last refuel summary card (clock icon + Tanggal/Nominal/Liter stats)
// ──────────────────────────────────────────────────────────────────────────────

class _LastRefuelSummaryCard extends StatelessWidget {
  const _LastRefuelSummaryCard({
    required this.refuel,
    required this.rupiah,
    required this.date,
  });

  final Refuel refuel;
  final NumberFormat rupiah;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: cs.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Pengisian Terakhir',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStatItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Tanggal',
                    value: date.format(refuel.refuelDate),
                    iconColor: cs.primary,
                  ),
                ),
                VerticalDivider(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                  thickness: 1,
                ),
                Expanded(
                  child: _SummaryStatItem(
                    icon: Icons.payments_rounded,
                    label: 'Nominal',
                    value: rupiah.format(refuel.totalRp),
                    iconColor: cs.secondary,
                  ),
                ),
                VerticalDivider(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                  thickness: 1,
                ),
                Expanded(
                  child: _SummaryStatItem(
                    icon: Icons.water_drop_rounded,
                    label: 'Liter',
                    value: '${refuel.liters.toStringAsFixed(2)} L',
                    iconColor: cs.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatItem extends StatelessWidget {
  const _SummaryStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Recent refuel item
// ──────────────────────────────────────────────────────────────────────────────

class _RecentRefuelItem extends StatelessWidget {
  const _RecentRefuelItem({
    required this.refuel,
    required this.rupiah,
    required this.date,
  });

  final Refuel refuel;
  final NumberFormat rupiah;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: refuel.isFullTank
                  ? cs.primaryContainer
                  : cs.secondaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              refuel.isFullTank
                  ? Icons.local_gas_station_rounded
                  : Icons.local_gas_station_outlined,
              color: refuel.isFullTank ? cs.primary : cs.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rupiah.format(refuel.totalRp),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  date.format(refuel.refuelDate),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${refuel.liters.toStringAsFixed(2)} L',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
              ),
              if (refuel.isFullTank) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Full',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Loading / Error / Empty states
// ──────────────────────────────────────────────────────────────────────────────

class _CenteredLoading extends StatelessWidget {
  const _CenteredLoading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: cs.primary),
              const SizedBox(height: 12),
              Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
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
      padding: const EdgeInsets.all(16),
      children: [
        _CenteredEmpty(title: 'Terjadi Kesalahan', subtitle: message),
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: cs.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fuel Prediction Card
// ─────────────────────────────────────────────────────────────────────────────

class _FuelPredictionCard extends StatelessWidget {
  const _FuelPredictionCard({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository.ofDefaultClient();
    final cs = Theme.of(context).colorScheme;

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
        if (snap.hasError || snap.data == null) return const SizedBox.shrink();

        final refuels = snap.data!.$1;
        final trips = snap.data!.$2;

        // Butuh minimal 1 refuel untuk tampilkan card
        if (refuels.isEmpty) return const SizedBox.shrink();

        final meta = Supabase.instance.client.auth.currentUser?.userMetadata;

        // ── 1. Efisiensi km/L ──────────────────────────────────────────
        // Gunakan data historis seluruhnya; jika belum ada GPS trip, km/L = null
        final totalTripKm =
            trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
        final totalLiters =
            refuels.fold<double>(0, (s, r) => s + r.liters);
        final kmPerLiter =
            (totalTripKm > 0 && totalLiters > 0)
                ? totalTripKm / totalLiters
                : null;

        // ── 2. Sisa bensin estimasi ────────────────────────────────────
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
          // Tidak ada GPS data → perkirakan full tank jika isi penuh, 50% jika tidak
          remainingPct = lastRefuel.isFullTank ? 1.0 : 0.5;
          remaining = lastRefuel.liters.toDouble() * remainingPct;
        }

        // ── 3. avgDailyKm: multi-window fallback ──────────────────────
        //
        // Priority:
        //   A. GPS 30 hari terakhir (data aktual terbaik)
        //   B. GPS 90 hari terakhir
        //   C. GPS all-time / jumlah hari sejak pertama trip
        //   D. Preferences weekly_km / 7
        //   E. Tidak bisa prediksi hari (null)
        //
        // Jika GPS dan preferences keduanya ada → weighted blend:
        //   GPS confidence makin tinggi seiring data bertambah.

        double? avgDailyKm;
        String? dailyKmSource; // untuk tampilan confidence

        if (trips.isNotEmpty) {
          // A. 30-day window
          final d30ago = DateTime.now().subtract(const Duration(days: 30));
          final km30 = trips
              .where((t) => t.startedAt.isAfter(d30ago))
              .fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
          if (km30 > 0) {
            avgDailyKm = km30 / 30;
            dailyKmSource = '30 hari';
          }

          // B. 90-day window (jika 30 hari kosong)
          if (avgDailyKm == null || avgDailyKm <= 0) {
            final d90ago = DateTime.now().subtract(const Duration(days: 90));
            final km90 = trips
                .where((t) => t.startedAt.isAfter(d90ago))
                .fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
            if (km90 > 0) {
              avgDailyKm = km90 / 90;
              dailyKmSource = '90 hari';
            }
          }

          // C. All-time GPS / days since first trip
          if (avgDailyKm == null || avgDailyKm <= 0) {
            final oldest = trips.last.startedAt;
            final daySpan =
                DateTime.now().difference(oldest).inDays.toDouble();
            if (totalTripKm > 0 && daySpan > 0) {
              avgDailyKm = totalTripKm / daySpan.clamp(1, 9999);
              dailyKmSource = 'semua data';
            }
          }
        }

        // D. Preferences fallback (jika GPS belum cukup)
        final prefWeeklyKm = meta?['weekly_km'];
        if (prefWeeklyKm is num && prefWeeklyKm > 0) {
          final prefDaily = prefWeeklyKm / 7;
          if (avgDailyKm == null || avgDailyKm <= 0) {
            // Tidak ada GPS sama sekali → pakai preferences murni
            avgDailyKm = prefDaily.toDouble();
            dailyKmSource = 'preferensi';
          } else {
            // GPS ada → blend: semakin banyak data GPS, bobot GPS makin besar
            // Jumlah trips sebagai proxy kualitas GPS data (max blend di 20 trips)
            final gpsWeight = (trips.length / 20).clamp(0.2, 0.9);
            avgDailyKm =
                (avgDailyKm * gpsWeight) + (prefDaily * (1 - gpsWeight));
            dailyKmSource = trips.length >= 10 ? 'GPS' : 'GPS+preferensi';
          }
        }

        // ── 4. Prediksi hari & tanggal isi ulang ──────────────────────
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

        // ── 5. Tentukan state warning ──────────────────────────────────
        // Warning hanya jika bisa kalkulasi (jangan false alarm jika data kosong)
        final hasGoodData = kmPerLiter != null && avgDailyKm != null;
        final isWarning = hasGoodData &&
            (remainingPct < 0.15 || (daysLeft != null && daysLeft < 2));
        final isDataLimited = kmPerLiter == null || avgDailyKm == null;

        return _PredictionCardUI(
          cs: cs,
          remainingLiters: remaining,
          remainingPct: remainingPct,
          kmPerLiter: kmPerLiter,
          daysUntilEmpty: daysLeft,
          predictedDate: predictedDate,
          isWarning: isWarning,
          isDataLimited: isDataLimited,
          dailyKmSource: dailyKmSource,
        );
      },
    );
  }
}

class _PredictionCardUI extends StatelessWidget {
  const _PredictionCardUI({
    required this.cs,
    required this.remainingLiters,
    required this.remainingPct,
    this.kmPerLiter,
    this.daysUntilEmpty,
    this.predictedDate,
    required this.isWarning,
    this.isDataLimited = false,
    this.dailyKmSource,
  });

  final ColorScheme cs;
  final double remainingLiters;
  final double remainingPct;
  final double? kmPerLiter;
  final double? daysUntilEmpty;
  final DateTime? predictedDate;
  final bool isWarning;
  final bool isDataLimited;
  final String? dailyKmSource;

  void _showDisclaimer(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: cs.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Tentang Prediksi Ini'),
          ],
        ),
        content: Text(
          'Estimasi ini dihitung dari beberapa sumber data secara bertahap:\n\n'
          '⛽ Efisiensi (km/L) = total jarak GPS ÷ total liter isi bensin.\n\n'
          '📅 Rata-rata km/hari dihitung dari:\n'
          '   1. GPS 30 hari terakhir (prioritas)\n'
          '   2. GPS 90 hari terakhir\n'
          '   3. Seluruh riwayat GPS\n'
          '   4. Preferensi awal (input manual)\n\n'
          'Jika tersedia keduanya, data GPS dan preferensi digabung '
          'dengan bobot: semakin banyak data GPS, semakin akurat.\n\n'
          '⚠️ Akurasi meningkat seiring bertambahnya trip dan isi bensin. '
          'Kondisi jalan & gaya berkendara memengaruhi hasilnya.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warningColor =
        isWarning ? const Color(0xFFE53935) : cs.primary;
    final bgColor = isWarning
        ? const Color(0xFFFFF3F3)
        : Colors.white.withValues(alpha: 0.92);
    final dateStr = predictedDate != null
        ? DateFormat('d MMM yyyy', 'id_ID').format(predictedDate!)
        : '–';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isWarning
              ? warningColor.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.4),
          width: isWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: warningColor.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: isWarning
                        ? warningColor.withValues(alpha: 0.1)
                        : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isWarning
                        ? Icons.warning_amber_rounded
                        : Icons.local_gas_station_rounded,
                    color: warningColor,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isWarning
                            ? '⚠️ Bensin Hampir Habis'
                            : 'Prediksi Bensin',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: warningColor,
                            ),
                      ),
                      if (isDataLimited)
                        Row(
                          children: [
                            Icon(Icons.bar_chart_rounded,
                                size: 11,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.6)),
                            const SizedBox(width: 3),
                            Text(
                              'Data terbatas — akurasi meningkat seiring waktu',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        )
                      else if (dailyKmSource != null)
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 11,
                                color: cs.primary.withValues(alpha: 0.6)),
                            const SizedBox(width: 3),
                            Text(
                              'Berdasarkan $dailyKmSource',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Disclaimer button
                GestureDetector(
                  onTap: () => _showDisclaimer(context),
                  child: Container(
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest
                          .withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimasi sisa bensin',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(remainingPct * 100).toStringAsFixed(0)}%  •  ${remainingLiters.toStringAsFixed(1)} L',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: remainingPct,
                    minHeight: 10,
                    backgroundColor: cs.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(warningColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                _PredStat(
                  label: 'Efisiensi',
                  value: kmPerLiter != null
                      ? '${kmPerLiter!.toStringAsFixed(1)} km/L'
                      : '–',
                  icon: Icons.speed_rounded,
                  cs: cs,
                ),
                const SizedBox(width: 8),
                _PredStat(
                  label: 'Sisa hari',
                  value: daysUntilEmpty != null
                      ? '~${daysUntilEmpty!.toStringAsFixed(0)} hari'
                      : '–',
                  icon: Icons.hourglass_bottom_rounded,
                  cs: cs,
                  highlight: isWarning,
                ),
                const SizedBox(width: 8),
                _PredStat(
                  label: 'Isi lagi',
                  value: dateStr,
                  icon: Icons.event_rounded,
                  cs: cs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PredStat extends StatelessWidget {
  const _PredStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.cs,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFE53935).withValues(alpha: 0.07)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: highlight
              ? Border.all(
                  color:
                      const Color(0xFFE53935).withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 14,
                color: highlight
                    ? const Color(0xFFE53935)
                    : cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: highlight
                    ? const Color(0xFFE53935)
                    : cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
