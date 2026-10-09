import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'network_controller.dart';

class NetworkWrapper extends StatelessWidget {
  const NetworkWrapper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NetworkController>();
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Obx(
          () => controller.isOffline.value
              ? _OfflineOverlay(controller: controller)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay({required this.controller});
  final NetworkController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: ColoredBox(
            color: Colors.black.withOpacity(0.25),
            child: Center(
              child: Container(
                width: 310.w,
                margin: EdgeInsets.symmetric(horizontal: 28.w),
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 26.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x29000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58.w,
                      height: 58.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        color: const Color(0xFFE02E32),
                        size: 30.sp,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'No internet connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Please check your Wi-Fi or mobile data and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 13.sp,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Obx(
                      () => SizedBox(
                        width: double.infinity,
                        height: 46.h,
                        child: ElevatedButton(
                          onPressed: controller.isRetrying.value
                              ? null
                              : controller.retry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC000),
                            disabledBackgroundColor: const Color(0x99FFC000),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: controller.isRetrying.value
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  'Retry',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
