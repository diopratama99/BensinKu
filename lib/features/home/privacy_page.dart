import 'package:flutter/material.dart';

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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        children: [
          Text('PRIVASI', style: AppEditorial.eyebrow()),
          const SizedBox(height: 12),
          Text(
            'Privasi\n& data.',
            style: AppEditorial.mono(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Data pengisianmu adalah milikmu. Kami menyimpan seminimal '
            'mungkin dan tidak menjual datamu ke pihak ketiga.',
            style: AppEditorial.sans(
              fontSize: 14,
              color: AppEditorial.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // ── YANG KAMU BERIKAN ──
          const EditorialSectionHeader(
            index: '01',
            label: 'YANG KAMU BERIKAN',
          ),
          const SizedBox(height: 14),
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
          ),
          const SizedBox(height: 28),

          // ── DI MANA DISIMPAN ──
          const EditorialSectionHeader(
            index: '02',
            label: 'DI MANA DISIMPAN',
          ),
          const SizedBox(height: 14),
          Text(
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
          const SizedBox(height: 28),

          // ── YANG TIDAK KAMI LAKUKAN ──
          const EditorialSectionHeader(
            index: '03',
            label: 'YANG TIDAK KAMI LAKUKAN',
          ),
          const SizedBox(height: 14),
          _Bullet(
            'Tidak ada pelacakan iklan atau analitik pihak ketiga.',
          ),
          _Bullet(
            'Tidak ada penjualan data.',
          ),
          _Bullet(
            'Tidak ada pengiriman datamu ke layanan eksternal '
            'tanpa pemicu langsung dari kamu.',
          ),
          const SizedBox(height: 28),

          // ── HAK KAMU ──
          const EditorialSectionHeader(
            index: '04',
            label: 'HAK KAMU',
          ),
          const SizedBox(height: 14),
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
          ),
          const SizedBox(height: 28),

          // ── KONTAK ──
          const EditorialSectionHeader(
            index: '05',
            label: 'KONTAK',
          ),
          const SizedBox(height: 14),
          Text(
            'Pertanyaan, permintaan ekspor, atau penghapusan data: '
            'hubungi TemanLabs lewat halaman Tentang BensinKu.',
            style: AppEditorial.sans(
              fontSize: 14,
              color: AppEditorial.ink,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 12),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppEditorial.ink,
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
