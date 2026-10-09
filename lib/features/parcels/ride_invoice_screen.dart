import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../constants/app_fonts.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils.dart';
import 'looking_for_truck_screen.dart';
import '../../widgets/location_route_markers.dart';

class RideInvoiceScreen extends StatefulWidget {
  final String pickupAddress;
  final String pickupContactName;
  final String pickupContactPhone;
  final LatLng pickupLatLng;
  final String dropAddress;
  final String dropContactName;
  final String dropContactPhone;
  final LatLng dropLatLng;
  final Map<String, dynamic> selectedParcel;
  final String? estimateId;
  final Map<String, dynamic> estimateRequest;
  final String goodsType;
  final String helperRequired;

  const RideInvoiceScreen({
    super.key,
    required this.pickupAddress,
    required this.pickupContactName,
    required this.pickupContactPhone,
    required this.pickupLatLng,
    required this.dropAddress,
    required this.dropContactName,
    required this.dropContactPhone,
    required this.dropLatLng,
    required this.selectedParcel,
    this.estimateId,
    required this.estimateRequest,
    required this.goodsType,
    required this.helperRequired,
  });

  @override
  State<RideInvoiceScreen> createState() => _RideInvoiceScreenState();
}

class _RideInvoiceScreenState extends State<RideInvoiceScreen> {
  bool _isBooking = false;
  String? _errorMessage;

  String? get _estimateId {
    final value =
        widget.estimateId?.trim() ??
        widget.selectedParcel['estimateId']?.toString().trim();
    return value != null && value.isNotEmpty ? value : null;
  }

  double _getPriceValue() {
    final backendFare =
        widget.selectedParcel['fare'] ?? widget.selectedParcel['totalFare'];
    if (backendFare is num) return backendFare.toDouble();
    final parsedBackendFare = double.tryParse(backendFare?.toString() ?? '');
    if (parsedBackendFare != null) return parsedBackendFare;

    final priceStr = widget.selectedParcel['price']?.toString() ?? '0';
    final cleaned = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _createBooking() async {
    if (_isBooking) return;
    if (_estimateId == null) {
      AppUtils.showSnackBar(
        context,
        'Fare estimate expired or unavailable. Please select the vehicle again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isBooking = true;
      _errorMessage = null;
    });

    try {
      final estimateRequest = widget.estimateRequest;
      final selectedVehicleModelId = widget.selectedParcel['vehicleModelId']
          ?.toString()
          .trim();
      final selectedVehicleType = widget.selectedParcel['vehicleType']
          ?.toString()
          .trim();
      final selectedVehicleName = widget.selectedParcel['vehicleName']
          ?.toString()
          .trim();
      if (selectedVehicleModelId == null || selectedVehicleModelId.isEmpty) {
        throw Exception(
          'Selected vehicle model is unavailable. Please select the vehicle again.',
        );
      }
      if (selectedVehicleType == null || selectedVehicleType.isEmpty) {
        throw Exception(
          'Selected vehicle type is unavailable. Please select the vehicle again.',
        );
      }
      if (selectedVehicleName == null || selectedVehicleName.isEmpty) {
        throw Exception(
          'Selected vehicle name is unavailable. Please select the vehicle again.',
        );
      }

      final body = <String, dynamic>{
        'pickup': estimateRequest['pickup'],
        'drop': estimateRequest['drop'],
        'categoryId':
            widget.selectedParcel['categoryId'] ?? selectedVehicleModelId,
        'vehicleCategoryId':
            widget.selectedParcel['categoryId'] ?? selectedVehicleModelId,
        'fareEstimateId': _estimateId,
        'paymentMethod': 'CASH',
        'notes':
            'Goods: ${widget.selectedParcel['goodsType'] ?? selectedVehicleName}. '
            'Sender: ${widget.pickupContactName} (${widget.pickupContactPhone}), '
            'Receiver: ${widget.dropContactName} (${widget.dropContactPhone})',
        'idempotencyKey': 'goods-${DateTime.now().microsecondsSinceEpoch}',
      };

      final bookingUrl = '${ApiConstants.baseUrl}${ApiEndpoints.goodsBookings}';
      debugPrint('==================================================');
      debugPrint('🚀 === [CREATE GOODS BOOKING API CALL] ===');
      debugPrint('URL: $bookingUrl');
      debugPrint('Payload Body: $body');
      debugPrint('==================================================');

      final response = await ApiService.to.post(
        ApiEndpoints.goodsBookings,
        body: body,
      );

      debugPrint('==================================================');
      debugPrint('📥 === [CREATE GOODS BOOKING API RESPONSE] ===');
      debugPrint('URL: $bookingUrl');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.data}');
      debugPrint('==================================================');

      final responseBody = response.data;
      final data = responseBody is Map ? responseBody['data'] : null;
      final bookingId = data is Map
          ? (data['id'] ?? data['bookingId'] ?? data['goodsBookingId'])
                ?.toString()
          : null;

      debugPrint('✅ [BOOKING CREATED SUCCESSFULLY] Booking ID: $bookingId');

      if (bookingId == null || bookingId.isEmpty) {
        throw Exception('Booking created but booking id was not returned.');
      }

      if (!mounted) return;
      if (data is Map && data['_fareRecalculated'] == true) {
        AppUtils.showSnackBar(context, 'Fare was refreshed due to time limit.');
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LookingForTruckScreen(bookingId: bookingId),
        ),
      );
    } catch (error) {
      debugPrint('==================================================');
      debugPrint('❌ === [CREATE GOODS BOOKING API ERROR] ===');
      debugPrint('URI: ${ApiEndpoints.goodsBookings}');
      if (error is ApiException) {
        debugPrint('Status Code: ${error.statusCode}');
        debugPrint('Error Message: ${error.message}');
        debugPrint('Response Body: ${error.responseBody}');
      } else {
        debugPrint('Error: $error');
      }
      debugPrint('==================================================');
      if (!mounted) return;
      final errorMessage = error is ApiException
          ? (error.statusCode >= 500
                ? 'Server is unavailable. Please try again in a moment.'
                : error.message)
          : 'Booking could not be created. Please try again.';
      setState(() {
        _errorMessage = errorMessage;
      });
      AppUtils.showSnackBar(context, errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceValue = _getPriceValue();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              color: const Color(0xFFE6F7FD),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16.h,
                bottom: 16.h,
                left: 20.w,
                right: 20.w,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18.sp,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Text(
                      'Ride Invoice',
                      style: AppFonts.h1.copyWith(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Invoice Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                child: Column(
                  children: [
                    // Location Details Card
                    Container(
                      padding: EdgeInsets.only(
                        top: 14.h,
                        right: 14.w,
                        bottom: 14.h,
                        left: 14.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.black.withOpacity(0.10),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Details',
                            style: AppFonts.h2.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                // Timeline Dots and Line
                                Column(
                                  children: [
                                    SizedBox(height: 8.h),
                                    const RouteLocationMarker.pickup(),
                                    // Line
                                    Expanded(
                                      child: Container(
                                        width: 1.5.w,
                                        color: Colors.grey.shade300,
                                        margin: EdgeInsets.symmetric(
                                          vertical: 2.h,
                                        ),
                                      ),
                                    ),
                                    const RouteLocationMarker.dropOff(),
                                    SizedBox(height: 8.h),
                                  ],
                                ),
                                SizedBox(width: 8.w),
                                // Texts and Boxes
                                Expanded(
                                  child: Column(
                                    children: [
                                      // Top Box (Pickup)
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.only(
                                          top: 8.h,
                                          right: 12.w,
                                          bottom: 8.h,
                                          left: 12.w,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFF0F0F0),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${widget.pickupContactName} | ${widget.pickupContactPhone}',
                                              style: AppFonts.captionDark
                                                  .copyWith(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 12.sp,
                                                  ),
                                            ),
                                            SizedBox(height: 3.h),
                                            Text(
                                              widget.pickupAddress,
                                              style: AppFonts.bodyText.copyWith(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      // Bottom Box (Delivery)
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.only(
                                          top: 8.h,
                                          right: 12.w,
                                          bottom: 8.h,
                                          left: 12.w,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFF0F0F0),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${widget.dropContactName} | ${widget.dropContactPhone}',
                                              style: AppFonts.captionDark
                                                  .copyWith(
                                                    color: Colors.grey.shade500,
                                                    fontSize: 12.sp,
                                                  ),
                                            ),
                                            SizedBox(height: 3.h),
                                            Text(
                                              widget.dropAddress,
                                              style: AppFonts.bodyText.copyWith(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13.sp,
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
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Booking Summary Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 16.w,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFF4B41A).withValues(alpha: 0.2),
                          width: 1.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking Summary',
                            style: AppFonts.h2.copyWith(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vehicle Type',
                                style: AppFonts.captionDark.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.selectedParcel['title'] ?? 'Truck',
                                style: AppFonts.bodyText.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Goods Type',
                                style: AppFonts.captionDark.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.goodsType,
                                style: AppFonts.bodyText.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Helper Service',
                                style: AppFonts.captionDark.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.helperRequired,
                                style: AppFonts.bodyText.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estimate ETA',
                                style: AppFonts.captionDark.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.selectedParcel['time'] ?? 'ETA 8 mins',
                                style: AppFonts.bodyText.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Divider(color: Colors.grey.shade200),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Fare',
                                style: AppFonts.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '₹${priceValue.toStringAsFixed(2)}',
                                style: AppFonts.h1.copyWith(
                                  fontSize: 16.sp,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Payment timing information
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.w,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFFFCC80),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFFF57C00),
                            size: 24.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pay after the truck arrives',
                                  style: AppFonts.bodyText.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE65100),
                                    fontSize: 13.sp,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'We will find a truck first. When the driver reaches your pickup location, pay 50% before sharing the pickup OTP.',
                                  style: AppFonts.bodyText.copyWith(
                                    color: const Color(
                                      0xFFE65100,
                                    ).withOpacity(0.8),
                                    fontSize: 11.sp,
                                    height: 1.3,
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
              ),
            ),

            // Bottom booking action
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 20.w),
              decoration: BoxDecoration(
                color: Colors.white,
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
                        'Total estimated fare',
                        style: AppFonts.captionDark.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${priceValue.toStringAsFixed(2)}',
                        style: AppFonts.h1.copyWith(
                          fontSize: 20.sp,
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4B41A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: _isBooking ? null : _createBooking,
                      child: _isBooking
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text(
                              'Book Pickup',
                              style: AppFonts.buttonText.copyWith(
                                color: Colors.black,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
}
