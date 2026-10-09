import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/utils.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_keys.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import 'add_address_screen.dart';

class PickupAddressScreen extends StatefulWidget {
  final String? initialPickupAddress;
  final bool returnResult;

  const PickupAddressScreen({
    super.key,
    this.initialPickupAddress,
    this.returnResult = false,
  });

  @override
  State<PickupAddressScreen> createState() => _PickupAddressScreenState();
}

class _PickupAddressScreenState extends State<PickupAddressScreen> {
  GoogleMapController? _mapController;
  late final TextEditingController _searchController;
  List<dynamic> _placeSuggestions = [];

  LatLng _cameraCenter = const LatLng(28.7041, 77.1025);
  String _currentAddress = 'Fetching location...';
  bool _isReversingGeocode = false;
  int _reverseGeocodeGeneration = 0;
  bool _skipNextReverseGeocode = false;

  void _clearPickupAddress() {
    _reverseGeocodeGeneration++;
    _skipNextReverseGeocode = true;
    _searchController.clear();
    setState(() {
      _currentAddress = '';
      _placeSuggestions = [];
    });
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    if (_skipNextReverseGeocode) {
      _skipNextReverseGeocode = false;
      return;
    }
    if (_isReversingGeocode) return;
    final requestGeneration = _reverseGeocodeGeneration;
    setState(() {
      _isReversingGeocode = true;
    });

    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&key=${ApiKeys.googleMapsKey}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final formattedAddress =
              data['results'][0]['formatted_address'] as String;
          final cleanedAddress = AppUtils.cleanGeocodedAddress(
            formattedAddress,
          );
          if (!mounted || requestGeneration != _reverseGeocodeGeneration) {
            return;
          }
          setState(() {
            _currentAddress = cleanedAddress;
            _searchController.text = cleanedAddress;
          });
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    } finally {
      if (mounted) setState(() => _isReversingGeocode = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 15),
        ),
      );

      _reverseGeocode(latLng);
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  final List<Map<String, dynamic>> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialPickupAddress,
    );
    if (widget.initialPickupAddress != null && widget.initialPickupAddress!.trim().isNotEmpty) {
      _currentAddress = widget.initialPickupAddress!;
    } else {
      _getCurrentLocation();
    }
    _fetchRecentAddresses();
  }

  Future<void> _fetchRecentAddresses() async {
    try {
      print('APP LOG: Recent Addresses API call started in Pickup Screen');
      final response = await ApiService.to.get(ApiEndpoints.recentAddresses);
      print(
        'APP LOG: Recent Addresses API Success in Pickup Screen -> ${response.data}',
      );
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> recentList = response.data['data'] ?? [];
        final List<Map<String, dynamic>> parsedAddresses = [];
        final Set<String> existingSubtitles = _savedAddresses
            .map((e) => e['subtitle'] as String)
            .toSet();

        for (var item in recentList) {
          String? address;
          String title = 'Recent Location';

          if (item is String) {
            address = item;
          } else if (item is Map<String, dynamic>) {
            title = item['title'] ?? item['name'] ?? 'Recent Location';
            address =
                item['address'] ??
                item['pickupAddress'] ??
                item['dropAddress'] ??
                item['subtitle'] ??
                item['formattedAddress'];
          }

          if (address != null && address.trim().isNotEmpty) {
            final trimmed = address.trim();
            if (!existingSubtitles.contains(trimmed)) {
              existingSubtitles.add(trimmed);
              parsedAddresses.add({
                'icon': Icons.history,
                'color': const Color(0xFFE0F7FA),
                'iconColor': const Color(0xFF00B8D4),
                'title': title,
                'subtitle': trimmed,
              });
            }
          }
        }

        if (parsedAddresses.isNotEmpty) {
          setState(() {
            _savedAddresses.addAll(parsedAddresses);
          });
        }
      }
    } catch (e) {
      print('APP LOG: Recent Addresses API Error in Pickup Screen -> $e');
    }
  }

  Future<void> _getPlaceSuggestions(String input) async {
    if (input.isEmpty || input == _currentAddress) {
      setState(() {
        _placeSuggestions = [];
      });
      return;
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${ApiKeys.googleMapsKey}&components=country:in';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _placeSuggestions = data['predictions'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching places: $e');
    }
  }

  Future<void> _confirmPickupLocation() async {
    FocusScope.of(context).unfocus();
    final typedAddress = _searchController.text.trim();
    final address = typedAddress.isNotEmpty
        ? typedAddress
        : _currentAddress.trim();

    if (address.isEmpty) {
      AppUtils.showSnackBar(
        context,
        'Please select or enter a pickup location',
        isError: true,
      );
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddAddressScreen(
          selectedAddress: address,
          returnResult: widget.returnResult,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (widget.returnResult) {
      Navigator.pop(context, result);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Background Map
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).size.height * 0.45,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(28.7041, 77.1025), // Default to Delhi
                    zoom: 15,
                  ),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMove: (position) {
                    _cameraCenter = position.target;
                  },
                  onCameraIdle: () {
                    _reverseGeocode(_cameraCenter);
                  },
                ),
              ),

              // Custom Map Marker in Center
              Positioned(
                top: MediaQuery.of(context).size.height * 0.27,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top Header and Search Bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 10.h,
                left: 20.w,
                right: 20.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 8.w,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Text(
                          'Pickup Address',
                          style: AppFonts.h1.copyWith(
                            fontSize: 18.sp,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(47.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: 46.h,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.90),
                            borderRadius: BorderRadius.circular(47.r),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _getPlaceSuggestions,
                            maxLines: 1,
                            textAlignVertical: TextAlignVertical.center,
                            style: AppFonts.bodyText.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              height: 1.2,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search for area, street or landmark',
                              hintStyle: AppFonts.bodyText.copyWith(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey.shade400,
                                height: 1.2,
                              ),
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(
                                  left: 15.w,
                                  right: 8.w,
                                  top: 2.h,
                                ),
                                child: Icon(
                                  Icons.search,
                                  color: const Color(0xFFF4B41A),
                                  size: 18.sp,
                                ),
                              ),
                              suffixIcon:
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _searchController,
                                    builder: (context, value, child) {
                                      if (value.text.isNotEmpty) {
                                        return GestureDetector(
                                          onTap: _clearPickupAddress,
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.grey,
                                            size: 20.sp,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                              prefixIconConstraints: BoxConstraints(
                                minWidth: 40.w,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(right: 15.w),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Sheet Content
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: isKeyboardOpen
                      ? constraints.maxHeight -
                            (MediaQuery.of(context).padding.top + 140.h)
                      : MediaQuery.of(context).size.height * 0.68,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag Handle
                      SizedBox(height: 12.h),
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      Expanded(
                        child: _placeSuggestions.isNotEmpty
                            ? ListView.builder(
                                padding: EdgeInsets.only(
                                  left: 20.w,
                                  right: 20.w,
                                  bottom: 20.h,
                                ),
                                itemCount: _placeSuggestions.length,
                                itemBuilder: (context, index) {
                                  final place = _placeSuggestions[index];
                                  final structuredFormatting =
                                      place['structured_formatting']
                                          as Map<String, dynamic>?;
                                  final mainText =
                                      structuredFormatting?['main_text'] ??
                                      place['description'] ??
                                      '';
                                  final secondaryText =
                                      structuredFormatting?['secondary_text'] ??
                                      '';

                                  return InkWell(
                                    onTap: () async {
                                      _searchController.text = mainText;
                                      setState(() {
                                        _placeSuggestions = [];
                                      });
                                      final newAddress =
                                          await Navigator.push<
                                            Map<String, dynamic>
                                          >(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AddAddressScreen(
                                                    selectedAddress: mainText,
                                                    returnResult:
                                                        widget.returnResult,
                                                  ),
                                            ),
                                          );
                                      if (newAddress != null) {
                                        if (widget.returnResult) {
                                          Navigator.pop(context, newAddress);
                                          return;
                                        }
                                        setState(() {
                                          _savedAddresses.add(newAddress);
                                        });
                                      }
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: 10.h),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 14.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFF4B41A,
                                          ).withValues(alpha: 0.20),
                                          width: 1.2.w,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFF4B41A,
                                            ).withValues(alpha: 0.04),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 38.w,
                                            height: 38.w,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFFF9E6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.location_on_rounded,
                                              color: const Color(0xFFD97706),
                                              size: 20.sp,
                                            ),
                                          ),
                                          SizedBox(width: 14.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  mainText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        AppFonts.fontFamily,
                                                    fontSize: 15.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(
                                                      0xFF1E293B,
                                                    ),
                                                  ),
                                                ),
                                                if (secondaryText
                                                    .isNotEmpty) ...[
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    secondaryText,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          AppFonts.fontFamily,
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: const Color(
                                                        0xFF64748B,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: const Color(
                                              0xFFD97706,
                                            ).withValues(alpha: 0.7),
                                            size: 14.sp,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  left: 20.w,
                                  right: 20.w,
                                  bottom: 20.h,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Save Address Title
                                    Text(
                                      'Save Address',
                                      style: AppFonts.h2.copyWith(
                                        fontSize: 16.sp,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: 16.h),

                                    // Addresses List
                                    ..._savedAddresses.map(
                                      (address) => _buildAddressTile(address),
                                    ),

                                    SizedBox(height: 16.h),

                                    // Use Current Location Button
                                    Container(
                                      width: double.infinity,
                                      height: 40.h,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFF4B41A,
                                          ).withValues(alpha: 0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                          onTap: _getCurrentLocation,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.my_location,
                                                color: const Color(0xFFD97706),
                                                size: 20.sp,
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                'Use Current Location',
                                                style: AppFonts.bodyText
                                                    .copyWith(
                                                      color: Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      fontSize: 14.sp,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 16.h),

                                    SizedBox(height: 24.h),
                                  ],
                                ),
                              ),
                      ),

                      // Fixed Bottom Button
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: EdgeInsets.only(
                            left: 20.w,
                            right: 20.w,
                            top: 16.h,
                            bottom: 20.h,
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
                          child: SizedBox(
                            height: 46.h,
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4B41A),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              onPressed: _isReversingGeocode
                                  ? null
                                  : _confirmPickupLocation,
                              child: Text(
                                'Confirm Pickup Location',
                                textAlign: TextAlign.center,
                                style: AppFonts.buttonText.copyWith(
                                  color: Colors.black,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
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
          );
        },
      ),
    );
  }

  Widget _buildAddressTile(Map<String, dynamic> address) {
    return InkWell(
      onTap: () async {
        final newAddress = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => AddAddressScreen(
              selectedAddress: address['subtitle'] ?? address['title'],
              returnResult: widget.returnResult,
            ),
          ),
        );
        if (newAddress != null) {
          if (widget.returnResult) {
            Navigator.pop(context, newAddress);
            return;
          }
          setState(() {
            _savedAddresses.add(newAddress);
          });
        }
      },
      child: Column(
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 23, sigmaY: 23),
              child: Container(
                height: 50.h,
                padding: EdgeInsets.only(top: 10.h, bottom: 10.h, right: 5.w),
                child: Row(
                  children: [
                    Container(
                      width: 30.w,
                      height: 30.w,
                      decoration: BoxDecoration(
                        color: address['color'],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          address['icon'],
                          color: address['iconColor'],
                          size: 16.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            address['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.h2.copyWith(
                              fontSize: 14.sp,
                              color: Colors.black,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            address['subtitle'],
                            style: AppFonts.captionDark.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 11.sp,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Divider(
              color: Colors.grey.shade100,
              height: 1,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
