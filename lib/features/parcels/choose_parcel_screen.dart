import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_fonts.dart';
import '../../constants/api_keys.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_response.dart';
import '../../core/api/api_exception.dart';
import 'ride_invoice_screen.dart';

class ChooseParcelScreen extends StatefulWidget {
  final String pickupAddress;
  final String pickupContactName;
  final String pickupContactPhone;
  final String dropAddress;
  final String dropContactName;
  final String dropContactPhone;
  final String goodsType;
  final String helperRequired;

  const ChooseParcelScreen({
    super.key,
    required this.pickupAddress,
    required this.pickupContactName,
    required this.pickupContactPhone,
    required this.dropAddress,
    required this.dropContactName,
    required this.dropContactPhone,
    required this.goodsType,
    required this.helperRequired,
  });

  @override
  State<ChooseParcelScreen> createState() => _ChooseParcelScreenState();
}

class _ChooseParcelScreenState extends State<ChooseParcelScreen> {
  int _selectedParcelIndex = 0;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isEstimating = true;
  String? _estimateError;
  String? _estimateId;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;

  late List<Map<String, dynamic>> _parcelOptions;

  final List<Map<String, dynamic>> _fallbackOptions = [
    {
      'title': 'Mini Truck',
      'capacity': '1.5 Ton Capacity',
      'dimensions': '8 ft (L) x 5 ft (W) x 5 ft (H)',
      'time': 'ETA 8 mins',
      'price': '₹599',
      'vehicleType': 'TRUCK_SMALL',
      'image': 'assets/images/truck.png',
    },
    {
      'title': 'Tata Ace',
      'capacity': '800 kgs Capacity',
      'dimensions': '6.5 ft (L) x 5 ft (W) x 4 ft (H)',
      'time': 'ETA 8 mins',
      'price': '₹447',
      'vehicleType': 'TRUCK_SMALL',
      'image': 'assets/images/truck.png',
    },
    {
      'title': 'Pickup',
      'capacity': '2 Ton Capacity',
      'dimensions': '10 ft (L) x 6 ft (W) x 6 ft (H)',
      'time': 'ETA 8 mins',
      'price': '₹899',
      'vehicleType': 'TRUCK_MEDIUM',
      'image': 'assets/images/truck.png',
    },
    {
      'title': 'Large Truck',
      'capacity': '5 Ton Capacity',
      'dimensions': '17 ft (L) x 7 ft (W) x 7 ft (H)',
      'time': 'ETA 8 mins',
      'price': '₹1499',
      'vehicleType': 'Mini truck',
      'image': 'assets/images/truck.png',
    },
  ];

  Map<String, dynamic> _getHardcodedData(String categoryName) {
    final name = categoryName.toLowerCase();

    if (name == 'mini truck' ||
        name.contains('mini truck') ||
        name.contains('ace') ||
        name.contains('small') ||
        name.contains('dost')) {
      return {
        'capacity': '1.5 Ton Capacity',
        'dimensions': '8 ft (L) x 5 ft (W) x 5 ft (H)',
        'vehicleType': 'TRUCK_SMALL',
        'image': 'assets/images/truck.png',
      };
    }
    // Tata Ace -> TRUCK_SMALL
    else if (name.contains('ace') || name.contains('small')) {
      return {
        'capacity': '800 kgs Capacity',
        'dimensions': '6.5 ft (L) x 5 ft (W) x 4 ft (H)',
        'vehicleType': 'TRUCK_SMALL',
        'image': 'assets/images/truck.png',
      };
    }
    // Pickup -> TRUCK_MEDIUM
    else if (name.contains('pickup') || name.contains('medium')) {
      return {
        'capacity': '1 Ton Capacity',
        'dimensions': '8 ft (L) x 5 ft (W) x 5 ft (H)',
        'vehicleType': 'TRUCK_MEDIUM',
        'image': 'assets/images/truck.png',
      };
    }
    // Large Truck -> TRUCK
    else if (name.contains('large') ||
        name.contains('big') ||
        name.contains('heavy')) {
      return {
        'capacity': '5 Ton Capacity',
        'dimensions': '17 ft (L) x 7 ft (W) x 7 ft (H)',
        'vehicleType': 'TRUCK',
        'image': 'assets/images/truck.png',
      };
    }
    // Default fallback
    else {
      return {
        'capacity': '1 Ton Capacity',
        'dimensions': '8 ft (L) x 5 ft (W) x 5 ft (H)',
        'vehicleType': 'TRUCK_MEDIUM',
        'image': 'assets/images/truck.png',
      };
    }
  }

  Widget _buildVehicleImage(String? source) {
    const fallbackAsset = 'assets/images/truck.png';
    if (source == null || source.trim().isEmpty) {
      return Image.asset(fallbackAsset, fit: BoxFit.contain);
    }

    final value = source.trim();
    if (!value.startsWith('http') && !value.startsWith('/')) {
      return Image.asset(
        value,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Image.asset(fallbackAsset, fit: BoxFit.contain),
      );
    }

    final imageUrl = value.startsWith('http')
        ? value
        : '${ApiConstants.baseUrl}$value';
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 20.w,
            height: 20.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) =>
          Image.asset(fallbackAsset, fit: BoxFit.contain),
    );
  }

  @override
  void initState() {
    super.initState();
    _parcelOptions = List.from(_fallbackOptions);
    _fetchEstimates();
  }

  List<LatLng> _decodePolyline(String str) {
    List<LatLng> coordinates = [];
    int index = 0, len = str.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = str.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      coordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return coordinates;
  }

  Future<LatLng> _getCoordinates(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=${ApiKeys.googleMapsKey}';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
    } catch (e) {
      debugPrint('Error geocoding address: $e');
    }
    if (address.toLowerCase().contains('saket')) {
      return const LatLng(28.5244, 77.2066);
    }
    return const LatLng(28.628, 77.364);
  }

  Future<void> _fetchEstimates() async {
    setState(() {
      _isEstimating = true;
      _estimateError = null;
      _estimateId = null;
    });

    try {
      final pickupLatLng = await _getCoordinates(widget.pickupAddress);
      final dropLatLng = await _getCoordinates(widget.dropAddress);

      setState(() {
        _pickupLatLng = pickupLatLng;
        _dropLatLng = dropLatLng;
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickupLatLng,
            infoWindow: InfoWindow(
              title: 'Pickup Location',
              snippet: widget.pickupAddress,
            ),
          ),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('delivery'),
            position: dropLatLng,
            infoWindow: InfoWindow(
              title: 'Delivery Location',
              snippet: widget.dropAddress,
            ),
          ),
        );
      });

      final categoriesResponse = await ApiService.to.get(
        ApiEndpoints.vehicleCategories,
        queryParameters: {
          'latitude': pickupLatLng.latitude,
          'longitude': pickupLatLng.longitude,
        },
      );
      final categoryPayload = categoriesResponse.data is Map
          ? categoriesResponse.data['data'] ?? categoriesResponse.data
          : categoriesResponse.data;
      final categories = categoryPayload is List
          ? categoryPayload
          : categoryPayload is Map && categoryPayload['items'] is List
          ? categoryPayload['items'] as List
          : <dynamic>[];

      final basePayload = {
        'pickup': {
          "address": widget.pickupAddress,
          "latitude": pickupLatLng.latitude,
          "longitude": pickupLatLng.longitude,
        },
        'drop': {
          "address": widget.dropAddress,
          "latitude": dropLatLng.latitude,
          "longitude": dropLatLng.longitude,
        },
      };

      try {
        final batchResponse = await ApiService.to.post(
          ApiEndpoints.goodsEstimate,
          body: basePayload,
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
          final List<Map<String, dynamic>> options = [];
          for (var category in categories) {
            if (category is! Map || category['id'] == null) continue;
            final catId = category['id'].toString();
            final est = estimateMap[catId];
            if (est != null) {
              final name =
                  (category['name'] ?? category['displayName'] ?? 'Vehicle')
                      .toString();
              final hc = _getHardcodedData(name);
              final fareRaw = est['totalFare'] ?? est['fare'] ?? est['estimatedFare'] ?? est['subtotal'] ?? est['total'];
              final fare = fareRaw is num
                  ? fareRaw.toDouble()
                  : double.tryParse('$fareRaw');
              options.add(<String, dynamic>{
                ...Map<String, dynamic>.from(category),
                'id': catId,
                'categoryId': catId,
                'vehicleModelId': catId,
                'vehicleType': category['type']?.toString() ?? name,
                'vehicleName': name,
                'estimateId': (est['id'] ?? est['estimateId'])?.toString(),
                'estimateRequest': { ...basePayload, 'categoryId': catId },
                'fare': fare,
                'totalFare': fare,
                'title': name,
                'capacity': category['capacity']?.toString() ?? hc['capacity'],
                'dimensions': category['dimensions'] ?? hc['dimensions'],
                'time': est['estimatedDuration']?.toString() ?? 'Available',
                'price': fare == null ? '₹--' : '₹${fare.toStringAsFixed(2)}',
                'imageUrl': category['imageUrl']?.toString(),
                'image': category['imageUrl'] ?? hc['image'],
              });
            }
          }
          _parcelOptions = options;
        } else {
          _parcelOptions = [];
        }

        if (_parcelOptions.isEmpty) {
          _estimateError = 'No drivers available in your area at the moment.';
        }
      } catch (e) {
        debugPrint('Parcel estimate failed: $e');
        _parcelOptions = [];
        final errStr = e is ApiException ? e.message : e.toString();
        _estimateError = errStr.contains('No drivers') || errStr.contains('driver')
            ? errStr
            : 'No drivers available in your area at the moment.';
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapController != null) {
          final bounds = LatLngBounds(
            southwest: LatLng(
              pickupLatLng.latitude < dropLatLng.latitude
                  ? pickupLatLng.latitude
                  : dropLatLng.latitude,
              pickupLatLng.longitude < dropLatLng.longitude
                  ? pickupLatLng.longitude
                  : dropLatLng.longitude,
            ),
            northeast: LatLng(
              pickupLatLng.latitude > dropLatLng.latitude
                  ? pickupLatLng.latitude
                  : dropLatLng.latitude,
              pickupLatLng.longitude > dropLatLng.longitude
                  ? pickupLatLng.longitude
                  : dropLatLng.longitude,
            ),
          );
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          );
        }
      });
    } catch (e) {
      debugPrint('Overall estimate error: $e');
      setState(() {
        _estimateError = e.toString();
      });
    } finally {
      setState(() {
        _isEstimating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: Stack(
        children: [
          // Live Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(28.7080, 77.1080),
                zoom: 14.5,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // Top Floating Address Card (Reused from ReceiverDetailsScreen but styled as float)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10.h,
            left: 20.w,
            right: 20.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circular Back Button
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
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
                SizedBox(height: 10.h),
                // Location Timeline Card
                Container(
                  padding: EdgeInsets.only(
                    top: 10.h,
                    right: 10.w,
                    bottom: 10.h,
                    left: 12.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.black.withOpacity(0.10),
                      width: 0.5,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        // Timeline Dots and Line
                        Column(
                          children: [
                            SizedBox(height: 8.h),
                            // Green Dot
                            Container(
                              width: 20.w,
                              height: 20.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFF439A72).withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 12.w,
                                  height: 12.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF439A72),
                                      width: 2.5.w,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Line
                            Expanded(
                              child: Container(
                                width: 1.5.w,
                                color: Colors.grey.shade300,
                                margin: EdgeInsets.symmetric(vertical: 2.h),
                              ),
                            ),
                            // Red Location Pin
                            Icon(
                              Icons.location_on,
                              color: const Color(0xFF9E1000),
                              size: 22.sp,
                            ),
                            SizedBox(height: 8.h),
                          ],
                        ),
                        SizedBox(width: 8.w),
                        // Texts and Boxes
                        Expanded(
                          child: Column(
                            children: [
                              // Top Box (Pickup)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.only(
                                  top: 8.h,
                                  right: 12.w,
                                  bottom: 8.h,
                                  left: 12.w,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: const Color(0xFFF0F0F0),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${widget.pickupContactName} | ${widget.pickupContactPhone}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.captionDark
                                                .copyWith(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 12.sp,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 3.h),
                                    Text(
                                      widget.pickupAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.bodyText.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              // Bottom Box (Delivery)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.only(
                                  top: 8.h,
                                  right: 12.w,
                                  bottom: 8.h,
                                  left: 12.w,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: const Color(0xFFF0F0F0),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${widget.dropContactName} | ${widget.dropContactPhone}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.captionDark
                                                .copyWith(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 12.sp,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 3.h),
                                    Text(
                                      widget.dropAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.bodyText.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.sp,
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
                ),
              ],
            ),
          ),

          // Bottom Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(top: 12.h, bottom: 16.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),

                  // Parcel Options List
                  Expanded(
                    child: _isEstimating
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFF4B41A),
                            ),
                          )
                        : _estimateError != null
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _estimateError != null &&
                                            _estimateError!.contains('No goods')
                                        ? Icons.info_outline_rounded
                                        : Icons.error_outline,
                                    color:
                                        _estimateError != null &&
                                            _estimateError!.contains('No goods')
                                        ? Colors.orange
                                        : Colors.red,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    _estimateError ??
                                        'Failed to load estimates',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF4B41A),
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: _fetchEstimates,
                                    child: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            itemCount: _parcelOptions.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: 12.h),
                            itemBuilder: (context, index) {
                              final option = _parcelOptions[index];
                              final isSelected = _selectedParcelIndex == index;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedParcelIndex = index;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 12.w,
                                  ),
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
                                              color: const Color(0xFFF4B41A)
                                                  .withValues(alpha: 0.12),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.02),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Vehicle Image Container
                                      Container(
                                        width: 58.w,
                                        height: 58.w,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F7F7),
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                          child: _buildVehicleImage(
                                            option['imageUrl']?.toString() ??
                                                option['image']?.toString(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 14.w),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option['title'],
                                              style: TextStyle(
                                                fontFamily: AppFonts.fontFamily,
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF111827),
                                              ),
                                            ),
                                            SizedBox(height: 3.h),
                                            Text(
                                              option['capacity'],
                                              style: TextStyle(
                                                fontFamily: AppFonts.fontFamily,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11.sp,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              option['dimensions'],
                                              style: TextStyle(
                                                fontFamily: AppFonts.fontFamily,
                                                color: Colors.grey.shade600,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              option['time'],
                                              style: TextStyle(
                                                fontFamily: AppFonts.fontFamily,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Price & Select Button
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.local_offer,
                                                  color: const Color(0xFFF4B41A),
                                                  size: 13.sp,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  option['price'],
                                                  style: TextStyle(
                                                    fontFamily: AppFonts.fontFamily,
                                                    fontSize: 15.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF111827),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          Container(
                                            width: 64.w,
                                            height: 24.h,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFFF4B41A)
                                                  : Colors.white,
                                              border: Border.all(
                                                color: const Color(0xFFF4B41A),
                                                width: 1.w,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Select',
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: isSelected
                                                      ? Colors.black
                                                      : const Color(0xFFF4B41A),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  if (_estimateError == null && !_isEstimating)
                    // Total Fare Section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
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
                            'Total Fare',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                          Text(
                            _parcelOptions.isNotEmpty &&
                                    _selectedParcelIndex >= 0 &&
                                    _selectedParcelIndex < _parcelOptions.length
                                ? _parcelOptions[_selectedParcelIndex]['price']
                                      .toString()
                                : '₹--',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Confirm Button
                  Padding(
                    padding: EdgeInsets.only(
                      left: 20.w,
                      right: 20.w,
                      top: 10.h,
                      bottom: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom
                          : 20.h,
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
                        onPressed:
                            !_isEstimating &&
                                _estimateId != null &&
                                _estimateId!.isNotEmpty &&
                                _parcelOptions.isNotEmpty &&
                                _selectedParcelIndex >= 0 &&
                                _selectedParcelIndex < _parcelOptions.length
                            ? () {
                                final selectedParcel =
                                    _parcelOptions[_selectedParcelIndex];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RideInvoiceScreen(
                                      pickupAddress: widget.pickupAddress,
                                      pickupContactName:
                                          widget.pickupContactName,
                                      pickupContactPhone:
                                          widget.pickupContactPhone,
                                      pickupLatLng:
                                          _pickupLatLng ??
                                          const LatLng(28.628, 77.364),
                                      dropAddress: widget.dropAddress,
                                      dropContactName: widget.dropContactName,
                                      dropContactPhone: widget.dropContactPhone,
                                      dropLatLng:
                                          _dropLatLng ??
                                          const LatLng(28.552, 77.554),
                                      selectedParcel: selectedParcel,
                                      estimateId: _estimateId,
                                      estimateRequest:
                                          Map<String, dynamic>.from(
                                            selectedParcel['estimateRequest']
                                                as Map,
                                          ),
                                      goodsType: widget.goodsType,
                                      helperRequired: widget.helperRequired,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: Text(
                          _parcelOptions.isNotEmpty &&
                                  _selectedParcelIndex >= 0 &&
                                  _selectedParcelIndex < _parcelOptions.length
                              ? 'Book ${_parcelOptions[_selectedParcelIndex]['title']}'
                              : 'Book',
                          style: AppFonts.buttonText.copyWith(
                            color: Colors.black,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
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
}
