import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../constants/app_fonts.dart';

class CountdownTimer extends StatefulWidget {
  final String expiresAt;
  final VoidCallback? onExpired;

  const CountdownTimer({super.key, required this.expiresAt, this.onExpired});

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    if (_remaining.inSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _calculateRemaining();
      });
    }
  }

  void _calculateRemaining() {
    final expiryDate = DateTime.tryParse(widget.expiresAt);
    if (expiryDate == null) return;

    final now = DateTime.now();
    final remaining = expiryDate.difference(now);

    if (remaining.isNegative) {
      if (_timer != null) {
        _timer?.cancel();
        _timer = null;
        widget.onExpired?.call();
      }
      if (mounted) {
        setState(() => _remaining = Duration.zero);
      }
    } else {
      if (mounted) {
        setState(() => _remaining = remaining);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    if (_remaining.inSeconds <= 0) return 'Expired';
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    }
    return '${minutes}m ${seconds}s remaining';
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining.inSeconds <= 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14.sp,
            color: isExpired ? Colors.red.shade700 : Colors.orange.shade800,
          ),
          SizedBox(width: 6.w),
          Text(
            _formattedTime,
            style: AppFonts.semiBold(
              size: 10,
              color: isExpired ? Colors.red.shade700 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
