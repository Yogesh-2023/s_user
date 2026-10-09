import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_fonts.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_service.dart';
import '../../core/socket/socket_service.dart';
import '../../core/socket/socket_events.dart';
import 'goods_tracking_screen.dart';
import 'razorpay_checkout_sheet.dart';
import '../main_navigation_screen.dart';

class DeliveryBookedScreen extends StatefulWidget {
  final String bookingId;

  const DeliveryBookedScreen({super.key, required this.bookingId});

  @override
  State<DeliveryBookedScreen> createState() => _DeliveryBookedScreenState();
}

class _DeliveryBookedScreenState extends State<DeliveryBookedScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _bookingData;
  Timer? _pollingTimer;

  final TextEditingController _otpController = TextEditingController();
  bool _isActionLoading = false;
  String? _actionError;
  bool _isCancellationDialogShowing = false;

  void _onSocketEvent(dynamic data) {
    _fetchBookingDetails(silent: true);
  }

  void _onBookingCancelled(dynamic data) {
    if (!mounted || _isCancellationDialogShowing) return;
    final payload = data is List ? (data.isNotEmpty ? data.first : null) : data;
    final eventBookingId = payload is Map
        ? (payload['bookingId'] ??
                  payload['tripId'] ??
                  payload['id'] ??
                  payload['booking']?['id'])
              ?.toString()
        : null;
    if (eventBookingId != null &&
        eventBookingId.isNotEmpty &&
        eventBookingId != widget.bookingId) {
      return;
    }
    final message = payload is Map ? payload['message']?.toString() : null;
    _showCancellationPopup(
      message ?? 'This booking has been cancelled by the driver.',
    );
  }

  Future<void> _showCancellationPopup(String message) async {
    if (!mounted || _isCancellationDialogShowing) return;
    _isCancellationDialogShowing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Booking Cancelled'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
              );
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
    _isCancellationDialogShowing = false;
  }

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
    // Socket is the primary live update channel. Polling keeps the OTP/status
    // current when a transient disconnect causes the delivery event to be missed.
    _pollingTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) _fetchBookingDetails(silent: true);
    });

    // Listen to all relevant goods booking events
    SocketService.to.listenTo(SocketEvents.goodsDriverAssigned, _onSocketEvent);
    SocketService.to.listenTo(SocketEvents.goodsPickupOtpSent, _onSocketEvent);
    SocketService.to.listenTo(SocketEvents.goodsDriverArrived, _onSocketEvent);
    SocketService.to.listenTo(
      SocketEvents.goodsPickupOtpVerified,
      _onSocketEvent,
    );
    SocketService.to.listenTo(SocketEvents.goodsTripStarted, _onSocketEvent);
    SocketService.to.listenTo(
      SocketEvents.goodsLocationUpdated,
      _onSocketEvent,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsDriverReachedDestination,
      _onSocketEvent,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsDeliveryOtpSent,
      _onSocketEvent,
    );
    SocketService.to.listenTo(
      SocketEvents.goodsDeliveryOtpVerified,
      _onSocketEvent,
    );
    SocketService.to.listenTo(SocketEvents.goodsTripEnded, _onSocketEvent);
    SocketService.to.listenTo(
      SocketEvents.goodsPaymentCompleted,
      _onSocketEvent,
    );
    SocketService.to.listenTo(SocketEvents.goodsCompleted, _onSocketEvent);
    SocketService.to.listenTo(
      SocketEvents.goodsBookingCancelled,
      _onBookingCancelled,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _otpController.dispose();

    SocketService.to.stopListening(
      SocketEvents.goodsDriverAssigned,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsPickupOtpSent,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsDriverArrived,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsPickupOtpVerified,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsTripStarted,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsLocationUpdated,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsDriverReachedDestination,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsDeliveryOtpSent,
      _onSocketEvent,
    );
    SocketService.to.stopListening(
      SocketEvents.goodsDeliveryOtpVerified,
      _onSocketEvent,
    );
    SocketService.to.stopListening(SocketEvents.goodsTripEnded, _onSocketEvent);
    SocketService.to.stopListening(
      SocketEvents.goodsPaymentCompleted,
      _onSocketEvent,
    );
    SocketService.to.stopListening(SocketEvents.goodsCompleted, _onSocketEvent);
    SocketService.to.stopListening(
      SocketEvents.goodsBookingCancelled,
      _onBookingCancelled,
    );

    super.dispose();
  }

  Future<void> _fetchBookingDetails({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await ApiService.to.get(
        ApiEndpoints.goodsBookingDetails(widget.bookingId),
      );
      if (response.statusCode == 200 && response.data != null) {
        if (mounted) {
          setState(() {
            _bookingData = response.data['data'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = response.message;
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

  Future<void> _callDriver(Map<String, dynamic> driver) async {
    final phone = [
      driver['phone'],
      driver['mobile'],
      driver['phoneNumber'],
      driver['mobileNumber'],
      driver['contactNumber'],
      driver['user']?['phone'],
      driver['user']?['mobile'],
    ].where((value) => value?.toString().trim().isNotEmpty == true).firstOrNull;
    if (phone == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone number not available')),
        );
      }
      return;
    }
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: phone.toString()),
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open phone dialer')),
      );
    }
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Advance payment confirmed successfully!'),
          ),
        );
        _fetchBookingDetails();
      } else {
        if (!mounted) return;
        setState(() {
          _actionError = response.message;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = e.toString().replaceAll('ApiException:', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
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
        _fetchBookingDetails();
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

  Future<void> _cancelBooking() async {
    if (_isActionLoading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isActionLoading = true;
      _actionError = null;
    });

    try {
      final response = await ApiService.to.post(
        ApiEndpoints.goodsCancel(widget.bookingId),
        body: {'reason': 'Cancelled by customer'},
      );

      if (response.statusCode == 200) {
        await _showCancellationPopup(
          'Your booking has been cancelled successfully.',
        );
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
        return 'Looking for Truck';
      case 'DRIVER_ASSIGNED':
        return 'Driver Assigned';
      case 'AT_PICKUP':
        return 'Driver Arrived at Pickup';
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

  Color _getStatusColor(String? status) {
    if (status == null) return const Color(0xFFF4B41A);
    switch (status) {
      case 'DELIVERED':
        return const Color(0xFF1C9840);
      case 'CANCELLED':
        return Colors.red;
      case 'PENDING_DRIVER_ASSIGNMENT':
        return Colors.orange;
      default:
        return const Color(0xFFF4B41A);
    }
  }

  Widget _buildStepItem({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
  }) {
    Color bgColor = isCompleted
        ? const Color(0xFF1C9840).withValues(alpha: 0.15)
        : isActive
        ? const Color(0xFFFFF9E6)
        : Colors.grey.shade100;
    Color iconColor = isCompleted
        ? const Color(0xFF1C9840)
        : isActive
        ? const Color(0xFFD97706)
        : Colors.grey.shade400;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Center(
              child: Icon(
                Icons.check_circle_outline,
                color: iconColor,
                size: 14.sp,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: AppFonts.bodyText.copyWith(
                fontSize: 10.sp,
                fontWeight: isActive || isCompleted
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isActive
                    ? const Color(0xFFD97706)
                    : isCompleted
                    ? Colors.black
                    : Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: AppFonts.captionDark.copyWith(
                fontSize: 8.sp,
                color: isActive
                    ? const Color(0xFFD97706)
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 51.h,
        padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF4B41A),
                ),
              )
            else
              Icon(icon, color: const Color(0xFFD97706), size: 18.sp),
            SizedBox(height: 4.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppFonts.bodyText.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedConnector({required bool isCompleted}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashWidth = 3.w;
        final gapWidth = 2.w;
        final dashCount = (constraints.maxWidth / (dashWidth + gapWidth))
            .floor()
            .clamp(1, 1000);

        return Row(
          children: List.generate(
            dashCount,
            (index) => Padding(
              padding: EdgeInsets.only(
                right: index == dashCount - 1 ? 0 : gapWidth,
              ),
              child: Container(
                width: dashWidth,
                height: 1.5.h,
                color: isCompleted
                    ? const Color(0xFF4CAF50)
                    : Colors.grey.shade300,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
                  onPressed: () => _fetchBookingDetails(),
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
    final bookingNo =
        data['bookingNumber'] as String? ??
        'GB-${widget.bookingId.substring(0, 6).toUpperCase()}';
    final pickup = data['pickupLocation'] ?? {};
    final drop = data['dropLocation'] ?? {};

    // Stepper logic
    final isBooked = true;
    final isPickup = [
      'AT_PICKUP',
      'GOODS_PICKED_UP',
      'IN_TRANSIT',
      'ARRIVED_DESTINATION',
      'DELIVERED',
      'PAYMENT_PENDING',
      'PAYMENT_COMPLETED',
      'COMPLETED',
    ].contains(status);
    final isInTransit = [
      'GOODS_PICKED_UP',
      'IN_TRANSIT',
      'ARRIVED_DESTINATION',
      'DELIVERED',
    ].contains(status);
    final isArrivedDest = ['ARRIVED_DESTINATION', 'DELIVERED'].contains(status);
    final isDelivered = [
      'DELIVERED',
      'PAYMENT_PENDING',
      'PAYMENT_COMPLETED',
      'COMPLETED',
    ].contains(status);

    final isPickupActive = status == 'DRIVER_ASSIGNED' || status == 'AT_PICKUP';
    final isInTransitActive =
        status == 'GOODS_PICKED_UP' || status == 'IN_TRANSIT';
    final isArrivedDestActive = status == 'ARRIVED_DESTINATION';
    final isDeliveredActive = [
      'DELIVERED',
      'PAYMENT_PENDING',
      'PAYMENT_COMPLETED',
      'COMPLETED',
    ].contains(status);

    final double totalFare = (data['totalFare'] as num?)?.toDouble() ?? 0.0;
    final double advanceFare =
        (data['advanceFareAmount'] as num?)?.toDouble() ?? totalFare * 0.5;
    final bool isAdvancePaid = data['advancePaymentStatus'] == 'PAID';

    final driver = data['driver'] ?? {};

    // OTP retrieval
    final String? pickupOtpCode = data['pickupOtp']?.toString();
    final String? deliveryOtpCode = data['deliveryOtp']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.w,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDisplayStatus(status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.h1.copyWith(
                            fontSize: 18.sp,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          bookingNo,
                          style: AppFonts.captionDark.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _fetchBookingDetails(),
                  ),
                ],
              ),
            ),

            if (_actionError != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
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
                        _actionError!,
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Content Area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20.w,
                    right: 20.w,
                    top: 24.h,
                    bottom: 120.h,
                  ),
                  child: Column(
                    children: [
                      // Status Badge
                      CustomPaint(
                        size: Size(58.w, 58.w),
                        painter: RosetteCheckPainter(
                          color: _getStatusColor(status),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      Text(
                        status == 'CANCELLED'
                            ? 'Trip Cancelled'
                            : status == 'DELIVERED'
                            ? 'Delivered Successfully!'
                            : status == 'PENDING_DRIVER_ASSIGNMENT'
                            ? 'Looking for Truck'
                            : status == 'DRIVER_ASSIGNED'
                            ? 'Your truck is assigned'
                            : 'Booking Confirmed!',
                        style: AppFonts.h1.copyWith(
                          fontSize: 18.sp,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        status == 'CANCELLED'
                            ? 'This booking has been cancelled'
                            : status == 'DELIVERED'
                            ? 'Your goods have been delivered'
                            : status == 'PENDING_DRIVER_ASSIGNMENT'
                            ? 'We are matching you with a nearby verified driver'
                            : status == 'DRIVER_ASSIGNED'
                            ? 'The driver is on the way to your pickup location'
                            : 'Your truck booking is in progress',
                        style: AppFonts.bodyText.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Booking ID Container
                      Container(
                        width: 200.w,
                        padding: EdgeInsets.symmetric(
                          vertical: 6.h,
                          horizontal: 12.w,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: _getStatusColor(status),
                            width: 1,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Booking ID: ${widget.bookingId}',
                                style: AppFonts.bodyText.copyWith(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.sp,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.bookingId),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Booking ID copied to clipboard',
                                      ),
                                    ),
                                  );
                                },
                                child: Icon(
                                  Icons.content_copy_outlined,
                                  color: _getStatusColor(status),
                                  size: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Driver Details Card (Dynamic)
                      if (status != 'PENDING_DRIVER_ASSIGNMENT' &&
                          driver.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 16.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: const Color(0xFFF4B41A).withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24.r,
                                backgroundColor: const Color(
                                  0xFFFFF9E6,
                                ),
                                backgroundImage:
                                    driver['profilePicture'] != null
                                    ? NetworkImage(driver['profilePicture'])
                                    : null,
                                child: driver['profilePicture'] == null
                                    ? Icon(
                                        Icons.person,
                                        color: const Color(0xFFD97706),
                                        size: 24.sp,
                                      )
                                    : null,
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${driver['firstName'] ?? 'Driver'} ${driver['lastName'] ?? ''}'
                                          .trim(),
                                      style: AppFonts.h2.copyWith(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      '${driver['vehicle']?['brand'] ?? 'Truck'} • ${driver['vehicle']?['plateNumber'] ?? ''}'
                                          .trim(),
                                      style: AppFonts.bodyText.copyWith(
                                        color: Colors.grey.shade600,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFF9E6,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.phone),
                                  color: const Color(0xFFD97706),
                                  onPressed: () => _callDriver(
                                    Map<String, dynamic>.from(driver),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],

                      // Live OTP Display & Verification Section (For Test & Simulation)
                      if (status != 'DELIVERED' && status != 'CANCELLED') ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 16.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.security,
                                    color: Color(0xFFD97706),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    status == 'AT_PICKUP' && !isAdvancePaid
                                        ? 'Advance payment required'
                                        : 'Secure trip verification',
                                    style: AppFonts.h2.copyWith(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),

                              // Show active OTPs
                              if (pickupOtpCode != null &&
                                  isAdvancePaid &&
                                  (status == 'DRIVER_ASSIGNED' ||
                                      status == 'AT_PICKUP')) ...[
                                Text(
                                  'Pickup OTP: $pickupOtpCode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: Colors.green[800],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                              ],
                              if (deliveryOtpCode != null &&
                                  (status == 'GOODS_PICKED_UP' ||
                                      status == 'IN_TRANSIT' ||
                                      status == 'ARRIVED_DESTINATION')) ...[
                                Text(
                                  'Delivery OTP: $deliveryOtpCode',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                              ],

                              // Verification action input
                              if ((status == 'AT_PICKUP' && isAdvancePaid) ||
                                  status == 'ARRIVED_DESTINATION') ...[
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
                                        backgroundColor: const Color(
                                          0xFFF4B41A,
                                        ),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                      ),
                                      onPressed: _isActionLoading
                                          ? null
                                          : () => _verifyOtp(
                                              status == 'AT_PICKUP',
                                            ),
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
                                SizedBox(height: 12.h),
                              ],

                              // Advance payment button
                              if (status == 'AT_PICKUP' && !isAdvancePaid) ...[
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 12.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: const Color(0xFFFED7AA),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Truck has reached your pickup',
                                        style: AppFonts.bodyText.copyWith(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF9A3412),
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        'Pay 50% (₹${advanceFare.toStringAsFixed(2)}) now. Your pickup OTP will be available after successful payment.',
                                        style: AppFonts.bodyText.copyWith(
                                          fontSize: 11.sp,
                                          height: 1.35,
                                          color: const Color(0xFF9A3412),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.payment),
                                    onPressed: _isActionLoading
                                        ? null
                                        : _confirmAdvancePayment,
                                    label: Text(
                                      'Pay 50% Advance • ₹${advanceFare.toStringAsFixed(2)}',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 20.h),
                      ],

                      // Location Timeline Card
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.w,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.10),
                            width: 0.5,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  SizedBox(height: 8.h),
                                  Container(
                                    width: 20.w,
                                    height: 20.w,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF439A72,
                                      ).withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 12.w,
                                        height: 12.w,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF439A72),
                                            width: 2.5.w,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      width: 1.5.w,
                                      color: Colors.grey.shade300,
                                      margin: EdgeInsets.symmetric(
                                        vertical: 2.h,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.location_on,
                                    color: const Color(0xFF9E1000),
                                    size: 22.sp,
                                  ),
                                  SizedBox(height: 8.h),
                                ],
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Column(
                                  children: [
                                    // Pickup Box
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.w,
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
                                            'Pickup Location',
                                            style: AppFonts.captionDark
                                                .copyWith(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 11.sp,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            pickup['address']?.toString() ??
                                                'Pickup Address',
                                            style: AppFonts.bodyText.copyWith(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    // Delivery Box
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.w,
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
                                            'Drop Location',
                                            style: AppFonts.captionDark
                                                .copyWith(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 11.sp,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            drop['address']?.toString() ??
                                                'Drop Address',
                                            style: AppFonts.bodyText.copyWith(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
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
                      ),
                      SizedBox(height: 24.h),

                      // Stepper Card
                      if (status != 'CANCELLED') ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 12.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: const Color(0xFF000000).withOpacity(0.05),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What\'s Next?',
                                style: AppFonts.h2.copyWith(
                                  color: Colors.black,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  // Stepper Connector Line (Dotted & Solid)
                                  Positioned(
                                    top: 12.w,
                                    left: 30.w,
                                    right: 30.w,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 1.5.h,
                                            color: isPickup
                                                ? const Color(0xFF4CAF50)
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDottedConnector(
                                            isCompleted: isInTransit,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDottedConnector(
                                            isCompleted: isArrivedDest,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDottedConnector(
                                            isCompleted: isDelivered,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stepper Items Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildStepItem(
                                        title: 'Booked',
                                        subtitle: 'Completed',
                                        isCompleted: isBooked,
                                        isActive:
                                            status ==
                                            'PENDING_DRIVER_ASSIGNMENT',
                                      ),
                                      _buildStepItem(
                                        title: 'Pickup',
                                        subtitle: isPickup
                                            ? 'Verified'
                                            : 'Pending',
                                        isCompleted: isPickup,
                                        isActive: isPickupActive,
                                      ),
                                      _buildStepItem(
                                        title: 'In Transit',
                                        subtitle: isInTransit
                                            ? 'Active'
                                            : 'Upcoming',
                                        isCompleted: isInTransit,
                                        isActive: isInTransitActive,
                                      ),
                                      _buildStepItem(
                                        title: 'Arrived Drop',
                                        subtitle: isArrivedDest
                                            ? 'At Drop'
                                            : 'Upcoming',
                                        isCompleted: isArrivedDest,
                                        isActive: isArrivedDestActive,
                                      ),
                                      _buildStepItem(
                                        title: 'Delivered',
                                        subtitle: isDelivered
                                            ? 'Success'
                                            : 'Upcoming',
                                        isCompleted: isDelivered,
                                        isActive: isDeliveredActive,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],

                      // Row of Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.share_outlined,
                              label: 'Share Details',
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text:
                                        'Booking No: $bookingNo\nPickup: ${pickup['address']}\nDrop: ${drop['address']}',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Details copied to share'),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (status != 'CANCELLED' &&
                              status != 'DELIVERED') ...[
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.cancel_outlined,
                                label: 'Cancel Booking',
                                onTap: _cancelBooking,
                                isLoading: _isActionLoading,
                              ),
                            ),
                          ],
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.local_shipping_outlined,
                              label: 'Track Delivery',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GoodsTrackingScreen(
                                      bookingId: widget.bookingId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Bottom Section
            Container(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fare block
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isAdvancePaid ? 'Remaining Amount' : 'Total Fare',
                          style: AppFonts.captionDark.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 14.sp,
                          ),
                        ),
                        Text(
                          isAdvancePaid
                              ? '₹${((data['remainingFareAmount'] as num?)?.toDouble() ?? (totalFare - advanceFare)).toStringAsFixed(2)}'
                              : '₹${totalFare.toStringAsFixed(2)}',
                          style: AppFonts.h2.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Go to Home Button
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20.w,
                      right: 20.w,
                      top: 10.h,
                      bottom: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom
                          : 20.h,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4B41A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        child: Text(
                          'Go to Home',
                          style: AppFonts.buttonText.copyWith(
                            color: Colors.black,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
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

class RosetteCheckPainter extends CustomPainter {
  final Color color;
  RosetteCheckPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5.w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 2.w;

    final double baseRadius = radius * 0.88;
    final double amplitude = radius * 0.12;

    for (int i = 0; i <= 360; i += 2) {
      final double theta = i * 3.141592653589793 / 180;
      final double r = baseRadius + amplitude * math.cos(8 * theta);
      final double x = center.dx + r * math.cos(theta);
      final double y = center.dy + r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5.w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final checkPath = Path();
    checkPath.moveTo(size.width * 0.32, size.height * 0.50);
    checkPath.lineTo(size.width * 0.46, size.height * 0.64);
    checkPath.lineTo(size.width * 0.68, size.height * 0.36);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
