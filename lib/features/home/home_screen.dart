import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/utils.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/api_keys.dart';
import '../../constants/app_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/profile_service.dart';
import '../../services/active_booking_recovery_service.dart';
import '../activity/activity_screen.dart';
import 'location_search_screen.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../bookings/bookings_screen.dart';
import '../../widgets/location_route_markers.dart';
import '../../widgets/notification_bell.dart';
import '../../models/vehicle_category.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onViewAllServices});

  final VoidCallback? onViewAllServices;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentAddress = "Fetching location...";
  String _userName = "";
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  String? get _prefilledPickupAddress {
    const unavailableAddresses = {
      'Fetching location...',
      'Location services disabled',
      'Location permission denied',
      'Location permission permanently denied',
      'Unable to get location',
      'Location not found',
      'Error getting address',
    };

    if (unavailableAddresses.contains(_currentAddress)) {
      return null;
    }

    return _currentAddress;
  }

  List<Map<String, dynamic>> _vehicleCategories = [];
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _checkOngoingBooking();
    _loadUserProfile();
    _fetchVehicleCategories();
  }

  Future<void> _fetchVehicleCategories() async {
    if (_isLoadingCategories) return;
    _isLoadingCategories = true;
    try {
      final queryParams = <String, String>{};
      if (_currentPosition != null) {
        queryParams['latitude'] = _currentPosition!.latitude.toString();
        queryParams['longitude'] = _currentPosition!.longitude.toString();
      }
      final response = await ApiService.to.get(
        ApiEndpoints.vehicleCategories,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final rawData = response.data is Map
          ? response.data['data'] ?? response.data
          : response.data;
      final rawCategories = rawData is List
          ? rawData
          : rawData is Map && rawData['items'] is List
              ? rawData['items'] as List
              : <dynamic>[];

      final List<Map<String, dynamic>> parsedList = [];
      for (var cat in rawCategories) {
        if (cat is Map) {
          final vCat = VehicleCategory.fromJson(Map<String, dynamic>.from(cat));
          final String displayName = vCat.displayName;
          final String imagePath = (vCat.iconUrl != null && vCat.iconUrl!.trim().isNotEmpty)
              ? vCat.iconUrl!.trim()
              : ((vCat.imageUrl != null && vCat.imageUrl!.trim().isNotEmpty)
                  ? vCat.imageUrl!.trim()
                  : vCat.assetPath);
          final IconData icon = _getIconForCategory(vCat);
          final String categoryId = vCat.id.isNotEmpty ? vCat.id : vCat.value;

          parsedList.add({
            'title': displayName,
            'image': imagePath,
            'icon': icon,
            'category': displayName,
            'categoryId': categoryId,
            'isAvailable': vCat.isAvailable,
            'vCat': vCat,
            'action': () => _openLocationSearch(category: displayName, categoryId: categoryId),
          });
        }
      }

      if (mounted) {
        setState(() {
          _vehicleCategories = parsedList;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('[HOME_SCREEN] Error fetching vehicle categories: $e');
      if (mounted) {
        setState(() {
          _vehicleCategories = [];
          _isLoadingCategories = false;
        });
      }
    }
  }

  IconData _getIconForCategory(dynamic vCat) {
    final String clean = (vCat is VehicleCategory ? vCat.name : vCat.toString()).toLowerCase();
    if (clean.contains('bike') || clean.contains('motor') || clean.contains('2_wheeler')) {
      return Icons.two_wheeler_rounded;
    } else if (clean.contains('auto') || clean.contains('rickshaw') || clean.contains('3_wheeler') || clean.contains('tuktuk')) {
      return Icons.electric_rickshaw_rounded;
    } else if (clean.contains('sedan') || clean.contains('cab') || clean.contains('car')) {
      return Icons.directions_car_filled_rounded;
    } else if (clean.contains('suv') || clean.contains('xl') || clean.contains('muv') || clean.contains('luxury')) {
      return Icons.airport_shuttle_rounded;
    }
    return Icons.directions_car_rounded;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name');
      if (savedName != null && savedName.isNotEmpty && mounted) {
        setState(() {
          _userName = savedName;
        });
      }
      final profile = await ProfileService().getMyProfile();
      if (profile != null) {
        final name = profile.name.isNotEmpty
            ? profile.name
            : '${profile.firstname} ${profile.lastname}'.trim();
        if (name.isNotEmpty) {
          await prefs.setString('user_name', name);
          if (mounted) {
            setState(() {
              _userName = name;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _getCurrentLocation(),
      _loadUserProfile(),
      _checkOngoingBooking(),
    ]);
  }

  Future<void> _checkOngoingBooking() async {
    if (!mounted) return;
    await ActiveBookingRecoveryService.fetchAndResume(context);
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _currentAddress = "Location services disabled";
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _currentAddress = "Location permission denied";
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _currentAddress = "Location permission permanently denied";
        });
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
      _getAddressFromLatLng(position);
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = "Unable to get location";
        });
      }
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${ApiKeys.googleMapsKey}';
    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          setState(() {
            _currentAddress = AppUtils.cleanGeocodedAddress(
              data['results'][0]['formatted_address'],
            );
          });
        } else {
          setState(() {
            _currentAddress = "Location not found";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = "Error getting address";
        });
      }
    }
  }

  void _openLocationSearch({bool isScheduled = false, String? category, String? categoryId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(
          initialPickupLocation: _prefilledPickupAddress,
          isScheduled: isScheduled,
          selectedCategory: category,
          selectedCategoryId: categoryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP APP BAR & COMPACT LOCATION ROW
            _buildTopAppBarAndLocation(),

            // MAIN SCROLLABLE CONTENT
            Expanded(
              child: RefreshIndicator(
                color: AppColors.fleetgoYellow,
                onRefresh: _refreshHome,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: EdgeInsets.only(
                    left: 16.w,
                    right: 16.w,
                    top: 0,
                    bottom: 12.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // 2. GREETING / HERO SECTION WITH MAP PREVIEW
                    _buildGreetingHeroSection(),

                    // 3. PICKUP / DROP-OFF CARD
                    _buildPickupDropoffCard(),
                    SizedBox(height: 16.h),

                    // 4. QUICK ACTION CARD
                    _buildQuickActionCard(),
                    SizedBox(height: 16.h),

                    // 5. PROMOTIONAL BANNER
                    _buildPromotionalBanner(),
                    SizedBox(height: 20.h),

                    // 6. SERVICES FOR YOU SECTION
                    _buildServicesForYouSection(),
                    SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. TOP APP BAR & COMPACT LOCATION ROW
  Widget _buildTopAppBarAndLocation() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Top Row: Logo & Notification Bell
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fleetgo Logo
                Row(
                  children: [
                    Image.asset(
                      'assets/images/sawariya_login_logo.png',
                      width: 140.w,
                      height: 40.h,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF4B41A),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.directions_car_filled_rounded,
                              color: Colors.black,
                              size: 20.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Sawariyaa',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const NotificationBell(),
              ],
            ),
          ),

          // Top divider line above location section
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),

          // Location Selector Bar
          GestureDetector(
            onTap: _openLocationSearch,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 10.h),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: const Color(0xFFF4B41A),
                    size: 20.sp,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      _currentAddress,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF111827),
                    size: 22.sp,
                  ),
                ],
              ),
            ),
          ),

          // Bottom divider line below location section
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  // 2. GREETING / HERO SECTION
  Widget _buildGreetingHeroSection() {
    final String displayName = _userName.isNotEmpty
        ? _userName.split(' ').first
        : 'Guest User';

    return SizedBox(
      height: 145.h,
      child: Stack(
        children: [
          // Background right-side Map graphics preview
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 170.w,
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Container(
                color: const Color(0xFFF3F4F6),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SvgPicture.asset(
                        'assets/images/bg_home.svg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: Center(
                            child: Icon(
                              Icons.map_rounded,
                              color: const Color(0xFFF4B41A),
                              size: 40.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Soft left-to-right fade gradient overlay for clean integration
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Yellow node point indicator icon
                    Positioned(
                      top: 40.h,
                      right: 40.w,
                      child: Container(
                        width: 26.r,
                        height: 26.r,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4B41A).withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 14.r,
                            height: 14.r,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF4B41A),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Left-side Greeting Text Content
          Positioned(
            left: 0,
            top: 25.h,
            bottom: 0,
            width: 200.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'Hello, $displayName',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'Ready When',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'you are',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Book a ride in minutes and\nreach your destination',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. PICKUP / DROP-OFF CARD
  Widget _buildPickupDropoffCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Timeline Graphic
          const RouteMarkerTimeline(connectorHeight: 34),
          SizedBox(width: 14.w),

          // Right Inputs & Divider
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pick up Location
                GestureDetector(
                  onTap: _openLocationSearch,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pick up Location',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 11.sp,
                                color: const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _prefilledPickupAddress ?? 'Where are you going ?',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Later Button
                      GestureDetector(
                        onTap: () => _openLocationSearch(isScheduled: true),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14.sp,
                                color: const Color(0xFF111827),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Later',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Divider(height: 1, color: Colors.grey.shade200),
                ),

                // Drop-off Location
                GestureDetector(
                  onTap: _openLocationSearch,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Drop-off Location',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Enter drop-off location',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  // 4. QUICK ACTION CARD
  Widget _buildQuickActionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          // 1. Ride Now
          Expanded(
            child: GestureDetector(
              onTap: _openLocationSearch,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 26.h,
                    child: Image.asset(
                      'assets/images/1Ride Now.png',
                      height: 26.sp,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.directions_car_rounded,
                        color: const Color(0xFFF4B41A),
                        size: 26.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Ride Now',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      letterSpacing: 0,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 32.h, color: Colors.grey.shade200),

          // 2. Schedule
          Expanded(
            child: GestureDetector(
              onTap: () => _openLocationSearch(isScheduled: true),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 26.h,
                    child: Image.asset(
                      'assets/images/1Schedule.png',
                      height: 26.sp,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.calendar_month_rounded,
                        color: const Color(0xFFF4B41A),
                        size: 26.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Schedule',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      letterSpacing: 0,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 32.h, color: Colors.grey.shade200),

          // 3. Favorites
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActivityScreen(),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 26.h,
                    child: Image.asset(
                      'assets/images/1Favorites.png',
                      height: 26.sp,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.star_rounded,
                        color: const Color(0xFFF4B41A),
                        size: 26.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Favorites',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      letterSpacing: 0,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 32.h, color: Colors.grey.shade200),

          // 4. History
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BookingsScreen(),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 26.h,
                    child: Image.asset(
                      'assets/images/1History.png',
                      height: 26.sp,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.history_rounded,
                        color: const Color(0xFFF4B41A),
                        size: 26.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'History',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      letterSpacing: 0,
                      color: const Color(0xFF111827),
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

  // 5. PROMOTIONAL BANNER
  Widget _buildPromotionalBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ActivityScreen()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/banner.png',
            width: double.infinity,
            height: 100.h,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF0D0D0D),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              child: Row(
                children: [
                  Container(
                    width: 52.r,
                    height: 52.r,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4B41A),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Center(
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Save more on every ride',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  // 6. SERVICES FOR YOU SECTION
  Widget _buildServicesForYouSection() {
    if (_isLoadingCategories) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services for you',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF242A37),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 70.h,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFF4B41A)),
            ),
          ),
        ],
      );
    }

    if (_vehicleCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final services = _vehicleCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & View All Header Frame (Figma Spec)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Services for you',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF242A37),
              ),
            ),
            GestureDetector(
              onTap: () {
                final switchToServices = widget.onViewAllServices;
                if (switchToServices != null) {
                  switchToServices();
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActivityScreen(),
                  ),
                );
              },
              child: Text(
                'View all',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),

        // Horizontal Service Cards Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: services.map((service) {
              final String img = (service['image'] ?? '').toString();
              final bool isAvailable = service['isAvailable'] != false;

              return Padding(
                padding: EdgeInsets.only(right: 10.w),
                child: GestureDetector(
                  onTap: service['action'] as VoidCallback,
                  child: Opacity(
                    opacity: isAvailable ? 1.0 : 0.65,
                    child: Container(
                      width: 64.w,
                      height: 70.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9FA),
                        borderRadius: BorderRadius.circular(15.r),
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 6.h,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 28.h,
                            child: img.startsWith('http://') || img.startsWith('https://')
                                ? Image.network(
                                    img,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      service['icon'] as IconData,
                                      color: const Color(0xFFF4B41A),
                                      size: 22.sp,
                                    ),
                                  )
                                : Image.asset(
                                    img,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      service['icon'] as IconData,
                                      color: const Color(0xFFF4B41A),
                                      size: 22.sp,
                                    ),
                                  ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            service['title'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: isAvailable ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
