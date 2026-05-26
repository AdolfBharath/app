import '../utils/supabase_config.dart';

class ApiConfig {
  static String get baseUrl {
    final base = SupabaseConfig.baseUrl.endsWith('/')
        ? SupabaseConfig.baseUrl.substring(0, SupabaseConfig.baseUrl.length - 1)
        : SupabaseConfig.baseUrl;
    if (SupabaseConfig.useFunctionProxy) {
      return '$base/functions/v1/api/rest/v1';
    }
    return '$base/rest/v1';
  }

  static Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    // Ensure path starts with a slash if not provided, but don't double slash
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(queryParameters: queryParameters);
  }
}
