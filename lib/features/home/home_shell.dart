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
  // Profile is accessed via header avatar button → overlay / separate route
  int _index = 0;
  bool _sheetOpen = false;

  // Whether profile panel is showing (pushed as page)
  void _onTabTapped(int index) {
    if (index == 2) {
      _toggleAddFuelSheet();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _index = index);
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

    if (mounted) setState(() => _sheetOpen = false);
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

    // Map shell index to IndexedStack child index
    // Shell: 0=Home, 1=Statistik, 3=Riwayat, 4=Peta
    // Stack: 0=Home, 1=Statistik, 2=Riwayat, 3=Peta
    final stackIndex = switch (_index) {
      0 => 0,
      1 => 1,
      3 => 2,
      4 => 3,
      _ => 0,
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: stackIndex,
          children: [
            SummaryTab(
              onGoToHistory: () => setState(() => _index = 3),
              onGoToProfile: _openProfile,
            ),
            const AnalyticsTab(),
            const HistoryTab(),
            const TripMapScreen(),
          ],
        ),
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
              // ── Center Add Button ──
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
    );
  }

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
