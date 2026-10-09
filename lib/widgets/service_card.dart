import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_fonts.dart';

class ServiceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? time;
  final String? imagePath;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? badgeText;

  const ServiceCard({
    super.key,
    required this.title,
    this.subtitle,
    this.time,
    this.imagePath,
    this.icon,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle ?? time;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFFF9F9FA),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: borderColor ?? const Color(0xFFEEEEEE),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (badgeText != null) ...[
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B41A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 8.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4.h),
            ],
            Expanded(
              child: Center(
                child: imagePath != null && imagePath!.isNotEmpty
                    ? Image.asset(
                        imagePath!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.category_rounded,
                          color: const Color(0xFFF4B41A),
                          size: 32.sp,
                        ),
                      )
                    : Icon(
                        icon ?? Icons.category_rounded,
                        color: const Color(0xFFF4B41A),
                        size: 32.sp,
                      ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            if (sub != null && sub.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 10.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

