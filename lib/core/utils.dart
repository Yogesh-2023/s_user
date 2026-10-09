import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'api/api_exception.dart';

// Place your core utility functions, network helpers, and app configurations here.
class AppUtils {
  static void printLog(String message) {
    print('APP LOG: $message');
  }

  static num? parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return null;
      return num.tryParse(cleaned);
    }
    return null;
  }

  static double? parseDouble(dynamic value) {
    final parsed = parseNum(value);
    return parsed?.toDouble();
  }

  static int? parseInt(dynamic value) {
    final parsed = parseNum(value);
    return parsed?.toInt();
  }

  static String? parseString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }


  static String extractErrorMessage(dynamic error) {
    if (error == null) return 'Something went wrong';
    if (error is String) return error;

    if (error is ApiException) {
      if (error.responseBody is Map<String, dynamic>) {
        final body = error.responseBody as Map<String, dynamic>;
        final errorObj = body['error'];
        final details = (errorObj is Map<String, dynamic> ? errorObj['details'] : null) ?? body['details'];
        if (details is Map<String, dynamic>) {
          final fieldErrors = details['fieldErrors'];
          if (fieldErrors is Map<String, dynamic>) {
            final messages = <String>[];
            fieldErrors.forEach((key, val) {
              if (val is List && val.isNotEmpty) {
                messages.add(val.first.toString());
              } else if (val is String && val.isNotEmpty) {
                messages.add(val);
              }
            });
            if (messages.isNotEmpty) {
              return messages.join(', ');
            }
          }
        }
        if (errorObj is Map<String, dynamic> && errorObj['message'] is String && errorObj['message'].toString().isNotEmpty) {
          return errorObj['message'].toString();
        }
        if (body['message'] is String && body['message'] != 'Request validation failed') {
          return body['message'].toString();
        }
      }
      return error.message;
    }

    final str = error.toString();
    if (str.contains('Invalid Indian mobile number')) {
      return 'Invalid Indian mobile number';
    }
    if (str.startsWith('Exception: ')) return str.substring(11);
    return str;
  }

  static String cleanGeocodedAddress(String address) {
    final regex = RegExp(r'\b\d{10}\b[\s,]*');
    return address.replaceAll(regex, '').trim();
  }

  static OverlayEntry? _currentOverlayEntry;

  static void clearSnackBar() {
    if (_currentOverlayEntry != null) {
      try {
        _currentOverlayEntry!.remove();
      } catch (_) {}
      _currentOverlayEntry = null;
    }
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    clearSnackBar();

    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    final overlayState = rootNav?.overlay ?? Overlay.maybeOf(context);
    if (overlayState == null) return;

    final mediaQuery = MediaQuery.maybeOf(context);
    final topPadding = mediaQuery?.padding.top ?? 40.0;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopSnackBarWidget(
        message: message,
        isError: isError,
        topPadding: topPadding,
        onDismiss: () {
          if (_currentOverlayEntry == entry) {
            try {
              entry.remove();
            } catch (_) {}
            _currentOverlayEntry = null;
          }
        },
      ),
    );

    _currentOverlayEntry = entry;
    overlayState.insert(entry);
  }
}

class _TopSnackBarWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final double topPadding;
  final VoidCallback onDismiss;

  const _TopSnackBarWidget({
    required this.message,
    required this.isError,
    required this.topPadding,
    required this.onDismiss,
  });

  @override
  State<_TopSnackBarWidget> createState() => _TopSnackBarWidgetState();
}

class _TopSnackBarWidgetState extends State<_TopSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: widget.isError
                    ? Colors.red.shade600
                    : Colors.green.shade600,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 21.sp,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      widget.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
