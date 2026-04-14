import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'config/app_config.dart';
import 'services/supabase_bootstrap.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Pertahankan splash screen sampai app siap
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Status bar: icons gelap agar terlihat di background terang
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS
    ),
  );

  await initializeDateFormatting('id_ID', null);

  final config = AppConfig.fromEnv();
  final supabaseReady = await SupabaseBootstrap.tryInitialize(config);

  // Semua init selesai → hapus splash
  FlutterNativeSplash.remove();

  runApp(BensinKuApp(config: config, supabaseReady: supabaseReady));
}
