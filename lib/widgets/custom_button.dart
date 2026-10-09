import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_fonts.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.controlHeight.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          disabledBackgroundColor: const Color(0xFFE7ECF1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.controlRadius.r),
            side: BorderSide(
              width: 1,
              color: onPressed == null
                  ? const Color(0xFFE7ECF1)
                  : AppColors.authButtonBorder,
            ),
          ),
        ),
        onPressed: onPressed,
        child: Text(text, style: AppFonts.buttonText),
      ),
    );
  }
}
