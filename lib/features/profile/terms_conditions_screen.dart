import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Title: Terms & Conditions
                    _buildSectionHeading('Terms & Conditions'),
                    SizedBox(height: 8.h),
                    _buildBodyText(
                      'Agar tum Sawariyaa ke liye modern aur minimal Terms & Conditions screen bana rahe ho, to content zyada legal nahi lagna chahiye. User-friendly aur readable hona chahiye.',
                    ),
                    SizedBox(height: 20.h),

                    // Section 1: 1. Acceptance of terms
                    _buildSectionHeading('1. Acceptance of terms'),
                    SizedBox(height: 8.h),
                    _buildBodyText(
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
                    ),
                    SizedBox(height: 20.h),

                    // Section 2: 2. Dedinitions
                    _buildSectionHeading('2. Dedinitions'),
                    SizedBox(height: 8.h),
                    _buildBodyText(
                      'Contrary to popular belief, Lorem Ipsum is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old. Richard McClintock, a Latin professor at Hampden-Sydney College in Virginia, looked up one of the more obscure Latin words, consectetur, from a Lorem Ipsum passage, and going.',
                    ),
                    SizedBox(height: 20.h),

                    // Section 3: 3. Eligibility to use the services
                    _buildSectionHeading('3. Eligibility to use the services'),
                    SizedBox(height: 8.h),
                    _buildBodyText(
                      'Contrary to popular belief, Lorem Ipsum is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old. Richard McClintock, a Latin professor at Hampden-Sydney College in Virginia, looked up one of the more obscure Latin words, consectetur, from a Lorem Ipsum passage, and going.',
                    ),
                    SizedBox(height: 12.h),
                    _buildBodyText(
                      'There are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don\'t look even slightly believable. If you are going to use a passage of Lorem Ipsum, you need to be sure there isn\'t anything embarrassing hidden in the middle of text.',
                    ),
                    SizedBox(height: 30.h),
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
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Text(
              'Terms & Conditions',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Gilroy',
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
        color: Colors.black,
      ),
    );
  }

  Widget _buildBodyText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Gilroy',
        fontSize: 12.sp,
        fontWeight: FontWeight.w300,
        height: 1.2,
        letterSpacing: -0.14,
        color: const Color(0xFF2E2E2E),
      ),
    );
  }
}
