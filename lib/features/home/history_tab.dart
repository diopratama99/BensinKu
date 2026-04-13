import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/repository.dart';

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
    symbol: 'Rp',
    decimalDigits: 0,
  );

  final _date = DateFormat('dd MMM yyyy', 'id_ID');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => setState(() => _limit = _pageSize),
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

          final vehicleById = {for (final v in vehicles) v.id: v};

          return FutureBuilder<List<FuelProduct>>(
            future: _repo.listFuelProducts(),
            builder: (context, productsSnap) {
              if (productsSnap.hasError) {
                return _CenteredError(productsSnap.error.toString());
              }
              final products = productsSnap.data;
              if (products == null) {
                return const _CenteredLoading('Memuat...');
              }

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
                  if (refuels == null) {
                    return const _CenteredLoading('Memuat riwayat...');
                  }

                  final canLoadMore = refuels.length == _limit;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      // ─── Header ───────────────────────────────────────
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
                                Icons.history_rounded,
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
                                    'Riwayat',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    '${refuels.length} pengisian tercatat',
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

                      // ─── Filter bar ────────────────────────────────────
                      _buildFilterBar(vehicles, refuels),
                      const SizedBox(height: 12),

                      // ─── List ──────────────────────────────────────────
                      if (refuels.isEmpty)
                        _EmptyState(
                          title: 'Belum Ada Data',
                          subtitle:
                              'Tambah pengisian pertama kamu di tab Add Fuel.',
                        )
                      else
                        ...refuels.map(
                          (r) => _RefuelTile(
                            refuel: r,
                            vehicle: vehicleById[r.vehicleId],
                            product: productById[r.fuelProductId],
                            rupiah: _rupiah,
                            dateFormat: _date,
                          ),
                        ),

                      if (canLoadMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: FilledButton.tonal(
                            onPressed: () =>
                                setState(() => _limit += _pageSize),
                            child: const Text('Muat lebih banyak'),
                          ),
                        ),
                      const SizedBox(height: 90),
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

  Widget _buildFilterBar(List<Vehicle> vehicles, List<Refuel> refuels) {
    final cs = Theme.of(context).colorScheme;

    if (vehicles.isEmpty) {
      _vehicleIdFilter = null;
    } else if (_vehicleIdFilter != null &&
        !vehicles.any((v) => v.id == _vehicleIdFilter)) {
      _vehicleIdFilter = null;
    }

    final now = DateTime.now();
    final years =
        <int>{now.year, ...refuels.map((r) => r.refuelDate.year)}.toList()
          ..sort();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
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
              Icon(Icons.tune_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Filter',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_vehicleIdFilter != null ||
                  _monthFilter != null ||
                  _yearFilter != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _vehicleIdFilter = null;
                    _monthFilter = null;
                    _yearFilter = null;
                  }),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Vehicle chips
          if (vehicles.isNotEmpty) ...[
            Text(
              'Kendaraan',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChipItem(
                    label: 'Semua',
                    selected: _vehicleIdFilter == null,
                    onTap: () =>
                        setState(() => _vehicleIdFilter = null),
                  ),
                  ...vehicles.map((v) => _FilterChipItem(
                        label: '${v.type.label} — ${v.name}',
                        selected: _vehicleIdFilter == v.id,
                        onTap: () =>
                            setState(() => _vehicleIdFilter = v.id),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Month/year row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulan',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      key: ValueKey(_monthFilter),
                      initialValue: _monthFilter,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Semua'),
                        ),
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(
                            value: m,
                            child:
                                Text(m.toString().padLeft(2, '0')),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _monthFilter = v;
                        if (_monthFilter != null &&
                            _yearFilter == null) {
                          _yearFilter = DateTime.now().year;
                        }
                        _limit = _pageSize;
                      }),
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
                      'Tahun',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      key: ValueKey(_yearFilter),
                      initialValue: _yearFilter,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Semua'),
                        ),
                        for (final y in years)
                          DropdownMenuItem(
                              value: y, child: Text(y.toString())),
                      ],
                      onChanged: (v) => setState(() {
                        _yearFilter = v;
                        if (_yearFilter == null) {
                          _monthFilter = null;
                        }
                        _limit = _pageSize;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (DateTime?, DateTime?) _dateRangeForQuery() {
    if (_yearFilter == null) return (null, null);

    if (_monthFilter == null) {
      final from = DateTime(_yearFilter!, 1, 1);
      final toExclusive = DateTime(_yearFilter! + 1, 1, 1);
      return (from, toExclusive);
    }

    final from = DateTime(_yearFilter!, _monthFilter!, 1);
    final toExclusive = DateTime(_yearFilter!, _monthFilter! + 1, 1);
    return (from, toExclusive);
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RefuelTile extends StatelessWidget {
  const _RefuelTile({
    required this.refuel,
    required this.vehicle,
    required this.product,
    required this.rupiah,
    required this.dateFormat,
  });

  final Refuel refuel;
  final Vehicle? vehicle;
  final FuelProduct? product;
  final NumberFormat rupiah;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vehicleText = vehicle == null
        ? 'Kendaraan'
        : '${vehicle!.type.label} — ${vehicle!.name}';
    final productText = product?.label ?? 'BBM';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: refuel.isFullTank
                  ? cs.primaryContainer
                  : cs.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              refuel.isFullTank
                  ? Icons.local_gas_station_rounded
                  : Icons.local_gas_station_outlined,
              color: refuel.isFullTank
                  ? cs.primary
                  : cs.secondary,
              size: 22,
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
                  dateFormat.format(refuel.refuelDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$vehicleText • $productText',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${refuel.liters.toStringAsFixed(2)} L',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              if (refuel.odometerKm != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${refuel.odometerKm} km',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (refuel.isFullTank) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
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
              Text(text,
                  style:
                      TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
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
        _EmptyState(title: 'Terjadi Kesalahan', subtitle: message),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, color: cs.onSurfaceVariant, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
