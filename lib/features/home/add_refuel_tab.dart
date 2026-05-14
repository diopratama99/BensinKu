import 'package:flutter/material.dart';
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

  DateTime _refuelDate = DateTime.now();
  String? _vehicleId;
  String? _fuelProductId;
  bool _saving = false;
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
    super.dispose();
  }

  num? _parseNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned);
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
                  prefixText: 'Rp ',
                  prefixStyle: AppEditorial.mono(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppEditorial.inkSoft,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // §05 Hasil hitung — looks like a printed receipt
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingLine();
                }
                if (price == null) {
                  return const _ErrorBox(
                    message:
                        'Harga BBM belum di-set untuk tanggal ini. Hubungi admin.',
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
                : const Text('SIMPAN PENGISIAN →'),
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

      final price = await _repo.getFuelPrice(
        fuelProductId: fuelProductId,
        onDate: _refuelDate,
      );
      if (price == null) {
        throw StateError('Harga BBM belum ada untuk tanggal ini');
      }

      final pricePerLiter = price.pricePerLiter;
      if (pricePerLiter <= 0) {
        throw StateError('Harga per liter tidak valid');
      }

      final liters = total / pricePerLiter;

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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppEditorial.hairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dateFmt.format(date),
                style: AppEditorial.mono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.event_outlined,
                color: AppEditorial.inkSoft, size: 20),
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
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppEditorial.ink : AppEditorial.canvas,
              border: Border.all(color: AppEditorial.ink, width: 1),
              borderRadius: BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: Text(
              '${v.type.label.toUpperCase()} · ${v.name}',
              style: AppEditorial.mono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppEditorial.canvas
                    : AppEditorial.ink,
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppEditorial.hairline, width: 1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedId,
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppEditorial.inkSoft),
          dropdownColor: AppEditorial.cream,
          style: AppEditorial.mono(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppEditorial.butter,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('AUTO HITUNG', style: AppEditorial.eyebrow()),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppEditorial.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liters == null ? '—' : liters.toStringAsFixed(3),
                      style: AppEditorial.mono(
                        fontSize: 36,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('LITER', style: AppEditorial.eyebrow()),
                  ],
                ),
              ),
              Container(
                  width: 1, height: 56, color: AppEditorial.ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rupiah.format(pricePerLiter).trim(),
                      style: AppEditorial.mono(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('HARGA / L', style: AppEditorial.eyebrow()),
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
        color: AppEditorial.canvas,
        border: Border.all(color: AppEditorial.rust, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
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
