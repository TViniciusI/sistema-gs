class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const officeUrl = String.fromEnvironment('OFFICE_URL');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static List<String> get officeUrls {
    if (officeUrl.isNotEmpty) return [officeUrl];
    return const [
      'http://127.0.0.1:3000',
      'http://localhost:3000',
      'http://10.0.2.2:3000',
    ];
  }
}
