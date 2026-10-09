import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'activity/activity_screen.dart';
import 'home/home_screen.dart';
import 'bookings/bookings_screen.dart';
import 'profile/profile_screen.dart';
import '../constants/app_fonts.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _isValidIndex(widget.initialIndex)
        ? widget.initialIndex
        : 0;
  }

  void setIndex(int index) {
    if (!_isValidIndex(index) || index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  static const int _tabCount = 4;

  bool _isValidIndex(int index) => index >= 0 && index < _tabCount;

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B41A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.exit_to_app_rounded,
                    color: const Color(0xFFF4B41A),
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Exit App?',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Are you sure you want to exit Fleetgo?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4B41A),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Exit',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        } else {
          final bool exitApp = await _showExitDialog(context) ?? false;
          if (exitApp) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(onViewAllServices: () => setIndex(1)),
            const ActivityScreen(),
            const BookingsScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: CustomBottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: setIndex,
            ),
          ),
        ),
      ),
    );
  }
}
