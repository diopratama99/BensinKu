import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models.dart';

/// Satu baris analisis konsumsi: jarak yang ditempuh dari satu kali pengisian.
class _ConsumptionRow {
  _ConsumptionRow({
    required this.vehicleName,
    required this.dateLabel,
    required this.liters,
    required this.cost,
    required this.distanceKm,
    required this.kmPerLiter,
    required this.fromOdometer,
  });
  final String vehicleName;
  final String dateLabel;
  final num liters;
  final num cost;
  final double? distanceKm;
  final double? kmPerLiter;
  final bool fromOdometer;
}

/// Membuat & mencetak laporan kendaraan A4 (ringkasan + konsumsi + linimasa).
class ReportPrintService {
  static final _rp = NumberFormat('#,##0', 'id_ID');
  static final _dayFmt = DateFormat('d MMM yyyy', 'id_ID');
  static final _dayTimeFmt = DateFormat('d MMM yyyy · HH:mm', 'id_ID');

  static const _ink = PdfColor.fromInt(0xFF1B1A17);
  static const _inkSoft = PdfColor.fromInt(0xFF5E5A52);
  static const _inkMuted = PdfColor.fromInt(0xFF9A958A);
  static const _brand = PdfColor.fromInt(0xFFF5BE2E);
  static const _brandSoft = PdfColor.fromInt(0xFFFCEFC9);
  static const _hair = PdfColor.fromInt(0xFFEAE7E0);
  static const _canvasSoft = PdfColor.fromInt(0xFFF8F7F4);

  static String _rpStr(num v) => 'Rp ${_rp.format(v.round())}';

  static Future<void> printReport({
    required List<Vehicle> vehicles,
    required List<Refuel> refuels,
    required List<Trip> trips,
    required List<MaintenanceItem> maint,
    required String scopeLabel,
  }) async {
    await Printing.layoutPdf(
      name: 'Laporan BensinKu',
      format: PdfPageFormat.a4,
      onLayout: (format) => _build(
        vehicles: vehicles,
        refuels: refuels,
        trips: trips,
        maint: maint,
        scopeLabel: scopeLabel,
      ),
    );
  }

  /// Laporan satu periode pengisian: dari [anchor] sampai sebelum [next]
  /// (atau sampai sekarang bila [next] null). [mapPng] = banner peta rute.
  static Future<void> printPeriodReport({
    required Vehicle vehicle,
    required Refuel anchor,
    Refuel? next,
    required List<Trip> trips,
    required List<MaintenanceItem> maint,
    Uint8List? mapPng,
    int? periodIndex,
  }) async {
    await Printing.layoutPdf(
      name: 'Laporan Periode BensinKu',
      format: PdfPageFormat.a4,
      onLayout: (format) => _buildPeriod(
        vehicle: vehicle,
        anchor: anchor,
        next: next,
        trips: trips,
        maint: maint,
        mapPng: mapPng,
        periodIndex: periodIndex,
      ),
    );
  }

  // ── Perhitungan ────────────────────────────────────────────────────────
  static String _vName(Map<String, Vehicle> byId, String id) {
    final v = byId[id];
    return v == null ? '-' : '${v.type.label} · ${v.name}';
  }

  /// Jarak (km) yang ditempuh di antara dua tanggal — fallback dari trip
  /// kalau odometer tak tersedia.
  static double _tripDistanceBetween(
      List<Trip> trips, String vehicleId, DateTime from, DateTime to) {
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    double sum = 0;
    for (final t in trips) {
      if (t.vehicleId != vehicleId) continue;
      if (t.startedAt.isAfter(from) && t.startedAt.isBefore(end)) {
        sum += t.distanceKm ?? 0;
      }
    }
    return sum;
  }

  static List<_ConsumptionRow> _consumption(
    Map<String, Vehicle> byId,
    List<Refuel> refuels,
    List<Trip> trips,
  ) {
    // Kelompokkan per kendaraan, urutkan menaik.
    final byVehicle = <String, List<Refuel>>{};
    for (final r in refuels) {
      byVehicle.putIfAbsent(r.vehicleId, () => []).add(r);
    }
    final rows = <_ConsumptionRow>[];
    for (final entry in byVehicle.entries) {
      final list = [...entry.value]
        ..sort((a, b) => a.refuelDate.compareTo(b.refuelDate));
      for (var i = 1; i < list.length; i++) {
        final prev = list[i - 1];
        final cur = list[i];

        double? dist;
        bool fromOdo = false;
        if (prev.odometerKm != null &&
            cur.odometerKm != null &&
            cur.odometerKm! > prev.odometerKm!) {
          dist = (cur.odometerKm! - prev.odometerKm!).toDouble();
          fromOdo = true;
        } else {
          final d = _tripDistanceBetween(
              trips, cur.vehicleId, prev.refuelDate, cur.refuelDate);
          if (d > 0) dist = d;
        }

        final kmpl = (dist != null && dist > 0 && cur.liters > 0)
            ? dist / cur.liters
            : null;

        rows.add(_ConsumptionRow(
          vehicleName: _vName(byId, cur.vehicleId),
          dateLabel: _dayFmt.format(cur.refuelDate),
          liters: cur.liters,
          cost: cur.totalRp,
          distanceKm: dist,
          kmPerLiter: kmpl,
          fromOdometer: fromOdo,
        ));
      }
    }
    rows.sort((a, b) => b.dateLabel.compareTo(a.dateLabel));
    return rows;
  }

  // ── PDF ────────────────────────────────────────────────────────────────
  static Future<Uint8List> _build({
    required List<Vehicle> vehicles,
    required List<Refuel> refuels,
    required List<Trip> trips,
    required List<MaintenanceItem> maint,
    required String scopeLabel,
  }) async {
    final byId = {for (final v in vehicles) v.id: v};
    final multiVehicle = vehicles.length > 1;

    final base = await PdfGoogleFonts.interRegular();
    final bold = await PdfGoogleFonts.interBold();
    final semi = await PdfGoogleFonts.interSemiBold();
    final theme = pw.ThemeData.withFont(base: base, bold: bold)
        .copyWith(defaultTextStyle: pw.TextStyle(font: base, color: _ink));

    // Agregat ringkasan.
    final totalFills = refuels.length;
    final totalLiters = refuels.fold<num>(0, (s, r) => s + r.liters);
    final totalFuelCost = refuels.fold<num>(0, (s, r) => s + r.totalRp);
    final totalKm = trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
    final avgPrice = totalLiters > 0 ? totalFuelCost / totalLiters : 0;

    final cons = _consumption(byId, refuels, trips);
    final measured = cons.where((r) => r.kmPerLiter != null).toList();
    final sumDist =
        measured.fold<double>(0, (s, r) => s + (r.distanceKm ?? 0));
    final sumLiters = measured.fold<num>(0, (s, r) => s + r.liters);
    final avgKmpl = sumLiters > 0 ? sumDist / sumLiters : null;
    final costPerKm = totalKm > 0 ? totalFuelCost / totalKm : null;

    // Periode.
    final dates = <DateTime>[
      ...refuels.map((r) => r.refuelDate),
      ...trips.map((t) => t.startedAt),
      ...maint.map((m) => m.lastServiceDate),
    ];
    String periodLabel = '-';
    if (dates.isNotEmpty) {
      dates.sort();
      periodLabel =
          '${_dayFmt.format(dates.first)} – ${_dayFmt.format(dates.last)}';
    }

    // Linimasa gabungan.
    final events = _timelineEvents(byId, refuels, trips, maint);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('Laporan BensinKu',
                    style: pw.TextStyle(
                        font: semi, fontSize: 9, color: _inkMuted)),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount} · Dicetak via BensinKu',
            style: pw.TextStyle(font: base, fontSize: 8, color: _inkMuted),
          ),
        ),
        build: (ctx) => [
          _title(scopeLabel, periodLabel, bold, semi, base),
          pw.SizedBox(height: 18),
          _sectionLabel('Ringkasan', semi),
          pw.SizedBox(height: 8),
          _summaryGrid(
            bold: bold,
            base: base,
            items: [
              ('Total Pengisian', '$totalFills×'),
              ('Total BBM', '${totalLiters.toStringAsFixed(2)} L'),
              ('Biaya BBM', _rpStr(totalFuelCost)),
              ('Total Jarak', '${totalKm.toStringAsFixed(0)} km'),
              ('Rata-rata Konsumsi',
                  avgKmpl == null ? '—' : '${avgKmpl.toStringAsFixed(1)} km/L'),
              ('Rata-rata Harga', '${_rpStr(avgPrice)}/L'),
              ('Biaya per km',
                  costPerKm == null ? '—' : '${_rpStr(costPerKm)}/km'),
              ('Total Perjalanan', '${trips.length}×'),
            ],
          ),
          pw.SizedBox(height: 22),
          _sectionLabel('Konsumsi per Pengisian', semi),
          pw.SizedBox(height: 4),
          pw.Text(
            'Jarak yang ditempuh dari tiap kali isi BBM (metode tangki-ke-tangki; '
            'pakai odometer bila ada, jika tidak diperkirakan dari perjalanan).',
            style: pw.TextStyle(font: base, fontSize: 9, color: _inkSoft),
          ),
          pw.SizedBox(height: 8),
          _consumptionTable(cons, multiVehicle, semi, base),
          pw.SizedBox(height: 22),
          _sectionLabel('Linimasa', semi),
          pw.SizedBox(height: 8),
          _timelineTable(events, multiVehicle, semi, base),
          if (maint.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _sectionLabel('Servis & Perawatan', semi),
            pw.SizedBox(height: 8),
            _maintTable(byId, maint, multiVehicle, semi, base),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ── Laporan per periode pengisian ───────────────────────────────────────
  static Future<Uint8List> _buildPeriod({
    required Vehicle vehicle,
    required Refuel anchor,
    Refuel? next,
    required List<Trip> trips,
    required List<MaintenanceItem> maint,
    Uint8List? mapPng,
    int? periodIndex,
  }) async {
    final base = await PdfGoogleFonts.interRegular();
    final bold = await PdfGoogleFonts.interBold();
    final semi = await PdfGoogleFonts.interSemiBold();
    final theme = pw.ThemeData.withFont(base: base, bold: bold)
        .copyWith(defaultTextStyle: pw.TextStyle(font: base, color: _ink));

    final byId = {vehicle.id: vehicle};
    final start = anchor.refuelDate;
    final end = next?.refuelDate;
    final startLabel = _dayFmt.format(start);
    final endLabel = end == null ? 'sekarang' : _dayFmt.format(end);

    // Jarak periode: odometer delta bila tersedia, jika tidak dari perjalanan.
    double? dist;
    bool fromOdo = false;
    if (next != null &&
        anchor.odometerKm != null &&
        next.odometerKm != null &&
        next.odometerKm! > anchor.odometerKm!) {
      dist = (next.odometerKm! - anchor.odometerKm!).toDouble();
      fromOdo = true;
    } else {
      final d = trips.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
      if (d > 0) dist = d;
    }
    final liters = anchor.liters;
    final kmpl = (dist != null && dist > 0 && liters > 0) ? dist / liters : null;
    final rpPerKm =
        (dist != null && dist > 0) ? anchor.totalRp / dist : null;

    final events = _timelineEvents(
      byId,
      [anchor, if (next != null) next],
      trips,
      maint,
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount} · Dicetak via BensinKu',
            style: pw.TextStyle(font: base, fontSize: 8, color: _inkMuted),
          ),
        ),
        build: (ctx) => [
          _title(
            '${vehicle.type.label} · ${vehicle.name}',
            '$startLabel – $endLabel',
            bold,
            semi,
            base,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            periodIndex == null
                ? 'Periode satu kali pengisian BBM'
                : 'Periode pengisian #$periodIndex',
            style: pw.TextStyle(font: semi, fontSize: 11, color: _inkSoft),
          ),
          pw.SizedBox(height: 16),
          // Map banner.
          if (mapPng != null) ...[
            pw.ClipRRect(
              horizontalRadius: 10,
              verticalRadius: 10,
              child: pw.Image(
                pw.MemoryImage(mapPng),
                width: PdfPageFormat.a4.width - 72,
                height: 230,
                fit: pw.BoxFit.cover,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Rute perjalanan pada periode ini  ·  ● mulai   ● selesai',
              style: pw.TextStyle(font: base, fontSize: 8, color: _inkMuted),
            ),
            pw.SizedBox(height: 18),
          ] else ...[
            _emptyNote(
                'Tidak ada rute GPS yang terekam pada periode ini.', base),
            pw.SizedBox(height: 18),
          ],
          _sectionLabel('Ringkasan Periode', semi),
          pw.SizedBox(height: 8),
          _summaryGrid(
            bold: bold,
            base: base,
            items: [
              ('BBM Diisi', '${liters.toStringAsFixed(2)} L'),
              ('Biaya Isi', _rpStr(anchor.totalRp)),
              ('Jarak Ditempuh',
                  dist == null ? '—' : '${dist.toStringAsFixed(0)} km'),
              ('Konsumsi',
                  kmpl == null ? '—' : '${kmpl.toStringAsFixed(1)} km/L'),
              ('Biaya per km',
                  rpPerKm == null ? '—' : '${_rpStr(rpPerKm)}/km'),
              ('Jumlah Perjalanan', '${trips.length}×'),
              ('Harga/Liter', '${_rpStr(anchor.pricePerLiterSnapshot)}/L'),
              ('Sumber Jarak', dist == null
                  ? '—'
                  : (fromOdo ? 'Odometer' : 'Perjalanan')),
            ],
          ),
          pw.SizedBox(height: 22),
          _sectionLabel('Linimasa Periode', semi),
          pw.SizedBox(height: 8),
          _timelineTable(events, false, semi, base),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _title(String scope, String period, pw.Font bold,
      pw.Font semi, pw.Font base) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Laporan Kendaraan',
                  style: pw.TextStyle(font: bold, fontSize: 22, color: _ink)),
              pw.SizedBox(height: 4),
              pw.Text(scope,
                  style:
                      pw.TextStyle(font: semi, fontSize: 11, color: _inkSoft)),
              pw.Text('Periode: $period',
                  style:
                      pw.TextStyle(font: base, fontSize: 10, color: _inkMuted)),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: pw.BoxDecoration(
            color: _brand,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text('BENSINKU',
              style: pw.TextStyle(
                  font: bold, fontSize: 13, color: _ink, letterSpacing: 1)),
        ),
      ],
    );
  }

  static pw.Widget _sectionLabel(String t, pw.Font semi) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 4, height: 14, color: _brand),
        pw.SizedBox(width: 8),
        pw.Text(t,
            style: pw.TextStyle(font: semi, fontSize: 13, color: _ink)),
      ],
    );
  }

  static pw.Widget _summaryGrid({
    required pw.Font bold,
    required pw.Font base,
    required List<(String, String)> items,
  }) {
    pw.Widget cell((String, String) it) => pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _canvasSoft,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _hair, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(it.$1,
                  style: pw.TextStyle(font: base, fontSize: 8.5, color: _inkMuted)),
              pw.SizedBox(height: 4),
              pw.Text(it.$2,
                  style: pw.TextStyle(font: bold, fontSize: 14, color: _ink)),
            ],
          ),
        );

    // 4 kolom grid.
    final rows = <pw.Widget>[];
    for (var i = 0; i < items.length; i += 4) {
      final chunk = items.skip(i).take(4).toList();
      rows.add(pw.Row(
        children: [
          for (var j = 0; j < 4; j++) ...[
            pw.Expanded(child: j < chunk.length ? cell(chunk[j]) : pw.SizedBox()),
            if (j < 3) pw.SizedBox(width: 8),
          ],
        ],
      ));
      if (i + 4 < items.length) rows.add(pw.SizedBox(height: 8));
    }
    return pw.Column(children: rows);
  }

  static pw.Widget _consumptionTable(List<_ConsumptionRow> rows,
      bool multiVehicle, pw.Font semi, pw.Font base) {
    if (rows.isEmpty) {
      return _emptyNote(
          'Belum cukup data untuk hitung konsumsi (butuh ≥ 2 pengisian).', base);
    }
    final headers = [
      if (multiVehicle) 'Kendaraan',
      'Tanggal',
      'Liter',
      'Biaya',
      'Jarak',
      'km/L',
    ];
    final data = rows.map((r) {
      return [
        if (multiVehicle) r.vehicleName,
        r.dateLabel,
        '${r.liters.toStringAsFixed(2)} L',
        _rpStr(r.cost),
        r.distanceKm == null
            ? '—'
            : '${r.distanceKm!.toStringAsFixed(0)} km${r.fromOdometer ? '' : '*'}',
        r.kmPerLiter == null ? '—' : r.kmPerLiter!.toStringAsFixed(1),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _dataTable(headers, data, semi, base,
            rightAlignFrom: multiVehicle ? 2 : 1),
        pw.SizedBox(height: 4),
        pw.Text('* jarak diperkirakan dari perjalanan (odometer tidak diisi).',
            style: pw.TextStyle(font: base, fontSize: 7.5, color: _inkMuted)),
      ],
    );
  }

  static pw.Widget _timelineTable(List<List<String>> events, bool multiVehicle,
      pw.Font semi, pw.Font base) {
    if (events.isEmpty) {
      return _emptyNote('Belum ada aktivitas.', base);
    }
    final headers = [
      'Waktu',
      'Jenis',
      'Detail',
      if (multiVehicle) 'Kendaraan',
      'Nominal',
    ];
    // events row: [waktu, jenis, detail, vehicle, nominal]
    final data = events.map((e) {
      return [
        e[0],
        e[1],
        e[2],
        if (multiVehicle) e[3],
        e[4],
      ];
    }).toList();
    return _dataTable(headers, data, semi, base,
        rightAlignFrom: multiVehicle ? 4 : 3);
  }

  static pw.Widget _maintTable(Map<String, Vehicle> byId,
      List<MaintenanceItem> maint, bool multiVehicle, pw.Font semi, pw.Font base) {
    final headers = [
      'Servis',
      if (multiVehicle) 'Kendaraan',
      'Interval',
      'Terakhir',
      'Jatuh Tempo',
    ];
    final sorted = [...maint]
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    final data = sorted.map((m) {
      return [
        m.title,
        if (multiVehicle) _vName(byId, m.vehicleId),
        '${m.intervalDays} hari',
        _dayFmt.format(m.lastServiceDate),
        _dayFmt.format(m.nextDueDate),
      ];
    }).toList();
    return _dataTable(headers, data, semi, base, rightAlignFrom: 999);
  }

  static List<List<String>> _timelineEvents(
    Map<String, Vehicle> byId,
    List<Refuel> refuels,
    List<Trip> trips,
    List<MaintenanceItem> maint,
  ) {
    final out = <(DateTime, List<String>)>[];
    for (final r in refuels) {
      out.add((
        r.refuelDate,
        [
          _dayTimeFmt.format(r.refuelDate),
          'Isi BBM',
          '${r.liters.toStringAsFixed(2)} L'
              '${r.odometerKm != null ? ' · odo ${r.odometerKm} km' : ''}',
          _vName(byId, r.vehicleId),
          _rpStr(r.totalRp),
        ],
      ));
    }
    for (final t in trips) {
      final dur = t.endedAt?.difference(t.startedAt);
      out.add((
        t.startedAt,
        [
          _dayTimeFmt.format(t.startedAt),
          'Perjalanan',
          '${(t.distanceKm ?? 0).toStringAsFixed(1)} km'
              '${dur != null ? ' · ${dur.inMinutes} mnt' : ''}',
          _vName(byId, t.vehicleId),
          '—',
        ],
      ));
    }
    for (final m in maint) {
      out.add((
        m.lastServiceDate,
        [
          _dayTimeFmt.format(m.lastServiceDate),
          'Servis',
          m.title,
          _vName(byId, m.vehicleId),
          '—',
        ],
      ));
    }
    out.sort((a, b) => b.$1.compareTo(a.$1));
    return out.map((e) => e.$2).toList();
  }

  // Tabel generik dengan header brand & baris zebra.
  static pw.Widget _dataTable(
    List<String> headers,
    List<List<String>> rows,
    pw.Font semi,
    pw.Font base, {
    int rightAlignFrom = 999,
  }) {
    pw.Widget hcell(String t, int i) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: pw.Text(t,
              textAlign:
                  i >= rightAlignFrom ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(font: semi, fontSize: 8.5, color: _ink)),
        );
    pw.Widget cell(String t, int i) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: pw.Text(t,
              textAlign:
                  i >= rightAlignFrom ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(font: base, fontSize: 8.5, color: _inkSoft)),
        );

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _hair, width: 0.6),
        bottom: pw.BorderSide(color: _hair, width: 0.6),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _brandSoft),
          children: [
            for (var i = 0; i < headers.length; i++) hcell(headers[i], i),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: r.isOdd ? _canvasSoft : PdfColors.white,
            ),
            children: [
              for (var i = 0; i < rows[r].length; i++) cell(rows[r][i], i),
            ],
          ),
      ],
    );
  }

  static pw.Widget _emptyNote(String t, pw.Font base) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _canvasSoft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(t,
          style: pw.TextStyle(font: base, fontSize: 9, color: _inkMuted)),
    );
  }
}
