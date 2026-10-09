import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_fonts.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final String? imageIcon;
  final VoidCallback onTap;
  final bool isFullWidth;

  const AuthButton({
    super.key,
    required this.text,
    this.icon,
    this.imageIcon,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: AppDimensions.controlHeight.h,
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.horizontalPadding.w,
        ),
        decoration: BoxDecoration(
          color: AppColors.authButtonBackground,
          border: Border.all(color: AppColors.authButtonBorder, width: 1),
          borderRadius: BorderRadius.circular(AppDimensions.controlRadius.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20.sp, color: AppColors.black),
              SizedBox(width: 8.w),
            ] else if (imageIcon != null) ...[
              Image.asset(imageIcon!, width: 20.w, height: 20.w),
              SizedBox(width: 8.w),
            ],
            Text(
              text,
              style: AppFonts.bodyText.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w600,
                fontSize: 15.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
