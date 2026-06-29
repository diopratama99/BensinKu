import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppEditorial.brandTint,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rPill),
                      ),
                      child: Text(
                        'Preferensi',
                        style: AppEditorial.sans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppEditorial.brandDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Sedikit detail untuk prediksi yang akurat.',
                  style: AppEditorial.heading(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Semakin lengkap data, semakin tepat prediksi waktu isi ulang dan estimasi konsumsi.',
                  style: AppEditorial.sans(
                    fontSize: 14,
                    color: AppEditorial.inkSoft,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                const _PrefSectionLabel('BBM favorit'),
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
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppEditorial.brand
                                : AppEditorial.canvasSoft,
                            borderRadius:
                                BorderRadius.circular(AppEditorial.rPill),
                          ),
                          child: Text(
                            p.label,
                            style: AppEditorial.sans(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppEditorial.ink,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 26),

                const _PrefSectionLabel('Jarak per minggu'),
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
                const SizedBox(height: 26),

                const _PrefSectionLabel('Frekuensi isi'),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_weeklyRefuelCount.round()}',
                      style: AppEditorial.heading(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: AppEditorial.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'kali per minggu',
                      style: AppEditorial.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18),
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
                const SizedBox(height: 26),

                const _PrefSectionLabel('Profil pemakaian'),
                const SizedBox(height: 12),
                _PrefPicker<UsageProfile>(
                  value: _usageProfile,
                  options: UsageProfile.values,
                  labelOf: (v) => v.label,
                  onChange: (v) => setState(() => _usageProfile = v),
                ),
                const SizedBox(height: 26),

                const _PrefSectionLabel('Kota utama'),
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
                      : const Text('Simpan & masuk dashboard'),
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
        Text('Memuat…',
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
                  horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: selected
                    ? AppEditorial.brand
                    : AppEditorial.canvasSoft,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppEditorial.ink
                          : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(
                              color: AppEditorial.inkMuted,
                              width: 1.5,
                            ),
                    ),
                    child: selected
                        ? const Icon(PhosphorIconsRegular.check,
                            size: 13, color: AppEditorial.brand)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      labelOf(opt),
                      style: AppEditorial.sans(
                        fontSize: 14.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: AppEditorial.ink,
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

/// Label section pada halaman preferensi — judul ringkas sentence case.
class _PrefSectionLabel extends StatelessWidget {
  const _PrefSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppEditorial.heading(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }
}
