import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_service.dart';
import '../core/api/api_endpoints.dart';

class NotificationApiService {
  static final ApiService _api = ApiService.to;

  static Future<Map<String, dynamic>> fetchNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
    String? from,
    String? to,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null) queryParams['type'] = type;
    if (isRead != null) queryParams['isRead'] = isRead;
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;

    final response = await _api.get(
      ApiEndpoints.notifications,
      queryParameters: queryParams,
    );
    return _map(response.data);
  }

  static Future<Map<String, dynamic>> fetchNotificationDetail(String id) async {
    final response = await _api.get(ApiEndpoints.notificationDetail(id));
    return _map(response.data);
  }

  static Future<int> fetchUnreadCount() async {
    final response = await _api.get(ApiEndpoints.unreadNotificationCount);
    final data = _map(response.data);
    final rawCount = data['count'] ??
        data['unreadCount'] ??
        data['unread_count'] ??
        (response.data is Map
            ? (response.data['unreadCount'] ??
                response.data['count'] ??
                response.data['unread_count'])
            : null);
    if (rawCount is int) return rawCount;
    if (rawCount is num) return rawCount.toInt();
    if (rawCount is String) return int.tryParse(rawCount) ?? 0;
    return 0;
  }

  static Future<bool> markAsRead(String id) async {
    final response = await _api.patch(ApiEndpoints.markNotificationRead(id));
    return response.statusCode == 200;
  }

  static Future<bool> markAsUnread(String id) async {
    return false;
  }

  static Future<bool> markAllAsRead() async {
    final response = await _api.patch(ApiEndpoints.markAllNotificationsRead);
    return response.statusCode == 200;
  }

  static Future<bool> deleteNotification(String id) async {
    final response = await _api.delete(ApiEndpoints.notificationDetail(id));
    return response.statusCode == 200;
  }

  static Future<bool> clearReadNotifications() async {
    return false;
  }

  static Future<Map<String, dynamic>> fetchPreferences() async {
    final response = await _api.get(ApiEndpoints.notificationPreferences);
    return _map(response.data);
  }

  static Future<bool> updatePreferences(Map<String, dynamic> data) async {
    final response = await _api.patch(
      ApiEndpoints.notificationPreferences,
      body: data,
    );
    return response.statusCode == 200;
  }

  static Future<void> registerToken(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['platform'] = (payload['platform'] ?? 'ANDROID')
        .toString()
        .toUpperCase();
    final response = await _api.post(ApiEndpoints.registerToken, body: payload);
    final result = _map(response.data);
    final id = result['id'] ?? result['deviceTokenId'];
    if (id != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_token_id', id.toString());
    }
  }

  static Future<void> updateToken(Map<String, dynamic> data) async {
    await registerToken(data);
  }

  static Future<void> deleteToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('device_token_id');
    if (id != null && id.isNotEmpty)
      await _api.delete(ApiEndpoints.deviceToken(id));
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    final data = value['data'] is Map ? value['data'] : value;
    return Map<String, dynamic>.from(data);
  }
}
