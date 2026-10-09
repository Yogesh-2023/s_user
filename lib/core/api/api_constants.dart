class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = 'https://tuk.technogigz.co.in';
  static const Duration connectTimeout = Duration(seconds: 30);

  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
}
