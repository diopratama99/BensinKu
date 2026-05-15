import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'prediction_service.dart';

/// Pushes data into Android home widget storage and triggers a refresh.
///
/// Backed by the `home_widget` plugin which writes shared preferences
/// readable from `BensinKuWidgetProvider.kt`.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  /// Android-only widget. iOS support would need a separate WidgetKit
  /// extension which is out of scope for now.
  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Compose all widget content from current Supabase state and push it.
  /// Safe to call on every meaningful state change (refuel saved, trip
  /// ended, app resume). Failures are swallowed — widget is best-effort.
  Future<void> refresh() async {
    if (!_isSupported) return;
    try {
      await _refreshInternal();
    } catch (_) {
      // Network/auth failure shouldn't crash callers.
    }
  }

  Future<void> _refreshInternal() async {
    final repo = SupabaseRepository.ofDefaultClient();
    final user = Supabase.instance.client.auth.currentUser;

    final greeting = _composeGreeting(user);
    final dateStr = DateFormat('d.MM.yy', 'id_ID')
        .format(DateTime.now())
        .toUpperCase();
    final footer = await _composeFooter(repo, user);

    await Future.wait([
      HomeWidget.saveWidgetData<String>('widget_greeting', greeting),
      HomeWidget.saveWidgetData<String>('widget_date', dateStr),
      HomeWidget.saveWidgetData<String>('widget_footer', footer),
    ]);

    await HomeWidget.updateWidget(
      androidName: 'BensinKuWidgetProvider',
      qualifiedAndroidName:
          'com.temanlabs.bensinku.BensinKuWidgetProvider',
    );
  }

  String _composeGreeting(User? user) {
    final hour = DateTime.now().hour;
    final timeOfDay = switch (hour) {
      >= 4 && < 11 => 'Selamat Pagi',
      >= 11 && < 15 => 'Selamat Siang',
      >= 15 && < 18 => 'Selamat Sore',
      _ => 'Selamat Malam',
    };

    final raw = user?.userMetadata?['name'];
    var name = raw is String ? raw.trim() : '';
    if (name.isEmpty) {
      final email = user?.email ?? '';
      name = email.contains('@') ? email.split('@').first : 'Pengendara';
    }
    final firstName = name.split(RegExp(r'\s+')).first;
    return '$timeOfDay, $firstName';
  }

  /// Footer summary: total bulan ini + estimasi km/L.
  /// "Mei: Rp 150rb · 5.2 L · 12 km/L"
  Future<String> _composeFooter(
      SupabaseRepository repo, User? user) async {
    if (user == null) return 'Belum ada catatan bulan ini';

    try {
      final vehicles = await repo.listVehicles();
      if (vehicles.isEmpty) return 'Tambah kendaraan dulu';

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthRefuels = await repo.listRefuels(
        from: monthStart,
        toExclusive: DateTime(now.year, now.month + 1, 1),
      );

      if (monthRefuels.isEmpty) {
        return 'Belum ada pengisian bulan ini';
      }

      final totalRp =
          monthRefuels.fold<num>(0, (s, r) => s + r.totalRp);
      final totalLiter =
          monthRefuels.fold<num>(0, (s, r) => s + r.liters);

      final rpStr = _shortRupiah(totalRp.toDouble());
      final monthName =
          DateFormat('MMM', 'id_ID').format(now);

      // Posterior km/L from prediction service for the primary vehicle.
      final firstVehicle = vehicles.first;
      final samples = await repo.recentEfficiencySamples(
        vehicleId: firstVehicle.id,
        limit: 20,
      );
      final meta = user.userMetadata;
      final estimate = PredictionService.posteriorKmPerLiter(
        vehicle: firstVehicle,
        samples: samples,
        usageProfile:
            UsageProfile.tryParse(meta?['usage_profile'] as String?),
        primaryCity:
            PrimaryCity.tryParse(meta?['primary_city'] as String?),
      );

      return '$monthName: $rpStr · ${totalLiter.toStringAsFixed(1)} L · '
          '${estimate.kmPerLiter.toStringAsFixed(0)} km/L';
    } catch (_) {
      return 'Tap untuk lihat ringkasan';
    }
  }

  /// Compact rupiah ("Rp 150rb", "Rp 1,2jt") so it fits in widget footer.
  String _shortRupiah(double v) {
    if (v <= 0) return 'Rp 0';
    if (v >= 1000000) {
      final jt = v / 1000000.0;
      return 'Rp ${jt.toStringAsFixed(jt < 10 ? 1 : 0)}jt';
    }
    if (v >= 1000) {
      final rb = v / 1000.0;
      return 'Rp ${rb.toStringAsFixed(rb < 10 ? 1 : 0)}rb';
    }
    return 'Rp ${v.toStringAsFixed(0)}';
  }
}
