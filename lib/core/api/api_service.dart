import 'package:get/get.dart';

import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

class ApiService extends GetxService {
  ApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static ApiService get to {
    try {
      return Get.find<ApiService>();
    } catch (e) {
      return Get.put(ApiService(), permanent: true);
    }
  }

  static const String baseUrl = ApiConstants.baseUrl;

  Future<ApiResponse<dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) {
    return _client.get(
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse<dynamic>> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) {
    return _client.post(endpoint, headers: headers, body: body);
  }

  Future<ApiResponse<dynamic>> patch(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) {
    return _client.patch(endpoint, headers: headers, body: body);
  }

  Future<ApiResponse<dynamic>> put(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) {
    return _client.put(endpoint, headers: headers, body: body);
  }

  Future<ApiResponse<dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic body,
  }) {
    return _client.delete(
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
      body: body,
    );
  }
}
