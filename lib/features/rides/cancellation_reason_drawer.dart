import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../constants/app_fonts.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/socket/socket_service.dart';
import '../main_navigation_screen.dart';

class CancellationReasonDrawer extends StatefulWidget {
  final String tripId;
  final String? returnBookingId;
  final String? tripType;
  final String? tripLeg;
  final bool isReturnLegOnly;
  final VoidCallback? onCancelledSuccess;

  const CancellationReasonDrawer({
    super.key,
    required this.tripId,
    this.returnBookingId,
    this.tripType,
    this.tripLeg,
    this.isReturnLegOnly = false,
    this.onCancelledSuccess,
  });

  /// Static helper to launch the modal bottom sheet drawer.
  /// Returns `true` if booking was successfully cancelled, `false` or `null` if dismissed/backed out.
  static Future<bool?> show(
    BuildContext context, {
    required String tripId,
    String? returnBookingId,
    String? tripType,
    String? tripLeg,
    bool isReturnLegOnly = false,
    VoidCallback? onCancelledSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (sheetContext) => CancellationReasonDrawer(
        tripId: tripId,
        returnBookingId: returnBookingId,
        tripType: tripType,
        tripLeg: tripLeg,
        isReturnLegOnly: isReturnLegOnly,
        onCancelledSuccess: onCancelledSuccess,
      ),
    );
  }

  @override
  State<CancellationReasonDrawer> createState() => _CancellationReasonDrawerState();
}

class _CancellationReasonDrawerState extends State<CancellationReasonDrawer> {
  int? _selectedIndex;
  bool _isLoading = false;
  final TextEditingController _otherReasonController = TextEditingController();

  final List<String> _reasons = [
    'Selected Wrong Pickup Location',
    'Selected Wrong Drop Location',
    'Booked by mistake',
    'Selected different service/vehicle',
    'Taking too long to confirm the ride',
    'Got a ride elsewhere',
    'Others',
  ];

  String _getReasonCode(String reason) {
    switch (reason) {
      case 'Selected Wrong Pickup Location':
        return 'WRONG_PICKUP_LOCATION';
      case 'Selected Wrong Drop Location':
        return 'WRONG_DROP_LOCATION';
      case 'Booked by mistake':
        return 'BOOKED_BY_MISTAKE';
      case 'Selected different service/vehicle':
        return 'DIFFERENT_VEHICLE';
      case 'Taking too long to confirm the ride':
        return 'TAKING_TOO_LONG';
      case 'Got a ride elsewhere':
        return 'GOT_RIDE_ELSEWHERE';
      case 'Others':
      default:
        return 'OTHER';
    }
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_selectedIndex == null || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final selectedReasonText = _reasons[_selectedIndex!];
    final code = _getReasonCode(selectedReasonText);
    final customText = _otherReasonController.text.trim();
    final finalReason = (selectedReasonText == 'Others' && customText.isNotEmpty)
        ? customText
        : selectedReasonText;

    final String cancelTargetId = (widget.isReturnLegOnly && widget.returnBookingId != null)
        ? widget.returnBookingId!
        : widget.tripId;

    try {
      print('--- [USER BOOKING CANCEL] Calling cancellation API for Target ID: $cancelTargetId ---');
      final response = await ApiService.to.post(
        ApiEndpoints.cancelBooking(cancelTargetId),
        body: {
          'reasonCode': code,
          'reason': finalReason,
        },
      );

      if (!mounted) return;

      if (response.isSuccess || response.statusCode == 200 || response.statusCode == 201) {
        // Execute socket untrack & event cleanup ONLY after successful API call
        SocketService.to.untrackBooking(bookingId: cancelTargetId);
        SocketService.to.clearBookingEvents(cancelTargetId);
        if (widget.returnBookingId != null && !widget.isReturnLegOnly) {
          SocketService.to.untrackBooking(bookingId: widget.returnBookingId!);
          SocketService.to.clearBookingEvents(widget.returnBookingId!);
        }

        // Close drawer with success flag
        Navigator.pop(context, true);

        if (widget.onCancelledSuccess != null) {
          widget.onCancelledSuccess!();
        } else {
          Get.offAll(() => const MainNavigationScreen());
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Cancellation Failed',
          response.message.isNotEmpty ? response.message : 'Failed to cancel booking. Please try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.redAccent.withOpacity(0.9),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      print('--- [USER BOOKING CANCEL] API Exception: $e ---');
      Get.snackbar(
        'Cancellation Error',
        'An error occurred while cancelling your ride. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final isReasonSelected = _selectedIndex != null;

    return PopScope(
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_isLoading) {
          Navigator.pop(context, false);
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                ),

                // Header with Back button and Title/Subtitle
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _isLoading ? null : () => Navigator.pop(context, false),
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 20.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why do you want to cancel?',
                              style: AppFonts.h2.copyWith(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Please provide the reason for cancellation',
                              style: AppFonts.bodyText.copyWith(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF0F0F0)),

                if ((widget.tripType == 'RETURN' || widget.returnBookingId != null) && !widget.isReturnLegOnly)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFFFEEBA)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: const Color(0xFF856404), size: 20.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Note: Cancelling this outbound ride will automatically cancel your linked return ride.',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF856404),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.isReturnLegOnly)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E3E5),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFD6D8DB)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: const Color(0xFF383D41), size: 20.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'You are cancelling only the return leg. Your completed outbound ride will not be affected.',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF383D41),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Scrollable Reason Options
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reasons.length,
                          separatorBuilder: (context, index) => SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final reasonText = _reasons[index];
                            final isSelected = _selectedIndex == index;

                            return GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedIndex = index;
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 12.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFF9E6)
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFF4B41A)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        reasonText,
                                        style: AppFonts.bodyText.copyWith(
                                          fontSize: 14.sp,
                                          color: isSelected ? const Color(0xFF111827) : Colors.black87,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    // Custom Radio Circle on Right
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 22.w,
                                      height: 22.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFF4B41A)
                                              : Colors.grey.shade400,
                                          width: isSelected ? 6.w : 1.5.w,
                                        ),
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // If "Others" is selected, render optional text input
                        if (_selectedIndex != null && _reasons[_selectedIndex!] == 'Others') ...[
                          SizedBox(height: 14.h),
                          Text(
                            'Specify reason (Optional)',
                            style: AppFonts.bodyText.copyWith(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          TextField(
                            controller: _otherReasonController,
                            maxLines: 2,
                            enabled: !_isLoading,
                            style: AppFonts.bodyText.copyWith(
                              fontSize: 13.sp,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your reason here...',
                              hintStyle: AppFonts.bodyText.copyWith(
                                fontSize: 13.sp,
                                color: Colors.grey.shade400,
                              ),
                              contentPadding: EdgeInsets.all(12.r),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFF0F0F0)),

                // Action Buttons Row: [ Back ]  [ Continue ]
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    12.h,
                    16.w,
                    paddingBottom > 0 ? paddingBottom + 8.h : 16.h,
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context, false),
                            child: Text(
                              'Back',
                              style: AppFonts.buttonText.copyWith(
                                color: const Color(0xFF111827),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Continue Button
                      Expanded(
                        child: SizedBox(
                          height: 48.h,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReasonSelected
                                  ? const Color(0xFFF4B41A)
                                  : Colors.grey.shade300,
                              elevation: isReasonSelected ? 2 : 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            onPressed: (isReasonSelected && !_isLoading)
                                ? _handleContinue
                                : null,
                            child: _isLoading
                                ? SizedBox(
                                    width: 22.w,
                                    height: 22.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF111827),
                                    ),
                                  )
                                : Text(
                                    'Continue',
                                    style: AppFonts.buttonText.copyWith(
                                      color: isReasonSelected
                                          ? const Color(0xFF111827)
                                          : Colors.grey.shade600,
                                      fontSize: 15.sp,
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
        ),
      ),
    );
  }
}
