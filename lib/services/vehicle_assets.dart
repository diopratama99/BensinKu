import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';

/// Resolves a photo asset for a vehicle.
///
/// Lookup order:
///   1. `assets/vehicles/<vehicleId>.jpg` — user-uploaded specific photo
///   2. `assets/vehicles/<type>-default.jpg` — type fallback (motor/mobil)
///   3. null — UI must show silhouette / initials fallback
///
/// Result is cached per-id in memory so we don't keep hitting the
/// AssetBundle when scrolling lists.
class VehicleAssets {
  VehicleAssets._();

  static final Map<String, String?> _cache = {};

  /// Returns asset path or null.
  static Future<String?> resolve(Vehicle v) async {
    final cached = _cache[v.id];
    if (cached != null || _cache.containsKey(v.id)) return cached;

    final candidates = [
      'assets/vehicles/${v.id}.jpg',
      'assets/vehicles/${v.id}.png',
      'assets/vehicles/${v.type.dbValue}-default.jpg',
      'assets/vehicles/${v.type.dbValue}-default.png',
    ];

    for (final path in candidates) {
      try {
        await rootBundle.load(path);
        _cache[v.id] = path;
        return path;
      } catch (_) {
        // try next
      }
    }
    _cache[v.id] = null;
    return null;
  }

  /// Sync version — returns previously-resolved cached path or null.
  /// Caller should still warm cache via [resolve] before relying on this.
  static String? cachedFor(Vehicle v) => _cache[v.id];

  @visibleForTesting
  static void clearCache() => _cache.clear();
}
