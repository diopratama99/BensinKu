import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../trip/trip_map_screen.dart';
import 'add_refuel_tab.dart';
import 'analytics_tab.dart';
import 'history_tab.dart';
import 'profile_tab.dart';
import 'summary_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Index mapping: 0=Home, 1=Statistik, 2=Add(sheet), 3=Riwayat, 4=Peta
  int _index = 0;
  bool _sheetOpen = false;

  // Increment saat tab diaktifkan → tab rebuild + fetch data terbaru
  final _refreshCounters = {0: 0, 1: 0, 3: 0, 4: 0};

  void _onTabTapped(int index) {
    if (index == 2) {
      _toggleAddFuelSheet();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _index = index;
      // Refresh tab yang dituju saat pindah
      _refreshCounters[index] = (_refreshCounters[index] ?? 0) + 1;
    });
  }

  Future<void> _toggleAddFuelSheet() async {
    if (_sheetOpen) return;
    HapticFeedback.mediumImpact();
    setState(() => _sheetOpen = true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => const _AddFuelSheet(),
    );

    if (mounted) {
      setState(() {
        _sheetOpen = false;
        // Setelah isi bensin, refresh home & analytics
        _refreshCounters[0] = (_refreshCounters[0] ?? 0) + 1;
        _refreshCounters[1] = (_refreshCounters[1] ?? 0) + 1;
      });
    }
  }

  void _openProfile() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileTab()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final stackIndex = switch (_index) {
      0 => 0,
      1 => 1,
      3 => 2,
      4 => 3,
      _ => 0,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F8FA),
        appBar: _buildAppBar(cs),
        body: IndexedStack(
          index: stackIndex,
          children: [
            SummaryTab(
              key: ValueKey('summary-${_refreshCounters[0]}'),
              onGoToHistory: () => setState(() {
                _index = 3;
                _refreshCounters[3] = (_refreshCounters[3] ?? 0) + 1;
              }),
              onGoToProfile: _openProfile,
            ),
            AnalyticsTab(
              key: ValueKey('analytics-${_refreshCounters[1]}'),
            ),
            HistoryTab(
              key: ValueKey('history-${_refreshCounters[3]}'),
            ),
            const TripMapScreen(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 72,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(0,
                      iconData: Icons.home_rounded, label: 'Home'),
                ),
                Expanded(
                  child: _buildNavItem(1,
                      iconData: Icons.bar_chart_rounded, label: 'Statistik'),
                ),
                Expanded(child: _buildAddButton(cs)),
                Expanded(
                  child: _buildNavItem(3,
                      iconData: Icons.history_rounded, label: 'Riwayat'),
                ),
                Expanded(
                  child: _buildNavItem(4,
                      iconData: Icons.map_rounded, label: 'Peta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Per-tab fixed AppBar ─────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    switch (_index) {
      case 0:
        return AppBar(
          backgroundColor: const Color(0xFFF2F8FA),
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: const Color(0xFFF2F8FA),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_gas_station_rounded,
                  color: cs.onPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BensinKu',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: -0.3,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Pantau pengeluaran BBM-mu',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: _openProfile,
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: cs.primary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        );

      case 1:
        return AppBar(
          backgroundColor: const Color(0xFFF2F8FA),
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: const Color(0xFFF2F8FA),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.bar_chart_rounded, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistik',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: cs.onSurface),
                  ),
                  Text(
                    'Analisis pengeluaran BBM-mu',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        );

      case 3:
        return AppBar(
          backgroundColor: const Color(0xFFF2F8FA),
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: const Color(0xFFF2F8FA),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.history_rounded, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: cs.onSurface),
                  ),
                  Text(
                    'Semua pengisian BBM',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        );

      case 4:
        return AppBar(
          backgroundColor: const Color(0xFFF2F8FA),
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: const Color(0xFFF2F8FA),
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.map_rounded, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peta',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: cs.onSurface),
                  ),
                  Text(
                    'Lacak perjalananmu',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return AppBar(
          backgroundColor: const Color(0xFFF2F8FA),
          elevation: 0,
          automaticallyImplyLeading: false,
        );
    }
  }

  // ── Bottom nav helpers ───────────────────────────────────────────────────

  Widget _buildAddButton(ColorScheme cs) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleAddFuelSheet,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: _sheetOpen
                  ? cs.primary.withValues(alpha: 0.15)
                  : cs.primary,
              shape: BoxShape.circle,
              boxShadow: _sheetOpen
                  ? []
                  : [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: AnimatedRotation(
              turns: _sheetOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: _sheetOpen ? cs.primary : cs.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: _sheetOpen ? cs.primary : cs.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
            child: const Text('Isi BBM'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int targetIndex, {
    required IconData iconData,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _index == targetIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(targetIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                iconData,
                key: ValueKey('${targetIndex}_$isSelected'),
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                size: isSelected ? 24 : 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                letterSpacing: 0.1,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Fuel bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddFuelSheet extends StatelessWidget {
  const _AddFuelSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Input Pengisian',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Nominal (Rp) saja. Liter dihitung otomatis.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: cs.onSurfaceVariant, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const Expanded(child: AddRefuelTab()),
        ],
      ),
    );
  }
}
