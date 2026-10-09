import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_fonts.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final Widget? prefixIcon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.controlHeight.h,
      decoration: BoxDecoration(
        color: AppColors.textFieldBackground,
        border: Border.all(color: AppColors.authButtonBorder, width: 1),
        borderRadius: BorderRadius.circular(AppDimensions.controlRadius.r),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters:
            inputFormatters ??
            (keyboardType == TextInputType.phone
                ? [
                    FilteringTextInputFormatter
                        .digitsOnly, // Only numbers allowed
                    LengthLimitingTextInputFormatter(10), // Max 10 digits
                  ]
                : null),
        textAlignVertical: TextAlignVertical.center,
        style: AppFonts.bodyText.copyWith(
          color: AppColors.black,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppDimensions.horizontalPadding.w,
          ),
          prefixIcon: prefixIcon,
          prefixIconConstraints: BoxConstraints(
            minWidth: 44.w,
            minHeight: AppDimensions.controlHeight.h,
          ),
          hintText: hintText,
          hintStyle: AppFonts.bodyText,
        ),
      ),
    );
  }
}
