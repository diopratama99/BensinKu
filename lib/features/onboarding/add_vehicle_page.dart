import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'setup_preferences_page.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key, this.goHomeOnComplete = false});

  final bool goHomeOnComplete;

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _repo = SupabaseRepository.ofDefaultClient();

  VehicleType? _type;
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  num? _parseNum(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned);
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

      await _repo.createVehicle(
        type: type,
        name: name,
        tankCapacityLiters: capacity,
      );

      if (!mounted) return;
      if (widget.goHomeOnComplete) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SetupPreferencesPage()),
          (route) => false,
        );
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
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                const SizedBox(height: 32),
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
