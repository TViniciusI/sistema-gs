class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const officeUrl = String.fromEnvironment('OFFICE_URL');
  static const loginGateUrl = String.fromEnvironment(
    'LOGIN_GATE_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbzo6F1Ety_rS3asCvynmFsqSNXzuywc8zpKxqXpi2iOT16ddEGD_GSva1nEfoI82KVTRQ/exec',
  );
  static const loginGateToken = String.fromEnvironment(
    'LOGIN_GATE_TOKEN',
    defaultValue: 'gs-dev-gate-v1',
  );

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
