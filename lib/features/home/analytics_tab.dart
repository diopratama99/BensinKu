import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

enum _Range { week, month, year }

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  _Range _range = _Range.week;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: cs.primary,
      backgroundColor: cs.surface,
      child: FutureBuilder<List<Refuel>>(
        future: _repo.listRefuels(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _Centered(text: snap.error.toString());
          }
          final refuels = snap.data;
          if (refuels == null) {
            return const _Centered(loading: true);
          }

          final points = _buildSeries(refuels, _range);
          final total = points.fold<num>(0, (s, p) => s + p.value);
          final totalLiter = refuels.fold<num>(0, (s, r) {
            final now = DateTime.now();
            final monthStart = DateTime(now.year, now.month, 1);
            final nextMonth = now.month == 12
                ? DateTime(now.year + 1, 1, 1)
                : DateTime(now.year, now.month + 1, 1);
            if (!r.refuelDate.isBefore(monthStart) &&
                r.refuelDate.isBefore(nextMonth)) {
              return s + r.liters;
            }
            return s;
          });
          final avgPerRefuel = refuels.isEmpty
              ? 0
              : refuels.fold<num>(0, (s, r) => s + r.totalRp) /
                  refuels.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // ─── Header ─────────────────────────────────────────────
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
                            color: cs.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
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
                            'Statistik',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Analisis pengeluaran BBM-mu',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Total spend hero ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.secondary],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pengeluaran',
                            style: TextStyle(
                              color: cs.onPrimary.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _rupiah.format(total),
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.query_stats_rounded,
                        color: cs.onPrimary,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ─── Micro stats row ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _MiniStatBox(
                      label: 'Liter Bulan Ini',
                      value: '${totalLiter.toStringAsFixed(2)} L',
                      icon: Icons.water_drop_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatBox(
                      label: 'Rata-rata/Isi',
                      value: _rupiah.format(avgPerRefuel),
                      icon: Icons.calculate_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ─── Range selector ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    _RangeTab(
                      label: 'Minggu',
                      selected: _range == _Range.week,
                      onTap: () => setState(() => _range = _Range.week),
                    ),
                    _RangeTab(
                      label: 'Bulan',
                      selected: _range == _Range.month,
                      onTap: () => setState(() => _range = _Range.month),
                    ),
                    _RangeTab(
                      label: 'Tahun',
                      selected: _range == _Range.year,
                      onTap: () => setState(() => _range = _Range.year),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── Chart card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Grafik Pengeluaran',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Container(
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Rp',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _MiniBars(points: points, rupiah: _rupiah),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── Riwayat Perjalanan ──────────────────────────────────
              FutureBuilder<List<Trip>>(
                future: _repo.listTrips(),
                builder: (context, tripSnap) {
                  final trips = tripSnap.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Riwayat Perjalanan',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (trips.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${trips.length} trip',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (tripSnap.connectionState ==
                          ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (trips.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined,
                                  color: cs.onSurfaceVariant, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'Belum ada riwayat perjalanan',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      else
                        ...trips.take(5).map((t) => _TripItem(trip: t)),
                    ],
                  );
                },
              ),

              const SizedBox(height: 90),
            ],
          );
        },
      ),
    );
  }

  List<_Point> _buildSeries(List<Refuel> all, _Range range) {
    final now = DateTime.now();

    switch (range) {
      case _Range.week:
        final start =
            DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final days = List.generate(
          7,
          (i) => DateTime(start.year, start.month, start.day + i),
        );
        final byDay = <String, num>{};
        for (final r in all) {
          final d = DateTime(r.refuelDate.year, r.refuelDate.month, r.refuelDate.day);
          if (d.isBefore(days.first) || d.isAfter(days.last)) continue;
          final key = '${d.year}-${d.month}-${d.day}';
          byDay[key] = (byDay[key] ?? 0) + r.totalRp;
        }
        final fmt = DateFormat('E', 'id_ID');
        return days
            .map((d) {
              final key = '${d.year}-${d.month}-${d.day}';
              return _Point(label: fmt.format(d), value: byDay[key] ?? 0);
            })
            .toList();

      case _Range.month:
        final months = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - (5 - i), 1);
          return DateTime(m.year, m.month, 1);
        });
        final byMonth = <String, num>{};
        for (final r in all) {
          final m = DateTime(r.refuelDate.year, r.refuelDate.month, 1);
          final key = '${m.year}-${m.month}';
          byMonth[key] = (byMonth[key] ?? 0) + r.totalRp;
        }
        final fmt = DateFormat('MMM', 'id_ID');
        return months
            .map((m) {
              final key = '${m.year}-${m.month}';
              return _Point(label: fmt.format(m), value: byMonth[key] ?? 0);
            })
            .toList();

      case _Range.year:
        final years = List.generate(5, (i) => now.year - (4 - i));
        final byYear = <int, num>{};
        for (final r in all) {
          byYear[r.refuelDate.year] =
              (byYear[r.refuelDate.year] ?? 0) + r.totalRp;
        }
        return years
            .map((y) => _Point(label: y.toString(), value: byYear[y] ?? 0))
            .toList();
    }
  }
}

class _Point {
  const _Point({required this.label, required this.value});

  final String label;
  final num value;
}

class _RangeTab extends StatelessWidget {
  const _RangeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary, size: 18),
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
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.points, required this.rupiah});

  final List<_Point> points;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = points.isEmpty
        ? 0
        : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.value > 0)
                      Text(
                        p.value >= 1000000
                            ? '${(p.value / 1000000).toStringAsFixed(1)}M'
                            : p.value >= 1000
                                ? '${(p.value / 1000).toStringAsFixed(0)}K'
                                : p.value.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: _barHeight(p.value, max),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: p.value <= 0
                              ? [
                                  cs.surfaceContainerHighest,
                                  cs.surfaceContainerHighest,
                                ]
                              : [
                                  cs.primary.withValues(alpha: 0.9),
                                  cs.secondary,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _barHeight(num value, num max) {
    if (max <= 0) return 12;
    if (value <= 0) return 12;
    final ratio = (value / max).toDouble().clamp(0.05, 1.0);
    return 130 * ratio;
  }
}

class _Centered extends StatelessWidget {
  const _Centered({this.text, this.loading = false});

  final String? text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Center(
          child: loading
              ? CircularProgressIndicator(color: cs.primary)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    text ?? '',
                    style:
                        TextStyle(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip list item
// ─────────────────────────────────────────────────────────────────────────────

class _TripItem extends StatelessWidget {
  const _TripItem({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    final distText = trip.distanceKm != null
        ? '${trip.distanceKm!.toStringAsFixed(2)} km'
        : trip.isActive
            ? 'Sedang berjalan'
            : '—';

    final duration =
        trip.endedAt?.difference(trip.startedAt);

    final durText = duration != null
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : '—';

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
              color: trip.isActive
                  ? cs.tertiaryContainer
                  : cs.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              trip.isActive
                  ? Icons.directions_car_rounded
                  : Icons.map_rounded,
              color: trip.isActive ? cs.tertiary : cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFmt.format(trip.startedAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 3),
                Text(
                  distText,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                durText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              if (trip.isActive) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: cs.tertiary,
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
