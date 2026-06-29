import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../services/receipt_print_service.dart';

/// Detail of one refuel entry, with edit + delete.
///
/// Pops with `true` if the entry was changed or deleted, so the calling
/// list can refresh.
class RefuelDetailPage extends StatefulWidget {
  const RefuelDetailPage({
    super.key,
    required this.refuel,
    this.vehicle,
    this.product,
  });

  final Refuel refuel;
  final Vehicle? vehicle;
  final FuelProduct? product;

  @override
  State<RefuelDetailPage> createState() => _RefuelDetailPageState();
}

class _RefuelDetailPageState extends State<RefuelDetailPage>
    with SingleTickerProviderStateMixin {
  final _repo = SupabaseRepository.ofDefaultClient();
  late Refuel refuel;
  bool _changed = false;

  late final AnimationController _print;

  final _rupiah =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    refuel = widget.refuel;
    _print = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Mulai "ngeprint" setelah frame pertama.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _print.forward();
    });
  }

  @override
  void dispose() {
    _print.dispose();
    super.dispose();
  }

  void _reprint() {
    _print.forward(from: 0);
  }

  String get _shortId {
    final clean = refuel.id.replaceAll('-', '').toUpperCase();
    return clean.length <= 12 ? clean : clean.substring(0, 12);
  }

  ReceiptData _receiptData() {
    return ReceiptData(
      shortId: _shortId,
      dateLabel:
          DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(refuel.refuelDate),
      vehicleText: widget.vehicle == null
          ? '-'
          : '${widget.vehicle!.type.label} - ${widget.vehicle!.name}',
      productText: widget.product?.label ?? 'BBM',
      litersLabel: refuel.liters.toStringAsFixed(2),
      pricePerLiterLabel:
          'Rp${_rupiah.format(refuel.pricePerLiterSnapshot).trim()}',
      totalLabel: 'Rp ${_rupiah.format(refuel.totalRp).trim()}',
      isFullTank: refuel.isFullTank,
      odometerLabel:
          refuel.odometerKm == null ? null : '${refuel.odometerKm} km',
    );
  }

  Future<void> _openPrintSheet() async {
    // Replay animasi "ngeprint" sebagai feedback visual.
    _reprint();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppEditorial.canvas,
      builder: (_) => _PrintSheet(data: _receiptData()),
    );
  }

  Future<void> _edit() async {
    final result = await showModalBottomSheet<Refuel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppEditorial.ink.withValues(alpha: 0.45),
      builder: (_) => _RefuelEditSheet(refuel: refuel),
    );
    if (result != null && mounted) {
      setState(() {
        refuel = result;
        _changed = true;
      });
      _reprint();
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus pengisian?',
            style: AppEditorial.heading(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            )),
        content: Text(
          'Catatan pengisian ini akan dihapus permanen.',
          style: AppEditorial.sans(fontSize: 13.5, color: AppEditorial.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: AppEditorial.rust),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteRefuel(refuel.id);
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
    final vehicleText = widget.vehicle == null
        ? '—'
        : '${widget.vehicle!.type.label} · ${widget.vehicle!.name}';
    final productText = widget.product?.label ?? 'BBM';

    return Scaffold(
      backgroundColor: AppEditorial.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
        title: const Text('Detail pengisian'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.pencilSimple),
            tooltip: 'Edit',
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trash,
                color: AppEditorial.rust),
            tooltip: 'Hapus',
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Struk yang muncul "ter-print" saat halaman dibuka.
                AnimatedBuilder(
                  animation: _print,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_print.value);
                    return Align(
                      alignment: Alignment.topCenter,
                      heightFactor: t.clamp(0.0001, 1.0),
                      child: Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: _Receipt(
                    dateLabel: DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                        .format(refuel.refuelDate),
                    trxId: refuel.id,
                    vehicleText: vehicleText,
                    productText: productText,
                    liters: refuel.liters,
                    pricePerLiter: refuel.pricePerLiterSnapshot,
                    totalRp: refuel.totalRp,
                    isFullTank: refuel.isFullTank,
                    odometerKm: refuel.odometerKm,
                    rupiah: _rupiah,
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _openPrintSheet,
                    icon: const Icon(PhosphorIconsRegular.printer, size: 18),
                    label: const Text('Cetak struk'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: const BorderSide(
                          color: AppEditorial.hairline, width: 1.4),
                      foregroundColor: AppEditorial.ink,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 13),
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

/// Struk SPBU — kertas bertepi sobek, garis putus-putus, total besar.
class _Receipt extends StatelessWidget {
  const _Receipt({
    required this.dateLabel,
    required this.trxId,
    required this.vehicleText,
    required this.productText,
    required this.liters,
    required this.pricePerLiter,
    required this.totalRp,
    required this.isFullTank,
    required this.odometerKm,
    required this.rupiah,
  });

  final String dateLabel;
  final String trxId;
  final String vehicleText;
  final String productText;
  final num liters;
  final num pricePerLiter;
  final num totalRp;
  final bool isFullTank;
  final num? odometerKm;
  final NumberFormat rupiah;

  static TextStyle _mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.robotoMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppEditorial.ink,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  String get _shortId {
    final clean = trxId.replaceAll('-', '').toUpperCase();
    return clean.length <= 12 ? clean : clean.substring(0, 12);
  }

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      clipper: _ReceiptClipper(),
      color: const Color(0xFFFFFDF6),
      shadowColor: AppEditorial.ink.withValues(alpha: 0.16),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 36, 26, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppEditorial.brand,
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rTiny),
                    ),
                    child: const Icon(PhosphorIconsRegular.gasPump,
                        color: AppEditorial.ink, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'BENSINKU',
                    style: _mono(20,
                        weight: FontWeight.w700, letterSpacing: 3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'STRUK PENGISIAN BBM',
                    style: _mono(10.5,
                        weight: FontWeight.w500,
                        color: AppEditorial.inkSoft,
                        letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _DashedDivider(),
            const SizedBox(height: 12),

            _row('TANGGAL', dateLabel),
            _row('NO. STRUK', _shortId),
            _row('KENDARAAN', vehicleText),
            _row('JENIS BBM', productText),

            const SizedBox(height: 12),
            const _DashedDivider(),
            const SizedBox(height: 12),

            // Item
            Text(
              productText.toUpperCase(),
              style: _mono(13, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _row(
              '${liters.toStringAsFixed(2)} L x Rp${rupiah.format(pricePerLiter).trim()}',
              'Rp${rupiah.format(totalRp).trim()}',
            ),
            _row('TANGKI PENUH', isFullTank ? 'YA' : 'TIDAK'),
            if (odometerKm != null) _row('ODOMETER', '$odometerKm km'),

            const SizedBox(height: 12),
            const _DashedDivider(thick: true),
            const SizedBox(height: 12),

            // Total
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('TOTAL',
                    style: _mono(16, weight: FontWeight.w700)),
                const Spacer(),
                Text(
                  'Rp ${rupiah.format(totalRp).trim()}',
                  style: _mono(22, weight: FontWeight.w700),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const _DashedDivider(),
            const SizedBox(height: 18),

            // Footer
            Center(
              child: Column(
                children: [
                  Text(
                    'TERIMA KASIH',
                    style: _mono(12.5,
                        weight: FontWeight.w700, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Berkendara aman & hemat bensin',
                    style: _mono(10.5,
                        weight: FontWeight.w400,
                        color: AppEditorial.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Barcode(seed: _shortId),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _shortId,
                style: _mono(11,
                    weight: FontWeight.w500,
                    color: AppEditorial.inkSoft,
                    letterSpacing: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: _mono(12, color: AppEditorial.inkSoft),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _mono(12, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis putus-putus ala struk.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({this.thick = false});
  final bool thick;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, thick ? 2 : 1),
      painter: _DashedPainter(thick: thick),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({required this.thick});
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppEditorial.ink.withValues(alpha: thick ? 0.55 : 0.32)
      ..strokeWidth = thick ? 2 : 1.2;
    const dash = 5.0;
    const gap = 4.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.thick != thick;
}

/// Tepi sobek (gerigi) hanya di ATAS; bawah rata karena masuk ke slot mesin.
class _ReceiptClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const tooth = 9.0; // tinggi gerigi
    const step = 16.0; // lebar tiap gerigi
    final path = Path()..moveTo(0, tooth);

    // Atas — gerigi
    double x = 0;
    while (x < w) {
      path.lineTo(x + step / 2, 0);
      path.lineTo(x + step, tooth);
      x += step;
    }
    // Sisi kanan lurus → bawah rata → sisi kiri lurus.
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ReceiptClipper old) => false;
}

/// Barcode palsu — deterministik dari id transaksi.
class _Barcode extends StatelessWidget {
  const _Barcode({required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    final bars = <Widget>[];
    final codes = seed.isEmpty ? 'BENSINKU' : seed;
    for (var i = 0; i < 46; i++) {
      final code = codes.codeUnitAt(i % codes.length) + i * 7;
      final width = (code % 3) + 1.0; // 1..3
      final black = ((code >> (i % 5)) & 1) == 1;
      bars.add(Container(
        width: width,
        height: 46,
        color: black ? AppEditorial.ink : Colors.transparent,
      ));
      bars.add(const SizedBox(width: 2));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: bars,
    );
  }
}

/// Edit sheet for a refuel. Keeps it simple: date, nominal, liters,
/// full-tank flag. Price/liter is recomputed from total ÷ liters so the
/// snapshot stays consistent even for eceran entries.
class _RefuelEditSheet extends StatefulWidget {
  const _RefuelEditSheet({required this.refuel});
  final Refuel refuel;

  @override
  State<_RefuelEditSheet> createState() => _RefuelEditSheetState();
}

class _RefuelEditSheetState extends State<_RefuelEditSheet> {
  final _repo = SupabaseRepository.ofDefaultClient();
  final _totalCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();

  late DateTime _date;
  late bool _isFullTank;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.refuel;
    _date = r.refuelDate;
    _isFullTank = r.isFullTank;
    _totalCtrl.text = r.totalRp.toInt().toString();
    _litersCtrl.text = r.liters.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _litersCtrl.dispose();
    super.dispose();
  }

  num? _parseInt(String raw) {
    final c = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (c.isEmpty) return null;
    return num.tryParse(c);
  }

  double? _parseLiters(String raw) {
    final c = raw.trim().replaceAll(',', '.');
    if (c.isEmpty) return null;
    final v = double.tryParse(c);
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final total = _parseInt(_totalCtrl.text);
    final liters = _parseLiters(_litersCtrl.text);
    if (total == null || total <= 0) {
      _toast('Nominal tidak valid.');
      return;
    }
    if (liters == null) {
      _toast('Liter tidak valid.');
      return;
    }
    final pricePerLiter = total / liters;

    setState(() => _saving = true);
    try {
      final updated = await _repo.updateRefuel(
        id: widget.refuel.id,
        vehicleId: widget.refuel.vehicleId,
        fuelProductId: widget.refuel.fuelProductId,
        refuelDate: DateTime(_date.year, _date.month, _date.day),
        odometerKm: widget.refuel.odometerKm,
        totalRp: total,
        pricePerLiterSnapshot: pricePerLiter,
        liters: liters,
        isFullTank: _isFullTank,
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Gagal simpan: $e');
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/${_date.year}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppEditorial.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                      borderRadius:
                          BorderRadius.circular(AppEditorial.rPill),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('Edit pengisian',
                        style: AppEditorial.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        )),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(PhosphorIconsRegular.x,
                          size: 22, color: AppEditorial.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Text('Tanggal',
                    style: AppEditorial.sans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppEditorial.inkSoft,
                    )),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius:
                        BorderRadius.circular(AppEditorial.rButton),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                        color: AppEditorial.canvasSoft,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rButton),
                      ),
                      child: Row(
                        children: [
                          const Icon(PhosphorIconsRegular.calendarBlank,
                              size: 17, color: AppEditorial.inkSoft),
                          const SizedBox(width: 12),
                          Text(dateLabel,
                              style: AppEditorial.mono(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nominal',
                              style: AppEditorial.sans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppEditorial.inkSoft,
                              )),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _totalCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            style: AppEditorial.mono(
                                fontSize: 18, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                              hintText: '0',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Liter',
                              style: AppEditorial.sans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppEditorial.inkSoft,
                              )),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _litersCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: AppEditorial.mono(
                                fontSize: 18, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              suffixText: 'L',
                              hintText: '0.0',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Full-tank toggle
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: AppEditorial.canvasSoft,
                    borderRadius: BorderRadius.circular(AppEditorial.rButton),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Tanki penuh',
                            style: AppEditorial.sans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                      Switch(
                        value: _isFullTank,
                        onChanged: (v) => setState(() => _isFullTank = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFFFFFF),
                          ),
                        )
                      : const Text('Simpan perubahan'),
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
// Print sheet — pilih: dialog print sistem (PDF) atau printer thermal Bluetooth.
// ─────────────────────────────────────────────────────────────────────────────

class _PrintSheet extends StatefulWidget {
  const _PrintSheet({required this.data});
  final ReceiptData data;

  @override
  State<_PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends State<_PrintSheet> {
  bool _showDevices = false;
  bool _loading = false;
  String? _statusMsg;
  List<BluetoothInfo> _devices = [];
  String? _busyMac;

  Future<void> _doPdf() async {
    setState(() => _loading = true);
    try {
      await ReceiptPrintService.printPdf(widget.data);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMsg = 'Gagal membuka print: $e';
        });
      }
    }
  }

  Future<void> _openBluetooth() async {
    setState(() {
      _loading = true;
      _statusMsg = null;
    });

    // Minta izin Bluetooth (Android 12+). Di iOS/Android lama, no-op aman.
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final on = await ReceiptPrintService.isBluetoothOn();
    if (!on) {
      if (mounted) {
        setState(() {
          _loading = false;
          _showDevices = true;
          _devices = [];
          _statusMsg = 'Bluetooth belum aktif. Aktifkan dulu lalu coba lagi.';
        });
      }
      return;
    }

    final devices = await ReceiptPrintService.pairedPrinters();
    if (mounted) {
      setState(() {
        _loading = false;
        _showDevices = true;
        _devices = devices;
        _statusMsg = devices.isEmpty
            ? 'Tidak ada printer ter-pairing. Pasangkan printer di Pengaturan Bluetooth dulu.'
            : null;
      });
    }
  }

  Future<void> _printTo(BluetoothInfo device) async {
    setState(() {
      _busyMac = device.macAdress;
      _statusMsg = null;
    });
    final res = await ReceiptPrintService.printToBluetooth(
      mac: device.macAdress,
      d: widget.data,
    );
    if (!mounted) return;
    if (res.ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Struk terkirim ke printer.')),
      );
    } else {
      setState(() {
        _busyMac = null;
        _statusMsg = res.message ?? 'Gagal mencetak.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                if (_showDevices)
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _showDevices = false;
                              _statusMsg = null;
                            }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 20),
                  ),
                if (_showDevices) const SizedBox(width: 10),
                Text(_showDevices ? 'Pilih printer' : 'Cetak struk',
                    style: AppEditorial.heading(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            if (!_showDevices) ...[
              _PrintOption(
                icon: PhosphorIconsRegular.printer,
                title: 'Print / Simpan PDF',
                subtitle:
                    'Printer Wi-Fi/AirPrint, simpan PDF, atau bagikan struk',
                onTap: _loading ? null : _doPdf,
              ),
              const SizedBox(height: 12),
              _PrintOption(
                icon: PhosphorIconsRegular.bluetooth,
                title: 'Printer Bluetooth',
                subtitle: 'Printer struk thermal (ESC/POS) 58mm',
                onTap: _loading ? null : _openBluetooth,
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: AppEditorial.ink),
                    ),
                  ),
                ),
            ] else ...[
              for (final d in _devices)
                _DeviceTile(
                  device: d,
                  busy: _busyMac == d.macAdress,
                  enabled: _busyMac == null,
                  onTap: () => _printTo(d),
                ),
              if (_devices.isEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.bluetoothSlash,
                          size: 18, color: AppEditorial.inkMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tidak ada printer ter-pairing.',
                          style: AppEditorial.sans(
                              fontSize: 13, color: AppEditorial.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (_statusMsg != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppEditorial.rustSoft,
                  borderRadius: BorderRadius.circular(AppEditorial.rTiny),
                ),
                child: Text(
                  _statusMsg!,
                  style: AppEditorial.sans(
                      fontSize: 12.5, color: AppEditorial.rust, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrintOption extends StatelessWidget {
  const _PrintOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppEditorial.cream,
      borderRadius: BorderRadius.circular(AppEditorial.rCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppEditorial.rCard),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppEditorial.rCard),
            border: Border.all(color: AppEditorial.hairline, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppEditorial.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppEditorial.brandDeep),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppEditorial.heading(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppEditorial.sans(
                            fontSize: 12, color: AppEditorial.inkMuted)),
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

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });
  final BluetoothInfo device;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppEditorial.cream,
        borderRadius: BorderRadius.circular(AppEditorial.rTiny),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppEditorial.rTiny),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppEditorial.rTiny),
              border: Border.all(color: AppEditorial.hairline, width: 1),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.printer,
                    size: 20, color: AppEditorial.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name.isEmpty ? 'Printer' : device.name,
                        style: AppEditorial.heading(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(device.macAdress,
                          style: AppEditorial.mono(
                              fontSize: 11, color: AppEditorial.inkMuted)),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppEditorial.ink),
                  )
                else
                  const Icon(PhosphorIconsRegular.caretRight,
                      size: 18, color: AppEditorial.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
