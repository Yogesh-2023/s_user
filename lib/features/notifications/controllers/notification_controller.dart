import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/notification_api_service.dart';
import '../../../core/api/api_exception.dart';

class NotificationController extends GetxController {
  static NotificationController get to => Get.find<NotificationController>();

  var notifications = <dynamic>[].obs;
  var unreadCount = 0.obs;
  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var hasMore = true.obs;
  var page = 1.obs;

  var ringTrigger = 0.obs;
  final Set<String> _processedNotificationKeys = {};

  @override
  void onInit() {
    super.onInit();
    _loadLocalNotifications();
  }
  

  void ringBell() {
    ringTrigger.value++;
  }

  Future<String> _getStorageKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        return 'local_user_notifications_$userId';
      }
    } catch (_) {}
    return 'local_user_notifications_guest';
  }

  Future<void> _loadLocalNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey();
      final String? saved = prefs.getString(key);
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> list = jsonDecode(saved);
        final fcmNotifications = list.where(_isFirebaseNotification).toList();
        _processedNotificationKeys.clear();
        for (var item in fcmNotifications) {
          final String dedupKey = _buildDedupKey(item);
          if (dedupKey.isNotEmpty) _processedNotificationKeys.add(dedupKey);
        }
        notifications.assignAll(fcmNotifications);
        if (fcmNotifications.length != list.length) {
          await _saveLocalNotifications();
        }
        _recalculateUnreadCount();
      } else {
        notifications.clear();
        unreadCount.value = 0;
        _processedNotificationKeys.clear();
      }
    } catch (e) {
      debugPrint('Error loading local notifications: $e');
    }
  }

  Future<void> _saveLocalNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey();
      await prefs.setString(key, jsonEncode(notifications.toList()));
    } catch (e) {
      debugPrint('Error saving local notifications: $e');
    }
  }

  Future<void> resetState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getStorageKey();
      await prefs.remove(key);
      await prefs.remove('local_user_notifications');
    } catch (e) {
      debugPrint('Error resetting notification storage: $e');
    }
    notifications.clear();
    unreadCount.value = 0;
    _processedNotificationKeys.clear();
    isLoading.value = false;
    isLoadingMore.value = false;
    hasMore.value = true;
    page.value = 1;
  }

  void _recalculateUnreadCount() {
    int unread = 0;
    for (var n in notifications) {
      if (_isFirebaseNotification(n) && n['isRead'] == false) unread++;
    }
    unreadCount.value = unread;
  }

  Future<void> syncLocalNotifications() => _loadLocalNotifications();

  bool _isFirebaseNotification(dynamic item) {
    if (item is! Map) return false;
    final meta = item['metadata'] is Map
        ? item['metadata']
        : (item['data'] is Map ? item['data'] : null);
    return meta?['source'] == 'FCM';
  }

  String _buildDedupKey(dynamic item) {
    if (item is! Map) return '';
    final id = item['id'] ?? item['_id'];
    if (id != null && id.toString().isNotEmpty) {
      return id.toString();
    }
    final meta = item['metadata'] is Map
        ? item['metadata']
        : (item['data'] is Map ? item['data'] : null);
    final bookingId = (meta?['bookingId'] ?? meta?['rideId'] ?? meta?['tripId'])?.toString();
    final type = (meta?['type'] ?? meta?['event'])?.toString().toUpperCase();
    if (bookingId != null && bookingId.isNotEmpty && type != null && type.isNotEmpty) {
      return '${bookingId}_$type';
    }
    return '';
  }

  void addLocalNotification({
    required String title,
    required String body,
    required String type,
    String? bookingId,
    Map<String, dynamic>? extraData,
  }) {
    try {
      final typeUpper = type.toUpperCase();
      final dedupKey = (bookingId != null && bookingId.isNotEmpty)
          ? '${bookingId}_$typeUpper'
          : 'notif_${title}_$typeUpper';

      if (_processedNotificationKeys.contains(dedupKey)) {
        debugPrint('[NOTIFICATION][DEDUP] Duplicate notification ignored: $dedupKey');
        return;
      }

      // Check if existing notification list contains matching item
      final exists = notifications.any((n) {
        final key = _buildDedupKey(n);
        return key == dedupKey;
      });

      if (exists) {
        _processedNotificationKeys.add(dedupKey);
        return;
      }

      _processedNotificationKeys.add(dedupKey);

      final id = 'loc_${DateTime.now().millisecondsSinceEpoch}_${bookingId ?? ''}_$typeUpper';
      final newNotif = {
        'id': id,
        'title': title,
        'body': body,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        'metadata': {
          'type': typeUpper,
          'bookingId': bookingId,
          ...?extraData,
          'source': 'FCM',
        },
      };

      notifications.insert(0, newNotif);
      notifications.refresh();
      unreadCount.value++;
      ringBell();
      _saveLocalNotifications();
    } catch (e) {
      debugPrint('Error adding local notification: $e');
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final count = await NotificationApiService.fetchUnreadCount();
      if (count > unreadCount.value) {
        ringBell();
      }
      debugPrint('Remote unread notification count: $count');
    } catch (e) {
      debugPrint('Failed to fetch unread count: $e');
    }
  }

  Future<void> refreshList() async {
    page.value = 1;
    hasMore.value = true;
    await fetchNotifications(isRefresh: true);
  }

  Future<void> fetchNotifications({bool isRefresh = false}) async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;

    if (isRefresh) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final data = await NotificationApiService.fetchNotifications(
        page: page.value,
        limit: 20,
      );
      final List<dynamic> newNotifications = data['notifications'] ?? [];

      if (isRefresh) {
        // Merge API notifications with existing local notifications safely
        final Map<String, dynamic> mergedMap = {};
        for (var n in notifications) {
          final key = _buildDedupKey(n);
          if (key.isNotEmpty) mergedMap[key] = n;
        }
        for (var n in newNotifications) {
          final key = _buildDedupKey(n);
          if (key.isNotEmpty && _isFirebaseNotification(n)) {
            mergedMap[key] = n;
          } else {
            debugPrint('Remote notification skipped for Firebase-only badge/list.');
          }
        }
        final mergedList = mergedMap.values.toList();
        mergedList.sort((a, b) {
          final aDate = a['createdAt'] ?? a['created_at'] ?? '';
          final bDate = b['createdAt'] ?? b['created_at'] ?? '';
          return bDate.toString().compareTo(aDate.toString());
        });
        notifications.assignAll(mergedList);
      } else {
        for (var n in newNotifications) {
          final key = _buildDedupKey(n);
          if (key.isEmpty || !_processedNotificationKeys.contains(key)) {
            notifications.add(n);
            if (key.isNotEmpty) _processedNotificationKeys.add(key);
          }
        }
      }

      _saveLocalNotifications();

      if (newNotifications.length < 20) {
        hasMore.value = false;
      } else {
        page.value++;
      }
    } catch (e) {
      if (e is ApiException) {
        Get.snackbar('Error', e.message);
      } else {
        debugPrint('Failed to load remote notifications, using local items.');
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> markAsRead(String id, int index) async {
    if (index < 0 || index >= notifications.length) return;
    if (notifications[index]['isRead'] == true) return;

    // Optimistic update
    notifications[index]['isRead'] = true;
    notifications.refresh();
    if (unreadCount.value > 0) {
      unreadCount.value--;
    }
    _saveLocalNotifications();

    if (!id.startsWith('loc_')) {
      try {
        await NotificationApiService.markAsRead(id);
      } catch (e) {
        debugPrint('Failed to sync markAsRead with server: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in notifications) {
      n['isRead'] = true;
    }
    notifications.refresh();
    unreadCount.value = 0;
    _saveLocalNotifications();

    try {
      await NotificationApiService.markAllAsRead();
    } catch (e) {
      debugPrint('Failed to sync markAllAsRead with server: $e');
    }
  }

  Future<void> deleteNotification(String id, int index) async {
    if (index < 0 || index >= notifications.length) return;
    final removedItem = notifications[index];
    final bool wasUnread = removedItem['isRead'] == false;
    notifications.removeAt(index);
    if (wasUnread && unreadCount.value > 0) {
      unreadCount.value--;
    }
    _saveLocalNotifications();

    if (!id.startsWith('loc_')) {
      try {
        await NotificationApiService.deleteNotification(id);
      } catch (e) {
        notifications.insert(index, removedItem);
        _recalculateUnreadCount();
        _saveLocalNotifications();
        Get.snackbar('Error', 'Failed to delete notification.');
      }
    }
  }
}
