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

  static const String _maintChannelId = 'maintenance_reminders';
  static const String _maintChannelName = 'Perawatan';
  static const String _maintChannelDesc =
      'Pengingat jadwal perawatan kendaraan (ganti oli, servis, dll).';

  /// Prefix payload yang dipakai untuk auto-stop notif. Format:
  ///   `auto_stop:<trip_id>`
  /// Dipakai oleh UI (lewat [consumePendingTripDetail]) untuk navigate
  /// ke `TripDetailPage` saat user tap notif, alih-alih jatuh ke flow
  /// generic launch yang malah mulai trip baru.
  static const String _autoStopPayloadPrefix = 'auto_stop:';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Trip-id yang menunggu di-handle oleh UI (di-set saat user tap notif
  /// auto-stop). Konsume sekali pakai lewat [consumePendingTripDetail].
  ///
  /// Pola sengaja sama dengan `WidgetLaunchIntent`: notif callback bisa
  /// fire kapan saja (cold launch, warm resume) tapi UI hanya siap
  /// navigate setelah widget tree-nya mounted. Cache di sini sampai UI
  /// ambil.
  static String? _pendingTripDetailId;

  /// Ambil + reset pending trip-id yang harus di-buka detail-nya. Kalau
  /// tidak ada, return null.
  static String? consumePendingTripDetail() {
    final v = _pendingTripDetailId;
    _pendingTripDetailId = null;
    return v;
  }

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
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Cek apakah app baru saja di-cold-launch lewat tap notif. Tanpa
    // ini, payload dari notif yang user tap saat app belum running akan
    // hilang.
    try {
      final launchDetails =
          await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final payload = launchDetails?.notificationResponse?.payload;
        _handlePayload(payload);
      }
    } catch (_) {
      // Non-fatal: lewat saja, app jalan normal tanpa deeplink.
    }

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
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _maintChannelId,
            _maintChannelName,
            description: _maintChannelDesc,
            importance: Importance.defaultImportance,
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
      '$distText tercatat. Tap untuk lihat detail.',
      details,
      payload: '$_autoStopPayloadPrefix${trip.id}',
    );
  }

  /// Stable id so subsequent auto-stops replace the previous notif
  /// instead of stacking.
  static const int _autoStopNotificationId = 1001;

  /// Show reminders for maintenance items that are overdue or due within
  /// the next 7 days. Best-effort, fire-and-forget; called on app open.
  ///
  /// Uses a stable id per item (derived from the item id hash) so a given
  /// item's reminder replaces its previous one instead of stacking. We
  /// only surface the most urgent few to avoid spamming.
  Future<void> notifyMaintenanceDue(List<MaintenanceItem> items) async {
    if (!_initialized) await init();

    final due = items
        .where((m) => m.isOverdue || m.isDueSoon)
        .toList()
      ..sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));
    if (due.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _maintChannelId,
        _maintChannelName,
        channelDescription: _maintChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
      ),
    );

    // Cap at 3 most-urgent reminders.
    for (final m in due.take(3)) {
      final title = m.isOverdue
          ? '${m.title} sudah lewat jadwal'
          : '${m.title} sebentar lagi';
      final body = m.isOverdue
          ? 'Terlewat ${m.daysUntilDue.abs()} hari. Cek tab Perawatan.'
          : 'Jatuh tempo ${m.daysUntilDue} hari lagi. Cek tab Perawatan.';
      await _plugin.show(
        _maintBaseId + (m.id.hashCode & 0xffff),
        title,
        body,
        details,
      );
    }
  }

  /// Base id offset for maintenance notifications so they don't collide
  /// with the trip auto-stop id.
  static const int _maintBaseId = 2000;
}

/// Top-level callback wajib top-level / static — plugin tidak terima
/// closure yang capture `this`. Cuma extract trip-id dari payload dan
/// simpan ke static cache untuk di-konsume UI saat resume.
@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  _handlePayload(response.payload);
}

void _handlePayload(String? payload) {
  if (payload == null || payload.isEmpty) return;
  const prefix = NotificationService._autoStopPayloadPrefix;
  if (payload.startsWith(prefix)) {
    NotificationService._pendingTripDetailId =
        payload.substring(prefix.length);
  }
}
