import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../trip/trip_detail_page.dart';
import 'history_tab.dart';

enum _Range { week, month, year }

enum _View { grafik, riwayat }

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  _Range _range = _Range.week;
  _View _view = _View.grafik;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Segmented control: Grafik | Riwayat
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppEditorial.canvasSoft,
              borderRadius: BorderRadius.circular(AppEditorial.rPill),
            ),
            child: Row(
              children: [
                _ViewTab(
                  label: 'Grafik',
                  selected: _view == _View.grafik,
                  onTap: () => setState(() => _view = _View.grafik),
                ),
                _ViewTab(
                  label: 'Riwayat',
                  selected: _view == _View.riwayat,
                  onTap: () => setState(() => _view = _View.riwayat),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _view == _View.grafik
              ? _buildGrafik(context)
              : const HistoryTab(),
        ),
      ],
    );
  }

  Widget _buildGrafik(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppEditorial.ink,
      backgroundColor: AppEditorial.cream,
      child: FutureBuilder<(List<Refuel>, List<Trip>)>(
        future: () async {
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final results = await Future.wait([
            _repo.listRefuels(),
            _repo.listTrips(since: monthStart),
          ]);
          return (results[0] as List<Refuel>, results[1] as List<Trip>);
        }(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _Centered(text: snap.error.toString());
          }
          final data = snap.data;
          if (data == null) return const _GrafikSkeleton();

          final refuels = data.$1;
          final monthTrips = data.$2;

          final points = _buildSeries(refuels, _range);
          final total = points.fold<num>(0, (s, p) => s + p.value);

          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final nextMonth = now.month == 12
              ? DateTime(now.year + 1, 1, 1)
              : DateTime(now.year, now.month + 1, 1);

          final monthRefuels = refuels.where((r) =>
              !r.refuelDate.isBefore(monthStart) &&
              r.refuelDate.isBefore(nextMonth)).toList();
          final totalLiter =
              monthRefuels.fold<num>(0, (s, r) => s + r.liters);
          final avgPerRefuel = refuels.isEmpty
              ? 0
              : refuels.fold<num>(0, (s, r) => s + r.totalRp) /
                  refuels.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
            children: [
              // Total periode — kartu brand
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppEditorial.brand,
                  borderRadius: BorderRadius.circular(AppEditorial.rCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_rangeLabel(_range),
                        style: AppEditorial.sans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppEditorial.ink.withValues(alpha: 0.65),
                        )),
                    const SizedBox(height: 8),
                    EditorialReadout(
                      prefix: 'Rp ',
                      value: _rupiah.format(total).trim(),
                      fontSize: 38,
                      color: AppEditorial.ink,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppEditorial.cream,
                  borderRadius: BorderRadius.circular(AppEditorial.rCard),
                  boxShadow: AppEditorial.softShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Liter bulan ini',
                        value: '${totalLiter.toStringAsFixed(2)} L',
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 44,
                        color: AppEditorial.hairlineSoft),
                    Expanded(
                      child: _MiniStat(
                        label: 'Rata-rata / isi',
                        value:
                            'Rp ${_rupiah.format(avgPerRefuel).trim()}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              const EditorialSectionHeader(
                label: 'Grafik pengeluaran',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _RangeTab(
                    label: 'Minggu',
                    selected: _range == _Range.week,
                    onTap: () => setState(() => _range = _Range.week),
                  ),
                  const SizedBox(width: 8),
                  _RangeTab(
                    label: 'Bulan',
                    selected: _range == _Range.month,
                    onTap: () => setState(() => _range = _Range.month),
                  ),
                  const SizedBox(width: 8),
                  _RangeTab(
                    label: 'Tahun',
                    selected: _range == _Range.year,
                    onTap: () => setState(() => _range = _Range.year),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                decoration: BoxDecoration(
                  color: AppEditorial.cream,
                  borderRadius: BorderRadius.circular(AppEditorial.rCard),
                  boxShadow: AppEditorial.softShadow,
                ),
                child: _MiniBars(points: points, rupiah: _rupiah),
              ),
              const SizedBox(height: 28),

              const EditorialSectionHeader(
                label: 'Jarak tempuh bulan ini',
              ),
              const SizedBox(height: 14),
              _TripStats(trips: monthTrips),
              const SizedBox(height: 28),

              FutureBuilder<List<Trip>>(
                future: _repo.listTrips(),
                builder: (context, tripSnap) {
                  final trips = tripSnap.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EditorialSectionHeader(
                        label: 'Riwayat perjalanan',
                        trailing: Text('${trips.length} trip',
                            style: AppEditorial.sans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppEditorial.inkMuted,
                            )),
                      ),
                      const SizedBox(height: 12),
                      if (tripSnap.connectionState ==
                          ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppEditorial.ink),
                          ),
                        )
                      else if (trips.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: AppEditorial.cream,
                            borderRadius:
                                BorderRadius.circular(AppEditorial.rCard),
                            boxShadow: AppEditorial.softShadow,
                          ),
                          child: Center(
                            child: Text(
                              'Belum ada perjalanan terekam.',
                              style: AppEditorial.sans(
                                fontSize: 13,
                                color: AppEditorial.inkMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: AppEditorial.cream,
                            borderRadius:
                                BorderRadius.circular(AppEditorial.rCard),
                            boxShadow: AppEditorial.softShadow,
                          ),
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < trips.take(5).length;
                                  i++)
                                _TripRow(
                                  trip: trips[i],
                                  isLast: i == trips.take(5).length - 1,
                                  onChanged: () => setState(() {}),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _rangeLabel(_Range r) => switch (r) {
        _Range.week => '7 hari terakhir',
        _Range.month => '6 bulan terakhir',
        _Range.year => '5 tahun terakhir',
      };

  List<_Point> _buildSeries(List<Refuel> all, _Range range) {
    final now = DateTime.now();

    switch (range) {
      case _Range.week:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        final days = List.generate(
          7,
          (i) => DateTime(start.year, start.month, start.day + i),
        );
        final byDay = <String, num>{};
        for (final r in all) {
          final d = DateTime(
              r.refuelDate.year, r.refuelDate.month, r.refuelDate.day);
          if (d.isBefore(days.first) || d.isAfter(days.last)) continue;
          final key = '${d.year}-${d.month}-${d.day}';
          byDay[key] = (byDay[key] ?? 0) + r.totalRp;
        }
        final fmt = DateFormat('E', 'id_ID');
        return days.map((d) {
          final key = '${d.year}-${d.month}-${d.day}';
          return _Point(label: fmt.format(d), value: byDay[key] ?? 0);
        }).toList();
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
        return months.map((m) {
          final key = '${m.year}-${m.month}';
          return _Point(label: fmt.format(m), value: byMonth[key] ?? 0);
        }).toList();
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Point {
  const _Point({required this.label, required this.value});
  final String label;
  final num value;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppEditorial.sans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppEditorial.inkSoft,
              )),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppEditorial.heading(
              fontSize: 17,
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

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppEditorial.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(AppEditorial.rPill),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppEditorial.heading(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFFFFFFFF)
                  : AppEditorial.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppEditorial.brand : AppEditorial.canvasSoft,
            borderRadius: BorderRadius.circular(AppEditorial.rPill),
          ),
          child: Text(
            label,
            style: AppEditorial.sans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppEditorial.ink : AppEditorial.inkSoft,
            ),
          ),
        ),
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.value > 0)
                      Text(
                        p.value >= 1000000
                            ? '${(p.value / 1000000).toStringAsFixed(1)}jt'
                            : p.value >= 1000
                                ? '${(p.value / 1000).toStringAsFixed(0)}rb'
                                : p.value.toStringAsFixed(0),
                        style: AppEditorial.sans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: _barHeight(p.value, max),
                      decoration: BoxDecoration(
                        color: p.value <= 0
                            ? AppEditorial.hairline
                            : AppEditorial.brand,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.label,
                      style: AppEditorial.sans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppEditorial.inkMuted,
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
    if (max <= 0) return 6;
    if (value <= 0) return 6;
    final ratio = (value / max).toDouble().clamp(0.05, 1.0);
    return 130 * ratio;
  }
}

class _TripStats extends StatelessWidget {
  const _TripStats({required this.trips});
  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    final totalKm =
        trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
    final tripCount = trips.length;
    final avgKm = tripCount > 0 ? totalKm / tripCount : 0.0;
    final maxKm = trips.isEmpty
        ? 0.0
        : trips
            .map((t) => t.distanceKm ?? 0.0)
            .reduce((a, b) => a > b ? a : b);

    if (trips.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppEditorial.cream,
          borderRadius: BorderRadius.circular(AppEditorial.rCard),
          boxShadow: AppEditorial.softShadow,
        ),
        child: Center(
          child: Text(
            'Belum ada GPS trip bulan ini.',
            style: AppEditorial.sans(
                fontSize: 13, color: AppEditorial.inkMuted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                totalKm.toStringAsFixed(1),
                style: AppEditorial.heading(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'km',
                style: AppEditorial.heading(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppEditorial.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EditorialDataRow(
            label: 'Jumlah trip',
            value: '$tripCount trip',
          ),
          EditorialDataRow(
            label: 'Rata-rata / trip',
            value: '${avgKm.toStringAsFixed(1)} km',
          ),
          EditorialDataRow(
            label: 'Trip terpanjang',
            value: '${maxKm.toStringAsFixed(1)} km',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip, required this.isLast, this.onChanged});
  final Trip trip;
  final bool isLast;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM', 'id_ID');
    final timeFmt = DateFormat('HH:mm');

    final distText = trip.distanceKm != null
        ? '${trip.distanceKm!.toStringAsFixed(2)} km'
        : (trip.isActive ? 'aktif' : '—');

    final duration = trip.endedAt?.difference(trip.startedAt);
    final durText = duration != null ? '${duration.inMinutes} mnt' : '—';

    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
              builder: (_) => TripDetailPage(trip: trip)),
        );
        if (changed == true) onChanged?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : AppEditorial.hairlineSoft,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppEditorial.brandTint,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: const Icon(PhosphorIconsRegular.path,
                  size: 20, color: AppEditorial.brandDeep),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    distText,
                    style: AppEditorial.heading(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dateFmt.format(trip.startedAt)} · ${timeFmt.format(trip.startedAt)} · $durText',
                    style: AppEditorial.sans(
                      fontSize: 12,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight,
                size: 20, color: AppEditorial.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 200),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              text ?? '',
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading — tampilan grafik
// ─────────────────────────────────────────────────────────────────────────────

class _GrafikSkeleton extends StatelessWidget {
  const _GrafikSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
      children: [
        // Total periode — kartu brand
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppEditorial.brand,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton(width: 120, height: 12, baseColor: Color(0xFFE9B528)),
              SizedBox(height: 12),
              Skeleton(width: 200, height: 34, baseColor: Color(0xFFE9B528)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Row(
            children: const [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 90, height: 11),
                    SizedBox(height: 8),
                    Skeleton(width: 70, height: 18),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 90, height: 11),
                    SizedBox(height: 8),
                    Skeleton(width: 80, height: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Skeleton(width: 180, height: 18),
        const SizedBox(height: 14),
        Row(
          children: const [
            Skeleton(width: 72, height: 38, radius: AppEditorial.rPill),
            SizedBox(width: 8),
            Skeleton(width: 66, height: 38, radius: AppEditorial.rPill),
            SizedBox(width: 8),
            Skeleton(width: 66, height: 38, radius: AppEditorial.rPill),
          ],
        ),
        const SizedBox(height: 16),
        // Chart card — batang-batang
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final h in [70.0, 110.0, 50.0, 140.0, 90.0, 120.0, 60.0])
                  Skeleton(width: 22, height: h, radius: 6),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Skeleton(width: 200, height: 18),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Row(
            children: const [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 80, height: 11),
                    SizedBox(height: 8),
                    Skeleton(width: 100, height: 22),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 80, height: 11),
                    SizedBox(height: 8),
                    Skeleton(width: 100, height: 22),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
