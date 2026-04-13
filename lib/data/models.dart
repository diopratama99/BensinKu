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

class Vehicle {
  const Vehicle({
    required this.id,
    required this.type,
    required this.name,
    required this.tankCapacityLiters,
  });

  final String id;
  final VehicleType type;
  final String name;
  final num? tankCapacityLiters;

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
    );
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
