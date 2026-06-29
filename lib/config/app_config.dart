class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.googleWebClientId,
    this.googleIosClientId,
  });

  final String? supabaseUrl;
  final String? supabaseAnonKey;

  /// Google "Web" OAuth client ID. Used as `serverClientId` for native
  /// Google Sign-In — the audience the Supabase server verifies against.
  final String? googleWebClientId;

  /// Google "iOS" OAuth client ID. Used as `clientId` on iOS only.
  final String? googleIosClientId;

  bool get hasSupabase =>
      (supabaseUrl != null && supabaseUrl!.trim().isNotEmpty) &&
      (supabaseAnonKey != null && supabaseAnonKey!.trim().isNotEmpty);

  /// Google sign-in is only offered when the web client id is configured.
  bool get hasGoogleSignIn =>
      googleWebClientId != null && googleWebClientId!.trim().isNotEmpty;

  factory AppConfig.fromEnv() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const googleWeb = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    const googleIos = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

    String? clean(String v) => v.trim().isEmpty ? null : v.trim();

    return AppConfig(
      supabaseUrl: clean(url),
      supabaseAnonKey: clean(anonKey),
      googleWebClientId: clean(googleWeb),
      googleIosClientId: clean(googleIos),
    );
  }
}
