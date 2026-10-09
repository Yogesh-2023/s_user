import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OtpVerifiedDialog extends StatefulWidget {
  final VoidCallback onClose;
  const OtpVerifiedDialog({super.key, required this.onClose});

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onClose,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'OtpVerifiedDialog',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return OtpVerifiedDialog(
          onClose: () {
            Navigator.of(context).pop();
            onClose();
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.9,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<OtpVerifiedDialog> createState() => _OtpVerifiedDialogState();
}

class _OtpVerifiedDialogState extends State<OtpVerifiedDialog> {
  Timer? _autoCloseTimer;
  bool _hasClosed = false;

  @override
  void initState() {
    super.initState();
    _autoCloseTimer = Timer(const Duration(milliseconds: 1800), _closeOnce);
  }

  void _closeOnce() {
    if (_hasClosed || !mounted) return;
    _hasClosed = true;
    _autoCloseTimer?.cancel();
    widget.onClose();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      elevation: 0,
      child: Center(
        child: Container(
          width: 332.w,
          height: 400.h,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top Right Close (X) Icon
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _closeOnce,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(4.r),
                    child: Icon(
                      Icons.close_rounded,
                      size: 22.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ),

              // Vertically Centered Content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 10.h),

                  // Success Illustration Stack (otpverified2.png behind otpverified.png)
                  SizedBox(
                    width: 240.w,
                    height: 150.h,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Sparkle Stars Background Layer
                        Image.asset(
                          'assets/images/otpverified2.png',
                          width: 230.w,
                          height: 145.h,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),

                        // Main Illustration Layer
                        Image.asset(
                          'assets/images/otp_verified.png',
                          height: 135.h,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/images/otpverified.png',
                            height: 135.h,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.check_circle_rounded,
                              size: 95.sp,
                              color: const Color(0xFFFFC000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Title: OTP Verified
                  Text(
                    'OTP Verified',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 25.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0,
                      color: const Color(0xFF000000),
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Description
                  SizedBox(
                    width: 280.w,
                    child: Text(
                      'Your number is confirmed and you can now go ahead to the next step easily',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        letterSpacing: 0,
                        color: const Color(0xFF000000),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Close CTA Button
                  SizedBox(
                    width: 280.w,
                    height: 44.h,
                    child: ElevatedButton(
                      onPressed: _closeOnce,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF242A37),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(176.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.8.w,
                          vertical: 12.h,
                        ),
                      ),
                      child: Text(
                        'Close',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
