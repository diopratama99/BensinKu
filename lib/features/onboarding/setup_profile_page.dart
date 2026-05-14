import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
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
        MaterialPageRoute(
            builder: (_) => const AddVehiclePage(goHomeOnComplete: true)),
      );
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Row(
              children: [
                Text('STEP 01/02 · PROFIL',
                    style: AppEditorial.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.butterDeep,
                      letterSpacing: 0.6,
                    )),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Halo, siapa namamu?',
              style: AppEditorial.mono(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dipakai di halaman profil dan greeting.',
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
            const SizedBox(height: 28),
            Container(height: 1, color: AppEditorial.ink),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              style: AppEditorial.mono(
                  fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'NAMA',
                hintText: 'John Doe',
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppEditorial.rust, width: 1),
                  borderRadius: BorderRadius.circular(AppEditorial.rTiny),
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
                  : const Text('LANJUT KE KENDARAAN →'),
            ),
          ],
        ),
      ),
    );
  }
}
