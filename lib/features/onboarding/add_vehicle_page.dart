import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'setup_preferences_page.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({
    super.key,
    this.goHomeOnComplete = false,
    this.onCompleted,
  });

  final bool goHomeOnComplete;

  /// When provided (and `goHomeOnComplete` is true), called after a
  /// successful create instead of pushing the next route. Used by the
  /// auth gate to re-evaluate routing.
  final VoidCallback? onCompleted;

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _repo = SupabaseRepository.ofDefaultClient();

  VehicleType? _type;
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _engineCcController = TextEditingController();
  final _yearController = TextEditingController();
  final _makeModelController = TextEditingController();

  BodyType? _bodyType;
  Transmission? _transmission;

  bool _saving = false;
  bool _detailExpanded = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _engineCcController.dispose();
    _yearController.dispose();
    _makeModelController.dispose();
    super.dispose();
  }

  num? _parseNum(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned);
  }

  int? _parseInt(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  Future<void> _create(List<Vehicle> existing) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final type = _type;
      if (type == null) throw StateError('Pilih jenis kendaraan');
      if (existing.any((v) => v.type == type)) {
        throw StateError('${type.label} sudah ada (limit 1 per jenis).');
      }

      final name = _nameController.text.trim();
      final capacity = _parseNum(_capacityController.text);
      final engineCc = _parseInt(_engineCcController.text);
      final year = _parseInt(_yearController.text);
      final makeModel = _makeModelController.text.trim();

      // Required reference data — wajib diisi supaya prediksi akurat dari
      // hari pertama. Field opsional (RON, make/model) tetap boleh kosong.
      if (name.isEmpty) {
        throw StateError('Nama kendaraan wajib diisi.');
      }
      if (capacity == null || capacity <= 0) {
        throw StateError('Kapasitas tanki wajib diisi.');
      }
      if (engineCc == null) {
        throw StateError('CC mesin wajib diisi.');
      }
      if (engineCc < 50 || engineCc > 9999) {
        throw StateError('CC mesin harus 50–9999.');
      }
      if (year == null) {
        throw StateError('Tahun produksi wajib diisi.');
      }
      if (year < 1980 || year > 2035) {
        throw StateError('Tahun produksi harus 1980–2035.');
      }
      if (_transmission == null) {
        throw StateError('Pilih jenis transmisi.');
      }
      if (type == VehicleType.mobil && _bodyType == null) {
        throw StateError('Pilih tipe bodi mobil.');
      }

      await _repo.createVehicle(
        type: type,
        name: name,
        tankCapacityLiters: capacity,
        engineCc: engineCc,
        manufacturingYear: year,
        bodyType: _bodyType,
        transmission: _transmission,
        makeModel: makeModel.isEmpty ? null : makeModel,
      );

      if (!mounted) return;
      if (widget.goHomeOnComplete) {
        if (widget.onCompleted != null) {
          // Auth-gate flow: signal completion, gate re-evaluates routing.
          widget.onCompleted!();
        } else {
          // Linear onboarding fallback (legacy).
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => const SetupPreferencesPage()),
            (route) => false,
          );
        }
      } else {
        Navigator.of(context).pop(true);
      }
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inOnboarding = widget.goHomeOnComplete;
    return PopScope(
      canPop: !inOnboarding,
      child: Scaffold(
        backgroundColor: AppEditorial.canvas,
        appBar: AppBar(
          leading: inOnboarding
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          automaticallyImplyLeading: !inOnboarding,
        ),
      body: FutureBuilder<List<Vehicle>>(
        future: _repo.listVehicles(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _CenteredMessage(
              title: 'ERROR',
              subtitle: snap.error.toString(),
            );
          }

          final vehicles = snap.data;
          if (vehicles == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppEditorial.ink));
          }

          final hasMotor = vehicles.any((v) => v.type == VehicleType.motor);
          final hasMobil = vehicles.any((v) => v.type == VehicleType.mobil);
          final canAdd = !(hasMotor && hasMobil);

          if (!hasMotor && !hasMobil) _type ??= VehicleType.motor;
          if (!hasMotor && hasMobil) _type ??= VehicleType.motor;
          if (hasMotor && !hasMobil) _type ??= VehicleType.mobil;
          if (hasMotor && hasMobil) _type = null;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                Row(
                  children: [
                    Text(
                      widget.goHomeOnComplete
                          ? 'STEP 02/02 · KENDARAAN'
                          : 'TAMBAH KENDARAAN',
                      style: AppEditorial.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppEditorial.butterDeep,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Hero illustration
                AspectRatio(
                  aspectRatio: 1080 / 800,
                  child: Image.asset(
                    'assets/illustrations/onboarding_tank.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Tambah kendaraan harianmu.',
                  style: AppEditorial.mono(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Maksimal 1 motor + 1 mobil. Cukup untuk pemakaian harian.',
                  style: AppEditorial.sans(
                    fontSize: 13,
                    color: AppEditorial.inkSoft,
                  ),
                ),
                const SizedBox(height: 28),
                Container(height: 1, color: AppEditorial.ink),
                const SizedBox(height: 24),

                Text('JENIS', style: AppEditorial.eyebrow()),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TypePill(
                        label: 'MOTOR',
                        active: _type == VehicleType.motor,
                        disabled: hasMotor,
                        onTap: () =>
                            setState(() => _type = VehicleType.motor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TypePill(
                        label: 'MOBIL',
                        active: _type == VehicleType.mobil,
                        disabled: hasMobil,
                        onTap: () =>
                            setState(() => _type = VehicleType.mobil),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _nameController,
                  enabled: canAdd,
                  style: AppEditorial.mono(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'NAMA KENDARAAN',
                    hintText: 'Vario / Avanza',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _capacityController,
                  enabled: canAdd,
                  keyboardType: TextInputType.number,
                  style: AppEditorial.mono(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'KAPASITAS TANKI',
                    hintText: '5 atau 40',
                    suffixText: 'L',
                  ),
                ),

                const SizedBox(height: 24),
                _DetailMesinSection(
                  enabled: canAdd,
                  vehicleType: _type,
                  expanded: _detailExpanded,
                  onExpandToggle: () => setState(
                      () => _detailExpanded = !_detailExpanded),
                  engineCcController: _engineCcController,
                  yearController: _yearController,
                  makeModelController: _makeModelController,
                  bodyType: _bodyType,
                  transmission: _transmission,
                  onBodyTypeChange: (v) =>
                      setState(() => _bodyType = v),
                  onTransmissionChange: (v) =>
                      setState(() => _transmission = v),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppEditorial.rust, width: 1),
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rTiny),
                    ),
                    child: Text(
                      _error!,
                      style: AppEditorial.sans(
                        fontSize: 12.5,
                        color: AppEditorial.rust,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed:
                      (!canAdd || _saving) ? null : () => _create(vehicles),
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppEditorial.canvas,
                          ),
                        )
                      : Text(!canAdd
                          ? 'LIMIT TERCAPAI'
                          : 'SIMPAN & LANJUT →'),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.active,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? AppEditorial.inkMuted
        : (active ? AppEditorial.canvas : AppEditorial.ink);
    final bg = disabled
        ? AppEditorial.cream
        : (active ? AppEditorial.ink : AppEditorial.canvas);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: disabled ? AppEditorial.hairline : AppEditorial.ink,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
        ),
        child: Text(
          disabled ? '$label (ADA)' : label,
          style: AppEditorial.mono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppEditorial.mono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail mesin — collapsible section. Optional, tapi diisi = prediksi lebih
// akurat sejak hari pertama (anti cold-start).
// ─────────────────────────────────────────────────────────────────────────────

class _DetailMesinSection extends StatelessWidget {
  const _DetailMesinSection({
    required this.enabled,
    required this.vehicleType,
    required this.expanded,
    required this.onExpandToggle,
    required this.engineCcController,
    required this.yearController,
    required this.makeModelController,
    required this.bodyType,
    required this.transmission,
    required this.onBodyTypeChange,
    required this.onTransmissionChange,
  });

  final bool enabled;
  final VehicleType? vehicleType;
  final bool expanded;
  final VoidCallback onExpandToggle;

  final TextEditingController engineCcController;
  final TextEditingController yearController;
  final TextEditingController makeModelController;

  final BodyType? bodyType;
  final Transmission? transmission;

  final ValueChanged<BodyType?> onBodyTypeChange;
  final ValueChanged<Transmission?> onTransmissionChange;

  @override
  Widget build(BuildContext context) {
    final isMobil = vehicleType == VehicleType.mobil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: enabled ? onExpandToggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text('DETAIL MESIN',
                    style: AppEditorial.eyebrow()),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppEditorial.rust.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rTiny),
                  ),
                  child: Text(
                    'WAJIB',
                    style: AppEditorial.mono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.rust,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: AppEditorial.ink,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Diperlukan untuk prediksi konsumsi yang akurat sejak awal.',
          style: AppEditorial.sans(
            fontSize: 11.5,
            color: AppEditorial.inkSoft,
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 18),
          // CC mesin + tahun produksi side-by-side
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: engineCcController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  style: AppEditorial.mono(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'CC MESIN',
                    hintText: '125 atau 1500',
                    suffixText: 'cc',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: yearController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  style: AppEditorial.mono(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'TAHUN',
                    hintText: '2020',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Make/model bebas (opsional — informational only)
          TextField(
            controller: makeModelController,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            style: AppEditorial.mono(
                fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'MERK / MODEL · OPSIONAL',
              hintText: 'Honda Vario 125',
            ),
          ),
          if (isMobil) ...[
            const SizedBox(height: 22),
            Text('TIPE BODI', style: AppEditorial.eyebrow()),
            const SizedBox(height: 8),
            _EnumPicker<BodyType>(
              enabled: enabled,
              value: bodyType,
              options: BodyType.values,
              labelOf: (v) => v.label.toUpperCase(),
              onChange: onBodyTypeChange,
            ),
          ],
          const SizedBox(height: 22),
          Text('TRANSMISI', style: AppEditorial.eyebrow()),
          const SizedBox(height: 8),
          _EnumPicker<Transmission>(
            enabled: enabled,
            value: transmission,
            options: Transmission.values,
            labelOf: (v) => v.label,
            onChange: onTransmissionChange,
          ),
        ],
      ],
    );
  }
}

/// Pill-style single-select picker untuk enum. Tap pada pill yang aktif
/// akan deselect (kembali ke null) — semua field di section ini opsional.
class _EnumPicker<T> extends StatelessWidget {
  const _EnumPicker({
    required this.enabled,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChange,
  });

  final bool enabled;
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
          onTap: enabled
              ? () => onChange(selected ? null : opt)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: !enabled
                  ? AppEditorial.cream
                  : (selected
                      ? AppEditorial.ink
                      : AppEditorial.canvas),
              border: Border.all(
                color: !enabled
                    ? AppEditorial.hairline
                    : AppEditorial.ink,
                width: 1,
              ),
              borderRadius:
                  BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: Text(
              labelOf(opt),
              style: AppEditorial.mono(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: !enabled
                    ? AppEditorial.inkMuted
                    : (selected
                        ? AppEditorial.canvas
                        : AppEditorial.ink),
                letterSpacing: 0.4,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
