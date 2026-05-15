import 'dart:math' as math;

import '../data/models.dart';

/// Daily km estimate result with provenance — UI displays "sumber: <source>".
class DailyKmEstimate {
  const DailyKmEstimate({required this.kmPerDay, required this.source});

  final double kmPerDay;

  /// Provenance label so UI can show "sumber: data 30 hari" / "preferensi" /
  /// "profil pakai" / "default".
  final String source;
}

/// Result of fuel-economy estimation, with provenance and confidence.
class FuelEconomyEstimate {
  const FuelEconomyEstimate({
    required this.kmPerLiter,
    required this.source,
    required this.sampleCount,
  });

  /// Estimated km/L for the vehicle.
  final double kmPerLiter;

  /// Where the estimate came from. One of:
  ///   - 'PRIOR'        : 100% prior, no measurements yet
  ///   - 'MIXED'        : prior + samples blended
  ///   - 'DATA-DRIVEN'  : prior weight is negligible, samples dominate
  final String source;

  /// Number of `EfficiencySample` rows used in the blend.
  final int sampleCount;
}

/// Prediction service — encodes the cold-start prior + Bayesian-style update
/// against measured `EfficiencySample` rows.
///
/// Design: NO RAG, NO embedding. Pure deterministic stats. Each adjustment
/// factor is documented inline with the rationale + magnitude.
///
/// Tested values are derived from public Indonesian-market consumption data
/// (Pertamina trip reports, basic spec sheets). Exact numbers are not
/// rocket-science precise, but they're an order-of-magnitude better than
/// the previous implementation which had no prior at all.
class PredictionService {
  PredictionService._();

  // ── Tunables ──────────────────────────────────────────────────────────

  /// Prior weight (in "effective measurements"). After this many
  /// real samples, the prior contribution is negligible (~50% at α=8 and
  /// 8 samples; ~10% at α=8 and 72 samples).
  static const double _priorWeightAlpha = 8.0;

  /// km/L below this is treated as outlier (urban gridlock can cap at ~3
  /// km/L for a small car, but a measurement of 0.5 means data corruption).
  static const double _kmLLowerSanity = 2.0;

  /// km/L above this is treated as outlier (a 110cc motor might hit 70 km/L
  /// downhill, but >100 means corrupted data).
  static const double _kmLUpperSanity = 100.0;

  // ── Public API ────────────────────────────────────────────────────────

  /// Cold-start prior km/L. Always returns a positive number (worst case
  /// falls back to `vehicle.type` baseline).
  ///
  /// Adjustments stack multiplicatively:
  ///   base × ageFactor × transmissionFactor × cityFactor
  ///
  /// RON / octane penalty intentionally omitted — Indonesian fuel quality
  /// is inconsistent and pump labelling is unreliable, so any per-RON
  /// adjustment would be noise more often than signal.
  static double priorKmPerLiter({
    required Vehicle vehicle,
    PrimaryCity? primaryCity,
    UsageProfile? usageProfile,
  }) {
    double base = _baseKmPerLiter(vehicle);

    base *= _ageFactor(vehicle.manufacturingYear);
    base *= _transmissionFactor(
        vehicle.transmission, primaryCity, usageProfile);
    base *= _cityFactor(primaryCity);

    return base.clamp(_kmLLowerSanity, _kmLUpperSanity);
  }

  /// Posterior km/L: blend prior with measured ground-truth samples.
  /// Bayesian-style weighted mean:
  ///
  ///   posterior = (α·prior + Σ samples) / (α + n)
  ///
  /// where α is the prior weight (in "effective measurements") and n is
  /// the count of valid samples after outlier filtering. This converges
  /// to the sample mean as more data arrives, which is what we want for
  /// adaptive learning.
  static FuelEconomyEstimate posteriorKmPerLiter({
    required Vehicle vehicle,
    required List<EfficiencySample> samples,
    PrimaryCity? primaryCity,
    UsageProfile? usageProfile,
  }) {
    final prior = priorKmPerLiter(
      vehicle: vehicle,
      primaryCity: primaryCity,
      usageProfile: usageProfile,
    );

    // Filter outliers — protects against typo/parser errors.
    final clean = samples
        .where((s) =>
            s.kmPerLiter >= _kmLLowerSanity &&
            s.kmPerLiter <= _kmLUpperSanity)
        .toList();

    if (clean.isEmpty) {
      return FuelEconomyEstimate(
        kmPerLiter: prior,
        source: 'PRIOR',
        sampleCount: 0,
      );
    }

    final sampleSum = clean.fold<double>(0, (s, x) => s + x.kmPerLiter);
    final n = clean.length;
    final posterior =
        (_priorWeightAlpha * prior + sampleSum) / (_priorWeightAlpha + n);

    // Source label depends on how much weight the samples carry.
    final sampleWeight = n / (_priorWeightAlpha + n);
    final source = sampleWeight < 0.25
        ? 'MIXED'
        : (sampleWeight < 0.75 ? 'MIXED' : 'DATA-DRIVEN');

    return FuelEconomyEstimate(
      kmPerLiter: posterior.clamp(_kmLLowerSanity, _kmLUpperSanity),
      source: source,
      sampleCount: n,
    );
  }

  /// Estimated daily km. Priority order:
  ///   1. Trip data (last 30 days, ≥5 trips, ≥30 km total) — actual usage
  ///   2. `weekly_km` user preference — direct user signal
  ///   3. `usage_profile` mapping — coarse fallback for cold-start
  ///   4. Hard default (10 km/day) — last resort
  static DailyKmEstimate dailyKmEstimate({
    required List<Trip> recentTrips,
    num? weeklyKmPref,
    UsageProfile? usageProfile,
  }) {
    // (1) Trip data — most accurate
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recent = recentTrips.where((t) =>
        t.startedAt.isAfter(thirtyDaysAgo) && t.distanceKm != null);
    final tripKm =
        recent.fold<double>(0, (s, t) => s + (t.distanceKm ?? 0));
    if (recent.length >= 5 && tripKm >= 30) {
      return DailyKmEstimate(
        kmPerDay: tripKm / 30,
        source: 'data 30 hari',
      );
    }

    // (2) User-stated weekly km
    if (weeklyKmPref is num && weeklyKmPref > 0) {
      return DailyKmEstimate(
        kmPerDay: weeklyKmPref / 7,
        source: 'preferensi',
      );
    }

    // (3) Usage profile mapping
    if (usageProfile != null) {
      return DailyKmEstimate(
        kmPerDay: _usageProfileDailyKm(usageProfile),
        source: 'profil pakai',
      );
    }

    // (4) Fallback
    return const DailyKmEstimate(kmPerDay: 10.0, source: 'default');
  }

  // ── Base km/L by vehicle ──────────────────────────────────────────────

  /// Base efficiency for an "ideal" example of this vehicle: relatively new,
  /// manual transmission, mid-tier city traffic, fed correct RON.
  /// All the situational factors compound on top of this.
  static double _baseKmPerLiter(Vehicle v) {
    if (v.type == VehicleType.motor) {
      return _motorBaseFromCc(v.engineCc);
    }
    return _mobilBaseFromBodyAndCc(v.bodyType, v.engineCc);
  }

  /// Indonesian commuter-motor baselines. Rough but anchored to common
  /// real-world numbers (Honda/Yamaha trip reports, owner forums).
  static double _motorBaseFromCc(int? cc) {
    if (cc == null) return 45.0; // generic motor commuter
    if (cc <= 110) return 55.0; // Beat / Mio / matic kecil
    if (cc <= 125) return 48.0; // Vario / NMax-ish
    if (cc <= 160) return 40.0; // PCX, ADV, sport bebek
    if (cc <= 250) return 32.0; // CBR250, Ninja kecil
    if (cc <= 600) return 22.0; // sport mid-range
    return 18.0; // big bikes
  }

  /// Mobil baseline. Body type is the dominant factor; CC is a tiebreaker.
  /// Values target Pertalite/Pertamax fed to relatively modern cars.
  static double _mobilBaseFromBodyAndCc(BodyType? body, int? cc) {
    final cc0 = cc ?? 1500;
    final ccFactor = math.pow(1500 / cc0, 0.35).toDouble().clamp(0.6, 1.6);

    final bodyBase = switch (body) {
      BodyType.hatchback => 14.0, // Brio, Agya, Yaris
      BodyType.sedan => 13.0, // Vios, City, Civic
      BodyType.mpv => 12.0, // Avanza, Xenia, Ertiga
      BodyType.suv => 10.0, // Rush, HR-V, CR-V
      BodyType.pickup => 9.0, // Hilux, Triton (single cab)
      BodyType.sport => 8.0, // sporty / performance
      null => 12.0, // unknown body — assume MPV-ish (most common in ID)
    };

    return bodyBase * ccFactor;
  }

  // ── Multiplicative adjustment factors ─────────────────────────────────

  /// Older vehicles consume more due to engine wear, deposits, worn
  /// injectors etc. Curve approximated from common service-shop wisdom:
  /// ~1.5%/year past 5 years, capped at -25% for >15-year-old cars.
  static double _ageFactor(int? year) {
    if (year == null) return 1.0;
    final now = DateTime.now().year;
    final age = (now - year).clamp(0, 40);
    if (age <= 5) return 1.0;
    if (age >= 15) return 0.75;
    final extra = age - 5;
    return 1.0 - (0.015 * extra);
  }

  /// Matic transmission consumes more in stop-go traffic. The penalty only
  /// kicks in for jakarta-class congestion or daily-commute users.
  static double _transmissionFactor(
    Transmission? tx,
    PrimaryCity? city,
    UsageProfile? profile,
  ) {
    if (tx == null || tx == Transmission.manual) return 1.0;

    final inCongestedCity = city == PrimaryCity.jakarta ||
        city == PrimaryCity.bandung ||
        city == PrimaryCity.surabaya;
    final isCommute = profile == UsageProfile.dailyCommute;

    if (!inCongestedCity && !isCommute) return 1.0;

    return switch (tx) {
      Transmission.at => 0.90, // -10%
      Transmission.cvt => 0.95, // -5% (CVT handles stop-go better)
      Transmission.dct => 0.92, // -8%
      Transmission.manual => 1.0,
    };
  }

  /// City factor — proxy for traffic congestion.
  static double _cityFactor(PrimaryCity? city) {
    return switch (city) {
      PrimaryCity.jakarta => 0.80, // -20%
      PrimaryCity.bandung => 0.88, // -12%
      PrimaryCity.surabaya => 0.90, // -10%
      PrimaryCity.midSized => 0.95, // -5%
      PrimaryCity.rural => 1.05, // +5% (open road)
      null => 1.0,
    };
  }

  /// Maps a usage profile to an estimated daily km, used as a fallback
  /// when neither trip data nor explicit `weekly_km` preference is set.
  static double _usageProfileDailyKm(UsageProfile profile) {
    return switch (profile) {
      UsageProfile.dailyCommute => 25.0, // ~175 km/week, typical commute
      UsageProfile.weekendOnly => 8.0, // ~55 km/week
      UsageProfile.mixed => 18.0,
      UsageProfile.fieldwork => 50.0, // sales/inspection, heavy use
    };
  }
}
