class ApiConfig {
  static const String baseUrl =
      String.fromEnvironment('MOTCHILL_PUBLIC_API_BASE_URL', defaultValue: 'https://motchilltv.taxi');
  static const Duration requestTimeout = Duration(seconds: 20);

  static Map<String, String> headers() {
    return const {
      'User-Agent': 'Mozilla/5.0 (MotchillApiBase)',
      'Accept': 'application/json,text/plain,*/*',
    };
  }
}
