import '../../models/vehicle_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../constants/app_assets.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../support/raise_issue_screen.dart';
import '../../widgets/location_route_markers.dart';

class RideInvoiceScreen extends StatefulWidget {
  final String? bookingId;
  final Map<String, dynamic>? initialBookingData;

  const RideInvoiceScreen({
    super.key,
    this.bookingId,
    this.initialBookingData,
  });

  @override
  State<RideInvoiceScreen> createState() => _RideInvoiceScreenState();
}

class _RideInvoiceScreenState extends State<RideInvoiceScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _invoiceData;

  dynamic _extractPath(dynamic data, List<dynamic> keys) {
    dynamic current = data;
    for (final key in keys) {
      if (current == null) return null;
      if (current is Map) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  String? _getSafeString(List<dynamic> candidates) {
    for (final item in candidates) {
      if (item != null) {
        final s = item.toString().trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
    }
    return null;
  }

  Map<String, dynamic> _getSafeMap(List<dynamic> candidates) {
    for (final item in candidates) {
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
    }
    return {};
  }

  double _parsePrice(dynamic val) {
    if (val is num) return val.toDouble();
    if (val != null) {
      final p = double.tryParse(val.toString().replaceAll(RegExp(r'[^\d.]'), ''));
      if (p != null) return p;
    }
    return 0.0;
  }

  Map<String, dynamic> get _driver {
    final value = _getSafeMap([
      _extractPath(_bookingData, ['assignedDriver']),
      _extractPath(_bookingData, ['driver']),
      _extractPath(_bookingData, ['driverDetails']),
      _extractPath(_bookingData, ['driverData', 'driver']),
      _extractPath(_bookingData, ['driverData']),
      _extractPath(_bookingData, ['acceptedDriver']),
      _extractPath(widget.initialBookingData, ['assignedDriver']),
      _extractPath(widget.initialBookingData, ['driver']),
    ]);
    return value;
  }

  Map<String, dynamic> get _vehicle {
    final value = _getSafeMap([
      _extractPath(_bookingData, ['assignedVehicle']),
      _extractPath(_driver, ['assignedVehicle']),
      _extractPath(_driver, ['vehicle']),
      _driver['vehicles'] is List && (_driver['vehicles'] as List).isNotEmpty
          ? _driver['vehicles'][0]
          : null,
      _extractPath(_driver, ['driverProfile', 'vehicles']) is List &&
              (_extractPath(_driver, ['driverProfile', 'vehicles']) as List).isNotEmpty
          ? _driver['driverProfile']['vehicles'][0]
          : null,
      _extractPath(_bookingData, ['vehicle']),
      _extractPath(_bookingData, ['driverData', 'vehicle']),
      _extractPath(widget.initialBookingData, ['assignedVehicle']),
      _extractPath(widget.initialBookingData, ['vehicle']),
    ]);
    return value;
  }

  String _getPickupAddress() {
    final addr = _getSafeString([
      _extractPath(_bookingData, ['pickupAddress']),
      _extractPath(_bookingData, ['pickup', 'address']),
      _extractPath(_bookingData, ['pickupLocation', 'address']),
      _extractPath(_bookingData, ['pickupLocation']),
      _extractPath(_bookingData, ['pickup']),
      _extractPath(_bookingData, ['pickup_address']),
      _extractPath(_bookingData, ['startAddress']),
      _extractPath(_bookingData, ['pickupName']),
      _extractPath(_bookingData, ['booking', 'pickupAddress']),
      _extractPath(_bookingData, ['booking', 'pickup', 'address']),
      _extractPath(widget.initialBookingData, ['pickupAddress']),
      _extractPath(widget.initialBookingData, ['pickup', 'address']),
      _extractPath(widget.initialBookingData, ['pickupLocation', 'address']),
      _extractPath(widget.initialBookingData, ['pickupLocation']),
      _extractPath(widget.initialBookingData, ['pickup']),
    ]);
    return addr ?? 'Pickup Location';
  }

  String _getDropAddress() {
    final addr = _getSafeString([
      _extractPath(_bookingData, ['dropAddress']),
      _extractPath(_bookingData, ['drop', 'address']),
      _extractPath(_bookingData, ['destination', 'address']),
      _extractPath(_bookingData, ['dropLocation', 'address']),
      _extractPath(_bookingData, ['dropLocation']),
      _extractPath(_bookingData, ['drop']),
      _extractPath(_bookingData, ['drop_address']),
      _extractPath(_bookingData, ['dropoffAddress']),
      _extractPath(_bookingData, ['destinationAddress']),
      _extractPath(_bookingData, ['destination']),
      _extractPath(_bookingData, ['booking', 'dropAddress']),
      _extractPath(_bookingData, ['booking', 'drop', 'address']),
      _extractPath(widget.initialBookingData, ['dropAddress']),
      _extractPath(widget.initialBookingData, ['drop', 'address']),
      _extractPath(widget.initialBookingData, ['destination', 'address']),
      _extractPath(widget.initialBookingData, ['dropLocation']),
      _extractPath(widget.initialBookingData, ['drop']),
    ]);
    return addr ?? 'Drop Location';
  }

  String _getDriverName() {
    final name = _getSafeString([
      _extractPath(_driver, ['user', 'displayName']),
      _extractPath(_driver, ['user', 'name']),
      _extractPath(_driver, ['user', 'fullName']),
      _extractPath(_driver, ['displayName']),
      _extractPath(_driver, ['name']),
      _extractPath(_driver, ['fullName']),
      _extractPath(_driver, ['firstName']) != null
          ? '${_extractPath(_driver, ['firstName'])} ${_extractPath(_driver, ['lastName']) ?? ''}'.trim()
          : null,
      _extractPath(_driver, ['driverName']),
      _extractPath(_driver, ['driverProfile', 'name']),
      _extractPath(_bookingData, ['driverName']),
      _extractPath(_bookingData, ['driver', 'user', 'displayName']),
      _extractPath(_bookingData, ['driver', 'name']),
      _extractPath(_bookingData, ['driver', 'fullName']),
      _extractPath(_bookingData, ['driverData', 'driver', 'name']),
      _extractPath(_bookingData, ['driverData', 'name']),
      _extractPath(_bookingData, ['acceptedDriver', 'name']),
      _extractPath(widget.initialBookingData, ['driverName']),
      _extractPath(widget.initialBookingData, ['driver', 'name']),
      _extractPath(widget.initialBookingData, ['driver', 'user', 'displayName']),
    ]);
    return name ?? 'Driver';
  }

  String? _getDriverProfileImage() {
    final img = _getSafeString([
      _extractPath(_driver, ['profileImageUrl']),
      _extractPath(_driver, ['profileImage']),
      _extractPath(_driver, ['image']),
      _extractPath(_driver, ['avatar']),
      _extractPath(_driver, ['photo']),
      _extractPath(_driver, ['profilePic']),
      _extractPath(_driver, ['user', 'profileImageUrl']),
      _extractPath(_driver, ['user', 'profileImage']),
      _extractPath(_driver, ['user', 'image']),
      _extractPath(_driver, ['user', 'avatar']),
      _extractPath(_driver, ['driverProfile', 'profileImage']),
      _extractPath(_bookingData, ['driverProfileImage']),
      _extractPath(_bookingData, ['driverImage']),
      _extractPath(_bookingData, ['driver', 'profileImageUrl']),
      _extractPath(_bookingData, ['driver', 'profileImage']),
      _extractPath(_bookingData, ['driver', 'avatar']),
      _extractPath(_bookingData, ['driverData', 'profileImage']),
      _extractPath(widget.initialBookingData, ['driverProfileImage']),
      _extractPath(widget.initialBookingData, ['driverImage']),
      _extractPath(widget.initialBookingData, ['driver', 'profileImageUrl']),
    ]);
    return img;
  }

  String _getDriverRating() {
    final r = _getSafeString([
      _extractPath(_driver, ['averageRating']),
      _extractPath(_driver, ['rating']),
      _extractPath(_driver, ['avgRating']),
      _extractPath(_driver, ['driverProfile', 'rating']),
      _extractPath(_bookingData, ['driverRating']),
    ]);
    if (r != null) {
      final numVal = num.tryParse(r);
      if (numVal != null) return numVal.toStringAsFixed(1);
    }
    return '5.0';
  }

  String _getDriverTrips() {
    final t = _getSafeString([
      _extractPath(_driver, ['totalTrips']),
      _extractPath(_driver, ['trips']),
      _extractPath(_driver, ['completedTrips']),
      _extractPath(_driver, ['driverProfile', 'totalTrips']),
      _extractPath(_bookingData, ['driverTrips']),
    ]);
    return t ?? '0';
  }

  String _getVehicleCategoryName() {
    final catObj = _extractPath(_bookingData, ['vehicleCategory']) ??
        _extractPath(widget.initialBookingData, ['vehicleCategory']);
    String? rawCat;
    if (catObj is Map) {
      rawCat = catObj['displayName']?.toString() ?? catObj['name']?.toString();
    } else if (catObj != null) {
      rawCat = catObj.toString();
    }
    rawCat ??= _getSafeString([
      _extractPath(_vehicle, ['type']),
      _extractPath(_vehicle, ['category']),
      _extractPath(_vehicle, ['vehicleType']),
      _extractPath(_bookingData, ['category']),
      _extractPath(_bookingData, ['vehicleType']),
      _extractPath(_bookingData, ['carType']),
      _extractPath(_bookingData, ['serviceType']),
    ]);

    final categoryEnum = VehicleCategory.fromString(rawCat);
    if (categoryEnum != null) {
      return categoryEnum.displayName;
    }
    final clean = rawCat?.toUpperCase() ?? '';
    if (clean.contains('TRUCK') || clean.contains('GOODS') || clean.contains('TEMPO') || clean.contains('LOAD')) {
      return 'Truck';
    }
    if (clean.contains('BIKE') || clean.contains('MOTO') || clean.contains('2_WHEELER')) {
      return 'Bike';
    }
    if (clean.contains('AUTO') || clean.contains('RICKSHAW') || clean.contains('3_WHEELER') || clean.contains('TUKTUK')) {
      return 'Auto';
    }
    if (clean.contains('SEDAN')) {
      return 'Sedan';
    }
    if (clean.contains('SUV')) {
      return 'SUV';
    }
    if (rawCat != null && rawCat.isNotEmpty) {
      return rawCat;
    }
    return 'Vehicle';
  }

  String _getVehicleModelName() {
    final make = _getSafeString([_extractPath(_vehicle, ['make'])]);
    final model = _getSafeString([
      _extractPath(_vehicle, ['model']),
      _extractPath(_vehicle, ['vehicleModel']),
      _extractPath(_vehicle, ['vehicleName']),
      _extractPath(_vehicle, ['name']),
      _extractPath(_bookingData, ['vehicleModel']),
      _extractPath(_bookingData, ['vehicleName']),
    ]);

    if (make != null && make.isNotEmpty && model != null && model.isNotEmpty && !model.toLowerCase().contains(make.toLowerCase())) {
      return '$make $model';
    }
    if (model != null && model.isNotEmpty) {
      return model;
    }
    if (make != null && make.isNotEmpty) {
      return make;
    }
    return _getVehicleCategoryName();
  }

  String _getVehicleAssetPath() {
    final rawType = _getSafeString([
      _extractPath(_bookingData, ['vehicleCategory', 'name']),
      _extractPath(_bookingData, ['vehicleCategory', 'displayName']),
      _extractPath(_bookingData, ['vehicleCategory']),
      _extractPath(_bookingData, ['vehicle', 'vehicleType']),
      _extractPath(_bookingData, ['vehicle', 'category']),
      _extractPath(_bookingData, ['vehicle', 'type']),
      _extractPath(_bookingData, ['vehicleType']),
      _extractPath(_bookingData, ['category']),
      _extractPath(_bookingData, ['serviceType']),
      _extractPath(_bookingData, ['carType']),
      _extractPath(_vehicle, ['vehicleType']),
      _extractPath(_vehicle, ['type']),
      _extractPath(_vehicle, ['category']),
    ]);

    final category = VehicleCategory.fromString(rawType);
    if (category != null) {
      return category.assetPath;
    }

    final clean = rawType?.toUpperCase() ?? '';
    if (clean.contains('BIKE') || clean.contains('MOTO') || clean.contains('2_WHEELER')) {
      return 'assets/images/Bike1.png';
    }
    if (clean.contains('AUTO') || clean.contains('RICKSHAW') || clean.contains('3_WHEELER') || clean.contains('TUKTUK')) {
      return 'assets/images/rickshawnew.png';
    }
    if (clean.contains('TRUCK') || clean.contains('GOODS') || clean.contains('TEMPO') || clean.contains('LOAD')) {
      return 'assets/images/truck.png';
    }
    if (clean.contains('HATCHBACK') || clean.contains('SEDAN') || clean.contains('CAB') || clean.contains('CAR')) {
      return 'assets/images/ridenew.png';
    }
    if (clean.contains('SUV')) {
      return 'assets/images/suvnew.png';
    }

    return AppAssets.carImage;
  }

  String get _vehicleNumber =>
      (_getSafeString([
            _extractPath(_vehicle, ['registrationNumber']),
            _extractPath(_vehicle, ['vehicleNumber']),
            _extractPath(_vehicle, ['plateNumber']),
            _extractPath(_vehicle, ['registrationNo']),
            _extractPath(_driver, ['vehicleNumber']),
            _extractPath(_driver, ['registrationNumber']),
            _extractPath(_bookingData, ['vehicleNumber']),
            _extractPath(_bookingData, ['registrationNumber']),
            _extractPath(_bookingData, ['assignedVehicle', 'registrationNumber']),
          ]) ??
          '—');

  @override
  void initState() {
    super.initState();
    if (widget.initialBookingData != null && widget.initialBookingData!.isNotEmpty) {
      _bookingData = Map<String, dynamic>.from(widget.initialBookingData!);
      _invoiceData = _getSafeMap([
        _extractPath(_bookingData, ['payment', 'invoice']),
        _extractPath(_bookingData, ['invoice']),
        _extractPath(_bookingData, ['trip', 'invoice']),
      ]);
      _isLoading = false;
    }
    _fetchInvoice();
  }

  Future<void> _fetchInvoice() async {
    final bId = widget.bookingId ??
        _getSafeString([
          _extractPath(_bookingData, ['id']),
          _extractPath(_bookingData, ['_id']),
          _extractPath(_bookingData, ['bookingId']),
        ]);

    if (bId == null || bId.isEmpty) {
      if (_bookingData != null && _bookingData!.isNotEmpty) {
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'No booking ID provided';
        });
      }
      return;
    }

    try {
      final response = await ApiService.to.get(
        ApiEndpoints.bookingDetails(bId),
      );
      if (response.isSuccess) {
        final rawData = response.data;
        final fetchedMap = rawData['data'] is Map
            ? Map<String, dynamic>.from(rawData['data'])
            : (rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{});

        final bookingObj = fetchedMap['booking'] is Map
            ? Map<String, dynamic>.from(fetchedMap['booking'] as Map)
            : <String, dynamic>{};

        setState(() {
          _bookingData = {
            ...?widget.initialBookingData,
            ...fetchedMap,
            ...bookingObj,
            if (_extractPath(fetchedMap, ['assignedDriver']) == null &&
                _extractPath(bookingObj, ['assignedDriver']) == null &&
                _extractPath(widget.initialBookingData, ['assignedDriver']) != null)
              'assignedDriver': widget.initialBookingData!['assignedDriver'],
            if (_extractPath(fetchedMap, ['driver']) == null &&
                _extractPath(bookingObj, ['driver']) == null &&
                _extractPath(widget.initialBookingData, ['driver']) != null)
              'driver': widget.initialBookingData!['driver'],
          };
          _invoiceData = _getSafeMap([
            _extractPath(_bookingData, ['payment', 'invoice']),
            _extractPath(_bookingData, ['invoice']),
            _extractPath(_bookingData, ['trip', 'invoice']),
          ]);
          _isLoading = false;
          _error = null;
        });
      } else {
        if (_bookingData != null && _bookingData!.isNotEmpty) {
          setState(() => _isLoading = false);
        } else {
          setState(() {
            _error = response.message.isNotEmpty
                ? response.message
                : 'Failed to fetch ride details';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (_bookingData != null && _bookingData!.isNotEmpty) {
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getFormattedTime(dynamic rawTime, {bool isDrop = false}) {
    final str = rawTime?.toString().trim() ?? '';
    if (str.isNotEmpty && str != '--:--') {
      try {
        final dt = DateTime.tryParse(str);
        if (dt != null) {
          return DateFormat('hh:mm a').format(dt.toLocal());
        }
        return str;
      } catch (_) {
        return str;
      }
    }
    final fallbackDate = isDrop
        ? (_bookingData?['completedAt'] ??
              _bookingData?['trip']?['completedAt'] ??
              _bookingData?['updatedAt'] ??
              _bookingData?['dropTime'])
        : (_bookingData?['startedAt'] ??
              _bookingData?['trip']?['startedAt'] ??
              _bookingData?['createdAt'] ??
              _bookingData?['pickedUpAt'] ??
              _bookingData?['pickupTime']);
    final fallbackStr = fallbackDate?.toString().trim() ?? '';
    if (fallbackStr.isNotEmpty && fallbackStr != '--:--') {
      try {
        final dt = DateTime.tryParse(fallbackStr);
        if (dt != null) {
          return DateFormat('hh:mm a').format(dt.toLocal());
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    final dt = isDrop ? now : now.subtract(const Duration(minutes: 15));
    return DateFormat('hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _bookingData != null && _bookingData!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading && !hasData
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00ABE4)),
                  )
                : _error != null && !hasData
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCompletedStatusBanner(),
                            SizedBox(height: 20.h),
                            _buildTripDetailsCard(),
                            SizedBox(height: 16.h),
                            _buildStatsRow(),
                            SizedBox(height: 20.h),
                            _buildDriverVehicleDetailsCard(),
                            SizedBox(height: 20.h),
                            _buildFareBreakdownCard(),
                            SizedBox(height: 20.h),
                            _buildPaymentDetailsCard(),
                            SizedBox(height: 20.h),
                            _buildSystemGeneratedNotice(),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
          ),
          _buildBottomActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final invoiceNumber = _invoiceData?['invoiceNumber'] ??
        _bookingData?['invoiceNumber'] ??
        _bookingData?['trip']?['invoice']?['invoiceNumber'] ??
        'INV-${(_bookingData?['id']?.toString() ?? 'XXXXXX').take(6).toUpperCase()}';

    return Container(
      color: const Color(0xFFE6F7FD),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16.h,
        bottom: 16.h,
        left: 20.w,
        right: 20.w,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ride Invoice',
                  style: AppFonts.h2.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Invoice ID: $invoiceNumber',
                  style: AppFonts.captionDark.copyWith(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedStatusBanner() {
    final completedAtStr = _getSafeString([
      _extractPath(_bookingData, ['completedAt']),
      _extractPath(_bookingData, ['trip', 'completedAt']),
      _extractPath(_bookingData, ['updatedAt']),
    ]);

    String formattedDate;
    if (completedAtStr != null && completedAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(completedAtStr).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      }
    } else {
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    }

    return Container(
      constraints: BoxConstraints(minHeight: 54.h),
      padding: EdgeInsets.symmetric(
        horizontal: 10.w,
        vertical: 8.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: const Color(0xFF14A03F).withOpacity(0.25),
          width: 1.w,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: const BoxDecoration(
              color: Color(0xFF14A03F),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: Colors.white, size: 14.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ride Completed',
                  style: AppFonts.bodyText.copyWith(
                    color: const Color(0xFF14A03F),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5.sp,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Thanks for riding with us',
                  style: AppFonts.captionDark.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 10.5.sp,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formattedDate,
            style: AppFonts.captionDark.copyWith(
              color: Colors.grey.shade500,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsCard() {
    final rideIdStr = _getSafeString([
          _extractPath(_bookingData, ['id']),
          _extractPath(_bookingData, ['_id']),
          _extractPath(_bookingData, ['bookingId']),
          widget.bookingId,
        ]) ??
        '';

    final formattedRideId = rideIdStr.length >= 8
        ? rideIdStr.substring(0, 8).toUpperCase()
        : (rideIdStr.isNotEmpty ? rideIdStr.toUpperCase() : 'LRXXXXXX');

    return Container(
      constraints: BoxConstraints(minHeight: 180.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: const Color(0xFF00ABE4).withOpacity(0.25),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trip Details',
                style: AppFonts.bodyText.copyWith(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                ),
              ),
              Text(
                'Ride ID: $formattedRideId',
                style: AppFonts.captionDark.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20.w,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 12.h),
                          RouteMarkerTimeline(connectorHeight: 45.h),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAddressCard(
                            title: 'Pick-up Location',
                            address: _getPickupAddress(),
                            time: _getFormattedTime(
                              _extractPath(_bookingData, ['pickedUpAt']) ?? _extractPath(_bookingData, ['trip', 'startedAt']),
                              isDrop: false,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          _buildAddressCard(
                            title: 'Your Destination',
                            address: _getDropAddress(),
                            time: _getFormattedTime(
                              _extractPath(_bookingData, ['completedAt']) ?? _extractPath(_bookingData, ['trip', 'completedAt']),
                              isDrop: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 8,
                child: Container(
                  height: 140.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6FC),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFF00ABE4).withOpacity(0.2),
                      width: 1.w,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: MockMapPainter()),
                        ),
                        Positioned(
                          bottom: 20.h,
                          left: 15.w,
                          child: Container(
                            width: 18.w,
                            height: 18.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00ABE4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.near_me_rounded,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 20.h,
                          right: 20.w,
                          child: Icon(
                            Icons.location_on_rounded,
                            color: const Color(0xFF00ABE4),
                            size: 20.sp,
                          ),
                        ),
                        Positioned(
                          top: 55.h,
                          right: 32.w,
                          child: Transform.rotate(
                            angle: -0.6,
                            child: Image.asset(
                              _getVehicleAssetPath(),
                              width: 28.w,
                              height: 16.h,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildAddressCard({
    required String title,
    required String address,
    required String time,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: const Color(0xFF00ABE4).withOpacity(0.18),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppFonts.captionDark.copyWith(
              color: Colors.grey.shade500,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.bodyText.copyWith(
              color: const Color(0xFF1A1A1A),
              fontSize: 10.5.sp,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            time,
            style: AppFonts.captionDark.copyWith(
              color: Colors.grey.shade500,
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final distanceMeters = _parsePrice(
      _getSafeString([
        _extractPath(_bookingData, ['actualDistanceMeters']),
        _extractPath(_bookingData, ['trip', 'actualDistanceMeters']),
        _extractPath(_bookingData, ['distanceMeters']),
        _extractPath(_bookingData, ['tripDistance']),
        _extractPath(_bookingData, ['distance']),
        _extractPath(_bookingData, ['estimatedDistance']),
      ]),
    );
    final durationSeconds = _parsePrice(
      _getSafeString([
        _extractPath(_bookingData, ['actualDurationSeconds']),
        _extractPath(_bookingData, ['trip', 'actualDurationSeconds']),
        _extractPath(_bookingData, ['durationSeconds']),
        _extractPath(_bookingData, ['tripDuration']),
        _extractPath(_bookingData, ['duration']),
        _extractPath(_bookingData, ['estimatedDuration']),
      ]),
    );

    String distStr;
    if (distanceMeters > 0) {
      if (distanceMeters >= 100) {
        distStr = '${(distanceMeters / 1000).toStringAsFixed(1)} km';
      } else {
        distStr = '${distanceMeters.toStringAsFixed(1)} km';
      }
    } else {
      distStr = '—';
    }

    String durStr;
    if (durationSeconds > 0) {
      if (durationSeconds >= 60) {
        durStr = '${(durationSeconds / 60).round()} min';
      } else {
        durStr = '${durationSeconds.round()} sec';
      }
    } else {
      durStr = '—';
    }

    return Container(
      constraints: BoxConstraints(minHeight: 56.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FDFF),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(
          color: const Color(0xFF00ABE4).withOpacity(0.25),
          width: 1.w,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildStatItemInline(
              icon: Icons.access_time_filled_rounded,
              iconColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFFE0F2FE),
              label: 'Duration',
              value: durStr,
            ),
          ),
          Expanded(
            child: _buildStatItemInline(
              icon: Icons.route_rounded,
              iconColor: const Color(0xFF16A34A),
              bgColor: const Color(0xFFDCFCE7),
              label: 'Distance',
              value: distStr,
            ),
          ),
          Expanded(
            child: _buildStatItemInline(
              icon: Icons.more_time_rounded,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF3E8FF),
              label: 'Time',
              value: _getFormattedTime(
                _extractPath(_bookingData, ['completedAt']) ?? _extractPath(_bookingData, ['trip', 'completedAt']),
                isDrop: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItemInline({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 12.sp),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.captionDark.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.bodyText.copyWith(
                  color: const Color(0xFF212529),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverVehicleDetailsCard() {
    final driverName = _getDriverName();
    final driverImg = _getDriverProfileImage();
    final categoryName = _getVehicleCategoryName();
    final modelName = _getVehicleModelName();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 10.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: const Color(0xFF00ABE4).withOpacity(0.25),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Driver & Vehicle Details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.bodyText.copyWith(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w800,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF00ABE4).withOpacity(0.10),
                      const Color(0xFF00ABE4).withOpacity(0.00),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6.65.r),
                  border: Border.all(
                    color: const Color(0xFF00ABE4).withOpacity(0.20),
                    width: 0.46.w,
                  ),
                ),
                child: Center(
                  child: ClipOval(
                    child: Builder(
                      builder: (context) {
                        if (driverImg != null &&
                            driverImg.isNotEmpty &&
                            driverImg.startsWith('http')) {
                          return Image.network(
                            driverImg,
                            width: 40.w,
                            height: 40.h,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Image.asset(
                              AppAssets.profileImage,
                              width: 40.w,
                              height: 40.h,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return Image.asset(
                          AppAssets.profileImage,
                          width: 40.w,
                          height: 40.h,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.bodyText.copyWith(
                              color: const Color(0xFF1A1A1A),
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: const Color(0xFFFEF3C7),
                              width: 0.8.w,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: const Color(0xFFF59E0B),
                                size: 10.sp,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                _getDriverRating(),
                                style: AppFonts.bodyText.copyWith(
                                  color: const Color(0xFFB45309),
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      '${_getDriverTrips()} Trips',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.captionDark.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_vehicleNumber.isNotEmpty && _vehicleNumber != '—') ...[
                      SizedBox(height: 1.h),
                      Text(
                        _vehicleNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodyText.copyWith(
                          color: const Color(0xFF1A1A1A),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 1.h),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: modelName,
                            style: AppFonts.captionDark.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (categoryName.isNotEmpty && categoryName != modelName) ...[
                            TextSpan(
                              text: ' • $categoryName',
                              style: AppFonts.captionDark.copyWith(
                                color: const Color(0xFF00ABE4),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Builder(
                builder: (context) {
                  final vehicleImg = _getSafeString([
                    _extractPath(_bookingData, ['vehicle', 'image']),
                    _extractPath(_bookingData, ['vehicle', 'vehicleImage']),
                    _extractPath(_vehicle, ['image']),
                    _extractPath(_vehicle, ['vehicleImage']),
                  ]);

                  if (vehicleImg != null &&
                      vehicleImg.isNotEmpty &&
                      vehicleImg.startsWith('http')) {
                    return Image.network(
                      vehicleImg,
                      width: 65.w,
                      height: 55.h,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Image.asset(
                        _getVehicleAssetPath(),
                        width: 65.w,
                        height: 55.h,
                        fit: BoxFit.contain,
                      ),
                    );
                  }
                  return Image.asset(
                    _getVehicleAssetPath(),
                    width: 65.w,
                    height: 55.h,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareBreakdownCard() {
    final fb = _extractPath(_bookingData, ['fareBreakdown']) ??
        _extractPath(_bookingData, ['trip', 'fareBreakdown']) ??
        (_bookingData?['fareBreakdowns'] is List && (_bookingData!['fareBreakdowns'] as List).isNotEmpty
            ? _bookingData!['fareBreakdowns'][0]
            : null);

    final baseFare = _parsePrice(
      _getSafeString([
        _extractPath(fb, ['baseFare']),
        _extractPath(_bookingData, ['baseFare']),
        _extractPath(_bookingData, ['fare', 'baseFare']),
        _extractPath(_invoiceData, ['baseFare']),
        _extractPath(_bookingData, ['estimatedFare']),
      ]),
    );

    final distanceFare = _parsePrice(
      _getSafeString([
        _extractPath(fb, ['distanceCharge']),
        _extractPath(fb, ['distanceFare']),
        _extractPath(_bookingData, ['distanceFare']),
        _extractPath(_bookingData, ['distanceCharge']),
        _extractPath(_bookingData, ['fare', 'distanceFare']),
        _extractPath(_invoiceData, ['distanceFare']),
      ]),
    );

    final waitingFare = _parsePrice(
      _getSafeString([
        _extractPath(fb, ['waitingCharge']),
        _extractPath(fb, ['timeCharge']),
        _extractPath(fb, ['waitingFare']),
        _extractPath(_bookingData, ['waitingFare']),
        _extractPath(_bookingData, ['timeCharge']),
        _extractPath(_bookingData, ['fare', 'waitingFare']),
        _extractPath(_invoiceData, ['timeFare']),
      ]),
    );

    final taxes = _parsePrice(
      _getSafeString([
        _extractPath(fb, ['tax']),
        _extractPath(_invoiceData, ['taxes']),
        _extractPath(_bookingData, ['tax']),
        _extractPath(_bookingData, ['serviceFee']),
        _extractPath(_bookingData, ['fare', 'tax']),
      ]),
    );

    final discount = _parsePrice(
      _getSafeString([
        _extractPath(fb, ['discount']),
        _extractPath(_invoiceData, ['discount']),
        _extractPath(_bookingData, ['discount']),
        _extractPath(_bookingData, ['fare', 'discount']),
      ]),
    );

    final totalFare = _parsePrice(
      _getSafeString([
        _extractPath(_bookingData, ['finalFare']),
        _extractPath(_bookingData, ['totalFare']),
        _extractPath(_bookingData, ['amount']),
        _extractPath(fb, ['total']),
        _extractPath(fb, ['subtotal']),
        _extractPath(_bookingData, ['fare', 'totalFare']),
        _extractPath(_invoiceData, ['totalAmount']),
        _extractPath(_invoiceData, ['grandTotal']),
        _extractPath(_bookingData, ['estimatedFare']),
      ]),
    );

    final displayBaseFare = (baseFare == 0.0 && totalFare > 0.0)
        ? (totalFare - taxes + discount > 0 ? totalFare - taxes + discount : totalFare)
        : baseFare;

    return Container(
      padding: EdgeInsets.only(
        top: 10.h,
        right: 16.w,
        bottom: 10.h,
        left: 16.w,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: const Color(0xFF14A03F).withOpacity(0.25),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Fare Breakdown',
            style: AppFonts.bodyText.copyWith(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w800,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 10.h),
          _buildFareRow(
            'Trip Amount',
            '₹${displayBaseFare.toStringAsFixed(2)}',
          ),
          if (distanceFare > 0)
            _buildFareRow(
              'Distance Fare',
              '₹${distanceFare.toStringAsFixed(2)}',
            ),
          if (waitingFare > 0)
            _buildFareRow(
              'Time Fare',
              '₹${waitingFare.toStringAsFixed(2)}',
            ),
          if (taxes > 0)
            _buildFareRow(
              'Taxes & Fees',
              '₹${taxes.toStringAsFixed(2)}',
            ),
          if (discount > 0)
            _buildFareRow(
              'Discount',
              '-₹${discount.toStringAsFixed(2)}',
              isDiscount: true,
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: List.generate(40, (index) {
                return Expanded(
                  child: Container(
                    height: 1.h,
                    color: index % 2 == 0
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                );
              }),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Fare',
                style: AppFonts.bodyText.copyWith(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.sp,
                ),
              ),
              Text(
                '₹${totalFare.toStringAsFixed(2)}',
                style: AppFonts.bodyText.copyWith(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isDiscount
                ? AppFonts.bodyText.copyWith(
                    color: const Color(0xFF14A03F),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  )
                : AppFonts.captionDark.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
          ),
          Text(
            value,
            style: AppFonts.bodyText.copyWith(
              color: isDiscount
                  ? const Color(0xFF14A03F)
                  : const Color(0xFF1A1A1A),
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    final pm = _extractPath(_bookingData, ['payments']) is List &&
            (_extractPath(_bookingData, ['payments']) as List).isNotEmpty
        ? _bookingData!['payments'][0]
        : null;

    final methodRaw = (_getSafeString([
      _extractPath(pm, ['method']),
      _extractPath(_bookingData, ['payment', 'paymentType']),
      _extractPath(_bookingData, ['payment', 'method']),
      _extractPath(_bookingData, ['paymentType']),
      _extractPath(_bookingData, ['paymentMethod']),
    ]) ?? 'Cash');

    String methodDisplay = methodRaw.toUpperCase();
    if (methodDisplay == 'CASH') {
      methodDisplay = 'Cash';
    } else if (methodDisplay == 'UPI') {
      methodDisplay = 'UPI';
    } else if (methodDisplay == 'CARD') {
      methodDisplay = 'Card';
    } else if (methodDisplay == 'WALLET') {
      methodDisplay = 'Wallet';
    } else {
      methodDisplay = methodRaw;
    }

    final fb = _extractPath(_bookingData, ['fareBreakdown']) ??
        _extractPath(_bookingData, ['trip', 'fareBreakdown']) ??
        (_bookingData?['fareBreakdowns'] is List && (_bookingData!['fareBreakdowns'] as List).isNotEmpty
            ? _bookingData!['fareBreakdowns'][0]
            : null);

    final totalFare = _parsePrice(
      _getSafeString([
        _extractPath(_bookingData, ['finalFare']),
        _extractPath(_bookingData, ['totalFare']),
        _extractPath(_bookingData, ['amount']),
        _extractPath(fb, ['total']),
        _extractPath(_invoiceData, ['totalAmount']),
        _extractPath(_invoiceData, ['grandTotal']),
        _extractPath(_bookingData, ['estimatedFare']),
      ]),
    );

    final txnId = _getSafeString([
      _extractPath(pm, ['providerPaymentId']),
      _extractPath(pm, ['id']),
      _extractPath(_bookingData, ['payment', 'transactionId']),
      _extractPath(_bookingData, ['payment', 'id']),
      _extractPath(_bookingData, ['paymentId']),
      _extractPath(_bookingData, ['transactionId']),
    ]);

    final paidAtStr = _getSafeString([
      _extractPath(pm, ['paidAt']),
      _extractPath(_bookingData, ['completedAt']),
      _extractPath(_bookingData, ['trip', 'completedAt']),
      _extractPath(_bookingData, ['updatedAt']),
    ]);

    String formattedPaidDate;
    if (paidAtStr != null && paidAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(paidAtStr).toLocal();
        formattedPaidDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        formattedPaidDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      }
    } else {
      formattedPaidDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    }

    return Container(
      padding: EdgeInsets.only(
        top: 10.h,
        right: 16.w,
        bottom: 10.h,
        left: 16.w,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: const Color(0xFF14A03F).withOpacity(0.25),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Payment Details',
            style: AppFonts.bodyText.copyWith(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w800,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Paid by $methodDisplay',
                      style: AppFonts.bodyText.copyWith(
                        color: const Color(0xFF1A1A1A),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      formattedPaidDate,
                      style: AppFonts.captionDark.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (txnId != null && txnId.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'Txn ID: $txnId',
                        style: AppFonts.captionDark.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 9.5.sp,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14A03F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFF14A03F).withOpacity(0.3),
                        width: 0.8.w,
                      ),
                    ),
                    child: Text(
                      'Paid',
                      style: AppFonts.bodyText.copyWith(
                        color: const Color(0xFF14A03F),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '₹${totalFare.toStringAsFixed(2)}',
                    style: AppFonts.bodyText.copyWith(
                      color: const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
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

  Widget _buildSystemGeneratedNotice() {
    return Container(
      constraints: BoxConstraints(minHeight: 59.h),
      padding: EdgeInsets.only(
        top: 12.h,
        right: 12.w,
        bottom: 12.h,
        left: 12.w,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FC),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: const Color(0xFFE3F6FC), width: 1.w),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: const BoxDecoration(
              color: Color(0xFFD0ECF7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.verified_rounded,
                color: const Color(0xFF00ABE4),
                size: 14.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This is a system generated invoice.',
                  style: AppFonts.bodyText.copyWith(
                    color: const Color(0xFF1A1A1A),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 2.h),
                RichText(
                  text: TextSpan(
                    style: AppFonts.captionDark.copyWith(
                      fontSize: 10.sp,
                      color: Colors.grey.shade500,
                      height: 1.15,
                    ),
                    children: [
                      const TextSpan(text: 'for any queries, visit '),
                      TextSpan(
                        text: 'Help & Support.',
                        style: AppFonts.bodyText.copyWith(
                          fontSize: 10.sp,
                          color: const Color(0xFF00ABE4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(BuildContext context) {
    final bId = widget.bookingId ??
        _getSafeString([
          _extractPath(_bookingData, ['id']),
          _extractPath(_bookingData, ['_id']),
          _extractPath(_bookingData, ['bookingId']),
        ]);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 14.h,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 10.h
            : 16.h,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 46.h,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E293B),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RaiseIssueScreen(
                  preselectedBookingId: bId,
                ),
              ),
            );
          },
          icon: Icon(Icons.help_outline_rounded, size: 18.sp),
          label: Text(
            'Report an Issue / Need Help',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String take(int nb) => length <= nb ? this : substring(0, nb);
}

class MockMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(8.r),
      ),
      bgPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.w
      ..strokeCap = StrokeCap.round;

    final roadPath1 = Path()
      ..moveTo(0, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.15,
        size.width * 0.65,
        size.height * 0.5,
      )
      ..lineTo(size.width, size.height * 0.75);

    final roadPath2 = Path()
      ..moveTo(size.width * 0.25, 0)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.55,
        size.width * 0.75,
        size.height,
      );

    canvas.drawPath(roadPath1, roadPaint);
    canvas.drawPath(roadPath2, roadPaint);

    final routePaint = Paint()
      ..color = const Color(0xFF00ABE4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5.w
      ..strokeCap = StrokeCap.round;

    final routePath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.8)
      ..cubicTo(
        size.width * 0.45,
        size.height * 0.7,
        size.width * 0.55,
        size.height * 0.4,
        size.width * 0.75,
        size.height * 0.25,
      );

    canvas.drawPath(routePath, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
