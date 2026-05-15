import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../home/home_shell.dart';

class SetupPreferencesPage extends StatefulWidget {
  const SetupPreferencesPage({super.key, this.onCompleted});

  /// When provided, called after successful save. The default flow uses
  /// this from the auth gate to re-evaluate routing. If null, falls back
  /// to pushing `HomeShell` directly (used by the linear onboarding flow).
  final VoidCallback? onCompleted;

  @override
  State<SetupPreferencesPage> createState() => _SetupPreferencesPageState();
}

class _SetupPreferencesPageState extends State<SetupPreferencesPage> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _weeklyKmCtrl = TextEditingController();

  String? _preferredFuelId;
  double _weeklyRefuelCount = 1;
  UsageProfile? _usageProfile;
  PrimaryCity? _primaryCity;
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

      // Required: usage_profile + primary_city. Without these, the prediction
      // service falls back to generic defaults — defeats the purpose.
      if (_usageProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih profil pemakaian.')),
        );
        return;
      }
      if (_primaryCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih kota utama.')),
        );
        return;
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            ...?Supabase.instance.client.auth.currentUser?.userMetadata,
            'preferred_fuel_id': _preferredFuelId,
            'weekly_km': weeklyKm,
            'weekly_refuel_count': _weeklyRefuelCount.round(),
            'usage_profile': _usageProfile?.dbValue,
            'primary_city': _primaryCity?.dbValue,
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
    if (widget.onCompleted != null) {
      // Called from auth gate: just signal back, the gate handles routing.
      widget.onCompleted!();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prefs page is a hard requirement — don't let user back-button out
    // of it. They must commit a usage_profile + primary_city before the
    // dashboard renders.
    return PopScope(
      canPop: false,
      child: Scaffold(
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

                const EditorialSectionHeader(
                  index: '04',
                  label: 'PROFIL PEMAKAIAN',
                ),
                const SizedBox(height: 12),
                _PrefPicker<UsageProfile>(
                  value: _usageProfile,
                  options: UsageProfile.values,
                  labelOf: (v) => v.label,
                  onChange: (v) => setState(() => _usageProfile = v),
                ),
                const SizedBox(height: 28),

                const EditorialSectionHeader(
                  index: '05',
                  label: 'KOTA UTAMA',
                ),
                const SizedBox(height: 12),
                _PrefPicker<PrimaryCity>(
                  value: _primaryCity,
                  options: PrimaryCity.values,
                  labelOf: (v) => v.label,
                  onChange: (v) => setState(() => _primaryCity = v),
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
              ],
            );
          },
        ),
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

/// Vertically-stacked single-select picker for prefs page. Each option is a
/// full-width row so labels (e.g. "Kerja lapangan") tidak terpotong.
class _PrefPicker<T> extends StatelessWidget {
  const _PrefPicker({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChange,
  });

  final T? value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((opt) {
        final selected = value == opt;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onChange(selected ? null : opt),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppEditorial.butter
                    : AppEditorial.canvas,
                border: Border.all(
                  color: selected
                      ? AppEditorial.ink
                      : AppEditorial.hairline,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius:
                    BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppEditorial.ink,
                        width: 1.2,
                      ),
                      color: selected
                          ? AppEditorial.ink
                          : AppEditorial.canvas,
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 11, color: AppEditorial.canvas)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      labelOf(opt),
                      style: AppEditorial.mono(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
