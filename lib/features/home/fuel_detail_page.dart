import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../services/prediction_service.dart';

/// Detail prediksi bensin — background diisi "bensin" kuning setinggi
/// persentase sisa, dengan permukaan cair yang bergelombang & miring
/// mengikuti kemiringan HP (accelerometer).
class FuelDetailPage extends StatefulWidget {
  const FuelDetailPage({
    super.key,
    required this.forecast,
    required this.vehicle,
  });

  final RefillForecast forecast;
  final Vehicle vehicle;

  @override
  State<FuelDetailPage> createState() => _FuelDetailPageState();
}

class _FuelDetailPageState extends State<FuelDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  // Kemiringan permukaan (slope), di-smooth dari accelerometer.
  double _slope = 0;
  double _targetSlope = 0;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 33),
    ).listen((e) {
      // Sumbu-x ~ kemiringan kiri/kanan. Bagi gravitasi (9.8) → kira-kira
      // tangen sudut; batasi supaya tidak ekstrem.
      // Sumbu-x ~ kemiringan kiri/kanan. Dibuat kecil supaya permukaan
      // tidak membentuk "baji" tajam di pojok (yang terlihat seperti gap),
      // tapi tetap bereaksi terhadap kemiringan.
      _targetSlope = (e.x / 9.8).clamp(-1.0, 1.0) * 0.13;
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _wave.dispose();
    super.dispose();
  }

  void _showEstimateInfo(BuildContext context) {
    final f = widget.forecast;
    final String konsumsiDesc;
    switch (f.method) {
      case 'pola isi ulang':
        konsumsiDesc =
            'Dihitung dari pola jeda pengisianmu (${f.refuelCount}× riwayat) — '
            'rata-rata pemakaian bensin per hari.';
        break;
      case 'konsumsi harian':
        konsumsiDesc =
            'Dihitung dari perkiraan jarak harianmu dikali efisiensi '
            '(km/L) kendaraan.';
        break;
      default:
        konsumsiDesc =
            'Masih estimasi awal. Catat beberapa kali pengisian agar '
            'perhitungan makin akurat.';
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppEditorial.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text('Cara hitung estimasi',
                  style: AppEditorial.heading(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 4),
              Text(
                'Perkiraan, bukan ukuran pasti dari sensor tangki.',
                style: AppEditorial.sans(
                  fontSize: 12.5,
                  color: AppEditorial.inkMuted,
                ),
              ),
              const SizedBox(height: 18),
              const _InfoRow(
                icon: PhosphorIconsRegular.gasPump,
                title: 'Sisa bensin',
                desc:
                    'Bensin dari pengisian terakhir dikurangi perkiraan '
                    'pemakaian sejak saat itu.',
              ),
              _InfoRow(
                icon: PhosphorIconsRegular.flame,
                title: 'Konsumsi harian',
                desc: konsumsiDesc,
              ),
              const _InfoRow(
                icon: PhosphorIconsRegular.calendarBlank,
                title: 'Sisa hari & perkiraan isi ulang',
                desc: 'Sisa bensin dibagi konsumsi harian.',
              ),
              const _InfoRow(
                icon: PhosphorIconsRegular.gauge,
                title: 'Efisiensi (km/L)',
                desc:
                    'Gabungan profil kendaraan dengan data nyata '
                    'pemakaianmu.',
                isLast: true,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppEditorial.brandTint,
                  borderRadius: BorderRadius.circular(AppEditorial.rTiny),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.lightbulb,
                        size: 18, color: AppEditorial.brandDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Makin sering catat pengisian, makin akurat prediksinya.',
                        style: AppEditorial.sans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppEditorial.brandDeep,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.forecast;
    final pct = f.remainingPct.clamp(0.0, 1.0);
    final isWarning =
        pct < 0.15 || (f.daysLeft != null && f.daysLeft! < 2);
    final accent = isWarning ? AppEditorial.rust : AppEditorial.sage;
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppEditorial.brandTint,
        body: Stack(
          children: [
            // ── Bensin cair (background) ─────────────────────────────
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, level, _) {
                  return AnimatedBuilder(
                    animation: _wave,
                    builder: (context, __) {
                      // Smooth follow ke target slope tiap frame.
                      _slope += (_targetSlope - _slope) * 0.08;
                      return CustomPaint(
                        painter: _FuelPainter(
                          level: level,
                          phase: _wave.value * 2 * math.pi,
                          slope: _slope,
                          warning: isWarning,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Konten ───────────────────────────────────────────────
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                    child: Row(
                      children: [
                        _CircleIconButton(
                          icon: PhosphorIconsRegular.arrowLeft,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Prediksi bensin',
                          style: AppEditorial.heading(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        _InfoButton(onTap: () => _showEstimateInfo(context)),
                        const SizedBox(width: 6),
                        _VehicleTag(
                          name: widget.vehicle.name,
                          isMotor:
                              widget.vehicle.type == VehicleType.motor,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Big readout
                  Column(
                    children: [
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: AppEditorial.heading(
                          fontSize: 92,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -4,
                          height: 1.0,
                          color: AppEditorial.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'bensin tersisa',
                        style: AppEditorial.sans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppEditorial.ink.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StatusPill(
                        label: isWarning ? 'Hampir habis' : 'Aman',
                        color: accent,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Detail card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      decoration: BoxDecoration(
                        color: AppEditorial.cream,
                        borderRadius:
                            BorderRadius.circular(AppEditorial.rCard),
                        boxShadow: AppEditorial.softShadow,
                      ),
                      child: Column(
                        children: [
                          EditorialDataRow(
                            label: 'Sisa bensin',
                            value:
                                '${f.remainingLiters.toStringAsFixed(1)} L',
                            valueStyle: AppEditorial.mono(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppEditorial.brandDeep,
                            ),
                          ),
                          EditorialDataRow(
                            label: 'Sisa hari',
                            value: f.daysLeft != null
                                ? '~${f.daysLeft!.toStringAsFixed(0)} hari'
                                : '—',
                            valueStyle: AppEditorial.mono(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isWarning
                                  ? AppEditorial.rust
                                  : AppEditorial.ink,
                            ),
                          ),
                          EditorialDataRow(
                            label: 'Perkiraan isi ulang',
                            value: f.predictedDate != null
                                ? dateFmt.format(f.predictedDate!)
                                : '—',
                          ),
                          EditorialDataRow(
                            label: 'Konsumsi',
                            value: f.litersPerDay > 0
                                ? '${f.litersPerDay.toStringAsFixed(2)} L/hari'
                                : '—',
                          ),
                          EditorialDataRow(
                            label: 'Efisiensi',
                            value:
                                '${f.kmPerLiter.toStringAsFixed(1)} km/L',
                            isLast: true,
                          ),
                        ],
                      ),
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
// Painter — bensin cair
// ─────────────────────────────────────────────────────────────────────────────

class _FuelPainter extends CustomPainter {
  _FuelPainter({
    required this.level,
    required this.phase,
    required this.slope,
    required this.warning,
  });

  final double level; // 0..1
  final double phase; // radian
  final double slope; // tangen kemiringan permukaan
  final bool warning;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (level <= 0) return;

    // Garis dasar permukaan (level). Dinaikkan + dikompensasi terhadap
    // kemiringan: makin miring, isian dinaikkan supaya sisi yang turun
    // tetap menutup (tidak memperlihatkan background di pojok atas).
    final tiltComp = slope.abs() * (w * 0.5) * 1.6;
    final baseY = h * (1 - level) - 42 - tiltComp;

    final back = warning
        ? AppEditorial.rust.withValues(alpha: 0.28)
        : AppEditorial.brandBright.withValues(alpha: 0.55);
    final front = warning ? AppEditorial.rust : AppEditorial.brand;

    _drawWave(
      canvas,
      w,
      h,
      baseY: baseY + 5,
      amp: 9,
      wavelength: w * 0.9,
      phase: phase * 1.3 + math.pi / 2,
      slope: slope,
      color: back,
    );
    _drawWave(
      canvas,
      w,
      h,
      baseY: baseY,
      amp: 6,
      wavelength: w * 0.65,
      phase: phase,
      slope: slope,
      color: front,
    );

    // Garis kilap tipis di permukaan depan.
    final shine = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final shinePath = Path();
    for (double x = 0; x <= w; x += 4) {
      final y = _surfaceY(x, w, baseY, 6, w * 0.65, phase, slope);
      if (x == 0) {
        shinePath.moveTo(x, y);
      } else {
        shinePath.lineTo(x, y);
      }
    }
    canvas.drawPath(shinePath, shine);
  }

  void _drawWave(
    Canvas canvas,
    double w,
    double h, {
    required double baseY,
    required double amp,
    required double wavelength,
    required double phase,
    required double slope,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    // Gambar sedikit melewati tepi kiri & kanan (-16..w+16) supaya tidak
    // ada celah/strip pucat di pinggir layar.
    const over = 16.0;
    final path = Path()..moveTo(-over, h);
    for (double x = -over; x <= w + over; x += 4) {
      path.lineTo(
          x, _surfaceY(x, w, baseY, amp, wavelength, phase, slope));
    }
    path.lineTo(w + over, h);
    path.close();
    canvas.drawPath(path, paint);
  }

  double _surfaceY(
    double x,
    double w,
    double baseY,
    double amp,
    double wavelength,
    double phase,
    double slope,
  ) {
    final tilt = slope * (x - w / 2);
    final wave = amp * math.sin((2 * math.pi / wavelength) * x + phase);
    final wave2 =
        (amp * 0.45) * math.sin((2 * math.pi / (wavelength * 0.5)) * x - phase);
    return baseY + tilt + wave + wave2;
  }

  @override
  bool shouldRepaint(_FuelPainter old) =>
      old.level != level ||
      old.phase != phase ||
      old.slope != slope ||
      old.warning != warning;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bits
// ─────────────────────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppEditorial.ink),
    );
  }
}

class _VehicleTag extends StatelessWidget {
  const _VehicleTag({required this.name, required this.isMotor});
  final String name;
  final bool isMotor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(AppEditorial.rPill),
        boxShadow: AppEditorial.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMotor
                ? PhosphorIconsRegular.motorcycle
                : PhosphorIconsRegular.car,
            size: 15,
            color: AppEditorial.brandDeep,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppEditorial.sans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppEditorial.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppEditorial.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppEditorial.sans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol info bulat (i) — penjelasan cara hitung estimasi.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          shape: BoxShape.circle,
          boxShadow: AppEditorial.softShadow,
        ),
        child: const Icon(PhosphorIconsRegular.info,
            size: 18, color: AppEditorial.brandDeep),
      ),
    );
  }
}

/// Baris penjelasan di sheet "Cara hitung estimasi".
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.desc,
    this.isLast = false,
  });
  final IconData icon;
  final String title;
  final String desc;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 8 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppEditorial.brandTint,
              borderRadius: BorderRadius.circular(AppEditorial.rTiny),
            ),
            child: Icon(icon, size: 19, color: AppEditorial.brandDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppEditorial.heading(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppEditorial.sans(
                    fontSize: 12.5,
                    color: AppEditorial.inkSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
