class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
    this.url,
    this.responseBody,
  });

  final String message;
  final int statusCode;
  final String? url;
  final dynamic responseBody;

  @override
  String toString() {
    final urlText = (url != null && url!.isNotEmpty) ? ' [URL: $url]' : '';
    final bodyText = responseBody != null ? ' [Response: $responseBody]' : '';
    return 'ApiException($statusCode)$urlText: $message$bodyText';
  }
}
