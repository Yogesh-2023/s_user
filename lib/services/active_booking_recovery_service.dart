import 'package:flutter/material.dart';

import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';
import '../core/api/api_service.dart';
import '../core/utils.dart';
import '../features/bookings/scheduled_rides_screen.dart';
import '../features/parcels/delivery_booked_screen.dart';
import '../features/parcels/goods_tracking_screen.dart';
import '../features/rides/driver_assigned_screen.dart';
import '../features/rides/driver_tracking_screen.dart';
import '../features/rides/looking_for_ride_screen.dart';
import '../features/rides/payment_screen.dart';

class ActiveBookingRecoveryService {
  ActiveBookingRecoveryService._();

  static bool _isRecovering = false;
  static String? _lastNavigatedBookingId;

  static const Set<String> _inactiveStatuses = {
    'COMPLETED',
    'TRIP_COMPLETED',
    'PAYMENT_COMPLETED',
    'CAPTURED',
    'CANCELLED',
    'CANCELED',
    'EXPIRED',
    'NO_DRIVER_FOUND',
    'FAILED',
    'REFUNDED',
  };

  static const Set<String> _scheduledStatuses = {
    'SCHEDULED',
    'BOOKED',
    'WAITING_DISPATCH',
  };

  static const Set<String> _searchingStatuses = {
    'PENDING',
    'SEARCHING',
    'SEARCHING_DRIVER',
    'DISPATCHED',
  };

  static const Set<String> _assignedStatuses = {
    'DRIVER_ASSIGNED',
    'DRIVER_ARRIVING',
  };

  static const Set<String> _arrivedStatuses = {
    'DRIVER_ARRIVED',
    'AT_PICKUP',
    'ARRIVED',
  };

  static const Set<String> _inProgressStatuses = {
    'OTP_VERIFIED',
    'PICKED_UP',
    'IN_TRANSIT',
    'TRIP_STARTED',
    'STARTED',
    'IN_PROGRESS',
    'ON_GOING',
    'ARRIVED_DESTINATION',
  };

  static const Set<String> _paymentPendingStatuses = {
    'PAYMENT_PENDING',
    'AWAITING_PAYMENT',
  };

  static Future<bool> fetchAndResume(
    BuildContext context, {
    bool showMessage = false,
  }) async {
    if (_isRecovering) return false;
    _isRecovering = true;
    try {
      final response = await ApiService.to.get(ApiEndpoints.activeBooking);
      if (response.statusCode != 200) return false;

      final booking = _extractBooking(response.data);
      if (booking == null) return false;
      if (!context.mounted) return false;

      return resume(
        context,
        booking,
        showMessage: showMessage,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        debugPrint('Active booking recovery failed: ${error.message}');
      }
      return false;
    } catch (error) {
      debugPrint('Active booking recovery failed: $error');
      return false;
    } finally {
      _isRecovering = false;
    }
  }

  static bool resume(
    BuildContext context,
    Map<String, dynamic> booking, {
    bool showMessage = false,
  }) {
    Map<String, dynamic> activeTargetBooking = booking;
    String? status = _status(booking);

    if (status == null || _inactiveStatuses.contains(status)) {
      final returnBooking = _asStringKeyMap(booking['returnBooking']);
      if (returnBooking != null) {
        final returnStatus = _status(returnBooking);
        if (returnStatus != null && !_inactiveStatuses.contains(returnStatus)) {
          activeTargetBooking = returnBooking;
          status = returnStatus;
        } else {
          return false;
        }
      } else {
        return false;
      }
    }

    final bookingId = _bookingId(activeTargetBooking);
    if (bookingId == null) return false;

    if (_lastNavigatedBookingId == '$bookingId:$status') return true;
    _lastNavigatedBookingId = '$bookingId:$status';

    if (showMessage) {
      AppUtils.showSnackBar(
        context,
        'You already have an active booking. Taking you back to it.',
      );
    }

    final isGoods = _isGoodsBooking(activeTargetBooking);
    final driverData = _driverData(activeTargetBooking);
    final route = _routeFor(
      bookingId: bookingId,
      booking: activeTargetBooking,
      driverData: driverData,
      status: status,
      isGoods: isGoods,
    );

    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      route,
      (route) => route.isFirst,
    );
    return true;
  }

  static Route<void> _routeFor({
    required String bookingId,
    required Map<String, dynamic> booking,
    required Map<String, dynamic> driverData,
    required String status,
    required bool isGoods,
  }) {
    if (isGoods) {
      if (_searchingStatuses.contains(status)) {
        return MaterialPageRoute<void>(
          builder: (_) => DeliveryBookedScreen(bookingId: bookingId),
        );
      }
      return MaterialPageRoute<void>(
        builder: (_) => GoodsTrackingScreen(bookingId: bookingId),
      );
    }

    if (_paymentPendingStatuses.contains(status) ||
        _paymentStatus(booking) == 'PAYMENT_PENDING') {
      return MaterialPageRoute<void>(
        builder: (_) => PaymentScreen(
          bookingId: bookingId,
          driverData: driverData,
        ),
      );
    }

    if (_scheduledStatuses.contains(status)) {
      return MaterialPageRoute<void>(
        builder: (_) => const ScheduledRidesScreen(),
      );
    }

    if (_searchingStatuses.contains(status)) {
      return MaterialPageRoute<void>(
        builder: (_) => LookingForRideScreen(tripId: bookingId),
      );
    }

    if (_assignedStatuses.contains(status)) {
      return MaterialPageRoute<void>(
        builder: (_) => DriverAssignedScreen(
          tripId: bookingId,
          driverData: driverData,
        ),
      );
    }

    RideState initialState = RideState.arriving;
    if (_inProgressStatuses.contains(status)) {
      initialState = RideState.inProgress;
    } else if (_arrivedStatuses.contains(status)) {
      initialState = RideState.arriving;
    }

    return MaterialPageRoute<void>(
      builder: (_) => DriverTrackingScreen(
        tripId: bookingId,
        driverData: driverData,
        initialState: initialState,
      ),
    );
  }

  static Map<String, dynamic>? _extractBooking(dynamic body) {
    final root = _asStringKeyMap(body);
    if (root == null) return null;

    final data = _asStringKeyMap(root['data']) ?? root;
    final booking = _asStringKeyMap(data['booking']) ??
        _asStringKeyMap(data['activeBooking']) ??
        data;

    if (_bookingId(booking) == null) return null;
    return booking;
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String? _bookingId(Map<String, dynamic> booking) {
    return (booking['id'] ??
            booking['_id'] ??
            booking['bookingId'] ??
            booking['booking_id'] ??
            booking['tripId'])
        ?.toString();
  }

  static String? _status(Map<String, dynamic> booking) {
    return (booking['status'] ??
            booking['bookingStatus'] ??
            booking['booking_status'] ??
            booking['tripStatus'])
        ?.toString()
        .trim()
        .toUpperCase();
  }

  static String? _paymentStatus(Map<String, dynamic> booking) {
    final payment = _asStringKeyMap(booking['payment']) ??
        _asStringKeyMap(booking['latestPayment']);
    return (booking['paymentStatus'] ??
            booking['payment_status'] ??
            payment?['status'])
        ?.toString()
        .trim()
        .toUpperCase();
  }

  static Map<String, dynamic> _driverData(Map<String, dynamic> booking) {
    final driver = _asStringKeyMap(booking['driver']) ??
        _asStringKeyMap(booking['assignedDriver']) ??
        <String, dynamic>{};
    return {
      ...booking,
      ...driver,
      'booking': booking,
      'bookingId': _bookingId(booking),
      'tripId': _bookingId(booking),
    };
  }

  static bool _isGoodsBooking(Map<String, dynamic> booking) {
    final type = (booking['type'] ??
            booking['bookingType'] ??
            booking['serviceType'] ??
            booking['rideType'] ??
            booking['categoryType'])
        ?.toString()
        .toUpperCase();
    return type != null &&
        (type.contains('GOODS') ||
            type.contains('PARCEL') ||
            type.contains('DELIVERY') ||
            type.contains('TRUCK'));
  }
}
