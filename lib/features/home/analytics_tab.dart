import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../trip/trip_detail_page.dart';

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
    symbol: '',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppEditorial.ink,
      backgroundColor: AppEditorial.canvas,
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
          if (data == null) return const _Centered(loading: true);

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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 80),
            children: [
              // §01 Total
              const EditorialSectionHeader(
                index: '01',
                label: 'TOTAL PERIODE',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: AppEditorial.butter,
                  borderRadius:
                      BorderRadius.circular(AppEditorial.rCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_rangeLabel(_range),
                        style: AppEditorial.eyebrow()),
                    const SizedBox(height: 6),
                    EditorialReadout(
                      prefix: 'Rp ',
                      value: _rupiah.format(total).trim(),
                      fontSize: 38,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'LITER BULAN',
                      value: '${totalLiter.toStringAsFixed(2)} L',
                    ),
                  ),
                  Container(
                      width: 1, height: 56, color: AppEditorial.hairline),
                  Expanded(
                    child: _MiniStat(
                      label: 'RATA-RATA / ISI',
                      value: 'Rp ${_rupiah.format(avgPerRefuel).trim()}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // §02 Range tabs + chart
              const EditorialSectionHeader(
                index: '02',
                label: 'GRAFIK PENGELUARAN',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _RangeTab(
                    label: 'MINGGU',
                    selected: _range == _Range.week,
                    onTap: () => setState(() => _range = _Range.week),
                  ),
                  const SizedBox(width: 6),
                  _RangeTab(
                    label: 'BULAN',
                    selected: _range == _Range.month,
                    onTap: () => setState(() => _range = _Range.month),
                  ),
                  const SizedBox(width: 6),
                  _RangeTab(
                    label: 'TAHUN',
                    selected: _range == _Range.year,
                    onTap: () => setState(() => _range = _Range.year),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppEditorial.cream,
                  border:
                      Border.all(color: AppEditorial.hairlineSoft, width: 1),
                  borderRadius:
                      BorderRadius.circular(AppEditorial.rCard),
                ),
                child: _MiniBars(points: points, rupiah: _rupiah),
              ),
              const SizedBox(height: 28),

              // §03 Jarak tempuh GPS
              const EditorialSectionHeader(
                index: '03',
                label: 'JARAK TEMPUH (BULAN INI)',
              ),
              const SizedBox(height: 14),
              _TripStats(trips: monthTrips),
              const SizedBox(height: 28),

              // §04 Riwayat trip
              FutureBuilder<List<Trip>>(
                future: _repo.listTrips(),
                builder: (context, tripSnap) {
                  final trips = tripSnap.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EditorialSectionHeader(
                        index: '04',
                        label: 'RIWAYAT PERJALANAN',
                        trailing: Text('${trips.length} TRIP',
                            style: AppEditorial.eyebrow()),
                      ),
                      const SizedBox(height: 8),
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
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'belum ada perjalanan terekam.',
                            style: AppEditorial.sans(
                              fontSize: 13,
                              color: AppEditorial.inkSoft,
                            ),
                          ),
                        )
                      else
                        ...trips.take(5).toList().asMap().entries.map(
                              (e) => _TripRow(
                                trip: e.value,
                                isLast: e.key == trips.take(5).length - 1,
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
        _Range.week => '7 HARI TERAKHIR',
        _Range.month => '6 BULAN TERAKHIR',
        _Range.year => '5 TAHUN TERAKHIR',
      };

  List<_Point> _buildSeries(List<Refuel> all, _Range range) {
    final now = DateTime.now();

    switch (range) {
      case _Range.week:
        final start =
            DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 6));
        final days = List.generate(
          7,
          (i) => DateTime(start.year, start.month, start.day + i),
        );
        final byDay = <String, num>{};
        for (final r in all) {
          final d = DateTime(r.refuelDate.year, r.refuelDate.month,
              r.refuelDate.day);
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppEditorial.eyebrow(fontSize: 9.5)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppEditorial.mono(
              fontSize: 16,
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppEditorial.ink : AppEditorial.canvas,
            border: Border.all(color: AppEditorial.ink, width: 1),
            borderRadius: BorderRadius.circular(AppEditorial.rTiny),
          ),
          child: Text(
            label,
            style: AppEditorial.mono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  selected ? AppEditorial.canvas : AppEditorial.ink,
              letterSpacing: 0.6,
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
                        style: AppEditorial.mono(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppEditorial.ink,
                        ),
                      ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: _barHeight(p.value, max),
                      decoration: BoxDecoration(
                        color: p.value <= 0
                            ? AppEditorial.hairline
                            : AppEditorial.butter,
                      ),
                    ),
                    Container(
                      height: 1,
                      color: AppEditorial.ink,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p.label,
                      style: AppEditorial.mono(
                        fontSize: 9.5,
                        color: AppEditorial.inkSoft,
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'belum ada GPS trip bulan ini.',
          style: AppEditorial.sans(
              fontSize: 13, color: AppEditorial.inkSoft),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        border: Border.all(color: AppEditorial.hairlineSoft, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
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
                style: AppEditorial.mono(
                  fontSize: 38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'km',
                style: AppEditorial.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppEditorial.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
  const _TripRow({required this.trip, required this.isLast});
  final Trip trip;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM', 'id_ID');
    final timeFmt = DateFormat('HH:mm');

    final distText = trip.distanceKm != null
        ? '${trip.distanceKm!.toStringAsFixed(2)} km'
        : (trip.isActive ? 'aktif' : '—');

    final duration = trip.endedAt?.difference(trip.startedAt);
    final durText = duration != null
        ? '${duration.inMinutes}m'
        : '—';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => TripDetailPage(trip: trip)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast
                  ? Colors.transparent
                  : AppEditorial.hairline,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFmt.format(trip.startedAt),
                    style: AppEditorial.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    timeFmt.format(trip.startedAt),
                    style: AppEditorial.mono(
                      fontSize: 11,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                distText,
                style: AppEditorial.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              durText,
              style: AppEditorial.mono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppEditorial.butterDeep,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppEditorial.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({this.text, this.loading = false});
  final String? text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 200),
        Center(
          child: loading
              ? const CircularProgressIndicator(color: AppEditorial.ink)
              : Padding(
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
