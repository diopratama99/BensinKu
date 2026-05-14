import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../home/home_shell.dart';

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
            ...?Supabase.instance.client.auth.currentUser?.userMetadata,
            'preferred_fuel_id': _preferredFuelId,
            'weekly_km': weeklyKm,
            'weekly_refuel_count': _weeklyRefuelCount.round(),
          },
        ),
      );

      if (mounted) _goHome();
    } catch (_) {
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
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: SafeArea(
        child: FutureBuilder<List<FuelProduct>>(
          future: _repo.listFuelProducts(),
          builder: (context, snap) {
            final products = snap.data ?? [];

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Text('OPSIONAL · PREFERENSI',
                    style: AppEditorial.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.butterDeep,
                      letterSpacing: 0.6,
                    )),
                const SizedBox(height: 28),
                Text(
                  'Sedikit detail untuk prediksi yang akurat.',
                  style: AppEditorial.mono(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Semakin lengkap data, semakin tepat prediksi waktu isi ulang dan estimasi konsumsi.',
                  style: AppEditorial.sans(
                    fontSize: 13,
                    color: AppEditorial.inkSoft,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Container(height: 1, color: AppEditorial.ink),
                const SizedBox(height: 24),

                const EditorialSectionHeader(
                  index: '01',
                  label: 'BBM FAVORIT',
                ),
                const SizedBox(height: 12),
                if (products.isEmpty)
                  const _LoadingLine()
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: products.map((p) {
                      final selected = _preferredFuelId == p.id;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _preferredFuelId = selected ? null : p.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppEditorial.butter
                                : AppEditorial.canvas,
                            border: Border.all(
                              color: selected
                                  ? AppEditorial.ink
                                  : AppEditorial.hairline,
                              width: 1,
                            ),
                            borderRadius:
                                BorderRadius.circular(AppEditorial.rTiny),
                          ),
                          child: Text(
                            p.label,
                            style: AppEditorial.mono(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),

                const EditorialSectionHeader(
                  index: '02',
                  label: 'JARAK / MINGGU',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weeklyKmCtrl,
                  keyboardType: TextInputType.number,
                  style: AppEditorial.mono(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 100',
                    suffixText: 'km',
                  ),
                ),
                const SizedBox(height: 24),

                const EditorialSectionHeader(
                  index: '03',
                  label: 'FREKUENSI ISI',
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_weeklyRefuelCount.round()}',
                      style: AppEditorial.mono(
                        fontSize: 38,
                        fontWeight: FontWeight.w500,
                        color: AppEditorial.butterDeep,
                      ),
                    ),
                    Text(
                      '× / minggu',
                      style: AppEditorial.mono(
                        fontSize: 14,
                        color: AppEditorial.inkSoft,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppEditorial.ink,
                    inactiveTrackColor: AppEditorial.hairline,
                    thumbColor: AppEditorial.ink,
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8),
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
                const SizedBox(height: 28),

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
                      : const Text('SIMPAN & MASUK DASHBOARD →'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : _goHome,
                    child: const Text('LEWATI · ISI NANTI'),
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

class _LoadingLine extends StatelessWidget {
  const _LoadingLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppEditorial.ink,
          ),
        ),
        const SizedBox(width: 12),
        Text('memuat...',
            style: AppEditorial.sans(
              fontSize: 13,
              color: AppEditorial.inkSoft,
            )),
      ],
    );
  }
}
