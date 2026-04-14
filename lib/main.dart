import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'config/app_config.dart';
import 'services/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(BensinKuApp(config: config, supabaseReady: supabaseReady));
}
