import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'setup_profile_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Row(
              children: [
                Text('BENSINKU',
                    style: AppEditorial.mono(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    )),
                const SizedBox(width: 10),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppEditorial.butter,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text('VOL.00 · WELCOME',
                    style: AppEditorial.eyebrow()),
              ],
            ),
            const SizedBox(height: 32),
            // Hero illustration
            AspectRatio(
              aspectRatio: 1080 / 800,
              child: Image.asset(
                'assets/illustrations/onboarding_pump.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pantau bensinmu.',
              style: AppEditorial.mono(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pengeluaran bensin tahun ini, dirangkum jadi catatan harian yang ringkas.',
              style: AppEditorial.sans(
                fontSize: 14,
                color: AppEditorial.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(height: 1, color: AppEditorial.ink),
            const SizedBox(height: 24),

            const _Pillar(
              index: '01',
              title: 'CATAT LEBIH CEPAT',
              body:
                  'Input nominal saja. Liter dihitung otomatis dari harga aktual hari itu.',
            ),
            const SizedBox(height: 22),
            Container(height: 1, color: AppEditorial.hairline),
            const SizedBox(height: 22),
            const _Pillar(
              index: '02',
              title: 'LIHAT PENGELUARAN',
              body:
                  'Riwayat dan analytics jalan di latar. Buka kapan saja.',
            ),
            const SizedBox(height: 22),
            Container(height: 1, color: AppEditorial.hairline),
            const SizedBox(height: 22),
            const _Pillar(
              index: '03',
              title: 'SATU MOTOR, SATU MOBIL',
              body:
                  'Limit by design. Fokus pada kendaraan harian, bukan armada.',
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SetupProfilePage(),
                ),
              ),
              child: const Text('MULAI SEKARANG →'),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'flow tetap sama, tampilan baru.',
                style: AppEditorial.sans(
                  fontSize: 11.5,
                  color: AppEditorial.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({
    required this.index,
    required this.title,
    required this.body,
  });
  final String index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            index,
            style: AppEditorial.mono(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppEditorial.butterDeep,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppEditorial.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: AppEditorial.sans(
                  fontSize: 13,
                  color: AppEditorial.inkSoft,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
