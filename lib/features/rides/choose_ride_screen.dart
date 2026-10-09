import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../constants/app_fonts.dart';
import '../../constants/api_keys.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils.dart';
import '../../services/recent_location_service.dart';
import '../../services/customer_address_service.dart';
import '../../services/active_booking_recovery_service.dart';
import '../../models/recent_location_model.dart';
import '../home/location_search_screen.dart';
import 'looking_for_ride_screen.dart';
import '../../widgets/location_route_markers.dart';
import '../../models/vehicle_category.dart';

class ChooseRideScreen extends StatefulWidget {
  final String? pickupAddress;
  final String? destinationAddress;
  final LatLng? pickupLatLng;
  final LatLng? destinationLatLng;
  final bool isScheduled;
  final String? selectedCategory;
  final String? selectedCategoryId;

  const ChooseRideScreen({
    super.key,
    this.pickupAddress,
    this.destinationAddress,
    this.pickupLatLng,
    this.destinationLatLng,
    this.isScheduled = false,
    this.selectedCategory,
    this.selectedCategoryId,
  });

  @override
  State<ChooseRideScreen> createState() => _ChooseRideScreenState();
}

class _ChooseRideScreenState extends State<ChooseRideScreen> {
  static const double _addressLabelFontSize = 11;
  static const double _addressValueFontSize = 12;
  static const FontWeight _addressLabelFontWeight = FontWeight.w600;
  static const FontWeight _addressValueFontWeight = FontWeight.w600;

  int _selectedRideIndex = 0;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};

  bool _isLoadingFares = true;
  List<dynamic> _fareEstimates = [];
  DateTime? _scheduledAt;
  String _selectedPaymentMethod = 'CASH';

  String _tripType = 'ONE_WAY';
  DateTime? _returnDateTime;
  bool _isBookingCreating = false;

  Future<bool> _pickScheduledAt() async {
    final now = DateTime.now();
    final minValidTime = now.add(const Duration(minutes: 20));
    final date = await showDatePicker(
      context: context,
      initialDate: minValidTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFF4B41A),
            onPrimary: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return false;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(minValidTime),
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
    if (time == null || !mounted) return false;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isBefore(DateTime.now().add(const Duration(minutes: 15)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time at least 15 to 20 minutes from now.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    setState(() => _scheduledAt = selected);
    return true;
  }

  Future<bool> _pickReturnDateTime() async {
    final now = DateTime.now();
    final DateTime baseTime = _scheduledAt ?? now;
    final DateTime minValidTime = baseTime.add(const Duration(minutes: 20));

    final date = await showDatePicker(
      context: context,
      initialDate: _returnDateTime != null && _returnDateTime!.isAfter(minValidTime)
          ? _returnDateTime!
          : minValidTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFF4B41A),
            onPrimary: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return false;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _returnDateTime != null && _returnDateTime!.isAfter(minValidTime)
            ? _returnDateTime!
            : minValidTime,
      ),
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
    if (time == null || !mounted) return false;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (selected.isBefore(minValidTime)) {
      final minFormatted = _formatScheduledAt(minValidTime);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Return date/time must be after outbound departure ($minFormatted).'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    setState(() => _returnDateTime = selected);
    return true;
  }

  String _formatScheduledAt(DateTime value) {
    final hourOfPeriod = value.hour % 12;
    final hour = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${value.day}/${value.month}/${value.year}, $hour:$minute $period';
  }

  Future<void> _showReturnBookingSuccessDialog(Map<String, dynamic> data) async {
    final fare = data['fare'] is Map ? Map<String, dynamic>.from(data['fare'] as Map) : {};
    final totalFare = fare['total'] ?? fare['totalFare'] ?? data['estimatedFare'] ?? 0;
    final currency = fare['currency']?.toString() ?? '₹';
    final returnTimeStr = _returnDateTime != null ? _formatScheduledAt(_returnDateTime!) : 'Scheduled';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.swap_calls_rounded,
                  color: const Color(0xFF166534),
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Return Trip Booked!',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trip_origin, color: Colors.green, size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Outbound: ${widget.pickupAddress ?? "Pickup"} → ${widget.destinationAddress ?? "Drop"}',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 16.h),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.red, size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Return: ${widget.destinationAddress ?? "Drop"} → ${widget.pickupAddress ?? "Pickup"}',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Return Time:',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          returnTimeStr,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF4B41A),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Fare:',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$currency$totalFare',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4B41A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Proceed to Outbound Ride',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoDriversModal(BuildContext context, [String? message]) {
    if (!mounted) return;
    final msg = (message != null && message.trim().isNotEmpty)
        ? message
        : 'No drivers available in your area at the moment. Please try again later.';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(Icons.directions_car_filled_outlined, color: const Color(0xFFF59E0B), size: 28.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'No Drivers Available',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 14.sp,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchFareEstimates();
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;

    // 1. Try Google Geocoding API
    try {
      final String googleUrl =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=${ApiKeys.googleMapsKey}';
      final response = await http.get(Uri.parse(googleUrl)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          debugPrint('[FARE_DEBUG] Google Geocoded "$query" => Lat: $lat, Lng: $lng');
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('[FARE_DEBUG] Google Geocoding error for "$query": $e');
    }

    // 2. Try Nominatim (OpenStreetMap) free dynamic geocoding fallback
    try {
      final String nominatimUrl =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1';
      final response = await http.get(
        Uri.parse(nominatimUrl),
        headers: {'User-Agent': 'FleetGoApp/1.0'},
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lng = double.parse(data[0]['lon'].toString());
          debugPrint('[FARE_DEBUG] Nominatim Geocoded "$query" => Lat: $lat, Lng: $lng');
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('[FARE_DEBUG] Nominatim Geocoding error for "$query": $e');
    }

    debugPrint('[FARE_DEBUG] Could not geocode address: "$query"');
    return null;
  }

  Future<void> _fetchFareEstimates() async {
    setState(() {
      _isLoadingFares = true;
    });

    try {
      final pickupAddress = widget.pickupAddress;
      final dropAddress = widget.destinationAddress;

      if (pickupAddress == null || dropAddress == null) {
        setState(() {
          _isLoadingFares = false;
        });
        return;
      }

      final LatLng? pickupLatLng = widget.pickupLatLng ?? await _getLatLngFromAddress(pickupAddress);
      final LatLng? dropLatLng = widget.destinationLatLng ?? await _getLatLngFromAddress(dropAddress);

      debugPrint('====================================================');
      debugPrint('[FARE_DEBUG] 1. Pickup Location  : "$pickupAddress"');
      debugPrint('[FARE_DEBUG]    Pickup Coordinates: (${pickupLatLng?.latitude}, ${pickupLatLng?.longitude})');
      debugPrint('[FARE_DEBUG] 2. Drop Location    : "$dropAddress"');
      debugPrint('[FARE_DEBUG]    Drop Coordinates  : (${dropLatLng?.latitude}, ${dropLatLng?.longitude})');
      debugPrint('====================================================');

      if (pickupLatLng != null && dropLatLng != null) {
        final categoriesResponse = await ApiService.to.get(
          ApiEndpoints.vehicleCategories,
          queryParameters: {
            'latitude': pickupLatLng.latitude,
            'longitude': pickupLatLng.longitude,
          },
        );
        final categoriesData = categoriesResponse.data is Map
            ? categoriesResponse.data['data'] ?? categoriesResponse.data
            : categoriesResponse.data;
        final rawCategories = categoriesData is List
            ? categoriesData
            : categoriesData is Map && categoriesData['items'] is List
            ? categoriesData['items'] as List
            : <dynamic>[];

        // Map categories dynamically supporting both known enums and admin-created dynamic categories
        final List<Map<String, dynamic>> categories = [];
        for (var cat in rawCategories) {
          if (cat is Map) {
            final vCat = VehicleCategory.fromJson(Map<String, dynamic>.from(cat));
            final String displayName = vCat.displayName;
            final String imagePath = (vCat.iconUrl != null && vCat.iconUrl!.trim().isNotEmpty)
                ? vCat.iconUrl!.trim()
                : ((vCat.imageUrl != null && vCat.imageUrl!.trim().isNotEmpty)
                    ? vCat.imageUrl!.trim()
                    : vCat.assetPath);
            final String catEnum = vCat.slug.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

            categories.add({
              ...Map<String, dynamic>.from(cat),
              'id': vCat.id.isNotEmpty ? vCat.id : cat['id'],
              'vehicleCategoryEnum': catEnum,
              'displayName': displayName,
              'imagePath': imagePath,
              'isAvailable': vCat.isAvailable,
              'availability': vCat.isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
            });
          }
        }

        if (categories.isNotEmpty) {
          List<Map<String, dynamic>> options = [];
          String? errorMessage;
          try {
            debugPrint('[FARE_DEBUG] Sending API Request Payload to ${ApiEndpoints.fareEstimate}:');
            debugPrint('[FARE_DEBUG]   Pickup: ${pickupLatLng.latitude}, ${pickupLatLng.longitude} ("$pickupAddress")');
            debugPrint('[FARE_DEBUG]   Drop  : ${dropLatLng.latitude}, ${dropLatLng.longitude} ("$dropAddress")');

            final batchResponse = await ApiService.to.post(
              ApiEndpoints.fareEstimate,
              body: {
                'pickup': {
                  'latitude': pickupLatLng.latitude,
                  'longitude': pickupLatLng.longitude,
                  'address': pickupAddress,
                },
                'drop': {
                  'latitude': dropLatLng.latitude,
                  'longitude': dropLatLng.longitude,
                  'address': dropAddress,
                },
              },
            );
            final batchRaw = batchResponse.data is Map
                ? batchResponse.data['data'] ?? batchResponse.data
                : batchResponse.data;
            final batchList = batchRaw is List
                ? batchRaw
                : (batchRaw is Map && (batchRaw['estimateId'] != null || batchRaw['id'] != null) ? [batchRaw] : []);

            if (batchList.isNotEmpty) {
              final Map<String, Map<String, dynamic>> estimateMap = {};
              for (var item in batchList) {
                if (item is Map && item['categoryId'] != null) {
                  estimateMap[item['categoryId'].toString()] =
                      Map<String, dynamic>.from(item);
                }
              }
              for (var category in categories) {
                final catId = (category['id'] ?? category['vehicleCategoryEnum']).toString();
                final est = estimateMap[catId];
                if (est != null) {
                  options.add(<String, dynamic>{
                    ...category,
                    ...est,
                    'categoryId': catId,
                    'fareEstimateId': (est['id'] ?? est['estimateId'])?.toString(),
                    'name': category['displayName'],
                    'imagePath': category['imagePath'],
                    'isAvailable': true,
                  });
                }
              }
            } else if (batchResponse.data is Map && batchResponse.data['message'] != null) {
              errorMessage = batchResponse.data['message'].toString();
            }
          } catch (e) {
            debugPrint('[FARE_DEBUG] Fare estimate API call failed: $e');
            if (e is ApiException) {
              errorMessage = e.message;
            } else {
              errorMessage = e.toString();
            }
          }

          debugPrint('====================================================');
          debugPrint('[FARE_DEBUG] Computed ${options.length} Available Dynamic Fare Options:');
          for (var opt in options) {
            final fVal = opt['total'] ?? opt['totalFare'] ?? opt['subtotal'] ?? opt['price'] ?? opt['minimumFare'];
            debugPrint('[FARE_DEBUG]   - ${opt['name']}: ₹$fVal (Distance: ${opt['distance']}m, Duration: ${opt['duration']}s)');
          }
          debugPrint('====================================================');

          int targetIndex = 0;
          if (widget.selectedCategoryId != null || widget.selectedCategory != null) {
            final targetId = (widget.selectedCategoryId ?? '').toString().trim().toLowerCase();
            final targetName = (widget.selectedCategory ?? '').toString().trim().toLowerCase();

            for (int i = 0; i < options.length; i++) {
              final opt = options[i];
              final catId = (opt['categoryId'] ?? opt['id'] ?? '').toString().trim().toLowerCase();
              final catName = (opt['name'] ?? opt['displayName'] ?? opt['slug'] ?? opt['vehicleCategoryEnum'] ?? '').toString().trim().toLowerCase();
              final enumVal = (opt['vehicleCategoryEnum'] ?? '').toString().trim().toLowerCase();

              if ((targetId.isNotEmpty && (catId == targetId || enumVal == targetId)) ||
                  (targetName.isNotEmpty && (catName == targetName || enumVal == targetName || catName.contains(targetName) || targetName.contains(catName)))) {
                targetIndex = i;
                break;
              }
            }
          }

          setState(() {
            _fareEstimates = options;
            _selectedRideIndex = targetIndex;
            _isLoadingFares = false;
          });

          if (options.isEmpty) {
            debugPrint('No drivers available in this location.');
            _showNoDriversModal(
              context,
              errorMessage ?? 'No drivers available in your area at the moment. Please try again later.',
            );
          }
          return;
        } else {
          setState(() {
            _fareEstimates = [];
            _isLoadingFares = false;
          });
          debugPrint('No vehicle categories available.');
          _showNoDriversModal(
            context,
            'No drivers available in your area at the moment. Please try again later.',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching fare estimates: $e');
    }

    setState(() {
      _isLoadingFares = false;
    });
  }

  Map<String, String> _selectedRideDetails() {
    final fallback = {
      'carType': 'AUTO',
      'carName': 'Auto',
      'vehicleType': 'AUTO',
      'categoryId': '',
    };

    if (_fareEstimates.isEmpty || _selectedRideIndex >= _fareEstimates.length) {
      return fallback;
    }

    final estimate = _fareEstimates[_selectedRideIndex];
    if (estimate is! Map) return fallback;

    final String name = (estimate['name'] ?? estimate['displayName'] ?? estimate['title'] ?? 'Ride').toString();
    final String catId = (estimate['categoryId'] ?? estimate['id'] ?? estimate['vehicleCategoryId'] ?? '').toString();
    final String brandId = (estimate['brandId'] ?? estimate['brand_id'] ?? '').toString();
    final String modelId = (estimate['modelId'] ?? estimate['model_id'] ?? '').toString();
    final String slug = (estimate['slug'] ?? name.toLowerCase()).toString();

    return {
      'carType': slug.toUpperCase(),
      'carName': name,
      'vehicleType': slug.toUpperCase(),
      'categoryId': catId,
      if (brandId.isNotEmpty) 'brandId': brandId,
      if (modelId.isNotEmpty) 'modelId': modelId,
      if (estimate['fareEstimateId'] != null)
        'fareEstimateId': estimate['fareEstimateId'].toString(),
    };
  }

  String _generateUuidV4() {
    final math.Random random = math.Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xx
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String _bookingConflictMessage(ApiException error) {
    final body = error.responseBody;
    if (body is Map && body['message'] is String) {
      final message = body['message'].toString().trim();
      if (message.isNotEmpty) return message;
    }

    final message = AppUtils.extractErrorMessage(error).trim();
    return message.isNotEmpty
        ? message
        : 'You already have an active booking session.';
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _markers.clear();
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.5,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  void _editLocations() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocationSearchScreen(initialPickupLocation: widget.pickupAddress),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Live Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.7041, 77.1025), // Default to Delhi
                zoom: 15.5,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_currentPosition != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15.5,
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          // Floating title over the map (no AppBar)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12.h,
            left: 2.w,
            right: 16.w,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 26.w,
                    minHeight: 32.w,
                  ),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.black,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 0),
                Text(
                  'Choose a Ride',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),

          // Top Floating Address Card
          Positioned(
            top: MediaQuery.paddingOf(context).top + 62.h,
            left: 16.w,
            right: 16.w,
            child: GestureDetector(
              onTap: _editLocations,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFEEEEEE),
                    width: 1.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const RouteMarkerTimeline(connectorHeight: 46),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAddressField(
                            label: 'Pick-up Location',
                            address:
                                widget.pickupAddress ??
                                'Current Location',
                          ),
                          Divider(
                            height: 4.h,
                            thickness: 1,
                            color: const Color(0xFFF1F5F9),
                          ),
                          _buildAddressField(
                            label: 'Your Destination',
                            address:
                                widget.destinationAddress ??
                                'Select Destination',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.edit_outlined,
                      color: const Color(0xFFF4B41A),
                      size: 20.sp,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(top: 5.h, bottom: 4.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      'Select your Ride',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),

                  // Rides List
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 320.h),
                      child: _isLoadingFares
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFF4B41A),
                              ),
                            )
                          : _fareEstimates.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'No vehicles available at the moment.',
                                    style: AppFonts.bodyText,
                                  ),
                                  SizedBox(height: 10.h),
                                  ElevatedButton(
                                    onPressed: _fetchFareEstimates,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF4B41A),
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24.w,
                                        vertical: 12.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Try Again',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              itemCount: _fareEstimates.length,
                              itemBuilder: (context, index) {
                                final estimate = _fareEstimates[index];
                                String name =
                                    estimate['name']?.toString() ??
                                    estimate['carType']?.toString() ??
                                    'CAB';
                                if (name.toUpperCase() == 'AUTO') name = 'AUTO';

                                final rawDuration = estimate['duration'];
                                String durationStr = '5 min away';
                                if (rawDuration != null) {
                                  num dNum = num.tryParse(rawDuration.toString()) ?? 0;
                                  if (dNum > 120) {
                                    durationStr = '${(dNum / 60).round()} min away';
                                  } else if (dNum > 0) {
                                    durationStr = '$dNum min away';
                                  }
                                }

                                final rawDistance = estimate['distance'];
                                String distanceStr = '';
                                if (rawDistance != null) {
                                  num distNum = num.tryParse(rawDistance.toString()) ?? 0;
                                  if (distNum > 0) {
                                    distanceStr = '${(distNum / 1000).toStringAsFixed(1)} km';
                                  }
                                }

                                final availability = estimate['availability']?.toString().toUpperCase() ?? 'AVAILABLE';
                                final isAvailable = availability == 'AVAILABLE';
                                final availabilityText = isAvailable ? 'Available' : 'Busy';

                                final fareVal = estimate['total'] ??
                                    estimate['totalFare'] ??
                                    estimate['subtotal'] ??
                                    estimate['price'] ??
                                    estimate['fare'] ??
                                    estimate['minimumFare'] ??
                                    '0';
                                final fare = (fareVal is num)
                                    ? fareVal.toStringAsFixed(0)
                                    : fareVal.toString();

                                final timeSubtext = distanceStr.isNotEmpty
                                    ? '$durationStr ($distanceStr)'
                                    : durationStr;

                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: _buildRideCard(
                                    index: index,
                                    title: name,
                                    time: timeSubtext,
                                    dropTime: availabilityText,
                                    price: '₹$fare',
                                    imagePath:
                                        estimate['imagePath']?.toString() ??
                                        'assets/images/car1.png',
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  // Trip Type Selection (One Way / Return)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFF4B41A).withValues(alpha: 0.2),
                          width: 1.w,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Trip Type',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _tripType = 'ONE_WAY';
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: _tripType == 'ONE_WAY' ? const Color(0xFFF4B41A) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      child: Text(
                                        'One Way',
                                        style: TextStyle(
                                          fontFamily: AppFonts.fontFamily,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: _tripType == 'ONE_WAY' ? Colors.black : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _tripType = 'RETURN';
                                      });
                                      if (_returnDateTime == null) {
                                        _pickReturnDateTime();
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: _tripType == 'RETURN' ? const Color(0xFFF4B41A) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      child: Text(
                                        'Return',
                                        style: TextStyle(
                                          fontFamily: AppFonts.fontFamily,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: _tripType == 'RETURN' ? Colors.black : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_tripType == 'RETURN') ...[
                          SizedBox(height: 10.h),
                          InkWell(
                            onTap: _pickReturnDateTime,
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFFF4B41A).withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_repeat_rounded, color: const Color(0xFFD97706), size: 18.sp),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      _returnDateTime == null
                                          ? 'Select Return Date & Time'
                                          : 'Return: ${_formatScheduledAt(_returnDateTime!)}',
                                      style: TextStyle(
                                        fontFamily: AppFonts.fontFamily,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.edit_calendar_rounded, color: const Color(0xFFD97706), size: 18.sp),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Payment Method Section with Cream/Yellow theme
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFF4B41A).withValues(alpha: 0.2),
                          width: 1.w,
                        ),
                        bottom: BorderSide(
                          color: const Color(0xFFF4B41A).withValues(alpha: 0.2),
                          width: 1.w,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Method',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        PopupMenuButton<String>(
                          initialValue: _selectedPaymentMethod,
                          onSelected: (String value) {
                            setState(() {
                              _selectedPaymentMethod = value;
                            });
                          },
                          offset: Offset(0, 36.h),
                          elevation: 3,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'CASH',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    color: const Color(0xFFD97706),
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Cash',
                                    style: TextStyle(
                                      fontFamily: AppFonts.fontFamily,
                                      fontSize: 14.sp,
                                      fontWeight: _selectedPaymentMethod == 'CASH'
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  if (_selectedPaymentMethod == 'CASH') ...[
                                    SizedBox(width: 12.w),
                                    Icon(
                                      Icons.check_rounded,
                                      color: const Color(0xFFD97706),
                                      size: 18.sp,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem<String>(
                              value: 'ONLINE',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: const Color(0xFFD97706),
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      fontFamily: AppFonts.fontFamily,
                                      fontSize: 14.sp,
                                      fontWeight: _selectedPaymentMethod == 'ONLINE'
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  if (_selectedPaymentMethod == 'ONLINE') ...[
                                    SizedBox(width: 12.w),
                                    Icon(
                                      Icons.check_rounded,
                                      color: const Color(0xFFD97706),
                                      size: 18.sp,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: const Color(0xFFF4B41A).withValues(alpha: 0.5),
                                width: 1.w,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedPaymentMethod == 'CASH'
                                      ? Icons.payments_rounded
                                      : Icons.account_balance_wallet_rounded,
                                  color: const Color(0xFFD97706),
                                  size: 20.sp,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  _selectedPaymentMethod == 'CASH' ? 'Cash' : 'Online',
                                  style: TextStyle(
                                    fontFamily: AppFonts.fontFamily,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: const Color(0xFF111827),
                                  size: 22.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Continue / Schedule Button Bar
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF4B41A),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                                onPressed: _fareEstimates.isNotEmpty && !_isLoadingFares
                                    ? () async {
                                        final bool isScheduleBooking = widget.isScheduled || _scheduledAt != null;
                                        if (_tripType == 'RETURN') {
                                          final baseTime = _scheduledAt ?? DateTime.now();
                                          final minReturnAllowed = baseTime.add(const Duration(minutes: 20));
                                          if (_returnDateTime == null || _returnDateTime!.isBefore(minReturnAllowed)) {
                                            if (_returnDateTime != null && _returnDateTime!.isBefore(minReturnAllowed)) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const Text('Return time must be after the outbound ride time.'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                            if (!await _pickReturnDateTime()) {
                                              return;
                                            }
                                          }
                                        }
                                        if (isScheduleBooking) {
                                          final minAllowed = DateTime.now().add(const Duration(minutes: 15));
                                          if (_scheduledAt == null || _scheduledAt!.isBefore(minAllowed)) {
                                            if (_scheduledAt != null && _scheduledAt!.isBefore(minAllowed)) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Scheduled time must be at least 15 to 20 minutes in the future.'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                            if (!await _pickScheduledAt()) {
                                              return;
                                            }
                                          }
                                        }
                                        if (!mounted) return;
                                        // Show loading dialog
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFFF4B41A),
                                            ),
                                          ),
                                        );

                                        String? tripId;
                                        try {
                                          final pickupAddress = widget.pickupAddress;
                                          final dropAddress = widget.destinationAddress;
                                          final pickupLatLng =
                                              await _getLatLngFromAddress(
                                                pickupAddress ?? '',
                                              );
                                          final dropLatLng =
                                              await _getLatLngFromAddress(
                                                dropAddress ?? '',
                                              );
                                          final selectedRide = _selectedRideDetails();

                                          // Generate a fresh UUID v4 right before the booking attempt
                                          final String idempotencyKey = _generateUuidV4();
                                          debugPrint('[BOOKING_DEBUG] Generated fresh x-idempotency-key: $idempotencyKey');

                                          final body = <String, dynamic>{
                                            'pickup': {
                                              'address': pickupAddress ?? 'Delhi',
                                              'latitude':
                                                  pickupLatLng?.latitude ?? 28.6276,
                                              'longitude':
                                                  pickupLatLng?.longitude ?? 77.3820,
                                            },
                                            'drop': {
                                              'address': dropAddress ?? 'Delhi',
                                              'latitude':
                                                  dropLatLng?.latitude ?? 28.5244,
                                              'longitude':
                                                  dropLatLng?.longitude ?? 77.2173,
                                            },
                                            'categoryId': selectedRide['categoryId'],
                                            'vehicleCategoryId': selectedRide['categoryId'],
                                             if (selectedRide['brandId'] != null && selectedRide['brandId']!.isNotEmpty)
                                               'brandId': selectedRide['brandId'],
                                             if (selectedRide['modelId'] != null && selectedRide['modelId']!.isNotEmpty)
                                               'modelId': selectedRide['modelId'],
                                            'fareEstimateId':
                                                selectedRide['fareEstimateId'],
                                            'paymentMethod': _selectedPaymentMethod,
                                            'idempotencyKey': idempotencyKey,
                                            'rideType': _tripType,
                                            'tripType': _tripType,
                                            if (_tripType == 'RETURN' && _returnDateTime != null)
                                              'returnDateTime': _returnDateTime!
                                                  .toUtc()
                                                  .toIso8601String(),
                                            if (isScheduleBooking && _scheduledAt != null)
                                              'scheduledAt': _scheduledAt!
                                                  .toUtc()
                                                  .toIso8601String(),
                                          };

                                          dynamic response;
                                          int retries = 3;
                                          while (retries > 0) {
                                            try {
                                              response = await ApiService.to.post(
                                                isScheduleBooking
                                                    ? ApiEndpoints.scheduledBooking
                                                    : ApiEndpoints.bookings,
                                                headers: {
                                                  'x-idempotency-key': idempotencyKey,
                                                },
                                                body: body,
                                              );
                                              if (response.statusCode == 200 ||
                                                  response.statusCode == 201) {
                                                break;
                                              }
                                            } on ApiException catch (e) {
                                              if (e.statusCode == 409) {
                                                if (mounted) {
                                                  // ignore: use_build_context_synchronously
                                                  Navigator.pop(context);
                                                  final recovered =
                                                      await ActiveBookingRecoveryService
                                                          .fetchAndResume(
                                                    // ignore: use_build_context_synchronously
                                                    context,
                                                    showMessage: true,
                                                  );
                                                  if (!mounted) return;
                                                  if (!recovered) {
                                                    AppUtils.showSnackBar(
                                                      // ignore: use_build_context_synchronously
                                                      context,
                                                      _bookingConflictMessage(e),
                                                      isError: true,
                                                    );
                                                  }
                                                }
                                                return;
                                              }

                                              retries--;
                                              if (retries == 0) rethrow;
                                              await Future.delayed(
                                                const Duration(milliseconds: 500),
                                              );
                                            } catch (e) {
                                              retries--;
                                              if (retries == 0) rethrow;
                                              await Future.delayed(
                                                const Duration(milliseconds: 500),
                                              );
                                            }
                                          }

                                          if (mounted) {
                                            Navigator.pop(context); // hide loading
                                          }

                                          if (response != null &&
                                              (response.statusCode == 200 ||
                                                  response.statusCode == 201)) {
                                            // Asynchronously auto-save pickup and destination as recent addresses (non-blocking)
                                            _autoSaveRecentRideAddresses(
                                              pickupAddress: pickupAddress,
                                              pickupLatLng: pickupLatLng,
                                              dropAddress: dropAddress,
                                              dropLatLng: dropLatLng,
                                            );

                                            final data = response.data;
                                            tripId =
                                                data['booking']?['id']?.toString() ??
                                                data['booking']?['_id']?.toString() ??
                                                data['data']?['id']?.toString() ??
                                                data['data']?['_id']?.toString() ??
                                                data['id']?.toString() ??
                                                data['_id']?.toString();

                                            if (_tripType == 'RETURN' && mounted) {
                                              await _showReturnBookingSuccessDialog(data);
                                            }
                                            if (isScheduleBooking && mounted) {
                                              debugPrint('\n========== SCHEDULED RIDE CREATED ==========');
                                              debugPrint('[USER][SCHEDULED][CREATED] Booking ID: $tripId | ScheduledAt: ${_scheduledAt?.toIso8601String()}');
                                              debugPrint('=============================================\n');
                                              await showDialog<void>(
                                                context: context,
                                                builder: (dialogContext) => Dialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20.r),
                                                  ),
                                                  elevation: 10,
                                                  backgroundColor: Colors.white,
                                                  child: Padding(
                                                    padding: EdgeInsets.all(24.r),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: EdgeInsets.all(16.r),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFFF9E6),
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                              color: const Color(0xFFF4B41A),
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                          child: Icon(
                                                            Icons.event_available_rounded,
                                                            color: const Color(0xFFD97706),
                                                            size: 36.sp,
                                                          ),
                                                        ),
                                                        SizedBox(height: 18.h),
                                                        Text(
                                                          'Ride Scheduled!',
                                                          style: TextStyle(
                                                            fontFamily: AppFonts.fontFamily,
                                                            fontSize: 19.sp,
                                                            fontWeight: FontWeight.bold,
                                                            color: const Color(0xFF111827),
                                                          ),
                                                        ),
                                                        SizedBox(height: 8.h),
                                                        Text(
                                                          'Your ride is scheduled for\n${_formatScheduledAt(_scheduledAt!)}.',
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontFamily: AppFonts.fontFamily,
                                                            fontSize: 13.5.sp,
                                                            color: const Color(0xFF4B5563),
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                        SizedBox(height: 22.h),
                                                        SizedBox(
                                                          width: double.infinity,
                                                          height: 44.h,
                                                          child: ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(dialogContext),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: const Color(0xFFF4B41A),
                                                              elevation: 0,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(12.r),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Done',
                                                              style: TextStyle(
                                                                fontFamily: AppFonts.fontFamily,
                                                                fontSize: 15.sp,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.black,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                              if (mounted) {
                                                Navigator.of(
                                                  context,
                                                ).popUntil((route) => route.isFirst);
                                              }
                                            } else if (tripId != null && mounted) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      LookingForRideScreen(
                                                         tripId: tripId!,
                                                         vehicleCategory: VehicleCategory.fromString((selectedRide["vehicleCategoryEnum"] ?? selectedRide["name"] ?? selectedRide["displayName"] ?? selectedRide["slug"] ?? selectedRide["categoryId"])?.toString()),
                                                         vehicleCategoryName: (selectedRide["displayName"] ?? selectedRide["name"])?.toString(),
                                                       ),
                                                ),
                                              );
                                            }
                                          } else {
                                            if (mounted) {
                                              final is409 = response?.statusCode == 409;
                                              String msg = 'Failed to book ride';
                                              final responseData =
                                                  response?.data;
                                              if (responseData is Map &&
                                                  responseData['message'] !=
                                                      null) {
                                                msg = responseData['message']
                                                    .toString();
                                              } else if (is409) {
                                                msg =
                                                    'You already have an active booking session.';
                                              }

                                              if (is409) {
                                                if (mounted) {
                                                  final recovered =
                                                      await ActiveBookingRecoveryService
                                                          .fetchAndResume(
                                                    // ignore: use_build_context_synchronously
                                                    context,
                                                    showMessage: true,
                                                  );
                                                  if (!mounted) return;
                                                  if (!recovered) {
                                                    AppUtils.showSnackBar(
                                                      // ignore: use_build_context_synchronously
                                                      context,
                                                      msg,
                                                      isError: true,
                                                    );
                                                  }
                                                }
                                                return;
                                              }
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(msg),
                                                  backgroundColor: is409 ? Colors.orange.shade800 : Colors.redAccent,
                                                  duration: const Duration(seconds: 4),
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            Navigator.pop(context); // hide loading
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      }
                                    : null,
                                child: Text(
                                  (widget.isScheduled || _scheduledAt != null)
                                      ? _scheduledAt == null
                                            ? 'Select Date & Schedule'
                                            : 'Schedule Ride'
                                      : _tripType == 'RETURN' ? 'Book Return Trip' : 'Continue',
                                  style: TextStyle(
                                    fontFamily: AppFonts.fontFamily,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF000000),
                                  ),
                                ),
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
    );
  }

  Widget _buildAddressField({required String label, required String address}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: _addressLabelFontSize.sp,
              fontWeight: _addressLabelFontWeight,
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: _addressValueFontSize.sp,
              fontWeight: _addressValueFontWeight,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard({
    required int index,
    required String title,
    required String time,
    required String dropTime,
    required String price,
    String? oldPrice,
    required String imagePath,
  }) {
    bool isSelected = _selectedRideIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRideIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF4B41A)
                : const Color(0xFFEEEEEE),
            width: isSelected ? 1.5.w : 1.w,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF4B41A).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Car Image Box
            Container(
              width: 58.w,
              height: 58.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                child: imagePath.startsWith('http://') || imagePath.startsWith('https://')
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.directions_car_rounded,
                          color: const Color(0xFFF4B41A),
                          size: 26.sp,
                        ),
                      )
                    : Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.directions_car_rounded,
                          color: const Color(0xFFF4B41A),
                          size: 26.sp,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 14.w),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          dropTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Price Column with FittedBox protection
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 100.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (oldPrice != null)
                          Icon(
                            Icons.local_offer,
                            color: const Color(0xFFF4B41A),
                            size: 14.sp,
                          ),
                        if (oldPrice != null) SizedBox(width: 4.w),
                        Text(
                          price,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    if (oldPrice != null)
                      Text(
                        oldPrice,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 11.sp,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _autoSaveRecentRideAddresses({
    String? pickupAddress,
    LatLng? pickupLatLng,
    String? dropAddress,
    LatLng? dropLatLng,
  }) {
    Future.microtask(() async {
      try {
        final recentService = RecentLocationService();
        final addressService = CustomerAddressService();

        if (pickupAddress != null && pickupAddress.trim().isNotEmpty && pickupLatLng != null) {
          final pickupModel = RecentLocationModel(
            title: 'Pickup',
            address: pickupAddress.trim(),
            latitude: pickupLatLng.latitude,
            longitude: pickupLatLng.longitude,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          await recentService.addRecentLocation(pickupModel);
          await addressService.saveRecentAddress(
            addressLine: pickupAddress.trim(),
            latitude: pickupLatLng.latitude,
            longitude: pickupLatLng.longitude,
            label: 'Pickup',
          );
        }

        if (dropAddress != null && dropAddress.trim().isNotEmpty && dropLatLng != null) {
          final dropModel = RecentLocationModel(
            title: 'Destination',
            address: dropAddress.trim(),
            latitude: dropLatLng.latitude,
            longitude: dropLatLng.longitude,
            timestamp: DateTime.now().millisecondsSinceEpoch + 1,
          );
          await recentService.addRecentLocation(dropModel);
          await addressService.saveRecentAddress(
            addressLine: dropAddress.trim(),
            latitude: dropLatLng.latitude,
            longitude: dropLatLng.longitude,
            label: 'Destination',
          );
        }
      } catch (e) {
        debugPrint('[RECENT_ADDRESS_AUTO_SAVE] Non-blocking error: $e');
      }
    });
  }
}