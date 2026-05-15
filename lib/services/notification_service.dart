import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/models.dart';

/// Thin wrapper around `flutter_local_notifications` for the few moments
/// BensinKu wants to interrupt the user system-side. Currently used only
/// for the trip auto-stop event so the user knows their trip ended even
/// if the app is in background / phone in pocket.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _tripChannelId = 'trip_events';
  static const String _tripChannelName = 'Perjalanan';
  static const String _tripChannelDesc =
      'Pemberitahuan saat perjalanan otomatis dihentikan atau perubahan '
      'status tracking GPS.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    // Best-effort permission request. On Android 13+ requires runtime
    // grant; older versions will return true silently.
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();

        // Pre-create channel so the system shows it in app settings.
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _tripChannelId,
            _tripChannelName,
            description: _tripChannelDesc,
            importance: Importance.high,
          ),
        );
      } else if (!kIsWeb && Platform.isIOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {
      // Permission flow can throw on first run if the user denies. Not
      // fatal — notifications just won't appear, the rest of the app
      // works fine.
    }

    _initialized = true;
  }

  /// Show a notification telling the user that their trip was
  /// auto-stopped after 30 minutes of inactivity.
  Future<void> notifyAutoStop({required Trip trip}) async {
    if (!_initialized) await init();

    final distanceKm = trip.distanceKm ?? 0;
    final distText = distanceKm < 1
        ? '${(distanceKm * 1000).toStringAsFixed(0)} m'
        : '${distanceKm.toStringAsFixed(2)} km';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _tripChannelId,
        _tripChannelName,
        channelDescription: _tripChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
        ticker: 'Trip dihentikan otomatis',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      _autoStopNotificationId,
      'Trip dihentikan otomatis',
      '$distText tercatat. Buka BensinKu untuk lihat detail.',
      details,
    );
  }

  /// Stable id so subsequent auto-stops replace the previous notif
  /// instead of stacking.
  static const int _autoStopNotificationId = 1001;
}
