import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:get/get.dart';

import 'api_constants.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'api_status_code.dart';
import '../../features/notifications/controllers/notification_controller.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<Map<String, String>> authHeaders({
    bool includeContentType = true,
  }) async {
    String? cookie;
    String? token;
    try {
      cookie = await _secureStorage.read(key: 'session_cookie');
      token = await _secureStorage.read(key: 'auth_token');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    if (cookie == null || cookie.isEmpty) {
      cookie = prefs.getString('session_cookie');
    }
    if (token == null || token.isEmpty) {
      token = prefs.getString('auth_token');
    }
    String? csrfToken;
    try {
      csrfToken = await _secureStorage.read(key: 'csrf_token');
    } catch (_) {}
    if (csrfToken == null || csrfToken.isEmpty) {
      csrfToken = prefs.getString('csrf_token');
    }

    return {
      'Accept': 'application/json',
      if (includeContentType) 'Content-Type': 'application/json',
      if (cookie != null && cookie.isNotEmpty)
        'Cookie': cookie
      else if (token != null && token.isNotEmpty)
        'Cookie': 'session=$token; better-auth.session_token=$token',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (csrfToken != null && csrfToken.isNotEmpty) 'x-csrf-token': csrfToken,
    };
  }

  static Future<String?> readAuthToken() async {
    String? token;
    try {
      token = await _secureStorage.read(key: 'auth_token');
    } catch (_) {}
    if (token != null && token.isNotEmpty) return token;

    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    return token == null || token.isEmpty ? null : token;
  }

  static Future<bool> hasSession() async {
    final headers = await authHeaders(includeContentType: false);
    return headers.containsKey('Cookie') ||
        headers.containsKey('Authorization');
  }

  static Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: 'session_cookie');
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'csrf_token');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    await prefs.remove('auth_token');
    await prefs.remove('csrf_token');
    await prefs.remove('profile_complete');
    await prefs.remove('user_id');
    await prefs.remove('user_phone');
    await prefs.remove('user_name');

    if (Get.isRegistered<NotificationController>()) {
      await NotificationController.to.resetState();
    }
  }

  Future<Map<String, String>> _getMergedHeaders(
    Map<String, String>? customHeaders,
  ) async {
    final auth = await authHeaders();
    return {
      ...ApiConstants.defaultHeaders,
      ...auth,
      if (customHeaders != null) ...customHeaders,
    };
  }

  Future<ApiResponse<dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final mergedHeaders = await _getMergedHeaders(headers);
    await _ensureNetwork(uri);

    print('[YOGESH][BOOKING_STATUS_API]');
    print('[YOGESH][BOOKING_STATUS_API] URL= $uri');
    print('[YOGESH][BOOKING_STATUS_API] request started');

    try {
      print('=== API GET REQUEST ===');
      print('URI: $uri');
      final response = await _client
          .get(uri, headers: mergedHeaders)
          .timeout(ApiConstants.connectTimeout);

      print('[YOGESH][BOOKING_STATUS_API] HTTP status= ${response.statusCode}');
      print('[YOGESH][BOOKING_STATUS_API] response= ${response.body}');

      return await _handleResponse(response);
    } on TimeoutException catch (e) {
      print('[YOGESH][BOOKING_STATUS_API] timeout= true');
      throw ApiException(
        url: uri.toString(),
        message: 'Request timeout: ${e.message ?? 'Server response timed out'}',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      print('[YOGESH][BOOKING_STATUS_API] connection error= ${error.message}');
      print('[YOGESH][BOOKING_STATUS_API] exception type= http.ClientException');
      throw ApiException(
        url: uri.toString(),
        message: 'HTTP client error: ${error.message}',
        statusCode: 0,
      );
    } catch (error) {
      print('[YOGESH][BOOKING_STATUS_API] exception type= ${error.runtimeType}');
      print('[YOGESH][BOOKING_STATUS_API] exception message= $error');
      if (error is ApiException) rethrow;
      throw ApiException(
        url: uri.toString(),
        message: 'Connection exception: ${error.toString()}',
        statusCode: 0,
      );
    }
  }

  Future<ApiResponse<dynamic>> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final uri = _buildUri(endpoint, null);
    final mergedHeaders = await _getMergedHeaders(headers);
    await _ensureNetwork(uri);

    try {
      print('=== API POST REQUEST ===');
      print('URI: $uri');
      if (body != null) print('Body: ${jsonEncode(body)}');

      final response = await _client
          .post(
            uri,
            headers: mergedHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectTimeout);

      return await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        url: uri.toString(),
        message: 'Request timeout. Please try again.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        url: uri.toString(),
        message: error.message,
        statusCode: 0,
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        url: uri.toString(),
        message: error.toString(),
        statusCode: 0,
      );
    }
  }

  Future<ApiResponse<dynamic>> patch(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final uri = _buildUri(endpoint, null);
    final mergedHeaders = await _getMergedHeaders(headers);
    await _ensureNetwork(uri);

    try {
      print('=== API PATCH REQUEST ===');
      print('URI: $uri');
      if (body != null) print('Body: ${jsonEncode(body)}');

      final response = await _client
          .patch(
            uri,
            headers: mergedHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectTimeout);

      return await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        url: uri.toString(),
        message: 'Request timeout. Please try again.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        url: uri.toString(),
        message: error.message,
        statusCode: 0,
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        url: uri.toString(),
        message: error.toString(),
        statusCode: 0,
      );
    }
  }

  Future<ApiResponse<dynamic>> put(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final uri = _buildUri(endpoint, null);
    final mergedHeaders = await _getMergedHeaders(headers);
    await _ensureNetwork(uri);

    try {
      print('=== API PUT REQUEST ===');
      print('URI: $uri');
      if (body != null) print('Body: ${jsonEncode(body)}');

      final response = await _client
          .put(
            uri,
            headers: mergedHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectTimeout);

      return await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        url: uri.toString(),
        message: 'Request timeout. Please try again.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        url: uri.toString(),
        message: error.message,
        statusCode: 0,
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        url: uri.toString(),
        message: error.toString(),
        statusCode: 0,
      );
    }
  }

  Future<ApiResponse<dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final mergedHeaders = await _getMergedHeaders(headers);
    await _ensureNetwork(uri);

    try {
      print('=== API DELETE REQUEST ===');
      print('URI: $uri');
      if (body != null) print('Body: ${jsonEncode(body)}');

      final response = await _client
          .delete(
            uri,
            headers: mergedHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectTimeout);

      return await _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        url: uri.toString(),
        message: 'Request timeout. Please try again.',
        statusCode: 408,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        url: uri.toString(),
        message: error.message,
        statusCode: 0,
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        url: uri.toString(),
        message: error.toString(),
        statusCode: 0,
      );
    }
  }

  Uri _buildUri(String endpoint, Map<String, dynamic>? queryParameters) {
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';
    final uri = Uri.parse('${ApiConstants.baseUrl}$normalizedEndpoint');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final sanitizedQuery = queryParameters.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return uri.replace(queryParameters: sanitizedQuery);
  }

  Future<void> _ensureNetwork(Uri uri) async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        debugPrint('[YOGESH][BOOKING_STATUS_API] Connectivity status check returned none/empty. Proceeding with actual HTTP attempt for $uri');
      }
    } catch (e) {
      debugPrint('[YOGESH][BOOKING_STATUS_API] Connectivity check error: $e');
    }
  }

  Future<ApiResponse<dynamic>> _handleResponse(http.Response response) async {
    await _updateCookie(response);
    final body = _decodeBody(response.body);
    await _updateCsrfToken(response, body);

    final urlStr = response.request?.url.toString() ?? 'unknown_url';

    final methodStr = response.request?.method ?? 'UNKNOWN';

    if (ApiStatusCode.isSuccess(response.statusCode)) {
      await _persistTokenFromBody(body);
      print('=== API $methodStr RESPONSE ===');
      print('URI: $urlStr');
      print('Status Code: ${response.statusCode}');
      _printLongString('Response Body: ${response.body}');
      return ApiResponse<dynamic>(
        data: body,
        statusCode: response.statusCode,
        message: _successMessage(response.statusCode),
      );
    }

    print('=== API $methodStr ERROR ===');
    print('URI: $urlStr');
    print('Status Code: ${response.statusCode}');
    _printLongString('Response Body: ${response.body}');

    throw ApiException(
      url: urlStr,
      message: _errorMessage(response.statusCode, body),
      statusCode: response.statusCode,
      responseBody: body,
    );
  }

  Future<void> _persistTokenFromBody(dynamic body) async {
    if (body is! Map) return;
    final payload = body['data'] is Map ? body['data'] as Map : body;
    final session = payload['session'] is Map
        ? payload['session'] as Map
        : null;
    final token =
        (payload['accessToken'] ??
                payload['sessionToken'] ??
                payload['token'] ??
                session?['token'])
            ?.toString();
    if (token == null || token.isEmpty) return;
    try {
      await _secureStorage.write(key: 'auth_token', value: token);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _updateCookie(http.Response response) async {
    final rawCookie =
        response.headers['set-cookie'] ?? response.headers['Set-Cookie'];
    if (rawCookie != null && rawCookie.isNotEmpty) {
      final matches = RegExp(
        r'(?:^|,\s*)([^=;,\s]+)=([^;,\s]+)',
      ).allMatches(rawCookie).toList();
      final authCookies = matches.where((item) {
        final name = item.group(1)?.toLowerCase() ?? '';
        return name.contains('session') ||
            name.contains('csrf') ||
            name.contains('auth') ||
            name.contains('token');
      }).toList();
      if (authCookies.isEmpty) return;

      final cookieStr = authCookies
          .map((item) => '${item.group(1)}=${item.group(2)}')
          .join('; ');
      final sessionMatch = authCookies.cast<RegExpMatch?>().firstWhere(
        (item) => item?.group(1)?.toLowerCase().contains('session') == true,
        orElse: () => null,
      );
      final sessionToken = sessionMatch?.group(2);
      try {
        await _secureStorage.write(key: 'session_cookie', value: cookieStr);
        if (sessionToken != null && sessionToken.isNotEmpty) {
          await _secureStorage.write(key: 'auth_token', value: sessionToken);
        }
      } catch (_) {}
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', cookieStr);
      if (sessionToken != null && sessionToken.isNotEmpty) {
        await prefs.setString('auth_token', sessionToken);
      }
    }
  }

  Future<void> _updateCsrfToken(http.Response response, dynamic body) async {
    final payload = body is Map && body['data'] is Map
        ? body['data'] as Map
        : body is Map
        ? body
        : null;
    final token = (response.headers['x-csrf-token'] ?? payload?['csrfToken'])
        ?.toString();
    if (token == null || token.isEmpty) return;
    try {
      await _secureStorage.write(key: 'csrf_token', value: token);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('csrf_token', token);
    }
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  void _printLongString(String text) {
    final pattern = RegExp('.{1,800}'); // 800 is a safe chunk size for print
    for (final match in pattern.allMatches(text)) {
      print(match.group(0));
    }
  }

  String _successMessage(int statusCode) {
    switch (statusCode) {
      case ApiStatusCode.ok:
        return 'Request completed successfully.';
      case ApiStatusCode.created:
        return 'Resource created successfully.';
      case ApiStatusCode.noContent:
        return 'Request completed with no content.';
      default:
        return 'Request successful.';
    }
  }

  String _errorMessage(int statusCode, dynamic body) {
    if (statusCode >= 500) {
      return 'Something went wrong. Please try again later.';
    }

    final serverMessage = _extractServerMessage(body);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      if (_isTechnicalError(serverMessage, body)) {
        return 'Something went wrong. Please try again later.';
      }
      return serverMessage;
    }

    switch (statusCode) {
      case ApiStatusCode.badRequest:
        return 'Invalid request. Please check your details.';
      case ApiStatusCode.unauthorized:
        return 'Session expired. Please login again.';
      case ApiStatusCode.forbidden:
        return 'You do not have permission to perform this action.';
      case ApiStatusCode.notFound:
        return 'Requested data was not found.';
      case ApiStatusCode.conflict:
        return 'This request conflicts with existing data.';
      case ApiStatusCode.validationError:
        return 'Please check the submitted details.';
      case ApiStatusCode.serverError:
      case ApiStatusCode.badGateway:
      case ApiStatusCode.serviceUnavailable:
        return 'Server is unavailable. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  bool _isTechnicalError(String msg, dynamic body) {
    final lower = msg.toLowerCase();
    if (lower.contains('prisma') ||
        lower.contains('p20') ||
        lower.contains('sql') ||
        lower.contains('database') ||
        lower.contains('error fetching') ||
        lower.contains('exception') ||
        lower.contains('column') ||
        lower.contains('syntaxerror')) {
      return true;
    }
    if (body is Map<String, dynamic> && body['code'] != null) {
      final codeStr = body['code'].toString().toUpperCase();
      if (codeStr.startsWith('P20') || codeStr.startsWith('ERR_')) {
        return true;
      }
    }
    return false;
  }

  String? _extractServerMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final errorObj = body['error'];
      final details = (errorObj is Map<String, dynamic> ? errorObj['details'] : null) ?? body['details'];
      if (details is Map<String, dynamic>) {
        final fieldErrors = details['fieldErrors'];
        if (fieldErrors is Map<String, dynamic>) {
          final messages = <String>[];
          fieldErrors.forEach((key, val) {
            if (val is List && val.isNotEmpty) {
              messages.add(val.first.toString());
            } else if (val is String && val.isNotEmpty) {
              messages.add(val);
            }
          });
          if (messages.isNotEmpty) {
            return messages.join(', ');
          }
        }
        final formErrors = details['formErrors'];
        if (formErrors is List && formErrors.isNotEmpty) {
          return formErrors.map((e) => e.toString()).join(', ');
        }
      }

      if (errorObj is Map<String, dynamic> && errorObj['message'] is String && errorObj['message'].toString().isNotEmpty) {
        return errorObj['message'].toString();
      }

      final message = body['message'] ?? body['error'] ?? body['detail'];
      if (message is String && message != 'Request validation failed') {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(' | ');
      }
    }

    return null;
  }
}
