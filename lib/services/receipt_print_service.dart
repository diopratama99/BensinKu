import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

/// Data satu struk pengisian — sudah berisi string siap-tampil agar service
/// tidak perlu tahu soal `NumberFormat`/lokal.
class ReceiptData {
  const ReceiptData({
    required this.shortId,
    required this.dateLabel,
    required this.vehicleText,
    required this.productText,
    required this.litersLabel,
    required this.pricePerLiterLabel,
    required this.totalLabel,
    required this.isFullTank,
    this.odometerLabel,
  });

  final String shortId;
  final String dateLabel;
  final String vehicleText;
  final String productText;
  final String litersLabel; // mis. "2.46"
  final String pricePerLiterLabel; // mis. "Rp16.250"
  final String totalLabel; // mis. "Rp 40.000"
  final bool isFullTank;
  final String? odometerLabel; // mis. "12.000 km"
}

/// Hasil dari operasi cetak Bluetooth.
class PrintResult {
  const PrintResult(this.ok, [this.message]);
  final bool ok;
  final String? message;
}

/// Service cetak struk: ke dialog print sistem (PDF) atau printer thermal
/// Bluetooth (ESC/POS).
class ReceiptPrintService {
  // ── 1. Print / PDF via sistem ──────────────────────────────────────────
  /// Buka dialog print bawaan OS (AirPrint/Wi-Fi/USB, simpan PDF, share).
  static Future<void> printPdf(ReceiptData d) async {
    await Printing.layoutPdf(
      name: 'Struk BensinKu ${d.shortId}',
      format: PdfPageFormat.roll80,
      onLayout: (format) async => _buildPdf(d, format),
    );
  }

  static Future<Uint8List> _buildPdf(ReceiptData d, PdfPageFormat format) async {
    final doc = pw.Document();
    final mono = await PdfGoogleFonts.robotoMonoRegular();
    final monoBold = await PdfGoogleFonts.robotoMonoBold();

    pw.Widget kv(String k, String v, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Text(k, style: pw.TextStyle(font: mono, fontSize: 8)),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              flex: 6,
              child: pw.Text(
                v,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    font: bold ? monoBold : mono, fontSize: 8),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget dashed() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(
            List.filled(40, '-').join(),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(font: mono, fontSize: 8),
          ),
        );

    doc.addPage(
      pw.Page(
        pageFormat: format.copyWith(
          marginTop: 8,
          marginBottom: 8,
          marginLeft: 8,
          marginRight: 8,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text('BENSINKU',
                  style: pw.TextStyle(
                      font: monoBold, fontSize: 16, letterSpacing: 2)),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text('STRUK PENGISIAN BBM',
                  style: pw.TextStyle(font: mono, fontSize: 8, letterSpacing: 1)),
            ),
            dashed(),
            kv('TANGGAL', d.dateLabel, bold: true),
            kv('NO. STRUK', d.shortId, bold: true),
            kv('KENDARAAN', d.vehicleText, bold: true),
            kv('JENIS BBM', d.productText, bold: true),
            dashed(),
            pw.Text(d.productText.toUpperCase(),
                style: pw.TextStyle(font: monoBold, fontSize: 9)),
            pw.SizedBox(height: 3),
            kv('${d.litersLabel} L x ${d.pricePerLiterLabel}', d.totalLabel),
            kv('TANGKI PENUH', d.isFullTank ? 'YA' : 'TIDAK'),
            if (d.odometerLabel != null) kv('ODOMETER', d.odometerLabel!),
            dashed(),
            pw.Row(
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(font: monoBold, fontSize: 11)),
                pw.Spacer(),
                pw.Text(d.totalLabel,
                    style: pw.TextStyle(font: monoBold, fontSize: 14)),
              ],
            ),
            dashed(),
            pw.Center(
              child: pw.Text('TERIMA KASIH',
                  style: pw.TextStyle(
                      font: monoBold, fontSize: 9, letterSpacing: 1)),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text('Berkendara aman & hemat bensin',
                  style: pw.TextStyle(font: mono, fontSize: 7.5)),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: d.shortId,
                width: 160,
                height: 48,
                drawText: true,
                textStyle: pw.TextStyle(font: mono, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── 2. Bluetooth thermal (ESC/POS) ─────────────────────────────────────
  static Future<bool> isBluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  static Future<List<BluetoothInfo>> pairedPrinters() =>
      PrintBluetoothThermal.pairedBluetooths;

  /// Hubungkan ke [mac], kirim struk ESC/POS, lalu putuskan koneksi.
  static Future<PrintResult> printToBluetooth({
    required String mac,
    required ReceiptData d,
  }) async {
    try {
      final on = await PrintBluetoothThermal.bluetoothEnabled;
      if (!on) {
        return const PrintResult(false, 'Bluetooth belum aktif.');
      }

      final connected =
          await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!connected) {
        return const PrintResult(false, 'Gagal terhubung ke printer.');
      }

      final bytes = await _buildEscPos(d);
      final ok = await PrintBluetoothThermal.writeBytes(bytes);

      await PrintBluetoothThermal.disconnect;
      return ok
          ? const PrintResult(true)
          : const PrintResult(false, 'Gagal mengirim data ke printer.');
    } catch (e) {
      return PrintResult(false, 'Error: $e');
    }
  }

  static Future<List<int>> _buildEscPos(ReceiptData d) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    bytes.addAll(g.text('BENSINKU',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        )));
    bytes.addAll(g.text('STRUK PENGISIAN BBM',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.hr());

    void kv(String k, String v) {
      bytes.addAll(g.row([
        PosColumn(text: k, width: 5),
        PosColumn(
            text: v, width: 7, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    kv('TANGGAL', d.dateLabel);
    kv('NO STRUK', d.shortId);
    kv('KENDARAAN', d.vehicleText);
    kv('JENIS BBM', d.productText);
    bytes.addAll(g.hr());

    bytes.addAll(g.text(d.productText.toUpperCase(),
        styles: const PosStyles(bold: true)));
    kv('${d.litersLabel}L x ${d.pricePerLiterLabel}', d.totalLabel);
    kv('TANGKI PENUH', d.isFullTank ? 'YA' : 'TIDAK');
    if (d.odometerLabel != null) kv('ODOMETER', d.odometerLabel!);
    bytes.addAll(g.hr(ch: '='));

    bytes.addAll(g.row([
      PosColumn(
          text: 'TOTAL',
          width: 5,
          styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: d.totalLabel,
          width: 7,
          styles: const PosStyles(
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size2)),
    ]));
    bytes.addAll(g.hr());

    bytes.addAll(g.text('TERIMA KASIH',
        styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(g.text('Berkendara aman & hemat bensin',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());

    return bytes;
  }
}
