import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Arsip — service-log style entry list.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  static const _pageSize = 30;
  int _limit = _pageSize;

  String? _vehicleIdFilter;
  int? _monthFilter;
  int? _yearFilter;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _limit = _pageSize),
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

          final vehicleById = {for (final v in vehicles) v.id: v};

          return FutureBuilder<List<FuelProduct>>(
            future: _repo.listFuelProducts(),
            builder: (context, productsSnap) {
              if (productsSnap.hasError) {
                return _CenteredError(productsSnap.error.toString());
              }
              final products = productsSnap.data;
              if (products == null) return const _CenteredLoading();

              final productById = {for (final p in products) p.id: p};
              final range = _dateRangeForQuery();

              return FutureBuilder<List<Refuel>>(
                future: _repo.listRefuels(
                  vehicleId: _vehicleIdFilter,
                  from: range.$1,
                  toExclusive: range.$2,
                  limit: _limit,
                ),
                builder: (context, refuelsSnap) {
                  if (refuelsSnap.hasError) {
                    return _CenteredError(refuelsSnap.error.toString());
                  }
                  final refuels = refuelsSnap.data;
                  if (refuels == null) return const _CenteredLoading();

                  final canLoadMore = refuels.length == _limit;
                  final totalRp =
                      refuels.fold<num>(0, (s, r) => s + r.totalRp);
                  final totalLiter =
                      refuels.fold<num>(0, (s, r) => s + r.liters);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                    children: [
                      // §01 Ringkasan
                      EditorialSectionHeader(
                        index: '01',
                        label: 'TOTAL HASIL FILTER',
                        trailing: Text('${refuels.length} ENTRI',
                            style: AppEditorial.eyebrow()),
                      ),
                      const SizedBox(height: 14),
                      _SummaryBlock(
                        totalRp: totalRp,
                        totalLiter: totalLiter,
                        rupiah: _rupiah,
                      ),
                      const SizedBox(height: 24),

                      // §02 Filter
                      const EditorialSectionHeader(
                        index: '02',
                        label: 'FILTER',
                      ),
                      const SizedBox(height: 12),
                      _FilterBar(
                        vehicles: vehicles,
                        vehicleId: _vehicleIdFilter,
                        month: _monthFilter,
                        year: _yearFilter,
                        years: _allYears(refuels),
                        onVehicleChange: (v) =>
                            setState(() => _vehicleIdFilter = v),
                        onMonthChange: (v) {
                          setState(() {
                            _monthFilter = v;
                            if (_monthFilter != null && _yearFilter == null) {
                              _yearFilter = DateTime.now().year;
                            }
                            _limit = _pageSize;
                          });
                        },
                        onYearChange: (v) {
                          setState(() {
                            _yearFilter = v;
                            if (_yearFilter == null) _monthFilter = null;
                            _limit = _pageSize;
                          });
                        },
                        onReset: () => setState(() {
                          _vehicleIdFilter = null;
                          _monthFilter = null;
                          _yearFilter = null;
                        }),
                      ),
                      const SizedBox(height: 24),

                      // §03 List
                      const EditorialSectionHeader(
                        index: '03',
                        label: 'CATATAN PENGISIAN',
                      ),
                      const SizedBox(height: 8),

                      if (refuels.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'belum ada entri.',
                            style: AppEditorial.sans(
                              fontSize: 13,
                              color: AppEditorial.inkSoft,
                            ),
                          ),
                        )
                      else
                        ...refuels.asMap().entries.map(
                              (e) => _LogEntry(
                                refuel: e.value,
                                vehicle:
                                    vehicleById[e.value.vehicleId],
                                product:
                                    productById[e.value.fuelProductId],
                                rupiah: _rupiah,
                                isLast: e.key == refuels.length - 1,
                              ),
                            ),

                      if (canLoadMore) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _limit += _pageSize),
                          child: const Text('MUAT LEBIH BANYAK ↓'),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<int> _allYears(List<Refuel> refuels) {
    final now = DateTime.now();
    final years = <int>{
      now.year,
      ...refuels.map((r) => r.refuelDate.year),
    }.toList()
      ..sort();
    return years;
  }

  (DateTime?, DateTime?) _dateRangeForQuery() {
    if (_yearFilter == null) return (null, null);
    if (_monthFilter == null) {
      final from = DateTime(_yearFilter!, 1, 1);
      final to = DateTime(_yearFilter! + 1, 1, 1);
      return (from, to);
    }
    final from = DateTime(_yearFilter!, _monthFilter!, 1);
    final to = DateTime(_yearFilter!, _monthFilter! + 1, 1);
    return (from, to);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary block
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.totalRp,
    required this.totalLiter,
    required this.rupiah,
  });
  final num totalRp;
  final num totalLiter;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        border: Border.all(color: AppEditorial.hairlineSoft, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PENGELUARAN', style: AppEditorial.eyebrow()),
                const SizedBox(height: 6),
                EditorialReadout(
                  prefix: 'Rp ',
                  value: rupiah.format(totalRp).trim(),
                  fontSize: 28,
                ),
              ],
            ),
          ),
          Container(width: 1, height: 56, color: AppEditorial.hairline),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VOLUME', style: AppEditorial.eyebrow()),
                const SizedBox(height: 6),
                EditorialReadout(
                  value: totalLiter.toStringAsFixed(1),
                  suffix: ' L',
                  fontSize: 28,
                  color: AppEditorial.butterDeep,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.vehicles,
    required this.vehicleId,
    required this.month,
    required this.year,
    required this.years,
    required this.onVehicleChange,
    required this.onMonthChange,
    required this.onYearChange,
    required this.onReset,
  });

  final List<Vehicle> vehicles;
  final String? vehicleId;
  final int? month;
  final int? year;
  final List<int> years;
  final ValueChanged<String?> onVehicleChange;
  final ValueChanged<int?> onMonthChange;
  final ValueChanged<int?> onYearChange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        vehicleId != null || month != null || year != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFilter)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onReset,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '× RESET',
                  style: AppEditorial.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.rust,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        if (vehicles.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: 'SEMUA',
                  selected: vehicleId == null,
                  onTap: () => onVehicleChange(null),
                ),
                const SizedBox(width: 6),
                ...vehicles.map((v) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _FilterPill(
                        label: '${v.type.label} · ${v.name}'
                            .toUpperCase(),
                        selected: vehicleId == v.id,
                        onTap: () => onVehicleChange(v.id),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _MonthYearDropdown<int?>(
                label: 'BULAN',
                value: month,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(m.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: onMonthChange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthYearDropdown<int?>(
                label: 'TAHUN',
                value: year,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text(y.toString())),
                ],
                onChanged: onYearChange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthYearDropdown<T> extends StatelessWidget {
  const _MonthYearDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppEditorial.eyebrow(fontSize: 9.5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppEditorial.hairline, width: 1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.arrow_drop_down_rounded,
                  color: AppEditorial.inkSoft),
              dropdownColor: AppEditorial.cream,
              style: AppEditorial.mono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppEditorial.ink : AppEditorial.canvas,
          border: Border.all(color: AppEditorial.ink, width: 1),
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
        ),
        child: Text(
          label,
          style: AppEditorial.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? AppEditorial.canvas : AppEditorial.ink,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log entry — single line per refuel
// ─────────────────────────────────────────────────────────────────────────────

class _LogEntry extends StatelessWidget {
  const _LogEntry({
    required this.refuel,
    required this.vehicle,
    required this.product,
    required this.rupiah,
    required this.isLast,
  });

  final Refuel refuel;
  final Vehicle? vehicle;
  final FuelProduct? product;
  final NumberFormat rupiah;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final vehicleText = vehicle == null
        ? '—'
        : '${vehicle!.type.label} · ${vehicle!.name}';
    final productText = product?.label ?? 'BBM';
    final dayStr = DateFormat('dd').format(refuel.refuelDate);
    final monthYearStr =
        DateFormat('MMM yy', 'id_ID').format(refuel.refuelDate).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : AppEditorial.hairline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date — stacked calendar style (big day, small month/year)
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayStr,
                  style: AppEditorial.mono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  monthYearStr,
                  style: AppEditorial.eyebrow(
                    fontSize: 9.5,
                    color: AppEditorial.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rp ${rupiah.format(refuel.totalRp).trim()}',
                  style: AppEditorial.mono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  productText,
                  style: AppEditorial.sans(
                    fontSize: 12,
                    color: AppEditorial.inkSoft,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  vehicleText,
                  style: AppEditorial.mono(
                    fontSize: 11,
                    color: AppEditorial.inkMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                refuel.liters.toStringAsFixed(2),
                style: AppEditorial.mono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.butterDeep,
                ),
              ),
              Text('LITER', style: AppEditorial.eyebrow(fontSize: 9)),
              if (refuel.isFullTank) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
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
            ],
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 40),
        const EditorialEyebrow('ERROR'),
        const SizedBox(height: 10),
        Text(
          'Gagal memuat catatan.',
          style: AppEditorial.mono(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(message,
            style: AppEditorial.sans(
              fontSize: 13,
              color: AppEditorial.inkSoft,
              height: 1.5,
            )),
      ],
    );
  }
}
