import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fleetgoSurface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 10.h),
                    Container(
                      width: 210.w,
                      height: 76.h,
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 14.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.fleetgoYellow.withOpacity(0.28),
                          width: 1.w,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/sawariya_login_logo.png',
                        height: 36.h,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFFFFC000).withOpacity(0.3),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFEEEEEE),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        'Sawariyaa makes everyday travel and logistics simple, reliable, and accessible.\n\n'
                        'With one app, you can book rides, send parcels, reserve premium cars, and find trucks for your transport needs. We connect customers with trusted drivers while keeping every booking clear and convenient.\n\n'
                        'Our goal is simple: Book Easy, Feel Happy.',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                          letterSpacing: 0,
                          color: const Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Container(
      color: const Color(0xFFFFF9E6),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16.h,
        bottom: 16.h,
        left: 20.w,
        right: 20.w,
      ),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Text(
              'About Us',
              style: AppFonts.h1.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
