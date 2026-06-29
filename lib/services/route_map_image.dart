import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

/// Membangun gambar peta (PNG) bertile CARTO Positron dengan garis rute di
/// atasnya — dipakai sebagai banner di laporan PDF.
class RouteMapImage {
  /// Skala render (retina). Tile @2x = 512px → hasil 2× lebih tajam, lalu
  /// PDF mengecilkannya sehingga garis & label terlihat halus.
  static const _r = 2;
  static const _tile = 256 * _r; // ukuran tile ter-render (512)
  static const _subdomains = ['a', 'b', 'c', 'd'];

  /// [segments] = daftar polyline (satu per perjalanan), sudah urut waktu.
  /// Return PNG bytes, atau null bila titik tidak cukup / gagal.
  ///
  /// [maxStdSpan]/[maxStdHeight] dalam satuan piksel standar (256-based);
  /// dipakai memilih zoom agar rute tidak terlalu sempit (lebih "zoom out").
  static Future<Uint8List?> build(
    List<List<LatLng>> segments, {
    int maxStdW = 340,
    int maxStdH = 260,
  }) async {
    final flat = <LatLng>[
      for (final s in segments) ...s,
    ];
    if (flat.length < 2) return null;

    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final p in flat) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }

    // Pilih zoom terbesar yang muat (dalam ruang standar 256) — sisakan ruang
    // untuk padding agar rute tidak menempel tepi.
    int zoom = 1;
    for (var z = 18; z >= 1; z--) {
      final spanX = (_lonToXs(maxLon, z) - _lonToXs(minLon, z)).abs();
      final spanY = (_latToYs(minLat, z) - _latToYs(maxLat, z)).abs();
      final tilesX = (spanX * _r / _tile).ceil() + 2;
      final tilesY = (spanY * _r / _tile).ceil() + 2;
      if (spanX <= maxStdW && spanY <= maxStdH && tilesX * tilesY <= 30) {
        zoom = z;
        break;
      }
    }

    // Peta linimasa hanya hiasan → turunkan satu tingkat lagi supaya jauh
    // lebih zoom-out (area terlihat ~4× lebih luas).
    zoom = math.max(1, zoom - 1);

    // Semua koordinat di bawah ini dalam ruang ter-render (×_r).
    final spanXr = (_lonToX(maxLon, zoom) - _lonToX(minLon, zoom)).abs();
    final spanYr = (_latToY(minLat, zoom) - _latToY(maxLat, zoom)).abs();
    // Padding generous → kesan lebih zoom-out. 30% sisi terpanjang.
    final pad = (math.max(spanXr, spanYr) * 0.30).clamp(180.0, 900.0);

    final minX = _lonToX(minLon, zoom) - pad;
    final maxX = _lonToX(maxLon, zoom) + pad;
    final minY = _latToY(maxLat, zoom) - pad; // y kecil = lat besar
    final maxY = _latToY(minLat, zoom) + pad;

    final cropW = (maxX - minX).round().clamp(64, 4000);
    final cropH = (maxY - minY).round().clamp(64, 3200);

    final tileXmin = (minX / _tile).floor();
    final tileXmax = (maxX / _tile).floor();
    final tileYmin = (minY / _tile).floor();
    final tileYmax = (maxY / _tile).floor();
    final originX = tileXmin * _tile;
    final originY = tileYmin * _tile;

    final canvasW = (tileXmax - tileXmin + 1) * _tile;
    final canvasH = (tileYmax - tileYmin + 1) * _tile;

    final canvas = img.Image(width: canvasW, height: canvasH);
    img.fill(canvas, color: img.ColorRgb8(0xF2, 0xF1, 0xEE));

    // Unduh tile @2x paralel.
    final maxTile = (1 << zoom) - 1;
    final jobs = <Future<void>>[];
    var sub = 0;
    for (var tx = tileXmin; tx <= tileXmax; tx++) {
      for (var ty = tileYmin; ty <= tileYmax; ty++) {
        if (tx < 0 || ty < 0 || tx > maxTile || ty > maxTile) continue;
        final s = _subdomains[sub++ % _subdomains.length];
        final url =
            'https://$s.basemaps.cartocdn.com/light_all/$zoom/$tx/$ty@2x.png';
        final dstX = tx * _tile - originX;
        final dstY = ty * _tile - originY;
        jobs.add(_fetchTile(url).then((tile) {
          if (tile != null) {
            img.compositeImage(canvas, tile, dstX: dstX, dstY: dstY);
          }
        }));
      }
    }
    try {
      await Future.wait(jobs);
    } catch (_) {
      // sebagian tile gagal → tetap lanjut dengan yang ada.
    }

    int px(double lon) => (_lonToX(lon, zoom) - originX).round();
    int py(double lat) => (_latToY(lat, zoom) - originY).round();

    // Gambar rute: halo putih dulu, lalu garis ink. Bulatkan tiap titik agar
    // sambungan mulus.
    final ink = img.ColorRgb8(0x1B, 0x1A, 0x17);
    final halo = img.ColorRgb8(0xFF, 0xFF, 0xFF);
    void stroke(img.Color color, num thick, int joinR) {
      for (final seg in segments) {
        if (seg.length < 2) continue;
        for (var i = 0; i < seg.length - 1; i++) {
          img.drawLine(canvas,
              x1: px(seg[i].longitude),
              y1: py(seg[i].latitude),
              x2: px(seg[i + 1].longitude),
              y2: py(seg[i + 1].latitude),
              color: color,
              thickness: thick,
              antialias: true);
        }
        for (final p in seg) {
          img.fillCircle(canvas,
              x: px(p.longitude),
              y: py(p.latitude),
              radius: joinR,
              color: color,
              antialias: true);
        }
      }
    }

    stroke(halo, 11, 5);
    stroke(ink, 6, 3);

    // Marker start (hijau) & end (merah).
    void dot(LatLng p, img.Color c) {
      img.fillCircle(canvas,
          x: px(p.longitude), y: py(p.latitude), radius: 16, color: halo,
          antialias: true);
      img.fillCircle(canvas,
          x: px(p.longitude), y: py(p.latitude), radius: 11, color: c,
          antialias: true);
    }

    dot(flat.first, img.ColorRgb8(0x3F, 0x7D, 0x51));
    dot(flat.last, img.ColorRgb8(0xC8, 0x48, 0x2E));

    // Crop ke bbox + padding.
    final cx = (minX - originX).round().clamp(0, canvasW - 1);
    final cy = (minY - originY).round().clamp(0, canvasH - 1);
    final cw = math.min(cropW, canvasW - cx);
    final ch = math.min(cropH, canvasH - cy);
    final cropped = img.copyCrop(canvas, x: cx, y: cy, width: cw, height: ch);

    return Uint8List.fromList(img.encodePng(cropped));
  }

  static Future<img.Image?> _fetchTile(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'BensinKu/1.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return img.decodePng(res.bodyBytes) ?? img.decodeImage(res.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  // Ruang ter-render (×_r).
  static double _lonToX(double lon, int z) =>
      (lon + 180) / 360 * _tile * (1 << z);
  static double _latToY(double lat, int z) {
    final s = math.sin(lat * math.pi / 180);
    final y = 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
    return y * _tile * (1 << z);
  }

  // Ruang standar 256 (untuk pilih zoom).
  static double _lonToXs(double lon, int z) =>
      (lon + 180) / 360 * 256 * (1 << z);
  static double _latToYs(double lat, int z) {
    final s = math.sin(lat * math.pi / 180);
    final y = 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
    return y * 256 * (1 << z);
  }
}
