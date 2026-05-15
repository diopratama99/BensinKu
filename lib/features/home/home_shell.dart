import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../trip/trip_map_screen.dart';
import 'add_refuel_tab.dart';
import 'analytics_tab.dart';
import 'history_tab.dart';
import 'profile_tab.dart';
import 'receipt_processing_sheet.dart';
import 'summary_tab.dart';
import 'voice_input_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Index mapping: 0=Home, 1=Statistik, 2=Add(sheet), 3=Riwayat, 4=Peta
  int _index = 0;
  bool _sheetOpen = false;

  final _refreshCounters = {0: 0, 1: 0, 3: 0, 4: 0};

  void _onTabTapped(int index) {
    if (index == 2) {
      _openAddActions();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _index = index;
      _refreshCounters[index] = (_refreshCounters[index] ?? 0) + 1;
    });
  }

  Future<void> _toggleAddFuelSheet({ParsedRefuel? prefill}) async {
    if (_sheetOpen) return;
    HapticFeedback.mediumImpact();
    setState(() => _sheetOpen = true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _AddFuelSheet(prefill: prefill),
    );

    if (mounted) {
      setState(() {
        _sheetOpen = false;
        _refreshCounters[0] = (_refreshCounters[0] ?? 0) + 1;
        _refreshCounters[1] = (_refreshCounters[1] ?? 0) + 1;
      });
    }
  }

  Future<void> _openAddActions() async {
    if (_sheetOpen) return;
    HapticFeedback.mediumImpact();
    setState(() => _sheetOpen = true);

    final action = await showGeneralDialog<_AddAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup',
      barrierColor: AppEditorial.ink.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, _, __) {
        return _AddActionsOverlay(animation: anim);
      },
    );

    if (mounted) setState(() => _sheetOpen = false);

    if (!mounted || action == null) return;

    switch (action) {
      case _AddAction.manual:
        await _toggleAddFuelSheet();
      case _AddAction.voice:
        await _runVoiceFlow();
      case _AddAction.camera:
        await _runCameraFlow();
    }
  }

  Future<void> _runVoiceFlow() async {
    final parsed = await showModalBottomSheet<ParsedRefuel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppEditorial.ink.withValues(alpha: 0.55),
      builder: (_) => const VoiceInputSheet(),
    );
    if (!mounted || parsed == null) return;
    await _toggleAddFuelSheet(prefill: parsed);
  }

  Future<void> _runCameraFlow() async {
    final picker = ImagePicker();
    final source = await _pickImageSource();
    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (!mounted || picked == null) return;

    final parsed = await showModalBottomSheet<ParsedRefuel>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: AppEditorial.ink.withValues(alpha: 0.55),
      builder: (_) => ReceiptProcessingSheet(image: picked),
    );
    if (!mounted || parsed == null) return;
    await _toggleAddFuelSheet(prefill: parsed);
  }

  Future<ImageSource?> _pickImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppEditorial.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  color: AppEditorial.hairline,
                ),
              ),
              const SizedBox(height: 18),
              Text('SUMBER FOTO', style: AppEditorial.eyebrow()),
              const SizedBox(height: 14),
              Container(height: 1, color: AppEditorial.hairlineSoft),
              _SourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Ambil foto baru',
                subtitle: 'Foto langsung struk SPBU',
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              Container(height: 1, color: AppEditorial.hairlineSoft),
              _SourceTile(
                icon: Icons.image_outlined,
                title: 'Pilih dari galeri',
                subtitle: 'Foto struk yang sudah ada',
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              Container(height: 1, color: AppEditorial.hairlineSoft),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfile() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileTab()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: AppEditorial.canvas,
        extendBody: true,
        appBar: _buildAppBar(),
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
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── App bar (compact masthead, NOT giant italic) ──────────────────────

  PreferredSizeWidget _buildAppBar() {
    final now = DateTime.now();
    final dateStr =
        DateFormat('d.MM.yy', 'id_ID').format(now);
    final dayCode =
        DateFormat('EEE', 'id_ID').format(now).toUpperCase();

    final pageName = switch (_index) {
      0 => 'BERANDA',
      1 => 'ANALISA',
      3 => 'ARSIP',
      4 => 'RUTE',
      _ => 'BERANDA',
    };

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
              child: Row(
                children: [
                  Text(
                    pageName,
                    style: AppEditorial.mono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$dayCode $dateStr',
                    style: AppEditorial.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_index == 0)
                    GestureDetector(
                      onTap: _openProfile,
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          color: AppEditorial.cream,
                          border: Border.all(
                              color: AppEditorial.hairline, width: 1),
                          borderRadius: BorderRadius.circular(
                              AppEditorial.rTiny),
                        ),
                        child: const Icon(Icons.person_outline_rounded,
                            color: AppEditorial.ink, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 1, color: AppEditorial.ink),
          ],
        ),
      ),
    );
  }

  // ── Bottom nav (lifted FAB layout, halo-ring trick) ───────────────────

  Widget _buildBottomNav() {
    const barHeight = 72.0;
    const liftOverhang = 12.0;
    const addButtonSize = 64.0;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Total widget height: bar + how far the FAB pokes above + tiny pad
    // for shadow + bottom safe-area. The bar (canvas-painted) covers from
    // the divider all the way to the screen bottom, so no body content
    // shows through under the bar. Only the area ABOVE the divider (where
    // the FAB pokes out) is transparent.
    return SizedBox(
      height: barHeight + liftOverhang + 6 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Background bar (canvas + divider; covers safe-area too) ─
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // bar height + bottom safe-area, painted in canvas
            height: barHeight + bottomInset,
            child: Container(
              decoration: const BoxDecoration(
                color: AppEditorial.canvas,
                border: Border(
                  top: BorderSide(color: AppEditorial.ink, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: barHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            index: 0,
                            currentIndex: _index,
                            icon: Icons.home_outlined,
                            iconActive: Icons.home_rounded,
                            label: 'BERANDA',
                            onTap: _onTabTapped,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            index: 1,
                            currentIndex: _index,
                            icon: Icons.show_chart_rounded,
                            iconActive: Icons.show_chart_rounded,
                            label: 'ANALISA',
                            onTap: _onTabTapped,
                          ),
                        ),
                        // Gap reserved for the lifted FAB
                        const Expanded(child: SizedBox()),
                        Expanded(
                          child: _NavItem(
                            index: 3,
                            currentIndex: _index,
                            icon: Icons.receipt_long_outlined,
                            iconActive: Icons.receipt_long_rounded,
                            label: 'ARSIP',
                            onTap: _onTabTapped,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            index: 4,
                            currentIndex: _index,
                            icon: Icons.place_outlined,
                            iconActive: Icons.place_rounded,
                            label: 'RUTE',
                            onTap: _onTabTapped,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Lifted FAB (poking above the bar) ───────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: addButtonSize,
            child: Center(
              child: _AddButton(
                size: addButtonSize,
                onTap: _openAddActions,
                isOpen: _sheetOpen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData iconActive;
  final String label;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    final iconColor =
        selected ? AppEditorial.ink : AppEditorial.inkMuted;
    final labelColor =
        selected ? AppEditorial.ink : AppEditorial.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: () => onTap(index),
          radius: 32,
          highlightColor: Colors.transparent,
          splashColor: AppEditorial.butter.withValues(alpha: 0.18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fixed-size icon slot keeps the label baseline stable.
              SizedBox(
                width: 40,
                height: 36,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: selected ? 34 : 30,
                    height: selected ? 34 : 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppEditorial.butter
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      selected ? iconActive : icon,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppEditorial.mono(
                  fontSize: 9.5,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.size,
    required this.onTap,
    required this.isOpen,
  });

  final double size;
  final VoidCallback onTap;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    // Halo ring trick: the canvas-colored outer ring blends into the bar
    // background, so the section of the top hairline behind the FAB is
    // visually erased without us splitting the divider.
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppEditorial.canvas.withValues(alpha: 0.18),
        highlightColor: AppEditorial.canvas.withValues(alpha: 0.06),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppEditorial.canvas, // halo (matches bar bg)
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppEditorial.butterDeep.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4), // halo thickness
          alignment: Alignment.center,
          child: AnimatedRotation(
            turns: isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: Container(
              decoration: BoxDecoration(
                color: isOpen ? AppEditorial.canvas : AppEditorial.butter,
                shape: BoxShape.circle,
                border: Border.all(color: AppEditorial.ink, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: AppEditorial.ink,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Fuel bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddFuelSheet extends StatelessWidget {
  const _AddFuelSheet({this.prefill});

  final ParsedRefuel? prefill;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.92,
      decoration: const BoxDecoration(
        color: AppEditorial.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppEditorial.ink, width: 1),
          left: BorderSide(color: AppEditorial.ink, width: 1),
          right: BorderSide(color: AppEditorial.ink, width: 1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    color: AppEditorial.hairline,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      prefill == null
                          ? 'INPUT MANUAL'
                          : 'REVIEW HASIL AI',
                      style: AppEditorial.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close_rounded,
                          size: 22, color: AppEditorial.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Container(height: 1, color: AppEditorial.ink),
          Expanded(child: AddRefuelTab(prefill: prefill)),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppEditorial.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppEditorial.mono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppEditorial.sans(
                        fontSize: 12,
                        color: AppEditorial.inkSoft,
                      )),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppEditorial.ink),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add actions overlay
// ─────────────────────────────────────────────────────────────────────────────

enum _AddAction { camera, manual, voice }

class _AddActionsOverlay extends StatelessWidget {
  const _AddActionsOverlay({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // FAB center (matches _buildBottomNav layout: 88 stack height,
    // bar 64 high, FAB 64 high at top:0).
    final fabCenterY = mq.size.height - mq.padding.bottom - 56;
    final centerX = mq.size.width / 2;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        _MiniAction(
          animation: animation,
          target: Offset(centerX - 84, fabCenterY - 72),
          icon: Icons.photo_camera_outlined,
          label: 'STRUK',
          background: AppEditorial.canvas,
          foreground: AppEditorial.ink,
          onTap: () => Navigator.of(context).pop(_AddAction.camera),
        ),
        _MiniAction(
          animation: animation,
          target: Offset(centerX, fabCenterY - 124),
          icon: Icons.edit_outlined,
          label: 'MANUAL',
          background: AppEditorial.butter,
          foreground: AppEditorial.ink,
          onTap: () => Navigator.of(context).pop(_AddAction.manual),
          large: true,
        ),
        _MiniAction(
          animation: animation,
          target: Offset(centerX + 84, fabCenterY - 72),
          icon: Icons.mic_none_rounded,
          label: 'VOICE',
          background: AppEditorial.canvas,
          foreground: AppEditorial.ink,
          onTap: () => Navigator.of(context).pop(_AddAction.voice),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.animation,
    required this.target,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.large = false,
  });

  final Animation<double> animation;
  final Offset target;
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 60.0 : 52.0;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t =
            Curves.easeOutBack.transform(animation.value.clamp(0.0, 1.0));
        return Positioned(
          left: target.dx - size / 2,
          top: target.dy - size / 2,
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + 0.4 * t,
              child: Semantics(
                label: label,
                button: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  child: Container(
                    height: size,
                    width: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: background,
                      border:
                          Border.all(color: AppEditorial.ink, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppEditorial.ink.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: foreground, size: 24),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
