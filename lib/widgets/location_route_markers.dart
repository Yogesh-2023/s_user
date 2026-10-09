import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RouteLocationMarker extends StatelessWidget {
  final bool isPickup;
  final double size;

  const RouteLocationMarker.pickup({super.key, this.size = 20})
    : isPickup = true;

  const RouteLocationMarker.dropOff({super.key, this.size = 16})
    : isPickup = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Center(
        child: Image.asset(
          isPickup
              ? 'assets/images/pickup_marker.png'
              : 'assets/images/drop_marker.png',
          width: size.r,
          height: size.r,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class RouteMarkerTimeline extends StatelessWidget {
  final double connectorHeight;

  const RouteMarkerTimeline({super.key, this.connectorHeight = 34});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const RouteLocationMarker.pickup(size: 20),
          Transform.translate(
            offset: Offset(0, -1.h),
            child: Container(
              width: 2.w,
              height: connectorHeight.h + 2.h,
              color: const Color(0xFFD7DEE8),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -2.h),
            child: const RouteLocationMarker.dropOff(size: 16),
          ),
        ],
      ),
    );
  }
}

