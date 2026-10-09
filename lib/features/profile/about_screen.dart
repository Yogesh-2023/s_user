import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'about_us_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 20.w),
              children: [
                _AboutItem(
                  title: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()),
                    );
                  },
                ),
                _AboutItem(
                  title: 'Terms & Conditions',
                  icon: Icons.description_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TermsConditionsScreen(),
                      ),
                    );
                  },
                ),
                _AboutItem(
                  title: 'About Us',
                  icon: Icons.info_outline,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AboutUsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: const Color(0xFFE6F7FD),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
                ),
              ),
              SizedBox(width: 16.w),
              Text(
                'About',
                style: AppFonts.h2.copyWith(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  const _AboutItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: AppFonts.h2.copyWith(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
