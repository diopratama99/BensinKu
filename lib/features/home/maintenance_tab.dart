import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Maintenance — time-based service reminders per vehicle.
///
/// Design: NO odometer required. Each item is scheduled purely on
/// `last_service_date + intervalDays`, which matches how most people
/// actually think about servicing ("last oil change was ~2 months ago").
class MaintenanceTab extends StatefulWidget {
  const MaintenanceTab({super.key});

  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  final _repo = SupabaseRepository.ofDefaultClient();
  String? _vehicleId;

  Future<(List<Vehicle>, List<MaintenanceItem>)> _load() async {
    final vehicles = await _repo.listVehicles();
    _vehicleId ??= vehicles.isNotEmpty ? vehicles.first.id : null;
    final items = _vehicleId == null
        ? <MaintenanceItem>[]
        : await _repo.listMaintenanceItems(vehicleId: _vehicleId);
    return (vehicles, items);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppEditorial.ink,
      backgroundColor: AppEditorial.canvas,
      child: FutureBuilder<(List<Vehicle>, List<MaintenanceItem>)>(
        future: _load(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _Centered(text: snap.error.toString());
          }
          final data = snap.data;
          if (data == null) {
            return const _MaintenanceSkeleton();
          }
          final vehicles = data.$1;
          final items = data.$2;

          if (vehicles.isEmpty) {
            return const _Centered(
              text: 'Belum ada kendaraan.\nTambah dulu di tab Profil.',
            );
          }

          final selected = vehicles.firstWhere(
            (v) => v.id == _vehicleId,
            orElse: () => vehicles.first,
          );

          // Sort: overdue first, then by soonest due.
          final sorted = [...items]
            ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));

          final overdue = sorted.where((i) => i.isOverdue).length;
          final soon =
              sorted.where((i) => i.isDueSoon && !i.isOverdue).length;
          final ok = sorted.length - overdue - soon;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
            children: [
              if (vehicles.length > 1) ...[
                _VehiclePills(
                  vehicles: vehicles,
                  selectedId: selected.id,
                  onSelect: (id) => setState(() => _vehicleId = id),
                ),
                const SizedBox(height: 18),
              ],

              if (sorted.isNotEmpty) ...[
                _Overview(overdue: overdue, soon: soon, ok: ok),
                const SizedBox(height: 26),
              ],

              EditorialSectionHeader(
                label: 'Jadwal perawatan',
                trailing: _AddChip(onTap: () => _openEditor(selected)),
              ),
              const SizedBox(height: 14),

              if (sorted.isEmpty)
                _EmptyState(onAddPreset: () => _openPresetPicker(selected))
              else
                ...sorted.map(
                  (item) => _MaintenanceCard(
                    item: item,
                    onDone: () => _markDone(item),
                    onTap: () => _openEditor(selected, existing: item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _markDone(MaintenanceItem item) async {
    try {
      await _repo.markMaintenanceDone(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} ditandai selesai ✓')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _openEditor(Vehicle vehicle,
      {MaintenanceItem? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaintenanceEditPage(
          vehicleId: vehicle.id,
          existing: existing,
        ),
      ),
    );
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _openPresetPicker(Vehicle vehicle) => _openEditor(vehicle);
}

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle pills
// ─────────────────────────────────────────────────────────────────────────────

class _VehiclePills extends StatelessWidget {
  const _VehiclePills({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Vehicle> vehicles;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: vehicles.map((v) {
        final selected = v.id == selectedId;
        return GestureDetector(
          onTap: () => onSelect(v.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppEditorial.ink : AppEditorial.canvasSoft,
              borderRadius: BorderRadius.circular(AppEditorial.rPill),
            ),
            child: Text(
              v.name,
              style: AppEditorial.sans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFFFFFFFF)
                    : AppEditorial.inkSoft,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Chip "+ Tambah" untuk header section.
class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppEditorial.brandTint,
          borderRadius: BorderRadius.circular(AppEditorial.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.plus,
                size: 16, color: AppEditorial.brandDeep),
            const SizedBox(width: 3),
            Text('Tambah',
                style: AppEditorial.sans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.brandDeep,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Maintenance card
// ─────────────────────────────────────────────────────────────────────────────

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
    required this.item,
    required this.onDone,
    required this.onTap,
  });

  final MaintenanceItem item;
  final VoidCallback onDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final String statusText;
    if (item.isOverdue) {
      accent = AppEditorial.rust;
      statusText = 'Terlewat ${item.daysUntilDue.abs()} hari';
    } else if (item.isDueSoon) {
      accent = AppEditorial.brandDeep;
      statusText = '${item.daysUntilDue} hari lagi';
    } else {
      accent = AppEditorial.sage;
      statusText = '${item.daysUntilDue} hari lagi';
    }

    final dueFmt = DateFormat('d MMM yyyy', 'id_ID');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppEditorial.rCard),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppEditorial.cream,
              borderRadius: BorderRadius.circular(AppEditorial.rCard),
              boxShadow: AppEditorial.softShadow,
            ),
            child: Row(
              children: [
                // Ring progress + ikon jenis di tengah.
                _RingIcon(
                  progress: item.progress.clamp(0.0, 1.0),
                  accent: accent,
                  icon: _iconForType(item.type),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppEditorial.heading(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Jatuh tempo ${dueFmt.format(item.nextDueDate)} · tiap ${item.intervalDays} hari',
                        style: AppEditorial.sans(
                          fontSize: 12,
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
                          color: accent.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppEditorial.rPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: AppEditorial.sans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _DoneButton(onTap: onDone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lingkaran progress dengan ikon jenis di tengah.
class _RingIcon extends StatelessWidget {
  const _RingIcon({
    required this.progress,
    required this.accent,
    required this.icon,
  });
  final double progress;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4.5,
              backgroundColor: AppEditorial.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              strokeCap: StrokeCap.round,
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: accent),
          ),
        ],
      ),
    );
  }
}

/// Tombol bulat "tandai servis".
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tandai sudah servis',
      child: Material(
        color: AppEditorial.ink,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(PhosphorIconsRegular.check,
                size: 20, color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }
}

/// Ringkasan status perawatan (terlewat / segera / aman).
class _Overview extends StatelessWidget {
  const _Overview({
    required this.overdue,
    required this.soon,
    required this.ok,
  });
  final int overdue;
  final int soon;
  final int ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        children: [
          _stat('Terlewat', overdue, AppEditorial.rust),
          _divider(),
          _stat('Segera', soon, AppEditorial.brandDeep),
          _divider(),
          _stat('Aman', ok, AppEditorial.sage),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: AppEditorial.hairlineSoft,
      );

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: AppEditorial.heading(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppEditorial.sans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppEditorial.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForType(MaintenanceType type) => switch (type) {
      MaintenanceType.engineOil => PhosphorIconsRegular.drop,
      MaintenanceType.transmissionOil => PhosphorIconsRegular.gear,
      MaintenanceType.tires => PhosphorIconsRegular.circle,
      MaintenanceType.sparkPlug => PhosphorIconsRegular.lightning,
      MaintenanceType.brakePads => PhosphorIconsRegular.disc,
      MaintenanceType.airFilter => PhosphorIconsRegular.wind,
      MaintenanceType.battery => PhosphorIconsRegular.batteryCharging,
      MaintenanceType.generalService => PhosphorIconsRegular.wrench,
      MaintenanceType.cvtService => PhosphorIconsRegular.gearSix,
      MaintenanceType.chain => PhosphorIconsRegular.link,
      MaintenanceType.coolant => PhosphorIconsRegular.drop,
      MaintenanceType.other => PhosphorIconsRegular.wrench,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddPreset});
  final VoidCallback onAddPreset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppEditorial.brandTint,
              borderRadius: BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: const Icon(PhosphorIconsRegular.wrench,
                size: 26, color: AppEditorial.brandDeep),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum ada jadwal perawatan.',
            style: AppEditorial.heading(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tambah pengingat ganti oli, ban, busi, dan servis rutin. '
            'Berbasis waktu & input jarak trip.',
            textAlign: TextAlign.center,
            style: AppEditorial.sans(
              fontSize: 12.5,
              color: AppEditorial.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onAddPreset,
            child: const Text('Tambah perawatan'),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Text(
            text ?? '',
            textAlign: TextAlign.center,
            style: AppEditorial.sans(
              fontSize: 13,
              color: AppEditorial.inkSoft,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / edit page
// ─────────────────────────────────────────────────────────────────────────────

class MaintenanceEditPage extends StatefulWidget {
  const MaintenanceEditPage({
    super.key,
    required this.vehicleId,
    this.existing,
  });

  final String vehicleId;
  final MaintenanceItem? existing;

  @override
  State<MaintenanceEditPage> createState() => _MaintenanceEditPageState();
}

class _MaintenanceEditPageState extends State<MaintenanceEditPage> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _titleCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late MaintenanceType _type;
  late DateTime _lastService;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _titleCtrl.text = e.title;
      _intervalCtrl.text = e.intervalDays.toString();
      _lastService = e.lastServiceDate;
      _noteCtrl.text = e.note ?? '';
    } else {
      _type = MaintenanceType.engineOil;
      _intervalCtrl.text = _type.defaultIntervalDays.toString();
      _lastService = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _intervalCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onTypeChange(MaintenanceType t) {
    setState(() {
      _type = t;
      // Update interval to the preset default only when the user hasn't
      // typed a custom one (or it still matches the previous default).
      _intervalCtrl.text = t.defaultIntervalDays.toString();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastService,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      helpText: 'Tanggal servis terakhir',
    );
    if (picked != null) setState(() => _lastService = picked);
  }

  Future<void> _save() async {
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 0;
    if (interval < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interval hari harus diisi.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repo.updateMaintenanceItem(
          id: widget.existing!.id,
          type: _type,
          intervalDays: interval,
          lastServiceDate: _lastService,
          title: _titleCtrl.text,
          note: _noteCtrl.text,
        );
      } else {
        await _repo.createMaintenanceItem(
          vehicleId: widget.vehicleId,
          type: _type,
          intervalDays: interval,
          lastServiceDate: _lastService,
          title: _titleCtrl.text,
          note: _noteCtrl.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal simpan: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus perawatan?',
            style: AppEditorial.heading(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
        content: const Text('Jadwal ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: AppEditorial.rust),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteMaintenanceItem(widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Edit perawatan' : 'Tambah perawatan',
          style: AppEditorial.heading(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.trash,
                  color: AppEditorial.rust),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const EditorialSectionHeader(index: '01', label: 'JENIS'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MaintenanceType.values.map((t) {
              final selected = _type == t;
              return GestureDetector(
                onTap: () => _onTypeChange(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppEditorial.brand
                        : AppEditorial.canvasSoft,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rPill),
                  ),
                  child: Text(
                    t.label,
                    style: AppEditorial.sans(
                      fontSize: 12.5,
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
          const SizedBox(height: 24),

          const EditorialSectionHeader(index: '02', label: 'NAMA (OPSIONAL)'),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.words,
            style: AppEditorial.sans(fontSize: 15),
            decoration: InputDecoration(
              hintText: _type.label,
            ),
          ),
          const SizedBox(height: 24),

          const EditorialSectionHeader(
              index: '03', label: 'INTERVAL (HARI)'),
          const SizedBox(height: 8),
          TextField(
            controller: _intervalCtrl,
            keyboardType: TextInputType.number,
            style: AppEditorial.mono(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: '60',
              suffixText: 'hari',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [30, 60, 90, 180, 365].map((d) {
              return GestureDetector(
                onTap: () =>
                    setState(() => _intervalCtrl.text = d.toString()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppEditorial.canvasSoft,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rPill),
                  ),
                  child: Text(
                    '$d hari',
                    style: AppEditorial.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppEditorial.inkSoft,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          const EditorialSectionHeader(
              index: '04', label: 'TERAKHIR SERVIS'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppEditorial.rButton),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppEditorial.canvasSoft,
                borderRadius: BorderRadius.circular(AppEditorial.rButton),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.calendarBlank,
                      size: 16, color: AppEditorial.inkSoft),
                  const SizedBox(width: 12),
                  Text(
                    dateFmt.format(_lastService),
                    style: AppEditorial.sans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(PhosphorIconsRegular.caretDown,
                      color: AppEditorial.inkMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const EditorialSectionHeader(index: '05', label: 'CATATAN'),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: AppEditorial.sans(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'mis. ganti di bengkel langganan, merk oli, dll',
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
                : Text(_isEdit ? 'Simpan perubahan' : 'Simpan perawatan'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading
// ─────────────────────────────────────────────────────────────────────────────

class _MaintenanceSkeleton extends StatelessWidget {
  const _MaintenanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      children: [
        // Overview card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppEditorial.cream,
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            boxShadow: AppEditorial.softShadow,
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: Column(
                    children: const [
                      Skeleton(width: 40, height: 28),
                      SizedBox(height: 8),
                      Skeleton(width: 56, height: 11),
                    ],
                  ),
                ),
                if (i < 2)
                  Container(
                    width: 1,
                    height: 44,
                    color: AppEditorial.hairlineSoft,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Skeleton(width: 160, height: 18),
            Skeleton(width: 84, height: 32, radius: AppEditorial.rPill),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppEditorial.cream,
                borderRadius: BorderRadius.circular(AppEditorial.rCard),
                boxShadow: AppEditorial.softShadow,
              ),
              child: Row(
                children: const [
                  Skeleton.circle(size: 52),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 130, height: 16),
                        SizedBox(height: 8),
                        Skeleton(width: 90, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Skeleton.circle(size: 40),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
