import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/theme.dart';

/// Tentang BensinKu — editorial-style about page.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tentang'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        children: [
          Text(
            'Tentang BensinKu',
            style: AppEditorial.heading(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pencatat bahan bakar pribadi.',
            style: AppEditorial.heading(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppEditorial.brandDeep,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catat pengisian BBM, rekam rute perjalanan, dan biarkan '
            'aplikasi belajar pola berkendaramu untuk prediksi konsumsi '
            'yang makin akurat seiring waktu.',
            style: AppEditorial.sans(
              fontSize: 14.5,
              color: AppEditorial.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // ── Dibuat oleh ──
          const EditorialSectionHeader(label: 'Dibuat oleh'),
          const SizedBox(height: 12),
          EditorialCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppEditorial.brand,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rTiny),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'TL',
                    style: AppEditorial.heading(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TemanLabs',
                        style: AppEditorial.heading(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Developer & maintainer',
                        style: AppEditorial.sans(
                          fontSize: 12.5,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dibangun untuk siapa pun yang ingin mengubah '
                        'catatan pengisian harian menjadi insight '
                        'pengeluaran yang lebih baik.',
                        style: AppEditorial.sans(
                          fontSize: 13.5,
                          color: AppEditorial.ink,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Versi ──
          const EditorialSectionHeader(label: 'Versi'),
          const SizedBox(height: 12),
          EditorialCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppEditorial.brandTint,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rTiny),
                  ),
                  child: const Icon(PhosphorIconsRegular.lightning,
                      color: AppEditorial.brandDeep, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '1.0.0',
                        style: AppEditorial.heading(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'rilis awal',
                        style: AppEditorial.sans(
                          fontSize: 13.5,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Tumpukan teknologi ──
          const EditorialSectionHeader(label: 'Tumpukan teknologi'),
          const SizedBox(height: 12),
          EditorialCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              children: const [
                EditorialDataRow(label: 'UI', value: 'Flutter'),
                EditorialDataRow(label: 'Backend & Auth', value: 'Supabase'),
                EditorialDataRow(label: 'Database', value: 'Postgres'),
                EditorialDataRow(label: 'Maps', value: 'OpenStreetMap'),
                EditorialDataRow(label: 'GPS', value: 'Geolocator'),
                EditorialDataRow(label: 'AI', value: 'OpenAI', isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Terima kasih ──
          const EditorialSectionHeader(label: 'Terima kasih'),
          const SizedBox(height: 12),
          Text(
            'Untuk komunitas open source dan setiap orang yang sudah '
            'mencoba BensinKu sejak hari pertama.',
            style: AppEditorial.sans(
              fontSize: 14.5,
              color: AppEditorial.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2026 TemanLabs',
              style: AppEditorial.sans(
                fontSize: 12,
                color: AppEditorial.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
