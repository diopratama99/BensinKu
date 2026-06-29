import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'notification_service.dart';

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

/// Outcome of a trip stop / auto-stop.
///
/// We need a richer return type than just `Trip?` because of the
/// "invalid recording" case: user taps START → almost no GPS fix →
/// taps STOP within a few seconds. We don't want that row sitting in
/// the database polluting history and the prediction prior, so the
/// service deletes it and reports back why.
class TripStopResult {
  const TripStopResult.saved(this.trip)
      : discarded = false,
        reason = TripDiscardReason.none;
  const TripStopResult.discarded(this.reason)
      : trip = null,
        discarded = true;

  /// The persisted trip, or `null` if it was discarded.
  final Trip? trip;

  /// True jika rekaman dibuang (tidak masuk DB). UI harus tampilkan
  /// dialog "rekaman dibatalkan" alih-alih summary normal.
  final bool discarded;

  /// Alasan kenapa di-discard. `none` saat trip valid.
  final TripDiscardReason reason;
}

enum TripDiscardReason {
  none,

  /// Total durasi < ambang minimum (default 30 detik).
  tooShortDuration,

  /// Total jarak < ambang minimum (default 100 m).
  tooShortDistance,

  /// Tidak cukup waypoint GPS (default 5).
  tooFewWaypoints,
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

  // ── Idle auto-stop ──────────────────────────────────────────────────
  /// If the device doesn't genuinely move (stays within
  /// [_movementThresholdMeters] of an anchor point) for this long, the
  /// trip is auto-stopped. The idle window is trimmed from the recorded
  /// trip (ended_at = wall-clock time of the last genuine movement).
  static const Duration _idleTimeout = Duration(minutes: 30);

  /// How far (meters) the device must move from the current anchor before
  /// we count it as genuine movement. Bigger than typical GPS jitter
  /// (which can spike 15–40m while stationary) so parking drift doesn't
  /// keep resetting the idle clock.
  static const double _movementThresholdMeters = 50;

  Timer? _idleCheckTimer;

  /// Device wall-clock time (NOT the GPS fix timestamp) of the last
  /// genuine movement. Using `DateTime.now()` here avoids geolocator's
  /// `Position.timestamp` clock/zone quirks that previously made the idle
  /// duration come out negative — which is why auto-stop never fired.
  DateTime? _lastMovementWallTime;

  /// Reference position used to detect genuine movement. Re-anchored each
  /// time the device travels more than [_movementThresholdMeters].
  Position? _idleAnchor;

  /// Number of recorded positions up to (and including) the last genuine
  /// movement. Used to clip distance/waypoints so the idle tail isn't
  /// counted toward the trip.
  int _lastMovingPositionCount = 0;

  /// True if the trip was auto-stopped due to idle timeout. UI can use
  /// this to show a badge "DIHENTIKAN OTOMATIS".
  bool _autoStopped = false;
  bool get autoStopped => _autoStopped;

  /// Callback invoked when auto-stop fires. The host widget should show
  /// the trip summary dialog, or the "rekaman dibatalkan" dialog if
  /// `result.discarded` is true.
  void Function(TripStopResult)? onAutoStopped;

  // ── Validity thresholds ─────────────────────────────────────────────
  /// Minimum durasi (start → stop) supaya rekaman dianggap valid.
  /// Trip lebih pendek dari ini dianggap "salah pencet" dan dibuang.
  static const Duration _minValidDuration = Duration(seconds: 30);

  /// Minimum jarak total (meter) supaya rekaman valid. Mencegah trip
  /// statis (HP nyala di meja) bocor masuk ke DB dan meracuni prior.
  static const double _minValidDistanceMeters = 100;

  /// Minimum jumlah waypoint. Sangat kecil = GPS belum dapat fix /
  /// indoor / langsung di-stop.
  static const int _minValidWaypointCount = 5;

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

    // Idle auto-stop: check every 30s if user has been stationary too long.
    _lastMovementWallTime = DateTime.now();
    _idleAnchor = null;
    _lastMovingPositionCount = 0;
    _autoStopped = false;
    _idleCheckTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _checkIdle());
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
      final delta = Geolocator.distanceBetween(
        _positions.last.latitude,
        _positions.last.longitude,
        pos.latitude,
        pos.longitude,
      );
      _distanceMeters += delta;
    }

    _positions.add(pos);

    // ── Idle detection (anchor-based, wall-clock timed) ──
    // Compare against a fixed anchor instead of the previous fix so that
    // GPS jitter while parked (which can spike 15–40m between consecutive
    // fixes) doesn't keep resetting the idle clock. We only count it as
    // genuine movement once we're more than [_movementThresholdMeters]
    // from the anchor; then we re-anchor here.
    final anchor = _idleAnchor;
    if (anchor == null) {
      _idleAnchor = pos;
      _lastMovementWallTime = DateTime.now();
      _lastMovingPositionCount = _positions.length;
    } else {
      final fromAnchor = Geolocator.distanceBetween(
        anchor.latitude,
        anchor.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (fromAnchor > _movementThresholdMeters) {
        _idleAnchor = pos;
        // Use the device wall clock, NOT pos.timestamp — geolocator's
        // timestamp can be in a different clock/zone and made the idle
        // duration go negative, so auto-stop never triggered.
        _lastMovementWallTime = DateTime.now();
        _lastMovingPositionCount = _positions.length;
      }
    }

    _pendingWaypoints.add(TripWaypoint(
      tripId: _activeTrip!.id,
      lat: pos.latitude,
      lng: pos.longitude,
      recordedAt: pos.timestamp,
    ));

    notifyListeners();

    // Safety net: also evaluate idle on every fix. When the screen is off
    // or the app is backgrounded, `Timer.periodic` can be throttled or
    // suspended by the OS, so the 30s idle timer may not fire reliably.
    // The position stream (kept alive by the Android foreground service /
    // iOS background mode) is the more dependable wake source.
    _checkIdle();
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

  /// Fired every 30s. If the device hasn't genuinely moved for
  /// [_idleTimeout] (measured on the wall clock), auto-stop the trip.
  /// The idle tail is trimmed: distance/waypoints are clipped to the last
  /// moving position, and `ended_at` is set to that position's timestamp.
  void _checkIdle() {
    if (!isTracking) return;
    final lastMove = _lastMovementWallTime;
    if (lastMove == null) return;
    final idleDuration = DateTime.now().difference(lastMove);
    if (idleDuration >= _idleTimeout) {
      _performAutoStop();
    }
  }

  /// Public hook so the host screen can force an idle evaluation right
  /// when the app returns to the foreground.
  ///
  /// Why this matters: while the app is backgrounded with the screen off
  /// AND the device is stationary, no new GPS fixes arrive (distanceFilter)
  /// and the OS can suspend our periodic timer — so the scheduled idle
  /// check may not run. Calling this on resume guarantees that a trip
  /// which crossed the idle threshold while we were asleep gets stopped
  /// immediately, with `ended_at` correctly backdated to the last
  /// movement (the idle tail is never counted).
  void checkIdleNow() => _checkIdle();

  Future<void> _performAutoStop() async {
    if (!isTracking) return;

    // Cancel streams immediately.
    _positionSub?.cancel();
    _positionSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _idleCheckTimer?.cancel();
    _idleCheckTimer = null;

    // Flush remaining waypoints.
    await _flushWaypoints();

    // Clip to the last genuine movement: only count positions up to
    // [_lastMovingPositionCount]. Everything after that is the idle tail.
    final clipCount = _lastMovingPositionCount > 0
        ? _lastMovingPositionCount.clamp(0, _positions.length)
        : _positions.length;

    double clippedDistance = 0;
    for (int i = 1; i < clipCount; i++) {
      clippedDistance += Geolocator.distanceBetween(
        _positions[i - 1].latitude,
        _positions[i - 1].longitude,
        _positions[i].latitude,
        _positions[i].longitude,
      );
    }

    // ended_at = wall-clock time of the last genuine movement (idle tail
    // excluded). This is consistent with how `started_at` is recorded
    // (DateTime.now()), so the saved duration is correct regardless of
    // any GPS-timestamp clock quirks.
    final DateTime cutoffTime =
        _lastMovementWallTime ?? DateTime.now().subtract(_idleTimeout);

    final clippedWaypointCount = clipCount;

    // Validity check on the *clipped* trip, not the raw stream — kalau
    // user start → langsung idle 30 menit tanpa pernah bergerak,
    // rekamannya invalid dan harus dibuang.
    final clippedDuration =
        cutoffTime.difference(_activeTrip!.startedAt);
    final discardReason = _validateTrip(
      duration: clippedDuration,
      distanceMeters: clippedDistance,
      waypointCount: clippedWaypointCount,
    );

    if (discardReason != TripDiscardReason.none) {
      try {
        await _repo.discardTrip(_activeTrip!.id);
      } catch (_) {
        // Best-effort: kalau delete gagal, biarkan row jadi "completed
        // with tiny distance". Lebih baik daripada zombie active trip.
        try {
          await _repo.endTrip(
            tripId: _activeTrip!.id,
            distanceKm: clippedDistance / 1000.0,
            endedAt: cutoffTime,
          );
        } catch (_) {}
      }
      _activeTrip = null;
      _autoStopped = true;
      notifyListeners();
      onAutoStopped?.call(TripStopResult.discarded(discardReason));
      return;
    }

    try {
      final ended = await _repo.endTrip(
        tripId: _activeTrip!.id,
        distanceKm: clippedDistance / 1000.0,
        endedAt: cutoffTime,
      );
      _activeTrip = ended;
      _autoStopped = true;
      notifyListeners();
      // Best-effort notify the user — they may have the phone in pocket
      // and never see the in-app dialog otherwise.
      try {
        await NotificationService.instance.notifyAutoStop(trip: ended);
      } catch (_) {
        // Non-fatal: notif gagal != trip teardown gagal.
      }
      onAutoStopped?.call(TripStopResult.saved(ended));
    } catch (_) {
      // If DB update fails, trip stays "active" — user can manually stop
      // next time they open the app.
    }
  }

  /// Stops tracking, flushes all waypoints, ends trip in Supabase.
  ///
  /// Kalau rekaman tidak lulus validity check (terlalu pendek / kosong /
  /// salah pencet), trip dibuang dari DB dan hasilnya
  /// [TripStopResult.discarded] supaya UI bisa kasih dialog yang sesuai.
  Future<TripStopResult?> stopTrip() async {
    if (!isTracking) return null;

    _positionSub?.cancel();
    _positionSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _idleCheckTimer?.cancel();
    _idleCheckTimer = null;

    // Flush remaining waypoints
    await _flushWaypoints();

    final tripId = _activeTrip!.id;
    final startedAt = _activeTrip!.startedAt;
    final now = DateTime.now();
    final discardReason = _validateTrip(
      duration: now.difference(startedAt),
      distanceMeters: _distanceMeters,
      waypointCount: _positions.length,
    );

    if (discardReason != TripDiscardReason.none) {
      try {
        await _repo.discardTrip(tripId);
      } catch (_) {
        // Fallback: kalau delete gagal (network), tetap close supaya
        // trip tidak nyangkut active. Distance & ended_at di-set;
        // history akan tampil tapi kontribusinya minim.
        try {
          await _repo.endTrip(
            tripId: tripId,
            distanceKm: distanceKm,
            endedAt: now,
          );
        } catch (_) {}
      }
      _activeTrip = null;
      notifyListeners();
      return TripStopResult.discarded(discardReason);
    }

    final ended = await _repo.endTrip(
      tripId: tripId,
      distanceKm: distanceKm,
    );

    _activeTrip = ended;
    notifyListeners();
    return TripStopResult.saved(ended);
  }

  /// Centralized validity rule. Returns [TripDiscardReason.none] if
  /// the trip should be persisted, otherwise the reason it should be
  /// thrown away.
  TripDiscardReason _validateTrip({
    required Duration duration,
    required double distanceMeters,
    required int waypointCount,
  }) {
    if (duration < _minValidDuration) {
      return TripDiscardReason.tooShortDuration;
    }
    if (distanceMeters < _minValidDistanceMeters) {
      return TripDiscardReason.tooShortDistance;
    }
    if (waypointCount < _minValidWaypointCount) {
      return TripDiscardReason.tooFewWaypoints;
    }
    return TripDiscardReason.none;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _flushTimer?.cancel();
    _idleCheckTimer?.cancel();
    super.dispose();
  }
}
