import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Add refuel form — feels like a fuel pump terminal: numbered fields,
/// big pump-LCD nominal display, computed result block.
class AddRefuelTab extends StatefulWidget {
  const AddRefuelTab({super.key, this.prefill});

  final ParsedRefuel? prefill;

  @override
  State<AddRefuelTab> createState() => _AddRefuelTabState();
}

class _AddRefuelTabState extends State<AddRefuelTab> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _totalController = TextEditingController();
  final _litersController = TextEditingController();

  DateTime _refuelDate = DateTime.now();
  String? _vehicleId;
  String? _fuelProductId;
  bool _saving = false;
  bool _isEceran = false;
  String? _error;

  List<Vehicle> _vehicles = [];

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();

    final prefill = widget.prefill;
    if (prefill != null) {
      _refuelDate = DateTime(
        prefill.refuelDate.year,
        prefill.refuelDate.month,
        prefill.refuelDate.day,
      );
      if (prefill.vehicleId.isNotEmpty) _vehicleId = prefill.vehicleId;
      if (prefill.fuelProductId.isNotEmpty) {
        _fuelProductId = prefill.fuelProductId;
      }
      if (prefill.totalRp > 0) {
        _totalController.text = prefill.totalRp.toInt().toString();
      }
    }

    if (_fuelProductId == null) {
      final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
      final prefFuel = meta?['preferred_fuel_id'];
      if (prefFuel is String && prefFuel.isNotEmpty) {
        _fuelProductId = prefFuel;
      }
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    _litersController.dispose();
    super.dispose();
  }

  num? _parseNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned);
  }

  /// Parse a decimal liters value (allows comma or dot).
  double? _parseLiters(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final v = double.tryParse(cleaned);
    if (v == null || v <= 0) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppEditorial.ink,
      backgroundColor: AppEditorial.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 60),
        children: [
          // §01 Tanggal
          _Section(
            index: '01',
            label: 'TANGGAL',
            child: _DateField(
              date: _refuelDate,
              dateFmt: _dateFmt,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _refuelDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now()
                      .add(const Duration(days: 365)),
                );
                if (picked == null || !mounted) return;
                setState(() => _refuelDate = picked);
              },
            ),
          ),
          const SizedBox(height: 24),

          // §02 Kendaraan
          _Section(
            index: '02',
            label: 'KENDARAAN',
            child: FutureBuilder<List<Vehicle>>(
              future: _repo.listVehicles(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorBox(message: snapshot.error.toString());
                }
                final vehicles = snapshot.data;
                if (vehicles == null) return const _LoadingLine();
                if (vehicles.isEmpty) {
                  return const _ErrorBox(
                    message:
                        'Belum ada kendaraan. Tambahkan di tab Profil.',
                  );
                }
                _vehicles = vehicles;
                _vehicleId ??= vehicles.first.id;
                return _VehiclePicker(
                  vehicles: vehicles,
                  selectedId: _vehicleId,
                  onChanged: (v) => setState(() => _vehicleId = v),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // §03 BBM
          _Section(
            index: '03',
            label: 'JENIS BBM',
            child: FutureBuilder<List<FuelProduct>>(
              future: _repo.listFuelProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorBox(message: snapshot.error.toString());
                }
                final products = snapshot.data;
                if (products == null) return const _LoadingLine();
                if (products.isEmpty) {
                  return const _ErrorBox(
                    message: 'Master BBM kosong di server.',
                  );
                }
                _fuelProductId ??= products.first.id;
                return _FuelDropdown(
                  products: products,
                  selectedId: _fuelProductId,
                  onChanged: (v) => setState(() => _fuelProductId = v),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Eceran toggle — when on, the user fills liters manually because
          // bottled/eceran fuel has no fixed pump price-per-liter.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            decoration: BoxDecoration(
              color: _isEceran ? AppEditorial.butterSoft : AppEditorial.cream,
              border: Border.all(
                color: _isEceran
                    ? AppEditorial.butterDeep
                    : AppEditorial.hairlineSoft,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppEditorial.rCard),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.drop,
                    size: 18, color: AppEditorial.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bensin eceran',
                        style: AppEditorial.heading(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Isi harga & liter manual',
                        style: AppEditorial.sans(
                          fontSize: 11,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isEceran,
                  onChanged: (v) => setState(() => _isEceran = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // §04 Nominal — pump LCD style
          _Section(
            index: '04',
            label: 'NOMINAL (RUPIAH)',
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom:
                      BorderSide(color: AppEditorial.ink, width: 1.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Always-visible "Rp" prefix (InputDecoration.prefixText
                  // only shows when the field is focused/non-empty).
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    child: Text(
                      'Rp',
                      style: AppEditorial.mono(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppEditorial.inkSoft,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _totalController,
                      keyboardType: TextInputType.number,
                      style: AppEditorial.mono(
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: AppEditorial.mono(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: AppEditorial.inkMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // §05 Liter — manual input, ONLY for eceran.
          if (_isEceran) ...[
            _Section(
              index: '05',
              label: 'JUMLAH LITER',
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(color: AppEditorial.ink, width: 1.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _litersController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: AppEditorial.mono(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.0',
                          hintStyle: AppEditorial.mono(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: AppEditorial.inkMuted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        'L',
                        style: AppEditorial.mono(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Computed price/liter from total ÷ liters.
            _EceranComputedBlock(
              total: _parseNumber(_totalController.text),
              liters: _parseLiters(_litersController.text),
              rupiah: _rupiah,
            ),
          ] else
            // §05 Hasil hitung (SPBU) — auto from master price.
            if (_vehicleId != null && _fuelProductId != null)
              FutureBuilder<FuelPrice?>(
                future: _repo.getFuelPrice(
                  fuelProductId: _fuelProductId!,
                  onDate: _refuelDate,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorBox(message: snapshot.error.toString());
                  }
                  final price = snapshot.data;
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _LoadingLine();
                  }
                  if (price == null) {
                    return const _ErrorBox(
                      message:
                          'Harga BBM belum di-set untuk tanggal ini. '
                          'Aktifkan "Bensin eceran" untuk isi liter manual.',
                    );
                  }
                  return _ComputedBlock(
                    pricePerLiter: price.pricePerLiter,
                    total: _parseNumber(_totalController.text),
                    rupiah: _rupiah,
                  );
                },
              ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : () => _save(context),
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppEditorial.canvas,
                    ),
                  )
                : const Text('Simpan pengisian'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBox(message: _error!),
          ],
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final vehicleId = _vehicleId;
      final fuelProductId = _fuelProductId;
      if (vehicleId == null) throw StateError('Pilih kendaraan');
      if (fuelProductId == null) throw StateError('Pilih jenis BBM');

      final total = _parseNumber(_totalController.text);
      if (total == null) throw StateError('Nominal wajib diisi');

      final double pricePerLiter;
      final double liters;

      if (_isEceran) {
        // Eceran: user provides liters, price/liter is derived.
        final manualLiters = _parseLiters(_litersController.text);
        if (manualLiters == null) {
          throw StateError('Jumlah liter wajib diisi untuk eceran');
        }
        liters = manualLiters;
        pricePerLiter = total / liters;
      } else {
        // SPBU: look up master price, derive liters.
        final price = await _repo.getFuelPrice(
          fuelProductId: fuelProductId,
          onDate: _refuelDate,
        );
        if (price == null) {
          throw StateError(
            'Harga BBM belum ada untuk tanggal ini. '
            'Aktifkan "Bensin eceran" untuk isi liter manual.',
          );
        }
        if (price.pricePerLiter <= 0) {
          throw StateError('Harga per liter tidak valid');
        }
        pricePerLiter = price.pricePerLiter.toDouble();
        liters = total / pricePerLiter;
      }

      final selectedVehicle =
          _vehicles.where((v) => v.id == vehicleId).firstOrNull;
      final tankCap = selectedVehicle?.tankCapacityLiters;
      if (tankCap != null && liters > tankCap) {
        throw StateError(
          'Liter (${liters.toStringAsFixed(2)} L) melebihi kapasitas tanki ($tankCap L).',
        );
      }

      final isFullTank =
          tankCap != null ? (liters / tankCap >= 0.95) : false;

      await _repo.createRefuel(
        vehicleId: vehicleId,
        fuelProductId: fuelProductId,
        refuelDate: DateTime(
          _refuelDate.year,
          _refuelDate.month,
          _refuelDate.day,
        ),
        odometerKm: null,
        totalRp: total,
        pricePerLiterSnapshot: pricePerLiter,
        liters: liters,
        isFullTank: isFullTank,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Tersimpan ✓')),
      );
      navigator.pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.label,
    required this.child,
  });
  final String index;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(index: index, label: label),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.dateFmt,
    required this.onTap,
  });
  final DateTime date;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppEditorial.rButton),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppEditorial.canvasSoft,
          borderRadius: BorderRadius.circular(AppEditorial.rButton),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsRegular.calendarBlank,
                color: AppEditorial.inkSoft, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                dateFmt.format(date),
                style: AppEditorial.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(PhosphorIconsRegular.caretDown,
                color: AppEditorial.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({
    required this.vehicles,
    required this.selectedId,
    required this.onChanged,
  });
  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: vehicles.map((v) {
        final selected = selectedId == v.id;
        return GestureDetector(
          onTap: () => onChanged(v.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppEditorial.ink : AppEditorial.canvasSoft,
              borderRadius: BorderRadius.circular(AppEditorial.rPill),
            ),
            child: Text(
              '${v.type.label} · ${v.name}',
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
      }).toList(),
    );
  }
}

class _FuelDropdown extends StatelessWidget {
  const _FuelDropdown({
    required this.products,
    required this.selectedId,
    required this.onChanged,
  });
  final List<FuelProduct> products;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppEditorial.canvasSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rButton),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedId,
          icon: const Icon(PhosphorIconsRegular.caretDown,
              color: AppEditorial.inkSoft),
          dropdownColor: AppEditorial.cream,
          borderRadius: BorderRadius.circular(AppEditorial.rButton),
          style: AppEditorial.sans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppEditorial.ink,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          items: products
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(p.label),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ComputedBlock extends StatelessWidget {
  const _ComputedBlock({
    required this.pricePerLiter,
    required this.total,
    required this.rupiah,
  });
  final num pricePerLiter;
  final num? total;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final liters = (total == null || pricePerLiter <= 0)
        ? null
        : (total! / pricePerLiter);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppEditorial.butterSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Auto Hitung',
                  style: AppEditorial.heading(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.butterDeep,
                  )),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppEditorial.butter,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liters == null ? '—' : liters.toStringAsFixed(3),
                      style: AppEditorial.heading(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('LITER',
                        style: AppEditorial.eyebrow(
                            color: AppEditorial.butterDeep)),
                  ],
                ),
              ),
              Container(
                  width: 1, height: 52, color: AppEditorial.butter),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rupiah.format(pricePerLiter).trim(),
                      style: AppEditorial.heading(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('HARGA / L',
                        style: AppEditorial.eyebrow(
                            color: AppEditorial.butterDeep)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Eceran result block — liters are user-provided, price/liter is derived
/// (total ÷ liters) since bottled/eceran fuel has no fixed pump price.
class _EceranComputedBlock extends StatelessWidget {
  const _EceranComputedBlock({
    required this.total,
    required this.liters,
    required this.rupiah,
  });
  final num? total;
  final double? liters;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final pricePerLiter = (total == null || liters == null || liters! <= 0)
        ? null
        : (total! / liters!);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppEditorial.butterSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Eceran',
                  style: AppEditorial.heading(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.butterDeep,
                  )),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppEditorial.butter,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liters == null ? '—' : liters!.toStringAsFixed(2),
                      style: AppEditorial.heading(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('LITER (MANUAL)',
                        style: AppEditorial.eyebrow(
                            color: AppEditorial.butterDeep)),
                  ],
                ),
              ),
              Container(width: 1, height: 52, color: AppEditorial.butter),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pricePerLiter == null
                          ? '—'
                          : rupiah.format(pricePerLiter).trim(),
                      style: AppEditorial.heading(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('HARGA / L',
                        style: AppEditorial.eyebrow(
                            color: AppEditorial.butterDeep)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppEditorial.ink,
          ),
        ),
        const SizedBox(width: 12),
        Text('memuat...',
            style: AppEditorial.sans(
              fontSize: 13,
              color: AppEditorial.inkSoft,
            )),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppEditorial.rustSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rButton),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsRegular.warningCircle,
              color: AppEditorial.rust, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.rust,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
