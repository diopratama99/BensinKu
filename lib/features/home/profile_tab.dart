import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../onboarding/add_vehicle_page.dart';
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
    final initials = name.isEmpty
        ? '?'
        : name
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join();

    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text('PROFIL',
                  style: AppEditorial.mono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  )),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: AppEditorial.ink,
        backgroundColor: AppEditorial.canvas,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            // Identity card
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: AppEditorial.cream,
                border:
                    Border.all(color: AppEditorial.hairlineSoft, width: 1),
                borderRadius: BorderRadius.circular(AppEditorial.rCard),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: AppEditorial.butter,
                      border: Border.all(
                          color: AppEditorial.ink, width: 1.5),
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rTiny),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: AppEditorial.mono(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PEMILIK', style: AppEditorial.eyebrow()),
                        const SizedBox(height: 4),
                        Text(
                          name.isEmpty ? 'Pengguna' : name,
                          style: AppEditorial.mono(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          email.isEmpty ? '—' : email,
                          style: AppEditorial.sans(
                            fontSize: 12,
                            color: AppEditorial.inkSoft,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // §01 Kendaraan
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
                      index: '01',
                      label: 'KENDARAAN',
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
                        child: Text('+ TAMBAH',
                            style: AppEditorial.eyebrow(
                                color: AppEditorial.ink)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (vehicles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'belum ada kendaraan.',
                          style: AppEditorial.sans(
                            fontSize: 13,
                            color: AppEditorial.inkSoft,
                          ),
                        ),
                      )
                    else
                      ...vehicles.asMap().entries.map(
                            (e) => _VehicleEntry(
                              vehicle: e.value,
                              isLast: e.key == vehicles.length - 1,
                            ),
                          ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // §02 Preferensi
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
            const SizedBox(height: 24),

            // §03 Akun
            const EditorialSectionHeader(index: '03', label: 'AKUN'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Keluar dari akun?',
                        style: AppEditorial.mono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                    content: const Text('Sesi akan dihapus.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('BATAL'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppEditorial.rust,
                        ),
                        child: const Text('KELUAR'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true)
                      .popUntil((r) => r.isFirst);
                }
              },
              icon: const Icon(Icons.logout_rounded,
                  size: 16, color: AppEditorial.rust),
              label: const Text('KELUAR DARI AKUN',
                  style: TextStyle(color: AppEditorial.rust)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppEditorial.rust, width: 1),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'BENSINKU · v1.0.0',
                style: AppEditorial.mono(
                  fontSize: 10.5,
                  color: AppEditorial.inkMuted,
                  letterSpacing: 0.6,
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
              color: isLast ? Colors.transparent : AppEditorial.hairline,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                vehicle.type == VehicleType.motor ? 'MOTOR' : 'MOBIL',
                style: AppEditorial.eyebrow(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: AppEditorial.mono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    vehicle.tankCapacityLiters == null
                        ? 'tanki belum diatur'
                        : 'tanki ${vehicle.tankCapacityLiters} L',
                    style: AppEditorial.sans(
                      fontSize: 11.5,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: AppEditorial.ink, size: 16),
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
    final hasPrefs =
        weeklyKm != null || weeklyCount != null || prefFuelId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialSectionHeader(
          index: '02',
          label: 'PREFERENSI',
          trailing: GestureDetector(
            onTap: onEdit,
            child: Text('EDIT',
                style:
                    AppEditorial.eyebrow(color: AppEditorial.ink)),
          ),
        ),
        const SizedBox(height: 8),
        if (!hasPrefs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'belum diatur. isi untuk prediksi yang akurat.',
              style: AppEditorial.sans(
                fontSize: 13,
                color: AppEditorial.inkSoft,
              ),
            ),
          )
        else
          Column(
            children: [
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
                  value: 'TERPILIH',
                  isLast: true,
                ),
            ],
          ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppEditorial.rust, width: 1),
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final wk = meta?['weekly_km'];
    final wrc = meta?['weekly_refuel_count'];
    final pf = meta?['preferred_fuel_id'];
    if (wk is num) _weeklyKmCtrl.text = wk.toStringAsFixed(0);
    if (wrc is num) _weeklyRefuelCount = wrc.toDouble().clamp(1, 7);
    if (pf is String) _preferredFuelId = pf;
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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'EDIT PREFERENSI',
          style: AppEditorial.mono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
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
                    : const Text('SIMPAN PREFERENSI →'),
              ),
            ],
          );
        },
      ),
    );
  }
}
