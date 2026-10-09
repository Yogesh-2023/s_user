import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_fonts.dart';
import '../../constants/app_assets.dart';
import 'cancel_ride_screen.dart';
import 'cancellation_reason_drawer.dart';
import 'payment_screen.dart';
import 'driver_chat_screen.dart';
import 'ride_invoice_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/socket/socket_service.dart';
import '../../core/socket/socket_events.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_service.dart';
import '../../core/utils.dart';
import '../../core/maps/smooth_map_motion.dart';
import 'package:get/get.dart';
import '../main_navigation_screen.dart';
import '../notifications/controllers/notification_controller.dart';
import '../../widgets/location_route_markers.dart';

enum RideState { arriving, verifyOTP, inProgress }

class DriverTrackingScreen extends StatefulWidget {
  final String? tripId;
  final Map<String, dynamic>? driverData;
  final RideState? initialState;

  const DriverTrackingScreen({
    super.key,
    this.tripId,
    this.driverData,
    this.initialState,
  });

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
  String _calculateETA() {
    if (_rideState != RideState.arriving) return 'Arrived';
    if (_driverLocation == null) return 'Estimating...';

    final dropLat = double.tryParse(_bookingData?['dropLat']?.toString() ?? '');
    final dropLng = double.tryParse(_bookingData?['dropLng']?.toString() ?? '');
    final pickupLat = double.tryParse(
      _bookingData?['pickupLat']?.toString() ?? '',
    );
    final pickupLng = double.tryParse(
      _bookingData?['pickupLng']?.toString() ?? '',
    );

    final targetLat = _rideState == RideState.arriving ? pickupLat : dropLat;
    final targetLng = _rideState == RideState.arriving ? pickupLng : dropLng;

    if (targetLat == null || targetLng == null) return 'Estimating...';

    double distanceInMeters = Geolocator.distanceBetween(
      targetLat,
      targetLng,
      _driverLocation!.latitude,
      _driverLocation!.longitude,
    );
    int minutes = (distanceInMeters / 500).ceil();
    if (minutes <= 0) return 'Arriving now';
    return 'Arriving in $minutes min';
  }

  dynamic _readValue(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  Map<String, dynamic> get _driver {
    final value =
        _bookingData?['driver'] ??
        _bookingData?['assignedDriver'] ??
        _bookingData?['driverDetails'] ??
        _bookingData?['driverProfile'] ??
        _bookingData?['booking']?['driver'] ??
        _bookingData?['booking']?['assignedDriver'] ??
        _bookingData?['booking']?['driverDetails'] ??
        widget.driverData?['driver'] ??
        widget.driverData?['assignedDriver'] ??
        widget.driverData?['driverDetails'] ??
        widget.driverData?['booking']?['driver'] ??
        widget.driverData?['booking']?['assignedDriver'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> get _vehicle {
    final value =
        _driver['assignedVehicle'] ??
        _driver['vehicle'] ??
        _driver['vehicles']?[0] ??
        _driver['driverProfile']?['vehicles']?[0] ??
        _driver['driverProfile']?['vehicle'] ??
        _bookingData?['vehicle'] ??
        _bookingData?['assignedVehicle'] ??
        _bookingData?['booking']?['vehicle'] ??
        _bookingData?['booking']?['assignedVehicle'] ??
        widget.driverData?['vehicle'] ??
        widget.driverData?['assignedVehicle'] ??
        widget.driverData?['booking']?['vehicle'] ??
        widget.driverData?['booking']?['assignedVehicle'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _getDriverName() {
    final firstName = _readValue([
      _driver['firstName'],
      _driver['firstname'],
      _driver['user']?['firstName'],
      _driver['user']?['firstname'],
      _driver['driverProfile']?['user']?['firstName'],
    ])?.toString();
    final lastName = _readValue([
      _driver['lastName'],
      _driver['lastname'],
      _driver['user']?['lastName'],
      _driver['user']?['lastname'],
      _driver['driverProfile']?['user']?['lastName'],
    ])?.toString();
    final fullName = [
      firstName,
      lastName,
    ].where((v) => v?.trim().isNotEmpty == true).join(' ');
    if (fullName.isNotEmpty) return fullName;

    return (_readValue([
              _driver['name'],
              _driver['fullName'],
              _driver['displayName'],
              _driver['user']?['displayName'],
              _driver['user']?['name'],
              _driver['driverProfile']?['name'],
              _driver['driverProfile']?['user']?['name'],
              _driver['driverProfile']?['user']?['displayName'],
              _bookingData?['driverName'],
              _bookingData?['driver']?['name'],
              _bookingData?['driver']?['user']?['name'],
              _bookingData?['driver']?['user']?['displayName'],
              _bookingData?['assignedDriver']?['name'],
              _bookingData?['assignedDriver']?['user']?['name'],
              _bookingData?['assignedDriver']?['user']?['displayName'],
              _bookingData?['booking']?['driverName'],
              _bookingData?['booking']?['driver']?['name'],
              _bookingData?['booking']?['driver']?['user']?['name'],
              _bookingData?['booking']?['assignedDriver']?['name'],
              widget.driverData?['driverName'],
              widget.driverData?['driver']?['name'],
              widget.driverData?['driver']?['user']?['name'],
              widget.driverData?['assignedDriver']?['name'],
              widget.driverData?['booking']?['driverName'],
            ]) ??
            'Unknown Driver')
        .toString();
  }

  Map<String, dynamic> _getVehicleData() {
    return _vehicle;
  }

  String? get _driverPhone => _readValue([
    _driver['phone'],
    _driver['mobile'],
    _driver['phoneNumber'],
    _driver['mobileNumber'],
    _driver['contactNumber'],
    _driver['user']?['phone'],
    _driver['user']?['mobile'],
    _driver['user']?['phoneNumber'],
    _driver['driverProfile']?['phone'],
    _driver['driverProfile']?['user']?['phone'],
    _bookingData?['driverPhone'],
    _bookingData?['driver']?['phone'],
    _bookingData?['driver']?['user']?['phone'],
    _bookingData?['assignedDriver']?['phone'],
    _bookingData?['assignedDriver']?['user']?['phone'],
    _bookingData?['booking']?['driverPhone'],
    widget.driverData?['driverPhone'],
    widget.driverData?['driver']?['phone'],
    widget.driverData?['assignedDriver']?['phone'],
  ])?.toString();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _driverLocation;
  double _driverBearing = 0;
  final SmoothMapMotion _mapMotion = SmoothMapMotion();
  BitmapDescriptor? _driverMarkerIcon;
  List<LatLng> _routePoints = const [];
  RideState _rideState = RideState.arriving;

  int _waitingSeconds = 0;
  Timer? _waitingTimer;
  Timer? _trackingTimer;
  Map<String, dynamic>? _bookingData;
  bool _isNavigating = false;
  bool _isRecoveringGoodsDeliveryOtp = false;
  String? _otp;
  String? _deliveryOtp;

  bool _isCurrentBookingEvent(dynamic data) {
    return SocketService.to.isEventForBooking(data, widget.tripId);
  }

  @override
  void initState() {
    super.initState();
    _otp =
        widget.driverData?['rideStartOtp']?.toString() ??
        widget.driverData?['otp']?.toString() ??
        widget.driverData?['pickupOtp']?.toString() ??
        widget.driverData?['booking']?['rideStartOtp']?.toString() ??
        widget.driverData?['booking']?['pickupOtp']?.toString() ??
        widget.driverData?['booking']?['otp']?.toString();
    _deliveryOtp =
        widget.driverData?['deliveryOtp']?.toString() ??
        widget.driverData?['booking']?['deliveryOtp']?.toString();

    if (widget.driverData != null) {
      _driverLocation = SmoothMapMotion.locationFromPayload(widget.driverData);
      _routePoints = SmoothMapMotion.routeFromPayload(widget.driverData!);
      final rawMap = Map<String, dynamic>.from(widget.driverData!);
      Map<String, dynamic> nestedBooking = {};
      if (rawMap['booking'] is Map) {
        nestedBooking = Map<String, dynamic>.from(rawMap['booking'] as Map);
      } else if (rawMap['trip'] is Map) {
        nestedBooking = Map<String, dynamic>.from(rawMap['trip'] as Map);
      }
      _bookingData = {
        ...rawMap,
        ...nestedBooking,
      };
    }
    _loadDriverMarker();

    if (widget.initialState != null) {
      _rideState = widget.initialState!;
      if (_rideState == RideState.verifyOTP) {
        // If driver hasn't picked up yet, we don't show delivery OTP
        _deliveryOtp = null;
        _startWaitingTimer();
      }
    }

    _loadCachedOtps();
    _getCurrentLocation();
    _setupSocketListeners();
    _startLiveTracking();
  }

  Future<void> _loadCachedOtps() async {
    if (widget.tripId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_otp == null || _otp!.isEmpty) {
        final cachedOtp = prefs.getString('pickup_otp_${widget.tripId}');
        if (cachedOtp != null && cachedOtp.isNotEmpty && mounted) {
          setState(() => _otp = cachedOtp);
        }
      }
      if (_deliveryOtp == null || _deliveryOtp!.isEmpty) {
        final cachedDel = prefs.getString('delivery_otp_${widget.tripId}');
        if (cachedDel != null && cachedDel.isNotEmpty && mounted) {
          setState(() => _deliveryOtp = cachedDel);
        }
      }
    } catch (e) {
      debugPrint('Error loading OTPs from cache: $e');
    }
  }

  bool get _isGoods =>
      widget.driverData?['isGoods'] == true ||
      widget.driverData?['moduleType'] == 'GOODS' ||
      widget.driverData?['bookingType'] == 'GOODS' ||
      _bookingData?['isGoods'] == true ||
      _bookingData?['moduleType'] == 'GOODS' ||
      _bookingData?['bookingType'] == 'GOODS';

  Future<void> _loadDriverMarker() async {
    final data = await rootBundle.load(
      _isGoods ? 'assets/images/truck.png' : 'assets/images/car1.png',
    );
    final codec = await instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 20,
      targetHeight: 20,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ImageByteFormat.png);
    if (bytes == null) return;
    final icon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    if (mounted) setState(() => _driverMarkerIcon = icon);
  }

  LatLng? _bookingLocation(String key) {
    final value =
        _bookingData?[key] ??
        widget.driverData?[key] ??
        widget.driverData?['booking']?[key];
    return SmoothMapMotion.locationFromPayload(value);
  }

  Future<void> _checkBookingStatus() async {
    final bookingId = widget.tripId;
    if (bookingId == null || bookingId.isEmpty || _isNavigating) return;
    try {
      final response = await ApiService.to.get(ApiEndpoints.bookingDetails(bookingId));
      if (!mounted || response.data is! Map) return;
      final raw = Map<String, dynamic>.from(response.data as Map);
      final data = raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : raw;
      if (mounted) {
        setState(() {
          final bookingObj = data['booking'] is Map ? Map<String, dynamic>.from(data['booking'] as Map) : {};
          _bookingData = {
            ...?_bookingData,
            ...data,
            ...bookingObj,
          };
        });
      }
      final status = (data['status'] ?? data['booking']?['status'])?.toString().toUpperCase();
      if (status == 'COMPLETED' || status == 'TRIP_COMPLETED' || status == 'PAYMENT_PENDING' || status == 'PAYMENT_COMPLETED') {
        _handleTripCompleted(data);
      } else if (status == 'CANCELLED' || status == 'REJECTED') {
        _trackingTimer?.cancel();
        _handleTripCancelled(data);
      }
    } catch (e) {
      // silent polling error
    }
  }

  void _startLiveTracking() {
    if (widget.tripId == null || widget.tripId!.isEmpty) return;
    if (_isGoods) {
      _fetchGoodsTracking();
      _trackingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _fetchGoodsTracking(silent: true);
        _checkBookingStatus();
      });
      return;
    }
    _fetchRideDriverLocation();
    _trackingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchRideDriverLocation(silent: true);
      _checkBookingStatus();
    });
  }

  Future<void> _fetchRideDriverLocation({bool silent = false}) async {
    final tripId = widget.tripId;
    if (tripId == null || tripId.isEmpty) return;
    try {
      final response = await ApiService.to.get(
        ApiEndpoints.driverLocation(tripId),
      );
      if (!mounted || response.data is! Map) return;
      final raw = Map<String, dynamic>.from(response.data as Map);
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      final target = SmoothMapMotion.locationFromPayload(data);
      if (target != null) _animateDriverTo(target, followCamera: false);
      setState(() {
        if (data['etaMinutes'] != null) {
          _bookingData?['etaMinutes'] = data['etaMinutes'];
        }
        if (data['distanceToTargetKm'] != null) {
          _bookingData?['distanceKm'] = data['distanceToTargetKm'];
        }
      });
    } catch (error) {
      if (error.toString().contains('409') || error.toString().contains('Driver is not assigned yet')) {
        _checkBookingStatus();
      } else if (!silent) {
        debugPrint('Ride tracking fetch failed: $error');
      }
    }
  }

  Future<void> _fetchGoodsTracking({bool silent = false}) async {
    final bookingId = widget.tripId;
    if (bookingId == null || bookingId.isEmpty) return;
    try {
      final response = await ApiService.to.get(
        ApiEndpoints.goodsTracking(bookingId),
      );
      if (!mounted || response.data is! Map) return;
      final raw = Map<String, dynamic>.from(response.data as Map);
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      final booking = data['booking'] is Map
          ? Map<String, dynamic>.from(data['booking'] as Map)
          : <String, dynamic>{};
      final tracking = data['tracking'] is Map
          ? Map<String, dynamic>.from(data['tracking'] as Map)
          : <String, dynamic>{};
      final currentLocation = data['currentLocation'] is Map
          ? Map<String, dynamic>.from(data['currentLocation'] as Map)
          : <String, dynamic>{};
      final lat = double.tryParse(
        (currentLocation['latitude'] ?? currentLocation['lat'])?.toString() ??
            '',
      );
      final lng = double.tryParse(
        (currentLocation['longitude'] ?? currentLocation['lng'])?.toString() ??
            '',
      );

      setState(() {
        _bookingData = {
          ...?_bookingData,
          ...booking,
          if (tracking['distanceKm'] != null)
            'distanceKm': tracking['distanceKm'],
          if (tracking['estimatedDurationMin'] != null)
            'estimatedDurationMin': tracking['estimatedDurationMin'],
          if (tracking['etaMinutes'] != null)
            'etaMinutes': tracking['etaMinutes'],
        };
        _deliveryOtp =
            data['deliveryOtp']?.toString() ??
            booking['deliveryOtp']?.toString() ??
            _deliveryOtp;
        _otp =
            data['pickupOtp']?.toString() ??
            booking['pickupOtp']?.toString() ??
            data['otp']?.toString() ??
            booking['otp']?.toString() ??
            data['rideStartOtp']?.toString() ??
            booking['rideStartOtp']?.toString() ??
            _otp;
        final routePoints = SmoothMapMotion.routeFromPayload(data);
        if (routePoints.isNotEmpty) _routePoints = routePoints;
        final status = (booking['status'] ?? data['status'])?.toString();
        if (status == 'IN_TRANSIT' ||
            status == 'ARRIVED_DESTINATION' ||
            status == 'DELIVERED' ||
            status == 'PAYMENT_PENDING') {
          _waitingTimer?.cancel();
          _rideState = RideState.inProgress;
        }
      });
      final goodsStatus =
          (booking['status'] ?? data['status'] ?? _bookingData?['status'])
              ?.toString();
      if (_deliveryOtp == null &&
          (goodsStatus == 'ARRIVED_DESTINATION' ||
              goodsStatus == 'DELIVERED' ||
              goodsStatus == 'PAYMENT_PENDING')) {
        unawaited(_recoverGoodsDeliveryOtp());
      }
      if (lat != null && lng != null) {
        _animateDriverTo(LatLng(lat, lng), followCamera: false);
      }
      _updateMapCamera();
    } catch (error) {
      if (!silent) {
        debugPrint('Goods tracking fetch failed: $error');
      }
    }
  }

  void _startWaitingTimer() {
    if (widget.driverData != null &&
        widget.driverData!.containsKey('arrivedAt') &&
        widget.driverData!['arrivedAt'] != null) {
      try {
        final arrivedTime = DateTime.parse(
          widget.driverData!['arrivedAt'].toString(),
        );
        final diff = DateTime.now().difference(arrivedTime);
        _waitingSeconds = diff.inSeconds > 0 ? diff.inSeconds : 0;
      } catch (e) {
        print('Error parsing arrivedAt: $e');
        _waitingSeconds = 0;
      }
    }

    _waitingTimer?.cancel();
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _waitingSeconds++;
      });
    });
  }

  void _handleDriverArrived(dynamic data) {
    print('--- [SOCKET_IO] Received Driver Arrived: $data ---');
    if (!mounted || !_isCurrentBookingEvent(data)) return;

    Map<String, dynamic>? newBookingData;
    if (data is List && data.isNotEmpty && data[0] is Map) {
      final payload = data[0] as Map;
      if (payload.containsKey('booking')) {
        newBookingData = Map<String, dynamic>.from(payload['booking']);
      }
    } else if (data is Map && data.containsKey('booking')) {
      newBookingData = Map<String, dynamic>.from(data['booking']);
    }

    _startWaitingTimer();
    setState(() {
      if (newBookingData != null) {
        _bookingData = {
          ...?_bookingData,
          ...newBookingData,
        };
      }
      _rideState = RideState.verifyOTP;
    });
    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Driver Arrived',
        body: 'Your driver has arrived at the pickup location.',
        type: 'DRIVER_ARRIVED',
        bookingId: widget.tripId,
      );
    }
    AppUtils.showSnackBar(
      context,
      'Your driver has arrived at the pickup location!',
    );
  }

  void _handleTripStarted(dynamic data) {
    print('--- [SOCKET_IO] Received Trip Started: $data ---');
    if (!mounted || !_isCurrentBookingEvent(data)) return;
    _waitingTimer?.cancel();

    Map<String, dynamic>? bookingData;
    if (data is List && data.isNotEmpty && data[0] is Map) {
      final payload = data[0] as Map;
      if (payload.containsKey('booking')) {
        bookingData = Map<String, dynamic>.from(payload['booking']);
      }
    } else if (data is Map && data.containsKey('booking')) {
      bookingData = Map<String, dynamic>.from(data['booking']);
    }

    setState(() {
      if (bookingData != null) {
        _bookingData = {
          ...?_bookingData,
          ...bookingData,
        };
      }
      _rideState = RideState.inProgress;
    });
    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Ride Started',
        body: 'Your ride has started.',
        type: 'RIDE_STARTED',
        bookingId: widget.tripId,
      );
    }
    AppUtils.showSnackBar(context, 'Your trip has started!');
  }

  void _handleTripCompleted(dynamic data) {
    print('--- [SOCKET_IO] Received Trip Completed: $data ---');
    if (!mounted || _isNavigating || !_isCurrentBookingEvent(data)) return;
    _isNavigating = true;
    _trackingTimer?.cancel();

    final mergedData = {
      if (widget.driverData != null) ...widget.driverData!,
      if (_bookingData != null) ..._bookingData!,
    };

    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Ride Completed',
        body: 'Your ride has been completed successfully.',
        type: 'RIDE_COMPLETED',
        bookingId: widget.tripId,
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PaymentScreen(bookingId: widget.tripId, driverData: mergedData),
      ),
    );
  }

  void _setupSocketListeners() {
    print(
      '--- [SOCKET_IO] Setting up tracking listeners for Trip ID: ${widget.tripId} ---',
    );

    final bookingId = widget.tripId;
    if (bookingId != null && bookingId.isNotEmpty) {
      SocketService.to.trackBooking(bookingId: bookingId);
    }

    SocketService.to.listenTo(SocketEvents.driverArrived, _handleDriverArrived);
    SocketService.to.listenTo(
      SocketEvents.goodsDriverArrived,
      _handleDriverArrived,
    );
    SocketService.to.listenTo(
      'goods:driver:arrived_pickup',
      _handleDriverArrived,
    );
    SocketService.to.listenTo(
      'goods.driver.arrived_pickup',
      _handleDriverArrived,
    );

    SocketService.to.listenTo(SocketEvents.tripStarted, _handleTripStarted);
    SocketService.to.listenTo(
      SocketEvents.goodsTripStarted,
      _handleTripStarted,
    );
    SocketService.to.listenTo('goods:booking:start', _handleTripStarted);
    SocketService.to.listenTo('goods.booking.start', _handleTripStarted);

    SocketService.to.listenTo('trip:completed', _handleTripCompleted);
    SocketService.to.listenTo('booking:completed', _handleTripCompleted);
    SocketService.to.listenTo('payment:updated', _handleTripCompleted);
    SocketService.to.listenTo('payment:pending', _handleTripCompleted);
    SocketService.to.listenTo(SocketEvents.tripCompleted, _handleTripCompleted);
    SocketService.to.listenTo(
      SocketEvents.goodsCompleted,
      _handleTripCompleted,
    );
    SocketService.to.listenTo('goods:booking:complete', _handleTripCompleted);
    SocketService.to.listenTo('goods.booking.complete', _handleTripCompleted);
    SocketService.to.listenTo('goods.completed', _handleTripCompleted);
    SocketService.to.listenTo('goods.trip.ended', _handleTripCompleted);

    SocketService.to.listenTo('trip:otp-generated', _handleOtpReceived);
    SocketService.to.listenTo('trip.otp-generated', _handleOtpReceived);
    SocketService.to.listenTo('booking:driver-assigned', _handleOtpReceived);
    SocketService.to.listenTo('trip:otp', _handleOtpReceived);
    SocketService.to.listenTo('goods.pickup.otp.sent', _handleOtpReceived);
    SocketService.to.listenTo('goods:pickup:otp', _handleOtpReceived);
    SocketService.to.listenTo('goods.pickup.otp.required', _handleOtpReceived);
    SocketService.to.listenTo(
      SocketEvents.goodsDeliveryOtpSent,
      _handleDeliveryOtpReceived,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsDriverReachedDestination,
      _handleDeliveryOtpReceived,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsLocationUpdated,
      _handleGoodsLocationUpdated,
    );

    SocketService.to.listenTo(
      SocketEvents.tripCancelled,
      _handleTripCancelled,
      triggerCached: false,
    );
    SocketService.to.listenTo(
      'goods.booking.cancelled',
      _handleTripCancelled,
      triggerCached: false,
    );
    SocketService.to.listenTo(
      SocketEvents.tripCancelledByUser,
      _handleTripCancelledByUser,
      triggerCached: false,
    );
  }

  void _handleGoodsLocationUpdated(dynamic data) {
    if (!_isCurrentBookingEvent(data)) return;
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is! Map) return;
    final location = payload['location'] is Map
        ? payload['location']
        : payload['currentLocation'] is Map
        ? payload['currentLocation']
        : payload;
    final lat = double.tryParse(
      (location['latitude'] ?? location['lat'])?.toString() ?? '',
    );
    final lng = double.tryParse(
      (location['longitude'] ?? location['lng'])?.toString() ?? '',
    );
    if (!mounted || lat == null || lng == null) return;
    setState(() {
      final tracking = payload['tracking'];
      if (tracking is Map) {
        if (tracking['distanceKm'] != null) {
          _bookingData?['distanceKm'] = tracking['distanceKm'];
        }
        if (tracking['estimatedDurationMin'] != null) {
          _bookingData?['estimatedDurationMin'] =
              tracking['estimatedDurationMin'];
        }
        if (tracking['etaMinutes'] != null) {
          _bookingData?['etaMinutes'] = tracking['etaMinutes'];
        }
      }
    });
    _animateDriverTo(LatLng(lat, lng));
  }

  void _handleOtpReceived(dynamic data) {
    if (!mounted || !_isCurrentBookingEvent(data)) return;
    if (data is Map && data['otp'] != null) {
      setState(() {
        _otp = data['otp'].toString();
      });
      _saveOtpToCache('pickup', _otp!);
    } else if (data is List &&
        data.isNotEmpty &&
        data.first is Map &&
        data.first['otp'] != null) {
      setState(() {
        _otp = data.first['otp'].toString();
      });
      _saveOtpToCache('pickup', _otp!);
    }
  }

  void _handleDeliveryOtpReceived(dynamic data) {
    if (!mounted || !_isCurrentBookingEvent(data)) return;
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is! Map) return;
    final otp =
        payload['deliveryOtp'] ??
        payload['otp'] ??
        payload['booking']?['deliveryOtp'];
    if (otp == null || otp.toString().isEmpty) {
      unawaited(_recoverGoodsDeliveryOtp());
      return;
    }
    setState(() {
      _deliveryOtp = otp.toString();
      if (_bookingData != null) {
        _bookingData!['deliveryOtp'] = _deliveryOtp;
      }
    });
    _saveOtpToCache('delivery', _deliveryOtp!);
    // The OTP is shown inline on the screen, so we don't force open the popup.
  }

  Future<void> _recoverGoodsDeliveryOtp() async {
    final bookingId = widget.tripId;
    if (!mounted ||
        bookingId == null ||
        bookingId.isEmpty ||
        _isRecoveringGoodsDeliveryOtp ||
        (_deliveryOtp?.isNotEmpty ?? false)) {
      return;
    }

    _isRecoveringGoodsDeliveryOtp = true;
    try {
      final response = await ApiService.to.get(
        ApiEndpoints.goodsBookingDetails(bookingId),
      );
      if (!mounted || response.data is! Map) return;
      final responseMap = Map<String, dynamic>.from(response.data as Map);
      final rawData = responseMap['data'];
      if (rawData is! Map) return;
      final booking = Map<String, dynamic>.from(rawData);
      final otp =
          booking['deliveryOtp'] ??
          booking['otp']?['deliveryOtp'] ??
          booking['otp']?['delivery'];

      setState(() {
        _bookingData = {...?_bookingData, ...booking};
        if (otp != null && otp.toString().isNotEmpty) {
          _deliveryOtp = otp.toString();
        }
      });
      if (_deliveryOtp != null && _deliveryOtp!.isNotEmpty) {
        await _saveOtpToCache('delivery', _deliveryOtp!);
      }
    } catch (error) {
      debugPrint('Delivery OTP recovery failed: $error');
    } finally {
      _isRecoveringGoodsDeliveryOtp = false;
    }
  }

  Future<void> _saveOtpToCache(String type, String otp) async {
    if (widget.tripId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${type}_otp_${widget.tripId}', otp);
    } catch (e) {
      debugPrint('Error saving OTP to cache: $e');
    }
  }

  void _updateMapCamera() {
    if (_driverLocation != null && _mapController != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _driverLocation!, zoom: 15),
        ),
      );
    }
  }

  void _handleDriverLocation(dynamic data) {
    print('--- [SOCKET_IO] Received DRIVER_LOCATION: $data ---');
    if (!mounted || !_isCurrentBookingEvent(data)) return;
    final target = SmoothMapMotion.locationFromPayload(data);
    if (target != null) _animateDriverTo(target);
  }

  void _animateDriverTo(LatLng target, {bool followCamera = true}) {
    _mapMotion.move(
      from: _driverLocation,
      to: target,
      onUpdate: (position, bearing) {
        if (!mounted) return;
        setState(() {
          _driverLocation = position;
          _driverBearing = bearing;
        });
      },
    );
    if (followCamera) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16, bearing: _driverBearing),
        ),
      );
    }
  }

  void _handleTripCancelled(dynamic data) {
    print('--- [SOCKET_IO] Received TRIP_CANCELLED: $data ---');
    if (!mounted || _isNavigating) return;
    if (!_isCurrentBookingEvent(data)) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final payload = data is List ? (data.isNotEmpty ? data.first : {}) : data;
    final booking = payload is Map ? payload['booking'] : null;

    // If the user cancelled it themselves, the CancelRideScreen will handle the UI
    if (booking is Map && booking['cancelledBy'] == 'USER') return;
    if (payload is Map && payload['cancelledBy'] == 'USER') return;

    _isNavigating = true;
    _trackingTimer?.cancel();

    final reason = payload?['message'] ?? (payload is Map ? payload['reason'] : null) ?? 'The driver has cancelled this trip.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.redAccent, size: 28.sp),
            SizedBox(width: 10.w),
            Text(
              'Ride Cancelled',
              style: AppFonts.h2.copyWith(
                fontSize: 18.sp,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        content: Text(
          reason,
          style: AppFonts.bodyText.copyWith(color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ABE4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainNavigationScreen(),
                ),
                (route) => false,
              );
            },
            child: Text(
              'OK',
              style: AppFonts.buttonText.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTripCancelledByUser(dynamic data) {
    print('--- [SOCKET_IO] Received TRIP_CANCELLED_BY_USER: $data ---');
    if (!mounted || !_isCurrentBookingEvent(data)) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final payload = data is List ? (data.isNotEmpty ? data.first : {}) : data;
    final booking = payload is Map ? payload['booking'] : null;

    // If the user cancelled it themselves, the CancelRideScreen will handle the UI
    if (booking is Map && booking['cancelledBy'] == 'USER') return;
    if (payload is Map && payload['cancelledBy'] == 'USER') return;

    final reason = payload?['message'] ?? 'The user has cancelled this trip.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.redAccent, size: 28.sp),
            SizedBox(width: 10.w),
            Text(
              'Ride Cancelled',
              style: AppFonts.h2.copyWith(
                fontSize: 18.sp,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        content: Text(
          reason,
          style: AppFonts.bodyText.copyWith(color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ABE4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainNavigationScreen(),
                ),
                (route) => false,
              );
            },
            child: Text(
              'OK',
              style: AppFonts.buttonText.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error fetching location: \$e");
    }
  }

  @override
  void dispose() {
    final bookingId = widget.tripId;
    if (bookingId != null && bookingId.isNotEmpty) {
      SocketService.to.untrackBooking(bookingId: bookingId);
    }
    _mapMotion.dispose();
    _waitingTimer?.cancel();
    _trackingTimer?.cancel();
    _mapController?.dispose();
    SocketService.to.stopListening(
      SocketEvents.driverArrived,
      _handleDriverArrived,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsDriverArrived,
      _handleDriverArrived,
    );
    SocketService.to.stopListening(
      'goods:driver:arrived_pickup',
      _handleDriverArrived,
    );
    SocketService.to.stopListening(
      'goods.driver.arrived_pickup',
      _handleDriverArrived,
    );

    SocketService.to.stopListening(
      SocketEvents.tripStarted,
      _handleTripStarted,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsTripStarted,
      _handleTripStarted,
    );
    SocketService.to.stopListening('goods:booking:start', _handleTripStarted);
    SocketService.to.stopListening('goods.booking.start', _handleTripStarted);

    SocketService.to.stopListening(
      SocketEvents.tripCompleted,
      _handleTripCompleted,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsCompleted,
      _handleTripCompleted,
    );
    SocketService.to.stopListening(
      'goods:booking:complete',
      _handleTripCompleted,
    );
    SocketService.to.stopListening(
      'goods.booking.complete',
      _handleTripCompleted,
    );

    SocketService.to.stopListening(
      SocketEvents.tripCancelled,
      _handleTripCancelled,
    );
    SocketService.to.stopListening(
      SocketEvents.tripCancelledByUser,
      _handleTripCancelledByUser,
    );
    SocketService.to.stopListening(
      SocketEvents.driverLocation,
      _handleDriverLocation,
    );
    SocketService.to.stopListening('trip:otp-generated', _handleOtpReceived);
    SocketService.to.stopListening('trip.otp-generated', _handleOtpReceived);
    SocketService.to.stopListening('booking:driver-assigned', _handleOtpReceived);
    SocketService.to.stopListening('trip:otp', _handleOtpReceived);
    SocketService.to.stopListening('goods.pickup.otp.sent', _handleOtpReceived);
    SocketService.to.stopListening('goods:pickup:otp', _handleOtpReceived);
    SocketService.to.stopListening(
      'goods.pickup.otp.required',
      _handleOtpReceived,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsDeliveryOtpSent,
      _handleDeliveryOtpReceived,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsDriverReachedDestination,
      _handleDeliveryOtpReceived,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsLocationUpdated,
      _handleGoodsLocationUpdated,
    );
    super.dispose();
  }

  void _showCancelPopup() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Widget buildButton({
          required String label,
          required Color color,
          required Color textColor,
          required VoidCallback onPressed,
        }) {
          return SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: onPressed,
              child: Text(
                label,
                style: AppFonts.buttonText.copyWith(
                  color: textColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.fromLTRB(
            14.w,
            10.h,
            14.w,
            MediaQuery.of(sheetContext).padding.bottom + 16.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              SizedBox(height: 26.h),
              Text(
                'Cancel Ride?',
                style: AppFonts.h2.copyWith(
                  color: Colors.black,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Driver has already been assigned.\nCancellation charges may apply.',
                textAlign: TextAlign.center,
                style: AppFonts.captionDark.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 12.sp,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 28.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.redAccent,
                      size: 22.sp,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'If you cancel now, a cancellation fee may be deducted from your payment',
                        style: AppFonts.captionDark.copyWith(
                          color: Colors.black87,
                          fontSize: 11.sp,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 26.h),
              buildButton(
                label: 'Cancel Ride',
                color: const Color(0xFFFF2D2D),
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  CancellationReasonDrawer.show(
                    context,
                    tripId: widget.tripId ?? '',
                  );
                },
              ),
              SizedBox(height: 10.h),
              buildButton(
                label: 'Keep Ride',
                color: const Color(0xFFF0FBFE),
                textColor: Colors.black,
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AppUtils.showSnackBar(
          context,
          'Ride is in progress. You can cancel or wait until completion.',
        );
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: Stack(
        children: [
          // Background Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.7041, 77.1025), // Default to Delhi
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: {
                if (_bookingLocation('pickup') != null)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: _bookingLocation('pickup')!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: const InfoWindow(title: 'Pickup'),
                  ),
                if (_bookingLocation('drop') != null)
                  Marker(
                    markerId: const MarkerId('drop'),
                    position: _bookingLocation('drop')!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                    infoWindow: const InfoWindow(title: 'Drop'),
                  ),
                if (_driverLocation != null)
                  Marker(
                    markerId: const MarkerId('driver_vehicle'),
                    position: _driverLocation!,
                    rotation: _driverBearing,
                    flat: true,
                    icon:
                        _driverMarkerIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                    infoWindow: const InfoWindow(title: 'Driver Location'),
                  ),
              },
              polylines: {
                if (_routePoints.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('active_route'),
                    points: _routePoints,
                    color: const Color(0xFF1489F5),
                    width: 6,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
                final routeBounds = SmoothMapMotion.boundsFor([
                  ..._routePoints,
                  if (_driverLocation != null) _driverLocation!,
                ]);
                if (routeBounds != null) {
                  Future<void>.delayed(const Duration(milliseconds: 250), () {
                    if (mounted) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngBounds(routeBounds, 64),
                      );
                    }
                  });
                } else if (_currentPosition != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          _buildMapOverlays(),
          _buildTopActionButtons(),
          _buildBottomSheet(),
        ],
      ),
    ),
  );
}

  Future<void> _openExternalNavigation(double lat, double lng) async {
    final Uri googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final Uri webNavUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri);
      } else {
        await launchUrl(webNavUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error opening navigation: $e");
    }
  }

  Widget _buildTopActionButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10.h,
      left: 20.w,
      right: 20.w,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20.r,
                  child: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),
              if (_rideState == RideState.inProgress) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_bookingData != null ? (_bookingData!['distanceKm'] ?? _bookingData!['distance'] ?? '--') : '--'} km left',
                        style: AppFonts.bodyText.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_bookingData != null ? (_bookingData!['estimatedDurationMin'] ?? _bookingData!['duration'] ?? _bookingData!['etaMinutes'] ?? '--') : '--'} min',
                        style: AppFonts.captionDark.copyWith(
                          color: const Color(0xFF00ABE4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final drop =
                      _bookingData?['drop'] ??
                      _bookingData?['dropLocation'] ??
                      widget.driverData?['drop'] ??
                      {};
                  final pickup =
                      _bookingData?['pickup'] ??
                      _bookingData?['pickupLocation'] ??
                      widget.driverData?['pickup'] ??
                      {};
                  final targetMap = _rideState == RideState.inProgress
                      ? drop
                      : pickup;
                  final double? lat = double.tryParse(
                    targetMap['latitude']?.toString() ??
                        targetMap['lat']?.toString() ??
                        '',
                  );
                  final double? lng = double.tryParse(
                    targetMap['longitude']?.toString() ??
                        targetMap['lng']?.toString() ??
                        '',
                  );
                  if (lat != null && lng != null) {
                    _openExternalNavigation(lat, lng);
                  } else if (_currentPosition != null) {
                    _openExternalNavigation(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.near_me, color: Colors.white, size: 16.sp),
                      SizedBox(width: 4.w),
                      Text(
                        'Navigation',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_rideState == RideState.arriving ||
                  _rideState == RideState.verifyOTP) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'OTP',
                        style: AppFonts.captionDark.copyWith(fontSize: 10.sp),
                      ),
                      Text(
                        '${_otp ?? '----'}',
                        style: AppFonts.h2.copyWith(
                          fontSize: 14.sp,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapOverlays() {
    final etaText = _calculateEtaOnly();
    final statusTitle = _rideState == RideState.inProgress
        ? 'Driver is on the way'
        : _rideState == RideState.verifyOTP
            ? 'Driver has arrived'
            : 'Driver is on the way';

    return Positioned(
      top: MediaQuery.of(context).padding.top + 55.h,
      left: 16.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              statusTitle,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                color: Colors.black,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2.h),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  color: Colors.black54,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Arriving in '),
                  TextSpan(
                    text: etaText,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      color: const Color(0xFFFFB300),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 10.h,
                    right: 14.w,
                    bottom: 10.h,
                    left: 14.w,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          width: 44.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      if (_rideState == RideState.arriving)
                        _buildArrivingState(),
                      if (_rideState == RideState.verifyOTP)
                        _buildVerifyOTPState(),
                      if (_rideState == RideState.inProgress)
                        _buildInProgressState(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildFixedBottomAction(),
        ],
      ),
    );
  }

  Widget _buildFixedBottomAction() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: 16.h,
        left: 20.w,
        right: 20.w,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 20.h,
      ),
      decoration: const BoxDecoration(color: Colors.white),
      child: _rideState == RideState.verifyOTP
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [_buildCancelRideButton()],
            )
          : _rideState == RideState.inProgress
          ? const SizedBox()
          : _buildEmergencySOSContent(),
    );
  }

  Widget _buildFixedCompleteTripButton() {
    return SizedBox(
      width: double.infinity,
      height: 46.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00ABE4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        onPressed: () {
          _showTripCompletePopup();
        },
        child: Text(
          'Complete Trip',
          style: AppFonts.buttonText.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencySOSContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 46.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF2FBFE),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(
                  color: const Color(0xFF00ABE4).withOpacity(0.2),
                ),
              ),
            ),
            onPressed: () {
              setState(() {
                _rideState = RideState.verifyOTP;
              });
            },
            child: Text(
              'Wait for Driver',
              style: AppFonts.buttonText.copyWith(
                color: const Color(0xFF00ABE4),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          '24x7 Safety Support',
          style: AppFonts.captionDark.copyWith(
            color: Colors.grey.shade700,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelRideButton() {
    return SizedBox(
      width: double.infinity,
      height: 46.h,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          backgroundColor: const Color(0xFFFEF2F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        onPressed: () => _showCancelPopup(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel_outlined,
              color: const Color(0xFFEF4444),
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Cancel Ride',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareTripPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16.h),
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                    Text(
                      'Share Trip',
                      style: AppFonts.h1.copyWith(
                        fontSize: 18.sp,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Share your live trip details with your friends and family',
                      style: AppFonts.captionDark.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF00ABE4).withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6F9),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16.r),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Trip Tracking',
                                  style: AppFonts.bodyText.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Your live location will be share unit the trip ends.',
                                  style: AppFonts.captionDark.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16.r),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildShareRow(
                                  'Driver',
                                  _getDriverName(),
                                  imageAsset: AppAssets.profileImage,
                                ),
                                SizedBox(height: 16.h),
                                _buildShareRow(
                                  'Vehicle',
                                  '${_readValue([_vehicle['type'], _vehicle['vehicleType'], _vehicle['vehicleName'], widget.driverData?['carName']]) ?? 'Vehicle'} ${_readValue([_vehicle['color'], widget.driverData?['vehicleColor']]) ?? ''}'
                                      .trim(),
                                  imageAsset: AppAssets.carImage,
                                ),
                                SizedBox(height: 16.h),
                                _buildShareRow(
                                  'Vehicle No',
                                  (_readValue([
                                            _vehicle['plateNumber'],
                                            _vehicle['vehicleNumber'],
                                            widget.driverData?['vehicleNumber'],
                                          ]) ??
                                          'Vehicle No')
                                      .toString(),
                                  imageAsset: AppAssets.carImage,
                                ),
                                SizedBox(height: 16.h),
                                _buildShareRow(
                                  'Trip Rout',
                                  'B-52 Business Park, Sector 62\n→ Sector 62 Metro Station, Noida',
                                  icon: Icons.location_on,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildShareIcon(
                          Icons.call,
                          'WhatsApp',
                          Colors.green,
                          const Color(0xFFE8F5E9),
                        ),
                        _buildShareIcon(
                          Icons.chat,
                          'SMS',
                          Colors.white,
                          Colors.green,
                        ),
                        _buildShareIcon(
                          Icons.link,
                          'Copy Link',
                          const Color(0xFF00ABE4),
                          const Color(0xFFE6F7FD),
                        ),
                        _buildShareIcon(
                          Icons.more_horiz,
                          'More',
                          Colors.black,
                          Colors.grey.shade100,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: 14.h,
                  left: 12.w,
                  right: 12.w,
                  bottom: MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom + 14.h
                      : 14.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 17,
                      offset: const Offset(0, -13),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 46.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2FBFE),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppFonts.buttonText.copyWith(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareRow(
    String label,
    String value, {
    IconData? icon,
    String? imageAsset,
  }) {
    return Row(
      children: [
        Container(
          width: 55.w,
          height: 55.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.65.r),
            border: Border.all(
              color: const Color(0xFF00ABE4).withOpacity(0.20),
              width: 0.46.w,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF00ABE4).withOpacity(0.10),
                const Color(0xFF00ABE4).withOpacity(0.0),
              ],
            ),
          ),
          child: imageAsset != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6.65.r),
                  child: Image.asset(imageAsset, fit: BoxFit.cover),
                )
              : Icon(icon, color: const Color(0xFF00ABE4), size: 24.sp),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.captionDark.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: AppFonts.bodyText.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShareIcon(
    IconData icon,
    String label,
    Color iconColor,
    Color bgColor,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24.r,
          backgroundColor: bgColor,
          child: Icon(icon, color: iconColor),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: AppFonts.captionDark.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ==== STATE WIDGETS ====

  Widget _buildArrivingState() {
    return Column(
      children: [
        _buildDriverInfo(),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.only(
            top: 15.h,
            right: 15.w,
            bottom: 15.h,
            left: 20.w,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF00ABE4).withOpacity(0.2)),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Column(
            children: [
              // Green Banner
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F3),
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 4.w,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2F0E5),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF16A34A),
                        radius: 8.r,
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your driver is on the way to pickup location',
                            style: AppFonts.bodyText.copyWith(
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Please be ready at the pickup point',
                            style: AppFonts.captionDark.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              _buildRouteTimeline(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOTPState() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50.w,
              height: 50.w,
              child: CircularProgressIndicator(
                value: (_waitingSeconds % 60) / 60,
                strokeWidth: 3.w,
                backgroundColor: const Color(0xFFE6F7FD),
                color: const Color(0xFF00ABE4),
              ),
            ),
            Text(
              '${(_waitingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_waitingSeconds % 60).toString().padLeft(2, '0')}',
              style: AppFonts.captionDark.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          'Waiting Time',
          style: AppFonts.captionDark.copyWith(
            fontSize: 11.sp,
            color: const Color(0xFF00ABE4),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 20.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7FD),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF00ABE4).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share OTP with Driver',
                    style: AppFonts.captionDark.copyWith(
                      color: Colors.grey.shade800,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Driver will ask for this to start ride',
                    style: AppFonts.captionDark.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ABE4),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _otp ?? '----',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FDFF),
            border: Border.all(color: const Color(0xFF00ABE4).withOpacity(0.2)),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: const Color(0xFFD6F0FA),
                child: Icon(
                  Icons.verified,
                  color: const Color(0xFF00ABE4),
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'For your safety, never share this OTP with anyone else.',
                  style: AppFonts.captionDark.copyWith(color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        GestureDetector(
          onTap: () {
            setState(() {
              _rideState = RideState.inProgress;
            });
          },
          child: _buildDriverInfo(),
        ),
      ],
    );
  }

  String _calculateEtaOnly() {
    final serverEta = _readValue([
      _bookingData?['driverEtaMinutes'],
      _bookingData?['etaMinutes'],
      _bookingData?['estimatedDurationMin'],
      _bookingData?['driver']?['etaMinutes'],
      _bookingData?['booking']?['driverEtaMinutes'],
      _bookingData?['booking']?['etaMinutes'],
    ]);
    if (serverEta != null) {
      final text = serverEta.toString().replaceAll(RegExp(r'[^\d]'), '');
      if (text.isNotEmpty) return '$text min';
    }
    if (_driverLocation == null) return '3 min';

    final targetLat = _rideState == RideState.inProgress
        ? double.tryParse(_bookingData?['dropLat']?.toString() ?? '')
        : double.tryParse(_bookingData?['pickupLat']?.toString() ?? '');
    final targetLng = _rideState == RideState.inProgress
        ? double.tryParse(_bookingData?['dropLng']?.toString() ?? '')
        : double.tryParse(_bookingData?['pickupLng']?.toString() ?? '');

    if (targetLat != null && targetLng != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        targetLat,
        targetLng,
        _driverLocation!.latitude,
        _driverLocation!.longitude,
      );
      int minutes = (distanceInMeters / 500).ceil();
      if (minutes <= 0) return '1 min';
      return '$minutes min';
    }
    return '3 min';
  }

  String _getRemainingDistance() {
    final distValue = _readValue([
      _bookingData?['distanceKm'],
      _bookingData?['distance'],
      _bookingData?['distanceToTargetKm'],
      _bookingData?['booking']?['distanceKm'],
    ]);
    if (distValue != null && distValue.toString().trim().isNotEmpty) {
      final text = distValue.toString().trim();
      if (text.contains('km')) return text;
      return '$text km';
    }
    if (_driverLocation != null) {
      final targetLat = _rideState == RideState.inProgress
          ? double.tryParse(_bookingData?['dropLat']?.toString() ?? '')
          : double.tryParse(_bookingData?['pickupLat']?.toString() ?? '');
      final targetLng = _rideState == RideState.inProgress
          ? double.tryParse(_bookingData?['dropLng']?.toString() ?? '')
          : double.tryParse(_bookingData?['pickupLng']?.toString() ?? '');
      if (targetLat != null && targetLng != null) {
        double distMeters = Geolocator.distanceBetween(
          targetLat,
          targetLng,
          _driverLocation!.latitude,
          _driverLocation!.longitude,
        );
        return '${(distMeters / 1000).toStringAsFixed(1)} km';
      }
    }
    return '2.5 km';
  }

  String _getPickupAddress() {
    final val = _readValue([
      _bookingData?['pickupAddress'],
      _bookingData?['pickupLocation']?['address'],
      _bookingData?['pickupLocationName'],
      _bookingData?['pickup']?['address'],
      widget.driverData?['pickupAddress'],
    ]);
    return val?.toString().trim() ?? 'Pickup Location';
  }

  String _getDropAddress() {
    final val = _readValue([
      _bookingData?['dropAddress'],
      _bookingData?['dropLocation']?['address'],
      _bookingData?['destinationAddress'],
      _bookingData?['dropLocationName'],
      _bookingData?['drop']?['address'],
      widget.driverData?['dropAddress'],
    ]);
    return val?.toString().trim() ?? 'Your Destination';
  }

  String _getRideFare() {
    final val = _readValue([
      _bookingData?['finalFare'],
      _bookingData?['totalFare'],
      _bookingData?['totalAmount'],
      _bookingData?['fare'],
      _bookingData?['estimatedFare'],
      _bookingData?['amount'],
      _bookingData?['price'],
      _bookingData?['rideFare'],
      _bookingData?['booking']?['finalFare'],
      _bookingData?['booking']?['totalFare'],
      _bookingData?['booking']?['totalAmount'],
      _bookingData?['booking']?['fare'],
      _bookingData?['booking']?['estimatedFare'],
      widget.driverData?['finalFare'],
      widget.driverData?['totalFare'],
      widget.driverData?['totalAmount'],
      widget.driverData?['fare'],
      widget.driverData?['estimatedFare'],
      widget.driverData?['booking']?['fare'],
      widget.driverData?['booking']?['totalFare'],
      widget.driverData?['booking']?['finalFare'],
    ]);
    if (val != null && val.toString().trim().isNotEmpty) {
      final str = val.toString().replaceAll('₹', '').trim();
      return '₹$str';
    }
    return '₹--';
  }

  String _getPaymentMethod() {
    final method = _readValue([
      _bookingData?['paymentMethod'],
      _bookingData?['paymentType'],
      _bookingData?['payment']?['method'],
      widget.driverData?['paymentMethod'],
    ])?.toString().toUpperCase() ?? 'CASH';

    if (method.contains('ONLINE') ||
        method.contains('CARD') ||
        method.contains('UPI') ||
        method.contains('WALLET')) {
      return 'Online Payment';
    }
    return 'Cash';
  }

  String _getFallbackVehicleImageAsset(Map<String, dynamic> vehicle) {
    final typeStr = ([
      _bookingData?['bookingType'],
      _bookingData?['moduleType'],
      _bookingData?['vehicleType'],
      _bookingData?['carType'],
      _bookingData?['vehicleCategory']?['name'],
      _bookingData?['vehicleCategory']?['type'],
      _bookingData?['category']?['name'],
      _bookingData?['carName'],
      vehicle['vehicleType'],
      vehicle['type'],
      vehicle['category']?['name'],
      vehicle['category']?['type'],
      vehicle['make'],
      vehicle['model'],
      vehicle['vehicleModel'],
    ].where((e) => e != null).join(' ')).toUpperCase();

    if (typeStr.contains('BIKE') ||
        typeStr.contains('MOTORCYCLE') ||
        typeStr.contains('SCOOTER') ||
        typeStr.contains('TWO_WHEELER') ||
        typeStr.contains('ACTIVA') ||
        typeStr.contains('PULSAR') ||
        typeStr.contains('SPLENDOR')) {
      return 'assets/images/Bike1.png';
    } else if (typeStr.contains('RICKSHAW') ||
        typeStr.contains('AUTO') ||
        typeStr.contains('TUKTUK') ||
        typeStr.contains('THREE_WHEELER')) {
      return 'assets/images/rickshawnew.png';
    } else if (typeStr.contains('TRUCK') ||
        typeStr.contains('GOODS') ||
        typeStr.contains('PICKUP') ||
        _bookingData?['isGoods'] == true) {
      return 'assets/images/truck.png';
    } else {
      return 'assets/images/car1.png';
    }
  }

  Widget _buildDriverInfoCard() {
    final driver = _driver;
    String? driverImage = _readValue([
      driver['profileImageUrl'],
      driver['profileImage'],
      driver['profilePicture'],
      driver['image'],
      driver['avatar'],
      driver['driverProfile']?['profileImageUrl'],
      driver['driverProfile']?['profileImage'],
      driver['driverProfile']?['profilePicture'],
      driver['driverProfile']?['avatar'],
      driver['user']?['profileImageUrl'],
      driver['user']?['profileImage'],
      driver['user']?['profilePicture'],
      driver['user']?['avatar'],
      _bookingData?['driverImage'],
      _bookingData?['driver']?['profileImageUrl'],
      _bookingData?['driver']?['profileImage'],
      _bookingData?['driver']?['avatar'],
      _bookingData?['driverData']?['profileImageUrl'],
      _bookingData?['driverData']?['profileImage'],
      _bookingData?['assignedDriver']?['profileImageUrl'],
      _bookingData?['assignedDriver']?['profileImage'],
      _bookingData?['assignedDriver']?['avatar'],
      _bookingData?['assignedDriver']?['user']?['profileImageUrl'],
      _bookingData?['assignedDriver']?['user']?['profileImage'],
      _bookingData?['assignedDriver']?['user']?['avatar'],
      widget.driverData?['driverImage'],
      widget.driverData?['profileImageUrl'],
      widget.driverData?['profileImage'],
      widget.driverData?['driver']?['profileImageUrl'],
      widget.driverData?['driver']?['profileImage'],
      widget.driverData?['assignedDriver']?['profileImageUrl'],
      widget.driverData?['assignedDriver']?['profileImage'],
      widget.driverData?['assignedDriver']?['user']?['profileImageUrl'],
      widget.driverData?['assignedDriver']?['user']?['profileImage'],
    ])?.toString();

    if (driverImage != null && driverImage.trim().isNotEmpty) {
      driverImage = driverImage.trim();
      final uri = Uri.tryParse(driverImage);
      final isLocalUrl = uri != null &&
          (uri.host == 'localhost' ||
              uri.host == '127.0.0.1' ||
              uri.host == 'cars.carosa.in');
      if (isLocalUrl) {
        driverImage = '${ApiConstants.baseUrl}${uri.path}';
      } else if (!driverImage.startsWith('http')) {
        if (!driverImage.startsWith('/')) driverImage = '/$driverImage';
        driverImage = '${ApiConstants.baseUrl}$driverImage';
      }
    } else {
      driverImage = null;
    }

    final driverName = _getDriverName();
    final driverPhone = _driverPhone;
    final rating = double.tryParse(
      _readValue([
            driver['rating'],
            driver['averageRating'],
            driver['ratingAverage'],
            driver['avgRating'],
            widget.driverData?['rating'],
            _bookingData?['driverRating'],
          ])?.toString() ??
          '',
    ) ?? 5.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFC000), width: 2.w),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100.r),
                  child: driverImage != null && driverImage.startsWith('http')
                      ? Image.network(
                          driverImage,
                          width: 48.w,
                          height: 48.w,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              _buildDriverPlaceholder(driverName),
                        )
                      : _buildDriverPlaceholder(driverName),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(1.5.r),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: const Color(0xFFFFC000),
                    size: 14.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    _buildRatingChip(rating.toStringAsFixed(1)),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: const Color(0xFFFFC000),
                      size: 13.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Verified Driver',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () => _launchDialer(driverPhone),
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.call,
                color: const Color(0xFF0F172A),
                size: 18.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsCard() {
    final vehicle = _getVehicleData();
    final vehicleNumber = (_readValue([
      vehicle['registrationNo'],
      vehicle['registrationNumber'],
      vehicle['plateNumber'],
      vehicle['vehicleNumber'],
      _driver['registrationNo'],
      _driver['registrationNumber'],
      _driver['plateNumber'],
      _driver['vehicleNumber'],
      _bookingData?['registrationNo'],
      _bookingData?['registrationNumber'],
      _bookingData?['vehicleNumber'],
      _bookingData?['booking']?['registrationNo'],
      _bookingData?['booking']?['registrationNumber'],
      _bookingData?['booking']?['vehicleNumber'],
      widget.driverData?['registrationNo'],
      widget.driverData?['registrationNumber'],
      widget.driverData?['vehicleNumber'],
    ]) ?? '').toString().trim().toUpperCase();

    final make = _readValue([vehicle['make'], _driver['vehicle']?['make']])?.toString().trim();
    final model = _readValue([vehicle['model'], vehicle['vehicleModel'], _driver['vehicle']?['model']])?.toString().trim();
    final color = _readValue([vehicle['color'], _driver['vehicle']?['color']])?.toString().trim();

    List<String> nameParts = [];
    if (make != null && make.isNotEmpty) nameParts.add(make);
    if (model != null && model.isNotEmpty && !nameParts.contains(model)) nameParts.add(model);
    if (color != null && color.isNotEmpty && !nameParts.contains(color)) nameParts.add(color);

    String vehicleTitle = nameParts.join(' ');

    if (vehicleTitle.isEmpty) {
      final directName = _readValue([
        vehicle['vehicleName'],
        vehicle['name'],
        vehicle['carName'],
        _bookingData?['carName'],
        _bookingData?['vehicleName'],
        _bookingData?['vehicleModel']?['name'],
        _bookingData?['vehicleCategory']?['name'],
        _bookingData?['category']?['name'],
        vehicle['category']?['name'],
        vehicle['vehicleType'],
        vehicle['type'],
        _bookingData?['vehicleType'],
      ])?.toString();
      if (directName != null && directName.trim().isNotEmpty) {
        vehicleTitle = _formatVehicleName(directName.trim());
      }
    }

    final fallbackAsset = _getFallbackVehicleImageAsset(vehicle);

    if (vehicleTitle.isEmpty || vehicleTitle.toLowerCase() == 'vehicle') {
      if (fallbackAsset.contains('Bike')) {
        vehicleTitle = 'Honda Activa 6G';
      } else if (fallbackAsset.contains('truck')) {
        vehicleTitle = 'Delivery Truck';
      } else if (fallbackAsset.contains('rickshaw')) {
        vehicleTitle = 'Auto Rickshaw';
      } else {
        vehicleTitle = 'Mahindra SUV White';
      }
    }

    final displaySubtitle = vehicleNumber.isNotEmpty ? vehicleNumber : 'DL 01 SG 9859';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            padding: EdgeInsets.all(6.w),
            child: Image.asset(
              fallbackAsset,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Icon(
                Icons.directions_car_filled_rounded,
                color: Color(0xFF00ABE4),
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    color: const Color(0xFF0F172A),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  displaySubtitle,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideFareCard() {
    final fare = _getRideFare();
    final paymentMethod = _getPaymentMethod();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ride Fare',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 12.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                fare,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Payment Method',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 12.sp,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  paymentMethod,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationSection() {
    final pickup = _getPickupAddress();
    final drop = _getDropAddress();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 3.h),
                width: 10.w,
                height: 10.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup Location',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      pickup,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 13.sp,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 4.w, top: 4.h, bottom: 4.h),
            child: CustomPaint(
              size: Size(2.w, 18.h),
              painter: _DottedLinePainter(color: const Color(0xFFCBD5E1)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 3.h),
                width: 10.w,
                height: 10.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Destination',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      drop,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 13.sp,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Subtitle
        Text(
          'Trip in Progress',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'Enjoy your ride! You\'ll reach soon.',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 13.sp,
            color: const Color(0xFF64748B),
          ),
        ),
        SizedBox(height: 16.h),

        // Time and Distance Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _calculateEtaOnly(),
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance Left',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _getRemainingDistance(),
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),

        // Driver Info Card
        _buildDriverInfoCard(),
        SizedBox(height: 14.h),

        // Vehicle Details Card Section
        Text(
          'Vehicle Details',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 8.h),
        _buildVehicleDetailsCard(),
        SizedBox(height: 14.h),

        // Ride Fare Section
        _buildRideFareCard(),
        SizedBox(height: 14.h),

        // Destination Section
        Text(
          'Destination',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 8.h),
        _buildDestinationSection(),
        if (_deliveryOtp != null && _deliveryOtp!.isNotEmpty) ...[
          SizedBox(height: 14.h),
          InkWell(
            onTap: () => _showPremiumDeliveryOtpPopup(_deliveryOtp!),
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7FD),
                border: Border.all(
                  color: const Color(0xFF00ABE4).withOpacity(0.5),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security,
                    color: const Color(0xFF00ABE4),
                    size: 22.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery OTP',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            color: Colors.black54,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Share with driver at drop-off',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            color: Colors.black87,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ABE4),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _deliveryOtp!,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: 16.h),

        // Cancel Ride Button
        _buildCancelRideButton(),
      ],
    );
  }

  // ==== REUSABLE WIDGETS ====

  Future<void> _launchDialer(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone number not available')),
        );
      }
      return;
    }
    final Uri url = Uri(scheme: 'tel', path: phoneNumber.trim());
    final launched = await launchUrl(url);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone dialer')),
      );
    }
  }

  Widget _buildDriverInfo({bool showTrips = true}) {
    return Column(
      children: [
        _buildDriverRow(),
        SizedBox(height: 12.h),
        _buildVehicleCard(),
        if (showTrips) ...[
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildActionButton(
                Icons.phone,
                'Call',
                onTap: () => _launchDialer(_driverPhone),
              ),
              SizedBox(width: 8.w),
              _buildActionButton(
                Icons.chat_bubble_outline,
                'Chat',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DriverChatScreen(driverData: widget.driverData),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDriverRow() {
    final driver = _driver;
    String? driverImage = _readValue([
      driver['profileImageUrl'],
      driver['profileImage'],
      driver['profilePicture'],
      driver['image'],
      driver['avatar'],
      driver['driverProfile']?['profileImageUrl'],
      driver['driverProfile']?['profileImage'],
      driver['driverProfile']?['profilePicture'],
      driver['driverProfile']?['avatar'],
      driver['user']?['profileImageUrl'],
      driver['user']?['profileImage'],
      driver['user']?['profilePicture'],
      driver['user']?['avatar'],
      _bookingData?['driverImage'],
      _bookingData?['driver']?['profileImageUrl'],
      _bookingData?['driver']?['profileImage'],
      _bookingData?['driver']?['avatar'],
      _bookingData?['driverData']?['profileImageUrl'],
      _bookingData?['driverData']?['profileImage'],
      _bookingData?['assignedDriver']?['profileImageUrl'],
      _bookingData?['assignedDriver']?['profileImage'],
      _bookingData?['assignedDriver']?['avatar'],
      _bookingData?['assignedDriver']?['user']?['profileImageUrl'],
      _bookingData?['assignedDriver']?['user']?['profileImage'],
      _bookingData?['assignedDriver']?['user']?['avatar'],
      widget.driverData?['driverImage'],
      widget.driverData?['profileImageUrl'],
      widget.driverData?['profileImage'],
      widget.driverData?['driver']?['profileImageUrl'],
      widget.driverData?['driver']?['profileImage'],
      widget.driverData?['assignedDriver']?['profileImageUrl'],
      widget.driverData?['assignedDriver']?['profileImage'],
      widget.driverData?['assignedDriver']?['user']?['profileImageUrl'],
      widget.driverData?['assignedDriver']?['user']?['profileImage'],
    ])?.toString();

    if (driverImage != null && driverImage.trim().isNotEmpty) {
      driverImage = driverImage.trim();
      if (driverImage.contains('localhost') ||
          driverImage.contains('cars.carosa.in')) {
        final uri = Uri.tryParse(driverImage);
        if (uri != null && uri.path.isNotEmpty) {
          driverImage = '${ApiConstants.baseUrl}${uri.path}';
        }
      } else if (!driverImage.startsWith('http')) {
        if (!driverImage.startsWith('/')) driverImage = '/$driverImage';
        driverImage = '${ApiConstants.baseUrl}$driverImage';
      }
    } else {
      driverImage = null;
    }

    final driverName = _getDriverName();
    final driverPhone = _driverPhone;
    final rating = double.tryParse(
      _readValue([
            driver['rating'],
            driver['averageRating'],
            driver['ratingAverage'],
            driver['avgRating'],
            widget.driverData?['rating'],
            _bookingData?['driverRating'],
          ])?.toString() ??
          '',
    );
    final isVerified = ['APPROVED', 'VERIFIED'].contains(
      (driver['verificationStatus'] ?? driver['driverKycStatus'])
          ?.toString()
          .toUpperCase(),
    );

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF00ABE4).withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: driverImage != null && driverImage.startsWith('http')
                ? Image.network(
                    driverImage,
                    width: 50.w,
                    height: 50.w,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDriverPlaceholder(driverName),
                  )
                : _buildDriverPlaceholder(driverName),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.h2.copyWith(
                          color: Colors.black,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildRatingChip(
                      rating == null ? 'New' : rating.toStringAsFixed(1),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    if (isVerified) ...[
                      Icon(
                        Icons.verified,
                        color: const Color(0xFF00ABE4),
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Text(
                      isVerified ? 'Verified Driver' : 'Driver',
                      style: AppFonts.captionDark.copyWith(
                        color: const Color(0xFF00ABE4),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatVehicleName(String value) {
    switch (value.trim().toUpperCase().replaceAll(' ', '_')) {
      case 'TRUCK_SMALL':
      case 'MINI_TRUCK':
        return 'Mini Truck';
      case 'TRUCK_MEDIUM':
        return 'Pickup Truck';
      case 'TRUCK_LARGE':
        return 'Large Truck';
      default:
        return value
            .replaceAll('_', ' ')
            .split(' ')
            .where((word) => word.isNotEmpty)
            .map(
              (word) =>
                  '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  Widget _buildVehicleCard() {
    final vehicle = _getVehicleData();
    final vehicleNumber = _readValue([
      vehicle['vehicleNumber'],
      vehicle['registrationNumber'],
      vehicle['plateNumber'],
      vehicle['registrationNo'],
      _driver['vehicleNumber'],
      _driver['registrationNumber'],
      _driver['plateNumber'],
      widget.driverData?['vehicleNumber'],
      widget.driverData?['registrationNumber'],
      _bookingData?['vehicleNumber'],
      _bookingData?['registrationNumber'],
      _bookingData?['booking']?['vehicleNumber'],
      _bookingData?['booking']?['registrationNumber'],
      widget.driverData?['booking']?['vehicleNumber'],
      widget.driverData?['booking']?['registrationNumber'],
    ])?.toString();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF00ABE4).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 42.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.w),
            child: Builder(
              builder: (context) {
                String? imgUrl =
                    (vehicle['image'] ??
                            vehicle['vehicleImage'] ??
                            vehicle['imageUrl'] ??
                            vehicle['photoFrontView'] ??
                            vehicle['photoSideView'] ??
                            vehicle['photoBackView'] ??
                            _bookingData?['vehicleModel']?['imageUrl'])
                        ?.toString();

                if (imgUrl != null &&
                    (imgUrl.contains('localhost') ||
                        imgUrl.contains('cars.carosa.in'))) {
                  final uri = Uri.tryParse(imgUrl);
                  if (uri != null && uri.path.isNotEmpty) {
                    imgUrl = '${ApiConstants.baseUrl}${uri.path}';
                  }
                } else if (imgUrl != null && !imgUrl.startsWith('http')) {
                  if (!imgUrl.startsWith('/')) imgUrl = '/$imgUrl';
                  imgUrl = '${ApiConstants.baseUrl}$imgUrl';
                }

                if (imgUrl != null && imgUrl.isNotEmpty) {
                  return Image.network(
                    imgUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF00ABE4),
                    ),
                  );
                }
                return const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF00ABE4),
                );
              },
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatVehicleName(
                    (_readValue([
                              vehicle['vehicleName'],
                              vehicle['name'],
                              vehicle['vehicleType'],
                              vehicle['type'],
                              vehicle['vehicleModel'],
                              vehicle['model'],
                              _bookingData?['vehicleModel']?['name'],
                              _bookingData?['vehicleBrand']?['name'],
                              _bookingData?['vehicleType'],
                              _bookingData?['carType'],
                              widget.driverData?['carName'],
                              widget.driverData?['vehicleType'],
                            ]) ??
                            'Vehicle')
                        .toString(),
                  ),
                  style: AppFonts.h2.copyWith(
                    color: Colors.black,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (vehicleNumber != null && vehicleNumber.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Vehicle No: $vehicleNumber',
                    style: AppFonts.captionDark.copyWith(
                      color: Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverPlaceholder(String driverName) {
    final initial = driverName.trim().isNotEmpty
        ? driverName.trim().characters.first.toUpperCase()
        : 'D';
    return Container(
      width: 50.w,
      height: 50.w,
      alignment: Alignment.center,
      color: const Color(0xFFE6F7FD),
      child: Text(
        initial,
        style: AppFonts.h2.copyWith(
          color: const Color(0xFF00ABE4),
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRatingChip(String rating) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D6),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: const Color(0xFFFFB300), size: 13.sp),
          SizedBox(width: 3.w),
          Text(
            rating,
            style: AppFonts.captionDark.copyWith(
              color: Colors.black,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            height: 34.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: const Color(0xFF00ABE4).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15.sp, color: const Color(0xFF7D8793)),
                SizedBox(width: 5.w),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.bodyText.copyWith(
                      color: const Color(0xFF7D8793),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteTimeline() {
    return Container(
      decoration: const BoxDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox(height: 24.h),
              const RouteLocationMarker.pickup(),
              Container(width: 1.w, height: 48.h, color: Colors.grey.shade300),
              const RouteLocationMarker.dropOff(),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: 10.h,
                    right: 10.w,
                    bottom: 10.h,
                    left: 14.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF00ABE4).withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pick-up Location',
                              style: AppFonts.captionDark.copyWith(
                                color: Colors.grey.shade500,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              () {
                                final p = _bookingData?['pickup'];
                                if (p is Map && p['address'] != null)
                                  return p['address'].toString();
                                final pl =
                                    _bookingData?['pickupLocation'] ??
                                    widget
                                        .driverData?['booking']?['pickupLocation'];
                                if (pl is Map && pl['address'] != null)
                                  return pl['address'].toString();
                                return (_bookingData?['pickupAddress'] ??
                                        widget
                                            .driverData?['booking']?['pickupAddress'] ??
                                        'Loading...')
                                    .toString();
                              }(),
                              style: AppFonts.bodyText.copyWith(
                                color: Colors.black,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: 10.h,
                    right: 10.w,
                    bottom: 10.h,
                    left: 14.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF00ABE4).withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Destination',
                              style: AppFonts.captionDark.copyWith(
                                color: Colors.grey.shade500,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              () {
                                final d = _bookingData?['drop'];
                                if (d is Map && d['address'] != null)
                                  return d['address'].toString();
                                final dl =
                                    _bookingData?['dropLocation'] ??
                                    widget
                                        .driverData?['booking']?['dropLocation'];
                                if (dl is Map && dl['address'] != null)
                                  return dl['address'].toString();
                                return (_bookingData?['dropAddress'] ??
                                        widget
                                            .driverData?['booking']?['dropAddress'] ??
                                        'Loading...')
                                    .toString();
                              }(),
                              style: AppFonts.bodyText.copyWith(
                                color: Colors.black,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineButton(
    IconData icon,
    String text, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.only(
            top: 7.h,
            right: 10.w,
            bottom: 7.h,
            left: 14.w,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16.sp, color: Colors.grey.shade400),
              SizedBox(width: 4.w),
              Text(
                text,
                style: AppFonts.bodyText.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerEmergencySos() {
    final bookingId = widget.tripId;
    final lat = _driverLocation?.latitude ?? 0.0;
    final lng = _driverLocation?.longitude ?? 0.0;

    if (bookingId != null && bookingId.isNotEmpty) {
      SocketService.to.createSos(
        bookingId: bookingId,
        latitude: lat,
        longitude: lng,
        message: 'I feel unsafe',
      );
    }

    AppUtils.showSnackBar(
      context,
      'Emergency SOS alert sent. 24x7 Safety support notified.',
      isError: false,
    );
  }

  Widget _buildEmergencySOS() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDE8E8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: _triggerEmergencySos,
            child: Text(
              'Emergency SOS',
              style: AppFonts.buttonText.copyWith(
                color: const Color(0xFFE33A3A),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          '24x7 Safety Support',
          style: AppFonts.captionDark.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color iconColor,
    String title,
    String value,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14.r,
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, size: 14.sp, color: iconColor),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppFonts.captionDark.copyWith(color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: AppFonts.bodyText.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showPremiumDeliveryOtpPopup(String otp) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(height: 24.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ABE4).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: const Color(0xFF00ABE4),
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Delivery OTP',
                style: AppFonts.h1.copyWith(
                  fontSize: 24.sp,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Please share this OTP with the driver at the drop-off location to safely complete your delivery.',
                textAlign: TextAlign.center,
                style: AppFonts.bodyText.copyWith(
                  color: Colors.grey[600],
                  fontSize: 14.sp,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: const Color(0xFF00ABE4).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: otp.split('').map((char) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        char,
                        style: AppFonts.h1.copyWith(
                          fontSize: 36.sp,
                          color: const Color(0xFF00ABE4),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 40.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ABE4),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got it',
                    style: AppFonts.buttonText.copyWith(
                      fontSize: 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  void _showTripCompletePopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 16.h,
            left: 20.w,
            right: 20.w,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 16.h
                : 20.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(Icons.check, color: Colors.white, size: 30.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                'Trip Completed!',
                style: AppFonts.h1.copyWith(
                  fontSize: 20.sp,
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Thank you for riding with us.',
                style: AppFonts.captionDark.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFF00ABE4).withOpacity(0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fare Paid',
                              style: AppFonts.captionDark.copyWith(
                                color: Colors.grey.shade500,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '₹450.00',
                              style: AppFonts.h1.copyWith(
                                color: const Color(0xFF00ABE4),
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14A03F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFF14A03F).withOpacity(0.3),
                              width: 0.8.w,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: const Color(0xFF14A03F),
                                size: 12.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'PAID',
                                style: AppFonts.bodyText.copyWith(
                                  color: const Color(0xFF14A03F),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: Row(
                        children: List.generate(30, (index) {
                          return Expanded(
                            child: Container(
                              height: 1.h,
                              color: index % 2 == 0
                                  ? Colors.transparent
                                  : Colors.grey.shade400,
                            ),
                          );
                        }),
                      ),
                    ),
                    _buildPopupDetailRow(
                      'Payment Mode',
                      'Cash / Online',
                      isHighlighted: true,
                    ),
                    SizedBox(height: 8.h),
                    _buildPopupDetailRow('Distance Traveled', '12.5 km'),
                    SizedBox(height: 8.h),
                    _buildPopupDetailRow('Ride Duration', '24 mins'),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ABE4),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFF00ABE4).withOpacity(0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RideInvoiceScreen(bookingId: widget.tripId),
                      ),
                    );
                  },
                  child: Text(
                    'Done',
                    style: AppFonts.buttonText.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopupDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.captionDark.copyWith(
            color: Colors.grey.shade500,
            fontSize: 13.sp,
          ),
        ),
        Text(
          value,
          style: AppFonts.bodyText.copyWith(
            color: isHighlighted
                ? const Color(0xFF1A1A1A)
                : Colors.grey.shade800,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
      ],
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + 4), paint);
      startY += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
