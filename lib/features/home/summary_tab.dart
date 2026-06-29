import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/prediction_service.dart';
import '../../widgets/user_avatar.dart';
import '../calculator/calculator_page.dart';
import '../chat/chat_page.dart';
import 'fuel_detail_page.dart';
import 'history_tab.dart';
import 'timeline_page.dart';

/// Beranda — dashboard gaya digital-bank.
///
/// Panel hero kuning (greeting + total pengeluaran + ringkasan) yang
/// membentang ke atas, kartu quick-action yang mengambang menumpuk hero,
/// lalu kartu putih: prediksi bensin, pengisian terakhir, dan riwayat.
class SummaryTab extends StatefulWidget {
  const SummaryTab({
    super.key,
    this.onGoToHistory,
    this.onGoToProfile,
    this.onAddFuel,
    this.onGoToAnalytics,
    this.onGoToMaintenance,
  });

  final VoidCallback? onGoToHistory;
  final VoidCallback? onGoToProfile;
  final VoidCallback? onAddFuel;
  final VoidCallback? onGoToAnalytics;
  final VoidCallback? onGoToMaintenance;

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  final _repo = SupabaseRepository.ofDefaultClient();

  String? _vehicleId;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  final _date = DateFormat('d MMM yyyy', 'id_ID');

  final _scroll = ScrollController();
  // 0 = kuning & besar (atas), 1 = canvas & kecil (ter-scroll).
  final ValueNotifier<double> _headerT = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    const threshold = 150.0;
    _headerT.value = (_scroll.offset / threshold).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _headerT.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return RefreshIndicator(
      edgeOffset: topInset + 74,
      onRefresh: () async {
        try {
          await Supabase.instance.client.auth.getUser();
        } catch (_) {}
        UserAvatar.bumpCacheBust();
        setState(() {});
      },
      color: AppEditorial.ink,
      backgroundColor: AppEditorial.cream,
      child: FutureBuilder<List<Vehicle>>(
        future: _repo.listVehicles(),
        builder: (context, vehiclesSnap) {
          if (vehiclesSnap.hasError) {
            return _CenteredError(vehiclesSnap.error.toString());
          }
          final vehicles = vehiclesSnap.data;
          if (vehicles == null) return const _SummarySkeleton();

          if (vehicles.isEmpty) {
            return const _CenteredEmpty(
              title: 'Belum ada kendaraan.',
              subtitle: 'Tambah dulu di tab Profil.',
            );
          }

          _vehicleId ??= vehicles.first.id;

          return FutureBuilder<(List<Refuel>, List<Trip>)>(
            future: () async {
              final now = DateTime.now();
              final monthStart = DateTime(now.year, now.month, 1);
              final results = await Future.wait([
                _repo.listRefuels(vehicleId: _vehicleId),
                _repo.listTrips(vehicleId: _vehicleId, since: monthStart),
              ]);
              return (results[0] as List<Refuel>, results[1] as List<Trip>);
            }(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _CenteredError(snap.error.toString());
              }
              final data = snap.data;

              final refuels = data?.$1 ?? const <Refuel>[];
              final monthTrips = data?.$2 ?? const <Trip>[];

              final now = DateTime.now();
              final monthStart = DateTime(now.year, now.month, 1);
              final nextMonth = now.month == 12
                  ? DateTime(now.year + 1, 1, 1)
                  : DateTime(now.year, now.month + 1, 1);

              final monthRefuels = refuels.where((r) =>
                  !r.refuelDate.isBefore(monthStart) &&
                  r.refuelDate.isBefore(nextMonth)).toList();

              final totalSpend =
                  monthRefuels.fold<num>(0, (sum, r) => sum + r.totalRp);
              final totalLiters =
                  monthRefuels.fold<num>(0, (sum, r) => sum + r.liters);
              final tripDistanceKm = monthTrips.fold<double>(
                  0, (sum, t) => sum + (t.distanceKm ?? 0));

              final lastRefuel =
                  refuels.isNotEmpty ? refuels.first : null;
              final selectedVehicle = vehicles.firstWhere(
                (v) => v.id == _vehicleId,
                orElse: () => vehicles.first,
              );

              final headerH = topInset + 74;
              return Stack(
                children: [
                  ListView(
                    controller: _scroll,
                    padding: EdgeInsets.zero,
                    children: [
                      // Filler kuning yang membentang jauh ke atas (tinggi
                      // layout 0, tapi melukis ke atas via OverflowBox). Saat
                      // refresh ditarik sangat kencang, area di atas hero tetap
                      // kuning — tak ada garis putih.
                      SizedBox(
                        height: 0,
                        child: OverflowBox(
                          minHeight: 0,
                          maxHeight: 2000,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 2000,
                            color: AppEditorial.brand,
                          ),
                        ),
                      ),
                      // ── Hero body (kuning) — saldo + ringkasan ──
                      // Background kuning dibentangkan sampai ke atas (di balik
                      // header) lewat padding atas = headerH. Karena ikut
                      // di-scroll dalam satu widget, seam dgn header tak pernah
                      // bocor putih walau ditarik kencang saat refresh.
                      Container(
                        color: AppEditorial.brand,
                        padding: EdgeInsets.only(top: headerH),
                        child: _HeroBody(
                          totalSpend: totalSpend,
                          totalLiters: totalLiters,
                          distanceKm: tripDistanceKm,
                          refuelCount: monthRefuels.length,
                          rupiah: _rupiah,
                          loading: data == null,
                        ),
                      ),

                  // ── Strip fade + quick actions (pakai Stack supaya
                  //    tombol tetap bisa ditekan; Transform.translate
                  //    memindah area sentuh ke posisi lama → tidak responsif)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Strip fade: kuning melebur ke background.
                          Container(
                            height: 48,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppEditorial.brand,
                                  AppEditorial.canvas
                                ],
                              ),
                            ),
                          ),
                          // Ruang agar kartu yang menumpuk tetap di dalam
                          // batas Stack (penting untuk hit-test).
                          const SizedBox(height: 80),
                        ],
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 0,
                        child: _QuickActions(
                          onAssistant: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ChatPage(vehicles: vehicles),
                            ),
                          ),
                          onCalculator: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CalculatorPage(),
                            ),
                          ),
                          onHistory: _openHistory,
                          onTimeline: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TimelinePage(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Prediksi
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const EditorialSectionHeader(
                      label: 'Prediksi bensin',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _FuelPredictionBlock(vehicle: selectedVehicle),
                  ),
                  const SizedBox(height: 28),

                  // Pengisian terakhir
                  if (lastRefuel != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const EditorialSectionHeader(
                        label: 'Pengisian terakhir',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _LastRefuelCard(
                        refuel: lastRefuel,
                        rupiah: _rupiah,
                        date: _date,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Riwayat — tampilan kalender (beda dari tab Riwayat)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: EditorialSectionHeader(
                      label: 'Riwayat',
                      trailing:
                          EditorialSeeAll(onTap: _openHistory),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _HistoryCalendar(
                      refuels: refuels,
                    ),
                  ),
                  const SizedBox(height: 130),
                    ],
                  ),
                  // Header tetap (pinned) — mengecil & warna ber-transisi.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _headerT,
                      builder: (context, t, _) => _GreetingBar(
                        vehicle: selectedVehicle,
                        expandedHeight: headerH,
                        topInset: topInset,
                        t: t,
                        onPickVehicle: () => _pickVehicle(vehicles),
                        onTapProfile: widget.onGoToProfile,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppEditorial.canvas,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Riwayat',
              style: AppEditorial.heading(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          body: const HistoryTab(),
        ),
      ),
    );
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppEditorial.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppEditorial.hairline,
                    borderRadius: BorderRadius.circular(AppEditorial.rPill),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Pilih kendaraan',
                      style: AppEditorial.heading(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      )),
                  const Spacer(),
                  Text('${vehicles.length} unit',
                      style: AppEditorial.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppEditorial.inkMuted,
                      )),
                ],
              ),
              const SizedBox(height: 16),
              ...vehicles.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VehicleRow(
                      vehicle: v,
                      isSelected: v.id == _vehicleId,
                      onTap: () => Navigator.of(ctx).pop(v.id),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != _vehicleId) {
      setState(() => _vehicleId = picked);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting bar — header TETAP (pinned). Warna ber-transisi saat scroll.
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingBar extends StatelessWidget {
  const _GreetingBar({
    required this.vehicle,
    required this.expandedHeight,
    required this.topInset,
    required this.t,
    required this.onPickVehicle,
    this.onTapProfile,
  });

  final Vehicle vehicle;
  final double expandedHeight;
  final double topInset;
  final double t; // 0 = besar/kuning, 1 = kecil/canvas
  final VoidCallback onPickVehicle;
  final VoidCallback? onTapProfile;

  String _greeting(int hour) {
    if (hour >= 4 && hour < 11) return 'Selamat pagi';
    if (hour >= 11 && hour < 15) return 'Selamat siang';
    if (hour >= 15 && hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final raw = user?.userMetadata?['name'];
    var name = raw is String ? raw.trim() : '';
    if (name.isEmpty) {
      final email = user?.email ?? '';
      name = email.contains('@') ? email.split('@').first : 'Pengendara';
    }
    final firstName = name.split(' ').first;

    // Interpolasi (smooth, didorong oleh posisi scroll).
    final collapsedHeight = topInset + 56;
    final height =
        expandedHeight + (collapsedHeight - expandedHeight) * t;
    final avatar = 46 - 12 * t;
    final nameSize = 18 - 2.5 * t;
    final bg = Color.lerp(AppEditorial.brand, AppEditorial.canvas, t)!;

    return Container(
      height: height,
      width: double.infinity,
      color: bg,
      padding: EdgeInsets.only(left: 20, right: 20, top: topInset),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapProfile,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                UserAvatar(
                  size: avatar,
                  shape: BoxShape.circle,
                  borderColor: const Color(0xFFFFFFFF),
                  borderWidth: 2.5,
                ),
                const SizedBox(width: 11),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sapaan — tampil saat full, menyusut & memudar saat collapse.
                    ClipRect(
                      child: Align(
                        alignment: Alignment.topLeft,
                        heightFactor: (1 - t).clamp(0.0, 1.0),
                        child: Opacity(
                          opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              _greeting(DateTime.now().hour),
                              style: AppEditorial.sans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppEditorial.brandDeep,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      firstName,
                      style: AppEditorial.heading(
                        fontSize: nameSize,
                        fontWeight: FontWeight.w700,
                        color: AppEditorial.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          _VehiclePill(vehicle: vehicle, onTap: onPickVehicle),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero body — saldo (pengeluaran bulan ini) + ringkasan. Ikut scroll.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBody extends StatelessWidget {
  const _HeroBody({
    required this.totalSpend,
    required this.totalLiters,
    required this.distanceKm,
    required this.refuelCount,
    required this.rupiah,
    required this.loading,
  });

  final num totalSpend;
  final num totalLiters;
  final num distanceKm;
  final int refuelCount;
  final NumberFormat rupiah;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final monthName =
        DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now());

    return Container(
      width: double.infinity,
      color: AppEditorial.brand,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengeluaran bensin · $monthName',
            style: AppEditorial.sans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppEditorial.ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rp',
                style: AppEditorial.heading(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppEditorial.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: loading
                      ? Text(
                          '•••',
                          style: AppEditorial.heading(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.8,
                            color: AppEditorial.ink,
                            height: 1.0,
                          ),
                        )
                      : AnimatedCount(
                          value: totalSpend.toDouble(),
                          formatter: (v) => rupiah.format(v).trim(),
                          style: AppEditorial.heading(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.8,
                            color: AppEditorial.ink,
                            height: 1.0,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppEditorial.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: Row(
              children: [
                _HeroStat(
                  label: 'Liter',
                  value:
                      totalLiters <= 0 ? '—' : totalLiters.toStringAsFixed(1),
                  unit: 'L',
                ),
                _heroDivider(),
                _HeroStat(
                  label: 'Jarak',
                  value: distanceKm <= 0 ? '—' : distanceKm.toStringAsFixed(0),
                  unit: 'km',
                ),
                _heroDivider(),
                _HeroStat(
                  label: 'Pengisian',
                  value: refuelCount.toString(),
                  unit: '×',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
        width: 1,
        height: 30,
        color: AppEditorial.ink.withValues(alpha: 0.1),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(
      {required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppEditorial.sans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppEditorial.ink.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppEditorial.heading(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppEditorial.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: AppEditorial.sans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppEditorial.ink.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiclePill extends StatelessWidget {
  const _VehiclePill({required this.vehicle, required this.onTap});
  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMotor = vehicle.type.label.toLowerCase().contains('motor');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(AppEditorial.rPill),
          boxShadow: [
            BoxShadow(
              color: AppEditorial.brandDeep.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppEditorial.brandTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMotor
                    ? PhosphorIconsRegular.motorcycle
                    : PhosphorIconsRegular.car,
                size: 17,
                color: AppEditorial.brandDeep,
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                vehicle.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: AppEditorial.heading(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.ink,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsRegular.caretUpDown,
                size: 16, color: AppEditorial.inkMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions — kartu putih mengambang menumpuk hero
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    this.onAssistant,
    this.onCalculator,
    this.onHistory,
    this.onTimeline,
  });

  final VoidCallback? onAssistant;
  final VoidCallback? onCalculator;
  final VoidCallback? onHistory;
  final VoidCallback? onTimeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        children: [
          _QuickAction(
            icon: PhosphorIconsRegular.wrench,
            label: 'AI',
            onTap: onAssistant,
            highlight: true,
          ),
          _QuickAction(
            icon: PhosphorIconsRegular.calculator,
            label: 'Kalkulator',
            onTap: onCalculator,
          ),
          _QuickAction(
            icon: PhosphorIconsRegular.receipt,
            label: 'Riwayat',
            onTap: onHistory,
          ),
          _QuickAction(
            icon: PhosphorIconsRegular.clockCounterClockwise,
            label: 'Linimasa',
            onTap: onTimeline,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: highlight
                    ? AppEditorial.brand
                    : AppEditorial.brandTint,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Icon(icon,
                  size: 24,
                  color:
                      highlight ? AppEditorial.ink : AppEditorial.brandDeep),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppEditorial.sans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppEditorial.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pengisian terakhir
// ─────────────────────────────────────────────────────────────────────────────

class _LastRefuelCard extends StatelessWidget {
  const _LastRefuelCard({
    required this.refuel,
    required this.rupiah,
    required this.date,
  });

  final Refuel refuel;
  final NumberFormat rupiah;
  final DateFormat date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppEditorial.brandTint,
              borderRadius: BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: const Icon(PhosphorIconsRegular.gasPump,
                color: AppEditorial.brandDeep, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rp ${rupiah.format(refuel.totalRp).trim()}',
                  style: AppEditorial.heading(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${refuel.liters.toStringAsFixed(2)} L · ${date.format(refuel.refuelDate)}',
                  style: AppEditorial.sans(
                    fontSize: 12.5,
                    color: AppEditorial.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (refuel.isFullTank)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppEditorial.brand,
                borderRadius: BorderRadius.circular(AppEditorial.rPill),
              ),
              child: Text(
                'Full',
                style: AppEditorial.sans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prediksi bensin
// ─────────────────────────────────────────────────────────────────────────────

class _FuelPredictionBlock extends StatelessWidget {
  const _FuelPredictionBlock({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository.ofDefaultClient();

    return FutureBuilder<(List<Refuel>, List<Trip>, List<EfficiencySample>)>(
      future: () async {
        final results = await Future.wait([
          repo.listRefuels(vehicleId: vehicle.id),
          repo.listTrips(vehicleId: vehicle.id),
          repo.recentEfficiencySamples(vehicleId: vehicle.id, limit: 20),
        ]);
        return (
          results[0] as List<Refuel>,
          results[1] as List<Trip>,
          results[2] as List<EfficiencySample>,
        );
      }(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _PredictionSkeleton();
        }
        if (snap.hasError || snap.data == null) {
          return const SizedBox.shrink();
        }

        final refuels = snap.data!.$1;
        final trips = snap.data!.$2;
        final samples = snap.data!.$3;

        final meta =
            Supabase.instance.client.auth.currentUser?.userMetadata;
        final usageProfile =
            UsageProfile.tryParse(meta?['usage_profile'] as String?);
        final primaryCity =
            PrimaryCity.tryParse(meta?['primary_city'] as String?);
        final weeklyKmPref = meta?['weekly_km'] is num
            ? meta!['weekly_km'] as num
            : null;

        final f = PredictionService.forecastRefill(
          vehicle: vehicle,
          refuels: refuels,
          trips: trips,
          samples: samples,
          primaryCity: primaryCity,
          usageProfile: usageProfile,
          weeklyKmPref: weeklyKmPref,
        );

        final remainingPct = f.remainingPct;
        final remaining = f.remainingLiters;
        final daysLeft = f.daysLeft;
        final predictedDate = f.predictedDate;

        final isWarning =
            remainingPct < 0.15 || (daysLeft != null && daysLeft < 2);
        final accent = isWarning ? AppEditorial.rust : AppEditorial.sage;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    FuelDetailPage(forecast: f, vehicle: vehicle),
              ),
            );
          },
          child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ring persen sisa bensin
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: CircularProgressIndicator(
                            value: remainingPct.clamp(0.0, 1.0),
                            strokeWidth: 7,
                            backgroundColor: AppEditorial.hairline,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accent),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '${(remainingPct * 100).toStringAsFixed(0)}%',
                          style: AppEditorial.heading(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppEditorial.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusPill(
                          label: isWarning ? 'Hampir habis' : 'Normal',
                          color: accent,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${remaining.toStringAsFixed(1)} L tersisa',
                          style: AppEditorial.heading(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          daysLeft != null
                              ? 'Cukup untuk ~${daysLeft.toStringAsFixed(0)} hari lagi'
                              : 'Belum cukup data',
                          style: AppEditorial.sans(
                            fontSize: 12.5,
                            color: AppEditorial.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(PhosphorIconsRegular.caretRight,
                      size: 22, color: AppEditorial.inkMuted),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: AppEditorial.hairlineSoft),
              const SizedBox(height: 4),
              EditorialDataRow(
                label: 'Perkiraan isi ulang',
                value: predictedDate != null
                    ? DateFormat('d MMM yyyy', 'id_ID').format(predictedDate)
                    : '—',
              ),
              EditorialDataRow(
                label: 'Konsumsi',
                value: f.litersPerDay > 0
                    ? '${f.litersPerDay.toStringAsFixed(2)} L/hari'
                    : '—',
              ),
              EditorialDataRow(
                label: 'Efisiensi',
                value: '${f.kmPerLiter.toStringAsFixed(1)} km/L',
                isLast: true,
              ),
            ],
          ),
        ));
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppEditorial.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppEditorial.sans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: AppEditorial.inkMuted),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riwayat — kalender bulan ini (tanda pengisian)
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({required this.refuels});
  final List<Refuel> refuels;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName =
        DateFormat('MMMM yyyy', 'id_ID').format(now);

    // Tandai tanggal (bulan ini) yang punya pengisian.
    final marks = <int>{};
    for (final r in refuels) {
      if (r.refuelDate.year == now.year &&
          r.refuelDate.month == now.month) {
        marks.add(r.refuelDate.day);
      }
    }

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstWeekday = DateTime(now.year, now.month, 1).weekday; // Mon=1
    final leading = firstWeekday - 1;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7.0).ceil();

    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                monthName,
                style: AppEditorial.heading(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppEditorial.brand,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Ada pengisian',
                style: AppEditorial.sans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppEditorial.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Header hari
          Row(
            children: [
              for (final d in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppEditorial.sans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppEditorial.inkMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Grid tanggal
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      day: _dayForCell(row, col, leading, daysInMonth),
                      hasRefuel: marks.contains(
                          _dayForCell(row, col, leading, daysInMonth)),
                      isToday: _dayForCell(row, col, leading, daysInMonth) ==
                          now.day,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  int? _dayForCell(int row, int col, int leading, int daysInMonth) {
    final index = row * 7 + col;
    final day = index - leading + 1;
    if (day < 1 || day > daysInMonth) return null;
    return day;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasRefuel,
    required this.isToday,
  });
  final int? day;
  final bool hasRefuel;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox(height: 40);
    }
    return SizedBox(
      height: 40,
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasRefuel ? AppEditorial.brand : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !hasRefuel
                ? Border.all(color: AppEditorial.ink, width: 1.4)
                : null,
          ),
          child: Text(
            '$day',
            style: AppEditorial.mono(
              fontSize: 13,
              fontWeight: hasRefuel || isToday
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: hasRefuel
                  ? AppEditorial.ink
                  : (isToday ? AppEditorial.ink : AppEditorial.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle row (di sheet pemilih kendaraan)
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMotor = vehicle.type.label.toLowerCase().contains('motor');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppEditorial.rCard),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppEditorial.brandTint : AppEditorial.cream,
          border: Border.all(
            color: isSelected ? AppEditorial.brand : AppEditorial.hairline,
            width: isSelected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(AppEditorial.rCard),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppEditorial.brandSoft,
                borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              ),
              child: Icon(
                isMotor
                    ? PhosphorIconsRegular.motorcycle
                    : PhosphorIconsRegular.car,
                size: 24,
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle.tankCapacityLiters == null
                        ? '${vehicle.type.label} · tanki belum diatur'
                        : '${vehicle.type.label} · tanki ${vehicle.tankCapacityLiters}L',
                    style: AppEditorial.sans(
                      fontSize: 12,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppEditorial.ink : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppEditorial.ink : AppEditorial.hairline,
                  width: 1.4,
                ),
              ),
              child: isSelected
                  ? const Icon(PhosphorIconsRegular.check,
                      size: 15, color: AppEditorial.brand)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error / Empty
// ─────────────────────────────────────────────────────────────────────────────

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  // Tone placeholder untuk area di atas panel kuning.
  static const Color _onBrand = Color(0xFFE9B528);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // ── Header + hero (kuning) ──
        Container(
          color: AppEditorial.brand,
          padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Skeleton.circle(size: 46, color: _onBrand),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Skeleton(width: 70, height: 11, baseColor: _onBrand),
                      SizedBox(height: 7),
                      Skeleton(width: 96, height: 16, baseColor: _onBrand),
                    ],
                  ),
                  const Spacer(),
                  Skeleton(
                    width: 104,
                    height: 42,
                    radius: AppEditorial.rPill,
                    baseColor: const Color(0xFFFFFFFF),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Skeleton(width: 190, height: 12, baseColor: _onBrand),
              const SizedBox(height: 14),
              const Skeleton(width: 230, height: 38, baseColor: _onBrand),
              const SizedBox(height: 22),
              Skeleton(
                width: double.infinity,
                height: 58,
                baseColor: _onBrand,
              ),
            ],
          ),
        ),

        // ── Quick actions (kartu putih) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: EditorialCard(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Row(
              children: List.generate(
                4,
                (_) => Expanded(
                  child: Column(
                    children: const [
                      Skeleton(width: 52, height: 52, radius: AppEditorial.rTiny),
                      SizedBox(height: 8),
                      Skeleton(width: 46, height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Prediksi bensin ──
        _section(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Skeleton.circle(size: 72),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(width: 80, height: 22, radius: AppEditorial.rPill),
                          SizedBox(height: 12),
                          Skeleton(width: 140, height: 20),
                          SizedBox(height: 8),
                          Skeleton(width: 110, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < 3; i++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Skeleton(width: 120, height: 13),
                      Skeleton(width: 80, height: 13),
                    ],
                  ),
                  if (i < 2) const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Pengisian terakhir ──
        _section(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EditorialCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: const [
                Skeleton(width: 48, height: 48, radius: AppEditorial.rTiny),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 130, height: 18),
                      SizedBox(height: 8),
                      Skeleton(width: 170, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Riwayat (kalender) ──
        _section(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Skeleton(width: 110, height: 18),
                    Skeleton(width: 90, height: 12),
                  ],
                ),
                const SizedBox(height: 20),
                for (var r = 0; r < 4; r++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      7,
                      (_) => const Skeleton.circle(size: 26),
                    ),
                  ),
                  if (r < 3) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _section() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Skeleton(width: 150, height: 18),
        ),
      );
}

class _CenteredError extends StatelessWidget {
  const _CenteredError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      children: [
        Text(
          'Gagal memuat data',
          style: AppEditorial.heading(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: AppEditorial.sans(
            fontSize: 13,
            color: AppEditorial.inkSoft,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CenteredEmpty extends StatelessWidget {
  const _CenteredEmpty({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      children: [
        AspectRatio(
          aspectRatio: 800 / 600,
          child: Image.asset(
            'assets/illustrations/empty_garasi.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: AppEditorial.heading(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppEditorial.sans(
            fontSize: 13,
            color: AppEditorial.inkSoft,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
