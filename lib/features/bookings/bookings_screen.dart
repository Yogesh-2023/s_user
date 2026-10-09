import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../services/trip_history_service.dart';
import '../../widgets/location_route_markers.dart';
import '../../widgets/common_app_bar.dart';
import '../../core/utils.dart';
import '../home/location_search_screen.dart';
import 'scheduled_rides_screen.dart';
import '../rides/cancellation_reason_drawer.dart';
import '../../models/booking_model.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final TripHistoryService _historyService = TripHistoryService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedStatus = 'ALL';
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _trips = [];
  Map<String, int> _counts = {
    'all': 0,
    'accepted': 0,
    'ongoing': 0,
    'completed': 0,
    'cancelled': 0,
    'noShow': 0,
  };

  static const List<Map<String, String>> _statusTabs = [
    {'key': 'ALL', 'label': 'All'},
    {'key': 'ONGOING', 'label': 'Ongoing'},
    {'key': 'COMPLETED', 'label': 'Completed'},
    {'key': 'CANCELLED', 'label': 'Cancel'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTrips(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        _currentPage < _totalPages) {
      _loadMoreTrips();
    }
  }

  String? _formatDateParam(DateTime? dt) {
    if (dt == null) return null;
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _loadTrips({bool reset = true, bool showLoader = true}) async {
    if (reset) {
      _currentPage = 1;
      if (showLoader && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    try {
      final dateFrom = _formatDateParam(_selectedDateRange?.start);
      final dateTo = _formatDateParam(_selectedDateRange?.end);
      final search = _searchController.text.trim();

      final result = await _historyService.fetchTrips(
        status: _selectedStatus,
        page: _currentPage,
        limit: 20,
        order: 'desc',
        dateFrom: dateFrom,
        dateTo: dateTo,
        search: search.isEmpty ? null : search,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _trips = result.trips;
        } else {
          _trips.addAll(result.trips);
        }
        _counts = result.counts;
        _totalPages = AppUtils.parseInt(result.pagination['totalPages']) ?? 1;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = AppUtils.extractErrorMessage(e);
      });
    }
  }

  Future<void> _loadMoreTrips() async {
    if (_currentPage >= _totalPages || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadTrips(reset: false, showLoader: false);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF4B41A),
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Color(0xFF111827),
              secondary: Color(0xFFF4B41A),
              onSecondary: Colors.black,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF111827)),
              bodyMedium: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF111827)),
              titleMedium: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF111827)),
              titleLarge: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF111827)),
              labelLarge: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF111827)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF111827)),
              hintStyle: TextStyle(fontFamily: AppFonts.fontFamily, color: const Color(0xFF9CA3AF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
              ),
              fillColor: Colors.white,
              filled: true,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadTrips(reset: true);
    }
  }

  int _getTabCount(String key) {
    switch (key) {
      case 'ALL':
        return AppUtils.parseInt(_counts['all']) ?? 0;
      case 'ONGOING':
        return AppUtils.parseInt(_counts['ongoing']) ?? 0;
      case 'COMPLETED':
        return AppUtils.parseInt(_counts['completed']) ?? 0;
      case 'CANCELLED':
        return AppUtils.parseInt(_counts['cancelled']) ?? 0;
      default:
        return 0;
    }
  }

  String _formatTripDate(dynamic dateRaw) {
    if (dateRaw == null) return 'Date unavailable';
    final str = AppUtils.parseString(dateRaw);
    if (str == null) return 'Date unavailable';
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt == null) return str;
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
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),
            _buildSearchAndDateBar(),
            _buildStatusTabs(),
            Expanded(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: _buildTripsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return CommonAppBar(
      title: 'Ride History',
      trailingAction: IconButton(
        tooltip: 'Scheduled Rides',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ScheduledRidesScreen(),
            ),
          );
        },
        icon: Container(
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFC000)),
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            size: 18.sp,
            color: const Color(0xFFD97706),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndDateBar() {
    final hasDateFilter = _selectedDateRange != null;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadTrips(reset: true),
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                hintText: 'Search pickup, drop or ID...',
                hintStyle: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 12.sp,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: Icon(Icons.search, size: 18.sp, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 16.sp),
                        onPressed: () {
                          _searchController.clear();
                          _loadTrips(reset: true);
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: hasDateFilter ? const Color(0xFFFFF9E6) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10.r),
                border: hasDateFilter
                    ? Border.all(color: const Color(0xFFFFC000))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 18.sp,
                    color: hasDateFilter ? const Color(0xFFD97706) : Colors.black87,
                  ),
                  if (hasDateFilter) ...[
                    SizedBox(width: 4.w),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedDateRange = null);
                        _loadTrips(reset: true);
                      },
                      child: Icon(Icons.close, size: 14.sp, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: _statusTabs.map((tab) {
            final key = tab['key']!;
            final label = tab['label']!;
            final isSelected = _selectedStatus == key;
            final count = _getTabCount(key);

            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: InkWell(
                onTap: () {
                  if (_selectedStatus != key) {
                    setState(() {
                      _selectedStatus = key;
                    });
                    _loadTrips(reset: true);
                  }
                },
                borderRadius: BorderRadius.circular(16.r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 32.h,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFC000)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.5.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.black : const Color(0xFF4B5563),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.black.withValues(alpha: 0.15)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTripsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.fleetgoYellow),
      );
    }

    if (_errorMessage != null && _trips.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48.sp, color: Colors.grey),
              SizedBox(height: 12.h),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 14.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC000),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _loadTrips(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
      final selectedLabel = _statusTabs.firstWhere(
        (t) => t['key'] == _selectedStatus,
        orElse: () => {'label': _selectedStatus},
      )['label'];

      return RefreshIndicator(
        color: AppColors.fleetgoYellow,
        onRefresh: () => _loadTrips(reset: true, showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 80.h),
            _buildEmptyState(
              icon: Icons.history_rounded,
              title: 'No Rides Found',
              subtitle: 'No rides available under "$selectedLabel" category.',
              showBookRideButton: true,
            ),
          ],
        ),
      );
    }

    final groupedItems = _groupTrips(_trips);

    return RefreshIndicator(
      color: AppColors.fleetgoYellow,
      onRefresh: () => _loadTrips(reset: true, showLoader: false),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
        itemCount: groupedItems.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          if (index == groupedItems.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: const CircularProgressIndicator(color: AppColors.fleetgoYellow),
              ),
            );
          }
          final item = groupedItems[index];
          if (item is _TripGroupItem) {
            return _buildReturnTripGroupCard(item.outbound, item.returnLeg);
          }
          return _buildTripCard(item as Map<String, dynamic>);
        },
      ),
    );
  }

  Map<String, dynamic>? _findMatchingTrip(
    List<Map<String, dynamic>> trips,
    bool Function(Map<String, dynamic>) test,
  ) {
    for (final t in trips) {
      if (test(t)) return t;
    }
    return null;
  }

  List<dynamic> _groupTrips(List<Map<String, dynamic>> rawTrips) {
    final List<dynamic> result = [];
    final Set<String> processedIds = {};

    for (final trip in rawTrips) {
      final String id = (trip['id'] ?? trip['_id'] ?? trip['bookingId'] ?? '').toString();
      if (id.isEmpty || processedIds.contains(id)) continue;

      final String tripType = (trip['tripType'] ?? '').toString().toUpperCase();
      final String tripLeg = (trip['tripLeg'] ?? '').toString().toUpperCase();
      final String? returnBookingId = trip['returnBookingId']?.toString();
      final String? parentBookingId = trip['parentBookingId']?.toString();

      final bool isReturnRelated = tripType == 'RETURN' ||
          (returnBookingId != null && returnBookingId.isNotEmpty) ||
          (parentBookingId != null && parentBookingId.isNotEmpty) ||
          tripLeg == 'OUTBOUND' ||
          tripLeg == 'RETURN';

      if (isReturnRelated) {
        if (tripLeg == 'OUTBOUND' || (returnBookingId != null && returnBookingId.isNotEmpty)) {
          processedIds.add(id);
          Map<String, dynamic>? linkedReturn;
          final targetReturnId = returnBookingId ?? '';
          if (targetReturnId.isNotEmpty) {
            linkedReturn = _findMatchingTrip(rawTrips, (t) {
              final tId = (t['id'] ?? t['_id'] ?? t['bookingId'] ?? '').toString();
              final tParentId = (t['parentBookingId'] ?? '').toString();
              return (tId == targetReturnId || tParentId == id) && !processedIds.contains(tId);
            });
            if (linkedReturn != null) {
              final rId = (linkedReturn['id'] ?? linkedReturn['_id'] ?? linkedReturn['bookingId'] ?? '').toString();
              if (rId.isNotEmpty) processedIds.add(rId);
            }
          }
          result.add(_TripGroupItem(outbound: trip, returnLeg: linkedReturn));
        } else if (tripLeg == 'RETURN' || (parentBookingId != null && parentBookingId.isNotEmpty)) {
          processedIds.add(id);
          Map<String, dynamic>? linkedOutbound;
          final targetParentId = parentBookingId ?? '';
          if (targetParentId.isNotEmpty) {
            linkedOutbound = _findMatchingTrip(rawTrips, (t) {
              final tId = (t['id'] ?? t['_id'] ?? t['bookingId'] ?? '').toString();
              final tReturnId = (t['returnBookingId'] ?? '').toString();
              return (tId == targetParentId || tReturnId == id) && !processedIds.contains(tId);
            });
            if (linkedOutbound != null) {
              final oId = (linkedOutbound['id'] ?? linkedOutbound['_id'] ?? linkedOutbound['bookingId'] ?? '').toString();
              if (oId.isNotEmpty) processedIds.add(oId);
              result.add(_TripGroupItem(outbound: linkedOutbound, returnLeg: trip));
            } else {
              result.add(_TripGroupItem(outbound: trip, returnLeg: null));
            }
          } else {
            result.add(_TripGroupItem(outbound: trip, returnLeg: null));
          }
        } else {
          processedIds.add(id);
          result.add(_TripGroupItem(outbound: trip, returnLeg: null));
        }
      } else {
        processedIds.add(id);
        result.add(trip);
      }
    }

    return result;
  }

  Widget _buildStatusBadge(String status) {
    final isCancelled = status == 'CANCELLED';
    final isCompleted = status == 'COMPLETED';
    final statusColor = isCancelled
        ? const Color(0xFFDC2626)
        : isCompleted
            ? const Color(0xFF16A34A)
            : const Color(0xFFD97706);

    final statusBg = isCancelled
        ? const Color(0xFFFFEBEE)
        : isCompleted
            ? const Color(0xFFF1FBF4)
            : const Color(0xFFFFF9E6);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: AppFonts.fontFamily,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildReturnTripGroupCard(
    Map<String, dynamic> outbound,
    Map<String, dynamic>? returnLeg,
  ) {
    final outboundModel = BookingModel.fromMap(outbound);
    final returnModel = returnLeg != null ? BookingModel.fromMap(returnLeg) : null;

    final String outboundStatus = outboundModel.status;
    final String returnStatus = returnModel?.status ?? 'SCHEDULED';

    final double outboundFare = outboundModel.fare?.outbound ?? outboundModel.estimatedFare ?? 0.0;
    final double returnFare = outboundModel.fare?.returnFare ?? returnModel?.estimatedFare ?? outboundFare;
    final double totalFare = outboundModel.fare?.total ?? (outboundFare + returnFare);

    final String outboundDateStr = _formatTripDate(
      outbound['completedAt'] ?? outbound['startedAt'] ?? outbound['createdAt'],
    );
    final String returnDateStr = outboundModel.returnDateTime != null
        ? _formatTripDate(outboundModel.returnDateTime!.toIso8601String())
        : (returnModel?.scheduledAt != null
            ? _formatTripDate(returnModel!.scheduledAt!.toIso8601String())
            : 'Scheduled');

    final bool isOutboundActive = outboundStatus != 'COMPLETED' &&
        outboundStatus != 'CANCELLED' &&
        outboundStatus != 'FINISHED';

    final bool isReturnActive = returnStatus != 'COMPLETED' &&
        returnStatus != 'CANCELLED' &&
        returnStatus != 'FINISHED';

    final String outboundPickup = AppUtils.parseString(outboundModel.pickup?['address']) ?? 'Pickup';
    final String outboundDrop = AppUtils.parseString(outboundModel.drop?['address']) ?? 'Destination';

    final String returnPickup = returnModel != null
        ? (AppUtils.parseString(returnModel.pickup?['address']) ?? outboundDrop)
        : outboundDrop;
    final String returnDrop = returnModel != null
        ? (AppUtils.parseString(returnModel.drop?['address']) ?? outboundPickup)
        : outboundPickup;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF4B41A).withOpacity(0.5), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF4B41A).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFF4B41A)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_alt_rounded,
                      size: 14.sp,
                      color: const Color(0xFFD97706),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'RETURN TRIP',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Fare',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 10.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    '₹${totalFare.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 10.h),

          // Outbound Leg Card Component
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OUTBOUND LEG',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    _buildStatusBadge(outboundStatus),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.trip_origin, size: 12.sp, color: Colors.green),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        '$outboundPickup → $outboundDrop',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'Time: $outboundDateStr | Fare: ₹${outboundFare.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 10.5.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // Return Leg Card Component
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFF4B41A).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RETURN LEG',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    _buildStatusBadge(returnStatus),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12.sp, color: Colors.orange),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        '$returnPickup → $returnDrop',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'Scheduled Return: $returnDateStr | Fare: ₹${returnFare.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 10.5.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isOutboundActive)
                ElevatedButton.icon(
                  onPressed: () async {
                    final res = await CancellationReasonDrawer.show(
                      context,
                      tripId: outboundModel.id,
                      returnBookingId: outboundModel.returnBookingId ?? returnModel?.id,
                    );
                    if (res == true && mounted) {
                      _loadTrips(reset: true);
                    }
                  },
                  icon: Icon(Icons.cancel_outlined, size: 14.sp, color: Colors.red),
                  label: Text(
                    'Cancel Entire Return Trip',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                )
              else if (isReturnActive && returnModel != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    final res = await CancellationReasonDrawer.show(
                      context,
                      tripId: outboundModel.id,
                      returnBookingId: returnModel.id,
                      isReturnLegOnly: true,
                    );
                    if (res == true && mounted) {
                      _loadTrips(reset: true);
                    }
                  },
                  icon: Icon(Icons.cancel_outlined, size: 14.sp, color: Colors.red),
                  label: Text(
                    'Cancel Return Leg Only',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final status = (AppUtils.parseString(trip['status']) ??
            AppUtils.parseString(trip['bookingStatus']) ??
            'COMPLETED')
        .toUpperCase();
    final pickupMap = trip['pickup'] is Map ? trip['pickup'] as Map : null;
    final pickup = AppUtils.parseString(pickupMap?['address']) ??
        AppUtils.parseString(trip['pickupAddress']) ??
        'Pickup location';
    final dropMap = trip['drop'] is Map ? trip['drop'] as Map : null;
    final drop = AppUtils.parseString(dropMap?['address']) ??
        AppUtils.parseString(trip['dropAddress']) ??
        'Drop location';

    final driver = trip['driver'] is Map ? trip['driver'] as Map : null;
    final driverName = AppUtils.parseString(driver?['name']) ??
        AppUtils.parseString(driver?['user']?['displayName']) ??
        'Assigned Driver';
    final driverPhone = AppUtils.parseString(driver?['phone']); // Masked phone e.g. +91******1234
    final driverRating = AppUtils.parseDouble(driver?['rating'] ?? driver?['averageRating']) ?? 4.8;

    final vehicle = trip['vehicle'] is Map ? trip['vehicle'] as Map : null;
    final vehicleMake = AppUtils.parseString(vehicle?['make']) ?? '';
    final vehicleModel = AppUtils.parseString(vehicle?['model']) ?? '';
    final vehicleNumber = AppUtils.parseString(vehicle?['registrationNo']) ??
        AppUtils.parseString(vehicle?['number']) ??
        '';

    final vehicleCatMap = trip['vehicleCategory'] is Map ? trip['vehicleCategory'] as Map : null;
    final vehicleCatName = AppUtils.parseString(vehicleCatMap?['name']) ??
        AppUtils.parseString(vehicle?['category']);

    final vehicleTitle = '$vehicleMake $vehicleModel'.trim().isNotEmpty
        ? '$vehicleMake $vehicleModel'
        : (vehicleCatName != null && vehicleCatName.isNotEmpty
            ? vehicleCatName
            : 'Sawariya Vehicle');

    final fareVal = AppUtils.parseDouble(
      trip['fare'] ?? trip['totalFare'] ?? trip['amount'],
    );
    final fareStr = fareVal != null && !fareVal.isNaN && !fareVal.isInfinite
        ? '₹${fareVal.toStringAsFixed(2)}'
        : '₹0.00';

    final dateStr = _formatTripDate(
      trip['completedAt'] ?? trip['startedAt'] ?? trip['acceptedAt'] ?? trip['createdAt'],
    );


    final isCancelled = status == 'CANCELLED';
    final isCompleted = status == 'COMPLETED';
    final statusColor = isCancelled
        ? const Color(0xFFDC2626)
        : isCompleted
            ? const Color(0xFF16A34A)
            : const Color(0xFFD97706);

    final statusBg = isCancelled
        ? const Color(0xFFFFEBEE)
        : isCompleted
            ? const Color(0xFFF1FBF4)
            : const Color(0xFFFFF9E6);

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
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Vehicle / Category + Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFC000)),
                    ),
                    child: Icon(
                      Icons.directions_car_filled_rounded,
                      color: Colors.black,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleTitle,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (vehicleNumber.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          vehicleNumber,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 11.sp,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 12.h),

          // Pickup & Drop Locations
          Row(
            children: [
              const RouteMarkerTimeline(connectorHeight: 30),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        color: const Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      drop,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 10.h),

          // Bottom Info Row: Driver Name / Phone + Date + Fare
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 14.sp, color: Colors.grey.shade600),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            driverName,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.star_rounded, size: 14.sp, color: const Color(0xFFFFC000)),
                        Text(
                          driverRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (driverPhone != null && driverPhone.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        driverPhone, // Masked as-is
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    SizedBox(height: 2.h),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Fare',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 10.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    fareStr,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showBookRideButton = false,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56.sp, color: const Color(0xFF9CA3AF)),
            SizedBox(height: 14.h),
            Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 12.sp,
                color: const Color(0xFF6B7280),
              ),
            ),
            if (showBookRideButton) ...[
              SizedBox(height: 20.h),
              SizedBox(
                height: 44.h,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LocationSearchScreen(),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 18.sp,
                    color: Colors.black,
                  ),
                  label: Text(
                    'Book a Ride',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4B41A),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripGroupItem {
  final Map<String, dynamic> outbound;
  final Map<String, dynamic>? returnLeg;

  _TripGroupItem({required this.outbound, this.returnLeg});
}
