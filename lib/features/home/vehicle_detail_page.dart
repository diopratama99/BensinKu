import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../widgets/vehicle_cover.dart';

/// Vehicle detail — spec sheet style.
class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  final _repo = SupabaseRepository.ofDefaultClient();

  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  late TextEditingController _nameCtrl;
  late VehicleType _type;
  late TextEditingController _tankCtrl;
  late TextEditingController _engineCcCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _makeModelCtrl;
  BodyType? _bodyType;
  Transmission? _transmission;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.vehicle.name);
    _type = widget.vehicle.type;
    _tankCtrl = TextEditingController(
      text: widget.vehicle.tankCapacityLiters?.toString() ?? '',
    );
    _engineCcCtrl = TextEditingController(
      text: widget.vehicle.engineCc?.toString() ?? '',
    );
    _yearCtrl = TextEditingController(
      text: widget.vehicle.manufacturingYear?.toString() ?? '',
    );
    _makeModelCtrl = TextEditingController(
      text: widget.vehicle.makeModel ?? '',
    );
    _bodyType = widget.vehicle.bodyType;
    _transmission = widget.vehicle.transmission;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tankCtrl.dispose();
    _engineCcCtrl.dispose();
    _yearCtrl.dispose();
    _makeModelCtrl.dispose();
    super.dispose();
  }

  void _resetEdits() {
    _nameCtrl.text = widget.vehicle.name;
    _type = widget.vehicle.type;
    _tankCtrl.text = widget.vehicle.tankCapacityLiters?.toString() ?? '';
    _engineCcCtrl.text = widget.vehicle.engineCc?.toString() ?? '';
    _yearCtrl.text = widget.vehicle.manufacturingYear?.toString() ?? '';
    _makeModelCtrl.text = widget.vehicle.makeModel ?? '';
    _bodyType = widget.vehicle.bodyType;
    _transmission = widget.vehicle.transmission;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama wajib diisi')),
      );
      return;
    }
    final tank = double.tryParse(_tankCtrl.text.trim());
    final engineCc = int.tryParse(
        _engineCcCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final year = int.tryParse(
        _yearCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final makeModel = _makeModelCtrl.text.trim();

    if (engineCc != null && (engineCc < 50 || engineCc > 9999)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CC mesin harus 50–9999')),
      );
      return;
    }
    if (year != null && (year < 1980 || year > 2035)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahun produksi harus 1980–2035')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.updateVehicle(
        id: widget.vehicle.id,
        name: name,
        type: _type,
        tankCapacityLiters: tank,
        engineCc: engineCc,
        manufacturingYear: year,
        bodyType: _bodyType,
        transmission: _transmission,
        makeModel: makeModel.isEmpty ? null : makeModel,
      );
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tersimpan ✓')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Hapus kendaraan?',
          style: AppEditorial.mono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '"${widget.vehicle.name}" akan dihapus permanen.',
          style: AppEditorial.sans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppEditorial.rust),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _repo.deleteVehicle(widget.vehicle.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _editing ? 'EDIT KENDARAAN' : 'DETAIL KENDARAAN',
          style: AppEditorial.mono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        actions: [
          if (_editing)
            TextButton(
              onPressed: () => setState(() {
                _editing = false;
                _resetEdits();
              }),
              child: const Text('BATAL'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // Cover
          VehicleCover(
            vehicle: widget.vehicle,
            height: 180,
            borderRadius: AppEditorial.rCard,
          ),
          const SizedBox(height: 16),

          // Identity
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppEditorial.butter,
                  borderRadius:
                      BorderRadius.circular(AppEditorial.rTiny),
                ),
                child: Text(
                  _type.label.toUpperCase(),
                  style: AppEditorial.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.vehicle.id.substring(0, 8).toUpperCase(),
                style: AppEditorial.mono(
                  fontSize: 10.5,
                  color: AppEditorial.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.vehicle.makeModel?.isNotEmpty == true
                ? widget.vehicle.makeModel!
                : widget.vehicle.name,
            style: AppEditorial.mono(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          if (widget.vehicle.makeModel?.isNotEmpty == true &&
              widget.vehicle.makeModel != widget.vehicle.name)
            Text(
              widget.vehicle.name,
              style: AppEditorial.mono(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
          if (widget.vehicle.tankCapacityLiters != null)
            Text(
              'kapasitas tanki ${widget.vehicle.tankCapacityLiters} L',
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
          const SizedBox(height: 24),
          Container(height: 1, color: AppEditorial.hairline),
          const SizedBox(height: 24),

          if (_editing) _buildEditForm() else _buildViewMode(),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EditorialSectionHeader(index: '01', label: 'JENIS'),
        const SizedBox(height: 10),
        Row(
          children: VehicleType.values.map((tp) {
            final selected = _type == tp;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: tp == VehicleType.motor ? 10 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _type = tp),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppEditorial.ink
                          : AppEditorial.canvas,
                      border:
                          Border.all(color: AppEditorial.ink, width: 1),
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rTiny),
                    ),
                    child: Text(
                      tp.label.toUpperCase(),
                      style: AppEditorial.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppEditorial.canvas
                            : AppEditorial.ink,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'NAMA KENDARAAN',
            hintText: 'Vario 2015',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _tankCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: const InputDecoration(
            labelText: 'KAPASITAS TANKI',
            hintText: '5.5',
            suffixText: 'L',
          ),
        ),
        const SizedBox(height: 28),
        // Detail mesin
        Container(height: 1, color: AppEditorial.hairline),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('DETAIL MESIN', style: AppEditorial.eyebrow()),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppEditorial.butterSoft,
                borderRadius:
                    BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Text(
                'OPSIONAL',
                style: AppEditorial.mono(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.butterDeep,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _engineCcCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'CC MESIN',
                  hintText: '125',
                  suffixText: 'cc',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _yearCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'TAHUN',
                  hintText: '2020',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _makeModelCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'MERK / MODEL',
            hintText: 'Honda Vario 125',
          ),
        ),
        if (_type == VehicleType.mobil) ...[
          const SizedBox(height: 22),
          Text('TIPE BODI', style: AppEditorial.eyebrow()),
          const SizedBox(height: 8),
          _PillPicker<BodyType>(
            value: _bodyType,
            options: BodyType.values,
            labelOf: (v) => v.label.toUpperCase(),
            onChange: (v) => setState(() => _bodyType = v),
          ),
        ],
        const SizedBox(height: 22),
        Text('TRANSMISI', style: AppEditorial.eyebrow()),
        const SizedBox(height: 8),
        _PillPicker<Transmission>(
          value: _transmission,
          options: Transmission.values,
          labelOf: (v) => v.label,
          onChange: (v) => setState(() => _transmission = v),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppEditorial.canvas,
                  ),
                )
              : const Text('SIMPAN PERUBAHAN →'),
        ),
      ],
    );
  }

  Widget _buildViewMode() {
    final v = widget.vehicle;
    final hasSpec = v.engineCc != null ||
        v.manufacturingYear != null ||
        v.bodyType != null ||
        v.transmission != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSpec) ...[
          const EditorialSectionHeader(
              index: '01', label: 'SPESIFIKASI'),
          const SizedBox(height: 12),
          if (v.engineCc != null)
            EditorialDataRow(
              label: 'CC mesin',
              value: '${v.engineCc} cc',
            ),
          if (v.manufacturingYear != null)
            EditorialDataRow(
              label: 'Tahun produksi',
              value: '${v.manufacturingYear}',
            ),
          if (v.bodyType != null)
            EditorialDataRow(
              label: 'Tipe bodi',
              value: v.bodyType!.label,
            ),
          if (v.transmission != null)
            EditorialDataRow(
              label: 'Transmisi',
              value: v.transmission!.label,
              isLast: true,
            ),
          const SizedBox(height: 24),
        ],
        _StatsBlock(
          vehicleId: widget.vehicle.id,
          rupiah: _rupiah,
          headerIndex: hasSpec ? '02' : '01',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('EDIT KENDARAAN'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _deleting ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded,
              size: 16, color: AppEditorial.rust),
          label: Text(
            _deleting ? 'MENGHAPUS...' : 'HAPUS KENDARAAN',
            style: const TextStyle(color: AppEditorial.rust),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppEditorial.rust, width: 1),
          ),
        ),
      ],
    );
  }
}

class _StatsBlock extends StatelessWidget {
  const _StatsBlock({
    required this.vehicleId,
    required this.rupiah,
    this.headerIndex = '01',
  });
  final String vehicleId;
  final NumberFormat rupiah;
  final String headerIndex;

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository.ofDefaultClient();

    return FutureBuilder<(List<Refuel>, List<Trip>)>(
      future: () async {
        final res = await Future.wait([
          repo.listRefuels(vehicleId: vehicleId),
          repo.listTrips(vehicleId: vehicleId),
        ]);
        return (res[0] as List<Refuel>, res[1] as List<Trip>);
      }(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final refuels = snap.data!.$1;
        final trips = snap.data!.$2;

        final totalSpend =
            refuels.fold<double>(0, (s, r) => s + r.totalRp);
        final totalLiters =
            refuels.fold<double>(0, (s, r) => s + r.liters);
        final totalKm =
            trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
        final kmL = (totalKm > 0 && totalLiters > 0)
            ? totalKm / totalLiters
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EditorialSectionHeader(
                index: headerIndex, label: 'STATISTIK ALL-TIME'),
            const SizedBox(height: 12),
            EditorialDataRow(
              label: 'Total pengeluaran',
              value: 'Rp ${rupiah.format(totalSpend).trim()}',
            ),
            EditorialDataRow(
              label: 'Jumlah pengisian',
              value: '${refuels.length}×',
            ),
            EditorialDataRow(
              label: 'Total liter',
              value: '${totalLiters.toStringAsFixed(2)} L',
            ),
            EditorialDataRow(
              label: 'Jarak GPS',
              value: '${totalKm.toStringAsFixed(1)} km',
            ),
            EditorialDataRow(
              label: 'Efisiensi',
              value:
                  kmL != null ? '${kmL.toStringAsFixed(1)} km/L' : '—',
              isLast: true,
              valueStyle: AppEditorial.mono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppEditorial.butterDeep,
                tabular: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Single-select pill picker. Tapping the active pill clears it (null).
class _PillPicker<T> extends StatelessWidget {
  const _PillPicker({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChange,
  });

  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = value == opt;
        return GestureDetector(
          onTap: () => onChange(selected ? null : opt),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppEditorial.ink : AppEditorial.canvas,
              border: Border.all(color: AppEditorial.ink, width: 1),
              borderRadius:
                  BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: Text(
              labelOf(opt),
              style: AppEditorial.mono(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppEditorial.canvas
                    : AppEditorial.ink,
                letterSpacing: 0.4,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
