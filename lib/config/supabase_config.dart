/// Supabase configuration for El Shayeb Online (الشايب أونلاين).
///
/// Supports runtime overrides via `--dart-define=SUPABASE_URL=...` and
/// `--dart-define=SUPABASE_ANON_KEY=...`, with safe defaults pointing to
/// the production Supabase instance provided for this project.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lzmpwjfgrtlypticedic.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_xYJ1BQgVUUiEVmLvcE3q2Q_hmmRTBxX',
  );

  /// Toggle for local development against Supabase local CLI (`supabase start`)
  static const bool useLocal = bool.fromEnvironment(
    'USE_LOCAL_SUPABASE',
    defaultValue: false,
  );

  /// Default local gateway host (e.g., 10.0.2.2 for Android emulator, 127.0.0.1 for desktop/web)
  static const String localHost = String.fromEnvironment(
    'LOCAL_SUPABASE_HOST',
    defaultValue: '127.0.0.1',
  );

  static String get activeUrl =>
      useLocal ? 'http://$localHost:54321' : supabaseUrl;

  static String get activeAnonKey => supabaseAnonKey;
}
