import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class SupabaseRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;

  static SupabaseRepository ofDefaultClient() {
    return SupabaseRepository(Supabase.instance.client);
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PostgrestException catch (e, st) {
      final mapped = _mapPostgrestException(e);
      if (mapped != null) {
        Error.throwWithStackTrace(mapped, st);
      }
      rethrow;
    }
  }

  StateError? _mapPostgrestException(PostgrestException e) {
    final code = e.code;
    final msg = e.message;
    final details = e.details;

    final looksLikeMissingTable =
        code == 'PGRST205' || msg.contains('schema cache') || msg.contains("Could not find the table");
    if (!looksLikeMissingTable) return null;

    final text = [msg, details].whereType<String>().join(' ');
    final match = RegExp(r"table '([\w]+\.[\w]+)'").firstMatch(text);
    final tableName = match?.group(1);

    final tablePart = tableName == null ? 'tabel yang dibutuhkan' : 'tabel `$tableName`';
    return StateError(
      'Backend belum siap: $tablePart belum ada di database Supabase.\n'
      'Jalankan `supabase/schema.sql` lalu `supabase/seed.sql` di Supabase Studio → SQL Editor.\n'
      'Kalau sudah pernah, tunggu sebentar atau restart container REST/PostgREST supaya schema cache ke-refresh.',
    );
  }

  Future<List<Vehicle>> listVehicles() async {
    return _run(() async {
      final List<dynamic> rows = await _client
          .from('vehicles')
          .select()
          .order('vehicle_type');

      return rows.map((e) => Vehicle.fromJson(e)).toList();
    });
  }

  Future<Vehicle> createVehicle({
    required VehicleType type,
    required String name,
    num? tankCapacityLiters,
  }) async {
    return _run(() async {
      final capacity = tankCapacityLiters;
      final Map<String, dynamic> row = await _client
          .from('vehicles')
          .insert({
            'vehicle_type': type.dbValue,
            'name': name.trim().isEmpty ? type.label : name.trim(),
            if (capacity != null) 'tank_capacity_liters': capacity,
          })
          .select()
          .single();

      return Vehicle.fromJson(row);
    });
  }

  Future<List<FuelProduct>> listFuelProducts() async {
    return _run(() async {
      final List<dynamic> rows = await _client
          .from('fuel_products')
          .select('id, brand, name, active, sort_order')
          .eq('active', true)
          .order('brand')
          .order('sort_order')
          .order('name');

      return rows.map((e) => FuelProduct.fromJson(e)).toList();
    });
  }

  Future<FuelPrice?> getFuelPrice({
    required String fuelProductId,
    required DateTime onDate,
  }) async {
    return _run(() async {
      final day = _dateOnly(onDate);

      final rows = await _client
          .from('fuel_prices')
          .select('price_per_liter, effective_from')
          .eq('fuel_product_id', fuelProductId)
          .lte('effective_from', day)
          .order('effective_from', ascending: false)
          .limit(1);

      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;

      return FuelPrice.fromJson(list.first as Map<String, dynamic>);
    });
  }

  Future<Refuel> createRefuel({
    required String vehicleId,
    required String fuelProductId,
    required DateTime refuelDate,
    num? odometerKm,
    required num totalRp,
    required num pricePerLiterSnapshot,
    required num liters,
    required bool isFullTank,
  }) async {
    return _run(() async {
      final Map<String, dynamic> row = await _client
          .from('refuels')
          .insert({
            'vehicle_id': vehicleId,
            'fuel_product_id': fuelProductId,
            'refuel_date': refuelDate.toUtc().toIso8601String(),
            'odometer_km': odometerKm,
            'total_rp': totalRp,
            'price_per_liter_snapshot': pricePerLiterSnapshot,
            'liters': liters,
            'is_full_tank': isFullTank,
          })
          .select(
            'id, vehicle_id, fuel_product_id, refuel_date, odometer_km, total_rp, price_per_liter_snapshot, liters, is_full_tank',
          )
          .single();

      return Refuel.fromJson(row);
    });
  }

  Future<List<Refuel>> listRefuels({
    String? vehicleId,
    DateTime? from,
    DateTime? toExclusive,
    int? limit,
  }) async {
    return _run(() async {
      final base = _client.from('refuels').select(
            'id, vehicle_id, fuel_product_id, refuel_date, odometer_km, total_rp, price_per_liter_snapshot, liters, is_full_tank',
          );

        final filtered =
          vehicleId == null ? base : base.eq('vehicle_id', vehicleId);

        final dated = from == null
          ? filtered
          : filtered.gte('refuel_date', from.toUtc().toIso8601String());
        final ranged = toExclusive == null
          ? dated
          : dated.lt('refuel_date', toExclusive.toUtc().toIso8601String());

        final ordered = ranged.order('refuel_date', ascending: false);
        final rows =
          limit == null ? await ordered : await ordered.range(0, limit - 1);

      return (rows as List<dynamic>)
          .map((e) => Refuel.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  static String _dateOnly(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ─── Trip methods ───────────────────────────────────────────────────────

  Future<Trip> createTrip({required String vehicleId}) async {
    return _run(() async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw StateError('User not logged in');

      final Map<String, dynamic> row = await _client
          .from('trips')
          .insert({
            'vehicle_id': vehicleId,
            'user_id': userId,
            'started_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return Trip.fromJson(row);
    });
  }

  Future<Trip> endTrip({
    required String tripId,
    required double distanceKm,
  }) async {
    return _run(() async {
      final Map<String, dynamic> row = await _client
          .from('trips')
          .update({
            'ended_at': DateTime.now().toUtc().toIso8601String(),
            'distance_km': distanceKm,
          })
          .eq('id', tripId)
          .select()
          .single();
      return Trip.fromJson(row);
    });
  }

  Future<void> addWaypoints(List<TripWaypoint> waypoints) async {
    if (waypoints.isEmpty) return;
    return _run(() async {
      await _client
          .from('trip_waypoints')
          .insert(waypoints.map((w) => w.toJson()).toList());
    });
  }

  Future<List<Trip>> listTrips({String? vehicleId}) async {
    return _run(() async {
      final base = _client.from('trips').select();
      final filtered =
          vehicleId == null ? base : base.eq('vehicle_id', vehicleId);
      final List<dynamic> rows =
          await filtered.order('started_at', ascending: false);
      return rows
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<TripWaypoint>> getTripWaypoints(String tripId) async {
    return _run(() async {
      final List<dynamic> rows = await _client
          .from('trip_waypoints')
          .select()
          .eq('trip_id', tripId)
          .order('recorded_at');
      return rows
          .map((e) => TripWaypoint.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }
}
