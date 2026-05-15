import 'package:flutter/material.dart';

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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        children: [
          Text('TENTANG', style: AppEditorial.eyebrow()),
          const SizedBox(height: 12),
          Text(
            'Tentang\nBensinKu.',
            style: AppEditorial.mono(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Pencatat bahan bakar pribadi.',
            style: AppEditorial.mono(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catat pengisian BBM, rekam rute perjalanan, dan biarkan '
            'aplikasi belajar pola berkendaramu untuk prediksi konsumsi '
            'yang makin akurat seiring waktu.',
            style: AppEditorial.sans(
              fontSize: 14,
              color: AppEditorial.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // ── DIBUAT OLEH ──
          const EditorialSectionHeader(
            index: '01',
            label: 'DIBUAT OLEH',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppEditorial.cream,
              border:
                  Border.all(color: AppEditorial.hairlineSoft, width: 1),
              borderRadius: BorderRadius.circular(AppEditorial.rCard),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppEditorial.ink,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rTiny),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'TL',
                    style: AppEditorial.mono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.canvas,
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
                        style: AppEditorial.mono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Developer & maintainer',
                        style: AppEditorial.sans(
                          fontSize: 12,
                          color: AppEditorial.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dibangun untuk siapa pun yang ingin mengubah '
                        'catatan pengisian harian menjadi insight '
                        'pengeluaran yang lebih baik.',
                        style: AppEditorial.sans(
                          fontSize: 13,
                          color: AppEditorial.ink,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── VERSI ──
          const EditorialSectionHeader(
            index: '02',
            label: 'VERSI',
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '1.0.0',
                style: AppEditorial.mono(
                  fontSize: 48,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'rilis awal',
                style: AppEditorial.sans(
                  fontSize: 14,
                  color: AppEditorial.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── TUMPUKAN ──
          const EditorialSectionHeader(
            index: '03',
            label: 'TUMPUKAN',
          ),
          const SizedBox(height: 14),
          _StackRow(label: 'UI', value: 'Flutter'),
          _StackRow(label: 'Backend & Auth', value: 'Supabase'),
          _StackRow(label: 'Database', value: 'Postgres'),
          _StackRow(label: 'Maps', value: 'OpenStreetMap'),
          _StackRow(label: 'GPS', value: 'Geolocator'),
          _StackRow(label: 'AI', value: 'OpenAI'),
          const SizedBox(height: 28),

          // ── TERIMA KASIH ──
          const EditorialSectionHeader(
            index: '04',
            label: 'TERIMA KASIH',
          ),
          const SizedBox(height: 14),
          Text(
            'Untuk komunitas open source dan setiap orang yang sudah '
            'mencoba BensinKu sejak hari pertama.',
            style: AppEditorial.sans(
              fontSize: 14,
              color: AppEditorial.ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2026 TemanLabs',
              style: AppEditorial.mono(
                fontSize: 11,
                color: AppEditorial.inkMuted,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StackRow extends StatelessWidget {
  const _StackRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppEditorial.sans(
                fontSize: 14,
                color: AppEditorial.ink,
              ),
            ),
          ),
          Text(
            value,
            style: AppEditorial.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
