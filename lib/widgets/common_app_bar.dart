import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_fonts.dart';
import '../features/main_navigation_screen.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailingAction;
  final bool showBackArrow;

  const CommonAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailingAction,
    this.showBackArrow = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(48.h);

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      final mainNav = context.findAncestorStateOfType<MainNavigationScreenState>();
      if (mainNav != null) {
        mainNav.setIndex(0);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(initialIndex: 0),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 48.h,
          padding: EdgeInsets.only(left: 12.w, right: 16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBackArrow)
                GestureDetector(
                  onTap: () => _handleBack(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 22.sp,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              if (showBackArrow) SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
              ),
              if (trailingAction case final action?) action,
            ],
          ),
        ),
      ),
    );
  }
}
