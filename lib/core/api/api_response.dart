class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    required this.statusCode,
    required this.message,
  });

  final T data;
  final int statusCode;
  final String message;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
