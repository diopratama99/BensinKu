import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../home/home_shell.dart';

/// Halaman opsional setelah add_vehicle.
/// Mengumpulkan preferensi awal user untuk meningkatkan akurasi prediksi bensin.
/// Preferensi disimpan di Supabase user_metadata.
class SetupPreferencesPage extends StatefulWidget {
  const SetupPreferencesPage({super.key});

  @override
  State<SetupPreferencesPage> createState() => _SetupPreferencesPageState();
}

class _SetupPreferencesPageState extends State<SetupPreferencesPage> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _weeklyKmCtrl = TextEditingController();

  String? _preferredFuelId;
  double _weeklyRefuelCount = 1;
  bool _saving = false;

  @override
  void dispose() {
    _weeklyKmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final weeklyKm = double.tryParse(
            _weeklyKmCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0;

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            // Gabungkan dengan metadata lama agar tidak overwrite 'name'
            ...?Supabase.instance.client.auth.currentUser?.userMetadata,
            'preferred_fuel_id': _preferredFuelId,
            'weekly_km': weeklyKm,
            'weekly_refuel_count': _weeklyRefuelCount.round(),
          },
        ),
      );

      if (mounted) _goHome();
    } catch (_) {
      // Jika gagal simpan, tetap lanjut ke home (opsional)
      if (mounted) _goHome();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FA),
      body: SafeArea(
        child: FutureBuilder<List<FuelProduct>>(
          future: _repo.listFuelProducts(),
          builder: (context, snap) {
            final products = snap.data ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                const SizedBox(height: 24),

                // ── Header ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.tune_rounded,
                                color: cs.onPrimary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Setup Preferensi',
                              style: TextStyle(
                                color: cs.onPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: cs.onPrimary.withValues(alpha: 0.9),
                                size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Opsional — semakin detail data yang diisi, semakin akurat prediksi bensin dan perkiraan waktu isi ulang kamu.',
                                style: TextStyle(
                                  color:
                                      cs.onPrimary.withValues(alpha: 0.92),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Pertanyaan 1: BBM Favorit ────────────────────────────────
                _QuestionCard(
                  number: '1',
                  title: 'Biasanya isi bensin apa?',
                  subtitle: 'Akan otomatis terpilih saat kamu isi bensin',
                  child: products.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: products.map((p) {
                            final selected = _preferredFuelId == p.id;
                            return GestureDetector(
                              onTap: () => setState(() =>
                                  _preferredFuelId =
                                      selected ? null : p.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: selected
                                        ? cs.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  p.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),

                // ── Pertanyaan 2: Jarak/minggu ───────────────────────────────
                _QuestionCard(
                  number: '2',
                  title: 'Berapa km yang biasa kamu tempuh per minggu?',
                  subtitle: 'Digunakan untuk memprediksi waktu isi ulang',
                  child: TextField(
                    controller: _weeklyKmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Contoh: 100',
                      suffixText: 'km/minggu',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Pertanyaan 3: Frekuensi isi/minggu ──────────────────────
                _QuestionCard(
                  number: '3',
                  title: 'Berapa kali biasa isi bensin per minggu?',
                  subtitle: 'Membantu estimasi konsumsi bahan bakar',
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_weeklyRefuelCount.round()}× per minggu',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: cs.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _weeklyRefuelCount >= 7
                                  ? 'Setiap hari'
                                  : _weeklyRefuelCount <= 1
                                      ? '1× seminggu'
                                      : '${_weeklyRefuelCount.round()}× seminggu',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 22),
                        ),
                        child: Slider(
                          min: 1,
                          max: 7,
                          divisions: 6,
                          value: _weeklyRefuelCount,
                          onChanged: (v) =>
                              setState(() => _weeklyRefuelCount = v),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1×',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                          Text('7×',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Tombol aksi ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                        _saving ? 'Menyimpan...' : 'Simpan & Masuk Dashboard'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _saving ? null : _goHome,
                    child: const Text(
                      'Lewati — isi nanti',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Helper widget ────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 26,
                width: 26,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
