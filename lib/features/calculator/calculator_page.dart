import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';

/// Opsi BBM untuk kalkulator — diturunkan dari `fuel_products` + `fuel_prices`
/// di backend (bukan hardcode).
class _FuelOption {
  const _FuelOption({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
  });
  final String id;
  final String name;
  final String brand;
  final int price;
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _repo = SupabaseRepository.ofDefaultClient();
  late final Future<List<_FuelOption>> _fuelFuture = _loadFuels();

  Future<List<_FuelOption>> _loadFuels() async {
    final products = await _repo.listFuelProducts();
    final now = DateTime.now();
    final options = await Future.wait(products.map((p) async {
      final price = await _repo.getFuelPrice(fuelProductId: p.id, onDate: now);
      return _FuelOption(
        id: p.id,
        name: p.name,
        brand: p.brand,
        price: (price?.pricePerLiter ?? 0).round(),
      );
    }));
    // Hanya tampilkan yang punya harga master.
    return options.where((o) => o.price > 0).toList();
  }

  // Mode 0 — Biaya Perjalanan
  final _distance = TextEditingController();
  final _kmpl = TextEditingController();
  final _price = TextEditingController();

  // Mode 1 — Uang → Liter
  final _budget = TextEditingController();
  final _price2 = TextEditingController();
  final _kmpl2 = TextEditingController();

  // Mode 2 — Bandingkan BBM
  final _kmplA = TextEditingController();
  final _priceA = TextEditingController();
  final _kmplB = TextEditingController();
  final _priceB = TextEditingController();
  final _distC = TextEditingController();

  final _rupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) setState(() {});
      });
  }

  @override
  void dispose() {
    _tab.dispose();
    _distance.dispose();
    _kmpl.dispose();
    _price.dispose();
    _budget.dispose();
    _price2.dispose();
    _kmpl2.dispose();
    _kmplA.dispose();
    _priceA.dispose();
    _kmplB.dispose();
    _priceB.dispose();
    _distC.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) {
    final raw =
        c.text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: Column(
        children: [
          _FixedHeader(tab: _tab),
          Expanded(
            child: FutureBuilder<List<_FuelOption>>(
              future: _fuelFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppEditorial.ink,
                      strokeWidth: 2.4,
                    ),
                  );
                }
                final fuels = snap.data ?? const <_FuelOption>[];
                return TabBarView(
                  controller: _tab,
                  children: [
                    _TripCostTab(
                      distance: _distance,
                      kmpl: _kmpl,
                      price: _price,
                      rupiah: _rupiah,
                      num: _num,
                      fuels: fuels,
                    ),
                    _BudgetTab(
                      budget: _budget,
                      price: _price2,
                      kmpl: _kmpl2,
                      rupiah: _rupiah,
                      num: _num,
                      fuels: fuels,
                    ),
                    _CompareTab(
                      kmplA: _kmplA,
                      priceA: _priceA,
                      kmplB: _kmplB,
                      priceB: _priceB,
                      dist: _distC,
                      rupiah: _rupiah,
                      num: _num,
                      fuels: fuels,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixed header — clean white top bar + segmented tabs
// ─────────────────────────────────────────────────────────────────────────────

class _FixedHeader extends StatelessWidget {
  const _FixedHeader({required this.tab});
  final TabController tab;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppEditorial.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 20,
              bottom: 4,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.arrowLeft,
                      color: AppEditorial.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 2),
                Text(
                  'Kalkulator BBM',
                  style: AppEditorial.heading(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Segmented tab selector
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: AnimatedBuilder(
              animation: tab.animation ?? tab,
              builder: (context, _) {
                final current = tab.index;
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppEditorial.canvasSoft,
                    borderRadius: BorderRadius.circular(AppEditorial.rPill),
                  ),
                  child: Row(
                    children: [
                      _SegTab(
                        icon: PhosphorIconsRegular.path,
                        label: 'Perjalanan',
                        selected: current == 0,
                        onTap: () => tab.animateTo(0),
                      ),
                      _SegTab(
                        icon: PhosphorIconsRegular.coins,
                        label: 'Uang',
                        selected: current == 1,
                        onTap: () => tab.animateTo(1),
                      ),
                      _SegTab(
                        icon: PhosphorIconsRegular.scales,
                        label: 'Banding',
                        selected: current == 2,
                        onTap: () => tab.animateTo(2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppEditorial.hairline),
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppEditorial.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(AppEditorial.rPill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? const Color(0xFFFFFFFF)
                    : AppEditorial.inkSoft,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppEditorial.heading(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? const Color(0xFFFFFFFF)
                        : AppEditorial.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 0 — Biaya Perjalanan
// ─────────────────────────────────────────────────────────────────────────────

class _TripCostTab extends StatefulWidget {
  const _TripCostTab({
    required this.distance,
    required this.kmpl,
    required this.price,
    required this.rupiah,
    required this.num,
    required this.fuels,
  });
  final TextEditingController distance, kmpl, price;
  final NumberFormat rupiah;
  final double Function(TextEditingController) num;
  final List<_FuelOption> fuels;

  @override
  State<_TripCostTab> createState() => _TripCostTabState();
}

class _TripCostTabState extends State<_TripCostTab> {
  int? _fuelIdx;

  @override
  void initState() {
    super.initState();
    _fuelIdx = widget.fuels.isEmpty ? null : 0;
    if (widget.price.text.isEmpty && widget.fuels.isNotEmpty) {
      widget.price.text = widget.fuels[0].price.toString();
    }
  }

  void _rebuild() => setState(() {});

  Future<void> _pickFuel() async {
    final res = await _showFuelPicker(
      context,
      fuels: widget.fuels,
      currentIdx: _fuelIdx,
      currentPrice: widget.num(widget.price).toInt(),
      rupiah: widget.rupiah,
    );
    if (res == null) return;
    setState(() {
      if (res.idx != null) {
        _fuelIdx = res.idx;
        widget.price.text = widget.fuels[res.idx!].price.toString();
      } else {
        _fuelIdx = null;
        widget.price.text = res.customPrice.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dist = widget.num(widget.distance);
    final kmpl = widget.num(widget.kmpl);
    final price = widget.num(widget.price);
    final liters = kmpl > 0 ? dist / kmpl : 0.0;
    final cost = liters * price;
    final ready = dist > 0 && kmpl > 0 && price > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        // Inputs
        _InputCard(label: 'Data Perjalanan', children: [
          _CalcField(
            controller: widget.distance,
            label: 'Jarak Tempuh',
            suffix: 'km',
            hint: '120',
            onChanged: _rebuild,
          ),
          _FieldDivider(),
          _CalcField(
            controller: widget.kmpl,
            label: 'Konsumsi BBM',
            suffix: 'km/L',
            hint: '45',
            onChanged: _rebuild,
          ),
          _FieldDivider(),
          _FuelPriceField(
            label: 'Jenis BBM',
            fuels: widget.fuels,
            fuelIdx: _fuelIdx,
            price: price,
            rupiah: widget.rupiah,
            onTap: _pickFuel,
          ),
        ]),
        const SizedBox(height: 20),
        // Result hero
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ready
              ? _HeroResult(
                  key: const ValueKey('res0-ready'),
                  primaryLabel: 'Estimasi Biaya',
                  primaryValue: cost,
                  primaryFormatter: (v) =>
                      'Rp ${widget.rupiah.format(v).trim()}',
                  chips: [
                    _Chip(
                      icon: PhosphorIconsRegular.drop,
                      label: '${liters.toStringAsFixed(2)} L',
                      sub: 'bensin',
                    ),
                    _Chip(
                      icon: PhosphorIconsRegular.mapPin,
                      label: '${dist.toStringAsFixed(0)} km',
                      sub: 'jarak',
                    ),
                    if (price > 0)
                      _Chip(
                        icon: PhosphorIconsRegular.gasPump,
                        label: 'Rp ${widget.rupiah.format(price).trim()}',
                        sub: 'per liter',
                      ),
                  ],
                )
              : _EmptyResult(
                  key: const ValueKey('res0-empty'),
                  hint: 'Isi jarak, km/L, dan harga BBM untuk lihat estimasi.',
                ),
        ),
        // Quick presets
        const SizedBox(height: 20),
        _PresetsSection(
          label: 'Preset Konsumsi Umum',
          chips: [
            ('Motor matic · 45 km/L', '45'),
            ('Motor sport · 35 km/L', '35'),
            ('Mobil city · 18 km/L', '18'),
            ('Mobil SUV · 12 km/L', '12'),
          ],
          onSelect: (v) {
            widget.kmpl.text = v;
            _rebuild();
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Uang → Liter
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetTab extends StatefulWidget {
  const _BudgetTab({
    required this.budget,
    required this.price,
    required this.kmpl,
    required this.rupiah,
    required this.num,
    required this.fuels,
  });
  final TextEditingController budget, price, kmpl;
  final NumberFormat rupiah;
  final double Function(TextEditingController) num;
  final List<_FuelOption> fuels;

  @override
  State<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<_BudgetTab> {
  int? _fuelIdx;

  @override
  void initState() {
    super.initState();
    _fuelIdx = widget.fuels.isEmpty ? null : 0;
    if (widget.price.text.isEmpty && widget.fuels.isNotEmpty) {
      widget.price.text = widget.fuels[0].price.toString();
    }
  }

  void _rebuild() => setState(() {});

  Future<void> _pickFuel() async {
    final res = await _showFuelPicker(
      context,
      fuels: widget.fuels,
      currentIdx: _fuelIdx,
      currentPrice: widget.num(widget.price).toInt(),
      rupiah: widget.rupiah,
    );
    if (res == null) return;
    setState(() {
      if (res.idx != null) {
        _fuelIdx = res.idx;
        widget.price.text = widget.fuels[res.idx!].price.toString();
      } else {
        _fuelIdx = null;
        widget.price.text = res.customPrice.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.num(widget.budget);
    final price = widget.num(widget.price);
    final kmpl = widget.num(widget.kmpl);
    final liters = price > 0 ? budget / price : 0.0;
    final distance = liters * kmpl;
    final ready = budget > 0 && price > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        _InputCard(label: 'Nominal & BBM', children: [
          _CalcField(
            controller: widget.budget,
            label: 'Uang yang Dibawa',
            prefix: 'Rp',
            hint: '50.000',
            digitsOnly: true,
            onChanged: _rebuild,
          ),
          _FieldDivider(),
          _FuelPriceField(
            label: 'Jenis BBM',
            fuels: widget.fuels,
            fuelIdx: _fuelIdx,
            price: price,
            rupiah: widget.rupiah,
            onTap: _pickFuel,
          ),
          _FieldDivider(),
          _CalcField(
            controller: widget.kmpl,
            label: 'Konsumsi (opsional)',
            suffix: 'km/L',
            hint: '45',
            onChanged: _rebuild,
          ),
        ]),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ready
              ? _HeroResult(
                  key: const ValueKey('res1-ready'),
                  primaryLabel: 'Dapat Bensin',
                  primaryValue: liters,
                  primaryFormatter: (v) => '${v.toStringAsFixed(2)} L',
                  chips: [
                    _Chip(
                      icon: PhosphorIconsRegular.wallet,
                      label: 'Rp ${widget.rupiah.format(budget).trim()}',
                      sub: 'uang',
                    ),
                    if (kmpl > 0)
                      _Chip(
                        icon: PhosphorIconsRegular.mapPin,
                        label: '${distance.toStringAsFixed(0)} km',
                        sub: 'estimasi jarak',
                      ),
                    _Chip(
                      icon: PhosphorIconsRegular.gasPump,
                      label: 'Rp ${widget.rupiah.format(price).trim()}',
                      sub: 'per liter',
                    ),
                  ],
                )
              : _EmptyResult(
                  key: const ValueKey('res1-empty'),
                  hint: 'Pilih jenis BBM dan isi nominal uangmu.',
                ),
        ),
        const SizedBox(height: 20),
        _PresetsSection(
          label: 'Preset Uang Cepat',
          chips: [
            ('Rp 20rb', '20000'),
            ('Rp 50rb', '50000'),
            ('Rp 100rb', '100000'),
            ('Rp 200rb', '200000'),
          ],
          onSelect: (v) {
            widget.budget.text = v;
            _rebuild();
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Bandingkan BBM
// ─────────────────────────────────────────────────────────────────────────────

class _CompareTab extends StatefulWidget {
  const _CompareTab({
    required this.kmplA,
    required this.priceA,
    required this.kmplB,
    required this.priceB,
    required this.dist,
    required this.rupiah,
    required this.num,
    required this.fuels,
  });
  final TextEditingController kmplA, priceA, kmplB, priceB, dist;
  final NumberFormat rupiah;
  final double Function(TextEditingController) num;
  final List<_FuelOption> fuels;

  @override
  State<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<_CompareTab> {
  int? _fuelA;
  int? _fuelB;

  @override
  void initState() {
    super.initState();
    final n = widget.fuels.length;
    _fuelA = n > 0 ? 0 : null;
    _fuelB = n > 1 ? 1 : (n > 0 ? 0 : null);
    if (widget.priceA.text.isEmpty && _fuelA != null) {
      widget.priceA.text = widget.fuels[_fuelA!].price.toString();
    }
    if (widget.priceB.text.isEmpty && _fuelB != null) {
      widget.priceB.text = widget.fuels[_fuelB!].price.toString();
    }
  }

  void _rebuild() => setState(() {});

  Future<void> _pickFuel({required bool isA}) async {
    final res = await _showFuelPicker(
      context,
      fuels: widget.fuels,
      currentIdx: isA ? _fuelA : _fuelB,
      currentPrice: widget.num(isA ? widget.priceA : widget.priceB).toInt(),
      rupiah: widget.rupiah,
    );
    if (res == null) return;
    setState(() {
      final ctrl = isA ? widget.priceA : widget.priceB;
      final idx = res.idx;
      if (idx != null) {
        ctrl.text = widget.fuels[idx].price.toString();
        if (isA) {
          _fuelA = idx;
        } else {
          _fuelB = idx;
        }
      } else {
        ctrl.text = res.customPrice.toString();
        if (isA) {
          _fuelA = null;
        } else {
          _fuelB = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kmplA = widget.num(widget.kmplA);
    final priceA = widget.num(widget.priceA);
    final kmplB = widget.num(widget.kmplB);
    final priceB = widget.num(widget.priceB);
    final dist = widget.num(widget.dist);

    final costPerKmA = (kmplA > 0 && priceA > 0) ? priceA / kmplA : 0.0;
    final costPerKmB = (kmplB > 0 && priceB > 0) ? priceB / kmplB : 0.0;
    final totalA = costPerKmA * dist;
    final totalB = costPerKmB * dist;

    final readyPartial = kmplA > 0 && priceA > 0 && kmplB > 0 && priceB > 0;
    final readyFull = readyPartial && dist > 0;

    final winnerA = readyPartial && costPerKmA < costPerKmB;
    final winnerB = readyPartial && costPerKmB < costPerKmA;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _InputCard(
                label: 'Opsi A',
                labelColor: AppEditorial.sage,
                children: [
                  _CalcField(
                    controller: widget.kmplA,
                    label: 'Konsumsi (km/L)',
                    hint: '45',
                    stacked: true,
                    onChanged: _rebuild,
                  ),
                  _FieldDivider(),
                  _FuelPriceField(
                    label: 'Jenis BBM',
                    fuels: widget.fuels,
                    fuelIdx: _fuelA,
                    price: priceA,
                    rupiah: widget.rupiah,
                    stacked: true,
                    onTap: () => _pickFuel(isA: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InputCard(
                label: 'Opsi B',
                labelColor: AppEditorial.brandDeep,
                children: [
                  _CalcField(
                    controller: widget.kmplB,
                    label: 'Konsumsi (km/L)',
                    hint: '30',
                    stacked: true,
                    onChanged: _rebuild,
                  ),
                  _FieldDivider(),
                  _FuelPriceField(
                    label: 'Jenis BBM',
                    fuels: widget.fuels,
                    fuelIdx: _fuelB,
                    price: priceB,
                    rupiah: widget.rupiah,
                    stacked: true,
                    onTap: () => _pickFuel(isA: false),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InputCard(label: 'Jarak Perjalanan', children: [
          _CalcField(
            controller: widget.dist,
            label: 'Total jarak (opsional)',
            suffix: 'km',
            hint: '100',
            onChanged: _rebuild,
          ),
        ]),
        const SizedBox(height: 20),
        if (!readyPartial)
          _EmptyResult(
            key: const ValueKey('res2-empty'),
            hint:
                'Isi km/L dan harga tiap opsi untuk membandingkan efisiensi.',
          )
        else
          _CompareResult(
            costPerKmA: costPerKmA,
            costPerKmB: costPerKmB,
            totalA: totalA,
            totalB: totalB,
            winnerA: winnerA,
            winnerB: winnerB,
            dist: dist,
            readyFull: readyFull,
            rupiah: widget.rupiah,
          ),
      ],
    );
  }
}

class _CompareResult extends StatelessWidget {
  const _CompareResult({
    required this.costPerKmA,
    required this.costPerKmB,
    required this.totalA,
    required this.totalB,
    required this.winnerA,
    required this.winnerB,
    required this.dist,
    required this.readyFull,
    required this.rupiah,
  });

  final double costPerKmA, costPerKmB, totalA, totalB, dist;
  final bool winnerA, winnerB, readyFull;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final savings =
        readyFull ? (totalA - totalB).abs() : 0.0;
    final winnerLabel = winnerA ? 'Opsi A' : (winnerB ? 'Opsi B' : null);

    return Column(
      children: [
        // Per-km comparison bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biaya per Kilometer',
                  style: AppEditorial.eyebrow(color: AppEditorial.inkMuted)),
              const SizedBox(height: 14),
              _CostBar(
                label: 'Opsi A',
                color: AppEditorial.sage,
                value: costPerKmA,
                maxValue: costPerKmA > costPerKmB ? costPerKmA : costPerKmB,
                isWinner: winnerA,
                rupiah: rupiah,
              ),
              const SizedBox(height: 10),
              _CostBar(
                label: 'Opsi B',
                color: AppEditorial.brandDeep,
                value: costPerKmB,
                maxValue: costPerKmA > costPerKmB ? costPerKmA : costPerKmB,
                isWinner: winnerB,
                rupiah: rupiah,
              ),
            ],
          ),
        ),
        if (readyFull) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: winnerA ? AppEditorial.sageSoft : AppEditorial.brandSoft,
              borderRadius: BorderRadius.circular(AppEditorial.rCard),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.trophy,
                  color: winnerA ? AppEditorial.sage : AppEditorial.brandDeep,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        winnerLabel != null
                            ? '$winnerLabel lebih hemat ${dist.toStringAsFixed(0)} km'
                            : 'Biaya sama',
                        style: AppEditorial.heading(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: winnerA
                              ? AppEditorial.sage
                              : AppEditorial.brandDeep,
                        ),
                      ),
                      if (savings > 0)
                        Text(
                          'Hemat Rp ${rupiah.format(savings).trim()} per perjalanan',
                          style: AppEditorial.sans(
                            fontSize: 12.5,
                            color: AppEditorial.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TotalChip(
                  label: 'Total A',
                  value: 'Rp ${rupiah.format(totalA).trim()}',
                  color: AppEditorial.sage,
                  isWinner: winnerA),
              const SizedBox(width: 10),
              _TotalChip(
                  label: 'Total B',
                  value: 'Rp ${rupiah.format(totalB).trim()}',
                  color: AppEditorial.brandDeep,
                  isWinner: winnerB),
            ],
          ),
        ],
      ],
    );
  }
}

class _CostBar extends StatelessWidget {
  const _CostBar({
    required this.label,
    required this.color,
    required this.value,
    required this.maxValue,
    required this.isWinner,
    required this.rupiah,
  });
  final String label;
  final Color color;
  final double value, maxValue;
  final bool isWinner;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? value / maxValue : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: AppEditorial.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppEditorial.inkSoft)),
            const Spacer(),
            Text(
              'Rp ${rupiah.format(value).trim()}/km',
              style: AppEditorial.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isWinner ? color : AppEditorial.ink),
            ),
            if (isWinner) ...[
              const SizedBox(width: 6),
              Icon(PhosphorIconsRegular.checkCircle, size: 14, color: color),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: AppEditorial.hairline,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isWinner,
  });
  final String label, value;
  final Color color;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isWinner
              ? color.withValues(alpha: 0.08)
              : AppEditorial.cream,
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
          border: Border.all(
            color: isWinner ? color.withValues(alpha: 0.25) : AppEditorial.hairline,
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppEditorial.eyebrow(fontSize: 10, color: color)),
            const SizedBox(height: 4),
            Text(value,
                style: AppEditorial.mono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.ink)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.children,
    this.label,
    this.labelColor,
  });
  final List<Widget> children;
  final String? label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
              child: Text(
                label!,
                style: AppEditorial.eyebrow(
                    fontSize: 11,
                    color: labelColor ?? AppEditorial.inkMuted),
              ),
            )
          else
            const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: AppEditorial.hairlineSoft);
  }
}

class _CalcField extends StatelessWidget {
  const _CalcField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.prefix,
    this.suffix,
    this.hint,
    this.digitsOnly = false,
    this.stacked = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final String? prefix, suffix, hint;
  final bool digitsOnly;

  /// Layout vertikal (label di atas) — untuk kartu sempit.
  final bool stacked;

  Widget _field({required TextAlign align}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !digitsOnly),
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => onChanged(),
      textAlign: align,
      style: AppEditorial.mono(fontSize: 17, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixText: prefix == null ? null : '$prefix ',
        prefixStyle:
            AppEditorial.mono(fontSize: 14, color: AppEditorial.inkSoft),
        suffixText: suffix,
        suffixStyle:
            AppEditorial.mono(fontSize: 13, color: AppEditorial.inkMuted),
        hintText: hint,
        hintStyle: AppEditorial.mono(
            fontSize: 15,
            color: AppEditorial.inkMuted,
            fontWeight: FontWeight.w400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppEditorial.sans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppEditorial.inkSoft),
            ),
            _field(align: TextAlign.left),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppEditorial.sans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppEditorial.inkSoft),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _field(align: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _Chip {
  const _Chip({required this.icon, required this.label, required this.sub});
  final IconData icon;
  final String label, sub;
}

class _HeroResult extends StatelessWidget {
  const _HeroResult({
    super.key,
    required this.primaryLabel,
    required this.primaryValue,
    required this.primaryFormatter,
    required this.chips,
  });

  final String primaryLabel;
  final double primaryValue;
  final String Function(double) primaryFormatter;
  final List<_Chip> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppEditorial.brand,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.brandShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            primaryLabel.toUpperCase(),
            style: AppEditorial.eyebrow(
                fontSize: 11,
                color: AppEditorial.ink.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: AnimatedCount(
              value: primaryValue,
              formatter: primaryFormatter,
              style: AppEditorial.heading(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
                color: AppEditorial.ink,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((c) => _ResultChip(icon: c.icon, label: c.label, sub: c.sub))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.icon,
    required this.label,
    required this.sub,
  });
  final IconData icon;
  final String label, sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppEditorial.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppEditorial.ink.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppEditorial.heading(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.ink)),
              Text(sub,
                  style: AppEditorial.sans(
                      fontSize: 10.5,
                      color: AppEditorial.ink.withValues(alpha: 0.6))),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({super.key, required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppEditorial.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(PhosphorIconsRegular.calculator,
                color: AppEditorial.brandDeep, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(hint,
                style: AppEditorial.sans(
                    fontSize: 13, color: AppEditorial.inkMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _PresetsSection extends StatelessWidget {
  const _PresetsSection({
    required this.label,
    required this.chips,
    required this.onSelect,
  });
  final String label;
  final List<(String, String)> chips;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppEditorial.eyebrow(color: AppEditorial.inkMuted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips
              .map((c) => GestureDetector(
                    onTap: () => onSelect(c.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppEditorial.cream,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rPill),
                        border: Border.all(
                            color: AppEditorial.hairline, width: 1.2),
                      ),
                      child: Text(
                        c.$1,
                        style: AppEditorial.sans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppEditorial.ink),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fuel picker — bottom sheet pilih jenis BBM atau ketik harga sendiri
// ─────────────────────────────────────────────────────────────────────────────

class _FuelResult {
  const _FuelResult({this.idx, this.customPrice});
  final int? idx;
  final int? customPrice;
}

Future<_FuelResult?> _showFuelPicker(
  BuildContext context, {
  required List<_FuelOption> fuels,
  required int? currentIdx,
  required int currentPrice,
  required NumberFormat rupiah,
}) {
  return showModalBottomSheet<_FuelResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppEditorial.canvas,
    builder: (context) => _FuelPickerSheet(
      fuels: fuels,
      currentIdx: currentIdx,
      currentPrice: currentPrice,
      rupiah: rupiah,
    ),
  );
}

class _FuelPickerSheet extends StatefulWidget {
  const _FuelPickerSheet({
    required this.fuels,
    required this.currentIdx,
    required this.currentPrice,
    required this.rupiah,
  });
  final List<_FuelOption> fuels;
  final int? currentIdx;
  final int currentPrice;
  final NumberFormat rupiah;

  @override
  State<_FuelPickerSheet> createState() => _FuelPickerSheetState();
}

class _FuelPickerSheetState extends State<_FuelPickerSheet> {
  late final TextEditingController _custom;
  bool _customOpen = false;

  @override
  void initState() {
    super.initState();
    _customOpen = widget.currentIdx == null;
    _custom = TextEditingController(
      text: widget.currentIdx == null && widget.currentPrice > 0
          ? widget.currentPrice.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppEditorial.hairline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Pilih Jenis BBM',
                      style: AppEditorial.heading(fontSize: 17)),
                  const Spacer(),
                  Text('Harga master',
                      style: AppEditorial.sans(
                          fontSize: 11.5, color: AppEditorial.inkMuted)),
                ],
              ),
            ),
            for (var i = 0; i < widget.fuels.length; i++)
              _fuelRow(i, widget.fuels[i]),
            const Divider(
                height: 1, thickness: 1, color: AppEditorial.hairline),
            _customRow(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _fuelRow(int i, _FuelOption p) {
    final selected = widget.currentIdx == i;
    return InkWell(
      onTap: () => Navigator.of(context).pop(_FuelResult(idx: i)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppEditorial.brandSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(PhosphorIconsRegular.gasPump,
                  size: 18, color: AppEditorial.brandDeep),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: AppEditorial.heading(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  if (p.brand.isNotEmpty)
                    Text(
                        '${p.brand[0].toUpperCase()}${p.brand.substring(1)}',
                        style: AppEditorial.sans(
                            fontSize: 12, color: AppEditorial.inkMuted)),
                ],
              ),
            ),
            Text(
              'Rp ${widget.rupiah.format(p.price).trim()}',
              style: AppEditorial.mono(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsRegular.circle,
              size: 22,
              color: selected ? AppEditorial.ink : AppEditorial.hairline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _customRow() {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _customOpen = !_customOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppEditorial.canvasSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(PhosphorIconsRegular.pencilSimple,
                      size: 18, color: AppEditorial.inkSoft),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Ketik harga sendiri',
                      style: AppEditorial.heading(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Icon(
                  _customOpen
                      ? PhosphorIconsRegular.caretUp
                      : PhosphorIconsRegular.caretDown,
                  size: 18,
                  color: AppEditorial.inkMuted,
                ),
              ],
            ),
          ),
        ),
        if (_customOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _custom,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: AppEditorial.mono(
                        fontSize: 17, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '10.000',
                      suffixText: '/L',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    final v = int.tryParse(_custom.text) ?? 0;
                    Navigator.of(context).pop(_FuelResult(customPrice: v));
                  },
                  child: const Text('Pakai'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fuel price field — baris dalam input card yang membuka picker
// ─────────────────────────────────────────────────────────────────────────────

class _FuelPriceField extends StatelessWidget {
  const _FuelPriceField({
    required this.label,
    required this.fuels,
    required this.fuelIdx,
    required this.price,
    required this.rupiah,
    required this.onTap,
    this.stacked = false,
  });

  final String label;
  final List<_FuelOption> fuels;
  final int? fuelIdx; // null = harga sendiri
  final double price;
  final NumberFormat rupiah;
  final VoidCallback onTap;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final name = (fuelIdx == null || fuelIdx! >= fuels.length)
        ? 'Harga sendiri'
        : fuels[fuelIdx!].name;
    final priceStr = price > 0 ? 'Rp ${rupiah.format(price).trim()} /L' : '—';

    if (stacked) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppEditorial.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppEditorial.inkSoft)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppEditorial.heading(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(priceStr,
                            style: AppEditorial.mono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppEditorial.inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsRegular.caretDown,
                      size: 16, color: AppEditorial.inkMuted),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(label,
                  style: AppEditorial.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppEditorial.inkSoft)),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 7,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppEditorial.canvasSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(name,
                                style: AppEditorial.heading(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          const Icon(PhosphorIconsRegular.caretDown,
                              size: 13, color: AppEditorial.inkMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(priceStr,
                      style: AppEditorial.mono(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
