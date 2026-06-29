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

/// Daily fuel consumption (liters/day) with provenance.
class ConsumptionEstimate {
  const ConsumptionEstimate({
    required this.litersPerDay,
    required this.source,
    required this.refuelCount,
  });

  final double litersPerDay;

  /// 'riwayat isi' (tank-to-tank from purchase history — most accurate),
  /// 'estimasi jarak' / 'preferensi' / 'profil pakai' / 'default'.
  final String source;

  /// How many refuels backed this estimate.
  final int refuelCount;
}

/// Everything the dashboard needs to render the "kapan isi bensin" card.
///
/// Design philosophy (post-rewrite): for a regular commuter the strongest,
/// least-noisy signal is the *refuel history itself* — dates + liters are
/// hard transaction data, not stacked estimates. So the forecast leads with
/// the refill-interval / tank-to-tank consumption and only falls back to the
/// km/L × daily-km chain during cold start.
class RefillForecast {
  const RefillForecast({
    required this.remainingPct,
    required this.remainingLiters,
    required this.litersPerDay,
    required this.consumptionSource,
    required this.daysLeft,
    required this.predictedDate,
    required this.method,
    required this.kmPerLiter,
    required this.efficiencySource,
    required this.efficiencySampleCount,
    required this.refuelCount,
    this.intervalConsistent = false,
  });

  /// Fraction of tank remaining, 0..1.
  final double remainingPct;
  final double remainingLiters;

  /// Consumption rate used for the forecast.
  final double litersPerDay;
  final String consumptionSource;

  /// Days until predicted refill (null if not enough data).
  final double? daysLeft;
  final DateTime? predictedDate;

  /// Which method produced the date:
  ///   'pola isi ulang'  — refill-interval (regular pattern; most accurate)
  ///   'konsumsi harian' — depletion from L/day consumption
  ///   'estimasi awal'   — cold-start fallback
  final String method;

  /// km/L — now a secondary *display* figure, no longer the spine of the
  /// date prediction.
  final double kmPerLiter;
  final String efficiencySource;
  final int efficiencySampleCount;

  /// Number of refuels available — drives the confidence label.
  final int refuelCount;

  /// True when the refuel intervals are tight enough (low spread) that the
  /// pattern is trustworthy even with only 3 fills. Lets us show AKURAT
  /// earlier for genuinely regular commuters instead of waiting for an
  /// arbitrary count.
  final bool intervalConsistent;

  /// Honest confidence label for the *forecast* (not the km/L blend):
  ///   - 'AKURAT'  : pattern-based AND (≥4 fills OR a consistent cadence)
  ///   - 'BELAJAR' : we have ≥2 fills but the pattern isn't solid yet
  ///   - 'ESTIMASI': cold start
  String get confidenceLabel {
    if (method == 'pola isi ulang' &&
        (refuelCount >= 4 || (refuelCount >= 3 && intervalConsistent))) {
      return 'AKURAT';
    }
    if (refuelCount >= 2) return 'BELAJAR';
    return 'ESTIMASI';
  }
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

  // ── Consumption (liters/day) from refuel history ──────────────────────

  /// Liters/day derived DIRECTLY from purchase history — the most reliable
  /// signal for a regular commuter because it's hard transaction data, not
  /// stacked estimates.
  ///
  /// Method: for a user who fills to (roughly) full each time, the liters
  /// bought between the first and last refuel equals the liters burned in
  /// that span. So:
  ///
  ///   L/day = (Σ liters of all refuels EXCEPT the last) / (days from first
  ///           refuel to last refuel)
  ///
  /// We exclude the last fill because that fuel hasn't been consumed yet —
  /// it's sitting in the tank now. Needs ≥2 refuels spanning a sensible
  /// number of days; otherwise returns null so the caller can fall back to
  /// the km/L × daily-km chain.
  static ConsumptionEstimate? consumptionFromRefuels(List<Refuel> refuels) {
    if (refuels.length < 2) return null;

    // Sort oldest → newest (caller usually passes newest-first).
    final sorted = [...refuels]
      ..sort((a, b) => a.refuelDate.compareTo(b.refuelDate));

    final first = sorted.first;
    final last = sorted.last;
    final spanDays = last.refuelDate.difference(first.refuelDate).inHours /
        24.0;
    // Need a meaningful span; <1 day of history is noise.
    if (spanDays < 1) return null;

    // Liters consumed over the span = everything bought EXCEPT the most
    // recent fill (that one is still in the tank).
    final consumedLiters = sorted
        .take(sorted.length - 1)
        .fold<double>(0, (s, r) => s + r.liters.toDouble());
    if (consumedLiters <= 0) return null;

    final perDay = consumedLiters / spanDays;
    if (!perDay.isFinite || perDay <= 0) return null;

    return ConsumptionEstimate(
      litersPerDay: perDay,
      source: 'riwayat isi',
      refuelCount: sorted.length,
    );
  }

  /// Median number of days between consecutive refuels. Captures a weekly
  /// commuter rhythm (e.g. "selalu ~8 hari sekali") far better than a flat
  /// daily average. Returns null with <2 refuels.
  static double? medianRefuelIntervalDays(List<Refuel> refuels) {
    final gaps = _refuelGaps(refuels);
    if (gaps.isEmpty) return null;

    gaps.sort();
    final mid = gaps.length ~/ 2;
    if (gaps.length.isOdd) return gaps[mid];
    return (gaps[mid - 1] + gaps[mid]) / 2.0;
  }

  /// Cleaned day-gaps between consecutive refuels (same-day double-fills and
  /// absurd >90-day pauses removed).
  static List<double> _refuelGaps(List<Refuel> refuels) {
    if (refuels.length < 2) return const [];
    final sorted = [...refuels]
      ..sort((a, b) => a.refuelDate.compareTo(b.refuelDate));

    final gaps = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      final days =
          sorted[i].refuelDate.difference(sorted[i - 1].refuelDate).inHours /
              24.0;
      if (days >= 0.5 && days <= 90) gaps.add(days);
    }
    return gaps;
  }

  /// Whether the refuel cadence is regular enough to trust the pattern with
  /// only a few fills. Uses the coefficient of variation (stdev / mean):
  /// CV ≤ ~0.25 means the gaps cluster tightly (e.g. 8, 8, 7 days), which is
  /// exactly the steady-commuter case where the date prediction is solid.
  static bool refuelIntervalIsConsistent(List<Refuel> refuels) {
    final gaps = _refuelGaps(refuels);
    if (gaps.length < 2) return false;
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    if (mean <= 0) return false;
    final variance = gaps
            .map((g) => (g - mean) * (g - mean))
            .reduce((a, b) => a + b) /
        gaps.length;
    final cv = math.sqrt(variance) / mean;
    return cv <= 0.25;
  }

  /// The headline forecast for the dashboard "kapan isi bensin" card.
  ///
  /// Strategy, strongest signal first:
  ///   1. Refill-interval — if the user refuels on a regular cadence
  ///      (≥3 refuels), predict next = lastRefuelDate + medianInterval.
  ///      This mirrors the user's own mental model and is the most robust
  ///      for routine commuters.
  ///   2. Daily consumption — deplete the current tank using L/day derived
  ///      from purchase history (fallback: km/L × daily-km chain).
  ///   3. Cold-start — prior km/L + preference-based daily km.
  ///
  /// `remainingLiters` is computed from the last fill minus consumption
  /// since (using whichever L/day source we trust most), unless a fuel-gauge
  /// reading is provided in the future.
  static RefillForecast forecastRefill({
    required Vehicle vehicle,
    required List<Refuel> refuels,
    required List<Trip> trips,
    required List<EfficiencySample> samples,
    PrimaryCity? primaryCity,
    UsageProfile? usageProfile,
    num? weeklyKmPref,
  }) {
    // km/L still computed for display + as a fallback consumption source.
    final eff = posteriorKmPerLiter(
      vehicle: vehicle,
      samples: samples,
      primaryCity: primaryCity,
      usageProfile: usageProfile,
    );

    // ── Consumption rate (L/day) ──
    // Prefer purchase-history consumption (hard data). Otherwise derive
    // from the km/L × daily-km chain (estimate-on-estimate, less reliable).
    final fromHistory = consumptionFromRefuels(refuels);
    final dailyKm = dailyKmEstimate(
      recentTrips: trips,
      weeklyKmPref: weeklyKmPref,
      usageProfile: usageProfile,
    );
    final chainLitersPerDay =
        eff.kmPerLiter > 0 ? dailyKm.kmPerDay / eff.kmPerLiter : 0.0;

    final double litersPerDay;
    final String consumptionSource;
    if (fromHistory != null) {
      litersPerDay = fromHistory.litersPerDay;
      consumptionSource = fromHistory.source;
    } else {
      litersPerDay = chainLitersPerDay;
      consumptionSource = 'estimasi jarak';
    }

    // ── Remaining fuel ──
    final lastRefuel = refuels.isNotEmpty
        ? (refuels.first.refuelDate.isAfter(refuels.last.refuelDate)
            ? refuels.first
            : refuels.last)
        : null;
    final tankCap = vehicle.tankCapacityLiters?.toDouble();

    double remainingLiters;
    double remainingPct;
    if (lastRefuel != null) {
      final daysSinceLast =
          DateTime.now().difference(lastRefuel.refuelDate).inHours / 24.0;
      final consumedSince =
          (litersPerDay > 0 ? litersPerDay * daysSinceLast : 0.0);
      final startLiters = lastRefuel.liters.toDouble();
      remainingLiters =
          (startLiters - consumedSince).clamp(0.0, startLiters);
      final denom = lastRefuel.isFullTank && tankCap != null && tankCap > 0
          ? tankCap
          : startLiters;
      remainingPct =
          denom > 0 ? (remainingLiters / denom).clamp(0.0, 1.0) : 0.0;
    } else {
      remainingLiters = (tankCap ?? 0) * 0.9;
      remainingPct = 0.9;
    }

    // ── Predicted refill date ──
    double? daysLeft;
    DateTime? predictedDate;
    String method;

    final interval = medianRefuelIntervalDays(refuels);
    if (interval != null && refuels.length >= 3 && lastRefuel != null) {
      // Regular cadence — predict from the rhythm itself.
      predictedDate =
          lastRefuel.refuelDate.add(Duration(hours: (interval * 24).round()));
      daysLeft =
          predictedDate.difference(DateTime.now()).inHours / 24.0;
      // A past/!future prediction means we're overdue — clamp to 0.
      if (daysLeft < 0) daysLeft = 0;
      method = 'pola isi ulang';
    } else if (litersPerDay > 0 && remainingLiters > 0) {
      // Deplete current tank by consumption rate.
      daysLeft = remainingLiters / litersPerDay;
      predictedDate =
          DateTime.now().add(Duration(hours: (daysLeft * 24).round()));
      method = consumptionSource == 'riwayat isi'
          ? 'konsumsi harian'
          : 'estimasi awal';
    } else {
      method = 'estimasi awal';
    }

    return RefillForecast(
      remainingPct: remainingPct,
      remainingLiters: remainingLiters,
      litersPerDay: litersPerDay,
      consumptionSource: consumptionSource,
      daysLeft: daysLeft,
      predictedDate: predictedDate,
      method: method,
      kmPerLiter: eff.kmPerLiter,
      efficiencySource: eff.source,
      efficiencySampleCount: eff.sampleCount,
      refuelCount: refuels.length,
      intervalConsistent: refuelIntervalIsConsistent(refuels),
    );
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
