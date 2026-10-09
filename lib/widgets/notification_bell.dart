import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../features/notifications/controllers/notification_controller.dart';
import '../features/notifications/notifications_screen.dart';

class NotificationBell extends StatefulWidget {
  final Color iconColor;
  final Color backgroundColor;
  final double size;
  final VoidCallback? onTap;

  const NotificationBell({
    super.key,
    this.iconColor = Colors.black87,
    this.backgroundColor = const Color(0xFFF8F9FA),
    this.size = 40,
    this.onTap,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  Worker? _ringWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.25), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.25), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.15), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: 0.0), weight: 10),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (Get.isRegistered<NotificationController>()) {
      _ringWorker = ever(NotificationController.to.ringTrigger, (_) {
        if (mounted) {
          _animationController.forward(from: 0);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Get.isRegistered<NotificationController>()) {
        NotificationController.to.syncLocalNotifications();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringWorker?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<NotificationController>()
        ? NotificationController.to
        : Get.put(NotificationController());

    final isSquare = widget.size > 0;

    return GestureDetector(
      onTap: widget.onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
      child: Container(
        width: isSquare ? widget.size.r : null,
        height: isSquare ? widget.size.r : null,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: child,
                );
              },
              child: Icon(
                Icons.notifications_none_rounded,
                color: widget.iconColor,
                size: (widget.size * 0.55).sp,
              ),
            ),
            Positioned(
              top: 4.r,
              right: 4.r,
              child: Obx(() {
                final count = controller.unreadCount.value;
                if (count > 0) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: count > 9 ? 4.r : 3.r,
                      vertical: 2.r,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16.r,
                      minHeight: 16.r,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Center(
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ),
          ],
        ),
      ),
    );
  }
}
