import 'dart:async';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../api/api_constants.dart';
import '../utils.dart';
import 'socket_events.dart';

enum SocketConnectionStatus { disconnected, connecting, connected, error }

class SocketService extends GetxService {
  IO.Socket? _socket;
  final Rx<SocketConnectionStatus> connectionStatus =
      SocketConnectionStatus.disconnected.obs;

  // Keep track of listeners for specific events to allow targeted unregistration
  final Map<String, List<Function(dynamic)>> _registeredCallbacks = {};

  // Cache recent socket events to fix navigation race conditions
  final Map<String, dynamic> _eventCache = {};

  String? _bookingIdFrom(dynamic data) {
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is! Map) return null;
    final booking = payload['booking'];
    return (payload['bookingId'] ??
            payload['returnBookingId'] ??
            payload['parentBookingId'] ??
            payload['goodsBookingId'] ??
            payload['tripId'] ??
            payload['id'] ??
            (booking is Map ? booking['id'] : null))
        ?.toString();
  }

  bool isEventForBooking(dynamic data, String? bookingId) {
    if (bookingId == null || bookingId.isEmpty) return true;
    final extracted = _bookingIdFrom(data);
    if (extracted == null || extracted.isEmpty) return true;
    return extracted == bookingId;
  }

  /// Removes cached ride events for one completed/cancelled booking without
  /// disturbing the live socket connection or events for another booking.
  void clearBookingEvents(String bookingId) {
    if (bookingId.isEmpty) return;
    _eventCache.removeWhere((_, data) => _bookingIdFrom(data) == bookingId);
  }

  static SocketService get to {
    try {
      return Get.find<SocketService>();
    } catch (e) {
      return Get.put(SocketService(), permanent: true);
    }
  }

  // Active status checks
  bool get isConnected =>
      connectionStatus.value == SocketConnectionStatus.connected;
  bool get isConnecting =>
      connectionStatus.value == SocketConnectionStatus.connecting;

  // Stream for listening to connection status changes
  Stream<SocketConnectionStatus> get statusStream => connectionStatus.stream;

  // Callback to execute when connection is established (for active state recovery)
  Future<void> Function()? onConnectionEstablished;

  /// Initializes and connects to the socket server
  void initSocket({
    required String sessionToken,
    required String userId,
    String role = 'user',
  }) {
    print('--- [SOCKET_IO] Initializing socket connection for User App ---');
    print('--- [SOCKET_IO] Target URL: ${ApiConstants.baseUrl} ---');
    print(
      '--- [SOCKET_IO] Query Params: role=$role, userId=$userId, sessionToken=*** ---',
    );

    // Close existing socket if any
    closeSocket();

    connectionStatus.value = SocketConnectionStatus.connecting;

    String parsedSessionToken = sessionToken;
    if (sessionToken.contains('session=')) {
      final matches = RegExp(r'session=([^;]+)').firstMatch(sessionToken);
      if (matches != null && matches.groupCount >= 1) {
        parsedSessionToken = matches.group(1) ?? sessionToken;
      }
    }

    try {
      var socketUrl = ApiConstants.baseUrl.replaceAll('/api', '');
      print('--- [SOCKET_IO] Resolved Socket URL: $socketUrl ---');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .disableAutoConnect()
            .setPath('/socket.io')
            .setTransports(['websocket'])
            .enableWithCredentials()
            .enableForceNew()
            .enableReconnection()
            .setReconnectionAttempts(20)
            .setReconnectionDelay(1500)
            .setTimeout(20000)
            .setQuery({
              'role': role,
              'sessionToken': parsedSessionToken,
              'userId': userId,
              'moduleType': 'GOODS',
            })
            .setExtraHeaders({
              'Cookie': sessionToken.startsWith('fleet_session=')
                  ? sessionToken
                  : 'fleet_session=$sessionToken; better-auth.session_token=$sessionToken',
              'Authorization': 'Bearer $sessionToken',
            })
            .build(),
      );

      _setupListeners();
      _socket!.connect();
    } catch (e) {
      connectionStatus.value = SocketConnectionStatus.error;
      print('--- [SOCKET_IO] Initialization Error: $e ---');
    }
  }

  /// Sets up default event listeners
  void _setupListeners() {
    if (_socket == null) return;

    // Re-attach any previously registered listeners (e.g. after a reconnect/re-init)
    _registeredCallbacks.forEach((event, callbacks) {
      for (var callback in callbacks) {
        _socket!.on(event, (data) {
          if (data is Map) {
            _capitalizeAuto(data);
          }
          print('--- [SOCKET_IO] [RE-EVENT RECEIVED] -> Event: "$event" ---');
          callback(data);
        });

        final errorEvent = '$event:error';
        _socket!.on(errorEvent, (errorData) {
          print('--- [SOCKET_IO] [ERROR RECEIVED] -> Event: "$errorEvent" ---');
          _showSocketErrorSnackBar(errorData, event: errorEvent);
        });
      }
    });

    // 1. Connection established
    _socket!.on(SocketEvents.connect, (_) async {
      connectionStatus.value = SocketConnectionStatus.connected;
      print('[YOGESH][SOCKET][USER] Connected! Socket ID: ${_socket!.id}');

      // Request state recovery after reconnect
      emitEvent(SocketEvents.stateSyncRequest, <String, dynamic>{});

      // Trigger reconnection/recovery callback if registered
      if (onConnectionEstablished != null) {
        print(
          '[YOGESH][SOCKET][USER] Triggering active booking recovery callback',
        );
        await onConnectionEstablished!();
      }
    });

    // 1.1 Server Ready
    _socket!.on(SocketEvents.socketReady, (data) {
      print('[YOGESH][SOCKET][USER] socket:ready received: $data');
    });

    // 1.2 State Sync
    _socket!.on(SocketEvents.stateSync, (data) {
      print('[YOGESH][SOCKET][USER] state:sync received: $data');
    });

    // 1.3 Socket Error
    _socket!.on(SocketEvents.socketError, (errData) {
      print('[YOGESH][SOCKET][USER] socket:error received: $errData');
      final code = errData is Map ? errData['code'] ?? errData['error'] : errData;
      if (code == 'SOCKET_UNAUTHENTICATED') {
        connectionStatus.value = SocketConnectionStatus.error;
      }
      _showSocketErrorSnackBar(errData, event: SocketEvents.socketError);
    });

    // 2. Disconnected
    _socket!.on(SocketEvents.disconnect, (reason) {
      connectionStatus.value = SocketConnectionStatus.disconnected;
      print('[YOGESH][SOCKET][USER] Disconnected. Reason: $reason');
    });

    // 3. Connection Error
    _socket!.on(SocketEvents.connectError, (err) {
      connectionStatus.value = SocketConnectionStatus.error;
      print('[YOGESH][SOCKET][USER] Connection Error: $err');
    });

    // 4. General Error
    _socket!.on(SocketEvents.error, (err) {
      print('[YOGESH][SOCKET][USER] Socket Error: $err');
      _showSocketErrorSnackBar(err, event: SocketEvents.error);
    });

    // 5. Global Listener for debugging events (Custom Event Log)
    // Note: socket_io_client in Dart doesn't have socket.onevent out of the box,
    // so we wrap the standard event registration to print inputs.

    // Debug Listeners for all Ride & Goods Flows (Always print in terminal)
    final debugEvents = [
      'booking:created',
      'RIDE_BOOKED',
      'NEW_TRIP_REQUEST',
      'TRIP_ACCEPTED',
      'DRIVER_FOUND',
      'DRIVER_ON_THE_WAY',
      'DRIVER_REJECTED',
      'NO_DRIVER_FOUND',
      'DRIVER_LOCATION',
      'DRIVER_ARRIVED',
      'TRIP_CANCELLED',
      'TRIP_STARTED',
      'TRIP_COMPLETED',
      'goods.driver.assigned',
      'goods.driver.on_the_way',
      'goods.pickup.otp.sent',
      'goods.pickup.otp.required',
      'goods.booking.created',
      'goods:booking:request',
    ];

    for (var event in debugEvents) {
      _socket!.on(event, (data) {
        if (data is Map) {
          _capitalizeAuto(data);
        }
        _eventCache[event] = data;
        print('\n====== 🚀 [USER APP SOCKET DEBUG] $event ======');
        print('Payload: $data');
        print('===============================================\n');
      });
    }
  }

  void _capitalizeAuto(Map data) {
    try {
      if (data['carName']?.toString().toUpperCase() == 'AUTO') {
        data['carName'] = 'AUTO';
      }
      if (data['carType']?.toString().toUpperCase() == 'AUTO') {
        data['carType'] = 'AUTO';
      }
      if (data['vehicleType']?.toString().toUpperCase() == 'AUTO') {
        data['vehicleType'] = 'AUTO';
      }
      for (var key in data.keys.toList()) {
        if (data[key] is Map) {
          _capitalizeAuto(data[key]);
        }
      }
    } catch (e) {
      print('Failed to capitalize map data safely: $e');
    }
  }

  /// Registers a listener for a specific socket event
  void listenTo(
    String event,
    Function(dynamic data) callback, {
    bool fromQueue = false,
    bool triggerCached = false,
  }) {
    bool isFirstListener =
        !_registeredCallbacks.containsKey(event) ||
        _registeredCallbacks[event]!.isEmpty;

    _registeredCallbacks.putIfAbsent(event, () => []).add(callback);

    if (_socket == null) {
      print(
        '--- [SOCKET_IO] Warning: Socket not initialized yet. Listener for "$event" saved and will attach on connect. ---',
      );
      return;
    }

    if (triggerCached && _eventCache.containsKey(event)) {
      print(
        '--- [SOCKET_IO] Triggering cached event for "$event" to new listener ---',
      );
      Future.microtask(() => callback(_eventCache[event]));
    }

    if (!fromQueue) {
      print('--- [SOCKET_IO] Registering listener for "$event" ---');
    }

    if (isFirstListener) {
      _socket!.on(event, (data) {
        if (data is Map) {
          _capitalizeAuto(data);
        }
        _eventCache[event] = data;
        print('--- [SOCKET_IO] [EVENT RECEIVED] -> Event: "$event" ---');
        print('--- [SOCKET_IO] [PAYLOAD] -> $data ---');

        final callbacks = _registeredCallbacks[event]?.toList() ?? [];
        for (var cb in callbacks) {
          cb(data);
        }
      });

      // Also register error listeners for specific event (e.g. event_name:error)
      final errorEvent = '$event:error';
      _socket!.on(errorEvent, (errorData) {
        print('--- [SOCKET_IO] [ERROR RECEIVED] -> Event: "$errorEvent" ---');
        print('--- [SOCKET_IO] [ERROR DETAILS] -> $errorData ---');

        _showSocketErrorSnackBar(errorData, event: errorEvent);
      });
    }
  }

  void _showSocketErrorSnackBar(dynamic errorData, {String? event}) {
    final context = Get.context;
    if (context == null) return;

    final message = _friendlySocketErrorMessage(errorData, event: event);
    if (message == null || message.isEmpty) return;

    AppUtils.showSnackBar(context, message, isError: true);
  }

  String? _friendlySocketErrorMessage(dynamic errorData, {String? event}) {
    final rawMessage = _extractSocketMessage(errorData).trim();
    final normalized = rawMessage.toLowerCase();
    final normalizedEvent = event?.toLowerCase() ?? '';

    if (rawMessage.isEmpty ||
        normalized == 'null' ||
        normalized.contains('[socket_io]') ||
        normalized.contains('emitting with ack') ||
        normalized.contains('ack received') ||
        normalized.contains('driver:heartbeat') ||
        normalized.contains('driver:location:update') ||
        normalizedEvent.contains('driver:heartbeat') ||
        normalizedEvent.contains('driver:location:update')) {
      return null;
    }

    if (normalized.contains('already') &&
        normalized.contains('booking') &&
        normalized.contains('session')) {
      return 'You already have an active booking. Please complete or cancel it before starting a new one.';
    }

    if (normalized.contains('socket_not_connected') ||
        normalized.contains('not connected')) {
      return 'Connection lost. Please check your internet and try again.';
    }

    if (normalized.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (normalized.contains('unauthenticated') ||
        normalized.contains('session expired')) {
      return 'Your session has expired. Please log in again.';
    }

    if (normalized.contains('booking not found')) {
      return 'We could not find this booking. Please refresh and try again.';
    }

    if (normalized.contains('no driver') ||
        normalized.contains('driver not found')) {
      return 'No driver is available right now. Please try again in a moment.';
    }

    if (normalized.contains('location') &&
        (normalized.contains('permission') || normalized.contains('denied'))) {
      return 'Location permission is needed to update your ride.';
    }

    if (_looksTechnical(rawMessage)) {
      return 'Something went wrong. Please try again.';
    }

    return rawMessage;
  }

  String _extractSocketMessage(dynamic errorData) {
    if (errorData == null) return '';
    if (errorData is String) return errorData;
    if (errorData is List && errorData.isNotEmpty) {
      return _extractSocketMessage(errorData.first);
    }
    if (errorData is Map) {
      for (final key
          in const ['message', 'error', 'reason', 'details', 'code']) {
        final value = errorData[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }
    return errorData.toString();
  }

  bool _looksTechnical(String message) {
    final trimmed = message.trim();
    return trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.contains('Exception:') ||
        trimmed.contains('SocketException') ||
        trimmed.contains('_') ||
        trimmed.contains('->') ||
        trimmed.contains('Payload:');
  }

  /// Unregisters a listener for a specific event
  void stopListening(String event, [Function(dynamic data)? callback]) {
    if (callback != null) {
      _registeredCallbacks[event]?.remove(callback);
    } else {
      _registeredCallbacks.remove(event);
    }

    if ((_registeredCallbacks[event]?.isEmpty ?? true) && _socket != null) {
      _registeredCallbacks.remove(event);
      print('--- [SOCKET_IO] Stopped listening to: "$event" ---');
      _socket!.off(event);
      _socket!.off('$event:error');
    }
  }

  /// Emits an event with optional payload
  void emitEvent(String event, [dynamic data]) {
    if (_socket == null || !isConnected) {
      print(
        '--- [SOCKET_IO] Error: Cannot emit "$event". Socket is not connected. ---',
      );
      return;
    }

    print('--- [SOCKET_IO] [EMITTING EVENT] -> Event: "$event" ---');
    if (data != null) {
      print('--- [SOCKET_IO] [EMIT PAYLOAD] -> $data ---');
      _socket!.emit(event, data);
    } else {
      _socket!.emit(event);
    }
  }

  /// Emits an event with acknowledgement callback (returns Future response)
  Future<dynamic> emitWithAck(
    String event, [
    dynamic data,
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    if (_socket == null || !isConnected) {
      print(
        '--- [SOCKET_IO] Error: Cannot emitWithAck "$event". Socket is not connected. ---',
      );
      return {'success': false, 'error': 'SOCKET_NOT_CONNECTED'};
    }

    print(
      '--- [SOCKET_IO] [EMITTING WITH ACK] -> Event: "$event" Payload: $data ---',
    );
    final completer = Completer<dynamic>();

    try {
      _socket!.emitWithAck(
        event,
        data ?? {},
        ack: (response) {
          if (!completer.isCompleted) {
            print(
              '--- [SOCKET_IO] [ACK RECEIVED] -> Event: "$event" Response: $response ---',
            );
            completer.complete(response);
          }
        },
      );
    } catch (e) {
      print('--- [SOCKET_IO] Exception calling emitWithAck for "$event": $e ---');
      try {
        _socket!.emit(event, [
          data ?? {},
          (response) {
            if (!completer.isCompleted) {
              print(
                '--- [SOCKET_IO] [ACK CALLBACK RECEIVED] -> Event: "$event" Response: $response ---',
              );
              completer.complete(response);
            }
          },
        ]);
      } catch (e2) {
        if (!completer.isCompleted) {
          completer.completeError(e2);
        }
      }
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        print('--- [SOCKET_IO] Timeout waiting for ACK on event: "$event" ---');
        return {'success': false, 'error': 'TIMEOUT'};
      },
    );
  }

  // ==========================================
  // CANONICAL SOCKET API CONVENIENCE METHODS
  // ==========================================

  /// 1. booking:track
  Future<dynamic> trackBooking({required String bookingId}) async {
    clearBookingEvents(bookingId);
    final payload = <String, dynamic>{'bookingId': bookingId};
    emitEvent(SocketEvents.bookingTrack, payload);
    return await emitWithAck(SocketEvents.bookingTrack, payload);
  }

  /// 2. booking:untrack
  Future<dynamic> untrackBooking({required String bookingId}) async {
    final payload = <String, dynamic>{'bookingId': bookingId};
    emitEvent(SocketEvents.bookingUntrack, payload);
    return await emitWithAck(SocketEvents.bookingUntrack, payload);
  }

  /// 3. booking:cancel
  Future<dynamic> cancelBooking({
    required String bookingId,
    String? reasonCode,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      if (reasonCode != null && reasonCode.isNotEmpty) 'reasonCode': reasonCode,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    emitEvent(SocketEvents.bookingCancel, payload);
    return await emitWithAck(SocketEvents.bookingCancel, payload);
  }

  /// Shared: state:sync:request
  Future<dynamic> requestStateSync() async {
    return await emitWithAck(
      SocketEvents.stateSyncRequest,
      <String, dynamic>{},
    );
  }

  /// Shared: sos:create
  Future<dynamic> createSos({
    required String bookingId,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'latitude': latitude,
      'longitude': longitude,
      if (message != null && message.isNotEmpty) 'message': message,
    };
    emitEvent(SocketEvents.sosCreate, payload);
    return await emitWithAck(SocketEvents.sosCreate, payload);
  }

  /// Shared: chat:join
  Future<dynamic> joinChat({required String bookingId}) async {
    final payload = <String, dynamic>{'bookingId': bookingId};
    emitEvent(SocketEvents.chatJoin, payload);
    return await emitWithAck(SocketEvents.chatJoin, payload);
  }

  /// Shared: chat:send
  Future<dynamic> sendChat({
    required String bookingId,
    required String message,
    String? clientMessageId,
  }) async {
    final payload = <String, dynamic>{
      'bookingId': bookingId,
      'message': message,
      'clientMessageId':
          clientMessageId ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
    };
    emitEvent(SocketEvents.chatSend, payload);
    return await emitWithAck(SocketEvents.chatSend, payload);
  }

  /// Closes the socket connection
  void closeSocket() {
    if (_socket != null) {
      print('--- [SOCKET_IO] Closing and destroying socket connection ---');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _eventCache.clear();
    connectionStatus.value = SocketConnectionStatus.disconnected;
  }

  @override
  void onClose() {
    closeSocket();
    super.onClose();
  }
}
