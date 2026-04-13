import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../widgets/brand_scaffold.dart';
import '../home/home_shell.dart';

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
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Vehicle')),
      body: BrandBackdrop(
        assetPath: 'assets/illustrations/dashboard_wave.svg',
        topPadding: -20,
        child: FutureBuilder<List<Vehicle>>(
          future: _repo.listVehicles(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _CenteredMessage(
                title: 'Error',
                subtitle: snap.error.toString(),
              );
            }

            final vehicles = snap.data;
            if (vehicles == null) {
              return const _CenteredLoading();
            }

            final hasMotor = vehicles.any((v) => v.type == VehicleType.motor);
            final hasMobil = vehicles.any((v) => v.type == VehicleType.mobil);
            final canAdd = !(hasMotor && hasMobil);

            _type ??=
                hasMotor ? (hasMobil ? null : VehicleType.mobil) : VehicleType.motor;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                IntroHeroCard(
                  title: 'Tambah Kendaraan',
                  subtitle:
                      'Simpan 1 motor dan 1 mobil. Isi data kendaraan agar ringkasan lebih akurat.',
                  assetPath: 'assets/illustrations/fuel_hero.svg',
                ),
                const SizedBox(height: 14),
                BrandPanel(
                  child: Column(
                    children: [
                      DropdownButtonFormField<VehicleType>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Jenis kendaraan',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: [
                          if (!hasMotor)
                            const DropdownMenuItem(
                              value: VehicleType.motor,
                              child: Text('Motor'),
                            ),
                          if (!hasMobil)
                            const DropdownMenuItem(
                              value: VehicleType.mobil,
                              child: Text('Mobil'),
                            ),
                        ],
                        onChanged:
                            canAdd ? (v) => setState(() => _type = v) : null,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _capacityController,
                        enabled: canAdd,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kapasitas tanki (liter)',
                          hintText: 'Contoh: 5 / 40',
                          prefixIcon: Icon(Icons.water_drop_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        enabled: canAdd,
                        decoration: const InputDecoration(
                          labelText: 'Nama kendaraan',
                          hintText: 'Contoh: Vario / Avanza',
                          prefixIcon: Icon(Icons.directions_car_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      (!canAdd || _saving) ? null : () => _create(vehicles),
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(
                    !canAdd
                        ? 'Limit kendaraan tercapai'
                        : 'Simpan & Masuk Dashboard',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: cs.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CenteredLoading extends StatelessWidget {
  const _CenteredLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
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
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
