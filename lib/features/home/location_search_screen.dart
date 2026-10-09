import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/utils.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_keys.dart';
import '../../constants/app_fonts.dart';
import '../../models/recent_location_model.dart';
import '../../models/saved_address_model.dart';
import '../../services/recent_location_service.dart';
import '../../services/customer_address_service.dart';
import '../rides/choose_ride_screen.dart';
import '../../widgets/location_route_markers.dart';

class LocationSearchScreen extends StatefulWidget {
  final String? initialPickupLocation;
  final bool isScheduled;
  final String? selectedCategory;
  final String? selectedCategoryId;

  const LocationSearchScreen({
    super.key,
    this.initialPickupLocation,
    this.isScheduled = false,
    this.selectedCategory,
    this.selectedCategoryId,
  });

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropFocusNode = FocusNode();

  final RecentLocationService _recentLocationService = RecentLocationService();
  final CustomerAddressService _customerAddressService = CustomerAddressService();

  List<dynamic> _placeSuggestions = [];
  List<RecentLocationModel> _recentDropoffLocations = [];
  List<SavedAddressModel> _savedAddresses = [];
  bool _isGettingCurrentLocation = false;
  bool _isLoadingRecentLocations = false;
  bool _isLoadingSavedAddresses = false;

  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  late bool _isScheduled;

  @override
  void initState() {
    super.initState();
    _isScheduled = widget.isScheduled;
    final initialPickupLocation = widget.initialPickupLocation;
    if (initialPickupLocation != null && initialPickupLocation.isNotEmpty) {
      _pickupController.text = initialPickupLocation;
    } else {
      _useCurrentLocation();
    }
    _loadRecentDropoffLocations();
    _loadSavedAddresses();

    _dropFocusNode.addListener(_onDropFocusChange);
  }

  void _onDropFocusChange() {
    if (_dropFocusNode.hasFocus && _dropController.text.isEmpty) {
      _loadRecentDropoffLocations();
    }
  }

  Future<void> _loadRecentDropoffLocations() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecentLocations = true;
    });

    try {
      final localList = await _recentLocationService.getRecentLocations();
      List<Map<String, dynamic>> apiMaps = [];
      try {
        apiMaps = await _customerAddressService.fetchRecentAddresses();
      } catch (e) {
        debugPrint('API recent addresses fetch error (falling back to local cache): $e');
      }

      final List<RecentLocationModel> apiList = apiMaps
          .map((m) => RecentLocationModel.fromJson(m))
          .toList();

      final List<RecentLocationModel> merged = [...apiList];
      for (final loc in localList) {
        if (!merged.any((existing) => existing.isSameLocation(loc))) {
          merged.add(loc);
        }
      }
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _recentDropoffLocations = merged.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent dropoff locations: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecentLocations = false;
        });
      }
    }
  }

  Future<void> _loadSavedAddresses() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSavedAddresses = true;
    });

    try {
      final list = await _customerAddressService.fetchSavedAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved addresses: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSavedAddresses = false;
        });
      }
    }
  }

  /// Handles selection of a Google Place prediction item.
  Future<void> _selectPlaceSuggestion(Map<String, dynamic> place) async {
    final structuredFormatting =
        place['structured_formatting'] as Map<String, dynamic>?;
    final mainText =
        structuredFormatting?['main_text'] ?? place['description'] ?? 'Location';
    final secondaryText = structuredFormatting?['secondary_text'] ?? '';
    final fullDescription =
        place['description'] ?? (secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText);
    final placeId = place['place_id']?.toString();

    final isForDrop = _dropFocusNode.hasFocus ||
        (_pickupController.text.isNotEmpty && _dropController.text.isEmpty);

    // Fetch place details or geocode coordinates
    LatLng? locationLatLng = await _fetchLatLngForPlace(placeId: placeId, address: fullDescription);

    if (isForDrop) {
      _dropController.text = fullDescription;
      _dropLatLng = locationLatLng;
      _dropFocusNode.unfocus();

      if (locationLatLng != null) {
        // Save to Recent Locations ONLY when explicitly selected
        final newRecent = RecentLocationModel(
          title: mainText,
          address: fullDescription,
          latitude: locationLatLng.latitude,
          longitude: locationLatLng.longitude,
          placeId: placeId,
        );
        final updatedList = await _recentLocationService.addRecentLocation(newRecent);
        if (mounted) {
          setState(() {
            _recentDropoffLocations = updatedList;
          });
        }
      }

      if (_pickupController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_pickupFocusNode);
      }
    } else {
      _pickupController.text = fullDescription;
      _pickupLatLng = locationLatLng;
      _pickupFocusNode.unfocus();

      if (_dropController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_dropFocusNode);
      }
    }

    setState(() {
      _placeSuggestions = [];
    });

    _checkAndNavigateToRide();
  }

  /// Selects a recent drop-off location directly without Google API calls.
  Future<void> _selectRecentLocation(RecentLocationModel recent) async {
    final locationText = recent.address.isNotEmpty ? recent.address : recent.title;
    _dropController.text = locationText;
    _dropLatLng = LatLng(recent.latitude, recent.longitude);
    _dropFocusNode.unfocus();

    // Re-save/promote to top of recent list
    final updatedList = await _recentLocationService.addRecentLocation(recent);
    if (mounted) {
      setState(() {
        _recentDropoffLocations = updatedList;
        _placeSuggestions = [];
      });
    }

    if (_pickupController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_pickupFocusNode);
    } else {
      _checkAndNavigateToRide();
    }
  }

  /// Selects a saved customer address (Home, Work, etc.).
  Future<void> _selectSavedAddress(SavedAddressModel saved) async {
    final locationText = saved.addressLine;
    _dropController.text = locationText;
    _dropLatLng = LatLng(saved.latitude, saved.longitude);
    _dropFocusNode.unfocus();

    // Also add to recent dropoff locations
    final recent = RecentLocationModel(
      title: saved.label,
      address: saved.addressLine,
      latitude: saved.latitude,
      longitude: saved.longitude,
    );
    final updatedList = await _recentLocationService.addRecentLocation(recent);
    if (mounted) {
      setState(() {
        _recentDropoffLocations = updatedList;
        _placeSuggestions = [];
      });
    }

    if (_pickupController.text.isEmpty) {
      FocusScope.of(context).requestFocus(_pickupFocusNode);
    } else {
      _checkAndNavigateToRide();
    }
  }

  void _checkAndNavigateToRide() {
    if (_pickupController.text.isNotEmpty && _dropController.text.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChooseRideScreen(
            pickupAddress: _pickupController.text,
            destinationAddress: _dropController.text,
            pickupLatLng: _pickupLatLng,
            destinationLatLng: _dropLatLng,
            isScheduled: _isScheduled,
            selectedCategory: widget.selectedCategory,
            selectedCategoryId: widget.selectedCategoryId,
          ),
        ),
      );
    }
  }

  Future<LatLng?> _fetchLatLngForPlace({String? placeId, required String address}) async {
    if (placeId != null && placeId.isNotEmpty) {
      try {
        final String detailsUrl =
            'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=${ApiKeys.googleMapsKey}';
        final res = await http.get(Uri.parse(detailsUrl));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == 'OK' && data['result'] != null) {
            final location = data['result']['geometry']?['location'];
            if (location != null && location['lat'] != null && location['lng'] != null) {
              return LatLng(
                (location['lat'] as num).toDouble(),
                (location['lng'] as num).toDouble(),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching place details: $e');
      }
    }

    // Fallback to Geocoding API if place details fails or no placeId
    try {
      final String geocodeUrl =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=${ApiKeys.googleMapsKey}';
      final res = await http.get(Uri.parse(geocodeUrl));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && data['results'] is List && (data['results'] as List).isNotEmpty) {
          final location = data['results'][0]['geometry']?['location'];
          if (location != null && location['lat'] != null && location['lng'] != null) {
            return LatLng(
              (location['lat'] as num).toDouble(),
              (location['lng'] as num).toDouble(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error geocoding address: $e');
    }

    return null;
  }

  Future<void> _getPlaceSuggestions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _placeSuggestions = [];
      });
      return;
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=${ApiKeys.googleMapsKey}&components=country:in';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _placeSuggestions = data['predictions'] ?? [];
          });
        } else {
          debugPrint(
            'Google API Error: ${data['status']} - ${data['error_message']}',
          );
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching places: $e');
    }
  }

  Future<void> _useCurrentLocation({bool forceDrop = false}) async {
    if (_isGettingCurrentLocation) return;

    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocation('Location services disabled', forceDrop: forceDrop);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocation('Location permission denied', forceDrop: forceDrop);
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocation('Location permission permanently denied', forceDrop: forceDrop);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final currentLatLng = LatLng(position.latitude, position.longitude);
      if (forceDrop) {
        _dropLatLng = currentLatLng;
      } else {
        _pickupLatLng = currentLatLng;
      }
      final address = await _getAddressFromLatLng(position);
      _setLocation(address, forceDrop: forceDrop);
    } catch (e) {
      _setLocation('Unable to get current location', forceDrop: forceDrop);
    } finally {
      if (mounted) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
      }
    }
  }

  Future<String> _getAddressFromLatLng(Position position) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=${ApiKeys.googleMapsKey}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final formattedAddress =
            data['results'][0]['formatted_address'] as String;
        return AppUtils.cleanGeocodedAddress(formattedAddress);
      }
    }

    return 'Current Location';
  }

  void _setLocation(String locationName, {bool forceDrop = false}) {
    if (!mounted) return;

    final isForDrop = forceDrop ||
        _dropFocusNode.hasFocus ||
        (_pickupController.text.isNotEmpty && _dropController.text.isEmpty);

    if (isForDrop) {
      setState(() {
        _dropController.text = locationName;
        _placeSuggestions = [];
      });
      _dropFocusNode.unfocus();
      if (_pickupController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_pickupFocusNode);
      }
    } else {
      setState(() {
        _pickupController.text = locationName;
        _placeSuggestions = [];
      });
      _pickupFocusNode.unfocus();
      if (_dropController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_dropFocusNode);
      }
    }

    _checkAndNavigateToRide();
  }

  @override
  void dispose() {
    _dropFocusNode.removeListener(_onDropFocusChange);
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocusNode.dispose();
    _dropFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Area
          Container(
            color: const Color(0xFFFFF9E6),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16.h,
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
                      color: Colors.black,
                      size: 22.sp,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    _isScheduled ? 'Book Your Schedule Ride' : 'Book Your Ride',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Inputs Area
          Container(
            margin: EdgeInsets.only(
              top: 16.h,
              left: 16.w,
              right: 16.w,
              bottom: 10.h,
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.10),
                width: 1.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const RouteMarkerTimeline(),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInputField(
                        controller: _pickupController,
                        hint: 'Pick up Location',
                        onChanged: _getPlaceSuggestions,
                        focusNode: _pickupFocusNode,
                        trailingIcon: GestureDetector(
                          onTap: () => _useCurrentLocation(forceDrop: false),
                          child: Icon(
                            Icons.my_location_rounded,
                            color: const Color(0xFFF4B41A),
                            size: 18.sp,
                          ),
                        ),
                      ),
                      Divider(
                        height: 4.h,
                        thickness: 1,
                        color: const Color(0xFFF1F5F9),
                      ),
                      _buildInputField(
                        controller: _dropController,
                        hint: 'Drop Location',
                        onChanged: _getPlaceSuggestions,
                        focusNode: _dropFocusNode,
                        trailingIcon: GestureDetector(
                          onTap: () => _useCurrentLocation(forceDrop: true),
                          child: Icon(
                            Icons.my_location_rounded,
                            color: const Color(0xFFF4B41A),
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Results or Recent & Saved Locations List
          Expanded(
            child: _placeSuggestions.isNotEmpty
                ? ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    itemCount: _placeSuggestions.length,
                    itemBuilder: (context, index) {
                      final place = _placeSuggestions[index];
                      return _buildSuggestionItem(place);
                    },
                  )
                : ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    children: [
                      // Section 1: Recent Locations (Max 5, if not empty)
                      if (_recentDropoffLocations.isNotEmpty) ...[
                        Text(
                          'Recent Locations',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        if (_isLoadingRecentLocations)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFF4B41A),
                              strokeWidth: 2,
                            ),
                          )
                        else
                          ..._recentDropoffLocations.take(5).map(
                            (recent) => _buildRecentLocationCard(recent),
                          ),
                        SizedBox(height: 20.h),
                      ],

                      // Section 2: Saved Addresses (Home, Work, etc., if available)
                      if (_savedAddresses.isNotEmpty) ...[
                        Text(
                          'Saved Addresses',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        if (_isLoadingSavedAddresses)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFF4B41A),
                              strokeWidth: 2,
                            ),
                          )
                        else
                          ..._savedAddresses.map(
                            (saved) => _buildSavedAddressCard(saved),
                          ),
                      ],
                    ],
                  ),
          ),

          // Use Current Location Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: GestureDetector(
              onTap: _useCurrentLocation,
              child: Container(
                width: double.infinity,
                height: 44.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4B41A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFF4B41A).withValues(alpha: 0.3),
                    width: 1.w,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isGettingCurrentLocation)
                      SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF4B41A),
                        ),
                      )
                    else
                      Icon(
                        Icons.my_location,
                        color: const Color(0xFFD97706),
                        size: 18.sp,
                      ),
                    SizedBox(width: 8.w),
                    Text(
                      _isGettingCurrentLocation
                          ? 'Getting location...'
                          : 'Use Current Location',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
    required FocusNode focusNode,
    Widget? trailingIcon,
  }) {
    return SizedBox(
      height: 32.h,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        maxLines: 1,
        strutStyle: StrutStyle(
          fontSize: 14.sp,
          height: 1.2,
          forceStrutHeight: false,
        ),
        style: TextStyle(
          fontFamily: AppFonts.fontFamily,
          color: const Color(0xFF111827),
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: AppFonts.fontFamily,
            color: Colors.grey.shade400,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0),
          suffixIconConstraints: BoxConstraints(
            minHeight: 24.h,
            minWidth: 32.w,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isNotEmpty) {
                return GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Icon(Icons.close, color: Colors.grey, size: 18.sp),
                );
              }
              return trailingIcon ?? const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> place) {
    final structuredFormatting =
        place['structured_formatting'] as Map<String, dynamic>?;
    final mainText =
        structuredFormatting?['main_text'] ?? place['description'] ?? '';
    final secondaryText = structuredFormatting?['secondary_text'] ?? '';

    return InkWell(
      onTap: () => _selectPlaceSuggestion(place),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFFF4B41A).withValues(alpha: 0.20),
            width: 1.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF4B41A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: const Color(0xFFD97706),
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if (secondaryText.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey.shade400,
              size: 14.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLocationCard(RecentLocationModel recent) {
    return InkWell(
      onTap: () => _selectRecentLocation(recent),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: const Color(0xFFEEEEEE), width: 1.w),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF4B41A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                color: const Color(0xFFD97706),
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recent.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if (recent.address.isNotEmpty && recent.address != recent.title) ...[
                    SizedBox(height: 2.h),
                    Text(
                      recent.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              Icons.north_west_rounded,
              color: Colors.grey.shade400,
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddressCard(SavedAddressModel saved) {
    IconData iconData = Icons.location_on_rounded;
    if (saved.label.toUpperCase().contains('HOME')) {
      iconData = Icons.home_rounded;
    } else if (saved.label.toUpperCase().contains('WORK')) {
      iconData = Icons.work_rounded;
    }

    return InkWell(
      onTap: () => _selectSavedAddress(saved),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: const Color(0xFFEEEEEE), width: 1.w),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF9E6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: const Color(0xFFFFC000),
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    saved.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    saved.addressLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}
