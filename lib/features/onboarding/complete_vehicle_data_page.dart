import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:postgrest/postgrest.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Forced top-up screen for vehicles that pre-existed before the
/// "reference data is required" rule, OR for users who quit the app
/// mid-onboarding. The auth gate routes here on every cold-boot until
/// every vehicle in the garage has complete reference data.
///
/// Hard wall — no back button, no skip. The user must complete the form
/// before the dashboard becomes accessible.
class CompleteVehicleDataPage extends StatefulWidget {
  const CompleteVehicleDataPage({
    super.key,
    required this.vehicle,
    required this.remainingCount,
    this.onSaved,
  });

  final Vehicle vehicle;

  /// How many vehicles still need to be completed (including this one).
  /// When > 1, the screen reads "Lengkapi data kendaraan (1 dari N)".
  final int remainingCount;

  /// Optional callback fired after a successful save. The auth gate uses
  /// this to trigger a re-evaluation (which may either route to the next
  /// incomplete vehicle, the prefs page, or finally the dashboard).
  final VoidCallback? onSaved;

  @override
  State<CompleteVehicleDataPage> createState() =>
      _CompleteVehicleDataPageState();
}

class _CompleteVehicleDataPageState
    extends State<CompleteVehicleDataPage> {
  final _repo = SupabaseRepository.ofDefaultClient();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _engineCcCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _makeModelCtrl;

  late VehicleType _type;
  BodyType? _bodyType;
  Transmission? _transmission;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _nameCtrl = TextEditingController(text: v.name);
    _capacityCtrl = TextEditingController(
      text: v.tankCapacityLiters?.toString() ?? '',
    );
    _engineCcCtrl =
        TextEditingController(text: v.engineCc?.toString() ?? '');
    _yearCtrl = TextEditingController(
      text: v.manufacturingYear?.toString() ?? '',
    );
    _makeModelCtrl = TextEditingController(text: v.makeModel ?? '');
    _type = v.type;
    _bodyType = v.bodyType;
    _transmission = v.transmission;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    _engineCcCtrl.dispose();
    _yearCtrl.dispose();
    _makeModelCtrl.dispose();
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final name = _nameCtrl.text.trim();
      final capacity = _parseNum(_capacityCtrl.text);
      final engineCc = _parseInt(_engineCcCtrl.text);
      final year = _parseInt(_yearCtrl.text);
      final makeModel = _makeModelCtrl.text.trim();

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
      if (_type == VehicleType.mobil && _bodyType == null) {
        throw StateError('Pilih tipe bodi mobil.');
      }

      await _repo.updateVehicle(
        id: widget.vehicle.id,
        name: name,
        type: _type,
        tankCapacityLiters: capacity,
        engineCc: engineCc,
        manufacturingYear: year,
        bodyType: _bodyType,
        transmission: _transmission,
        makeModel: makeModel.isEmpty ? null : makeModel,
      );

      if (!mounted) return;
      // Notify the auth gate that this vehicle is now complete. The gate
      // re-evaluates and routes to whatever comes next (more incomplete
      // vehicles, the preferences page, or the dashboard).
      widget.onSaved?.call();
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() =>
          _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobil = _type == VehicleType.mobil;
    final progressLabel = widget.remainingCount > 1
        ? 'LENGKAPI DATA · 1 dari ${widget.remainingCount}'
        : 'LENGKAPI DATA KENDARAAN';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppEditorial.canvas,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'WAJIB',
            style: AppEditorial.mono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppEditorial.rust,
              letterSpacing: 0.6,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Text(
                progressLabel,
                style: AppEditorial.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.butterDeep,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lengkapi data ${widget.vehicle.name}.',
                style: AppEditorial.mono(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kendaraan ini terdaftar sebelum sistem prediksi baru. '
                'Lengkapi field di bawah supaya prediksi konsumsi bensin '
                'akurat sejak hari ini.',
                style: AppEditorial.sans(
                  fontSize: 13,
                  color: AppEditorial.inkSoft,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(height: 1, color: AppEditorial.ink),
              const SizedBox(height: 24),

              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: AppEditorial.mono(
                    fontSize: 16, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'NAMA KENDARAAN',
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _capacityCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}')),
                ],
                style: AppEditorial.mono(
                    fontSize: 16, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'KAPASITAS TANKI',
                  hintText: '5 atau 40',
                  suffixText: 'L',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _engineCcCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: AppEditorial.mono(
                          fontSize: 16, fontWeight: FontWeight.w600),
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
              TextField(
                controller: _makeModelCtrl,
                textCapitalization: TextCapitalization.words,
                style: AppEditorial.mono(
                    fontSize: 16, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'MERK / MODEL · OPSIONAL',
                ),
              ),
              if (isMobil) ...[
                const SizedBox(height: 22),
                Text('TIPE BODI', style: AppEditorial.eyebrow()),
                const SizedBox(height: 8),
                _Pills<BodyType>(
                  value: _bodyType,
                  options: BodyType.values,
                  labelOf: (v) => v.label.toUpperCase(),
                  onChange: (v) => setState(() => _bodyType = v),
                ),
              ],
              const SizedBox(height: 22),
              Text('TRANSMISI', style: AppEditorial.eyebrow()),
              const SizedBox(height: 8),
              _Pills<Transmission>(
                value: _transmission,
                options: Transmission.values,
                labelOf: (v) => v.label,
                onChange: (v) => setState(() => _transmission = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
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
                    : const Text('SIMPAN & LANJUT →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pills<T> extends StatelessWidget {
  const _Pills({
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
              color:
                  selected ? AppEditorial.ink : AppEditorial.canvas,
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
