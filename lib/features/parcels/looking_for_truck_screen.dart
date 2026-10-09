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
import '../rides/driver_assigned_screen.dart';
import 'package:get/get.dart';
import '../main_navigation_screen.dart';

class LookingForTruckScreen extends StatefulWidget {
  final String bookingId;
  const LookingForTruckScreen({super.key, required this.bookingId});

  @override
  State<LookingForTruckScreen> createState() => _LookingForTruckScreenState();
}

class _LookingForTruckScreenState extends State<LookingForTruckScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _truckIcon;
  BitmapDescriptor? _userLocationIcon;
  bool _isNavigating = false;
  bool _isCancelling = false;
  String? _pendingPickupOtp;
  Timer? _searchPulseTimer;
  double _searchRadius = 180;
  bool _isPulseExpanding = true;

  Future<void> _handleDriverFound(dynamic data) async {
    print('--- [SOCKET_IO] Received goodsDriverAssigned event: $data ---');
    if (!mounted || _isNavigating) return;

    Map<String, dynamic> payload = {};
    if (data is List && data.isNotEmpty && data[0] is Map) {
      payload = Map<String, dynamic>.from(data[0] as Map);
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    }
    if (!SocketService.to.isEventForBooking(payload, widget.bookingId)) return;
    _isNavigating = true;
    payload['isGoods'] = true;
    payload['tripId'] = widget.bookingId;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    if (_pendingPickupOtp != null) {
      payload['otp'] = _pendingPickupOtp;
      payload['pickupOtp'] = _pendingPickupOtp;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DriverAssignedScreen(tripId: widget.bookingId, driverData: payload),
      ),
    );
  }

  void _handlePickupOtp(dynamic data) {
    final payload = data is List && data.isNotEmpty ? data.first : data;
    if (payload is! Map) return;
    final bookingId =
        payload['bookingId'] ??
        payload['goodsBookingId'] ??
        payload['tripId'] ??
        payload['booking']?['id'];
    if (bookingId != null && bookingId.toString() != widget.bookingId) return;
    final otp =
        payload['otp'] ??
        payload['pickupOtp'] ??
        payload['booking']?['pickupOtp'];
    if (otp != null && otp.toString().isNotEmpty) {
      _pendingPickupOtp = otp.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    print(
      '--- [SOCKET_IO] LookingForTruckScreen started for Booking ID: ${widget.bookingId} ---',
    );
    _loadMarkerIcons();
    _getCurrentLocation();
    _searchPulseTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || _currentPosition == null) return;
      setState(() {
        _searchRadius += _isPulseExpanding ? 12 : -12;
        if (_searchRadius >= 480) _isPulseExpanding = false;
        if (_searchRadius <= 180) _isPulseExpanding = true;
      });
    });

    // Listen for goods driver assigned event
    SocketService.to.listenTo(
      SocketEvents.goodsDriverAssigned,
      _handleDriverFound,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsPickupOtpSent,
      _handlePickupOtp,
    );
  }

  Future<void> _loadMarkerIcons() async {
    try {
      // 1. Load and scale truck icon
      final ByteData truckData = await rootBundle.load(
        'assets/images/truck.png',
      );
      final ui.Codec truckCodec = await ui.instantiateImageCodec(
        truckData.buffer.asUint8List(),
        targetWidth: 80,
      );
      final ui.FrameInfo truckFi = await truckCodec.getNextFrame();
      final ByteData? truckByteData = await truckFi.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      // 2. Generate custom user location icon on canvas
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      const Size size = Size(100, 100);
      final double centerX = size.width / 2;
      final double centerY = size.height / 2;

      // Draw translucent outer ripple
      final Paint ripplePaint = Paint()
        ..color = const Color(0xFFF4B41A).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 45, ripplePaint);

      // Draw white border circle
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 22, borderPaint);

      // Draw solid yellow inner circle
      final Paint innerPaint = Paint()
        ..color = const Color(0xFFF4B41A)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 18, innerPaint);

      // Draw white arrowhead (pointing up-right / 45 degrees)
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
        if (truckByteData != null) {
          _truckIcon = BitmapDescriptor.fromBytes(
            truckByteData.buffer.asUint8List(),
          );
        }
        if (userByteData != null) {
          _userLocationIcon = BitmapDescriptor.fromBytes(
            userByteData.buffer.asUint8List(),
          );
        }
        _updateMarkers();
      });
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

      // User location marker
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

      // Dummy trucks around user location
      if (_truckIcon != null) {
        final LatLng truck1Pos = LatLng(
          _currentPosition!.latitude + 0.0018,
          _currentPosition!.longitude - 0.0018,
        );
        final LatLng truck2Pos = LatLng(
          _currentPosition!.latitude + 0.0018,
          _currentPosition!.longitude + 0.0018,
        );
        final LatLng truck3Pos = LatLng(
          _currentPosition!.latitude + 0.0005,
          _currentPosition!.longitude + 0.0022,
        );

        _markers.add(
          Marker(
            markerId: const MarkerId('truck1'),
            position: truck1Pos,
            icon: _truckIcon!,
            rotation: _calculateBearing(truck1Pos, userLatLng) + 90,
          ),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('truck2'),
            position: truck2Pos,
            icon: _truckIcon!,
            rotation: _calculateBearing(truck2Pos, userLatLng) + 90,
          ),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('truck3'),
            position: truck3Pos,
            icon: _truckIcon!,
            rotation: _calculateBearing(truck3Pos, userLatLng) + 90,
          ),
        );
      }
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
    SocketService.to.stopListening(
      SocketEvents.goodsDriverAssigned,
      _handleDriverFound,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsPickupOtpSent,
      _handlePickupOtp,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: Stack(
        children: [
          // Background Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.7041, 77.1025), // Default
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
                    fillColor: const Color(0xFFF4B41A).withValues(alpha: 0.07),
                    strokeColor: const Color(0xFFF4B41A).withValues(alpha: 0.28),
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
                    children: [
                      Text(
                        'Looking for a truck nearby...',
                        style: AppFonts.h2.copyWith(
                          fontSize: 18.sp,
                          color: Colors.black,
                        ),
                      ),
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
                          color: Color(0xFFF4B41A),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: _isCancelling
                          ? null
                          : () async {
                              setState(() => _isCancelling = true);
                              print(
                                '--- [SOCKET_IO] Cancelling booking ID: ${widget.bookingId} ---',
                              );
                              try {
                                await ApiService.to.post(
                                  ApiEndpoints.goodsCancel(widget.bookingId),
                                  body: {
                                    'reason': 'User cancelled while searching',
                                  },
                                );
                              } catch (e) {
                                print(
                                  '--- [SOCKET_IO] Cancel booking API failed: $e ---',
                                );
                              }
                              if (!mounted) return;
                              Get.offAll(() => const MainNavigationScreen());
                            },
                      child: _isCancelling
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFF4B41A),
                              ),
                            )
                          : Text(
                              'Cancel Booking',
                              style: AppFonts.buttonText.copyWith(
                                color: Colors.black,
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
    );
  }
}
