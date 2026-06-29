import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/user_avatar.dart';
import '../onboarding/add_vehicle_page.dart';
import 'about_page.dart';
import 'account_edit_page.dart';
import 'privacy_page.dart';
import 'vehicle_detail_page.dart';

/// Profile — index card layout.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final raw = user?.userMetadata?['name'];
    final name = raw is String ? raw.trim() : '';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowLeft),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text('Profil',
                  style: AppEditorial.heading(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  )),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await Supabase.instance.client.auth.getUser();
          } catch (_) {}
          UserAvatar.bumpCacheBust();
          setState(() {});
        },
        color: AppEditorial.ink,
        backgroundColor: AppEditorial.canvas,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            // ── Kartu identitas ──
            EditorialCard(
              padding: const EdgeInsets.all(18),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountEditPage()),
                );
                if (!mounted) return;
                setState(() {});
              },
              child: Row(
                children: [
                  const UserAvatar(
                    size: 62,
                    shape: BoxShape.circle,
                    borderColor: Color(0xFFFFFFFF),
                    borderWidth: 0,
                    monogramFontSize: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Pengguna' : name,
                          style: AppEditorial.heading(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email.isEmpty ? '—' : email,
                          style: AppEditorial.sans(
                            fontSize: 12.5,
                            color: AppEditorial.inkSoft,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppEditorial.brandTint,
                            borderRadius:
                                BorderRadius.circular(AppEditorial.rPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIconsRegular.pencilSimple,
                                  size: 13, color: AppEditorial.brandDeep),
                              const SizedBox(width: 4),
                              Text('Edit profil',
                                  style: AppEditorial.sans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppEditorial.brandDeep,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // ── Kendaraan ──
            FutureBuilder<List<Vehicle>>(
              future: _repo.listVehicles(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorBox(message: snap.error.toString());
                }
                final vehicles = snap.data;
                if (vehicles == null) return const _LoadingLine();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EditorialSectionHeader(
                      label: 'Kendaraan',
                      trailing: GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddVehiclePage(),
                            ),
                          );
                          if (!mounted) return;
                          setState(() {});
                        },
                        child: Text('+ Tambah',
                            style: AppEditorial.sans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppEditorial.brandDeep)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (vehicles.isEmpty)
                      EditorialCard(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Center(
                          child: Text(
                            'Belum ada kendaraan.',
                            style: AppEditorial.sans(
                              fontSize: 13,
                              color: AppEditorial.inkMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      EditorialCard(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (var i = 0; i < vehicles.length; i++)
                              _VehicleEntry(
                                vehicle: vehicles[i],
                                isLast: i == vehicles.length - 1,
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),

            // ── Preferensi ──
            _PreferencesBlock(
              onEdit: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const _PreferencesEditPage()),
                );
                if (!mounted) return;
                setState(() {});
              },
            ),
            const SizedBox(height: 26),

            // ── Lainnya ──
            const EditorialSectionHeader(label: 'Lainnya'),
            const SizedBox(height: 12),
            EditorialCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _MenuTile(
                    icon: PhosphorIconsRegular.shield,
                    label: 'Privasi & data',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPage()),
                    ),
                  ),
                  _MenuTile(
                    icon: PhosphorIconsRegular.info,
                    label: 'Tentang BensinKu',
                    isLast: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // ── Akun ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Keluar dari akun?',
                          style: AppEditorial.heading(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          )),
                      content: const Text('Sesi akan dihapus.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppEditorial.rust,
                          ),
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  await GoogleAuthService.signOutGoogle();
                  await Supabase.instance.client.auth.signOut();
                },
                icon: const Icon(PhosphorIconsRegular.signOut,
                    size: 18, color: AppEditorial.rust),
                label: const Text('Keluar dari akun',
                    style: TextStyle(color: AppEditorial.rust)),
                style: OutlinedButton.styleFrom(
                  side:
                      const BorderSide(color: AppEditorial.rust, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'BensinKu · v1.0.0 · TemanLabs',
                style: AppEditorial.sans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
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

class _VehicleEntry extends StatelessWidget {
  const _VehicleEntry({required this.vehicle, required this.isLast});
  final Vehicle vehicle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VehicleDetailPage(vehicle: vehicle),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : AppEditorial.hairlineSoft,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppEditorial.brandTint,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Icon(
                vehicle.type == VehicleType.motor
                    ? PhosphorIconsRegular.motorcycle
                    : PhosphorIconsRegular.car,
                size: 22,
                color: AppEditorial.brandDeep,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: AppEditorial.heading(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle.tankCapacityLiters == null
                        ? '${vehicle.type.label} · tanki belum diatur'
                        : '${vehicle.type.label} · tanki ${vehicle.tankCapacityLiters} L',
                    style: AppEditorial.sans(
                      fontSize: 12,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight,
                color: AppEditorial.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PreferencesBlock extends StatelessWidget {
  const _PreferencesBlock({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final weeklyKm = meta?['weekly_km'];
    final weeklyCount = meta?['weekly_refuel_count'];
    final prefFuelId = meta?['preferred_fuel_id'];
    final usageProfile = UsageProfile.tryParse(meta?['usage_profile'] as String?);
    final primaryCity = PrimaryCity.tryParse(meta?['primary_city'] as String?);
    final hasPrefs = weeklyKm != null ||
        weeklyCount != null ||
        prefFuelId != null ||
        usageProfile != null ||
        primaryCity != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionHeader(
          label: 'Preferensi',
          trailing: GestureDetector(
            onTap: onEdit,
            child: Text('Edit',
                style: AppEditorial.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.brandDeep)),
          ),
        ),
        const SizedBox(height: 12),
        if (!hasPrefs)
          EditorialCard(
            onTap: onEdit,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.slidersHorizontal,
                    size: 20, color: AppEditorial.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum diatur. Isi untuk prediksi yang lebih akurat.',
                    style: AppEditorial.sans(
                      fontSize: 13,
                      color: AppEditorial.inkSoft,
                      height: 1.4,
                    ),
                  ),
                ),
                const Icon(PhosphorIconsRegular.caretRight,
                    size: 20, color: AppEditorial.inkMuted),
              ],
            ),
          )
        else
          Builder(builder: (_) {
            final rows = <Widget>[
              if (weeklyKm is num)
                EditorialDataRow(
                  label: 'Jarak per minggu',
                  value: '${weeklyKm.toStringAsFixed(0)} km',
                ),
              if (weeklyCount is num)
                EditorialDataRow(
                  label: 'Frekuensi isi',
                  value: '${weeklyCount.round()}× / minggu',
                ),
              if (prefFuelId != null)
                const EditorialDataRow(
                  label: 'BBM favorit',
                  value: 'Terpilih',
                ),
              if (usageProfile != null)
                EditorialDataRow(
                  label: 'Profil pakai',
                  value: usageProfile.label,
                ),
              if (primaryCity != null)
                EditorialDataRow(
                  label: 'Kota utama',
                  value: primaryCity.label,
                ),
            ];
            // Mark the last row so it doesn't draw a divider.
            if (rows.isNotEmpty) {
              final last = rows.last;
              if (last is EditorialDataRow) {
                rows[rows.length - 1] = EditorialDataRow(
                  label: last.label,
                  value: last.value,
                  valueStyle: last.valueStyle,
                  isLast: true,
                );
              }
            }
            return EditorialCard(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(children: rows),
            );
          }),
      ],
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppEditorial.rustSoft,
        borderRadius: BorderRadius.circular(AppEditorial.rButton),
      ),
      child: Text(
        message,
        style: AppEditorial.sans(
          fontSize: 13,
          color: AppEditorial.rust,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preferences edit page
// ─────────────────────────────────────────────────────────────────────────────

class _PreferencesEditPage extends StatefulWidget {
  const _PreferencesEditPage();

  @override
  State<_PreferencesEditPage> createState() =>
      _PreferencesEditPageState();
}

class _PreferencesEditPageState extends State<_PreferencesEditPage> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _weeklyKmCtrl = TextEditingController();

  String? _preferredFuelId;
  double _weeklyRefuelCount = 1;
  UsageProfile? _usageProfile;
  PrimaryCity? _primaryCity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final wk = meta?['weekly_km'];
    final wrc = meta?['weekly_refuel_count'];
    final pf = meta?['preferred_fuel_id'];
    final up = meta?['usage_profile'];
    final pc = meta?['primary_city'];
    if (wk is num) _weeklyKmCtrl.text = wk.toStringAsFixed(0);
    if (wrc is num) _weeklyRefuelCount = wrc.toDouble().clamp(1, 7);
    if (pf is String) _preferredFuelId = pf;
    if (up is String) _usageProfile = UsageProfile.tryParse(up);
    if (pc is String) _primaryCity = PrimaryCity.tryParse(pc);
  }

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
            'usage_profile': _usageProfile?.dbValue,
            'primary_city': _primaryCity?.dbValue,
          },
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tersimpan ✓')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit preferensi',
          style: AppEditorial.heading(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FutureBuilder<List<FuelProduct>>(
        future: _repo.listFuelProducts(),
        builder: (context, snap) {
          final products = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
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
                      onTap: () => setState(() => _preferredFuelId =
                          selected ? null : p.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
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
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppEditorial.ink
                                : AppEditorial.inkSoft,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 28),
              const EditorialSectionHeader(
                  index: '02', label: 'JARAK / MINGGU'),
              const SizedBox(height: 12),
              TextField(
                controller: _weeklyKmCtrl,
                keyboardType: TextInputType.number,
                style: AppEditorial.mono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'Contoh: 100',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 28),
              const EditorialSectionHeader(
                  index: '03', label: 'FREKUENSI ISI'),
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
              const SizedBox(height: 32),
              const EditorialSectionHeader(
                index: '04',
                label: 'PROFIL PEMAKAIAN',
              ),
              const SizedBox(height: 12),
              _ProfilePicker<UsageProfile>(
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
              _ProfilePicker<PrimaryCity>(
                value: _primaryCity,
                options: PrimaryCity.values,
                labelOf: (v) => v.label,
                onChange: (v) => setState(() => _primaryCity = v),
              ),
              const SizedBox(height: 32),
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
                    : const Text('Simpan preferensi'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Vertically-stacked single-select picker. Shared with the onboarding
/// SetupPreferencesPage but defined locally to avoid an import cycle.
class _ProfilePicker<T> extends StatelessWidget {
  const _ProfilePicker({
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:
                    selected ? AppEditorial.brand : AppEditorial.canvasSoft,
                borderRadius:
                    BorderRadius.circular(AppEditorial.rButton),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppEditorial.ink
                            : AppEditorial.inkMuted,
                        width: 1.6,
                      ),
                      color: selected
                          ? AppEditorial.ink
                          : Colors.transparent,
                    ),
                    child: selected
                        ? const Icon(PhosphorIconsRegular.check,
                            size: 13, color: AppEditorial.brand)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      labelOf(opt),
                      style: AppEditorial.sans(
                        fontSize: 14,
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

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast
                  ? Colors.transparent
                  : AppEditorial.hairlineSoft,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppEditorial.canvasSoft,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Icon(icon, size: 19, color: AppEditorial.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppEditorial.sans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight,
                size: 20, color: AppEditorial.inkMuted),
          ],
        ),
      ),
    );
  }
}
