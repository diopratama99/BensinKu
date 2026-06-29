import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../app/theme.dart';

/// Privasi & data — editorial-style privacy policy page.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Privasi'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        children: [
          Text(
            'Privasi & data',
            style: AppEditorial.heading(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Data pengisianmu adalah milikmu. Kami menyimpan seminimal '
            'mungkin dan tidak menjual datamu ke pihak ketiga.',
            style: AppEditorial.sans(
              fontSize: 14.5,
              color: AppEditorial.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // ── Yang kamu berikan ──
          const EditorialSectionHeader(label: 'Yang kamu berikan'),
          const SizedBox(height: 12),
          EditorialCard(
            child: Column(
              children: const [
                _Bullet(
                  'Email untuk masuk dan menerima email penting '
                  '(verifikasi, lupa sandi).',
                ),
                _Bullet(
                  'Nama yang ditampilkan di dashboard.',
                ),
                _Bullet(
                  'Catatan pengisian BBM: nominal, liter, tanggal, '
                  'kendaraan, dan tipe BBM. Semua milikmu, bisa diakses '
                  'dan dihapus kapan saja.',
                ),
                _Bullet(
                  'Data kendaraan: CC mesin, tahun produksi, transmisi, '
                  'tipe bodi — dipakai untuk prediksi konsumsi yang akurat.',
                ),
                _Bullet(
                  'Data rute GPS (opsional): titik-titik koordinat selama '
                  'perjalanan aktif. Hanya direkam saat kamu menekan '
                  '"Mulai Perjalanan".',
                ),
                _Bullet(
                  'Preferensi berkendara: profil pemakaian, kota utama, '
                  'jarak mingguan — untuk kalibrasi prediksi.',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Di mana disimpan ──
          const EditorialSectionHeader(label: 'Di mana disimpan'),
          const SizedBox(height: 12),
          EditorialCard(
            child: Text(
              'Database Postgres di Supabase (region Asia Tenggara). '
              'Semua koneksi melalui HTTPS. Setiap baris di-tag dengan '
              'ID pengguna dan dilindungi Row Level Security, jadi kamu '
              'hanya bisa membaca catatanmu sendiri.',
              style: AppEditorial.sans(
                fontSize: 14,
                color: AppEditorial.ink,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Yang tidak kami lakukan ──
          const EditorialSectionHeader(label: 'Yang tidak kami lakukan'),
          const SizedBox(height: 12),
          EditorialCard(
            child: Column(
              children: const [
                _Bullet(
                  'Tidak ada pelacakan iklan atau analitik pihak ketiga.',
                ),
                _Bullet(
                  'Tidak ada penjualan data.',
                ),
                _Bullet(
                  'Tidak ada pengiriman datamu ke layanan eksternal '
                  'tanpa pemicu langsung dari kamu.',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Hak kamu ──
          const EditorialSectionHeader(label: 'Hak kamu'),
          const SizedBox(height: 12),
          EditorialCard(
            child: Column(
              children: const [
                _Bullet(
                  'Edit atau hapus catatan kapan saja dari halaman Arsip.',
                ),
                _Bullet(
                  'Hapus akun dan semua data terkait. Tombolnya akan '
                  'segera tersedia, sementara ini bisa diminta lewat '
                  'kontak di bawah.',
                ),
                _Bullet(
                  'Minta salinan datamu dengan menghubungi developer.',
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Kontak ──
          const EditorialSectionHeader(label: 'Kontak'),
          const SizedBox(height: 12),
          EditorialCard(
            child: Text(
              'Pertanyaan, permintaan ekspor, atau penghapusan data: '
              'hubungi TemanLabs lewat halaman Tentang BensinKu.',
              style: AppEditorial.sans(
                fontSize: 14,
                color: AppEditorial.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.isLast = false});
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppEditorial.brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppEditorial.sans(
                fontSize: 14,
                color: AppEditorial.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
