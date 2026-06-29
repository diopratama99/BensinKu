import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/home_widget_service.dart';
import '../../services/notification_service.dart';
import '../../services/widget_launch_intent.dart';
import '../../widgets/user_avatar.dart';
import '../trip/trip_map_screen.dart';
import 'add_refuel_tab.dart';
import 'analytics_tab.dart';
import 'maintenance_tab.dart';
import 'profile_tab.dart';
import 'receipt_processing_sheet.dart';
import 'summary_tab.dart';
import 'voice_input_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver {
  // Index mapping: 0=Home, 1=Statistik, 2=Add(sheet), 3=Riwayat, 4=Peta
  int _index = 0;
  bool _sheetOpen = false;

  final _refreshCounters = {0: 0, 1: 0, 3: 0, 4: 0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybeJumpFromWidget();
    // Push a fresh widget snapshot on app open so values are current
    // even if the user just edited something in another session.
    HomeWidgetService.instance.refresh();
    // Surface any due/overdue maintenance reminders on open (best-effort).
    _checkMaintenanceReminders();
  }

  Future<void> _checkMaintenanceReminders() async {
    try {
      final repo = SupabaseRepository.ofDefaultClient();
      final items = await repo.listMaintenanceItems();
      await NotificationService.instance.notifyMaintenanceDue(items);
    } catch (_) {
      // Non-fatal — reminders are opportunistic.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Widget tap brings app to foreground without recreating HomeShell;
    // poll the pending flag again on resume so we still hijack to the
    // Rute tab + auto-start trip when warm-launched.
    if (state == AppLifecycleState.resumed) {
      _maybeJumpFromWidget();
      // Another app sharing this Supabase instance may have changed the
      // display name or avatar while we were backgrounded. Pull fresh
      // user metadata from the server, then bust the image cache so the
      // latest photo + name show up here too.
      _refreshUserAndAvatar();
    }
  }

  Future<void> _refreshUserAndAvatar() async {
    try {
      // Re-fetch the user so `userMetadata` (name, avatar_updated_at)
      // reflects edits made in other apps. Local session is cached
      // otherwise and won't see cross-app changes.
      await Supabase.instance.client.auth.getUser();
    } catch (_) {
      // Offline / token issue — fall back to a local cache-bust anyway.
    }
    UserAvatar.bumpCacheBust();
    if (mounted) setState(() {});
  }

  Future<void> _maybeJumpFromWidget() async {
    final shouldJump = await WidgetLaunchIntent.consumePending();
    if (!shouldJump || !mounted) return;
    setState(() {
      _index = 4; // Rute tab
      _refreshCounters[4] = (_refreshCounters[4] ?? 0) + 1;
    });
  }

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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppEditorial.hairline,
                    borderRadius: BorderRadius.circular(AppEditorial.rPill),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Sumber Foto',
                  style: AppEditorial.heading(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  )),
              const SizedBox(height: 14),
              Container(height: 1, color: AppEditorial.hairlineSoft),
              _SourceTile(
                icon: PhosphorIconsRegular.camera,
                title: 'Ambil foto baru',
                subtitle: 'Foto langsung struk SPBU',
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              Container(height: 1, color: AppEditorial.hairlineSoft),
              _SourceTile(
                icon: PhosphorIconsRegular.image,
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
    // Tab index → IndexedStack child index.
    // Nav layout: 0=Beranda 1=Maintenance 2=(+) 3=Analisa 4=Rute
    final stackIndex = switch (_index) {
      0 => 0, // Beranda
      1 => 1, // Maintenance
      3 => 2, // Analisa (now also hosts history)
      4 => 3, // Rute
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
        appBar: _index == 0 ? null : _buildAppBar(),
        body: IndexedStack(
          index: stackIndex,
          children: [
            SummaryTab(
              key: ValueKey('summary-${_refreshCounters[0]}'),
              onGoToHistory: () => setState(() {
                _index = 3; // Analisa hosts history now
                _refreshCounters[3] = (_refreshCounters[3] ?? 0) + 1;
              }),
              onGoToProfile: _openProfile,
              onAddFuel: _openAddActions,
              onGoToAnalytics: () => _onTabTapped(3),
              onGoToMaintenance: () => _onTabTapped(1),
            ),
            MaintenanceTab(
              key: ValueKey('maintenance-${_refreshCounters[1]}'),
            ),
            AnalyticsTab(
              key: ValueKey('analytics-${_refreshCounters[3]}'),
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
    final pageName = switch (_index) {
      0 => 'BERANDA',
      1 => 'PERAWATAN',
      3 => 'ANALISA',
      4 => 'RUTE',
      _ => 'BERANDA',
    };

    final pageTitle = pageName.substring(0, 1) +
        pageName.substring(1).toLowerCase();

    return PreferredSize(
      preferredSize: const Size.fromHeight(54),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                pageTitle,
                style: AppEditorial.heading(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom nav (lifted FAB layout, halo-ring trick) ───────────────────

  Widget _buildBottomNav() {
    const barHeight = 72.0;
    const liftOverhang = 16.0;
    const addButtonSize = 76.0;
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
              decoration: BoxDecoration(
                color: AppEditorial.canvasSoft,
                border: const Border(
                  top: BorderSide(color: AppEditorial.hairlineSoft, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppEditorial.ink.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
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
                            icon: PhosphorIconsRegular.house,
                            iconActive: PhosphorIconsRegular.house,
                            label: 'BERANDA',
                            onTap: _onTabTapped,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            index: 1,
                            currentIndex: _index,
                            icon: PhosphorIconsRegular.wrench,
                            iconActive: PhosphorIconsRegular.wrench,
                            label: 'PERAWATAN',
                            onTap: _onTabTapped,
                          ),
                        ),
                        // Gap reserved for the lifted FAB
                        const Expanded(child: SizedBox()),
                        Expanded(
                          child: _NavItem(
                            index: 3,
                            currentIndex: _index,
                            icon: PhosphorIconsRegular.chartLine,
                            iconActive: PhosphorIconsRegular.chartLine,
                            label: 'ANALISA',
                            onTap: _onTabTapped,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            index: 4,
                            currentIndex: _index,
                            icon: PhosphorIconsRegular.mapPin,
                            iconActive: PhosphorIconsRegular.mapPin,
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
              const SizedBox(height: 3),
              Text(
                label.substring(0, 1) + label.substring(1).toLowerCase(),
                style: AppEditorial.heading(
                  fontSize: 10.5,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor,
                  letterSpacing: 0,
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
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppEditorial.ink.withValues(alpha: 0.10),
        highlightColor: AppEditorial.ink.withValues(alpha: 0.04),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppEditorial.canvas, // halo blends with bar bg
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5), // breathing ring
          alignment: Alignment.center,
          child: AnimatedRotation(
            turns: isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: Container(
              decoration: BoxDecoration(
                color: isOpen ? AppEditorial.ink : AppEditorial.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppEditorial.brand.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                PhosphorIconsRegular.plus,
                color: isOpen ? AppEditorial.canvas : AppEditorial.ink,
                size: 34,
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
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    // Base sheet height (92% of screen). When the keyboard is up, shrink the
    // sheet by the keyboard height so its bottom sits ABOVE the keyboard —
    // otherwise the lower fields stay hidden behind it and can't scroll up.
    final sheetHeight = (mq.size.height * 0.92) - keyboard;

    return Container(
      height: sheetHeight,
      // Push the whole sheet up above the keyboard.
      margin: EdgeInsets.only(bottom: keyboard),
      decoration: const BoxDecoration(
        color: AppEditorial.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppEditorial.hairline,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rPill),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      prefill == null
                          ? 'Input Manual'
                          : 'Review Hasil AI',
                      style: AppEditorial.heading(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppEditorial.canvasSoft,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(PhosphorIconsRegular.x,
                          size: 20, color: AppEditorial.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Container(height: 1, color: AppEditorial.hairlineSoft),
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
                      style: AppEditorial.heading(
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
            const Icon(PhosphorIconsRegular.arrowRight,
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
          icon: PhosphorIconsRegular.camera,
          label: 'STRUK',
          background: AppEditorial.canvas,
          foreground: AppEditorial.ink,
          onTap: () => Navigator.of(context).pop(_AddAction.camera),
        ),
        _MiniAction(
          animation: animation,
          target: Offset(centerX, fabCenterY - 124),
          icon: PhosphorIconsRegular.pencilSimple,
          label: 'MANUAL',
          background: AppEditorial.butter,
          foreground: AppEditorial.ink,
          onTap: () => Navigator.of(context).pop(_AddAction.manual),
          large: true,
        ),
        _MiniAction(
          animation: animation,
          target: Offset(centerX + 84, fabCenterY - 72),
          icon: PhosphorIconsRegular.microphone,
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
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppEditorial.ink.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
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
