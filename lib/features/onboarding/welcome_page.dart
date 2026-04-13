import 'package:flutter/material.dart';

import '../../widgets/brand_scaffold.dart';
import 'setup_profile_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: BrandBackdrop(
        assetPath: 'assets/illustrations/dashboard_wave.svg',
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              IntroHeroCard(
                title: 'Selamat Datang di BensinKu',
                subtitle:
                    'Catat pengisian lebih cepat, lihat pengeluaran lebih jelas, dan kelola kendaraan dalam satu tempat.',
                assetPath: 'assets/illustrations/fuel_hero.svg',
              ),
              const SizedBox(height: 14),
              BrandPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Kenapa BensinKu?',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    _Bullet(text: 'Input nominal cepat, liter dihitung otomatis'),
                    const SizedBox(height: 10),
                    _Bullet(text: 'Limit 1 motor + 1 mobil, tetap simpel'),
                    const SizedBox(height: 10),
                    _Bullet(text: 'Harga BBM sinkron dari server admin'),
                    const SizedBox(height: 10),
                    _Bullet(text: 'Riwayat dan analytics siap dipantau'),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SetupProfilePage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Mulai Sekarang'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Flow aplikasi tetap sama, hanya tampilannya lebih modern.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          height: 22,
          width: 22,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 15,
            color: cs.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
