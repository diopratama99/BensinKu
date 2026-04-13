import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseBootstrap {
  static Future<bool> tryInitialize(AppConfig config) async {
    if (!config.hasSupabase) return false;

    try {
      await Supabase.initialize(
        url: config.supabaseUrl!,
        anonKey: config.supabaseAnonKey!,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
