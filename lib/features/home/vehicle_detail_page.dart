import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../widgets/vehicle_icon.dart';

class VehicleDetailPage extends StatefulWidget {
  const VehicleDetailPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  final _repo = SupabaseRepository.ofDefaultClient();

  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  late TextEditingController _nameCtrl;
  late VehicleType _type;
  late TextEditingController _tankCtrl;

  final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.vehicle.name);
    _type = widget.vehicle.type;
    _tankCtrl = TextEditingController(
      text: widget.vehicle.tankCapacityLiters?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tankCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kendaraan wajib diisi')),
      );
      return;
    }
    final tank = double.tryParse(_tankCtrl.text.trim());

    setState(() => _saving = true);
    try {
      await _repo.updateVehicle(
        id: widget.vehicle.id,
        name: name,
        type: _type,
        tankCapacityLiters: tank,
      );
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kendaraan berhasil diperbarui ✓')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Kendaraan?'),
        content: Text(
            'Kendaraan "${widget.vehicle.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _repo.deleteVehicle(widget.vehicle.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
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
        title: Text(
          _editing ? 'Edit Kendaraan' : 'Detail Kendaraan',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_editing)
            TextButton(
              onPressed: () => setState(() {
                _editing = false;
                _nameCtrl.text = widget.vehicle.name;
                _type = widget.vehicle.type;
                _tankCtrl.text =
                    widget.vehicle.tankCapacityLiters?.toString() ?? '';
              }),
              child: const Text('Batal'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Vehicle header card ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
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
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: VehicleIcon(type: _type, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vehicle.name,
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _type.label,
                              style: TextStyle(
                                color: cs.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.vehicle.tankCapacityLiters != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${widget.vehicle.tankCapacityLiters} L',
                                style: TextStyle(
                                  color: cs.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_editing) ...[
            // ── Edit mode ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Informasi',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),

                  // Vehicle type selector
                  Text('Jenis Kendaraan',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    children: VehicleType.values.map((t) {
                      final selected = _type == t;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _type = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? cs.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  VehicleIcon(type: t, size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kendaraan',
                      hintText: 'Contoh: Vario 2015',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _tankCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}'))
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Kapasitas Tanki (liter)',
                      hintText: 'Contoh: 5.5',
                      prefixIcon: Icon(Icons.water_drop_rounded),
                      suffixText: 'L',
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(
                          _saving ? 'Menyimpan...' : 'Simpan Perubahan'),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── View mode ────────────────────────────────────────────
            // Info card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informasi Kendaraan',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.directions_car_rounded,
                    label: 'Jenis',
                    value: _type.label,
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    icon: Icons.badge_rounded,
                    label: 'Nama',
                    value: widget.vehicle.name,
                  ),
                  const Divider(height: 20),
                  _InfoRow(
                    icon: Icons.water_drop_rounded,
                    label: 'Kapasitas Tanki',
                    value: widget.vehicle.tankCapacityLiters == null
                        ? '—'
                        : '${widget.vehicle.tankCapacityLiters} L',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Stats card (loaded async) ─────────────────────────
            _VehicleStatsCard(
              vehicleId: widget.vehicle.id,
              rupiah: _rupiah,
            ),
            const SizedBox(height: 14),

            // ── Edit & Hapus buttons ─────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit Kendaraan'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _delete,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: cs.error),
                label: Text(
                  _deleting ? 'Menghapus...' : 'Hapus Kendaraan',
                  style: TextStyle(
                      color: cs.error, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side:
                      BorderSide(color: cs.error.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card: load refuel + trip data untuk kendaraan ini
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleStatsCard extends StatelessWidget {
  const _VehicleStatsCard(
      {required this.vehicleId, required this.rupiah});
  final String vehicleId;
  final NumberFormat rupiah;

  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository.ofDefaultClient();
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<(List<Refuel>, List<Trip>)>(
      future: () async {
        final res = await Future.wait([
          repo.listRefuels(vehicleId: vehicleId),
          repo.listTrips(vehicleId: vehicleId),
        ]);
        return (res[0] as List<Refuel>, res[1] as List<Trip>);
      }(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final refuels = snap.data!.$1;
        final trips = snap.data!.$2;

        final totalSpend =
            refuels.fold<double>(0, (s, r) => s + r.totalRp);
        final totalLiters =
            refuels.fold<double>(0, (s, r) => s + r.liters);
        final totalKm =
            trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
        final kmL = (totalKm > 0 && totalLiters > 0)
            ? totalKm / totalLiters
            : null;

        return Container(
          padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Statistik Kendaraan',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StatChip(
                    label: 'Total Pengeluaran',
                    value: rupiah.format(totalSpend),
                    icon: Icons.payments_rounded,
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Total Isi',
                    value: '${refuels.length}x',
                    icon: Icons.local_gas_station_rounded,
                    cs: cs,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatChip(
                    label: 'Jarak GPS',
                    value: '${totalKm.toStringAsFixed(1)} km',
                    icon: Icons.route_rounded,
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Efisiensi',
                    value: kmL != null
                        ? '${kmL.toStringAsFixed(1)} km/L'
                        : '–',
                    icon: Icons.speed_rounded,
                    cs: cs,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.cs,
  });
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row widget
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}
