class SupabaseConfig {
  // Read values from build-time environment so keys are not committed.
  // Usage: pass values with `--dart-define=SUPABASE_URL=...` and
  // `--dart-define=SUPABASE_API_KEY=...` when running or building.
  // Defaults to the project host if SUPABASE_URL is not provided.
  static const String baseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://agrzjwnsapbanbvgbwkh.supabase.co',
  );

  // Use the project's publishable key in the client. Do NOT place a
  // service-role key here. The fallback keeps manually built APKs connected;
  // CI/CD can still override it with `--dart-define=SUPABASE_API_KEY=...`.
  static const String apiKey = String.fromEnvironment(
    'SUPABASE_API_KEY',
    defaultValue: 'sb_publishable_jrJRXGYEYpixwOAUS6kIWA_ccT4jZs6',
  );

  // Optional key for the Supabase Edge Function proxy (`functions/v1/api`).
  // This is the APP_API_KEY configured in Supabase Functions, not the public
  // anon/publishable key. When present, the app routes Supabase REST calls
  // through the function so admin/mentor writes can be performed server-side
  // without exposing the service-role key in Flutter.
  static const String appKey = String.fromEnvironment(
    'SUPABASE_APP_KEY',
    defaultValue: '',
  );

  static bool get useFunctionProxy => appKey.isNotEmpty;

  // Optional admin proxy URL. If provided at build time (for example
  // `--dart-define=ADMIN_PROXY_URL=http://localhost:4000`) certain
  // admin operations (create/update/delete users, assign courses) will
  // be routed to this server instead of calling Supabase directly. This
  // keeps the `service_role` key off the client.
  static const String adminProxyUrl = String.fromEnvironment(
    'ADMIN_PROXY_URL',
    defaultValue: 'http://localhost:4000',
  );
}
