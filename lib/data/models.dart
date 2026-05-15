enum VehicleType {
  motor('motor'),
  mobil('mobil');

  const VehicleType(this.dbValue);

  final String dbValue;

  static VehicleType? tryParse(String? value) {
    if (value == null) return null;
    for (final t in VehicleType.values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        VehicleType.motor => 'Motor',
        VehicleType.mobil => 'Mobil',
      };
}

/// Body type — only meaningful for cars (motor → null).
/// String values match CHECK constraint in
/// `supabase/migrations/20260515090000_predictions_v2.sql`.
enum BodyType {
  sedan('sedan'),
  hatchback('hatchback'),
  mpv('mpv'),
  suv('suv'),
  pickup('pickup'),
  sport('sport');

  const BodyType(this.dbValue);
  final String dbValue;

  static BodyType? tryParse(String? value) {
    if (value == null) return null;
    for (final t in BodyType.values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        BodyType.sedan => 'Sedan',
        BodyType.hatchback => 'City Car',
        BodyType.mpv => 'Keluarga',
        BodyType.suv => 'SUV',
        BodyType.pickup => 'Pickup',
        BodyType.sport => 'Sport',
      };
}

/// Transmission type. Mapped to CHECK constraint values.
enum Transmission {
  manual('manual'),
  at('at'),
  cvt('cvt'),
  dct('dct');

  const Transmission(this.dbValue);
  final String dbValue;

  static Transmission? tryParse(String? value) {
    if (value == null) return null;
    for (final t in Transmission.values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        Transmission.manual => 'Manual',
        Transmission.at => 'Matic',
        Transmission.cvt => 'Matic CVT',
        Transmission.dct => 'Matic Dual-Kopling',
      };
}

/// Octane rating populer di Indonesia. Validated against CHECK constraint
/// (88, 90, 92, 95, 98).
class OctaneRating {
  static const validRons = <int>[88, 90, 92, 95, 98];

  static String labelFor(int ron) => switch (ron) {
        88 => 'RON 88 (Premium)',
        90 => 'RON 90 (Pertalite)',
        92 => 'RON 92 (Pertamax)',
        95 => 'RON 95 (V-Power / Pertamax Turbo lama)',
        98 => 'RON 98 (Pertamax Turbo)',
        _ => 'RON $ron',
      };
}

/// User usage profile — tersimpan di `user_metadata.usage_profile`.
enum UsageProfile {
  dailyCommute('daily_commute', 'Komuter harian'),
  weekendOnly('weekend', 'Akhir pekan saja'),
  mixed('mixed', 'Campuran'),
  fieldwork('fieldwork', 'Kerja lapangan');

  const UsageProfile(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static UsageProfile? tryParse(String? value) {
    if (value == null) return null;
    for (final t in UsageProfile.values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }
}

/// City/area cluster — proxy untuk macet level. Stored in
/// `user_metadata.primary_city`.
enum PrimaryCity {
  jakarta('jakarta', 'Jakarta'),
  bandung('bandung', 'Bandung'),
  surabaya('surabaya', 'Surabaya'),
  midSized('mid_sized', 'Kota sedang'),
  rural('rural', 'Luar kota / desa');

  const PrimaryCity(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PrimaryCity? tryParse(String? value) {
    if (value == null) return null;
    for (final t in PrimaryCity.values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.type,
    required this.name,
    required this.tankCapacityLiters,
    this.engineCc,
    this.manufacturingYear,
    this.bodyType,
    this.transmission,
    this.recommendedRon,
    this.makeModel,
  });

  final String id;
  final VehicleType type;
  final String name;
  final num? tankCapacityLiters;

  // Detail mesin (Predictions v2). Semua nullable supaya backward-compatible
  // dengan kendaraan yang sudah ada sebelum migration.
  final int? engineCc;
  final int? manufacturingYear;
  final BodyType? bodyType;
  final Transmission? transmission;
  final int? recommendedRon;
  final String? makeModel;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final type = VehicleType.tryParse(json['vehicle_type'] as String?);
    if (type == null) throw StateError('Unknown vehicle_type');

    return Vehicle(
      id: json['id'] as String,
      type: type,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : type.label,
      tankCapacityLiters: json['tank_capacity_liters'] as num?,
      engineCc: (json['engine_cc'] as num?)?.toInt(),
      manufacturingYear: (json['manufacturing_year'] as num?)?.toInt(),
      bodyType: BodyType.tryParse(json['body_type'] as String?),
      transmission:
          Transmission.tryParse(json['transmission'] as String?),
      recommendedRon: (json['recommended_ron'] as num?)?.toInt(),
      makeModel: (json['make_model'] as String?)?.trim().isEmpty == true
          ? null
          : (json['make_model'] as String?)?.trim(),
    );
  }
}

/// Computed completeness check used by the auth gate. A vehicle is considered
/// "complete" only if all reference fields needed for the prediction prior
/// are filled. Body type is required for mobil only (motors don't have it).
extension VehicleCompleteness on Vehicle {
  bool get hasCompleteReferenceData {
    if (tankCapacityLiters == null) return false;
    if (engineCc == null) return false;
    if (manufacturingYear == null) return false;
    if (transmission == null) return false;
    if (type == VehicleType.mobil && bodyType == null) return false;
    return true;
  }
}

class FuelProduct {
  const FuelProduct({
    required this.id,
    required this.brand,
    required this.name,
  });

  final String id;
  final String brand;
  final String name;

  String get label {
    final brandCap = brand.isEmpty
        ? ''
        : '${brand[0].toUpperCase()}${brand.substring(1)}';
    return '$brandCap — $name';
  }

  factory FuelProduct.fromJson(Map<String, dynamic> json) {
    return FuelProduct(
      id: json['id'] as String,
      brand: (json['brand'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }
}

class FuelPrice {
  const FuelPrice({required this.pricePerLiter});

  final num pricePerLiter;

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    return FuelPrice(pricePerLiter: json['price_per_liter'] as num);
  }
}

class Refuel {
  const Refuel({
    required this.id,
    required this.vehicleId,
    required this.fuelProductId,
    required this.refuelDate,
    required this.odometerKm,
    required this.totalRp,
    required this.pricePerLiterSnapshot,
    required this.liters,
    required this.isFullTank,
  });

  final String id;
  final String vehicleId;
  final String fuelProductId;
  final DateTime refuelDate;
  final num? odometerKm;
  final num totalRp;
  final num pricePerLiterSnapshot;
  final num liters;
  final bool isFullTank;

  factory Refuel.fromJson(Map<String, dynamic> json) {
    return Refuel(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      fuelProductId: json['fuel_product_id'] as String,
      refuelDate: DateTime.parse(json['refuel_date'] as String).toLocal(),
      odometerKm: json['odometer_km'] as num?,
      totalRp: json['total_rp'] as num,
      pricePerLiterSnapshot: json['price_per_liter_snapshot'] as num,
      liters: json['liters'] as num,
      isFullTank: (json['is_full_tank'] as bool?) ?? false,
    );
  }
}

class Trip {
  const Trip({
    required this.id,
    required this.vehicleId,
    required this.startedAt,
    this.endedAt,
    this.distanceKm,
    this.note,
  });

  final String id;
  final String vehicleId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? distanceKm;
  final String? note;

  bool get isActive => endedAt == null;

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String).toLocal(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }
}

class TripWaypoint {
  const TripWaypoint({
    required this.tripId,
    required this.lat,
    required this.lng,
    required this.recordedAt,
  });

  final String tripId;
  final double lat;
  final double lng;
  final DateTime recordedAt;

  factory TripWaypoint.fromJson(Map<String, dynamic> json) {
    return TripWaypoint(
      tripId: json['trip_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'lat': lat,
        'lng': lng,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}


/// Hasil parse dari Edge Function `parse-fuel-receipt` atau `parse-fuel-voice`.
/// Sengaja loose (semua field nullable / optional) supaya UI bisa pre-fill apa
/// adanya dan user tinggal koreksi di sheet input.
class ParsedRefuel {
  const ParsedRefuel({
    required this.vehicleId,
    required this.vehicleLabel,
    required this.fuelProductId,
    required this.fuelProductLabel,
    required this.refuelDate,
    required this.totalRp,
    required this.pricePerLiter,
    required this.liters,
    required this.isFullTank,
    required this.confidence,
    required this.reasoning,
    this.odometerKm,
  });

  final String vehicleId;
  final String vehicleLabel;
  final String fuelProductId;
  final String fuelProductLabel;
  final DateTime refuelDate;
  final num? odometerKm;
  final num totalRp;
  final num pricePerLiter;
  final num liters;
  final bool isFullTank;
  final String confidence;
  final String reasoning;

  factory ParsedRefuel.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['refuel_date'];
    DateTime parsedDate;
    if (dateRaw is String && dateRaw.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateRaw) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ParsedRefuel(
      vehicleId: (json['vehicle_id'] as String?) ?? '',
      vehicleLabel: (json['vehicle_label'] as String?) ?? '',
      fuelProductId: (json['fuel_product_id'] as String?) ?? '',
      fuelProductLabel: (json['fuel_product_label'] as String?) ?? '',
      refuelDate: parsedDate,
      odometerKm: (json['odometer_km'] as num?),
      totalRp: (json['total_rp'] as num?) ?? 0,
      pricePerLiter: (json['price_per_liter'] as num?) ?? 0,
      liters: (json['liters'] as num?) ?? 0,
      isFullTank: (json['is_full_tank'] as bool?) ?? false,
      confidence: (json['confidence'] as String?) ?? 'medium',
      reasoning: (json['reasoning'] as String?) ?? '',
    );
  }
}

/// Ground-truth fuel efficiency sample, recorded between two consecutive
/// full-tank fills for a single vehicle. Used by the prediction service to
/// blend with the cold-start prior.
class EfficiencySample {
  const EfficiencySample({
    required this.id,
    required this.vehicleId,
    required this.kmTraveled,
    required this.litersFilled,
    required this.kmPerLiter,
    required this.measuredAt,
    this.fromRefuelId,
    this.toRefuelId,
  });

  final String id;
  final String vehicleId;
  final String? fromRefuelId;
  final String? toRefuelId;
  final double kmTraveled;
  final double litersFilled;
  final double kmPerLiter;
  final DateTime measuredAt;

  factory EfficiencySample.fromJson(Map<String, dynamic> json) {
    return EfficiencySample(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      fromRefuelId: json['from_refuel_id'] as String?,
      toRefuelId: json['to_refuel_id'] as String?,
      kmTraveled: (json['km_traveled'] as num).toDouble(),
      litersFilled: (json['liters_filled'] as num).toDouble(),
      kmPerLiter: (json['km_per_liter'] as num).toDouble(),
      measuredAt:
          DateTime.parse(json['measured_at'] as String).toLocal(),
    );
  }
}
