import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/models.dart';
import '../data/repository.dart';

/// Outcome of a location-permission request.
///
/// We need finer granularity than just "granted/denied" because
/// `whileInUseOnly` is silently lossy — tracking will look like it's
/// working in the foreground but stop accumulating waypoints once the
/// screen turns off. The UI should warn the user when this happens.
enum LocationPermissionStatus {
  /// Permission denied this round, but the user can be asked again next
  /// time (system has not flagged "don't ask again").
  denied,

  /// User picked "Don't ask again" / iOS "Never". Only the system
  /// settings page can re-grant from here.
  permanentlyDenied,

  /// Got "While using the app" but not "Always". Tracking works in
  /// foreground only; will pause when screen turns off.
  whileInUseOnly,

  /// Got "Always" / "Allow all the time". Tracking is robust to
  /// screen-off / backgrounding.
  alwaysGranted,
}

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

  /// Result of a permission request. Tells the caller whether tracking
  /// will survive screen-off / app-backgrounded.
  ///
  /// - [granted]: location permission obtained at all? If false, tracking
  ///   cannot start.
  /// - [background]: was "Allow all the time" (Always) granted? If false,
  ///   tracking still works while the app is foregrounded but Android will
  ///   pause GPS updates when the screen turns off, leaving the trip log
  ///   with gaps.
  /// - [permanentlyDenied]: the user picked "Don't ask again" — only the
  ///   app-settings page can re-grant.
  static const _permWhileInUse = LocationPermission.whileInUse;
  static const _permAlways = LocationPermission.always;

  /// Asks for location permission, escalating to "Always" so background
  /// tracking works.
  ///
  /// Two-step flow on Android 11+:
  ///   1. Request whileInUse — system shows the basic dialog.
  ///   2. If granted, request always — system kicks the user into
  ///      Settings to upgrade ("Allow all the time").
  ///
  /// On iOS we ask once; the system handles the two-step prompt itself.
  static Future<LocationPermissionStatus> requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();

    // Step 1: get at least whileInUse.
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return LocationPermissionStatus.permanentlyDenied;
    }
    if (perm == LocationPermission.denied) {
      return LocationPermissionStatus.denied;
    }

    // Step 2: try to escalate to "Always" so tracking survives screen-off.
    if (perm == _permWhileInUse) {
      try {
        final upgraded = await Geolocator.requestPermission();
        if (upgraded == _permAlways) {
          return LocationPermissionStatus.alwaysGranted;
        }
      } catch (_) {
        // requestPermission can throw on subsequent calls within a short
        // window. Treat as no-upgrade rather than a hard error.
      }
      return LocationPermissionStatus.whileInUseOnly;
    }

    if (perm == _permAlways) {
      return LocationPermissionStatus.alwaysGranted;
    }
    return LocationPermissionStatus.denied;
  }

  /// Opens the system app-settings screen so the user can grant
  /// "Allow all the time" manually. Used when [requestPermission] returns
  /// [LocationPermissionStatus.permanentlyDenied] or
  /// [LocationPermissionStatus.whileInUseOnly] and the user wants to fix
  /// it.
  static Future<bool> openLocationSettings() {
    return Geolocator.openAppSettings();
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

    final settings = _trackingLocationSettings();

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) => _onPosition(pos));

    // Flush waypoints to Supabase every 30s
    _flushTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _flushWaypoints());
  }

  /// Platform-aware location settings for an active trip.
  ///
  /// On Android we attach a foreground notification config so the OS keeps
  /// our position stream alive when the screen turns off. Without this,
  /// background scheduling kicks in and updates stop arriving until the user
  /// re-opens the app — which is the bug where "tracking active but no
  /// dots being added".
  ///
  /// On iOS we set `allowBackgroundLocationUpdates` + `pauseLocationUpdates`
  /// off. iOS also needs the `UIBackgroundModes: location` Info.plist key
  /// and `NSLocationAlwaysAndWhenInUseUsageDescription` for this to work
  /// past app backgrounding (configured separately).
  LocationSettings _trackingLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'BensinKu sedang mencatat rute',
          notificationText:
              'Tracking GPS berjalan. Tap untuk kembali ke aplikasi.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        // Required for the stream to keep delivering updates after the
        // user backgrounds the app or locks the screen.
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.automotiveNavigation,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );
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
