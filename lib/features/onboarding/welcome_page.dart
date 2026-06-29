import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
            // Wordmark
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppEditorial.brand,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rTiny),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.gasPump,
                    size: 20,
                    color: AppEditorial.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'BensinKu',
                  style: AppEditorial.heading(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text('Selamat datang', style: AppEditorial.eyebrow()),
              ],
            ),
            const SizedBox(height: 28),

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
                  'assets/illustrations/onboarding_pump.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Pantau bensinmu.',
              style: AppEditorial.heading(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                height: 1.06,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pengeluaran bensin tahun ini, dirangkum jadi catatan harian yang ringkas.',
              style: AppEditorial.sans(
                fontSize: 14.5,
                color: AppEditorial.inkSoft,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            const _Pillar(
              icon: PhosphorIconsRegular.lightning,
              title: 'Catat lebih cepat',
              body:
                  'Input nominal saja. Liter dihitung otomatis dari harga aktual hari itu.',
            ),
            const SizedBox(height: 12),
            const _Pillar(
              icon: PhosphorIconsRegular.chartLineUp,
              title: 'Lihat pengeluaran',
              body: 'Riwayat dan analitik jalan di latar. Buka kapan saja.',
            ),
            const SizedBox(height: 12),
            const _Pillar(
              icon: PhosphorIconsRegular.motorcycle,
              title: 'Satu motor, satu mobil',
              body:
                  'Fokus pada kendaraan harian, bukan armada. Sederhana sesuai kebutuhan.',
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SetupProfilePage(),
                ),
              ),
              child: const Text('Mulai sekarang'),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Hanya butuh satu menit.',
                style: AppEditorial.sans(
                  fontSize: 12.5,
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
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppEditorial.brandTint,
              borderRadius: BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: Icon(icon, size: 22, color: AppEditorial.brandDeep),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppEditorial.heading(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
