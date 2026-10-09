import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import '../firebase_options.dart';
import '../features/notifications/controllers/notification_controller.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/rides/driver_assigned_screen.dart';
import '../features/rides/driver_tracking_screen.dart';
import '../features/rides/payment_screen.dart';
import '../features/main_navigation_screen.dart';
import '../features/bookings/scheduled_rides_screen.dart';
import 'active_booking_recovery_service.dart';
import 'notification_api_service.dart';

const AndroidNotificationChannel _pushChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Important notifications',
  description: 'Ride, driver, payment and delivery updates.',
  importance: Importance.max,
  playSound: true,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _saveFirebaseMessage(message);
}

Future<String> _notificationStorageKey() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id');
  if (userId != null && userId.isNotEmpty) {
    return 'local_user_notifications_$userId';
  }
  return 'local_user_notifications_guest';
}

String _firebaseMessageDedupKey(RemoteMessage message) {
  final data = message.data;
  final id = message.messageId ?? data['notificationId'] ?? data['id'];
  if (id != null && id.toString().isNotEmpty) return id.toString();

  final bookingId = (data['bookingId'] ?? data['rideId'] ?? data['tripId'])?.toString();
  final type = (data['type'] ?? data['event'] ?? 'RIDE_UPDATE').toString().toUpperCase();
  if (bookingId != null && bookingId.isNotEmpty) return '${bookingId}_$type';

  final title = message.notification?.title ?? data['title'] ?? 'Sawariyaa';
  return 'notif_${title}_$type';
}

String _storedNotificationDedupKey(dynamic item) {
  if (item is! Map) return '';
  final id = item['id'] ?? item['_id'];
  if (id != null && id.toString().isNotEmpty) return id.toString();

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

Future<void> _saveFirebaseMessage(RemoteMessage message) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = await _notificationStorageKey();
    final saved = prefs.getString(key);
    final existing = saved == null || saved.isEmpty
        ? <dynamic>[]
        : (jsonDecode(saved) as List<dynamic>);
    final dedupKey = _firebaseMessageDedupKey(message);
    final alreadySaved = existing.any(
      (item) => _storedNotificationDedupKey(item) == dedupKey,
    );
    if (alreadySaved) return;

    final data = message.data;
    final title = message.notification?.title ?? data['title'] ?? 'Sawariyaa';
    final body = message.notification?.body ?? data['body'] ?? data['message'] ?? '';
    final type = (data['type'] ?? data['event'] ?? 'RIDE_UPDATE').toString().toUpperCase();
    final bookingId = (data['bookingId'] ?? data['rideId'] ?? data['tripId'])?.toString();

    existing.insert(0, {
      'id': message.messageId ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'body': body,
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
      'metadata': {
        'type': type,
        'bookingId': bookingId,
        ...data,
        'source': 'FCM',
      },
    });
    await prefs.setString(key, jsonEncode(existing));
  } catch (error) {
    debugPrint('Failed to save background Firebase notification: $error');
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializationFuture;
  String? _lastNavigatedNotificationId;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final messaging = FirebaseMessaging.instance;
      _messaging = messaging;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_pushChannel);

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      messaging.onTokenRefresh.listen(_registerToken);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(initialMessage);
        });
      }

      _initialized = true;
      await syncToken();
    } finally {
      if (!_initialized) _initializationFuture = null;
    }
  }

  Future<void> syncToken() async {
    try {
      if (!_initialized) await initialize();
      final token = await _messaging?.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error) {
      debugPrint('FCM token unavailable: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    debugPrint('[USER_APP][FCM][TOKEN] Token: $token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    final authToken = prefs.getString('auth_token');
    if (authToken == null || authToken.isEmpty) return;
    try {
      await NotificationApiService.registerToken({
        'token': token,
        'platform': Platform.operatingSystem,
        'deviceId': 'device_${Platform.operatingSystem}',
        'appType': 'CUSTOMER',
        'appVersion': '1.0.0',
      });
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('fcm_token');
    if (token != null && token.isNotEmpty) {
      try {
        await NotificationApiService.deleteToken(token);
        await prefs.remove('fcm_token');
      } catch (e) {
        debugPrint('Failed to remove FCM token: $e');
      }
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Sawariyaa';
    final body = notification?.body ?? data['body'] ?? data['message'] ?? '';
    final type = (data['type'] ?? data['event'] ?? 'RIDE_UPDATE').toString();
    final bookingId = (data['bookingId'] ?? data['rideId'] ?? data['tripId'])?.toString();

    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: title,
        body: body,
        type: type,
        bookingId: bookingId,
        extraData: data,
      );
    }

    await _localNotifications.show(
      message.messageId.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Important notifications',
          channelDescription: 'Ride, driver, payment and delivery updates.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[USER_APP][FCM][TAP] Payload: ${message.data}');
    _saveFirebaseMessage(message).then((_) {
      if (Get.isRegistered<NotificationController>()) {
        NotificationController.to.syncLocalNotifications();
      }
    });
    final data = message.data;
    final msgId = message.messageId ?? data['notificationId'] ?? data['id'];
    if (msgId != null && msgId == _lastNavigatedNotificationId) {
      debugPrint('[USER_APP][FCM][TAP] Duplicate tap ignored for $msgId');
      return;
    }
    _lastNavigatedNotificationId = msgId?.toString();

    final type = (data['type'] ?? data['event'] ?? data['module'])?.toString().toUpperCase();
    final bookingId = (data['rideId'] ?? data['bookingId'] ?? data['tripId'])?.toString();

    if (bookingId != null && bookingId.isNotEmpty) {
      try {
        if (type == 'RETURN_RIDE' || type == 'RETURN_DRIVER_ASSIGNED' || data['tripLeg'] == 'RETURN') {
          final context = Get.context;
          if (context != null) {
            ActiveBookingRecoveryService.fetchAndResume(context, showMessage: false).then((resumed) {
              if (!resumed) {
                Get.to(() => const ScheduledRidesScreen());
              }
            });
            return;
          }
        }
        if (type == 'DRIVER_ACCEPTED' || type == 'RIDE_ACCEPTED' || type == 'DRIVER_ASSIGNED' || type == 'DRIVER_ARRIVED' || type == 'SCHEDULED_DRIVER_ASSIGNED') {
          Get.to(() => DriverAssignedScreen(tripId: bookingId, driverData: data));
          return;
        }
        if (type == 'DRIVER_CANCELLED' || type == 'SCHEDULED_DRIVER_REJECTED') {
          Get.snackbar(
            'Scheduled Ride Update',
            'Searching for another available driver for your scheduled ride...',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFFFFC000),
            colorText: Colors.black,
          );
          Get.to(() => const ScheduledRidesScreen());
          return;
        }
        if (type == 'SCHEDULED_RIDE_RESCHEDULED' || type == 'SCHEDULED_RIDE_REASSIGNING') {
          if (type == 'SCHEDULED_RIDE_REASSIGNING') {
            Get.snackbar(
              'Finding Driver',
              'Re-assigning driver for your rescheduled ride',
              snackPosition: SnackPosition.TOP,
              backgroundColor: const Color(0xFF3B82F6),
              colorText: Colors.white,
            );
          }
          Get.to(() => const ScheduledRidesScreen());
          return;
        }
        if (type == 'SCHEDULED_RIDE_REMINDER' || type == 'SCHEDULED_RIDE_READY') {
          Get.to(() => const ScheduledRidesScreen());
          return;
        }
        if (type == 'RIDE_STARTED' || type == 'TRIP_STARTED' || type == 'IN_TRANSIT') {
          Get.to(() => DriverTrackingScreen(tripId: bookingId, driverData: data));
          return;
        }
        if (type == 'RIDE_COMPLETED' || type == 'PAYMENT_PENDING' || type == 'PAYMENT_SUCCESSFUL' || type == 'PAYMENT_FAILED') {
          Get.to(() => PaymentScreen(bookingId: bookingId, driverData: data));
          return;
        }
        if (type == 'RIDE_CANCELLED' || type == 'TRIP_CANCELLED') {
          Get.offAll(() => const MainNavigationScreen());
          return;
        }
      } catch (e) {
        debugPrint('Safe fallback navigation error: $e');
      }
    }

    // Default fallback: Go to NotificationsScreen
    Get.to(() => const NotificationsScreen());
  }
}
