class ApiStatusCode {
  const ApiStatusCode._();

  static const int ok = 200;
  static const int created = 201;
  static const int accepted = 202;
  static const int noContent = 204;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int validationError = 422;
  static const int serverError = 500;
  static const int badGateway = 502;
  static const int serviceUnavailable = 503;

  static bool isSuccess(int statusCode) {
    return statusCode >= ok && statusCode < 300;
  }
}
