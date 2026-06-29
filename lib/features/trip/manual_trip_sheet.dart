import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Manual trip entry — for when the user forgot to record live tracking.
///
/// Captures just distance (km) + duration (minutes) + date, and writes a
/// complete trip with no waypoints. This keeps distance-based features
/// (fuel prediction, maintenance estimates) fed even when GPS wasn't on.
///
/// Returns `true` via Navigator.pop when a trip was saved.
class ManualTripSheet extends StatefulWidget {
  const ManualTripSheet({
    super.key,
    required this.vehicles,
    this.initialVehicleId,
  });

  final List<Vehicle> vehicles;
  final String? initialVehicleId;

  @override
  State<ManualTripSheet> createState() => _ManualTripSheetState();
}

class _ManualTripSheetState extends State<ManualTripSheet> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _distanceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Vehicle? _vehicle;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicles.firstWhere(
      (v) => v.id == widget.initialVehicleId,
      orElse: () => widget.vehicles.first,
    );
  }

  @override
  void dispose() {
    _distanceCtrl.dispose();
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      helpText: 'Tanggal perjalanan',
    );
    if (picked != null) {
      setState(() => _date = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _date.hour,
            _date.minute,
          ));
    }
  }

  Future<void> _save() async {
    final distance = double.tryParse(
          _distanceCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    if (distance <= 0) {
      _toast('Masukkan jarak tempuh (km).');
      return;
    }
    if (_vehicle == null) {
      _toast('Pilih kendaraan dulu.');
      return;
    }

    // Duration is optional; default to a rough estimate (~30 km/h average)
    // if left blank so the trip still has a sensible end time.
    final minutes = int.tryParse(_durationCtrl.text.trim()) ??
        (distance / 30 * 60).round();
    final started = _date;
    final ended = started.add(Duration(minutes: minutes.clamp(1, 1440)));

    setState(() => _saving = true);
    try {
      await _repo.createManualTrip(
        vehicleId: _vehicle!.id,
        distanceKm: distance,
        startedAt: started,
        endedAt: ended,
        note: _noteCtrl.text.trim().isEmpty
            ? 'Input manual'
            : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Gagal simpan: $e');
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/${_date.year}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppEditorial.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppEditorial.hairline,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rPill),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('Catat manual',
                        style: AppEditorial.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        )),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(PhosphorIconsRegular.x,
                          size: 22, color: AppEditorial.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lupa nyalakan rute? Masukkan jarak & waktu tempuh '
                  'perjalananmu di sini.',
                  style: AppEditorial.sans(
                    fontSize: 12.5,
                    color: AppEditorial.inkSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // Vehicle picker
                if (widget.vehicles.length > 1) ...[
                  Text('KENDARAAN', style: AppEditorial.eyebrow()),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppEditorial.canvasSoft,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rTiny),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Vehicle>(
                        value: _vehicle,
                        isExpanded: true,
                        icon: const Icon(PhosphorIconsRegular.caretDown,
                            color: AppEditorial.ink),
                        dropdownColor: AppEditorial.cream,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rTiny),
                        style: AppEditorial.sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        items: widget.vehicles
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                      '${v.type.label} · ${v.name}'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _vehicle = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Distance + duration row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JARAK', style: AppEditorial.eyebrow()),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _distanceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]')),
                            ],
                            style: AppEditorial.mono(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              suffixText: 'km',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WAKTU (OPSIONAL)',
                              style: AppEditorial.eyebrow()),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _durationCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: AppEditorial.mono(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              suffixText: 'menit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date
                Text('TANGGAL', style: AppEditorial.eyebrow()),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppEditorial.rTiny),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppEditorial.canvasSoft,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rTiny),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsRegular.calendarBlank,
                            size: 16, color: AppEditorial.inkSoft),
                        const SizedBox(width: 12),
                        Text(
                          dateLabel,
                          style: AppEditorial.sans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(PhosphorIconsRegular.caretDown,
                            color: AppEditorial.inkMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note
                Text('CATATAN (OPSIONAL)', style: AppEditorial.eyebrow()),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteCtrl,
                  style: AppEditorial.sans(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'mis. Rumah → Kantor',
                  ),
                ),
                const SizedBox(height: 24),

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
                      : const Text('Simpan perjalanan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
