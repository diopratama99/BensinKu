import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../widgets/vehicle_icon.dart';
import '../onboarding/add_vehicle_page.dart';
import 'vehicle_detail_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
      backgroundColor: const Color(0xFFF2F8FA),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: cs.primary,
        backgroundColor: cs.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // ─── Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    // Back button jika dipush sebagai route
                    if (Navigator.of(context).canPop()) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_back_rounded,
                              color: cs.primary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ] else ...[
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, cs.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.person_rounded,
                            color: cs.onPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profil',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Kelola akun dan kendaraanmu',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── User identity card ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.secondary],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Pengguna' : name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: cs.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email.isEmpty ? '—' : email,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onPrimary.withValues(alpha: 0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ─── Vehicles section ──────────────────────────────────────
              FutureBuilder<List<Vehicle>>(
                future: _repo.listVehicles(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _ErrorCard(message: snap.error.toString());
                  }
                  final vehicles = snap.data;
                  if (vehicles == null) {
                    return const _LoadingCard();
                  }

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.directions_car_rounded,
                                color: cs.secondary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Kendaraanku',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AddVehiclePage(),
                                  ),
                                );
                                if (!mounted) return;
                                setState(() {});
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('+ Tambah',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (vehicles.isEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Belum ada kendaraan yang ditambahkan.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...vehicles.map(
                            (v) => _VehicleItem(vehicle: v),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // ─── Logout section ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: cs.error,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keluar',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Logout dari akun BensinKu',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Keluar dari Akun?'),
                            content: const Text(
                                'Kamu akan logout dari BensinKu.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(false),
                                child: const Text('Batal'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(true),
                                child: const Text('Keluar'),
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
                      icon: Icon(Icons.logout_rounded,
                          size: 16, color: cs.error),
                      label: Text(
                        'Keluar dari Akun',
                        style: TextStyle(
                            color: cs.error, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side:
                            BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ─── Preferensi Berkendara ───────────────────────────────────
              _PreferencesCard(onEdit: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _PreferencesEditPage(),
                  ),
                );
                setState(() {}); // Refresh setelah edit
              }),
              const SizedBox(height: 18),

              // ─── Footer ───────────────────────────────────────────────
              Center(
                child: Text(
                  'BensinKu • v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleItem extends StatelessWidget {
  const _VehicleItem({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMotor = vehicle.type == VehicleType.motor;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VehicleDetailPage(vehicle: vehicle),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMotor
              ? cs.primaryContainer.withValues(alpha: 0.5)
              : cs.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMotor
                ? cs.primary.withValues(alpha: 0.2)
                : cs.secondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: isMotor ? cs.primaryContainer : cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: VehicleIcon(type: vehicle.type),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vehicle.type.label} • ${vehicle.tankCapacityLiters == null ? '— L tank' : '${vehicle.tankCapacityLiters} L tank'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(color: cs.primary, strokeWidth: 2),
          const SizedBox(width: 14),
          const Text('Memuat kendaraan...'),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preferences Card (profile_tab)
// ─────────────────────────────────────────────────────────────────────────────

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta =
        Supabase.instance.client.auth.currentUser?.userMetadata;
    final weeklyKm = meta?['weekly_km'];
    final weeklyCount = meta?['weekly_refuel_count'];
    final prefFuelId = meta?['preferred_fuel_id'];

    final hasPrefs = weeklyKm != null || weeklyCount != null || prefFuelId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
            child: Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(Icons.tune_rounded, color: cs.tertiary, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Preferensi Berkendara',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  tooltip: 'Edit',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: hasPrefs
                ? Column(
                    children: [
                      if (weeklyKm is num)
                        _PrefRow(
                          icon: Icons.route_rounded,
                          label: 'Jarak per minggu',
                          value: '${weeklyKm.toStringAsFixed(0)} km',
                        ),
                      if (weeklyKm is num && weeklyCount is num)
                        const SizedBox(height: 8),
                      if (weeklyCount is num)
                        _PrefRow(
                          icon: Icons.local_gas_station_rounded,
                          label: 'Frekuensi isi',
                          value: '${weeklyCount.round()}× per minggu',
                        ),
                      if ((weeklyKm is num || weeklyCount is num) &&
                          prefFuelId != null)
                        const SizedBox(height: 8),
                      if (prefFuelId != null)
                        _PrefRow(
                          icon: Icons.water_drop_rounded,
                          label: 'BBM favorit',
                          value: 'Terpilih',
                        ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14,
                          color:
                              cs.onSurfaceVariant.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Belum ada preferensi. Isi sekarang untuk prediksi yang lebih akurat.',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow(
      {required this.icon,
      required this.label,
      required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit preferences page — wrap SetupPreferencesPage without full onboarding nav
// ─────────────────────────────────────────────────────────────────────────────

class _PreferencesEditPage extends StatelessWidget {
  const _PreferencesEditPage();

  @override
  Widget build(BuildContext context) {
    // Reuse SetupPreferencesPage dalam mode edit:
    // tombol Simpan & Lewati akan pushAndRemoveUntil ke HomeShell,
    // tapi dari sini kita push sebagai route biasa — jadi back button tetap ada.
    // Untuk menghindari navigasi ke HomeShell dari dalam sini,
    // kita bungkus dengan WillPopScope dan intercept navigasi.
    return const _EditPreferencesWrapper();
  }
}

class _EditPreferencesWrapper extends StatefulWidget {
  const _EditPreferencesWrapper();

  @override
  State<_EditPreferencesWrapper> createState() =>
      _EditPreferencesWrapperState();
}

class _EditPreferencesWrapperState
    extends State<_EditPreferencesWrapper> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _weeklyKmCtrl = TextEditingController();

  String? _preferredFuelId;
  double _weeklyRefuelCount = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meta =
        Supabase.instance.client.auth.currentUser?.userMetadata;
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
          const SnackBar(
              content: Text('Preferensi disimpan ✓')),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Edit Preferensi',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<List<FuelProduct>>(
        future: _repo.listFuelProducts(),
        builder: (context, snap) {
          final products = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Disclaimer
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: cs.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Semakin detail, prediksi bensin makin akurat.',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // BBM Favorit
              _QuestionSection(
                number: '1',
                title: 'BBM favorit kamu',
                subtitle: 'Auto-select saat isi bensin',
                child: products.isEmpty
                    ? const _LoadingItem()
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: products.map((p) {
                          final sel = _preferredFuelId == p.id;
                          return GestureDetector(
                            onTap: () => setState(() =>
                                _preferredFuelId = sel ? null : p.id),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest
                                        .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: sel
                                      ? cs.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                p.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: sel
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

              // km/minggu
              _QuestionSection(
                number: '2',
                title: 'Jarak per minggu',
                subtitle: 'Fallback prediksi jika belum ada GPS trip',
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

              // Frekuensi isi
              _QuestionSection(
                number: '3',
                title: 'Frekuensi isi per minggu',
                subtitle: 'Estimasi konsumsi bahan bakar',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_weeklyRefuelCount.round()}×',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: cs.primary,
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
                            '${_weeklyRefuelCount.round()}× seminggu',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      min: 1,
                      max: 7,
                      divisions: 6,
                      value: _weeklyRefuelCount,
                      onChanged: (v) =>
                          setState(() => _weeklyRefuelCount = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label:
                      Text(_saving ? 'Menyimpan...' : 'Simpan Preferensi'),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuestionSection extends StatelessWidget {
  const _QuestionSection({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 24,
                width: 24,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(number,
                      style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LoadingItem extends StatelessWidget {
  const _LoadingItem();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
