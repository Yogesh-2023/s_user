import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_keys.dart';
import '../../constants/app_fonts.dart';
import '../../constants/app_colors.dart';
import '../../core/utils.dart';
import '../home/location_search_screen.dart';
import '../../widgets/custom_bottom_navigation_bar.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/notification_bell.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_service.dart';
import '../../models/vehicle_category.dart';
import '../main_navigation_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with WidgetsBindingObserver {
  String _currentAddress = 'Fetching location...';
  Position? _currentPosition;
  bool _isFetchingLocation = false;

  Position? get currentPosition => _currentPosition;

  String? get _prefilledPickupAddress {
    const unavailableAddresses = {
      'Fetching location...',
      'Location services disabled',
      'Location permission denied',
      'Location permission permanently denied',
      'Unable to get location',
      'Unable to get current location',
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
    WidgetsBinding.instance.addObserver(this);
    _getCurrentLocation();
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
      debugPrint('[ACTIVITY_SCREEN] Error fetching vehicle categories: $e');
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentPosition == null) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isFetchingLocation) return;
    _isFetchingLocation = true;
    if (mounted) setState(() => _currentAddress = 'Fetching location...');

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _currentAddress = 'Location services disabled');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _currentAddress = 'Location permission denied');
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(
            () => _currentAddress = 'Location permission permanently denied',
          );
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted) {
          setState(() => _currentAddress = 'Unable to get current location');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      await _getAddressFromLatLng(position);
    } catch (e) {
      if (mounted) {
        setState(() => _currentAddress = 'Unable to get current location');
      }
      debugPrint('Activity location error: $e');
    } finally {
      _isFetchingLocation = false;
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
          return;
        }
      }
      setState(() {
        _currentAddress =
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
      }
      debugPrint('Activity reverse-geocoding error: $e');
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
    final bool isInsideMainNavigation =
        context.findAncestorStateOfType<MainNavigationScreenState>() != null;
    final bool canPop = Navigator.canPop(context) && !isInsideMainNavigation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. TOP APP BAR
            _buildTopHeader(context),

            // 2. LOCATION SECTION
            _buildLocationSection(),

            // MAIN SCROLLABLE CONTENT
            Expanded(
              child: RefreshIndicator(
                color: AppColors.fleetgoYellow,
                onRefresh: _getCurrentLocation,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 4. ALL SERVICES SECTION (Figma Spec: 3-column grid)
                      _buildAllServicesSection(),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: canPop
          ? SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: CustomBottomNavigationBar(
                  currentIndex: 1,
                  onTap: (index) {
                    final navState = context
                        .findAncestorStateOfType<MainNavigationScreenState>();
                    if (navState != null) {
                      navState.setIndex(index);
                      Navigator.pop(context);
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MainNavigationScreen(initialIndex: index),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
            )
          : null,
    );
  }

  // 1. TOP APP BAR
  Widget _buildTopHeader(BuildContext context) {
    return CommonAppBar(
      title: 'Services',
      trailingAction: _buildNotificationBell(context),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return const NotificationBell(size: 36);
  }

  // 2. LOCATION SECTION WITH TOP & BOTTOM DIVIDERS
  Widget _buildLocationSection() {
    return Container(
      color: const Color(0xFFF9F9FA),
      child: Column(
        children: [
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          GestureDetector(
            onTap: _currentPosition == null
                ? _getCurrentLocation
                : _openLocationSearch,
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
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  // 4. ALL SERVICES SECTION (8 Service Cards, Figma specs: 106.03x106.03, radius 19.4, border 1.29 #FFFFFF, bg #F9F9FA, gap 10.34)
  Widget _buildAllServicesSection() {
    final services = _vehicleCategories.isNotEmpty
        ? _vehicleCategories
        : _vehicleCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Services',
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D0D0D),
          ),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10.34.h,
            crossAxisSpacing: 10.34.w,
            childAspectRatio: 1.0,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return GestureDetector(
              onTap: service['action'] as VoidCallback?,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FA),
                  borderRadius: BorderRadius.circular(19.4.r),
                  border: Border.all(color: Colors.white, width: 1.29),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 42.h,
                      child: Image.asset(
                        service['image'] as String,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                              'assets/images/rentalsnew.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    service['icon'] as IconData,
                                    color: const Color(0xFFF4B41A),
                                    size: 32.sp,
                                  ),
                            ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      service['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
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
            );
          },
        ),
      ],
    );
  }
}
