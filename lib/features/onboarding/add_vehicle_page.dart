import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
                  icon: const Icon(PhosphorIconsRegular.arrowLeft),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          automaticallyImplyLeading: !inOnboarding,
        ),
      body: FutureBuilder<List<Vehicle>>(
        future: _repo.listVehicles(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _CenteredMessage(
              title: 'Terjadi kesalahan',
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                if (widget.goHomeOnComplete)
                  const _OnbStepHeader(
                    label: 'Kendaraan',
                    step: 2,
                    total: 2,
                  )
                else
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppEditorial.brandTint,
                          borderRadius:
                              BorderRadius.circular(AppEditorial.rPill),
                        ),
                        child: Text(
                          'Tambah kendaraan',
                          style: AppEditorial.sans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppEditorial.brandDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 22),
                // Hero illustration di kartu putih lembut
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppEditorial.cream,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rCard),
                    boxShadow: AppEditorial.softShadow,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1080 / 800,
                    child: Image.asset(
                      'assets/illustrations/onboarding_tank.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Tambah kendaraan harianmu.',
                  style: AppEditorial.heading(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Maksimal 1 motor dan 1 mobil. Cukup untuk pemakaian harian.',
                  style: AppEditorial.sans(
                    fontSize: 14,
                    color: AppEditorial.inkSoft,
                  ),
                ),
                const SizedBox(height: 28),

                const _VSectionLabel('Jenis kendaraan'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TypePill(
                        label: 'Motor',
                        icon: PhosphorIconsRegular.motorcycle,
                        active: _type == VehicleType.motor,
                        disabled: hasMotor,
                        onTap: () =>
                            setState(() => _type = VehicleType.motor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypePill(
                        label: 'Mobil',
                        icon: PhosphorIconsRegular.car,
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
                  style: AppEditorial.sans(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'Nama kendaraan',
                    hintText: 'Vario / Avanza',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _capacityController,
                  enabled: canAdd,
                  keyboardType: TextInputType.number,
                  style: AppEditorial.mono(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'Kapasitas tanki',
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
                  _ErrorNote(_error!),
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
                          ? 'Batas tercapai'
                          : 'Simpan & lanjut'),
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
    required this.icon,
    required this.active,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (disabled) {
      bg = AppEditorial.canvasSoft;
      fg = AppEditorial.inkMuted;
    } else if (active) {
      bg = AppEditorial.brand;
      fg = AppEditorial.ink;
    } else {
      bg = AppEditorial.canvasSoft;
      fg = AppEditorial.ink;
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: fg),
            const SizedBox(height: 8),
            Text(
              disabled ? '$label · sudah ada' : label,
              style: AppEditorial.sans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label section pada form kendaraan — judul ringkas sentence case.
class _VSectionLabel extends StatelessWidget {
  const _VSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppEditorial.heading(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Catatan error lembut — fill rustSoft, tanpa border keras.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppEditorial.rustSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsRegular.warningCircle,
              size: 18, color: AppEditorial.rust),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppEditorial.sans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppEditorial.rust,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header langkah onboarding — eyebrow + progress bar brand.
class _OnbStepHeader extends StatelessWidget {
  const _OnbStepHeader({
    required this.label,
    required this.step,
    required this.total,
  });

  final String label;
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppEditorial.brandTint,
                borderRadius: BorderRadius.circular(AppEditorial.rPill),
              ),
              child: Text(
                'Langkah $step dari $total',
                style: AppEditorial.sans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.brandDeep,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppEditorial.sans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppEditorial.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(total, (i) {
            final filled = i < step;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                height: 5,
                decoration: BoxDecoration(
                  color:
                      filled ? AppEditorial.brand : AppEditorial.hairline,
                  borderRadius: BorderRadius.circular(AppEditorial.rPill),
                ),
              ),
            );
          }),
        ),
      ],
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
              style: AppEditorial.heading(
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
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text('Detail mesin',
                    style: AppEditorial.heading(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppEditorial.brandTint,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rPill),
                  ),
                  child: Text(
                    'Wajib',
                    style: AppEditorial.sans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.brandDeep,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded
                      ? PhosphorIconsRegular.caretUp
                      : PhosphorIconsRegular.caretDown,
                  size: 22,
                  color: AppEditorial.inkSoft,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Diperlukan untuk prediksi konsumsi yang akurat sejak awal.',
          style: AppEditorial.sans(
            fontSize: 12.5,
            color: AppEditorial.inkSoft,
            height: 1.4,
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
                    labelText: 'CC mesin',
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
                    labelText: 'Tahun',
                    hintText: '2020',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Make/model bebas (opsional — informational only)
          TextField(
            controller: makeModelController,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            style: AppEditorial.sans(
                fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'Merk / model · opsional',
              hintText: 'Honda Vario 125',
            ),
          ),
          if (isMobil) ...[
            const SizedBox(height: 22),
            const _VSectionLabel('Tipe bodi'),
            const SizedBox(height: 10),
            _EnumPicker<BodyType>(
              enabled: enabled,
              value: bodyType,
              options: BodyType.values,
              labelOf: (v) => v.label,
              onChange: onBodyTypeChange,
            ),
          ],
          const SizedBox(height: 22),
          const _VSectionLabel('Transmisi'),
          const SizedBox(height: 10),
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
        final Color bg;
        final Color fg;
        if (!enabled) {
          bg = AppEditorial.canvasSoft;
          fg = AppEditorial.inkMuted;
        } else if (selected) {
          bg = AppEditorial.brand;
          fg = AppEditorial.ink;
        } else {
          bg = AppEditorial.canvasSoft;
          fg = AppEditorial.ink;
        }
        return GestureDetector(
          onTap: enabled
              ? () => onChange(selected ? null : opt)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  BorderRadius.circular(AppEditorial.rPill),
            ),
            child: Text(
              labelOf(opt),
              style: AppEditorial.sans(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
