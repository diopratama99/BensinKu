import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'config/app_config.dart';
import 'services/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  final config = AppConfig.fromEnv();
  final supabaseReady = await SupabaseBootstrap.tryInitialize(config);

  runApp(BensinKuApp(config: config, supabaseReady: supabaseReady));
}
