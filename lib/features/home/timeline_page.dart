import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/report_print_service.dart';
import '../../services/route_map_image.dart';
import '../trip/trip_detail_page.dart';
import 'refuel_detail_page.dart';

enum _Kind { refuel, trip, service }

class _Event {
  _Event({
    required this.time,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final DateTime time;
  final _Kind kind;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;
}

/// Linimasa — kronologi gabungan: pengisian BBM, perjalanan, & servis.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final _repo = SupabaseRepository.ofDefaultClient();
  String? _vehicleFilter;
  final Set<_Kind> _kindFilter = {};

  List<Vehicle> _vehicles = [];
  List<Refuel> _refuels = [];
  List<Trip> _trips = [];
  List<MaintenanceItem> _maint = [];
  bool _loading = true;
  String? _error;

  final _rupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _vehicles = await _repo.listVehicles();
      final results = await Future.wait([
        _repo.listRefuels(vehicleId: _vehicleFilter, limit: 200),
        _repo.listTrips(vehicleId: _vehicleFilter, limit: 200),
        _repo.listMaintenanceItems(vehicleId: _vehicleFilter),
      ]);
      _refuels = results[0] as List<Refuel>;
      _trips = results[1] as List<Trip>;
      _maint = results[2] as List<MaintenanceItem>;
      setState(() { _loading = false; _error = null; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openReportSheet() {
    if (_refuels.isEmpty && _trips.isEmpty && _maint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada data untuk dilaporkan.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppEditorial.canvas,
      builder: (_) => _ReportSheet(
        refuels: _refuels,
        vehicles: _vehicles,
        rupiah: _rupiah,
        onAll: () {
          Navigator.of(context).pop();
          _printAll();
        },
        onPeriod: (r) {
          Navigator.of(context).pop();
          _printPeriod(r);
        },
      ),
    );
  }

  Future<void> _printAll() async {
    final scope = _vehicleFilter == null
        ? 'Semua kendaraan'
        : () {
            final v = _vehicles.where((e) => e.id == _vehicleFilter);
            return v.isEmpty
                ? 'Semua kendaraan'
                : '${v.first.type.label} · ${v.first.name}';
          }();
    try {
      await ReportPrintService.printReport(
        vehicles: _vehicleFilter == null
            ? _vehicles
            : _vehicles.where((e) => e.id == _vehicleFilter).toList(),
        refuels: _refuels,
        trips: _trips,
        maint: _maint,
        scopeLabel: scope,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal buat laporan: $e')),
        );
      }
    }
  }

  /// Laporan satu periode: dari pengisian [anchor] sampai sebelum pengisian
  /// berikutnya (kendaraan yang sama).
  Future<void> _printPeriod(Refuel anchor) async {
    // Pengisian berikutnya untuk kendaraan yang sama.
    final sameVehicle = _refuels
        .where((r) => r.vehicleId == anchor.vehicleId)
        .toList()
      ..sort((a, b) => a.refuelDate.compareTo(b.refuelDate));
    final idx = sameVehicle.indexWhere((r) => r.id == anchor.id);
    final next = (idx >= 0 && idx < sameVehicle.length - 1)
        ? sameVehicle[idx + 1]
        : null;
    final periodIndex = idx >= 0 ? idx + 1 : null;

    final start = anchor.refuelDate;
    final end = next?.refuelDate ?? DateTime.now();

    final vehicle = _vehicles.firstWhere(
      (v) => v.id == anchor.vehicleId,
      orElse: () => _vehicles.isNotEmpty
          ? _vehicles.first
          : throw StateError('no vehicle'),
    );

    // Trip dalam jendela periode (kendaraan sama).
    final windowTrips = _trips
        .where((t) =>
            t.vehicleId == anchor.vehicleId &&
            !t.startedAt.isBefore(start) &&
            t.startedAt.isBefore(end.add(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final windowMaint = _maint
        .where((m) =>
            m.vehicleId == anchor.vehicleId &&
            !m.lastServiceDate.isBefore(start) &&
            m.lastServiceDate.isBefore(end.add(const Duration(seconds: 1))))
        .toList();

    _showBusy('Menyiapkan laporan & peta rute…');
    try {
      // Ambil waypoint tiap trip → segmen rute.
      final segments = <List<LatLng>>[];
      for (final t in windowTrips) {
        final wps = await _repo.getTripWaypoints(t.id);
        if (wps.length >= 2) {
          segments.add(wps.map((w) => LatLng(w.lat, w.lng)).toList());
        }
      }

      final mapPng = segments.isEmpty
          ? null
          : await RouteMapImage.build(segments);

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // tutup busy

      await ReportPrintService.printPeriodReport(
        vehicle: vehicle,
        anchor: anchor,
        next: next,
        trips: windowTrips,
        maint: windowMaint,
        mapPng: mapPng,
        periodIndex: periodIndex,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal buat laporan: $e')),
        );
      }
    }
  }

  void _showBusy(String msg) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppEditorial.cream,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppEditorial.ink),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(msg,
                    style: AppEditorial.sans(
                        fontSize: 13.5, color: AppEditorial.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppEditorial.canvas,
        body: _TimelineSkeleton(),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppEditorial.canvas,
        body: _errorView(_error!),
      );
    }

    final vehicleById = {for (final v in _vehicles) v.id: v};
    var events = _buildEvents(context, _refuels, _trips, _maint, vehicleById);
    if (_kindFilter.isNotEmpty) {
      events = events.where((e) => _kindFilter.contains(e.kind)).toList();
    }

    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: events.isEmpty
                ? _emptyView()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppEditorial.ink,
                    backgroundColor: AppEditorial.cream,
                    child: _buildTimeline(events),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final totalSpend = _refuels.fold<double>(0, (s, r) => s + r.totalRp);
    final totalKm = _trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));

    return Container(
      color: AppEditorial.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 20,
              bottom: 4,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.arrowLeft,
                      color: AppEditorial.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 2),
                Text(
                  'Linimasa',
                  style: AppEditorial.heading(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppEditorial.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                _ReportButton(onTap: _openReportSheet),
              ],
            ),
          ),
          // Stat badges
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                _StatBadge(
                  icon: PhosphorIconsRegular.gasPump,
                  value: '${_refuels.length}×',
                  label: 'Isi BBM',
                ),
                const SizedBox(width: 10),
                _StatBadge(
                  icon: PhosphorIconsRegular.path,
                  value: '${totalKm.toStringAsFixed(0)} km',
                  label: 'Perjalanan',
                ),
                const SizedBox(width: 10),
                _StatBadge(
                  icon: PhosphorIconsRegular.currencyDollar,
                  value: 'Rp ${_rupiah.format(totalSpend).trim()}',
                  label: 'Total BBM',
                ),
              ],
            ),
          ),
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_vehicles.length > 1) ...[
                  _VehicleFilter(
                    vehicles: _vehicles,
                    selected: _vehicleFilter,
                    onChange: (id) {
                      _vehicleFilter = id;
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                _KindFilter(
                  selected: _kindFilter,
                  onChange: (kind) => setState(() {
                    if (_kindFilter.contains(kind)) {
                      _kindFilter.remove(kind);
                    } else {
                      _kindFilter.add(kind);
                    }
                  }),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppEditorial.hairline),
        ],
      ),
    );
  }

  List<_Event> _buildEvents(
    BuildContext context,
    List<Refuel> refuels,
    List<Trip> trips,
    List<MaintenanceItem> maint,
    Map<String, Vehicle> vehicleById,
  ) {
    String vlabel(String id) {
      final v = vehicleById[id];
      return v == null ? '' : '${v.type.label} · ${v.name}';
    }

    final events = <_Event>[];

    for (final r in refuels) {
      events.add(_Event(
        time: r.refuelDate,
        kind: _Kind.refuel,
        title: 'Isi BBM',
        subtitle: '${r.liters.toStringAsFixed(2)} L · ${vlabel(r.vehicleId)}',
        trailing: 'Rp ${_rupiah.format(r.totalRp).trim()}',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RefuelDetailPage(
              refuel: r,
              vehicle: vehicleById[r.vehicleId],
            ),
          ),
        ),
      ));
    }

    for (final t in trips) {
      final dur = t.endedAt?.difference(t.startedAt);
      final durStr = dur != null ? ' · ${dur.inMinutes} mnt' : '';
      events.add(_Event(
        time: t.startedAt,
        kind: _Kind.trip,
        title: 'Perjalanan',
        subtitle:
            '${(t.distanceKm ?? 0).toStringAsFixed(1)} km$durStr · ${vlabel(t.vehicleId)}',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => TripDetailPage(trip: t)),
        ),
      ));
    }

    for (final m in maint) {
      events.add(_Event(
        time: m.lastServiceDate,
        kind: _Kind.service,
        title: 'Servis: ${m.title}',
        subtitle: 'tiap ${m.intervalDays} hari · ${vlabel(m.vehicleId)}',
      ));
    }

    events.sort((a, b) => b.time.compareTo(a.time));
    return events;
  }

  Widget _buildTimeline(List<_Event> events) {
    final dayFmt = DateFormat('EEEE, d MMM yyyy', 'id_ID');
    final children = <Widget>[];
    String? lastDay;

    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final dayKey = '${e.time.year}-${e.time.month}-${e.time.day}';

      if (dayKey != lastDay) {
        children.add(_DayHeader(
          label: _relativeDay(e.time, dayFmt),
          topPadding: i == 0 ? 20 : 28,
        ));
        lastDay = dayKey;
      }

      final isLastOfDay = i == events.length - 1 ||
          '${events[i + 1].time.year}-${events[i + 1].time.month}-${events[i + 1].time.day}' !=
              dayKey;

      children.add(_TimelineTile(
        event: e,
        isLast: isLastOfDay,
        index: i,
      ));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 48),
      children: children,
    );
  }

  String _relativeDay(DateTime t, DateFormat fmt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(t.year, t.month, t.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    return fmt.format(t);
  }

  Widget _emptyView() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppEditorial.brandSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(PhosphorIconsRegular.clockCounterClockwise,
                      size: 28, color: AppEditorial.brandDeep),
                ),
                const SizedBox(height: 16),
                Text('Belum ada aktivitas',
                    style: AppEditorial.heading(fontSize: 16)),
                const SizedBox(height: 6),
                Text('Mulai isi BBM atau lakukan perjalanan.',
                    style: AppEditorial.sans(
                        fontSize: 13, color: AppEditorial.inkMuted)),
              ],
            ),
          ),
        ],
      );

  Widget _errorView(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: AppEditorial.sans(
                  fontSize: 13, color: AppEditorial.inkMuted)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tombol cetak laporan
// ─────────────────────────────────────────────────────────────────────────────

class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppEditorial.ink,
      borderRadius: BorderRadius.circular(AppEditorial.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppEditorial.rPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsRegular.printer,
                  size: 16, color: Color(0xFFFFFFFF)),
              const SizedBox(width: 6),
              Text(
                'Laporan',
                style: AppEditorial.heading(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet pilih laporan — semua data atau per periode pengisian
// ─────────────────────────────────────────────────────────────────────────────

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.refuels,
    required this.vehicles,
    required this.rupiah,
    required this.onAll,
    required this.onPeriod,
  });
  final List<Refuel> refuels;
  final List<Vehicle> vehicles;
  final NumberFormat rupiah;
  final VoidCallback onAll;
  final ValueChanged<Refuel> onPeriod;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static final _dayFmt = DateFormat('d MMM yyyy', 'id_ID');
  static final _monthFmt = DateFormat('MMMM yyyy', 'id_ID');

  late final List<_PeriodItem> _periods;
  late final List<DateTime> _months; // unik per (tahun, bulan), terbaru dulu
  DateTime? _month; // null = semua bulan

  @override
  void initState() {
    super.initState();
    final byId = {for (final v in widget.vehicles) v.id: v};

    final byVehicle = <String, List<Refuel>>{};
    for (final r in widget.refuels) {
      byVehicle.putIfAbsent(r.vehicleId, () => []).add(r);
    }
    for (final l in byVehicle.values) {
      l.sort((a, b) => a.refuelDate.compareTo(b.refuelDate));
    }

    final periods = <_PeriodItem>[];
    byVehicle.forEach((vid, list) {
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        final next = i < list.length - 1 ? list[i + 1] : null;
        periods.add(_PeriodItem(
          refuel: r,
          index: i + 1,
          startLabel: _dayFmt.format(r.refuelDate),
          endLabel: next == null ? 'sekarang' : _dayFmt.format(next.refuelDate),
          vehicleLabel: byId[vid] == null
              ? ''
              : '${byId[vid]!.type.label} · ${byId[vid]!.name}',
        ));
      }
    });
    periods.sort((a, b) => b.refuel.refuelDate.compareTo(a.refuel.refuelDate));
    _periods = periods;

    final monthSet = <String, DateTime>{};
    for (final p in periods) {
      final d = p.refuel.refuelDate;
      monthSet['${d.year}-${d.month}'] = DateTime(d.year, d.month);
    }
    _months = monthSet.values.toList()..sort((a, b) => b.compareTo(a));
    _month = _months.isNotEmpty ? _months.first : null;
  }

  List<_PeriodItem> get _filtered {
    if (_month == null) return _periods;
    return _periods
        .where((p) =>
            p.refuel.refuelDate.year == _month!.year &&
            p.refuel.refuelDate.month == _month!.month)
        .toList();
  }

  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: AppEditorial.canvas,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pilih Bulan',
                    style: AppEditorial.heading(fontSize: 16)),
              ),
            ),
            _monthRow('Semua bulan', _kAll),
            for (final m in _months) _monthRow(_monthFmt.format(m), m),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null) return; // ditutup tanpa memilih
    setState(() => _month = identical(picked, _kAll) ? null : picked);
  }

  // Sentinel untuk opsi "Semua bulan" (≠ dismiss yang mengembalikan null).
  static final DateTime _kAll = DateTime.fromMillisecondsSinceEpoch(0);

  Widget _monthRow(String label, DateTime value) {
    final isAll = identical(value, _kAll);
    final selected = isAll
        ? _month == null
        : (_month != null &&
            value.year == _month!.year &&
            value.month == _month!.month);
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppEditorial.heading(
                      fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
            if (selected)
              const Icon(PhosphorIconsFill.checkCircle,
                  size: 20, color: AppEditorial.ink),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cetak Laporan',
                      style: AppEditorial.heading(fontSize: 17)),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    _ReportTile(
                      icon: PhosphorIconsRegular.stack,
                      title: 'Semua data',
                      subtitle:
                          'Ringkasan, konsumsi, & linimasa seluruh periode',
                      onTap: widget.onAll,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text('PER PERIODE PENGISIAN',
                            style: AppEditorial.eyebrow(
                                color: AppEditorial.inkMuted)),
                        const Spacer(),
                        if (_months.isNotEmpty) _monthDropdown(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Laporan + peta rute dari satu kali isi BBM sampai isi berikutnya.',
                      style: AppEditorial.sans(
                          fontSize: 12, color: AppEditorial.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    if (_periods.isEmpty)
                      Text('Belum ada pengisian.',
                          style: AppEditorial.sans(
                              fontSize: 13, color: AppEditorial.inkSoft))
                    else if (filtered.isEmpty)
                      Text('Tidak ada pengisian di bulan ini.',
                          style: AppEditorial.sans(
                              fontSize: 13, color: AppEditorial.inkSoft))
                    else
                      for (final p in filtered) ...[
                        _ReportTile(
                          icon: PhosphorIconsRegular.gasPump,
                          title:
                              'Periode #${p.index} · ${p.startLabel} → ${p.endLabel}',
                          subtitle: [
                            'Rp ${widget.rupiah.format(p.refuel.totalRp).trim()}',
                            '${p.refuel.liters.toStringAsFixed(2)} L',
                            if (widget.vehicles.length > 1) p.vehicleLabel,
                          ].join(' · '),
                          onTap: () => widget.onPeriod(p.refuel),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _monthDropdown() {
    return GestureDetector(
      onTap: _pickMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppEditorial.cream,
          borderRadius: BorderRadius.circular(AppEditorial.rPill),
          border: Border.all(color: AppEditorial.hairline, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.calendarBlank,
                size: 14, color: AppEditorial.inkSoft),
            const SizedBox(width: 6),
            Text(
              _month == null ? 'Semua bulan' : _monthFmt.format(_month!),
              style: AppEditorial.sans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppEditorial.ink),
            ),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsRegular.caretDown,
                size: 13, color: AppEditorial.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _PeriodItem {
  _PeriodItem({
    required this.refuel,
    required this.index,
    required this.startLabel,
    required this.endLabel,
    required this.vehicleLabel,
  });
  final Refuel refuel;
  final int index;
  final String startLabel;
  final String endLabel;
  final String vehicleLabel;
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppEditorial.cream,
      borderRadius: BorderRadius.circular(AppEditorial.rTiny),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppEditorial.rTiny),
            border: Border.all(color: AppEditorial.hairline, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppEditorial.brandSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: AppEditorial.brandDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppEditorial.heading(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppEditorial.sans(
                            fontSize: 11.5, color: AppEditorial.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(PhosphorIconsRegular.caretRight,
                  size: 18, color: AppEditorial.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat badge (hero panel)
// ─────────────────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppEditorial.canvasSoft,
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
          border: Border.all(color: AppEditorial.hairline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: AppEditorial.inkMuted),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppEditorial.mono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppEditorial.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: AppEditorial.sans(
                fontSize: 10.5,
                color: AppEditorial.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle filter chips
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleFilter extends StatelessWidget {
  const _VehicleFilter({
    required this.vehicles,
    required this.selected,
    required this.onChange,
  });
  final List<Vehicle> vehicles;
  final String? selected;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterPill(
            label: 'Semua',
            selected: selected == null,
            onTap: () => onChange(null),
          ),
          for (final v in vehicles)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterPill(
                label: '${v.type.label} · ${v.name}',
                selected: selected == v.id,
                onTap: () => onChange(v.id),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kind filter (BBM / Perjalanan / Servis)
// ─────────────────────────────────────────────────────────────────────────────

class _KindFilter extends StatelessWidget {
  const _KindFilter({
    required this.selected,
    required this.onChange,
  });
  final Set<_Kind> selected;
  final ValueChanged<_Kind> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KindPill(
          kind: _Kind.refuel,
          label: 'BBM',
          icon: PhosphorIconsRegular.gasPump,
          color: AppEditorial.brand,
          selected: selected.contains(_Kind.refuel),
          onTap: () => onChange(_Kind.refuel),
        ),
        const SizedBox(width: 8),
        _KindPill(
          kind: _Kind.trip,
          label: 'Perjalanan',
          icon: PhosphorIconsRegular.path,
          color: AppEditorial.sage,
          selected: selected.contains(_Kind.trip),
          onTap: () => onChange(_Kind.trip),
        ),
        const SizedBox(width: 8),
        _KindPill(
          kind: _Kind.service,
          label: 'Servis',
          icon: PhosphorIconsRegular.wrench,
          color: AppEditorial.brandDeep,
          selected: selected.contains(_Kind.service),
          onTap: () => onChange(_Kind.service),
        ),
      ],
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({
    required this.kind,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final _Kind kind;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppEditorial.canvasSoft,
          borderRadius: BorderRadius.circular(AppEditorial.rPill),
          border: Border.all(
            color: selected ? color : AppEditorial.hairline,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? color : AppEditorial.inkMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppEditorial.sans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppEditorial.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppEditorial.ink : AppEditorial.canvasSoft,
          borderRadius: BorderRadius.circular(AppEditorial.rPill),
          border: Border.all(
            color: selected ? AppEditorial.ink : AppEditorial.hairline,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppEditorial.sans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFFFFFFFF) : AppEditorial.inkSoft,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day header
// ─────────────────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, this.topPadding = 24});
  final String label;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppEditorial.cream,
              borderRadius: BorderRadius.circular(AppEditorial.rPill),
              border: Border.all(color: AppEditorial.hairline, width: 1),
            ),
            child: Text(
              label.toUpperCase(),
              style: AppEditorial.eyebrow(
                  fontSize: 10.5, color: AppEditorial.inkMuted),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(
                height: 1, thickness: 1, color: AppEditorial.hairlineSoft),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline tile
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineTile extends StatefulWidget {
  const _TimelineTile({
    required this.event,
    required this.isLast,
    required this.index,
  });
  final _Event event;
  final bool isLast;
  final int index;

  @override
  State<_TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<_TimelineTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  (Color dotBg, Color dotFg, Color accent, IconData icon) get _style =>
      switch (widget.event.kind) {
        _Kind.refuel => (
            AppEditorial.brand,
            AppEditorial.ink,
            AppEditorial.brandDeep,
            PhosphorIconsRegular.gasPump,
          ),
        _Kind.trip => (
            AppEditorial.sageSoft,
            AppEditorial.sage,
            AppEditorial.sage,
            PhosphorIconsRegular.path,
          ),
        _Kind.service => (
            AppEditorial.brandTint,
            AppEditorial.brandDeep,
            AppEditorial.brandDeep,
            PhosphorIconsRegular.wrench,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (dotBg, dotFg, accent, icon) = _style;
    final timeStr = DateFormat('HH:mm').format(widget.event.time);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rail
                SizedBox(
                  width: 44,
                  child: Column(
                    children: [
                      // Dot with subtle glow ring
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: dotBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dotBg.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 17, color: dotFg),
                      ),
                      if (!widget.isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: AppEditorial.hairline,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Card
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: widget.isLast ? 4 : 14),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.event.onTap,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rTiny),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppEditorial.cream,
                            borderRadius:
                                BorderRadius.circular(AppEditorial.rTiny),
                            boxShadow: AppEditorial.softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Accent top bar
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: dotBg,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppEditorial.rTiny),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    14, 11, 14, 13),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.event.title,
                                            style: AppEditorial.heading(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            widget.event.subtitle,
                                            style: AppEditorial.sans(
                                              fontSize: 12.5,
                                              color: AppEditorial.inkSoft,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (widget.event.trailing !=
                                            null)
                                          Text(
                                            widget.event.trailing!,
                                            style: AppEditorial.mono(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                            ),
                                          ),
                                        const SizedBox(height: 2),
                                        Text(
                                          timeStr,
                                          style: AppEditorial.sans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppEditorial.inkMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // White header skeleton
        Container(
          color: AppEditorial.cream,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            bottom: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Skeleton(width: 140, height: 22),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppEditorial.canvasSoft,
                          borderRadius:
                              BorderRadius.circular(AppEditorial.rTiny),
                          border: Border.all(
                              color: AppEditorial.hairline, width: 1),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 10),
                  ],
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppEditorial.hairline),
        for (var g = 0; g < 2; g++) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(20, g == 0 ? 20 : 28, 20, 10),
            child: const Skeleton(width: 90, height: 22, radius: 99),
          ),
          for (var i = 0; i < 3; i++)
            _SkeletonTile(isLast: g == 1 && i == 2),
        ],
      ],
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.isLast});
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  const Skeleton.circle(size: 38),
                  if (!isLast)
                    Expanded(
                      child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: AppEditorial.hairline),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 4 : 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppEditorial.cream,
                    borderRadius: BorderRadius.circular(AppEditorial.rTiny),
                    boxShadow: AppEditorial.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppEditorial.hairline,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppEditorial.rTiny)),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 11, 14, 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Skeleton(width: 110, height: 14)),
                                SizedBox(width: 10),
                                Skeleton(width: 50, height: 14),
                              ],
                            ),
                            SizedBox(height: 8),
                            Skeleton(width: 160, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
