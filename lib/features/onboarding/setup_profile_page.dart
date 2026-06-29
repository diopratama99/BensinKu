import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const _OnbStepHeader(
              label: 'Profil',
              step: 1,
              total: 2,
            ),
            const SizedBox(height: 22),
            // Hero illustration di kartu putih lembut
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppEditorial.cream,
                borderRadius: BorderRadius.circular(AppEditorial.rCard),
                boxShadow: AppEditorial.softShadow,
              ),
              child: AspectRatio(
                aspectRatio: 1080 / 800,
                child: Image.asset(
                  'assets/illustrations/onboarding_logbook.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Halo, siapa namamu?',
              style: AppEditorial.heading(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dipakai di halaman profil dan sapaan.',
              style: AppEditorial.sans(
                fontSize: 14,
                color: AppEditorial.inkSoft,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              style: AppEditorial.sans(
                  fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Nama',
                hintText: 'John Doe',
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorNote(_error!),
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
                  : const Text('Lanjut'),
            ),
          ],
        ),
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
