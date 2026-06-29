import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class SupabaseRepository {
  SupabaseRepository(this._client) : _db = _client.schema(_schemaName);

  final SupabaseClient _client;

  /// Postgres schema yang menampung semua tabel BensinKu.
  /// Lihat `supabase/migrations/20260514120000_move_to_bensinku_schema.sql`.
  static const String _schemaName = 'bensinku';

  /// Query builder yang otomatis resolve `.from()` / `.rpc()` ke
  /// `bensinku.<table>` tanpa perlu rewrite tiap call site.
  /// Tetap pakai `_client` langsung untuk auth / functions / storage / realtime.
  final SupabaseQuerySchema _db;

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
      final List<dynamic> rows = await _db
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
    int? engineCc,
    int? manufacturingYear,
    BodyType? bodyType,
    Transmission? transmission,
    int? recommendedRon,
    String? makeModel,
  }) async {
    return _run(() async {
      final capacity = tankCapacityLiters;
      // body_type wajib null untuk motor (CHECK constraint).
      final effectiveBodyType =
          type == VehicleType.motor ? null : bodyType;
      final Map<String, dynamic> row = await _db
          .from('vehicles')
          .insert({
            'vehicle_type': type.dbValue,
            'name': name.trim().isEmpty ? type.label : name.trim(),
            if (capacity != null) 'tank_capacity_liters': capacity,
            if (engineCc != null) 'engine_cc': engineCc,
            if (manufacturingYear != null)
              'manufacturing_year': manufacturingYear,
            if (effectiveBodyType != null)
              'body_type': effectiveBodyType.dbValue,
            if (transmission != null)
              'transmission': transmission.dbValue,
            if (recommendedRon != null)
              'recommended_ron': recommendedRon,
            if (makeModel != null && makeModel.trim().isNotEmpty)
              'make_model': makeModel.trim(),
          })
          .select()
          .single();

      return Vehicle.fromJson(row);
    });
  }

  Future<Vehicle> updateVehicle({
    required String id,
    required String name,
    required VehicleType type,
    num? tankCapacityLiters,
    int? engineCc,
    int? manufacturingYear,
    BodyType? bodyType,
    Transmission? transmission,
    int? recommendedRon,
    String? makeModel,
  }) async {
    return _run(() async {
      final effectiveBodyType =
          type == VehicleType.motor ? null : bodyType;
      final Map<String, dynamic> row = await _db
          .from('vehicles')
          .update({
            'vehicle_type': type.dbValue,
            'name': name.trim().isEmpty ? type.label : name.trim(),
            'tank_capacity_liters': tankCapacityLiters,
            'engine_cc': engineCc,
            'manufacturing_year': manufacturingYear,
            'body_type': effectiveBodyType?.dbValue,
            'transmission': transmission?.dbValue,
            'recommended_ron': recommendedRon,
            'make_model': (makeModel?.trim().isEmpty ?? true)
                ? null
                : makeModel!.trim(),
          })
          .eq('id', id)
          .select()
          .single();
      return Vehicle.fromJson(row);
    });
  }

  Future<void> deleteVehicle(String id) async {
    return _run(() async {
      await _db.from('vehicles').delete().eq('id', id);
    });
  }

  Future<List<FuelProduct>> listFuelProducts() async {
    return _run(() async {
      final List<dynamic> rows = await _db
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

      final rows = await _db
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
      final Map<String, dynamic> row = await _db
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

      final created = Refuel.fromJson(row);

      // Side effect: detect full-tank → full-tank cycles for prediction.
      // Failures here are non-fatal — the refuel itself was already saved,
      // efficiency sampling is best-effort.
      if (created.isFullTank) {
        try {
          await _maybeRecordFullTankCycle(created);
        } catch (_) {
          // Swallow — efficiency sample is opportunistic.
        }
      }

      return created;
    });
  }

  /// Update an existing refuel. Recomputes nothing here — the caller passes
  /// the final values (the form derives liters/price the same way as create).
  ///
  /// After saving, efficiency samples for the vehicle are fully rebuilt so
  /// the prediction re-calibrates against the corrected data.
  Future<Refuel> updateRefuel({
    required String id,
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
      final Map<String, dynamic> row = await _db
          .from('refuels')
          .update({
            'vehicle_id': vehicleId,
            'fuel_product_id': fuelProductId,
            'refuel_date': refuelDate.toUtc().toIso8601String(),
            'odometer_km': odometerKm,
            'total_rp': totalRp,
            'price_per_liter_snapshot': pricePerLiterSnapshot,
            'liters': liters,
            'is_full_tank': isFullTank,
          })
          .eq('id', id)
          .select(
            'id, vehicle_id, fuel_product_id, refuel_date, odometer_km, total_rp, price_per_liter_snapshot, liters, is_full_tank',
          )
          .single();
      final updated = Refuel.fromJson(row);

      // Re-calibrate: an edit can change dates / liters / full-tank flag,
      // so rebuild the whole sample set. Best-effort — the refuel itself
      // is already saved.
      try {
        await rebuildEfficiencySamples(vehicleId);
      } catch (_) {}

      return updated;
    });
  }

  Future<void> deleteRefuel(String id) async {
    return _run(() async {
      // Capture the vehicle before deleting so we can rebuild its samples.
      String? vehicleId;
      final rows = await _db
          .from('refuels')
          .select('vehicle_id')
          .eq('id', id)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isNotEmpty) {
        vehicleId = (list.first as Map<String, dynamic>)['vehicle_id']
            as String?;
      }

      await _db.from('refuels').delete().eq('id', id);

      // Removing a refuel breaks/forms cycles → rebuild samples.
      if (vehicleId != null) {
        try {
          await rebuildEfficiencySamples(vehicleId);
        } catch (_) {}
      }
    });
  }
  ///
  /// The unique index `fuel_efficiency_samples_pair_uidx` makes this
  /// idempotent — re-running on an already-recorded pair is a no-op.
  Future<void> _maybeRecordFullTankCycle(Refuel currentFull) async {
    // 1. Find the previous full-tank refuel for this vehicle.
    final prevRows = await _db
        .from('refuels')
        .select(
            'id, vehicle_id, refuel_date, liters, is_full_tank, odometer_km')
        .eq('vehicle_id', currentFull.vehicleId)
        .eq('is_full_tank', true)
        .lt(
          'refuel_date',
          currentFull.refuelDate.toUtc().toIso8601String(),
        )
        .order('refuel_date', ascending: false)
        .limit(1);

    final prevList = prevRows as List<dynamic>;
    if (prevList.isEmpty) return; // first full tank, no cycle yet

    final prevFull =
        Refuel.fromJson(prevList.first as Map<String, dynamic>);

    // 2. Determine km traveled between the two full-tanks.
    double? kmTraveled;

    // 2a. Prefer odometer delta if both refuels recorded an odometer.
    final prevOdo = prevFull.odometerKm;
    final curOdo = currentFull.odometerKm;
    if (prevOdo != null && curOdo != null && curOdo > prevOdo) {
      kmTraveled = (curOdo - prevOdo).toDouble();
    }

    // 2b. Else fall back to summing trip distance in the interval.
    if (kmTraveled == null) {
      final tripRows = await _db
          .from('trips')
          .select('distance_km')
          .eq('vehicle_id', currentFull.vehicleId)
          .gte('started_at',
              prevFull.refuelDate.toUtc().toIso8601String())
          .lt('started_at',
              currentFull.refuelDate.toUtc().toIso8601String())
          .not('ended_at', 'is', null);
      final trips = tripRows as List<dynamic>;
      final totalKm = trips.fold<double>(
        0,
        (s, r) => s + ((r['distance_km'] as num?)?.toDouble() ?? 0),
      );
      if (totalKm > 0) kmTraveled = totalKm;
    }

    // 3. No measurable km → skip silently. We don't want to record
    //    a sample we can't trust.
    if (kmTraveled == null || kmTraveled <= 0) return;

    // 4. Insert sample. Liters filled = the *current* full-tank fill,
    //    which is what was needed to refill from "empty-ish" back to full.
    await recordEfficiencySample(
      vehicleId: currentFull.vehicleId,
      fromRefuelId: prevFull.id,
      toRefuelId: currentFull.id,
      kmTraveled: kmTraveled,
      litersFilled: currentFull.liters.toDouble(),
    );
  }

  Future<List<Refuel>> listRefuels({
    String? vehicleId,
    DateTime? from,
    DateTime? toExclusive,
    int? limit,
  }) async {
    return _run(() async {
      final base = _db.from('refuels').select(
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

      final Map<String, dynamic> row = await _db
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
    DateTime? endedAt,
  }) async {
    return _run(() async {
      final Map<String, dynamic> row = await _db
          .from('trips')
          .update({
            'ended_at':
                (endedAt ?? DateTime.now()).toUtc().toIso8601String(),
            'distance_km': distanceKm,
          })
          .eq('id', tripId)
          .select()
          .single();
      return Trip.fromJson(row);
    });
  }

  /// Edit only the distance + duration of a finished trip. The GPS route
  /// (waypoints) and start time are left untouched — duration is applied by
  /// recomputing `ended_at = started_at + duration`.
  ///
  /// Distance feeds the efficiency-sample fallback, so samples for the
  /// vehicle are rebuilt afterward to keep the prediction calibrated.
  Future<Trip> updateTripDistanceDuration({
    required String tripId,
    required DateTime startedAt,
    required double distanceKm,
    required Duration duration,
  }) async {
    return _run(() async {
      final endedAt = startedAt.add(duration);
      final Map<String, dynamic> row = await _db
          .from('trips')
          .update({
            'distance_km': distanceKm,
            'ended_at': endedAt.toUtc().toIso8601String(),
          })
          .eq('id', tripId)
          .select()
          .single();
      final updated = Trip.fromJson(row);
      try {
        await rebuildEfficiencySamples(updated.vehicleId);
      } catch (_) {}
      return updated;
    });
  }

  /// Delete a trip. Its `trip_waypoints` are removed automatically by the
  /// `on delete cascade` FK. Efficiency samples are rebuilt since trip
  /// distance feeds the cycle km fallback.
  Future<void> deleteTrip(String tripId) async {
    return _run(() async {
      String? vehicleId;
      final rows = await _db
          .from('trips')
          .select('vehicle_id')
          .eq('id', tripId)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isNotEmpty) {
        vehicleId = (list.first as Map<String, dynamic>)['vehicle_id']
            as String?;
      }

      await _db.from('trips').delete().eq('id', tripId);

      if (vehicleId != null) {
        try {
          await rebuildEfficiencySamples(vehicleId);
        } catch (_) {}
      }
    });
  }

  /// Insert a fully-formed manual trip in one shot — for when the user
  /// forgot to record live (or wants to log a known route). No waypoints;
  /// just start/end time + distance. Counts toward distance-based features
  /// the same as a GPS trip.
  Future<Trip> createManualTrip({
    required String vehicleId,
    required double distanceKm,
    required DateTime startedAt,
    required DateTime endedAt,
    String? note,
  }) async {
    return _run(() async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw StateError('User not logged in');

      final Map<String, dynamic> row = await _db
          .from('trips')
          .insert({
            'vehicle_id': vehicleId,
            'user_id': userId,
            'started_at': startedAt.toUtc().toIso8601String(),
            'ended_at': endedAt.toUtc().toIso8601String(),
            'distance_km': distanceKm,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          })
          .select()
          .single();
      return Trip.fromJson(row);
    });
  }

  /// Hard-delete a trip + all its waypoints (CASCADE via FK).
  ///
  /// Dipakai untuk "discard" rekaman yang invalid (terlalu pendek, salah
  /// pencet) supaya tidak ikut ke history dan tidak meracuni
  /// fuel-efficiency sample (yang fallback ke `sum(distance_km)` saat
  /// odometer kosong).
  Future<void> discardTrip(String tripId) async {
    return _run(() async {
      await _db.from('trips').delete().eq('id', tripId);
    });
  }

  Future<void> addWaypoints(List<TripWaypoint> waypoints) async {
    if (waypoints.isEmpty) return;
    return _run(() async {
      await _db
          .from('trip_waypoints')
          .insert(waypoints.map((w) => w.toJson()).toList());
    });
  }

  Future<List<Trip>> listTrips({
    String? vehicleId,
    int? limit,
    DateTime? since,
  }) async {
    return _run(() async {
      var query = _db
          .from('trips')
          .select()
          .not('ended_at', 'is', null);
      if (vehicleId != null) {
        query = query.eq('vehicle_id', vehicleId);
      }
      if (since != null) {
        query = query.gte('started_at', since.toUtc().toIso8601String());
      }
      final List<dynamic> rows = await query
          .order('started_at', ascending: false)
          .limit(limit ?? 1000);
      return rows
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Fetch satu trip by id. Return null kalau tidak ada (mis. baru saja
  /// di-discard, atau dari user lain → RLS filter out). Dipakai
  /// terutama oleh tap-handler notif auto-stop yang membawa trip-id.
  Future<Trip?> getTrip(String tripId) async {
    return _run(() async {
      final rows = await _db
          .from('trips')
          .select()
          .eq('id', tripId)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return Trip.fromJson(list.first as Map<String, dynamic>);
    });
  }

  Future<List<TripWaypoint>> getTripWaypoints(String tripId) async {
    return _run(() async {
      final List<dynamic> rows = await _db
          .from('trip_waypoints')
          .select()
          .eq('trip_id', tripId)
          .order('recorded_at');
      return rows
          .map((e) => TripWaypoint.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  // ─── Efficiency sample methods (Predictions v2) ─────────────────────────

  /// Insert a measured km/L sample. Idempotent jika `(vehicle_id,
  /// from_refuel_id, to_refuel_id)` sudah ada (unique index akan throw 23505,
  /// di-swallow disini supaya auto-retry aman).
  Future<EfficiencySample?> recordEfficiencySample({
    required String vehicleId,
    required double kmTraveled,
    required double litersFilled,
    String? fromRefuelId,
    String? toRefuelId,
    Map<String, dynamic>? context,
  }) async {
    return _run(() async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw StateError('User not logged in');

      try {
        final Map<String, dynamic> row = await _db
            .from('fuel_efficiency_samples')
            .insert({
              'user_id': userId,
              'vehicle_id': vehicleId,
              'from_refuel_id': fromRefuelId,
              'to_refuel_id': toRefuelId,
              'km_traveled': kmTraveled,
              'liters_filled': litersFilled,
              if (context != null) 'context': context,
            })
            .select()
            .single();
        return EfficiencySample.fromJson(row);
      } on PostgrestException catch (e) {
        // 23505 = unique_violation. Pasangan refuel sudah pernah direkam,
        // ini operasi idempotent jadi bukan error.
        if (e.code == '23505') return null;
        rethrow;
      }
    });
  }

  /// N pengukuran efisiensi terbaru untuk satu kendaraan.
  Future<List<EfficiencySample>> recentEfficiencySamples({
    required String vehicleId,
    int limit = 10,
  }) async {
    return _run(() async {
      final List<dynamic> rows = await _db
          .from('fuel_efficiency_samples')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('measured_at', ascending: false)
          .range(0, limit - 1);
      return rows
          .map((e) =>
              EfficiencySample.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Recompute ALL efficiency samples for a vehicle from scratch.
  ///
  /// Editing or deleting a refuel can reorder dates, flip the full-tank
  /// flag, or change liters — patching individual samples would be fragile.
  /// Instead we wipe the vehicle's samples and rebuild every consecutive
  /// full-tank → full-tank cycle. Cheap (a user has at most dozens of
  /// refuels) and always correct.
  ///
  /// km traveled per cycle: prefer odometer delta, else fall back to summing
  /// finished GPS trips in the interval — same rule as live recording.
  Future<void> rebuildEfficiencySamples(String vehicleId) async {
    return _run(() async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw StateError('User not logged in');

      // 1. Wipe existing samples for this vehicle.
      await _db
          .from('fuel_efficiency_samples')
          .delete()
          .eq('vehicle_id', vehicleId);

      // 2. Load full-tank refuels, oldest → newest.
      final List<dynamic> rows = await _db
          .from('refuels')
          .select(
              'id, vehicle_id, fuel_product_id, refuel_date, odometer_km, total_rp, price_per_liter_snapshot, liters, is_full_tank')
          .eq('vehicle_id', vehicleId)
          .eq('is_full_tank', true)
          .order('refuel_date', ascending: true);
      final fullTanks = rows
          .map((e) => Refuel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (fullTanks.length < 2) return; // no cycle possible

      // 3. Pre-fetch finished trips for distance fallback (one query).
      final tripRows = await _db
          .from('trips')
          .select('started_at, distance_km')
          .eq('vehicle_id', vehicleId)
          .not('ended_at', 'is', null);
      final trips = (tripRows as List<dynamic>)
          .map((e) => (
                started: DateTime.parse(e['started_at'] as String).toLocal(),
                km: (e['distance_km'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList();

      // 4. Rebuild each consecutive full→full cycle.
      for (var i = 1; i < fullTanks.length; i++) {
        final prev = fullTanks[i - 1];
        final cur = fullTanks[i];

        double? kmTraveled;
        // 4a. Odometer delta if both present and increasing.
        final prevOdo = prev.odometerKm;
        final curOdo = cur.odometerKm;
        if (prevOdo != null && curOdo != null && curOdo > prevOdo) {
          kmTraveled = (curOdo - prevOdo).toDouble();
        }
        // 4b. Else sum GPS trip distance within the interval.
        if (kmTraveled == null) {
          final totalKm = trips
              .where((t) =>
                  !t.started.isBefore(prev.refuelDate) &&
                  t.started.isBefore(cur.refuelDate))
              .fold<double>(0, (s, t) => s + t.km);
          if (totalKm > 0) kmTraveled = totalKm;
        }
        if (kmTraveled == null || kmTraveled <= 0) continue;

        // Liters filled = current fill (to go from empty-ish back to full).
        await recordEfficiencySample(
          vehicleId: vehicleId,
          fromRefuelId: prev.id,
          toRefuelId: cur.id,
          kmTraveled: kmTraveled,
          litersFilled: cur.liters.toDouble(),
        );
      }
    });
  }

  // ─── Maintenance methods ────────────────────────────────────────────────

  /// All maintenance items, optionally scoped to one vehicle.
  Future<List<MaintenanceItem>> listMaintenanceItems({
    String? vehicleId,
  }) async {
    return _run(() async {
      final base = _db.from('maintenance_items').select();
      final filtered =
          vehicleId == null ? base : base.eq('vehicle_id', vehicleId);
      final List<dynamic> rows =
          await filtered.order('last_service_date', ascending: false);
      return rows
          .map((e) => MaintenanceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<MaintenanceItem> createMaintenanceItem({
    required String vehicleId,
    required MaintenanceType type,
    required int intervalDays,
    required DateTime lastServiceDate,
    String? title,
    String? note,
  }) async {
    return _run(() async {
      final Map<String, dynamic> row = await _db
          .from('maintenance_items')
          .insert({
            'vehicle_id': vehicleId,
            'type': type.dbValue,
            if (title != null && title.trim().isNotEmpty)
              'title': title.trim(),
            'interval_days': intervalDays,
            'last_service_date': lastServiceDate.toUtc().toIso8601String(),
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          })
          .select()
          .single();
      return MaintenanceItem.fromJson(row);
    });
  }

  Future<MaintenanceItem> updateMaintenanceItem({
    required String id,
    required MaintenanceType type,
    required int intervalDays,
    required DateTime lastServiceDate,
    String? title,
    String? note,
  }) async {
    return _run(() async {
      final Map<String, dynamic> row = await _db
          .from('maintenance_items')
          .update({
            'type': type.dbValue,
            'title': (title?.trim().isEmpty ?? true) ? null : title!.trim(),
            'interval_days': intervalDays,
            'last_service_date': lastServiceDate.toUtc().toIso8601String(),
            'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
          })
          .eq('id', id)
          .select()
          .single();
      return MaintenanceItem.fromJson(row);
    });
  }

  /// Mark a task as done now — resets `last_service_date` to today so the
  /// next due date rolls forward by the interval.
  Future<MaintenanceItem> markMaintenanceDone(String id) async {
    return _run(() async {
      final Map<String, dynamic> row = await _db
          .from('maintenance_items')
          .update({
            'last_service_date': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return MaintenanceItem.fromJson(row);
    });
  }

  Future<void> deleteMaintenanceItem(String id) async {
    return _run(() async {
      await _db.from('maintenance_items').delete().eq('id', id);
    });
  }
}
