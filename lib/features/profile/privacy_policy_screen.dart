import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  children: [
                    _buildPolicyCard(
                      numberId: 'SEC 01',
                      title: '1. Introduction & Scope',
                      content:
                          'Your privacy is extremely important to us. We collect and process your data to provide a seamless ride-hailing experience, ensure safety on the road, match trips efficiently, and manage driver earnings transparently.',
                      bulletPoints: [
                        'Matches you with the nearest passengers based on active routes.',
                        'Ensures security and legal compliance for all platform users.',
                      ],
                    ),
                    _buildPolicyCard(
                      numberId: 'SEC 02',
                      title: '2. Location Access (Background)',
                      content:
                          'To dispatch nearby ride requests and track ongoing trips for passenger safety, our application collects precise location data, including when the app is closed or running in the background. Background location access is required for core app functions.',
                      bulletPoints: [
                        'Tracks active trips in the background to provide accurate fares.',
                        'Verifies route completion and ensures passenger/driver safety.',
                      ],
                    ),
                    _buildPolicyCard(
                      numberId: 'SEC 03',
                      title: '3. Information We Collect',
                      content:
                          'We collect your personal information during registration (Name, Phone, Email), identity verification documents (Driver’s License, Vehicle Registration, Insurance), and financial details for payout processing.',
                      bulletPoints: [
                        'Verification: Driver’s license, vehicle documents, and commercial permit.',
                        'Payout details: Bank account number or payment wallet credentials.',
                      ],
                    ),
                    _buildPolicyCard(
                      numberId: 'SEC 04',
                      title: '4. Data Security & Storage',
                      content:
                          'All personal and vehicle data is encrypted in transit and at rest using industry-standard security protocols. We do not sell your personal data to third parties. We share location data with mapping partners solely for trip routing.',
                      bulletPoints: [
                        'Data Encryption: Fully secured with SSL/TLS protocols.',
                        'Third-party Sharing: Only with certified routing and map APIs.',
                      ],
                    ),
                    _buildPolicyCard(
                      numberId: 'SEC 05',
                      title: '5. Account & Data Deletion',
                      content:
                          'You retain complete ownership of your data. You can request changes or permanent deletion of your driver profile and associated trip records at any time by contacting our support desk or raising a ticket.',
                      bulletPoints: [
                        'Data Control: Request details modification through the profile tab.',
                        'Deletion: Permanent account closure and database purge upon request.',
                      ],
                    ),
                    SizedBox(height: 20.h),
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
              'Privacy Policy',
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

  Widget _buildPolicyCard({
    required String numberId,
    required String title,
    required String content,
    required List<String> bulletPoints,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFEEEEEE),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: const Color(0xFFFFC000).withOpacity(0.4),
                    width: 1.w,
                  ),
                ),
                child: Text(
                  numberId,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: 0.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 12.sp,
              fontWeight: FontWeight.w300,
              height: 1.2,
              letterSpacing: -0.144,
              color: const Color(0xFF475569),
            ),
          ),
          if (bulletPoints.isNotEmpty) ...[
            SizedBox(height: 10.h),
            ...bulletPoints.map(
              (point) => Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 5.h),
                      child: Container(
                        width: 5.w,
                        height: 5.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC000),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                          letterSpacing: -0.144,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
