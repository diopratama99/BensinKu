import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/brand_scaffold.dart';
import 'add_vehicle_page.dart';

class SetupProfilePage extends StatefulWidget {
  const SetupProfilePage({super.key});

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final _nameController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      if (name.isEmpty) throw StateError('Nama wajib diisi');

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'name': name}),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AddVehiclePage(goHomeOnComplete: true)),
      );
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
      appBar: AppBar(title: const Text('Setup Profile')),
      body: BrandBackdrop(
        assetPath: 'assets/illustrations/dashboard_wave.svg',
        topPadding: -20,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 6),
            BrandPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Nama kamu',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dipakai untuk halaman profile agar pengalaman jadi lebih personal.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nama',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    onSubmitted: (_) => _saving ? null : _save(),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Lanjut ke Kendaraan'),
                  ),
                ],
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
        ),
      ),
    );
  }
}
