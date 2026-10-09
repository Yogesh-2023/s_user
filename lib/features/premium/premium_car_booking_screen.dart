import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_service.dart';
import '../../core/utils.dart';
import '../main_navigation_screen.dart';

class PremiumCarBookingScreen extends StatefulWidget {
  const PremiumCarBookingScreen({super.key, required this.car});

  final Map<String, dynamic> car;

  @override
  State<PremiumCarBookingScreen> createState() =>
      _PremiumCarBookingScreenState();
}

class _PremiumCarBookingScreenState extends State<PremiumCarBookingScreen> {
  DateTime? _start;
  DateTime? _end;
  bool _startDateSelected = false;
  bool _startTimeSelected = false;
  bool _endDateSelected = false;
  bool _endTimeSelected = false;
  bool _driverRequired = true;
  bool _submitting = false;

  dynamic _nested(String key, String child) {
    final value = widget.car[key];
    return value is Map ? value[child] : null;
  }

  double get _hourlyPrice =>
      (_nested('price', 'hourlyPrice') as num?)?.toDouble() ?? 0;
  double get _hours => _start == null || _end == null
      ? 0
      : _end!.difference(_start!).inMinutes / 60;
  double get _estimate => _hours * _hourlyPrice;
  bool get _startComplete =>
      _startDateSelected && _startTimeSelected && _start != null;
  bool get _endComplete => _endDateSelected && _endTimeSelected && _end != null;
  Future<DateTime?> _pickDate(DateTime? initial, {DateTime? minimum}) async {
    final now = DateTime.now();
    final firstAllowed = minimum ?? now;
    final firstDate = DateTime(
      firstAllowed.year,
      firstAllowed.month,
      firstAllowed.day,
    );
    final date = await showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isBefore(firstDate)
          ? initial
          : firstDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return initial;
    if (initial == null) return date;
    return DateTime(
      date.year,
      date.month,
      date.day,
      initial.hour,
      initial.minute,
    );
  }

  Future<DateTime?> _pickTime(DateTime? initial) async {
    final time = await showTimePicker(
      context: context,
      initialTime: initial == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFF4B41A),
            onPrimary: Colors.black,
          ),
          timePickerTheme: TimePickerThemeData(
            hourMinuteTextStyle: TextStyle(
              fontSize: 42.sp,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
            timeSelectorSeparatorTextStyle: WidgetStateProperty.all(
              TextStyle(
                fontSize: 40.sp,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return initial;
    final baseDate = initial ?? DateTime.now();
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      time.hour,
      time.minute,
    );
  }

  String _justDateText(DateTime? value) =>
      value == null ? 'Date' : DateFormat('dd MMM yyyy').format(value);

  String _justTimeText(DateTime? value) =>
      value == null ? 'Time' : DateFormat('hh:mm a').format(value);

  @override
  Widget build(BuildContext context) {
    final brand = _nested('brand', 'name')?.toString() ?? 'Premium';
    final model = _nested('model', 'name')?.toString() ?? 'Car';
    final image = _nested('model', 'imageUrl')?.toString();
    final provider = _nested('provider', 'name')?.toString();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: Container(
                    height: 205.h,
                    color: const Color(0xFFEAF6FB),
                    child: image == null
                        ? Icon(
                            Icons.directions_car_filled_rounded,
                            size: 90.sp,
                            color: const Color(0xFF00A2E8),
                          )
                        : Image.network(image, fit: BoxFit.cover),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  '$brand $model',
                  style: AppFonts.h1.copyWith(fontSize: 22.sp),
                ),
                SizedBox(height: 5.h),
                Text(
                  provider == null
                      ? 'Verified provider'
                      : 'Provided by $provider',
                  style: AppFonts.bodyText,
                ),
                SizedBox(height: 16.h),
                _card(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _dateTile(
                              title: 'Start Date',
                              value: _justDateText(_start),
                              icon: Icons.calendar_today_rounded,
                              onTap: () async {
                                final value = await _pickDate(_start);
                                if (value != null) {
                                  setState(() {
                                    _start = value;
                                    _startDateSelected = true;
                                    if (_startTimeSelected &&
                                        !value.isAfter(DateTime.now())) {
                                      _startTimeSelected = false;
                                    }
                                    if (_end != null && !_end!.isAfter(value)) {
                                      _end = null;
                                      _endDateSelected = false;
                                      _endTimeSelected = false;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _dateTile(
                              title: 'Start Time',
                              value: _justTimeText(_start),
                              icon: Icons.access_time_rounded,
                              enabled: _startDateSelected,
                              onTap: !_startDateSelected
                                  ? null
                                  : () async {
                                      final value = await _pickTime(_start);
                                      if (value != null) {
                                        if (!value.isAfter(DateTime.now())) {
                                          _message(
                                            'Please select a future start time.',
                                            error: true,
                                          );
                                          return;
                                        }
                                        setState(() {
                                          _start = value;
                                          _startTimeSelected = true;
                                          if (_end != null &&
                                              !_end!.isAfter(value)) {
                                            _end = null;
                                            _endDateSelected = false;
                                            _endTimeSelected = false;
                                          }
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _dateTile(
                              title: 'End Date',
                              value: _justDateText(_end),
                              icon: Icons.event_available_rounded,
                              enabled: _startComplete,
                              onTap: !_startComplete
                                  ? null
                                  : () async {
                                      final value = await _pickDate(
                                        _end ?? _start,
                                        minimum: _start,
                                      );
                                      if (value != null) {
                                        setState(() {
                                          _end = value;
                                          _endDateSelected = true;
                                          if (_endTimeSelected &&
                                              !value.isAfter(_start!)) {
                                            _endTimeSelected = false;
                                          }
                                        });
                                      }
                                    },
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _dateTile(
                              title: 'End Time',
                              value: _justTimeText(_end),
                              icon: Icons.access_time_rounded,
                              enabled: _startComplete && _endDateSelected,
                              onTap: !_startComplete || !_endDateSelected
                                  ? null
                                  : () async {
                                      final value = await _pickTime(_end);
                                      if (value != null) {
                                        if (!value.isAfter(_start!)) {
                                          _message(
                                            'End time must be after start time.',
                                            error: true,
                                          );
                                          return;
                                        }
                                        setState(() {
                                          _end = value;
                                          _endTimeSelected = true;
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                _card(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Driver Required',
                      style: AppFonts.h2.copyWith(fontSize: 16.sp),
                    ),
                    subtitle: Text(
                      'Turn off if you will drive the car yourself',
                      style: AppFonts.captionDark,
                    ),
                    value: _driverRequired,
                    activeTrackColor: const Color(0xFF00A2E8),
                    onChanged: (value) =>
                        setState(() => _driverRequired = value),
                  ),
                ),
                SizedBox(height: 14.h),
                _card(
                  child: Column(
                    children: [
                      _priceRow(
                        'Hourly price',
                        '₹${_hourlyPrice.toStringAsFixed(0)}',
                      ),
                      SizedBox(height: 10.h),
                      _priceRow('Estimated hours', _hours.toStringAsFixed(1)),
                      const Divider(height: 24),
                      _priceRow(
                        'Estimated total',
                        '₹${_estimate.toStringAsFixed(0)}',
                        strong: true,
                      ),
                      SizedBox(height: 5.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Final hours and amount are calculated by the backend.',
                          style: AppFonts.captionDark,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 22.h),
                SizedBox(
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _book,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4B41A),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: _submitting
                        ? const CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          )
                        : Text(
                            'Request Booking',
                            style: AppFonts.buttonText.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Container(
    color: const Color(0xFFFFF9E6),
    padding: EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + 16.h,
      bottom: 16.h,
      left: 20.w,
      right: 20.w,
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: EdgeInsets.all(4.r),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 22.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Book Premium Car',
            style: AppFonts.h1.copyWith(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: EdgeInsets.all(15.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15.r),
      border: Border.all(color: const Color(0xFFE4E8ED)),
    ),
    child: child,
  );

  Widget _dateTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFFFF9E6) : const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: enabled
              ? const Color(0xFFF4B41A).withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: enabled ? const Color(0xFFF4B41A) : Colors.grey,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppFonts.captionDark.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: AppFonts.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.sp,
                    color: !enabled
                        ? Colors.grey
                        : (value == 'Date' || value == 'Time')
                        ? const Color(0xFF94A3B8)
                        : AppColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _priceRow(String label, String value, {bool strong = false}) => Row(
    children: [
      Expanded(child: Text(label, style: AppFonts.bodyText)),
      Text(
        value,
        style: AppFonts.h2.copyWith(
          color: strong ? const Color(0xFF111827) : AppColors.black,
          fontSize: strong ? 18.sp : 14.sp,
          fontWeight: strong ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ],
  );

  Future<void> _book() async {
    if (_start == null || _end == null) {
      _message('Please select start and end date/time.', error: true);
      return;
    }
    if (!_end!.isAfter(_start!)) {
      _message('End time must be after start time.', error: true);
      return;
    }
    if (_start!.isBefore(DateTime.now())) {
      _message('Start time cannot be in the past.', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final response = await ApiService.to.post(
        ApiEndpoints.createPremiumBooking,
        body: {
          'premiumCarId': widget.car['id'],
          'startDateTime': _start!.toUtc().toIso8601String(),
          'endDateTime': _end!.toUtc().toIso8601String(),
          'driverRequired': _driverRequired,
        },
      );
      if (!mounted) return;
      final data = response.data?['data'];
      final amount = data is Map ? data['totalAmount'] : null;
      _message(
        amount == null
            ? 'Premium booking request created.'
            : 'Booking requested. Total: ₹$amount',
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(initialIndex: 2),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        _message(error.toString().split(':').last.trim(), error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text, {bool error = false}) {
    AppUtils.showSnackBar(context, text, isError: error);
  }
}
