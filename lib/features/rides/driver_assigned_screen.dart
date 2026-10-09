import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_fonts.dart';
import 'cancellation_reason_drawer.dart';
import 'driver_chat_screen.dart';
import 'driver_tracking_screen.dart';
import '../../core/socket/socket_service.dart';
import '../../core/socket/socket_events.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils.dart';
import '../../core/maps/smooth_map_motion.dart';
import '../main_navigation_screen.dart';
import '../../widgets/location_route_markers.dart';

class DriverAssignedScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic>? driverData;

  const DriverAssignedScreen({
    super.key,
    required this.tripId,
    this.driverData,
  });

  @override
  State<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _DriverAssignedScreenState extends State<DriverAssignedScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;

  static const double _addressLabelFontSize = 11;
  static const double _addressValueFontSize = 12;
  static const FontWeight _addressLabelFontWeight = FontWeight.w600;
  static const FontWeight _addressValueFontWeight = FontWeight.w600;

  LatLng? _driverLocation;
  double _driverBearing = 0;
  final SmoothMapMotion _mapMotion = SmoothMapMotion();
  BitmapDescriptor? _driverMarkerIcon;
  List<LatLng> _routePoints = const [];
  bool _isNavigating = false;
  String? _otp;
  bool _isFetchingOtp = false;
  String? _otpError;
  String? _otpExpiresAt;
  Map<String, dynamic> _bookingData = {};
  Timer? _trackingTimer;

  String? get _resolvedTripId {
    final values = [
      _bookingData['tripId'],
      _bookingData['trip']?['id'],
      _bookingData['booking']?['tripId'],
      _bookingData['booking']?['trip']?['id'],
      widget.driverData?['tripId'],
      widget.driverData?['trip']?['id'],
      widget.driverData?['booking']?['tripId'],
      widget.driverData?['booking']?['trip']?['id'],
      widget.tripId,
    ];
    for (final v in values) {
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  bool _isCurrentBookingEvent(dynamic data) {
    return SocketService.to.isEventForBooking(data, widget.tripId);
  }

  @override
  void initState() {
    super.initState();
    _bookingData = Map<String, dynamic>.from(widget.driverData ?? {});
    _driverLocation = SmoothMapMotion.locationFromPayload(_bookingData);
    _routePoints = SmoothMapMotion.routeFromPayload(_bookingData);
    _loadDriverMarker();
    _otp =
        _bookingData['rideStartOtp']?.toString() ??
        _bookingData['otp']?.toString() ??
        _bookingData['pickupOtp']?.toString() ??
        _bookingData['deliveryOtp']?.toString() ??
        _bookingData['booking']?['rideStartOtp']?.toString() ??
        _bookingData['booking']?['pickupOtp']?.toString();
    _fetchBookingDetails();
    _fetchRealTripOtp();
    _getCurrentLocation();
    _setupSocketListeners();
    _trackingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (!mounted || _isNavigating) return;
        _fetchBookingDetails();
        if (_bookingData['isGoods'] == true ||
            _bookingData['moduleType'] == 'GOODS' ||
            _bookingData['bookingType'] == 'GOODS') {
          _fetchGoodsTracking();
        } else {
          _fetchRideDriverLocation();
        }
      },
    );
  }

  Future<void> _fetchRideDriverLocation() async {
    try {
      final response = await ApiService.to.get(
        ApiEndpoints.driverLocation(widget.tripId),
      );
      if (!mounted || response.data is! Map) return;
      final raw = Map<String, dynamic>.from(response.data as Map);
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      final status = (data['status'] ?? data['booking']?['status'])?.toString().toUpperCase();
      if (status == 'STARTED' ||
          status == 'TRIP_STARTED' ||
          status == 'IN_PROGRESS' ||
          status == 'IN_TRANSIT' ||
          status == 'OTP_VERIFIED' ||
          status == 'PICKED_UP' ||
          status == 'ON_GOING') {
        _openGoodsTripInProgress(data);
        return;
      }
      final target = SmoothMapMotion.locationFromPayload(data);
      if (target != null) _moveDriverMarker(target, followCamera: false);
      if (mounted) {
        setState(() {
          if (data['etaMinutes'] != null) {
            _bookingData['etaMinutes'] = data['etaMinutes'];
          }
          if (data['distanceToTargetKm'] != null) {
            _bookingData['distanceKm'] = data['distanceToTargetKm'];
          }
        });
      }
    } catch (error) {
      if (error.toString().contains('409') || error.toString().contains('Driver is not assigned yet')) {
        _fetchBookingDetails();
      } else {
        debugPrint('Ride driver tracking failed: $error');
      }
    }
  }

  Future<void> _fetchGoodsTracking() async {
    try {
      final response = await ApiService.to.get(
        ApiEndpoints.goodsTracking(widget.tripId),
      );
      if (!mounted || response.data is! Map) return;
      final raw = Map<String, dynamic>.from(response.data as Map);
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      final tracking = data['tracking'] is Map
          ? Map<String, dynamic>.from(data['tracking'] as Map)
          : <String, dynamic>{};
      final booking = data['booking'] is Map
          ? Map<String, dynamic>.from(data['booking'] as Map)
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
      final status = (booking['status'] ?? data['status'] ?? tracking['status'])?.toString().toUpperCase();
      if (status == 'STARTED' ||
          status == 'TRIP_STARTED' ||
          status == 'IN_PROGRESS' ||
          status == 'IN_TRANSIT' ||
          status == 'OTP_VERIFIED' ||
          status == 'PICKED_UP' ||
          status == 'ON_GOING') {
        _openGoodsTripInProgress({...data, ...booking});
        return;
      }
      setState(() {
        if (booking.isNotEmpty) {
          _bookingData['booking'] = {
            ...(_bookingData['booking'] is Map
                ? _bookingData['booking'] as Map
                : {}),
            ...booking,
          };
        }
        if (tracking['etaMinutes'] != null) {
          _bookingData['etaMinutes'] = tracking['etaMinutes'];
        }
        if (tracking['estimatedDurationMin'] != null) {
          _bookingData['estimatedDurationMin'] =
              tracking['estimatedDurationMin'];
        }
        if (tracking['distanceKm'] != null) {
          _bookingData['distanceKm'] = tracking['distanceKm'];
        }
      });
      if (lat != null && lng != null) {
        _moveDriverMarker(LatLng(lat, lng), followCamera: false);
      }
      _updateMapCamera();
    } catch (error) {
      debugPrint('Goods pickup tracking failed: $error');
    }
  }

  void _handleGoodsLocation(dynamic data) {
    if (!_isCurrentBookingEvent(data)) return;
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is! Map) return;
    final location = payload['location'] is Map
        ? payload['location']
        : payload['currentLocation'] is Map
        ? payload['currentLocation']
        : payload;
    final target = SmoothMapMotion.locationFromPayload(location);
    if (target != null) _moveDriverMarker(target);
  }

  Future<void> _fetchBookingDetails() async {
    final isGoods =
        _bookingData['goodsBookingId'] != null ||
        _bookingData['bookingType'] == 'GOODS' ||
        _bookingData['moduleType'] == 'GOODS' ||
        _bookingData['isGoods'] == true;
    final endpoint = isGoods
        ? ApiEndpoints.goodsBookingDetails(widget.tripId)
        : ApiEndpoints.bookingDetails(widget.tripId);

    try {
      final response = await ApiService.to.get(endpoint);
      if (response.isSuccess && response.data != null) {
        if (mounted) {
          setState(() {
            final raw = response.data is Map
                ? Map<String, dynamic>.from(response.data as Map)
                : <String, dynamic>{};
            final data = raw['data'] is Map
                ? Map<String, dynamic>.from(raw['data'] as Map)
                : raw;
            _bookingData = {
              ..._bookingData,
              ...data,
              'tripId': widget.tripId,
              if (isGoods) 'isGoods': true,
            };
            final status = (data['status'] ?? data['booking']?['status'])?.toString().toUpperCase();
            if (status == 'STARTED' || status == 'TRIP_STARTED' || status == 'IN_PROGRESS' || status == 'IN_TRANSIT') {
              _openGoodsTripInProgress(data);
              return;
            }
            if (status == 'CANCELLED' || status == 'REJECTED') {
              _trackingTimer?.cancel();
              _handleTripCancelled(data);
              return;
            }
            final routePoints = SmoothMapMotion.routeFromPayload(_bookingData);
            if (routePoints.isNotEmpty) _routePoints = routePoints;
            _otp =
                _readValue([
                  data['pickupOtp'],
                  data['rideStartOtp'],
                  data['otp'],
                  data['booking']?['pickupOtp'],
                  data['booking']?['rideStartOtp'],
                ])?.toString() ??
                _otp;
            if (_otp == null || _otp!.isEmpty) {
              _fetchRealTripOtp();
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching booking details: $e');
    }
  }

  Future<void> _fetchRealTripOtp({bool isRetry = false}) async {
    final tripId = _resolvedTripId;
    final bookingId =
        _bookingData['bookingId'] ??
        _bookingData['id'] ??
        widget.driverData?['bookingId'] ??
        widget.driverData?['id'] ??
        widget.tripId;

    debugPrint('[USER OTP] Driver accepted');
    debugPrint('[USER OTP] bookingId: $bookingId, tripId: $tripId');

    if (tripId == null || tripId.isEmpty) {
      debugPrint('[USER OTP] Cannot fetch OTP: actual tripId not found yet.');
      return;
    }

    if (_isFetchingOtp) return;
    if (_otp != null && _otp!.isNotEmpty && _otp != '----' && !isRetry) {
      debugPrint('[USER OTP] OTP already loaded for tripId: $tripId');
      return;
    }

    if (mounted) {
      setState(() {
        _isFetchingOtp = true;
        _otpError = null;
      });
    }

    final endpoint = ApiEndpoints.resendTripOtp(tripId);
    debugPrint('[USER OTP] Calling: POST $endpoint');

    try {
      final response = await ApiService.to.post(endpoint, body: {});
      debugPrint('[USER OTP] OTP API status: ${response.statusCode}');

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final raw = response.data is Map ? response.data as Map : {};
        final data = raw['data'] is Map ? raw['data'] as Map : raw;

        final fetchedOtp =
            data['otp']?.toString() ?? data['pickupOtp']?.toString();
        final expiresAt = data['expiresAt']?.toString();

        if (fetchedOtp != null && fetchedOtp.isNotEmpty) {
          setState(() {
            _otp = fetchedOtp;
            _otpExpiresAt = expiresAt;
            _bookingData['otp'] = fetchedOtp;
            _isFetchingOtp = false;
            _otpError = null;
          });
          debugPrint('[USER OTP] OTP loaded successfully for tripId: $tripId');
        } else {
          setState(() {
            _isFetchingOtp = false;
            _otpError = 'Unable to load OTP';
          });
        }
      } else {
        setState(() {
          _isFetchingOtp = false;
          _otpError = 'Unable to load OTP';
        });
        debugPrint(
          '[USER OTP] OTP API returned unsuccessful status: ${response.statusCode}',
        );
      }
    } catch (error) {
      debugPrint('[USER OTP] OTP API error: $error');
      if (mounted) {
        setState(() {
          _isFetchingOtp = false;
          _otpError = 'Unable to load OTP';
        });
      }
    }
  }

  void _handleDriverLocation(dynamic data) {
    if (!mounted || !_isCurrentBookingEvent(data)) return;
    final target = SmoothMapMotion.locationFromPayload(data);
    if (target != null) _moveDriverMarker(target);
  }

  void _moveDriverMarker(LatLng target, {bool followCamera = true}) {
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

  Future<void> _loadDriverMarker() async {
    final isGoods =
        _bookingData['isGoods'] == true ||
        _bookingData['moduleType'] == 'GOODS' ||
        _bookingData['bookingType'] == 'GOODS';
    final data = await rootBundle.load(
      isGoods ? 'assets/images/truck.png' : 'assets/images/car1.png',
    );
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 20,
      targetHeight: 20,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final icon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    if (mounted) setState(() => _driverMarkerIcon = icon);
  }

  LatLng? _bookingLocation(String key) {
    final booking = _bookingData['booking'];
    final value =
        _bookingData[key] ??
        (booking is Map ? booking[key] : null) ??
        widget.driverData?[key] ??
        widget.driverData?['booking']?[key];
    return SmoothMapMotion.locationFromPayload(value);
  }

  void _handleDriverArrived(dynamic data) {
    if (!mounted || _isNavigating || !_isCurrentBookingEvent(data)) return;
    _isNavigating = true;

    AppUtils.showSnackBar(context, 'Your driver has arrived at the pickup location.');

    Map<String, dynamic> nextDriverData = {};
    if (widget.driverData != null) {
      nextDriverData.addAll(widget.driverData!);
    }
    if (_bookingData != null) {
      nextDriverData.addAll(_bookingData!);
    }
    if (_otp != null) {
      nextDriverData['otp'] = _otp;
    }

    if (data is List && data.isNotEmpty && data[0] is Map) {
      nextDriverData.addAll(Map<String, dynamic>.from(data[0] as Map));
    } else if (data is Map) {
      nextDriverData.addAll(Map<String, dynamic>.from(data));
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DriverTrackingScreen(
          tripId: widget.tripId,
          driverData: nextDriverData,
          initialState: RideState.verifyOTP,
        ),
      ),
    );
  }

  void _handleGoodsTripStarted(dynamic data) {
    if (!mounted || _isNavigating || !_isCurrentBookingEvent(data)) return;
    final payload = data is List && data.isNotEmpty ? data.first : data;
    _openGoodsTripInProgress(
      payload is Map ? Map<String, dynamic>.from(payload) : const {},
    );
  }

  void _openGoodsTripInProgress(Map<String, dynamic> payload) {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    AppUtils.showSnackBar(context, 'Trip Started');

    final nextDriverData = <String, dynamic>{
      ...?_bookingData,
      ...?widget.driverData,
      ...payload,
      'isGoods': true,
      'tripId': widget.tripId,
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DriverTrackingScreen(
          tripId: widget.tripId,
          driverData: nextDriverData,
          initialState: RideState.inProgress,
        ),
      ),
    );
  }

  void _handleTripCancelled(dynamic data) {
    if (!mounted || _isNavigating) return;
    if (!_isCurrentBookingEvent(data)) return;
    final payload = data is List ? (data.isNotEmpty ? data.first : {}) : data;
    final booking = payload is Map ? payload['booking'] : null;

    // If the user cancelled it themselves, the CancelRideScreen will handle the UI
    if (booking is Map && booking['cancelledBy'] == 'USER') return;
    if (payload is Map && payload['cancelledBy'] == 'USER') return;

    _isNavigating = true;
    _trackingTimer?.cancel();

    final reason = payload?['message'] ?? (payload is Map ? payload['reason'] : null) ?? 'Trip was cancelled by driver.';

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
    if (!mounted || !_isCurrentBookingEvent(data)) return;
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

  void _setupSocketListeners() {
    SocketService.to.listenTo(
      SocketEvents.driverLocation,
      _handleDriverLocation,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsLocationUpdated,
      _handleGoodsLocation,
    );

    SocketService.to.listenTo(SocketEvents.driverArrived, _handleDriverArrived);
    SocketService.to.listenTo('driver_arrived', _handleDriverArrived);
    SocketService.to.listenTo('cars:driver:arrived', _handleDriverArrived);
    SocketService.to.listenTo('ride.driver.arrived', _handleDriverArrived);
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
    SocketService.to.listenTo(
      SocketEvents.goodsTripStarted,
      _handleGoodsTripStarted,
    );
    SocketService.to.listenTo(SocketEvents.tripStarted, _handleGoodsTripStarted);
    SocketService.to.listenTo('trip:started', _handleGoodsTripStarted);
    SocketService.to.listenTo('trip_started', _handleGoodsTripStarted);
    SocketService.to.listenTo('TRIP_STARTED', _handleGoodsTripStarted);
    SocketService.to.listenTo('booking:trip-started', _handleGoodsTripStarted);
    SocketService.to.listenTo('booking:started', _handleGoodsTripStarted);
    SocketService.to.listenTo('goods:booking:start', _handleGoodsTripStarted);
    SocketService.to.listenTo('goods.booking.start', _handleGoodsTripStarted);

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

    SocketService.to.listenTo('trip:otp-generated', _handleOtpReceived);
    SocketService.to.listenTo('trip.otp-generated', _handleOtpReceived);
    SocketService.to.listenTo('booking:driver-assigned', _handleOtpReceived);
    SocketService.to.listenTo('trip:otp', _handleOtpReceived);
    SocketService.to.listenTo('goods.pickup.otp.sent', _handleOtpReceived);
    SocketService.to.listenTo('goods:pickup:otp', _handleOtpReceived);
    SocketService.to.listenTo('goods.pickup.otp.required', _handleOtpReceived);
  }

  void _handleOtpReceived(dynamic data) {
    if (!mounted || !_isCurrentBookingEvent(data)) return;
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is Map) {
      final otp = _readValue([
        payload['otp'],
        payload['pickupOtp'],
        payload['rideStartOtp'],
        payload['booking']?['pickupOtp'],
      ]);
      if (otp != null && otp.toString().isNotEmpty) {
        setState(() {
          _otp = otp.toString();
          _isFetchingOtp = false;
          _otpError = null;
        });
        _bookingData['otp'] = _otp;
      } else {
        _fetchRealTripOtp();
      }
    }
  }

  dynamic _readValue(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  Map<String, dynamic> get _driver {
    final value =
        _bookingData['driver'] ??
        _bookingData['assignedDriver'] ??
        _bookingData['driverDetails'] ??
        _bookingData['booking']?['driver'] ??
        _bookingData['booking']?['assignedDriver'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> get _vehicle {
    final value =
        _driver['assignedVehicle'] ??
        _driver['vehicle'] ??
        _driver['vehicles']?[0] ??
        _driver['driverProfile']?['vehicles']?[0] ??
        _bookingData['vehicle'] ??
        _bookingData['assignedVehicle'] ??
        _bookingData['booking']?['vehicle'] ??
        _bookingData['booking']?['assignedVehicle'] ??
        widget.driverData?['vehicle'] ??
        widget.driverData?['assignedVehicle'] ??
        widget.driverData?['booking']?['vehicle'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  void _updateMapCamera() {
    if (_mapController == null) return;
    if (_currentPosition != null && _driverLocation != null) {
      double minLat = _currentPosition!.latitude < _driverLocation!.latitude
          ? _currentPosition!.latitude
          : _driverLocation!.latitude;
      double maxLat = _currentPosition!.latitude > _driverLocation!.latitude
          ? _currentPosition!.latitude
          : _driverLocation!.latitude;
      double minLng = _currentPosition!.longitude < _driverLocation!.longitude
          ? _currentPosition!.longitude
          : _driverLocation!.longitude;
      double maxLng = _currentPosition!.longitude > _driverLocation!.longitude
          ? _currentPosition!.longitude
          : _driverLocation!.longitude;

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.005, minLng - 0.005),
        northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  @override
  void dispose() {
    _mapMotion.dispose();
    _trackingTimer?.cancel();
    SocketService.to.stopListening(
      SocketEvents.driverLocation,
      _handleDriverLocation,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsLocationUpdated,
      _handleGoodsLocation,
    );
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
      SocketEvents.goodsTripStarted,
      _handleGoodsTripStarted,
    );
    SocketService.to.stopListening(
      'goods:booking:start',
      _handleGoodsTripStarted,
    );
    SocketService.to.stopListening(
      'goods.booking.start',
      _handleGoodsTripStarted,
    );
    SocketService.to.stopListening(
      SocketEvents.tripCancelled,
      _handleTripCancelled,
    );
    SocketService.to.stopListening(
      'goods.booking.cancelled',
      _handleTripCancelled,
    );
    SocketService.to.stopListening(
      SocketEvents.tripCancelledByUser,
      _handleTripCancelledByUser,
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
    super.dispose();
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
      debugPrint("Error fetching location: $e");
    }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AppUtils.showSnackBar(
          context,
          'Ride is currently active. You can cancel or wait until completion.',
        );
      },
      child: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 14,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      final routeBounds = SmoothMapMotion.boundsFor([
                        ..._routePoints,
                        if (_driverLocation != null) _driverLocation!,
                      ]);
                      if (routeBounds != null) {
                        Future<void>.delayed(
                          const Duration(milliseconds: 250),
                          () {
                            if (mounted) {
                              controller.animateCamera(
                                CameraUpdate.newLatLngBounds(routeBounds, 64),
                              );
                            }
                          },
                        );
                      } else {
                        _updateMapCamera();
                      }
                    },
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
                      if (_currentPosition != null)
                        Marker(
                          markerId: const MarkerId('user_location'),
                          position: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                          infoWindow: const InfoWindow(title: 'Your Location'),
                        ),
                      if (_driverLocation != null)
                        Marker(
                          markerId: const MarkerId('driver_location'),
                          position: _driverLocation!,
                          rotation: _driverBearing,
                          flat: true,
                          icon:
                              _driverMarkerIcon ??
                              BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueAzure,
                              ),
                          infoWindow: const InfoWindow(
                            title: 'Driver Location',
                          ),
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
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16.h,
            left: 20.w,
            child: _buildBackButton(context),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16.h,
            right: 20.w,
            child: GestureDetector(
              onTap: () {
                final pickup =
                    widget.driverData?['pickup'] ??
                    widget.driverData?['booking']?['pickup'] ??
                    {};
                final double? lat = double.tryParse(
                  pickup['latitude']?.toString() ?? '',
                );
                final double? lng = double.tryParse(
                  pickup['longitude']?.toString() ?? '',
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
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me, color: Colors.white, size: 16.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'Navigation',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 94.h,
            left: 94.w,
            child: _buildDriverMapLabel(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 64.h,
            right: 44.w,
            child: _buildOtpChip(_otp ?? '----'),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomPanel(context),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.arrow_back, color: Colors.black, size: 20.sp),
      ),
    );
  }

  Widget _buildDriverMapLabel() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Driver is on the way',
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
                  text: _calculateEtaOnly(),
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
    );
  }

  String _calculateEtaOnly() {
    final serverEta = _readValue([
      _bookingData['driverEtaMinutes'],
      _bookingData['etaMinutes'],
      _bookingData['estimatedDurationMin'],
      _bookingData['driver']?['etaMinutes'],
      _bookingData['booking']?['driverEtaMinutes'],
      _bookingData['booking']?['etaMinutes'],
    ]);
    if (serverEta != null) {
      final text = serverEta.toString().replaceAll(RegExp(r'[^\d]'), '');
      if (text.isNotEmpty) return '$text min';
    }
    if (_currentPosition == null || _driverLocation == null) return '3 min';
    double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _driverLocation!.latitude,
      _driverLocation!.longitude,
    );
    int minutes = (distanceInMeters / 500).ceil();
    if (minutes <= 0) return '1 min';
    return '$minutes min';
  }

  String _calculateETA() {
    return 'Arriving in ${_calculateEtaOnly()}';
  }

  Widget _buildOtpChip(String otp) {
    if (otp.isEmpty || otp == '----') {
      if (!_isFetchingOtp) return const SizedBox.shrink();
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFFFC000), width: 1.5.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12.w,
              height: 12.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC000)),
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              '• • • •',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                color: const Color(0xFF94A3B8),
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.w,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFFFC000), width: 1.8.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'OTP',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: const Color(0xFF64748B),
              fontSize: 9.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.w,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            otp,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: const Color(0xFF0F172A),
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.w,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    final driver = _driver;
    final driverPhone = _readValue([
      driver['phone'],
      driver['mobile'],
      driver['phoneNumber'],
      driver['mobileNumber'],
      driver['contactNumber'],
      driver['user']?['phone'],
      driver['user']?['mobile'],
    ])?.toString();

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16.w,
          12.h,
          16.w,
          MediaQuery.of(context).padding.bottom + 16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle Bar
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 14.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // Title: Assign Driver
            Text(
              'Assign Driver',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 14.h),

            // Driver Card (Matching Assign Driver Design)
            _buildDriverInfoCard(context, driverPhone),
            SizedBox(height: 16.h),

            // Vehicle Details Section Title & Card
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
            _buildVehicleCard(_bookingData),
            // Subtle Divider Line before action buttons
            Container(
              margin: EdgeInsets.symmetric(vertical: 4.h),
              height: 1.h,
              color: const Color(0xFFF1F5F9),
            ),
            SizedBox(height: 12.h),

            // Action Buttons Row: [ Cancel Ride ]  [ Track Driver ]
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                        backgroundColor: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                      ),
                      onPressed: () => _showCancelRideSheet(context),
                      child: Text(
                        'Cancel Ride',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC000),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                      ),
                      onPressed: () {
                        Map<String, dynamic> nextDriverData = {
                          ...?widget.driverData,
                          ...?_bookingData,
                          if (_otp != null) 'otp': _otp,
                        };
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DriverTrackingScreen(
                              tripId: widget.tripId,
                              driverData: nextDriverData,
                              initialState: RideState.arriving,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Track Driver',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard(BuildContext context, String? driverPhone) {
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
      _bookingData['driverImage'],
      _bookingData['driver']?['profileImageUrl'],
      _bookingData['driver']?['profileImage'],
      _bookingData['driver']?['avatar'],
      _bookingData['driverData']?['profileImageUrl'],
      _bookingData['driverData']?['profileImage'],
      _bookingData['assignedDriver']?['profileImageUrl'],
      _bookingData['assignedDriver']?['profileImage'],
      _bookingData['assignedDriver']?['avatar'],
      _bookingData['assignedDriver']?['user']?['profileImageUrl'],
      _bookingData['assignedDriver']?['user']?['profileImage'],
      _bookingData['assignedDriver']?['user']?['avatar'],
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

    final firstName = _readValue([
      driver['firstName'],
      driver['firstname'],
      driver['user']?['firstName'],
    ])?.toString();
    final lastName = _readValue([
      driver['lastName'],
      driver['lastname'],
      driver['user']?['lastName'],
    ])?.toString();
    final fullName = [
      firstName,
      lastName,
    ].where((value) => value?.trim().isNotEmpty == true).join(' ');
    final driverName = fullName.isNotEmpty
        ? fullName
        : (_readValue([
                    driver['name'],
                    driver['displayName'],
                    driver['fullName'],
                    driver['user']?['displayName'],
                    driver['user']?['name'],
                    _bookingData['driver']?['name'],
                    _bookingData['driver']?['displayName'],
                    _bookingData['driver']?['user']?['displayName'],
                    _bookingData['driver']?['user']?['name'],
                    _bookingData['assignedDriver']?['user']?['displayName'],
                    _bookingData['assignedDriver']?['user']?['name'],
                    _bookingData['assignedDriver']?['name'],
                    _bookingData['driverName'],
                  ]) ??
                  'Driver')
              .toString();
    final rating = double.tryParse(
      _readValue([
            driver['rating'],
            driver['averageRating'],
            driver['ratingAverage'],
            driver['avgRating'],
            driver['user']?['averageRating'],
            _bookingData['driver']?['rating'],
            _bookingData['driver']?['averageRating'],
            _bookingData['assignedDriver']?['averageRating'],
            _bookingData['driverRating'],
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
      child: Column(
        children: [
          // Top Row: Avatar | Name & Rating & Verified | Call Button
          Row(
            children: [
              // Driver Avatar with Yellow Ring & Checkmark Badge
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

              // Name, Rating & Verified status
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

              // Phone Call Action Button
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
          SizedBox(height: 12.h),

          // Bottom Pills Row: [ X min away ]  [ • Drop X:XX pm ]
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${_calculateEtaOnly()} away',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '• Drop ${_getEstimatedDropTime()}',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getEstimatedDropTime() {
    final dropTimeStr = _readValue([
      _bookingData['dropTime'],
      _bookingData['estimatedDropTime'],
      _bookingData['dropTimeFormatted'],
    ]);
    if (dropTimeStr != null && dropTimeStr.toString().isNotEmpty) {
      return dropTimeStr.toString();
    }
    final dt = DateTime.now().add(const Duration(minutes: 25));
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  Future<void> _launchDialer(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      AppUtils.showSnackBar(context, 'Driver phone number not available', isError: true);
      return;
    }
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) AppUtils.showSnackBar(context, 'Could not launch phone dialer', isError: true);
      }
    } catch (e) {
      if (mounted) AppUtils.showSnackBar(context, 'Error launching phone dialer: $e', isError: true);
    }
  }

  void _showCancelRideSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
              _buildSheetButton(
                label: 'Cancel Ride',
                color: const Color(0xFFFF2D2D),
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  CancellationReasonDrawer.show(
                    context,
                    tripId: widget.tripId,
                  );
                },
              ),
              SizedBox(height: 10.h),
              _buildSheetButton(
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

  Widget _buildSheetButton({
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

  Widget _buildDriverInfo(Map<String, dynamic>? data) {
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
      _bookingData['driverImage'],
      _bookingData['driver']?['profileImageUrl'],
      _bookingData['driver']?['profileImage'],
      _bookingData['driver']?['avatar'],
      _bookingData['driverData']?['profileImageUrl'],
      _bookingData['driverData']?['profileImage'],
      _bookingData['assignedDriver']?['profileImageUrl'],
      _bookingData['assignedDriver']?['profileImage'],
      _bookingData['assignedDriver']?['avatar'],
      _bookingData['assignedDriver']?['user']?['profileImageUrl'],
      _bookingData['assignedDriver']?['user']?['profileImage'],
      _bookingData['assignedDriver']?['user']?['avatar'],
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

    final firstName = _readValue([
      driver['firstName'],
      driver['firstname'],
    ])?.toString();
    final lastName = _readValue([
      driver['lastName'],
      driver['lastname'],
    ])?.toString();
    final fullName = [
      firstName,
      lastName,
    ].where((value) => value?.trim().isNotEmpty == true).join(' ');
    final driverName = fullName.isNotEmpty
        ? fullName
        : (_readValue([
                    driver['name'],
                    driver['fullName'],
                    driver['user']?['name'],
                    _bookingData['driverName'],
                  ]) ??
                  'Driver')
              .toString();
    final driverPhone = _readValue([
      driver['phone'],
      driver['mobile'],
      driver['phoneNumber'],
      driver['mobileNumber'],
      driver['contactNumber'],
      driver['user']?['phone'],
      driver['user']?['mobile'],
    ])?.toString();
    final rating = double.tryParse(
      _readValue([
            driver['rating'],
            driver['averageRating'],
            driver['ratingAverage'],
            driver['avgRating'],
            _bookingData['driverRating'],
          ])?.toString() ??
          '',
    );
    final isVerified = ['APPROVED', 'VERIFIED'].contains(
      (driver['verificationStatus'] ?? driver['driverKycStatus'])
          ?.toString()
          .toUpperCase(),
    );

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: driverImage != null && driverImage.startsWith('http')
              ? Image.network(
                  driverImage,
                  key: ValueKey(driverImage),
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
              if (driverPhone != null && driverPhone.isNotEmpty) ...[
                SizedBox(height: 3.h),
                Text(
                  driverPhone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.captionDark.copyWith(
                    color: const Color(0xFF404B5A),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverPlaceholder(String driverName) {
    final initial = driverName.trim().isNotEmpty
        ? driverName.trim().characters.first.toUpperCase()
        : null;
    return Container(
      width: 50.w,
      height: 50.w,
      alignment: Alignment.center,
      color: const Color(0xFFE6F7FD),
      child: initial == null
          ? Icon(
              Icons.person_outline,
              color: const Color(0xFF00ABE4),
              size: 28.sp,
            )
          : Text(
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

  String _getFallbackVehicleImageAsset(Map<String, dynamic> vehicle) {
    final typeStr = ([
      _bookingData['bookingType'],
      _bookingData['moduleType'],
      _bookingData['vehicleType'],
      _bookingData['carType'],
      _bookingData['vehicleCategory']?['name'],
      _bookingData['vehicleCategory']?['type'],
      _bookingData['category']?['name'],
      _bookingData['carName'],
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
        _bookingData['isGoods'] == true) {
      return 'assets/images/truck.png';
    } else {
      return 'assets/images/car1.png';
    }
  }

  Widget _buildVehicleCard(Map<String, dynamic>? data) {
    final vehicle = _vehicle;
    final vehicleNumber = (_readValue([
      vehicle['registrationNo'],
      vehicle['registrationNumber'],
      vehicle['plateNumber'],
      vehicle['vehicleNumber'],
      _driver['registrationNo'],
      _driver['registrationNumber'],
      _driver['plateNumber'],
      _driver['vehicleNumber'],
      _bookingData['registrationNo'],
      _bookingData['registrationNumber'],
      _bookingData['vehicleNumber'],
      _bookingData['booking']?['registrationNo'],
      _bookingData['booking']?['registrationNumber'],
      _bookingData['booking']?['vehicleNumber'],
      widget.driverData?['registrationNo'],
      widget.driverData?['registrationNumber'],
      widget.driverData?['vehicleNumber'],
      widget.driverData?['booking']?['registrationNo'],
      widget.driverData?['booking']?['registrationNumber'],
      widget.driverData?['booking']?['vehicleNumber'],
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
        _bookingData['carName'],
        _bookingData['vehicleName'],
        _bookingData['vehicleModel']?['name'],
        _bookingData['vehicleCategory']?['name'],
        _bookingData['category']?['name'],
        vehicle['category']?['name'],
        vehicle['vehicleType'],
        vehicle['type'],
        _bookingData['vehicleType'],
      ])?.toString();
      if (directName != null && directName.trim().isNotEmpty) {
        vehicleTitle = _formatVehicleName(directName.trim());
      }
    }

    final fallbackAsset = _getFallbackVehicleImageAsset(vehicle);

    if (vehicleTitle.isEmpty || vehicleTitle.toLowerCase() == 'vehicle') {
      if (fallbackAsset.contains('Bike')) {
        vehicleTitle = 'Bike Taxi';
      } else if (fallbackAsset.contains('truck')) {
        vehicleTitle = 'Delivery Truck';
      } else if (fallbackAsset.contains('rickshaw')) {
        vehicleTitle = 'Auto Rickshaw';
      } else {
        vehicleTitle = 'Cab / Ride';
      }
    }

    final displaySubtitle = vehicleNumber.isNotEmpty ? vehicleNumber : 'Verified Vehicle';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8.r),
            ),
            padding: EdgeInsets.all(4.w),
            child: Builder(
              builder: (context) {
                String? imgUrl =
                    (_bookingData['vehicleCategory']?['iconUrl'] ??
                            _bookingData['vehicleCategory']?['imageUrl'] ??
                            vehicle['category']?['iconUrl'] ??
                            vehicle['image'] ??
                            vehicle['vehicleImage'] ??
                            vehicle['imageUrl'] ??
                            vehicle['photoFrontView'] ??
                            vehicle['photoSideView'] ??
                            vehicle['photoBackView'] ??
                            _bookingData['vehicleModel']?['imageUrl'])
                        ?.toString();

                if (imgUrl != null && !imgUrl.startsWith('http')) {
                  if (!imgUrl.startsWith('/')) imgUrl = '/$imgUrl';
                  imgUrl = '${ApiConstants.baseUrl}$imgUrl';
                }

                if (imgUrl != null && imgUrl.isNotEmpty) {
                  return Image.network(
                    imgUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Image.asset(
                      fallbackAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.directions_car,
                        color: Color(0xFF00ABE4),
                      ),
                    ),
                  );
                }
                return Image.asset(
                  fallbackAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.directions_car,
                    color: Color(0xFF00ABE4),
                  ),
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
                SizedBox(height: 2.h),
                Text(
                  displaySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCardContainer() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Share OTP with Driver',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (_otpError != null && !_isFetchingOtp)
                GestureDetector(
                  onTap: () => _fetchRealTripOtp(isRetry: true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        color: const Color(0xFF00ABE4),
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Retry',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00ABE4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Driver will ask for this 4-digit code to start ride',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 11.sp,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          if (_isFetchingOtp)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC000)),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    '• • • •',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.w,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            )
          else if (_otpError != null || _otp == null || _otp!.isEmpty || _otp == '----')
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 18.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _otpError ?? 'Unable to load OTP',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _fetchRealTripOtp(isRetry: true),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00ABE4),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9EB),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFFFC000), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _otp!.split('').map((digit) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 6.w),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      digit,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context) {
    return Column(
      children: [
        _buildRouteTimeline(_bookingData),
        SizedBox(height: 12.h),
        _buildFarePaymentRow(_bookingData),
        SizedBox(height: 12.h),
        Row(
          children: [
            _buildActionButton(
              Icons.phone,
              'Call',
              onTap: () => _callDriver(context),
            ),
            SizedBox(width: 8.w),
            _buildActionButton(
              Icons.chat_bubble_outline,
              'Chat',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverChatScreen(
                      driverData: {..._bookingData, 'tripId': widget.tripId},
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteTimeline(Map<String, dynamic>? data) {
    final booking = data?['booking'] is Map
        ? Map<String, dynamic>.from(data!['booking'] as Map)
        : <String, dynamic>{};
    final pickup = booking['pickup'] ?? data?['pickup'] ?? {};
    final drop = booking['drop'] ?? data?['drop'] ?? {};
    final distanceKm =
        (booking['distanceKm'] ?? data?['distanceKm'])?.toString() ?? '0.0';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 18.h),
          child: const RouteMarkerTimeline(connectorHeight: 32),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            children: [
              _buildAddressBox(
                label: 'Pick-up Location',
                address:
                    (booking['pickupAddress'] ??
                            data?['pickupAddress'] ??
                            booking['pickupLocation'] ??
                            data?['pickupLocation'] ??
                            pickup['address'] ??
                            'Loading...')
                        .toString(),
                distance: '',
              ),
              SizedBox(height: 10.h),
              _buildAddressBox(
                label: 'Your Destination',
                address:
                    (booking['dropAddress'] ??
                            data?['dropAddress'] ??
                            booking['dropLocation'] ??
                            data?['dropLocation'] ??
                            drop['address'] ??
                            'Loading...')
                        .toString(),
                distance: '',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressBox({
    required String label,
    required String address,
    required String distance,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 9.h, 14.w, 9.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF00ABE4).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppFonts.captionDark.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: _addressLabelFontSize.sp,
                    fontWeight: _addressLabelFontWeight,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodyText.copyWith(
                    color: Colors.black,
                    fontSize: _addressValueFontSize.sp,
                    fontWeight: _addressValueFontWeight,
                  ),
                ),
              ],
            ),
          ),
          if (distance.isNotEmpty) ...[
            SizedBox(width: 8.w),
            Text(
              distance,
              style: AppFonts.captionDark.copyWith(
                color: const Color(0xFF7C8795),
                fontSize: 9.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFarePaymentRow(Map<String, dynamic>? data) {
    final booking = data?['booking'] is Map
        ? Map<String, dynamic>.from(data!['booking'] as Map)
        : <String, dynamic>{};
    final fare =
        (booking['totalFare'] ??
                data?['totalFare'] ??
                booking['estimatedFare'] ??
                data?['estimatedFare'] ??
                booking['fare'] ??
                data?['fare'] ??
                '0')
            .toString();
    final paymentMethod =
        (booking['paymentType'] ??
                data?['paymentType'] ??
                booking['paymentMethod'] ??
                data?['paymentMethod'] ??
                booking['pickup']?['paymentMethod'] ??
                data?['pickup']?['paymentMethod'] ??
                'Cash')
            .toString()
            .toUpperCase();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2FBFE),
        borderRadius: BorderRadius.circular(5.r),
        border: Border.all(color: const Color(0xFFD8F2FC)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.currency_rupee,
            color: const Color(0xFF00ABE4),
            size: 21.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(child: _buildInfoBlock('Fare', '₹$fare')),
          Container(width: 1.w, height: 28.h, color: const Color(0xFFD7EDF5)),
          SizedBox(width: 14.w),
          Icon(
            Icons.account_balance_wallet_outlined,
            color: const Color(0xFF00ABE4),
            size: 21.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(child: _buildInfoBlock('Payment Method', paymentMethod)),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.captionDark.copyWith(
            color: const Color(0xFF8390A0),
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: AppFonts.h2.copyWith(
            color: Colors.black,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _callDriver(BuildContext context) async {
    final phone = _readValue([
      _driver['phone'],
      _driver['mobile'],
      _driver['phoneNumber'],
      _driver['mobileNumber'],
      _driver['contactNumber'],
      _driver['user']?['phone'],
      _driver['user']?['mobile'],
    ])?.toString();

    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone number not available')),
        );
      }
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    final didLaunch = await launchUrl(uri);

    if (!didLaunch && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone dialer')),
      );
    }
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

  Widget _buildSafetyBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12.r,
            backgroundColor: const Color(0xFF22C55E),
            child: Icon(Icons.verified, color: Colors.white, size: 14.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Driver',
                  style: AppFonts.h2.copyWith(
                    color: const Color(0xFF039855),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Your safety is our priority. Emergency support is available 24x7',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.captionDark.copyWith(
                    color: const Color(0xFF8A95A3),
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
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
}
