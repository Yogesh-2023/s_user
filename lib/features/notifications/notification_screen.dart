import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static const List<_NotificationItem> _items = [
    _NotificationItem(
      icon: Icons.local_taxi_outlined,
      title: 'Ride confirmed',
      message:
          'Your cab booking is confirmed. Driver details will appear soon.',
      time: '2 min ago',
      color: Color(0xFFF4B41A),
    ),
    _NotificationItem(
      icon: Icons.local_offer_outlined,
      title: 'New offer available',
      message: 'Use your welcome offer on the next ride before it expires.',
      time: '18 min ago',
      color: Color(0xFFFFA726),
    ),
    _NotificationItem(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Wallet updated',
      message: 'Your wallet balance was refreshed successfully.',
      time: 'Today',
      color: Color(0xFF24B47E),
    ),
    _NotificationItem(
      icon: Icons.inventory_2_outlined,
      title: 'Parcel support',
      message: 'Parcel pickup updates will be shown here in real time.',
      time: 'Yesterday',
      color: Color(0xFF7C4DFF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
                itemCount: _items.length + 1,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildSummary();
                  }
                  return _NotificationTile(item: _items[index - 1]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 16.h),
      color: AppColors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.authButtonBorder),
                color: AppColors.white,
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20.sp,
                color: AppColors.black,
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              'Notifications',
              style: AppFonts.h1.copyWith(
                fontSize: 22.sp,
                color: AppColors.black,
              ),
            ),
          ),
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              color: const Color(0xFFF4B41A),
              size: 22.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE9F3F8)),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF9E6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.done_all,
              color: const Color(0xFFF4B41A),
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are all caught up',
                  style: AppFonts.h2.copyWith(
                    fontSize: 16.sp,
                    color: AppColors.black,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Recent ride, wallet, and offer updates appear here.',
                  style: AppFonts.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _NotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFECEFF3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppFonts.h2.copyWith(
                          fontSize: 15.sp,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      item.time,
                      style: AppFonts.bodyText.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  item.message,
                  style: AppFonts.bodyText.copyWith(
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final Color color;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.color,
  });
}
