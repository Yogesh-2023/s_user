import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../constants/app_assets.dart';
import '../../core/api/api_constants.dart';
import '../../models/vehicle_category.dart';
import '../../services/review_service.dart';
import '../main_navigation_screen.dart';

class RateRideScreen extends StatefulWidget {
  final String? bookingId;
  final Map<String, dynamic>? driverData;

  const RateRideScreen({super.key, this.bookingId, this.driverData});

  @override
  State<RateRideScreen> createState() => _RateRideScreenState();
}

class _RateRideScreenState extends State<RateRideScreen> {
  int _selectedRating = 5;
  final TextEditingController _feedbackController = TextEditingController();

  final List<Map<String, String>> _feedbackTags = [
    {'emoji': '🤗', 'text': 'Good Service'},
    {'emoji': '🤗', 'text': 'Safe Driving'},
    {'emoji': '🤗', 'text': 'On-time'},
    {'emoji': '🤗', 'text': 'Clean Car'},
    {'emoji': '🤗', 'text': 'Polite Drive'},
  ];

  final List<String> _selectedTags = [];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  dynamic _readValue(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  Map<String, dynamic> get _rootData {
    final data = widget.driverData;
    if (data == null) return {};
    final booking = data['booking'] ?? data['trip'] ?? data['data'];
    return booking is Map
        ? {...data, ...Map<String, dynamic>.from(booking)}
        : Map<String, dynamic>.from(data);
  }

  dynamic _firstListItem(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first;
    return null;
  }

  Map<String, dynamic> get _driver {
    if (widget.driverData == null) return {};
    final root = _rootData;
    final value =
        root['driver'] ??
        root['assignedDriver'] ??
        root['driverDetails'] ??
        root['driverProfile'] ??
        widget.driverData!['driver'] ??
        widget.driverData!['assignedDriver'] ??
        widget.driverData!['driverDetails'] ??
        widget.driverData!['booking']?['driver'] ??
        widget.driverData!['booking']?['assignedDriver'] ??
        widget.driverData!['booking']?['driverDetails'];

    if (value is Map) return Map<String, dynamic>.from(value);

    // In some API responses, widget.driverData IS the driver object itself
    if (widget.driverData != null &&
        (widget.driverData!.containsKey('name') ||
            widget.driverData!.containsKey('firstName') ||
            widget.driverData!.containsKey('driverName') ||
            widget.driverData!.containsKey('profileImage'))) {
      return Map<String, dynamic>.from(widget.driverData!);
    }

    return {};
  }

  Map<String, dynamic> get _vehicle {
    if (widget.driverData == null) return {};
    final root = _rootData;
    final value =
        _driver['assignedVehicle'] ??
        _driver['vehicle'] ??
        _firstListItem(_driver['vehicles']) ??
        _firstListItem(_driver['driverProfile']?['vehicles']) ??
        root['vehicle'] ??
        root['assignedVehicle'] ??
        root['vehicleModel'] ??
        widget.driverData!['vehicle'] ??
        widget.driverData!['assignedVehicle'] ??
        widget.driverData!['vehicleModel'] ??
        widget.driverData!['booking']?['vehicle'] ??
        widget.driverData!['booking']?['assignedVehicle'] ??
        widget.driverData!['booking']?['vehicleModel'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String? _bookedVehicleAsset() {
    final root = _rootData;
    final rawCategory = _readValue([
      root['vehicleCategory'],
      root['vehicleCategoryEnum'],
      root['vehicleCategoryName'],
      root['vehicleType'],
      root['category'],
      root['categoryName'],
      root['carType'],
      root['carName'],
      root['moduleType'],
      root['vehicleModel']?['category'],
      root['vehicleModel']?['vehicleType'],
      widget.driverData?['vehicleCategory'],
      widget.driverData?['vehicleCategoryEnum'],
      widget.driverData?['booking']?['vehicleCategory'],
      widget.driverData?['booking']?['vehicleCategoryEnum'],
      widget.driverData?['booking']?['vehicleType'],
      widget.driverData?['booking']?['category'],
    ])?.toString();

    final normalized = rawCategory
        ?.trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
    if (normalized != null &&
        (normalized.contains('TRUCK') ||
            normalized.contains('GOODS') ||
            normalized.contains('PARCEL'))) {
      return 'assets/images/truck.png';
    }

    return VehicleCategory.fromString(rawCategory)?.assetPath;
  }

  Widget _buildVehicleFallback({required bool isGoods}) {
    return Container(
      width: 75.w,
      height: 55.h,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7FD),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Icon(
        isGoods ? Icons.local_shipping_outlined : Icons.directions_car_outlined,
        color: const Color(0xFF00ABE4),
        size: 30.sp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final root = _rootData;
    final vehicleType =
        (_readValue([
                  root['vehicleCategory'],
                  root['vehicleCategoryEnum'],
                  root['vehicleType'],
                  _vehicle['vehicleType'],
                  _vehicle['type'],
                  widget.driverData?['vehicleType'],
                  widget.driverData?['booking']?['vehicleType'],
                ]) ??
                '')
            .toString()
            .toUpperCase();
    final isGoods =
        widget.driverData?['isGoods'] == true ||
        widget.driverData?['booking']?['isGoods'] == true ||
        widget.driverData?['moduleType']?.toString().toUpperCase() == 'GOODS' ||
        vehicleType.contains('TRUCK');

    String? driverImage = _readValue([
      _driver['profileImageUrl'],
      _driver['profileImage'],
      _driver['profilePicture'],
      _driver['image'],
      _driver['avatar'],
      _driver['driverProfile']?['profileImageUrl'],
      _driver['driverProfile']?['avatar'],
      _driver['user']?['profileImageUrl'],
      _driver['user']?['profileImage'],
      _driver['user']?['avatar'],
      root['driverImage'],
      root['driver']?['profileImageUrl'],
      root['driver']?['profileImage'],
      root['driverData']?['profileImageUrl'],
      root['driverData']?['profileImage'],
      root['assignedDriver']?['profileImageUrl'],
      root['assignedDriver']?['profileImage'],
      _driver['driverProfile']?['profileImage'],
      _driver['driverProfile']?['avatar'],
      widget.driverData?['driverImage'],
    ])?.toString();

    if (driverImage != null) {
      if (driverImage.contains('localhost') ||
          driverImage.contains('cars.carosa.in')) {
        final uri = Uri.tryParse(driverImage);
        if (uri != null && uri.path.isNotEmpty) {
          driverImage = '${ApiConstants.baseUrl}${uri.path}';
        }
      } else if (!driverImage.startsWith('http')) {
        if (!driverImage.startsWith('/')) driverImage = '/$driverImage';
        driverImage = '${ApiConstants.baseUrl}$driverImage';
      }
    }

    final firstName = _readValue([
      _driver['firstName'],
      _driver['firstname'],
      _driver['user']?['firstName'],
      _driver['user']?['firstname'],
      _driver['profile']?['firstName'],
      _driver['driverProfile']?['user']?['firstName'],
      root['driverFirstName'],
    ])?.toString();
    final lastName = _readValue([
      _driver['lastName'],
      _driver['lastname'],
      _driver['user']?['lastName'],
      _driver['user']?['lastname'],
      _driver['profile']?['lastName'],
      _driver['driverProfile']?['user']?['lastName'],
      root['driverLastName'],
    ])?.toString();
    final fullName = [
      firstName,
      lastName,
    ].where((v) => v?.trim().isNotEmpty == true).join(' ');
    final driverName = fullName.isNotEmpty
        ? fullName
        : (_readValue([
                    _driver['name'],
                    _driver['fullName'],
                    _driver['displayName'],
                    _driver['profile']?['name'],
                    _driver['profile']?['fullName'],
                    _driver['user']?['name'],
                    _driver['user']?['fullName'],
                    _driver['user']?['displayName'],
                    _driver['driverProfile']?['name'],
                    _driver['driverProfile']?['user']?['name'],
                    _driver['driverProfile']?['user']?['displayName'],
                    root['driverName'],
                    root['driver']?['name'],
                    root['driver']?['user']?['name'],
                    root['assignedDriver']?['name'],
                    root['assignedDriver']?['user']?['name'],
                    widget.driverData?['driverName'],
                  ]) ??
                  'Driver')
              .toString();

    final rating =
        _readValue([
          _driver['rating'],
          _driver['averageRating'],
          widget.driverData?['rating'],
        ]) ??
        '5.0';
    final totalTrips =
        _readValue([_driver['totalTrips'], widget.driverData?['totalTrips']]) ??
        0;
    final vehicleNumber =
        _readValue([
          _vehicle['vehicleNumber'],
          _vehicle['registrationNumber'],
          _vehicle['plateNumber'],
          _vehicle['registrationNo'],
          root['vehicleNumber'],
          root['registrationNumber'],
          _driver['vehicleNumber'],
          _driver['registrationNumber'],
          widget.driverData?['vehicleNumber'],
          widget.driverData?['registrationNumber'],
          widget.driverData?['booking']?['vehicleNumber'],
          widget.driverData?['booking']?['registrationNumber'],
        ]) ??
        '—';
    final vehicleName =
        '${_readValue([_vehicle['vehicleName'], _vehicle['model'], _vehicle['vehicleModel'], _vehicle['make'], root['vehicleModel']?['name'], root['vehicleModelName'], root['carName'], widget.driverData?['carName']]) ?? 'Vehicle'} ${_readValue([_vehicle['color'], root['vehicleColor'], widget.driverData?['vehicleColor']]) ?? ''}'
            .trim();
    final bookedVehicleAsset = _bookedVehicleAsset();

    String? vehicleImage = _readValue([
      _vehicle['image'],
      _vehicle['imageUrl'],
      _vehicle['vehicleImage'],
      _vehicle['photoFrontView'],
      _vehicle['photoSideView'],
      _vehicle['photoBackView'],
      widget.driverData?['vehicleImage'],
      widget.driverData?['booking']?['vehicleImage'],
    ])?.toString();
    if (vehicleImage != null) {
      if (vehicleImage.contains('localhost') ||
          vehicleImage.contains('cars.carosa.in')) {
        final uri = Uri.tryParse(vehicleImage);
        if (uri != null && uri.path.isNotEmpty) {
          vehicleImage = '${ApiConstants.baseUrl}${uri.path}';
        }
      } else if (!vehicleImage.startsWith('http')) {
        if (!vehicleImage.startsWith('/')) vehicleImage = '/$vehicleImage';
        vehicleImage = '${ApiConstants.baseUrl}$vehicleImage';
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Area with light blue background
          Container(
            color: AppColors.lightBlueBackground,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20.h,
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20.r,
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
                SizedBox(width: 16.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Your Ride',
                      style: AppFonts.h1.copyWith(
                        fontSize: 20.sp,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Your feedback helps us improve',
                      style: AppFonts.captionDark.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main White Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: 24.h,
                      left: 20.w,
                      right: 20.w,
                      bottom: 150.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Driver Info Box
                        Container(
                          height: 96.h,
                          padding: EdgeInsets.only(
                            top: 10.h,
                            right: 14.w,
                            bottom: 10.h,
                            left: 10.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15.r),
                            border: Border.all(
                              color: const Color(0xFF00ABE4).withOpacity(0.25),
                              width: 1.w,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 55.w,
                                height: 55.h,
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
                                    color: const Color(
                                      0xFF00ABE4,
                                    ).withOpacity(0.20),
                                    width: 0.46.w,
                                  ),
                                ),
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6.r),
                                    child: driverImage != null
                                        ? Image.network(
                                            driverImage,
                                            width: 44.w,
                                            height: 44.h,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Image.asset(
                                                  AppAssets.profileImage,
                                                  width: 44.w,
                                                  height: 44.h,
                                                  fit: BoxFit.cover,
                                                ),
                                          )
                                        : Image.asset(
                                            AppAssets.profileImage,
                                            width: 44.w,
                                            height: 44.h,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            driverName,
                                            style: AppFonts.bodyText.copyWith(
                                              color: const Color(0xFF1A1A1A),
                                              fontSize: 14.5.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 1.5.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(
                                              6.r,
                                            ),
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
                                                rating.toString(),
                                                style: AppFonts.bodyText
                                                    .copyWith(
                                                      color: const Color(
                                                        0xFFB45309,
                                                      ),
                                                      fontSize: 9.sp,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '$totalTrips Trips',
                                      style: AppFonts.captionDark.copyWith(
                                        color: Colors.grey.shade500,
                                        fontSize: 10.5.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      vehicleNumber,
                                      style: AppFonts.bodyText.copyWith(
                                        color: const Color(0xFF1A1A1A),
                                        fontSize: 10.5.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      vehicleName,
                                      style: AppFonts.captionDark.copyWith(
                                        color: Colors.grey.shade500,
                                        fontSize: 10.5.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (bookedVehicleAsset != null)
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: Image.asset(
                                    bookedVehicleAsset,
                                    width: 75.w,
                                    height: 55.h,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) =>
                                        _buildVehicleFallback(isGoods: isGoods),
                                  ),
                                )
                              else if (vehicleImage != null)
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: Image.network(
                                    vehicleImage,
                                    width: 75.w,
                                    height: 55.h,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) =>
                                        _buildVehicleFallback(isGoods: isGoods),
                                  ),
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: _buildVehicleFallback(
                                    isGoods: isGoods,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Rating Section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 14.h,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'How was your ride?',
                                style: AppFonts.bodyText.copyWith(
                                  fontSize: 16.sp,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Tap a star to rate',
                                style: AppFonts.captionDark.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 11.sp,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedRating = index + 1;
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6.w,
                                      ),
                                      child: Icon(
                                        index < _selectedRating
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: index < _selectedRating
                                            ? const Color(0xFFFCB21C)
                                            : const Color(0xFFE2E8F0),
                                        size: 32.sp,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              SizedBox(height: 8.h),
                              if (_selectedRating > 0)
                                Container(
                                  height: 26.h,
                                  padding: EdgeInsets.only(
                                    top: 5.h,
                                    right: 12.w,
                                    bottom: 5.h,
                                    left: 12.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F8F3),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(
                                      color: const Color(0xFFE3F6FC),
                                      width: 1.w,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        _selectedRating == 5
                                            ? 'Excellent'
                                            : _selectedRating == 4
                                            ? 'Good'
                                            : _selectedRating == 3
                                            ? 'Okay'
                                            : _selectedRating == 2
                                            ? 'Bad'
                                            : 'Very Bad',
                                        style: AppFonts.bodyText.copyWith(
                                          color: const Color(0xFF14A03F),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.sp,
                                          height: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        _selectedRating == 5
                                            ? '🤩'
                                            : _selectedRating == 4
                                            ? '😊'
                                            : _selectedRating == 3
                                            ? '😐'
                                            : _selectedRating == 2
                                            ? '🙁'
                                            : '😠',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32.h),

                        // Feedback Section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 16.h,
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
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Tell us more ',
                                      style: AppFonts.bodyText.copyWith(
                                        fontSize: 16.sp,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '(optional)',
                                      style: AppFonts.captionDark.copyWith(
                                        color: Colors.grey.shade500,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Share additional feedback about your ride',
                                textAlign: TextAlign.center,
                                style: AppFonts.captionDark.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 11.sp,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Container(
                                height: 90.h,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.w,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00ABE4,
                                    ).withOpacity(0.25),
                                    width: 1.w,
                                  ),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: TextField(
                                  controller: _feedbackController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Write your feedback...',
                                    hintStyle: AppFonts.captionDark.copyWith(
                                      color: Colors.grey.shade400,
                                      fontSize: 13.sp,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: AppFonts.bodyText.copyWith(
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8.w,
                                  runSpacing: 8.h,
                                  children: _feedbackTags.map((tag) {
                                    final bool isSelected = _selectedTags
                                        .contains(tag['text']);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedTags.remove(tag['text']);
                                          } else {
                                            _selectedTags.add(tag['text']!);
                                          }
                                        });
                                      },
                                      child: Container(
                                        height: 26.h,
                                        padding: EdgeInsets.only(
                                          top: 5.h,
                                          right: 8.w,
                                          bottom: 5.h,
                                          left: 8.w,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(
                                                  0xFF00ABE4,
                                                ).withOpacity(0.04)
                                              : Colors.white,
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF00ABE4)
                                                : const Color(0xFFE3F6FC),
                                            width: 1.w,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            100.r,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              tag['emoji']!,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                height: 1.0,
                                              ),
                                            ),
                                            SizedBox(width: 5.w),
                                            Text(
                                              tag['text']!,
                                              style: AppFonts.bodyText.copyWith(
                                                color: isSelected
                                                    ? const Color(0xFF00ABE4)
                                                    : Colors.grey.shade700,
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                height: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // Important Banner
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 16.w,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2FBFE),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: const Color(0xFF00ABE4).withOpacity(0.25),
                              width: 1.w,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF00ABE4),
                                radius: 12.r,
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14.sp,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Your feedback is important',
                                      style: AppFonts.bodyText.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'We use your feedback to improve our service',
                                      style: AppFonts.captionDark.copyWith(
                                        color: Colors.grey.shade600,
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
                  ),

                  // Fixed Bottom Buttons
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: EdgeInsets.only(
                        left: 20.w,
                        right: 20.w,
                        top: 16.h,
                        bottom: MediaQuery.of(context).padding.bottom > 0
                            ? MediaQuery.of(context).padding.bottom
                            : 20.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 46.h,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00ABE4),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final comment = _feedbackController.text.trim();
                                // Combine text with tags
                                final finalComment = _selectedTags.isNotEmpty
                                    ? '$comment [Tags: ${_selectedTags.join(", ")}]'
                                    : comment;

                                // Show loading (optional, but good practice)
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                final reviewService = Get.find<ReviewService>();
                                final bookingId = widget.bookingId ?? '';

                                if (bookingId.isEmpty) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Missing booking ID for review',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final success = await reviewService
                                    .submitReview(
                                      bookingId: bookingId,
                                      rating: _selectedRating.toDouble(),
                                      comment: finalComment,
                                    );

                                Navigator.pop(context); // Close loading

                                if (success) {
                                  _showReviewSubmittedDialog(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to submit review'),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Submit Review',
                                style: AppFonts.buttonText.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          SizedBox(
                            width: double.infinity,
                            height: 46.h,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00ABE4),
                                side: BorderSide(
                                  color: const Color(0xFF00ABE4),
                                  width: 1.5.w,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              onPressed: () {
                                // Navigate home
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MainNavigationScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Text(
                                'Skip',
                                style: AppFonts.buttonText.copyWith(
                                  color: const Color(0xFF00ABE4),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewSubmittedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 22.h, 14.w, 18.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54.w,
                  height: 54.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Review Submitted',
                  style: AppFonts.h2.copyWith(
                    color: Colors.black,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Thank you for sharing your feedback.',
                  textAlign: TextAlign.center,
                  style: AppFonts.bodyText.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 13.sp,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 20.h),
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainNavigationScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: Text(
                    'Go to Home Screen',
                    style: AppFonts.bodyText.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
