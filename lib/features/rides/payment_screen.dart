import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import 'rate_ride_screen.dart';
import 'ride_invoice_screen.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_constants.dart';
import '../notifications/controllers/notification_controller.dart';

class PaymentScreen extends StatefulWidget {
  final String? bookingId;
  final Map<String, dynamic>? driverData;

  const PaymentScreen({super.key, this.bookingId, this.driverData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late String _selectedPaymentMethod;
  bool _isPaying = false;

  void _notifyPaymentSuccess(String? id) {
    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Payment Successful',
        body: 'Your payment for the ride was successful.',
        type: 'PAYMENT_SUCCESSFUL',
        bookingId: id,
      );
    }
  }

  void _notifyPaymentFailed(String? id) {
    if (Get.isRegistered<NotificationController>()) {
      NotificationController.to.addLocalNotification(
        title: 'Payment Failed',
        body: 'Your ride payment could not be completed.',
        type: 'PAYMENT_FAILED',
        bookingId: id,
      );
    }
  }

  Future<void> _pay() async {
    final id = widget.bookingId ?? _booking['id']?.toString();
    if (id == null || id.isEmpty || _isPaying) return;
    setState(() => _isPaying = true);
    try {
      if (_selectedPaymentMethod == 'CASH') {
        _notifyPaymentSuccess(id);
        if (mounted) {
          final fareStr = _totalFare > 0 ? '₹${_totalFare.toStringAsFixed(0)} ' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please pay ${fareStr}in cash directly to your driver.'),
              backgroundColor: const Color(0xFF00ABE4),
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RateRideScreen(
                bookingId: id,
                driverData: _reviewData,
              ),
            ),
          );
        }
        return;
      }

      final idempotencyKey = 'pay_${id}_${DateTime.now().millisecondsSinceEpoch}';

      // Step 1: Initiate Payment for Online Methods (POST /api/v1/payments)
      final response = await ApiService.to.post(
        ApiEndpoints.payments,
        headers: {
          'x-idempotency-key': idempotencyKey,
        },
        body: {
          'bookingId': id,
          'method': _selectedPaymentMethod,
        },
      );

      final Map<String, dynamic> body = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {};
      final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
      final status = (data['status'] ?? body['status'])?.toString();

      // For CASH, WALLET, or instant CAPTURED
      if (status == 'CAPTURED' || _selectedPaymentMethod == 'CASH' || _selectedPaymentMethod == 'WALLET') {
        _notifyPaymentSuccess(id);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RateRideScreen(bookingId: id, driverData: _reviewData),
          ),
        );
        return;
      }

      // Step 2: For Online Methods (UPI, Cards, etc.) -> Verify Payment
      final paymentId = (data['id'] ?? data['paymentId'])?.toString();
      final providerOrderId = (data['providerOrderId'])?.toString() ?? 'order_simulated';

      if (paymentId != null && paymentId.isNotEmpty) {
        final verifyResponse = await ApiService.to.post(
          ApiEndpoints.paymentsVerify,
          body: {
            'paymentId': paymentId,
            'providerPaymentId': providerOrderId,
            'signature': 'simulated_signature_hash',
          },
        );

        final verifyBody = verifyResponse.data is Map
            ? Map<String, dynamic>.from(verifyResponse.data as Map)
            : {};
        final verifyData = verifyBody['data'] is Map ? Map<String, dynamic>.from(verifyBody['data'] as Map) : verifyBody;
        final verifyStatus = (verifyData['status'] ?? verifyBody['status'])?.toString();

        if (verifyStatus == 'CAPTURED' || verifyResponse.statusCode == 200 || verifyResponse.statusCode == 201) {
          _notifyPaymentSuccess(id);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RateRideScreen(bookingId: id, driverData: _reviewData),
            ),
          );
          return;
        }
      }

      _notifyPaymentSuccess(id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RateRideScreen(bookingId: id, driverData: _reviewData),
        ),
      );
    } catch (error) {
      _notifyPaymentFailed(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  dynamic _readValue(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  Map<String, dynamic> _liveBookingData = {};

  Map<String, dynamic> get _rawBooking {
    final nested = widget.driverData?['booking'] ?? widget.driverData?['trip'];
    final base = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(widget.driverData ?? const {});
    return {
      if (widget.driverData != null) ...widget.driverData!,
      ...base,
      ..._liveBookingData,
    };
  }

  Map<String, dynamic> get _driver {
    final raw = _rawBooking;
    final value =
        widget.driverData?['driver'] ??
        widget.driverData?['assignedDriver'] ??
        raw['driver'] ??
        raw['assignedDriver'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> get _vehicle {
    final raw = _rawBooking;
    final driver = _driver;
    final value =
        driver['assignedVehicle'] ??
        driver['vehicle'] ??
        (driver['vehicles'] is List && (driver['vehicles'] as List).isNotEmpty
            ? driver['vehicles'][0]
            : null) ??
        (driver['driverProfile']?['vehicles'] is List &&
                (driver['driverProfile']['vehicles'] as List).isNotEmpty
            ? driver['driverProfile']['vehicles'][0]
            : null) ??
        widget.driverData?['vehicle'] ??
        widget.driverData?['assignedVehicle'] ??
        raw['vehicle'] ??
        raw['assignedVehicle'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> get _booking {
    final raw = _rawBooking;
    final driver = _driver;
    final vehicle = _vehicle;
    return {
      ...raw,
      if (driver.isNotEmpty) 'driver': driver,
      if (vehicle.isNotEmpty) 'vehicle': vehicle,
    };
  }

  Map<String, dynamic> get _reviewData {
    final booking = _booking;
    return {
      if (widget.driverData != null) ...widget.driverData!,
      ..._liveBookingData,
      ...booking,
      'booking': booking,
    };
  }

  String get _paymentMethod =>
      (_booking['paymentMethod'] ?? _booking['paymentType'] ?? 'CASH')
          .toString()
          .toUpperCase();

  num get _totalFare {
    final value =
        _booking['finalFare'] ??
        _booking['totalFare'] ??
        _booking['fare']?['totalFare'];
    return value is num ? value : num.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> get _paymentMethods => [
    {
      'id': _paymentMethod,
      'title': _paymentMethod == 'CASH' ? 'Cash' : _paymentMethod,
      'subtitle': _paymentMethod == 'CASH'
          ? 'Pay in cash to driver'
          : 'Selected during booking',
      'icon': _paymentMethod == 'CASH' ? Icons.money : Icons.payment,
      'color': const Color(0xFF00ABE4),
    },
  ];

  Widget _buildDriverCard() {
    final driver = _driver;
    final vehicle = _vehicle;

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
      _rawBooking['driverImage'],
      _rawBooking['driver']?['profileImageUrl'],
      _rawBooking['driver']?['profileImage'],
      _rawBooking['driver']?['avatar'],
      _rawBooking['driverData']?['profileImageUrl'],
      _rawBooking['driverData']?['profileImage'],
      _rawBooking['assignedDriver']?['profileImageUrl'],
      _rawBooking['assignedDriver']?['profileImage'],
      _rawBooking['assignedDriver']?['avatar'],
      _rawBooking['assignedDriver']?['user']?['profileImageUrl'],
      _rawBooking['assignedDriver']?['user']?['profileImage'],
      _rawBooking['assignedDriver']?['user']?['avatar'],
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
    final fullName = [firstName, lastName]
        .where((v) => v?.trim().isNotEmpty == true)
        .join(' ');

    final driverName = fullName.isNotEmpty
        ? fullName
        : (_readValue([
                    driver['name'],
                    driver['displayName'],
                    driver['fullName'],
                    driver['user']?['displayName'],
                    driver['user']?['name'],
                    _rawBooking['driver']?['name'],
                    _rawBooking['driver']?['user']?['name'],
                    _rawBooking['assignedDriver']?['name'],
                    _rawBooking['assignedDriver']?['user']?['name'],
                    _rawBooking['driverName'],
                    widget.driverData?['driverName'],
                  ]) ??
                  'Driver')
              .toString();

    final vehicleNumber = _readValue([
      vehicle['registrationNumber'],
      vehicle['registrationNo'],
      vehicle['vehicleNumber'],
      vehicle['plateNumber'],
      driver['registrationNo'],
      driver['registrationNumber'],
      driver['vehicleNumber'],
      _rawBooking['vehicleNumber'],
    ])?.toString();

    final vehicleModel = _readValue([
      vehicle['model'],
      vehicle['vehicleModel'],
      vehicle['make'],
      vehicle['name'],
      driver['vehicleModel'],
    ])?.toString();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFC000), width: 2.w),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100.r),
              child: driverImage != null && driverImage.startsWith('http')
                  ? Image.network(
                      driverImage,
                      width: 44.w,
                      height: 44.w,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          _buildDriverAvatarPlaceholder(driverName),
                    )
                  : _buildDriverAvatarPlaceholder(driverName),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: AppFonts.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  [vehicleModel, vehicleNumber]
                      .where((v) => v != null && v.isNotEmpty)
                      .join(' • '),
                  style: AppFonts.captionDark.copyWith(
                    color: const Color(0xFF64748B),
                    fontSize: 12.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAvatarPlaceholder(String driverName) {
    final initial = driverName.trim().isNotEmpty
        ? driverName.trim().characters.first.toUpperCase()
        : null;
    return Container(
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      color: const Color(0xFFE6F7FD),
      child: initial == null
          ? Icon(
              Icons.person,
              color: const Color(0xFF00ABE4),
              size: 24.sp,
            )
          : Text(
              initial,
              style: TextStyle(
                color: const Color(0xFF00ABE4),
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = _paymentMethod;
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    final id = widget.bookingId ?? _booking['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      final response = await ApiService.to.get(ApiEndpoints.bookingDetails(id));
      if (!mounted || response.data is! Map) return;
      final raw = Map<String, dynamic>.from(response.data as Map);
      final data = raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : raw;
      setState(() {
        _liveBookingData = data;
        _selectedPaymentMethod = _paymentMethod;
      });
    } catch (e) {
      // ignore silent fetch failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Area with light blue background
          Container(
            color: AppColors.lightBlueBackground,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20.h,
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20.r,
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
                SizedBox(width: 16.w),
                Text(
                  'Payment',
                  style: AppFonts.h1.copyWith(
                    fontSize: 20.sp,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Main White Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: 24.h,
                      left: 20.w,
                      right: 20.w,
                      bottom: 200.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ride Completed Box
                        Container(
                          padding: EdgeInsets.only(
                            top: 10.h,
                            right: 14.w,
                            bottom: 10.h,
                            left: 10.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFF0F0F0),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(15.r),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.green,
                                radius: 14.r,
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ride Completed',
                                      style: AppFonts.bodyText.copyWith(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                     Builder(
                                       builder: (context) {
                                         final pickup = widget.driverData?['booking']?['pickupAddress'] ??
                                             widget.driverData?['trip']?['pickupAddress'] ??
                                             widget.driverData?['pickupLocation']?['address'] ??
                                             _booking['pickupAddress'] ??
                                             _booking['pickup']?['address'] ??
                                             'Pickup';
                                         final drop = widget.driverData?['booking']?['dropAddress'] ??
                                             widget.driverData?['trip']?['dropAddress'] ??
                                             widget.driverData?['dropLocation']?['address'] ??
                                             _booking['dropAddress'] ??
                                             _booking['drop']?['address'] ??
                                             'Drop';
                                         return Text(
                                           '$pickup → $drop',
                                           style: AppFonts.captionDark.copyWith(
                                             color: Colors.grey.shade700,
                                             height: 1.2,
                                           ),
                                           maxLines: 1,
                                           overflow: TextOverflow.ellipsis,
                                         );
                                       },
                                     ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total Fare',
                                    style: AppFonts.captionDark.copyWith(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  Text(
                                    '₹${_totalFare.toStringAsFixed(2)}',
                                    style: AppFonts.h2.copyWith(
                                      fontSize: 16.sp,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  GestureDetector(
                                    onTap: () {
                                      final id = _readValue([
                                        widget.bookingId,
                                        _booking['id'],
                                        _booking['_id'],
                                        _booking['bookingId'],
                                        widget.driverData?['id'],
                                        widget.driverData?['booking']?['id'],
                                        widget.driverData?['trip']?['id'],
                                        widget.driverData?['bookingId'],
                                      ])?.toString();

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => RideInvoiceScreen(
                                            initialBookingData: _booking,
                                            bookingId: id,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'View Details',
                                      style: AppFonts.captionDark.copyWith(
                                        color: const Color(0xFF00ABE4),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Driver Details Card
                        _buildDriverCard(),

                        SizedBox(height: 24.h),

                        // Payment Methods
                        Text(
                          'Choose Payment Method',
                          style: AppFonts.bodyText.copyWith(
                            color: Colors.black,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 16.h),

                        ..._paymentMethods
                            .map((method) => _buildPaymentOption(method)),

                        SizedBox(height: 24.h),

                        // Secured Banner
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.only(
                            top: 14.h,
                            right: 12.w,
                            bottom: 14.h,
                            left: 12.w,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8F3),
                            border: Border.all(
                              color: const Color(0xFFE3F6FC),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.green.shade100
                                    .withOpacity(0.5),
                                radius: 14.r,
                                child: Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                  size: 18.sp,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your payment is secured with 256-bit encryption',
                                      style: AppFonts.bodyText.copyWith(
                                        color: Colors.green.shade700,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'We never store your card or UPI details',
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
                      ],
                    ),
                  ),

                  // Fixed Bottom Bar
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom > 0
                            ? MediaQuery.of(context).padding.bottom
                            : 20.h,
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.only(
                              top: 14.h,
                              right: 22.w,
                              bottom: 14.h,
                              left: 14.w,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF7FDFF),
                              border: Border(
                                top: BorderSide(
                                  color: Color(0xFFE3F6FC),
                                  width: 1,
                                ),
                                bottom: BorderSide(
                                  color: Color(0xFFE3F6FC),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Payable',
                                      style: AppFonts.captionDark.copyWith(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    Text(
                                      '₹${_totalFare.toStringAsFixed(2)}',
                                      style: AppFonts.h1.copyWith(
                                        fontSize: 18.sp,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            child: SizedBox(
                              width: double.infinity,
                              height: 46.h,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ABE4),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isPaying ? null : _pay,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      color: Colors.white,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      _isPaying ? 'Processing...' : 'Pay Now',
                                      style: AppFonts.buttonText.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(Map<String, dynamic> method) {
    bool isSelected = _selectedPaymentMethod == method['id'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method['id'];
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.only(
          top: 10.h,
          right: 19.w,
          bottom: 10.h,
          left: 10.w,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF00ABE4) : Colors.grey.shade200,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? const Color(0xFFE6F7FD)
                  : Colors.grey.shade50,
              radius: 18.r,
              child: Icon(method['icon'], color: method['color'], size: 18.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['title'],
                    style: AppFonts.bodyText.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    method['subtitle'],
                    style: AppFonts.captionDark.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? const Color(0xFF00ABE4)
                  : Colors.grey.shade300,
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }
}
