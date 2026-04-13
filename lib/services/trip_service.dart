import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/models.dart';
import '../data/repository.dart';

/// Handles GPS-based trip tracking.
///
/// Usage:
///   final svc = TripService(repo: repo, vehicleId: id);
///   await svc.startTrip();
///   // ... user drives ...
///   final trip = await svc.stopTrip();
class TripService extends ChangeNotifier {
  TripService({required SupabaseRepository repo, required String vehicleId})
      : _repo = repo,
        _vehicleId = vehicleId;

  final SupabaseRepository _repo;
  final String _vehicleId;

  Trip? _activeTrip;
  Trip? get activeTrip => _activeTrip;
  bool get isTracking => _activeTrip != null && _activeTrip!.isActive;

  final List<Position> _positions = [];
  List<Position> get positions => List.unmodifiable(_positions);

  double _distanceMeters = 0.0;
  double get distanceKm => _distanceMeters / 1000.0;

  StreamSubscription<Position>? _positionSub;

  // Batch waypoints to reduce Supabase calls
  final List<TripWaypoint> _pendingWaypoints = [];
  Timer? _flushTimer;

  /// Requests location permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Checks if location services are enabled on device.
  static Future<bool> isServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  /// Starts a new trip and begins streaming GPS.
  Future<void> startTrip() async {
    if (isTracking) return;

    _positions.clear();
    _distanceMeters = 0.0;
    _pendingWaypoints.clear();

    _activeTrip = await _repo.createTrip(vehicleId: _vehicleId);
    notifyListeners();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // only emit when moved ≥15m
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) => _onPosition(pos));

    // Flush waypoints to Supabase every 30s
    _flushTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _flushWaypoints());
  }

  void _onPosition(Position pos) {
    if (!isTracking) return;

    if (_positions.isNotEmpty) {
      _distanceMeters += Geolocator.distanceBetween(
        _positions.last.latitude,
        _positions.last.longitude,
        pos.latitude,
        pos.longitude,
      );
    }

    _positions.add(pos);

    _pendingWaypoints.add(TripWaypoint(
      tripId: _activeTrip!.id,
      lat: pos.latitude,
      lng: pos.longitude,
      recordedAt: pos.timestamp,
    ));

    notifyListeners();
  }

  Future<void> _flushWaypoints() async {
    if (_pendingWaypoints.isEmpty || _activeTrip == null) return;
    final batch = List<TripWaypoint>.from(_pendingWaypoints);
    _pendingWaypoints.clear();
    try {
      await _repo.addWaypoints(batch);
    } catch (_) {
      // Re-queue on failure
      _pendingWaypoints.insertAll(0, batch);
    }
  }

  /// Stops tracking, flushes all waypoints, ends trip in Supabase.
  Future<Trip?> stopTrip() async {
    if (!isTracking) return null;

    _positionSub?.cancel();
    _positionSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    // Flush remaining waypoints
    await _flushWaypoints();

    final ended = await _repo.endTrip(
      tripId: _activeTrip!.id,
      distanceKm: distanceKm,
    );

    _activeTrip = ended;
    notifyListeners();
    return ended;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}
