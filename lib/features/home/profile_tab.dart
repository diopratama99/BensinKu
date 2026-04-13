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
                        await Supabase.instance.client.auth.signOut();
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
