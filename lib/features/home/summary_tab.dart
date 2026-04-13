import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

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

          return FutureBuilder<List<Refuel>>(
            future: _repo.listRefuels(vehicleId: _vehicleId),
            builder: (context, refuelsSnap) {
              if (refuelsSnap.hasError) {
                return _CenteredError(refuelsSnap.error.toString());
              }
              final refuels = refuelsSnap.data;
              if (refuels == null) {
                return const _CenteredLoading('Memuat ringkasan...');
              }

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

              final fullRefuels = refuels
                  .where((r) => r.isFullTank)
                  .toList()
                ..sort((a, b) => a.refuelDate.compareTo(b.refuelDate));

              num monthDistanceSum = 0;
              for (var i = 1; i < fullRefuels.length; i++) {
                final prev = fullRefuels[i - 1];
                final cur = fullRefuels[i];
                final prevOdo = prev.odometerKm;
                final curOdo = cur.odometerKm;
                if (prevOdo == null || curOdo == null) continue;

                final dist = curOdo - prevOdo;
                if (dist <= 0) continue;

                final inThisMonth = !cur.refuelDate.isBefore(monthStart) &&
                    cur.refuelDate.isBefore(nextMonth);
                if (inThisMonth) {
                  monthDistanceSum += dist;
                }
              }

              final recentRefuels = refuels.take(3).toList();
              final monthName = DateFormat('MMMM yyyy', 'id_ID').format(now);
              final lastRefuel = refuels.isNotEmpty ? refuels.first : null;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // ─── Header greeting ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.local_gas_station_rounded,
                            color: cs.onPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BensinKu',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              Text(
                                'Pantau pengeluaran BBM-mu',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onGoToProfile,
                          child: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: cs.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── Hero spending card ─────────────────────────────
                  _HeroSpendingCard(
                    totalSpend: totalSpend,
                    totalLiters: totalLiters,
                    monthDistanceSum: monthDistanceSum,
                    monthName: monthName,
                    rupiah: _rupiah,
                  ),
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
