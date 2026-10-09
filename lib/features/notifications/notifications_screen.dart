import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import 'controllers/notification_controller.dart';
import '../rides/driver_assigned_screen.dart';
import '../rides/driver_tracking_screen.dart';
import '../rides/payment_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationController _controller =
      Get.find<NotificationController>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.refreshList();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _controller.fetchNotifications();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        toolbarHeight: 68.h,
        leadingWidth: 44.w,
        titleSpacing: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black, size: 22.sp),
        title: Text(
          'Notifications',
          style: AppFonts.semiBold(size: 20, color: Colors.black),
        ),
        actions: [
          // Notification settings are temporarily hidden.
          // IconButton(
          //   icon: const Icon(Icons.settings, color: Colors.black),
          //   onPressed: () {
          //     Get.to(() => const NotificationPreferencesScreen());
          //   },
          // ),
          Obx(() {
            if (_controller.unreadCount.value > 0) {
              return TextButton(
                onPressed: _controller.markAllAsRead,
                child: Text(
                  'Mark all read',
                  style: AppFonts.medium(color: AppColors.fleetgoYellow),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.fleetgoYellow),
          );
        }

        if (_controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 64.w,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 16.h),
                Text(
                  'No notifications yet',
                  style: AppFonts.semiBold(size: 18, color: Colors.black54),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    "You don't have any notifications at the moment. We'll let you know when something arrives.",
                    textAlign: TextAlign.center,
                    style: AppFonts.regular(size: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.refreshList,
          color: AppColors.fleetgoYellow,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
                _controller.notifications.length +
                (_controller.hasMore.value ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == _controller.notifications.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.fleetgoYellow,
                    ),
                  ),
                );
              }

              final item = _controller.notifications[index];
              final isRead = item['isRead'] ?? false;

              return Dismissible(
                key: Key(item['id'] ?? item['_id'] ?? index.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  _controller.deleteNotification(
                    item['id'] ?? item['_id'],
                    index,
                  );
                },
                child: InkWell(
                  onTap: () {
                    final notificationId = item['id'] ?? item['_id'];
                    if (notificationId != null) {
                      _controller.markAsRead(notificationId.toString(), index);
                    }
                    final data = item['metadata'] is Map
                        ? Map<String, dynamic>.from(item['metadata'] as Map)
                        : item['data'] is Map
                        ? Map<String, dynamic>.from(item['data'] as Map)
                        : null;
                    if (data != null) {
                      final bookingId = (data['rideId'] ?? data['bookingId'] ?? data['tripId'])?.toString();
                      final type = (data['type'] ?? data['event'] ?? data['module'])?.toString().toUpperCase();
                      if (bookingId != null && bookingId.isNotEmpty) {
                        if (type == 'DRIVER_ASSIGNED' || type == 'DRIVER_ARRIVED') {
                          Get.to(() => DriverAssignedScreen(tripId: bookingId, driverData: data));
                        } else if (type == 'RIDE_STARTED' || type == 'TRIP_STARTED' || type == 'IN_TRANSIT') {
                          Get.to(() => DriverTrackingScreen(tripId: bookingId, driverData: data));
                        } else if (type == 'RIDE_COMPLETED' || type == 'PAYMENT_PENDING') {
                          Get.to(() => PaymentScreen(bookingId: bookingId, driverData: data));
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    color: isRead
                        ? Colors.white
                        : AppColors.fleetgoYellow.withOpacity(0.05),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isRead
                              ? Colors.grey[200]
                              : AppColors.fleetgoYellow.withOpacity(0.1),
                          child: Icon(
                            Icons.notifications,
                            color: isRead
                                ? Colors.grey
                                : AppColors.fleetgoYellow,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] ?? 'Notification',
                                style: AppFonts.semiBold(
                                  size: 16,
                                  color: isRead ? Colors.black87 : Colors.black,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                item['body'] ?? item['message'] ?? '',
                                style: AppFonts.regular(
                                  size: 14,
                                  color: Colors.grey[600]!,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                _formatDate(
                                  item['createdAt'] ?? item['created_at'],
                                ),
                                style: AppFonts.regular(
                                  size: 12,
                                  color: Colors.grey[400]!,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8.w,
                            height: 8.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.fleetgoYellow,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }
}
