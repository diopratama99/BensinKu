import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Gaya peta BensinKu — basemap CARTO Positron: peta bersih bernuansa
/// putih/abu netral seperti Google Maps light (latar putih, jalan abu tipis,
/// air biru muda). Tanpa tint apa pun.

/// Layer tile bersih (Positron). Child pertama `FlutterMap`.
Widget warmMapTiles() {
  return TileLayer(
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
    subdomains: const ['a', 'b', 'c', 'd'],
    userAgentPackageName: 'com.temanlabs.bensinku',
    maxZoom: 20,
  );
}

/// Atribusi OSM + CARTO (wajib). Badge "i" kecil yang bisa dibuka — taruh
/// sebagai child terakhir `FlutterMap`.
Widget mapAttribution() {
  return const RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    showFlutterMapAttribution: false,
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      TextSourceAttribution('CARTO'),
    ],
  );
}
