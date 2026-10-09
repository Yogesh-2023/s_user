import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_service.dart';
import '../../core/maps/smooth_map_motion.dart';
import 'razorpay_checkout_sheet.dart';

class GoodsTrackingScreen extends StatefulWidget {
  final String bookingId;

  const GoodsTrackingScreen({super.key, required this.bookingId});

  @override
  State<GoodsTrackingScreen> createState() => _GoodsTrackingScreenState();
}

class _GoodsTrackingScreenState extends State<GoodsTrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _trackingData;
  Timer? _trackingTimer;
  final SmoothMapMotion _mapMotion = SmoothMapMotion();
  LatLng? _displayedDriverLocation;
  double _driverBearing = 0;
  bool _hasFittedRoute = false;

  final TextEditingController _otpController = TextEditingController();
  bool _isActionLoading = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _fetchTrackingDetails();
    // Poll tracking and booking details every 5 seconds
    _trackingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchTrackingDetails(silent: true);
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _mapMotion.dispose();
    _otpController.dispose();
    super.dispose();
  }

  List<LatLng> _decodePolyline(String str) {
    List<LatLng> coordinates = [];
    int index = 0, len = str.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      coordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return coordinates;
  }

  Future<void> _fetchTrackingDetails({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final bookingRes = await ApiService.to.get(
        ApiEndpoints.goodsBookingDetails(widget.bookingId),
      );

      final trackingRes = await ApiService.to.get(
        ApiEndpoints.goodsTracking(widget.bookingId),
      );

      if (bookingRes.statusCode == 200 && bookingRes.data != null) {
        final bookingData = bookingRes.data['data'];
        final trackingData =
            trackingRes.statusCode == 200 && trackingRes.data != null
            ? trackingRes.data['data']
            : null;

        if (mounted) {
          setState(() {
            _bookingData = bookingData;
            _trackingData = trackingData;
            _isLoading = false;
          });
          _updateMapMarkersAndRoute();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = bookingRes.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('ApiException:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _updateMapMarkersAndRoute() {
    if (_bookingData == null) return;

    final pickup = _bookingData!['pickupLocation'] ?? {};
    final drop = _bookingData!['dropLocation'] ?? {};

    final pickupLatLng = LatLng(
      (pickup['latitude'] as num?)?.toDouble() ?? 28.628,
      (pickup['longitude'] as num?)?.toDouble() ?? 77.364,
    );
    final dropLatLng = LatLng(
      (drop['latitude'] as num?)?.toDouble() ?? 28.552,
      (drop['longitude'] as num?)?.toDouble() ?? 77.554,
    );

    LatLng? driverLatLng;
    if (_trackingData != null && _trackingData!['currentLocation'] != null) {
      final curLoc = _trackingData!['currentLocation'];
      driverLatLng = LatLng(
        (curLoc['latitude'] as num?)?.toDouble() ?? pickupLatLng.latitude,
        (curLoc['longitude'] as num?)?.toDouble() ?? pickupLatLng.longitude,
      );
    }

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLatLng,
          infoWindow: InfoWindow(
            title: 'Pickup Address',
            snippet: pickup['address']?.toString(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('drop'),
          position: dropLatLng,
          infoWindow: InfoWindow(
            title: 'Drop Address',
            snippet: drop['address']?.toString(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      if (_displayedDriverLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: _displayedDriverLocation!,
            rotation: _driverBearing,
            flat: true,
            infoWindow: const InfoWindow(title: 'Driver Current Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
      }

      // Check for route polyline
      if (_bookingData!['routePolyline'] != null) {
        final polyStr = _bookingData!['routePolyline'] as String;
        if (polyStr.isNotEmpty) {
          final points = _decodePolyline(polyStr);
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('tracking_route'),
              points: points,
              color: const Color(0xFFF4B41A),
              width: 5,
            ),
          );
        }
      } else {
        // Fallback straight line
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('fallback_route'),
            points: [pickupLatLng, dropLatLng],
            color: const Color(0xFFF4B41A).withValues(alpha: 0.6),
            width: 4,
          ),
        );
      }
    });

    if (driverLatLng != null) {
      _mapMotion.move(
        from: _displayedDriverLocation,
        to: driverLatLng,
        onUpdate: (position, bearing) {
          if (!mounted) return;
          setState(() {
            _displayedDriverLocation = position;
            _driverBearing = bearing;
            _markers.removeWhere(
              (marker) => marker.markerId == const MarkerId('driver'),
            );
            _markers.add(
              Marker(
                markerId: const MarkerId('driver'),
                position: position,
                rotation: bearing,
                flat: true,
                infoWindow: const InfoWindow(title: 'Driver Current Location'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
            );
          });
        },
      );
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: driverLatLng,
            zoom: 16,
            bearing: _driverBearing,
          ),
        ),
      );
    }

    // Animate map bounds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mapController != null && !_hasFittedRoute) {
        _hasFittedRoute = true;
        final List<LatLng> boundsPoints = [pickupLatLng, dropLatLng];
        if (driverLatLng != null) boundsPoints.add(driverLatLng);

        double minLat = boundsPoints
            .map((p) => p.latitude)
            .reduce((a, b) => a < b ? a : b);
        double maxLat = boundsPoints
            .map((p) => p.latitude)
            .reduce((a, b) => a > b ? a : b);
        double minLng = boundsPoints
            .map((p) => p.longitude)
            .reduce((a, b) => a < b ? a : b);
        double maxLng = boundsPoints
            .map((p) => p.longitude)
            .reduce((a, b) => a > b ? a : b);

        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
      }
    });
  }

  Future<void> _confirmAdvancePayment() async {
    final data = _bookingData ?? const <String, dynamic>{};
    final totalFare = (data['totalFare'] as num?)?.toDouble() ?? 0;
    final advanceAmount =
        (data['advanceFareAmount'] as num?)?.toDouble() ?? totalFare * 0.5;
    if (advanceAmount <= 0) {
      setState(() => _actionError = 'Advance amount is not available yet.');
      return;
    }

    final paymentResult = await RazorpayCheckoutSheet.show(
      context,
      amount: advanceAmount,
      description: '50% truck booking advance',
    );
    if (!mounted || paymentResult?['success'] != true) return;

    setState(() {
      _isActionLoading = true;
      _actionError = null;
    });

    try {
      final response = await ApiService.to.patch(
        ApiEndpoints.goodsAdvancePayment(widget.bookingId),
        body: {
          "paymentMode": "ONLINE",
          "transactionId": paymentResult?['transactionId'],
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Advance payment confirmed!')),
        );
        _fetchTrackingDetails();
      } else {
        setState(() {
          _actionError = response.message;
        });
      }
    } catch (e) {
      setState(() {
        _actionError = e.toString().replaceAll('ApiException:', '').trim();
      });
    } finally {
      setState(() {
        _isActionLoading = false;
      });
    }
  }

  Future<void> _verifyOtp(bool isPickup) async {
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _actionError = 'Please enter the OTP';
      });
      return;
    }

    setState(() {
      _isActionLoading = true;
      _actionError = null;
    });

    final endpoint = isPickup
        ? ApiEndpoints.goodsVerifyPickupOtp(widget.bookingId)
        : ApiEndpoints.goodsVerifyDeliveryOtp(widget.bookingId);

    try {
      final response = await ApiService.to.post(
        endpoint,
        body: {"otp": _otpController.text.trim()},
      );

      if (response.statusCode == 200 && response.data != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPickup
                  ? 'Pickup OTP verified successfully!'
                  : 'Delivery OTP verified successfully!',
            ),
          ),
        );
        _otpController.clear();
        _fetchTrackingDetails();
      } else {
        setState(() {
          _actionError = response.message;
        });
      }
    } catch (e) {
      setState(() {
        _actionError = e.toString().replaceAll('ApiException:', '').trim();
      });
    } finally {
      setState(() {
        _isActionLoading = false;
      });
    }
  }

  String _getDisplayStatus(String? status) {
    if (status == null) return 'Booked';
    switch (status) {
      case 'PENDING_DRIVER_ASSIGNMENT':
        return 'Finding Driver';
      case 'DRIVER_ASSIGNED':
        return 'Driver Assigned';
      case 'AT_PICKUP':
        return 'Driver at Pickup';
      case 'GOODS_PICKED_UP':
        return 'Goods Picked Up';
      case 'IN_TRANSIT':
        return 'In Transit';
      case 'ARRIVED_DESTINATION':
        return 'Arrived at Destination';
      case 'DELIVERED':
        return 'Delivered';
      case 'PAYMENT_PENDING':
        return 'Payment Pending';
      case 'PAYMENT_COMPLETED':
        return 'Payment Completed';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _bookingData == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF4B41A)),
        ),
      );
    }

    if (_errorMessage != null && _bookingData == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 20.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16.h),
                Text(_errorMessage!, textAlign: TextAlign.center),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => _fetchTrackingDetails(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _bookingData ?? {};
    final status = data['status'] as String? ?? 'PENDING_DRIVER_ASSIGNMENT';
    final driver = data['driver'] ?? {};
    final hasDriver = driver.isNotEmpty;

    final tracking = _trackingData != null ? _trackingData!['tracking'] : null;
    final double distanceKm =
        (tracking?['distanceKm'] as num?)?.toDouble() ?? 0.0;
    final int estDurationMin =
        (tracking?['estimatedDurationMin'] as num?)?.toInt() ?? 0;
    final String targetType =
        tracking?['targetType']?.toString() ??
        (status == 'DRIVER_ASSIGNED' || status == 'AT_PICKUP'
            ? 'PICKUP'
            : 'DROP');

    final String? pickupOtpCode = data['pickupOtp']?.toString();
    final String? deliveryOtpCode = data['deliveryOtp']?.toString();

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.7080, 77.1080),
                zoom: 12.5,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                _updateMapMarkersAndRoute();
              },
            ),
          ),

          // Custom Floating Back Button & Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10.h,
            left: 20.w,
            right: 20.w,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.w,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getDisplayStatus(status),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        if (status != 'CANCELLED' && status != 'DELIVERED')
                          Row(
                            children: [
                              Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Live tracking',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Info Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag indicator
                  Container(
                    margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),

                  // ETA & Distance Stats Block
                  if (status != 'CANCELLED' && status != 'DELIVERED')
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 10.h,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'ETA Remaining',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey[500],
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                estDurationMin > 0
                                    ? '$estDurationMin mins'
                                    : 'Calculating...',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1.w,
                            height: 32.h,
                            color: Colors.grey[200],
                          ),
                          Column(
                            children: [
                              Text(
                                'Distance to $targetType',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.grey[500],
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                distanceKm > 0
                                    ? '${distanceKm.toStringAsFixed(1)} km'
                                    : 'Calculating...',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const Divider(),

                  // Action Panel (OTP Verification & Payment confirmation)
                  if (_actionError != null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 4.h,
                      ),
                      child: Text(
                        _actionError!,
                        style: TextStyle(color: Colors.red, fontSize: 11.sp),
                      ),
                    ),

                  if (status != 'DELIVERED' && status != 'CANCELLED')
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 8.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pickupOtpCode != null &&
                              (status == 'DRIVER_ASSIGNED' ||
                                  status == 'AT_PICKUP'))
                            Text(
                              'Simulation Pickup OTP: $pickupOtpCode',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                                fontSize: 12.sp,
                              ),
                            ),
                          if (deliveryOtpCode != null &&
                              (status == 'GOODS_PICKED_UP' ||
                                  status == 'IN_TRANSIT' ||
                                  status == 'ARRIVED_DESTINATION'))
                            Text(
                              'Simulation Delivery OTP: $deliveryOtpCode',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                fontSize: 12.sp,
                              ),
                            ),

                          if (status == 'AT_PICKUP' ||
                              status == 'ARRIVED_DESTINATION') ...[
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Enter OTP',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 8.h,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                ElevatedButton(
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: const Color(0xFFF4B41A),
                                     foregroundColor: Colors.black,
                                     shape: RoundedRectangleBorder(
                                       borderRadius: BorderRadius.circular(8.r),
                                     ),
                                   ),
                                  onPressed: _isActionLoading
                                      ? null
                                      : () => _verifyOtp(status == 'AT_PICKUP'),
                                  child: _isActionLoading
                                      ? SizedBox(
                                          width: 16.w,
                                          height: 16.w,
                                          child:
                                              const CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                        )
                                      : Text(
                                          status == 'AT_PICKUP'
                                              ? 'Verify Pickup'
                                              : 'Verify Delivery',
                                        ),
                                ),
                              ],
                            ),
                          ],

                          if (status == 'AT_PICKUP' &&
                              data['advancePaymentStatus'] != 'PAID') ...[
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                icon: const Icon(Icons.payment),
                                onPressed: _isActionLoading
                                    ? null
                                    : _confirmAdvancePayment,
                                label: const Text('Confirm Advance Payment'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Driver details card
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20.w,
                      right: 20.w,
                      bottom: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom + 10.h
                          : 20.h,
                      top: 8.h,
                    ),
                    child: hasDriver
                        ? Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.w,
                            ),
                             decoration: BoxDecoration(
                               color: const Color(0xFFFFF9E6),
                               borderRadius: BorderRadius.circular(16.r),
                               border: Border.all(
                                 color: const Color(
                                   0xFFF4B41A,
                                 ).withValues(alpha: 0.2),
                               ),
                             ),
                             child: Row(
                               children: [
                                 CircleAvatar(
                                   radius: 20.r,
                                   backgroundColor: const Color(
                                     0xFFF4B41A,
                                   ).withValues(alpha: 0.2),
                                   child: const Icon(
                                     Icons.person,
                                     color: Color(0xFFD97706),
                                   ),
                                 ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driver['name']?.toString() ??
                                            'Driver Assigned',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        driver['phone']?.toString() ??
                                            'Call driver',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.orange,
                                        size: 14,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        '4.8',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 12.w,
                            ),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: Colors.orange[100]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.hourglass_empty,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 12.w),
                                const Expanded(
                                  child: Text(
                                    'Finding a matching driver for your vehicle...',
                                  ),
                                ),
                              ],
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
