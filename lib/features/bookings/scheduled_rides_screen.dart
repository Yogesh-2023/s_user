import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../constants/app_fonts.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_service.dart';
import '../../widgets/location_route_markers.dart';

import '../../services/scheduled_rides_service.dart';

import '../../core/socket/socket_service.dart';
import '../../core/socket/socket_events.dart';

class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  static const _yellow = Color(0xFFF4B41A);

  final ScheduledRidesService _scheduledRidesService = ScheduledRidesService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _rides = [];
  final Set<String> _busyRideIds = {};

  @override
  void initState() {
    super.initState();
    _loadRides();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    try {
      SocketService.to.listenTo(SocketEvents.bookingDriverAssigned, _onSocketUpdate);
      SocketService.to.listenTo(SocketEvents.bookingCancelled, _onSocketUpdate);
      SocketService.to.listenTo(SocketEvents.bookingRescheduled, _onSocketUpdate);
    } catch (_) {}
  }

  void _onSocketUpdate(dynamic data) {
    if (mounted) _loadRides(showLoader: false);
  }

  @override
  void dispose() {
    try {
      SocketService.to.stopListening(SocketEvents.bookingDriverAssigned, _onSocketUpdate);
      SocketService.to.stopListening(SocketEvents.bookingCancelled, _onSocketUpdate);
      SocketService.to.stopListening(SocketEvents.bookingRescheduled, _onSocketUpdate);
    } catch (_) {}
    super.dispose();
  }

  Map<String, dynamic>? _extractRide(dynamic responseData) {
    if (responseData is! Map) return null;
    final data = responseData['data'] ?? responseData['ride'] ?? responseData;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<void> _loadRides({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _scheduledRidesService.fetchScheduledRides(
        status: 'UPCOMING',
        page: 1,
        limit: 20,
      );
      final rides = List<Map<String, dynamic>>.from(result.rides);
      rides.sort((a, b) {
        final first = _scheduledDate(a) ?? DateTime(2100);
        final second = _scheduledDate(b) ?? DateTime(2100);
        return first.compareTo(second);
      });
      if (!mounted) return;
      setState(() {
        _rides = rides;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _message(error);
      });
    }
  }

  String _rideId(Map<String, dynamic> ride) {
    return (ride['id'] ?? ride['_id'] ?? ride['bookingId'] ?? '').toString();
  }

  DateTime? _scheduledDate(Map<String, dynamic> ride) {
    final raw =
        ride['scheduledAt'] ??
        ride['scheduleAt'] ??
        ride['scheduledDateTime'] ??
        ride['pickupTime'];
    return raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
  }

  String _address(Map<String, dynamic> ride, String type) {
    final location =
        ride[type] ??
        ride['${type}Location'] ??
        ride[type == 'drop' ? 'destination' : 'source'];
    if (location is Map) {
      return (location['address'] ?? location['formattedAddress'] ?? '')
          .toString();
    }
    return location?.toString() ?? '';
  }

  String _message(Object error) {
    final str = error.toString();
    if (str.contains('409') ||
        str.toLowerCase().contains('only pending') ||
        str.toLowerCase().contains('conflict')) {
      return 'Only pending scheduled rides can be rescheduled.';
    }
    return str
        .replaceFirst('ApiException:', '')
        .replaceFirst('Exception:', '')
        .trim();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Schedule unavailable';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${value.day} ${months[value.month - 1]} ${value.year}, $hour:$minute $period';
  }

  String _status(Map<String, dynamic> ride) {
    final raw = (ride['status'] ?? ride['bookingStatus'] ?? 'SCHEDULED').toString();
    return raw
        .split('_')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  bool _isReschedulable(Map<String, dynamic> ride) {
    final status = (ride['status'] ?? ride['bookingStatus'] ?? '').toString().toUpperCase();
    return status == 'PENDING' || status == 'SCHEDULED';
  }

  bool _isCancellable(Map<String, dynamic> ride) {
    final status = (ride['status'] ?? ride['bookingStatus'] ?? '').toString().toUpperCase();
    return status != 'CANCELLED' && status != 'COMPLETED' && status != 'FINISHED';
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final minValidTime = now.add(const Duration(minutes: 20));
    final initial = current != null && current.isAfter(minValidTime)
        ? current
        : minValidTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: _yellow,
            onPrimary: Colors.black,
            surface: Colors.white,
            onSurface: Color(0xFF111827),
          ),
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF111827)),
            hintStyle: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: _yellow,
            onPrimary: Colors.black,
            surface: Colors.white,
            onSurface: Color(0xFF111827),
          ),
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
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
    if (time == null) return null;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isBefore(DateTime.now().add(const Duration(minutes: 15)))) {
      if (mounted) {
        _showMessage('Select a time at least 15-20 minutes from now.', isError: true);
      }
      return null;
    }
    return selected;
  }

  Future<void> _changeSchedule(
    Map<String, dynamic> ride, {
    required bool useBookingEndpoint,
  }) async {
    final id = _rideId(ride);
    if (id.isEmpty || _busyRideIds.contains(id)) return;

    if (!_isReschedulable(ride)) {
      _showMessage(
        'Only pending scheduled rides can be rescheduled.',
        isError: true,
      );
      return;
    }

    final selected = await _pickDateTime(_scheduledDate(ride));
    if (selected == null || !mounted) return;

    setState(() => _busyRideIds.add(id));
    try {
      final endpoint = useBookingEndpoint
          ? ApiEndpoints.rescheduleBooking(id)
          : ApiEndpoints.scheduledRide(id);
      await ApiService.to.patch(
        endpoint,
        body: {'scheduledAt': selected.toUtc().toIso8601String()},
      );
      if (!mounted) return;
      _showMessage(
        useBookingEndpoint ? 'Ride rescheduled.' : 'Schedule updated.',
      );
      await _loadRides(showLoader: false);
    } catch (error) {
      if (mounted) {
        final errStr = error.toString().toLowerCase();
        if (errStr.contains('409') ||
            errStr.contains('only pending') ||
            errStr.contains('conflict')) {
          _showMessage(
            'Only pending scheduled rides can be rescheduled.',
            isError: true,
          );
        } else {
          _showMessage(_message(error), isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _busyRideIds.remove(id));
    }
  }

  Future<void> _cancelRide(Map<String, dynamic> ride) async {
    final id = _rideId(ride);
    if (id.isEmpty || _busyRideIds.contains(id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
        contentPadding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                color: const Color(0xFFDC2626),
                size: 22.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Cancel Scheduled Ride?',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this scheduled ride? This action cannot be undone.',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 13.sp,
            color: const Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Keep Ride',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Cancel Ride',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyRideIds.add(id));
    try {
      final cancelBody = {
        'reasonCode': 'USER_CANCELLED',
        'reason': 'Changed my mind',
      };
      try {
        await ApiService.to.post(
          ApiEndpoints.cancelBooking(id),
          body: cancelBody,
        );
      } catch (_) {
        await ApiService.to.delete(
          ApiEndpoints.scheduledRide(id),
          body: cancelBody,
        );
      }
      if (!mounted) return;
      _showMessage('Scheduled ride cancelled.');
      await _loadRides(showLoader: false);
    } catch (error) {
      if (mounted) _showMessage(_message(error), isError: true);
    } finally {
      if (mounted) setState(() => _busyRideIds.remove(id));
    }
  }

  Future<void> _showDetails(Map<String, dynamic> summary) async {
    final id = _rideId(summary);
    if (id.isEmpty) {
      _showMessage('Scheduled ride ID is missing.', isError: true);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => FutureBuilder(
        future: ApiService.to.get(ApiEndpoints.scheduledRide(id)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 260.h,
              child: const Center(
                child: CircularProgressIndicator(color: _yellow),
              ),
            );
          }
          final response = snapshot.data;
          final ride = response == null
              ? summary
              : _extractRide(response.data) ?? summary;
          return _detailsSheet(sheetContext, ride);
        },
      ),
    );
  }

  Widget _detailsSheet(BuildContext sheetContext, Map<String, dynamic> ride) {
    final canReschedule = _isReschedulable(ride);
    final canCancel = _isCancellable(ride);

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Scheduled Ride Details',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          _detailRow(
            Icons.calendar_month_rounded,
            _formatDate(_scheduledDate(ride)),
          ),
          _detailRow(Icons.trip_origin_rounded, _address(ride, 'pickup')),
          _detailRow(Icons.location_on_rounded, _address(ride, 'drop')),
          _detailRow(Icons.info_outline_rounded, _status(ride)),
          SizedBox(height: 18.h),
          if (canReschedule || canCancel)
            Row(
              children: [
                if (canReschedule) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _changeSchedule(ride, useBookingEndpoint: false);
                      },
                      icon: Icon(Icons.edit_calendar_rounded, size: 16.sp),
                      label: Text(
                        'Update',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _changeSchedule(ride, useBookingEndpoint: true);
                      },
                      icon: Icon(Icons.event_repeat_rounded, size: 16.sp),
                      label: Text(
                        'Reschedule',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (canCancel) SizedBox(width: 6.w),
                ],
                if (canCancel)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFFDC2626),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _cancelRide(ride);
                      },
                      icon: Icon(Icons.cancel_outlined, size: 16.sp),
                      label: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.sp, color: const Color(0xFFD39400)),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 13.sp,
                height: 1.4,
                color: const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.isEmpty ? 'Something went wrong.' : message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9E6),
        toolbarHeight: 68.h,
        leadingWidth: 44.w,
        titleSpacing: 0,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Scheduled Rides',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _yellow));
    }
    if (_error != null && _rides.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, size: 48.sp, color: Colors.grey.shade400),
              SizedBox(height: 12.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 13.sp,
                  color: const Color(0xFF111827),
                ),
              ),
              SizedBox(height: 14.h),
              ElevatedButton(
                onPressed: _loadRides,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _yellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _yellow,
      onRefresh: () => _loadRides(showLoader: false),
      child: _rides.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 130.h),
                Icon(
                  Icons.calendar_month_outlined,
                  size: 56.sp,
                  color: const Color(0xFF9CA3AF),
                ),
                SizedBox(height: 14.h),
                Text(
                  'No scheduled rides',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'You don\'t have any upcoming scheduled rides.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              itemCount: _rides.length,
              separatorBuilder: (_, _) => SizedBox(height: 12.h),
              itemBuilder: (context, index) => _rideCard(_rides[index]),
            ),
    );
  }

  Widget _rideCard(Map<String, dynamic> ride) {
    final id = _rideId(ride);
    final busy = _busyRideIds.contains(id);
    final canReschedule = _isReschedulable(ride);
    final canCancel = _isCancellable(ride);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: busy ? null : () => _showDetails(ride),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: const Color(0xFFFFC000)),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(_scheduledDate(ride)),
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E6),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  _status(ride),
                                  style: TextStyle(
                                    fontFamily: AppFonts.fontFamily,
                                    fontSize: 11.sp,
                                    color: const Color(0xFFD97706),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (busy)
                      SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _yellow,
                        ),
                      )
                    else if (canReschedule || canCancel)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF374151)),
                        onSelected: (action) {
                          if (action == 'update') {
                            _changeSchedule(ride, useBookingEndpoint: false);
                          } else if (action == 'reschedule') {
                            _changeSchedule(ride, useBookingEndpoint: true);
                          } else if (action == 'cancel') {
                            _cancelRide(ride);
                          }
                        },
                        itemBuilder: (context) => [
                          if (canReschedule) ...[
                            PopupMenuItem(
                              value: 'update',
                              child: Text(
                                'Update Time',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 13.sp,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'reschedule',
                              child: Text(
                                'Reschedule',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 13.sp,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                          ],
                          if (canCancel)
                            PopupMenuItem(
                              value: 'cancel',
                              child: Text(
                                'Cancel Ride',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 14.h),
                _routeLine(_address(ride, 'pickup'), isPickup: true),
                Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Container(
                    width: 1,
                    height: 12.h,
                    color: Colors.grey[300],
                  ),
                ),
                _routeLine(_address(ride, 'drop'), isPickup: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeLine(String address, {required bool isPickup}) {
    return Row(
      children: [
        isPickup
            ? const RouteLocationMarker.pickup()
            : const RouteLocationMarker.dropOff(),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            address.isEmpty ? 'Address unavailable' : address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 12.sp,
              fontWeight: isPickup ? FontWeight.w500 : FontWeight.w600,
              color: isPickup ? const Color(0xFF374151) : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}
