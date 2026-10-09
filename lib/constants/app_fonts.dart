import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

class AppFonts {
  static const String fontFamily = 'Gilroy'; // Set Gilroy as global default font family

  static TextStyle regular({double size = 14, Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size.sp,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.textSecondary,
  );

  static TextStyle medium({double size = 14, Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size.sp,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle semiBold({double size = 14, Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size.sp,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle get h1 => TextStyle(
    fontFamily: fontFamily,
    fontSize: 32.sp,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get h2 => TextStyle(
    fontFamily: fontFamily,
    fontSize: 24.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyText => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.sp,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.25,
  );

  static TextStyle get buttonText => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static TextStyle get captionDark => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.sp,
    fontWeight: FontWeight.w600, // Increased font weight (semi-bold)
    color: AppColors.textPrimary,
  );

  static TextStyle get linkText => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.sp,
    fontWeight: FontWeight.w600, // Increased font weight (semi-bold)
    color: const Color(0xFF38B6FF),
    decoration: TextDecoration.underline,
  );
}
