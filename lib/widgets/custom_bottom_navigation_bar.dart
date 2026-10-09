import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_fonts.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color selectedColor = Color(0xFFFFC000);
    const Color unselectedColor = Color(0xFF484C52);
    const Color borderColor = Color(0xFFDBDBDB);

    return SizedBox(
      height: 70.h,
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12.w),
          height: 70.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_filled,
                isIconData: true,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
              _buildNavItem(
                index: 1,
                label: 'Services',
                assetPath: 'assets/images/servicenew.png',
                isIconData: false,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
              _buildNavItem(
                index: 2,
                label: 'Booking',
                assetPath: 'assets/images/bookingnew.png',
                isIconData: false,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
              _buildNavItem(
                index: 3,
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                isIconData: true,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    IconData? icon,
    String? assetPath,
    required bool isIconData,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final bool isSelected = currentIndex == index;
    final Color itemColor = isSelected ? selectedColor : unselectedColor;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(15.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isIconData && icon != null)
              Icon(
                icon,
                size: 22.sp,
                color: itemColor,
              )
            else if (assetPath != null)
              ImageIcon(
                AssetImage(assetPath),
                size: 22.sp,
                color: itemColor,
              ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: itemColor,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
