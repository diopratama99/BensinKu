class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String? supabaseUrl;
  final String? supabaseAnonKey;

  bool get hasSupabase =>
      (supabaseUrl != null && supabaseUrl!.trim().isNotEmpty) &&
      (supabaseAnonKey != null && supabaseAnonKey!.trim().isNotEmpty);

  factory AppConfig.fromEnv() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return AppConfig(
      supabaseUrl: url.trim().isEmpty ? null : url.trim(),
      supabaseAnonKey: anonKey.trim().isEmpty ? null : anonKey.trim(),
    );
  }
}
