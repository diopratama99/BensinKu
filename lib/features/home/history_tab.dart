import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'refuel_detail_page.dart';

/// Riwayat — daftar pengisian dengan filter.
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
      backgroundColor: AppEditorial.cream,
      child: FutureBuilder<List<Vehicle>>(
        future: _repo.listVehicles(),
        builder: (context, vehiclesSnap) {
          if (vehiclesSnap.hasError) {
            return _CenteredError(vehiclesSnap.error.toString());
          }
          final vehicles = vehiclesSnap.data;
          if (vehicles == null) return const _HistorySkeleton();

          final vehicleById = {for (final v in vehicles) v.id: v};

          return FutureBuilder<List<FuelProduct>>(
            future: _repo.listFuelProducts(),
            builder: (context, productsSnap) {
              if (productsSnap.hasError) {
                return _CenteredError(productsSnap.error.toString());
              }
              final products = productsSnap.data;
              if (products == null) return const _HistorySkeleton();

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
                  if (refuels == null) return const _HistorySkeleton();

                  final canLoadMore = refuels.length == _limit;
                  final totalRp =
                      refuels.fold<num>(0, (s, r) => s + r.totalRp);
                  final totalLiter =
                      refuels.fold<num>(0, (s, r) => s + r.liters);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                    children: [
                      _SummaryBlock(
                        totalRp: totalRp,
                        totalLiter: totalLiter,
                        count: refuels.length,
                        rupiah: _rupiah,
                      ),
                      const SizedBox(height: 26),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filter',
                              style: AppEditorial.heading(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          if (_vehicleIdFilter != null ||
                              _monthFilter != null ||
                              _yearFilter != null)
                            GestureDetector(
                              onTap: () => setState(() {
                                _vehicleIdFilter = null;
                                _monthFilter = null;
                                _yearFilter = null;
                              }),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(PhosphorIconsRegular.x,
                                      size: 15, color: AppEditorial.rust),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Reset',
                                    style: AppEditorial.sans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppEditorial.rust,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                      ),
                      const SizedBox(height: 26),

                      EditorialSectionHeader(
                        label: 'Catatan pengisian',
                        trailing: Text(
                          '${refuels.length} entri',
                          style: AppEditorial.sans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppEditorial.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (refuels.isEmpty)
                        _EmptyArsip()
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
                              for (var i = 0; i < refuels.length; i++)
                                _LogEntry(
                                  refuel: refuels[i],
                                  vehicle:
                                      vehicleById[refuels[i].vehicleId],
                                  product: productById[
                                      refuels[i].fuelProductId],
                                  rupiah: _rupiah,
                                  isLast: i == refuels.length - 1,
                                  onChanged: () =>
                                      setState(() => _limit = _limit),
                                ),
                            ],
                          ),
                        ),

                      if (canLoadMore) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _limit += _pageSize),
                          child: const Text('Muat lebih banyak'),
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
    required this.count,
    required this.rupiah,
  });
  final num totalRp;
  final num totalLiter;
  final int count;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total pengeluaran',
                    style: AppEditorial.sans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppEditorial.inkSoft,
                    )),
                const SizedBox(height: 8),
                EditorialReadout(
                  prefix: 'Rp ',
                  value: rupiah.format(totalRp).trim(),
                  fontSize: 28,
                ),
              ],
            ),
          ),
          Container(width: 1, height: 52, color: AppEditorial.hairlineSoft),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Volume',
                    style: AppEditorial.sans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppEditorial.inkSoft,
                    )),
                const SizedBox(height: 8),
                EditorialReadout(
                  value: totalLiter.toStringAsFixed(1),
                  suffix: ' L',
                  fontSize: 28,
                  color: AppEditorial.brandDeep,
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
  });

  final List<Vehicle> vehicles;
  final String? vehicleId;
  final int? month;
  final int? year;
  final List<int> years;
  final ValueChanged<String?> onVehicleChange;
  final ValueChanged<int?> onMonthChange;
  final ValueChanged<int?> onYearChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vehicles.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: 'Semua',
                  selected: vehicleId == null,
                  onTap: () => onVehicleChange(null),
                ),
                const SizedBox(width: 8),
                ...vehicles.map((v) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterPill(
                        label: '${v.type.label} · ${v.name}',
                        selected: vehicleId == v.id,
                        onTap: () => onVehicleChange(v.id),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _MonthYearDropdown<int?>(
                label: 'Bulan',
                value: month,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(DateFormat('MMMM', 'id_ID')
                          .format(DateTime(2000, m))),
                    ),
                ],
                onChanged: onMonthChange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthYearDropdown<int?>(
                label: 'Tahun',
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
        Text(label,
            style: AppEditorial.sans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppEditorial.inkSoft,
            )),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppEditorial.canvasSoft,
            borderRadius: BorderRadius.circular(AppEditorial.rButton),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              icon: const Icon(PhosphorIconsRegular.caretDown,
                  color: AppEditorial.inkSoft),
              dropdownColor: AppEditorial.cream,
              borderRadius: BorderRadius.circular(AppEditorial.rButton),
              style: AppEditorial.sans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppEditorial.ink,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppEditorial.ink : AppEditorial.canvasSoft,
          borderRadius: BorderRadius.circular(AppEditorial.rPill),
        ),
        child: Text(
          label,
          style: AppEditorial.sans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFFFFFFFF)
                : AppEditorial.inkSoft,
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
    this.onChanged,
  });

  final Refuel refuel;
  final Vehicle? vehicle;
  final FuelProduct? product;
  final NumberFormat rupiah;
  final bool isLast;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final vehicleText = vehicle == null
        ? '—'
        : '${vehicle!.type.label} · ${vehicle!.name}';
    final productText = product?.label ?? 'BBM';
    final dayStr = DateFormat('dd').format(refuel.refuelDate);
    final monthYearStr = DateFormat('MMM yy', 'id_ID')
        .format(refuel.refuelDate)
        .toUpperCase();

    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => RefuelDetailPage(
              refuel: refuel,
              vehicle: vehicle,
              product: product,
            ),
          ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppEditorial.canvasSoft,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Column(
                children: [
                  Text(
                    dayStr,
                    style: AppEditorial.heading(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthYearStr,
                    style: AppEditorial.sans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.inkMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rp ${rupiah.format(refuel.totalRp).trim()}',
                    style: AppEditorial.heading(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$productText · $vehicleText',
                    style: AppEditorial.sans(
                      fontSize: 12,
                      color: AppEditorial.inkSoft,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${refuel.liters.toStringAsFixed(2)} L',
                  style: AppEditorial.heading(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.brandDeep,
                  ),
                ),
                if (refuel.isFullTank) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppEditorial.brandTint,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rPill),
                    ),
                    child: Text(
                      'Full',
                      style: AppEditorial.sans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppEditorial.brandDeep,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyArsip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 800 / 600,
            child: Image.asset(
              'assets/illustrations/empty_arsip.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada entri.',
            style: AppEditorial.sans(
              fontSize: 13,
              color: AppEditorial.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        // Summary card
        EditorialCard(
          child: Row(
            children: const [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 110, height: 12),
                    SizedBox(height: 12),
                    Skeleton(width: 130, height: 26),
                  ],
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 60, height: 12),
                    SizedBox(height: 12),
                    Skeleton(width: 90, height: 26),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Skeleton(width: 90, height: 18),
        const SizedBox(height: 14),
        Row(
          children: const [
            Skeleton(width: 70, height: 38, radius: AppEditorial.rPill),
            SizedBox(width: 8),
            Skeleton(width: 110, height: 38, radius: AppEditorial.rPill),
            SizedBox(width: 8),
            Skeleton(width: 96, height: 38, radius: AppEditorial.rPill),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(
                child: Skeleton(
                    width: double.infinity,
                    height: 50,
                    radius: AppEditorial.rButton)),
            SizedBox(width: 12),
            Expanded(
                child: Skeleton(
                    width: double.infinity,
                    height: 50,
                    radius: AppEditorial.rButton)),
          ],
        ),
        const SizedBox(height: 26),
        const Skeleton(width: 160, height: 18),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Column(
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == 5
                            ? Colors.transparent
                            : AppEditorial.hairlineSoft,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Skeleton(width: 50, height: 46, radius: AppEditorial.rTiny),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Skeleton(width: 110, height: 16),
                            SizedBox(height: 8),
                            Skeleton(width: 150, height: 11),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Skeleton(width: 54, height: 15),
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

class _CenteredError extends StatelessWidget {
  const _CenteredError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Gagal memuat catatan',
          style: AppEditorial.heading(
            fontSize: 22,
            fontWeight: FontWeight.w700,
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
