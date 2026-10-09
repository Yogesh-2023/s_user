import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_fonts.dart';
import '../../core/socket/socket_service.dart';
import '../../core/socket/socket_events.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils.dart';
import 'driver_assigned_screen.dart';
import 'driver_tracking_screen.dart';
import 'cancellation_reason_drawer.dart';
import '../../models/vehicle_category.dart';
import 'package:get/get.dart';
import '../main_navigation_screen.dart';
import '../notifications/controllers/notification_controller.dart';

class LookingForRideScreen extends StatefulWidget {
  final String tripId;
  final VehicleCategory? vehicleCategory;
  final String? vehicleCategoryName;

  const LookingForRideScreen({
    super.key,
    required this.tripId,
    this.vehicleCategory,
    this.vehicleCategoryName,
  });

  @override
  State<LookingForRideScreen> createState() => _LookingForRideScreenState();
}

class _LookingForRideScreenState extends State<LookingForRideScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _userLocationIcon;
  bool _isNavigating = false;
  bool _isCancelling = false;
  Timer? _searchPulseTimer;
  Timer? _statusPollingTimer;
  double _searchRadius = 180;
  bool _isPulseExpanding = true;
  String _currentStatus = 'SEARCHING_DRIVER';

  VehicleCategory? _bookedCategory;
  String? _bookedCategoryName;
  final Map<String, BitmapDescriptor> _categoryIcons = {};
  bool _hasFittedCamera = false;

  VehicleCategory? get _resolvedCategory {
    return _bookedCategory ??
        widget.vehicleCategory ??
        VehicleCategory.fromString(_bookedCategoryName) ??
        VehicleCategory.fromString(widget.vehicleCategoryName);
  }

  String get _searchingText {
    final cat = _resolvedCategory;
    if (cat != null && cat.displayName.isNotEmpty) {
      return 'Looking for a ${cat.displayName} nearby...';
    }
    return 'Looking for a ride nearby...';
  }

  String get _searchingVehicleAsset {
    final cat = _resolvedCategory;
    if (cat != null) {
      return cat.assetPath;
    }
    return 'assets/images/ridenew.png';
  }

  void _handleDriverFound(dynamic data) {
    if (!mounted || _isNavigating) return;

    dynamic rawData = data;
    if (data is List && data.isNotEmpty) {
      rawData = data.first;
    }
    final parsedData = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : null;

    if (parsedData != null) {
      final String? eventTripId =
          parsedData['tripId']?.toString() ??
          parsedData['bookingId']?.toString() ??
          parsedData['id']?.toString() ??
          parsedData['booking']?['id']?.toString();
      if (eventTripId != null &&
          eventTripId.isNotEmpty &&
          eventTripId != widget.tripId) {
        print(
          '[YOGESH][TRIP][USER] Ignoring cached event for old trip ID: $eventTripId (expected ${widget.tripId})',
        );
        return;
      }
    }

    _isNavigating = true;
    _searchPulseTimer?.cancel();
    _statusPollingTimer?.cancel();

    final driverId = parsedData?['driverId'] ??
        parsedData?['assignedDriverId'] ??
        parsedData?['driver']?['id'] ??
        parsedData?['booking']?['assignedDriverId'];

    print('''

==================================================
[USER RIDE STATUS UPDATE]
bookingId: ${widget.tripId}
previousStatus: $_currentStatus
newStatus: DRIVER_ASSIGNED
driverId: ${driverId ?? 'ASSIGNED'}
==================================================
''');

    final status = (parsedData?['status'] ?? parsedData?['booking']?['status'])?.toString().toUpperCase();
    final isStarted = status == 'STARTED' || status == 'TRIP_STARTED' || status == 'IN_PROGRESS' || status == 'IN_TRANSIT';

    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Ride Accepted',
        body: 'Your ride has been accepted by the driver.',
        type: 'RIDE_ACCEPTED',
        bookingId: widget.tripId,
        extraData: parsedData,
      );
    }

    if (isStarted) {
      print('[USER UI] Ride is in progress! Opening Trip in Progress screen for Trip ID: ${widget.tripId}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DriverTrackingScreen(
            tripId: widget.tripId,
            driverData: parsedData,
            initialState: RideState.inProgress,
          ),
        ),
      );
    } else {
      print('[USER UI] Opening driver assigned screen for Trip ID: ${widget.tripId}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DriverAssignedScreen(tripId: widget.tripId, driverData: parsedData),
        ),
      );
    }
  }

  Future<void> _checkBookingStatus() async {
    if (!mounted || _isNavigating) return;
    try {
      print('[YOGESH][BOOKING_STATUS] GET /bookings/active');
      print('[YOGESH][BOOKING_STATUS_API] Polling booking details for ID: ${widget.tripId}');
      final response = await ApiService.to.get(
        ApiEndpoints.bookingDetails(widget.tripId),
      );
      print('[YOGESH][BOOKING_STATUS] HTTP status= ${response.statusCode}');
      print('[YOGESH][BOOKING_STATUS] message= ${response.message}');
      if (!mounted || _isNavigating || !response.isSuccess) {
        print('[YOGESH][BOOKING_STATUS_API] Response not successful or unmounted. Status code: ${response.statusCode}');
        return;
      }

      final raw = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final data = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;

      final categoryInfo = data['vehicleCategory'] ?? data['category'] ?? data['booking']?['vehicleCategory'];
      if (categoryInfo != null) {
        final catName = categoryInfo is Map ? (categoryInfo['name'] ?? categoryInfo['slug']) : categoryInfo.toString();
        if (catName != null && catName.toString().isNotEmpty) {
          _bookedCategoryName = catName.toString();
          _bookedCategory = VehicleCategory.fromString(_bookedCategoryName);
        }
      }

      final status = (data['status'] ?? data['booking']?['status'])?.toString().toUpperCase();
      if (status == null || status.isEmpty) return;

      final num? version = data['version'] is num ? data['version'] as num : (data['booking']?['version'] is num ? data['booking']['version'] as num : null);

      print('[BOOKING_STATE] bookingId=${widget.tripId}, version=${version ?? 'N/A'}, oldStatus=$_currentStatus, newStatus=$status, source=BACKEND_API');

      if (status != 'SEARCHING_DRIVER' && status != 'PENDING' && status != 'NO_DRIVER_FOUND' && status != 'CANCELLED') {
        print('[USER RIDE] Real-time backend status is $status (Driver Assigned!)');
        _handleDriverFound(data);
      } else if (status == 'NO_DRIVER_FOUND') {
        _statusPollingTimer?.cancel();
        _searchPulseTimer?.cancel();
        if (!mounted || _isCancelling) return;
        _isCancelling = true;

        AppUtils.showSnackBar(
          context,
          'No drivers available nearby. Please try again.',
          isError: true,
        );
        Get.offAll(() => const MainNavigationScreen());
      } else if (status == 'CANCELLED') {
        _statusPollingTimer?.cancel();
        _searchPulseTimer?.cancel();
        if (!mounted || _isCancelling) return;
        _isCancelling = true;

        print('''

[CUSTOMER_BOOKING_CANCELLED]
bookingId: ${widget.tripId}
source: BACKEND_API
version: ${version ?? 'N/A'}
previousStatus: $_currentStatus
newStatus: CANCELLED
''');

        AppUtils.showSnackBar(
          context,
          'Ride request was cancelled.',
          isError: true,
        );
        Get.offAll(() => const MainNavigationScreen());
      }
    } catch (e) {
      print('[YOGESH][BOOKING_STATUS_API] Error checking booking status for ID ${widget.tripId}: $e');
    }
  }

  void _handleDriverAssignedEvent(dynamic data) {
    if (!mounted || _isNavigating) return;
    final parsedData = data is Map ? Map<String, dynamic>.from(data) : null;
    final String? eventTripId = parsedData?['tripId']?.toString() ??
        parsedData?['bookingId']?.toString() ??
        parsedData?['id']?.toString() ??
        parsedData?['booking']?['id']?.toString();

    if (eventTripId != null && eventTripId.isNotEmpty && eventTripId != widget.tripId) {
      print('[USER RIDE SOCKET] Ignoring driver-assigned event for different bookingId: $eventTripId (expected ${widget.tripId})');
      return;
    }
    _handleDriverFound(data);
  }

  void _handleCancellationEvent(dynamic data) {
    print('[USER RIDE SOCKET] Cancellation event received: $data');
    if (!mounted || _isCancelling) return;

    final parsedData = data is Map ? Map<String, dynamic>.from(data) : null;
    final String? eventTripId = parsedData?['tripId']?.toString() ??
        parsedData?['bookingId']?.toString() ??
        parsedData?['id']?.toString() ??
        parsedData?['booking']?['id']?.toString();

    print('[SOCKET_BOOKING_EVENT] bookingId=${eventTripId ?? 'N/A'}, active=${widget.tripId}, event=cancellation, data=$data');

    if (parsedData != null && eventTripId != null && eventTripId.isNotEmpty && eventTripId != widget.tripId) {
      print('[USER RIDE SOCKET] Ignoring cancellation event for non-matching bookingId: $eventTripId (active: ${widget.tripId})');
      return;
    }

    _statusPollingTimer?.cancel();
    _searchPulseTimer?.cancel();
    _isCancelling = true;

    print('''

[CUSTOMER_BOOKING_CANCELLED]
bookingId: ${widget.tripId}
source: BACKEND_SOCKET
version: ${parsedData?['version'] ?? 'N/A'}
previousStatus: $_currentStatus
newStatus: CANCELLED
''');

    AppUtils.showSnackBar(
      context,
      'Ride request was cancelled.',
      isError: true,
    );
    Get.offAll(() => const MainNavigationScreen());
  }

  void _handleNoDriverFoundEvent(dynamic data) {
    print('[USER RIDE SOCKET] No-driver-found event received: $data');
    if (!mounted || _isCancelling) return;

    final parsedData = data is Map ? Map<String, dynamic>.from(data) : null;
    final String? eventTripId = parsedData?['tripId']?.toString() ??
        parsedData?['bookingId']?.toString() ??
        parsedData?['id']?.toString() ??
        parsedData?['booking']?['id']?.toString();

    print('[SOCKET_BOOKING_EVENT] bookingId=${eventTripId ?? 'N/A'}, active=${widget.tripId}, event=no-driver-found, data=$data');

    if (parsedData != null && eventTripId != null && eventTripId.isNotEmpty && eventTripId != widget.tripId) {
      print('[USER RIDE SOCKET] Ignoring no-driver event for non-matching bookingId: $eventTripId (active: ${widget.tripId})');
      return;
    }

    _statusPollingTimer?.cancel();
    _searchPulseTimer?.cancel();
    _isCancelling = true;

    print('''

[BOOKING_STATE]
bookingId: ${widget.tripId}
source: BACKEND_SOCKET
version: ${parsedData?['version'] ?? 'N/A'}
oldStatus: $_currentStatus
newStatus: NO_DRIVER_FOUND
''');

    AppUtils.showSnackBar(
      context,
      'No drivers available nearby. Please try again.',
      isError: true,
    );
    Get.offAll(() => const MainNavigationScreen());
  }

  final List<String> _driverAssignedEvents = const [
    'booking:driver-assigned',
    'goods.driver.assigned',
    'driver:assigned',
    'driver:heading-to-pickup',
    'dispatch:accepted',
    SocketEvents.driverFound,
    SocketEvents.tripAccepted,
  ];

  final List<String> _cancellationEvents = const [
    'booking:cancelled',
    'goods.booking.cancelled',
    'booking:cancelled-by-user',
    'TRIP_CANCELLED',
    'TRIP_CANCELLED_BY_USER',
  ];

  final List<String> _noDriverFoundEvents = const [
    'booking:no-driver-found',
    'dispatch:no-driver-found',
    'no_driver_found',
    'goods.booking.no-driver-found',
  ];

  final Map<String, Map<String, dynamic>> _nearbyDrivers = {};

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  Future<BitmapDescriptor?> _loadScaledBitmap(String assetPath, {int width = 85}) async {
    final List<String> pathsToTry = [assetPath];
    final String lower = assetPath.toLowerCase();
    if (lower.contains('bike') && !lower.contains('bike1.png')) {
      pathsToTry.add('assets/images/Bike1.png');
    }
    if (lower.contains('auto') && !lower.contains('rickshawnew.png')) {
      pathsToTry.add('assets/images/rickshawnew.png');
    }
    if (lower.contains('sedan') && !lower.contains('ridenew.png')) {
      pathsToTry.add('assets/images/ridenew.png');
    }
    if (lower.contains('suv') && !lower.contains('suvnew.png')) {
      pathsToTry.add('assets/images/suvnew.png');
    }
    if ((lower.contains('sawariya') || lower.contains('xl')) && !lower.contains('figma_booking_vehicle_2.png')) {
      pathsToTry.add('assets/images/figma_booking_vehicle_2.png');
    }

    for (final path in pathsToTry) {
      try {
        final ByteData data = await rootBundle.load(path);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: width,
        );
        final ui.FrameInfo fi = await codec.getNextFrame();
        final ByteData? byteData = await fi.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
        }
      } catch (e) {
        debugPrint("Error loading bitmap for asset $path: $e");
      }
    }
    return null;
  }

  Future<void> _fetchNearbyDrivers() async {
    try {
      print('[USER RIDE NEARBY] GET ${ApiEndpoints.nearbyDrivers(widget.tripId)}');
      final response = await ApiService.to.get(
        ApiEndpoints.nearbyDrivers(widget.tripId),
      );
      if (!mounted) return;
      print('[USER RIDE NEARBY] HTTP status=${response.statusCode}');
      if (response.isSuccess && response.data != null) {
        final rawData = response.data is Map ? response.data['data'] : response.data;
        if (rawData is List) {
          final newDrivers = <String, Map<String, dynamic>>{};
          for (final item in rawData) {
            if (item is Map) {
              final driverId = item['driverId']?.toString() ?? item['id']?.toString() ?? item['_id']?.toString();
              if (driverId != null && driverId.isNotEmpty) {
                newDrivers[driverId] = Map<String, dynamic>.from(item);
              }
            }
          }
          setState(() {
            _nearbyDrivers.clear();
            _nearbyDrivers.addAll(newDrivers);
            _updateMarkers();
          });
          _fitCameraBoundsOnce();
          print('[USER RIDE NEARBY] Fetched ${_nearbyDrivers.length} initial nearby drivers');
        }
      }
    } catch (e) {
      print('[USER RIDE NEARBY] Error fetching initial nearby drivers: $e');
    }
  }

  BitmapDescriptor _getDriverIcon(Map<String, dynamic> driverData) {
    final dynamic catObj = driverData['vehicleCategory'] ??
        driverData['category'] ??
        driverData['vehicle']?['vehicleCategory'] ??
        driverData['vehicle']?['category'] ??
        driverData['driver']?['vehicleCategory'];

    final String? catName = catObj is Map
        ? (catObj['name'] ?? catObj['slug'] ?? catObj['code'] ?? catObj['type'] ?? catObj['id'])?.toString()
        : catObj?.toString();

    final String? catIdOrName = catName ??
        driverData['vehicleCategoryId']?.toString() ??
        driverData['vehicleType']?.toString() ??
        driverData['vehicle']?['vehicleType']?.toString() ??
        driverData['vehicle']?['type']?.toString() ??
        driverData['carType']?.toString() ??
        driverData['type']?.toString();

    final VehicleCategory? driverCat = VehicleCategory.fromString(catIdOrName);
    final VehicleCategory? resolvedCat = driverCat ?? _resolvedCategory;

    if (resolvedCat != null && _categoryIcons.containsKey(resolvedCat)) {
      return _categoryIcons[resolvedCat]!;
    }
    return _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  List<Map<String, dynamic>> _generateFallbackDrivers(LatLng center, VehicleCategory category) {
    final List<Map<String, double>> offsets = [
      {'lat': 0.0018, 'lng': 0.0015, 'heading': 45.0},   // North-East
      {'lat': -0.0014, 'lng': 0.0021, 'heading': 125.0}, // South-East
      {'lat': -0.0022, 'lng': -0.0012, 'heading': 210.0},// South-West
      {'lat': 0.0012, 'lng': -0.0024, 'heading': 305.0}, // North-West
      {'lat': 0.0026, 'lng': -0.0004, 'heading': 15.0},  // North
    ];

    final List<Map<String, dynamic>> list = [];
    for (int i = 0; i < offsets.length; i++) {
      final off = offsets[i];
      list.add({
        'driverId': 'sim_${category.name}_$i',
        'latitude': center.latitude + off['lat']!,
        'longitude': center.longitude + off['lng']!,
        'heading': off['heading']!,
        'vehicleCategory': category.name,
      });
    }
    return list;
  }

  void _fitCameraBoundsOnce() {
    if (_hasFittedCamera || _mapController == null || _currentPosition == null) return;
    if (_markers.isEmpty) return;

    final List<LatLng> points = [
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    ];

    for (final m in _markers) {
      if (m.markerId.value != 'user_location') {
        points.add(m.position);
      }
    }

    if (points.length <= 1) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _hasFittedCamera = true;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void _onDriverLocationUpdate(dynamic data) {
    if (!mounted) return;
    print('[USER RIDE NEARBY] driver_location_update socket received: $data');
    dynamic payload = data;
    if (payload is Map && payload.containsKey('data') && payload['data'] is Map) {
      payload = payload['data'];
    } else if (payload is List && payload.isNotEmpty) {
      payload = payload.first;
    }
    if (payload is! Map) return;

    final driverId = payload['driverId']?.toString() ?? payload['id']?.toString() ?? payload['driver']?['id']?.toString();
    final double? lat = _parseDouble(payload['latitude'] ?? payload['lat'] ?? payload['location']?['latitude'] ?? payload['location']?['coordinates']?[1]);
    final double? lng = _parseDouble(payload['longitude'] ?? payload['lng'] ?? payload['location']?['longitude'] ?? payload['location']?['coordinates']?[0]);

    if (driverId != null && driverId.isNotEmpty && lat != null && lng != null) {
      setState(() {
        final existing = _nearbyDrivers[driverId] ?? {};
        final Map<String, dynamic> updated = Map<String, dynamic>.from(existing);
        updated.addAll(Map<String, dynamic>.from(payload as Map));
        _nearbyDrivers[driverId] = updated;
        _updateMarkers();
      });
      print('[USER RIDE NEARBY] Updated location for driver $driverId ($lat, $lng)');
    }
  }

  void _setupSocketListeners() {
    print('[USER RIDE SOCKET] Tracking booking: ${widget.tripId}');
    SocketService.to.trackBooking(bookingId: widget.tripId);
    SocketService.to.listenTo('driver_location_update', _onDriverLocationUpdate);

    SocketService.to.onConnectionEstablished = () async {
      print('[USER RIDE SOCKET] Reconnected! Re-tracking booking and checking status.');
      if (!mounted || _isNavigating) return;
      SocketService.to.trackBooking(bookingId: widget.tripId);
      await _checkBookingStatus();
      await _fetchNearbyDrivers();
    };

    for (final event in _driverAssignedEvents) {
      SocketService.to.listenTo(event, _handleDriverAssignedEvent, triggerCached: false);
    }

    for (final event in _cancellationEvents) {
      SocketService.to.listenTo(event, _handleCancellationEvent, triggerCached: false);
    }

    for (final event in _noDriverFoundEvents) {
      SocketService.to.listenTo(event, _handleNoDriverFoundEvent, triggerCached: false);
    }
  }

  @override
  void initState() {
    super.initState();
    _bookedCategory = widget.vehicleCategory;
    _bookedCategoryName = widget.vehicleCategoryName ?? widget.vehicleCategory?.displayName;
    print(
      '[YOGESH][TRIP][USER] User booked trip. LookingForRideScreen active for Trip ID: ${widget.tripId}',
    );
    _loadMarkerIcons();
    _getCurrentLocation();
    _setupSocketListeners();
    _checkBookingStatus();
    _fetchNearbyDrivers();

    _searchPulseTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || _currentPosition == null) return;
      setState(() {
        _searchRadius += _isPulseExpanding ? 12 : -12;
        if (_searchRadius >= 480) _isPulseExpanding = false;
        if (_searchRadius <= 180) _isPulseExpanding = true;
      });
    });

    // Periodic status poll as fallback in case socket drops
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkBookingStatus();
    });
  }

  Future<void> _loadMarkerIcons() async {
    try {
      // 1. Pre-load resolved VehicleCategory icon
      if (_resolvedCategory != null) {
        final icon = await _loadScaledBitmap(_resolvedCategory!.assetPath, width: 85);
        if (icon != null) {
          _categoryIcons[_resolvedCategory!.value] = icon;
        }
      }

      // 2. Fallback car icon
      _carIcon = (_resolvedCategory != null ? _categoryIcons[_resolvedCategory!.value] : null) ??
          await _loadScaledBitmap('assets/images/ridenew.png', width: 85) ??
          await _loadScaledBitmap('assets/images/car1.png', width: 85);

      // 3. User location custom canvas marker
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      const Size size = Size(100, 100);
      final double centerX = size.width / 2;
      final double centerY = size.height / 2;

      final Paint ripplePaint = Paint()
        ..color = const Color(0xFF00ABE4).withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 45, ripplePaint);

      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 22, borderPaint);

      final Paint innerPaint = Paint()
        ..color = const Color(0xFF00ABE4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 18, innerPaint);

      final Paint arrowPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(45 * math.pi / 180);

      final Path arrowPath = Path();
      arrowPath.moveTo(0, -9);
      arrowPath.lineTo(-7, 7);
      arrowPath.lineTo(0, 3);
      arrowPath.lineTo(7, 7);
      arrowPath.close();

      canvas.drawPath(arrowPath, arrowPaint);
      canvas.restore();

      final userImg = await pictureRecorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final ByteData? userByteData = await userImg.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (!mounted) return;
      setState(() {
        if (userByteData != null) {
          _userLocationIcon = BitmapDescriptor.fromBytes(
            userByteData.buffer.asUint8List(),
          );
        }
        _updateMarkers();
      });
      _fitCameraBoundsOnce();
    } catch (e) {
      debugPrint("Error loading marker icons: $e");
    }
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final double lat1 = from.latitude * (math.pi / 180.0);
    final double lon1 = from.longitude * (math.pi / 180.0);
    final double lat2 = to.latitude * (math.pi / 180.0);
    final double lon2 = to.longitude * (math.pi / 180.0);

    final double dLon = lon2 - lon1;

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double radians = math.atan2(y, x);
    final double degrees = radians * (180.0 / math.pi);
    return (degrees + 360.0) % 360.0;
  }

  void _updateMarkers() {
    if (_currentPosition == null) return;

    setState(() {
      _markers.clear();

      final LatLng userLatLng = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      // User location marker (Blue marker)
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: userLatLng,
          icon:
              _userLocationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );

      final Map<String, Map<String, dynamic>> driversToPlot = {};

      if (_nearbyDrivers.length > 1) {
        // If API/socket returned multiple real drivers, plot all real drivers
        driversToPlot.addAll(_nearbyDrivers);
      } else {
        // If 0 or 1 real driver returned (dev/test mode), plot real driver + fallback drivers around user position
        driversToPlot.addAll(_nearbyDrivers);
        final categoryToUse = _resolvedCategory ?? const VehicleCategory(id: 'AUTO', name: 'Auto', slug: 'auto');
        final fallbacks = _generateFallbackDrivers(userLatLng, categoryToUse);
        for (final fb in fallbacks) {
          final id = fb['driverId'].toString();
          if (!driversToPlot.containsKey(id) && driversToPlot.length < 5) {
            driversToPlot[id] = fb;
          }
        }
      }

      // Plot all vehicle markers
      driversToPlot.forEach((driverId, driverData) {
        final double? lat = _parseDouble(driverData['latitude']);
        final double? lng = _parseDouble(driverData['longitude']);
        if (lat != null && lng != null) {
          final LatLng driverLatLng = LatLng(lat, lng);
          final double heading = _parseDouble(driverData['heading']) ??
              _calculateBearing(driverLatLng, userLatLng) + 90;
          final BitmapDescriptor icon = _getDriverIcon(driverData);
          _markers.add(
            Marker(
              markerId: MarkerId('driver_$driverId'),
              position: driverLatLng,
              icon: icon,
              rotation: heading,
              anchor: const Offset(0.5, 0.5),
            ),
          );
        }
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _updateMarkers();
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

  @override
  void dispose() {
    _searchPulseTimer?.cancel();
    _statusPollingTimer?.cancel();
    SocketService.to.onConnectionEstablished = null;
    SocketService.to.stopListening('driver_location_update', _onDriverLocationUpdate);
    SocketService.to.untrackBooking(bookingId: widget.tripId);

    for (final event in _driverAssignedEvents) {
      SocketService.to.stopListening(event, _handleDriverAssignedEvent);
    }
    for (final event in _cancellationEvents) {
      SocketService.to.stopListening(event, _handleCancellationEvent);
    }
    for (final event in _noDriverFoundEvents) {
      SocketService.to.stopListening(event, _handleNoDriverFoundEvent);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AppUtils.showSnackBar(
          context,
          'Searching for nearby drivers. You can cancel if you wish to exit.',
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
              markers: _markers,
              circles: {
                if (_currentPosition != null)
                  Circle(
                    circleId: const CircleId('driver_search_radius'),
                    center: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    radius: _searchRadius,
                    fillColor: const Color(0xFF00ABE4).withOpacity(0.07),
                    strokeColor: const Color(0xFF00ABE4).withOpacity(0.28),
                    strokeWidth: 2,
                  ),
              },
              buildingsEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_currentPosition != null) {
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

          // Bottom Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: 24.h,
                left: 24.w,
                right: 24.w,
                bottom: MediaQuery.of(context).padding.bottom + 20.h,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _searchingText,
                              style: AppFonts.h2.copyWith(
                                fontSize: 17.sp,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Image.asset(
                              _searchingVehicleAsset,
                              width: 32.w,
                              height: 32.h,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: const CircularProgressIndicator(
                          color: Color(0xFFF4B41A),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFDC3545),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: () async {
                        await CancellationReasonDrawer.show(
                          context,
                          tripId: widget.tripId,
                          onCancelledSuccess: () {
                            _searchPulseTimer?.cancel();
                            _statusPollingTimer?.cancel();
                            print('''

[LOCAL_CANCEL]
bookingId: ${widget.tripId}
reason: Customer cancellation drawer confirmed API success
source: USER_EXPLICIT_CANCEL
''');
                            Get.offAll(() => const MainNavigationScreen());
                          },
                        );
                      },
                      child: Text(
                        'Cancel Ride',
                        style: AppFonts.buttonText.copyWith(
                          color: const Color(0xFFDC3545),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
