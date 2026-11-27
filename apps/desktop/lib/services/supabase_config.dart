/// Compile-time Supabase connection settings.
///
/// Only the public project URL and the public anon key are supported here.
/// Service-role keys, JWT secrets and database passwords must never be
/// compiled into the desktop app.
class SupabaseConfig {
  SupabaseConfig({
    required String url,
    required this.anonKey,
    this.timeout = const Duration(seconds: 20),
  }) : baseUrl = _normalize(url) {
    if (anonKey.trim().isEmpty) {
      throw ArgumentError.value(anonKey, 'anonKey', 'must not be empty');
    }
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
  }

  final Uri baseUrl;
  final String anonKey;
  final Duration timeout;

  static SupabaseConfig? fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.trim().isEmpty || anonKey.trim().isEmpty) return null;
    return SupabaseConfig(url: url, anonKey: anonKey);
  }

  static Uri _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'url', 'must not be empty');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw ArgumentError.value(value, 'url', 'must be an http(s) URL');
    }
    return Uri.parse(trimmed.replaceAll(RegExp(r'/+$'), ''));
  }

  @override
  String toString() => 'SupabaseConfig(${baseUrl.toString()})';
}
