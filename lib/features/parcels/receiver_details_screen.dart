import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/api_keys.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../core/utils.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../services/profile_service.dart';
import 'choose_parcel_screen.dart';
import 'pickup_address_screen.dart';

class ReceiverDetailsScreen extends StatefulWidget {
  final String pickupAddress;
  final String pickupContactName;
  final String pickupContactPhone;
  final String goodsType;
  final String helperRequired;

  const ReceiverDetailsScreen({
    super.key,
    required this.pickupAddress,
    required this.pickupContactName,
    required this.pickupContactPhone,
    required this.goodsType,
    required this.helperRequired,
  });

  @override
  State<ReceiverDetailsScreen> createState() => _ReceiverDetailsScreenState();
}

class _ReceiverDetailsScreenState extends State<ReceiverDetailsScreen> {
  static const _primaryColor = Color(0xFFF4B41A);
  static final _namePattern = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$');
  static final _indianMobilePattern = RegExp(r'^[6-9][0-9]{9}$');

  bool _isLocationConfirmed = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final TextEditingController _receiverNameController;
  late final TextEditingController _receiverMobileController;
  late final TextEditingController _receiverAddressLine1Controller;
  List<dynamic> _placeSuggestions = [];
  bool _useMyInfo = false;
  late String _pickupAddress;
  late String _pickupContactName;
  late String _pickupContactPhone;
  int _reverseGeocodeGeneration = 0;
  bool _skipNextReverseGeocode = false;

  LatLng _cameraCenter = const LatLng(28.7041, 77.1025);
  bool _isReversingGeocode = false;
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _receiverNameController = TextEditingController();
    _receiverMobileController = TextEditingController();
    _receiverAddressLine1Controller = TextEditingController();
    _pickupAddress = widget.pickupAddress;
    _pickupContactName = widget.pickupContactName;
    _pickupContactPhone = widget.pickupContactPhone;
    _fetchRecentAddresses();
  }

  void _clearDropAddress() {
    _reverseGeocodeGeneration++;
    _skipNextReverseGeocode = true;
    _searchController.clear();
    _receiverAddressLine1Controller.clear();
    setState(() {
      _isLocationConfirmed = false;
      _placeSuggestions = [];
    });
    _searchFocusNode.requestFocus();
  }

  Future<void> _editPickupLocation() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PickupAddressScreen(
          initialPickupAddress: _pickupAddress,
          returnResult: true,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final address = result['address']?.toString().trim();
    if (address == null || address.isEmpty) return;
    setState(() {
      _pickupAddress = address;
      _pickupContactName =
          result['contactName']?.toString().trim().isNotEmpty == true
          ? result['contactName'].toString().trim()
          : _pickupContactName;
      _pickupContactPhone =
          result['contactPhone']?.toString().trim().isNotEmpty == true
          ? result['contactPhone'].toString().trim()
          : _pickupContactPhone;
    });
  }

  void _editDropLocation() {
    _clearDropAddress();
  }

  Future<void> _fetchRecentAddresses() async {
    try {
      debugPrint('Recent addresses request started');
      final response = await ApiService.to.get(ApiEndpoints.recentAddresses);
      debugPrint('Recent addresses request completed');
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
          if (!mounted) return;
          setState(() {
            _savedAddresses.addAll(parsedAddresses);
          });
        }
      }
    } catch (e) {
      debugPrint('Recent addresses request failed: $e');
    }
  }

  Future<void> _getPlaceSuggestions(String input) async {
    if (input.isEmpty) {
      if (!mounted) return;
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
          if (!mounted) return;
          setState(() {
            _placeSuggestions = data['predictions'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching places: $e');
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    if (_skipNextReverseGeocode) {
      _skipNextReverseGeocode = false;
      return;
    }
    if (_isReversingGeocode) return;
    if (!mounted) return;
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
            _searchController.text = cleanedAddress;
          });
        }
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReversingGeocode = false;
        });
      }
    }
  }

  String? _validateReceiverName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Receiver name is required';
    if (name.length < 2) return 'Enter at least 2 letters';
    if (!_namePattern.hasMatch(name)) {
      return 'Enter a valid name using letters only';
    }
    return null;
  }

  String? _validateMobileNumber(String? value) {
    final number = value?.trim() ?? '';
    if (number.isEmpty) return 'Mobile number is required';
    if (!_indianMobilePattern.hasMatch(number)) {
      return 'Enter a valid 10-digit Indian mobile number';
    }
    return null;
  }

  String _fullDropAddress() {
    final address = _searchController.text.trim();
    final details = _receiverAddressLine1Controller.text.trim();
    if (details.isEmpty ||
        address.toLowerCase().contains(details.toLowerCase())) {
      return address;
    }
    return '$details, $address';
  }

  Future<void> _toggleUseMyInformation(bool selected) async {
    setState(() => _useMyInfo = selected);
    if (!selected) {
      _receiverNameController.clear();
      _receiverMobileController.clear();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    String name = prefs.getString('user_name')?.trim() ?? '';
    String phone = prefs.getString('user_phone')?.trim() ?? '';

    if (name.isEmpty || phone.isEmpty) {
      try {
        final prof = await ProfileService().getMyProfile();
        if (prof != null) {
          if (name.isEmpty && prof.name.isNotEmpty) {
            name = prof.name;
            await prefs.setString('user_name', name);
          }
          if (phone.isEmpty && prof.phone.isNotEmpty) {
            phone = prof.phone;
            await prefs.setString('user_phone', phone);
          }
        }
      } catch (_) {}
    }

    String cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanedPhone.length == 12 && cleanedPhone.startsWith('91')) {
      cleanedPhone = cleanedPhone.substring(2);
    } else if (cleanedPhone.length > 10) {
      cleanedPhone = cleanedPhone.substring(cleanedPhone.length - 10);
    }

    _receiverNameController.text = name;
    _receiverMobileController.text = cleanedPhone;

    if (_receiverNameController.text.isEmpty ||
        _receiverMobileController.text.isEmpty) {
      AppUtils.showSnackBar(
        context,
        'Some profile details are missing. Please complete them below.',
        isError: true,
      );
    }
  }

  void _handleContinue() {
    FocusScope.of(context).unfocus();
    final dropAddress = _searchController.text.trim();
    if (!_isLocationConfirmed) {
      if (dropAddress.length < 5) {
        AppUtils.showSnackBar(
          context,
          'Please select a complete drop location',
          isError: true,
        );
        return;
      }
      setState(() => _isLocationConfirmed = true);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      AppUtils.showSnackBar(
        context,
        'Please correct the highlighted details',
        isError: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChooseParcelScreen(
          pickupAddress: _pickupAddress,
          pickupContactName: _pickupContactName,
          pickupContactPhone: _pickupContactPhone,
          goodsType: widget.goodsType,
          helperRequired: widget.helperRequired,
          dropAddress: _fullDropAddress(),
          dropContactName: _receiverNameController.text.trim(),
          dropContactPhone: _receiverMobileController.text.trim(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _receiverNameController.dispose();
    _receiverMobileController.dispose();
    _receiverAddressLine1Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
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
                    initialCameraPosition: CameraPosition(
                      target: _cameraCenter,
                      zoom: 15,
                    ),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
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
                        color: const Color(0xFF13A9FF).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 20.w,
                          height: 20.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFF13A9FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 12.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Header and Search Bar (Reused)
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
                            'Receiver Details',
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
                              color: Colors.white.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(47.r),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: TextField(
                              focusNode: _searchFocusNode,
                              controller: _searchController,
                              onChanged: (value) {
                                if (_isLocationConfirmed) {
                                  setState(() => _isLocationConfirmed = false);
                                }
                                _getPlaceSuggestions(value);
                              },
                              style: AppFonts.bodyText.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                height: 1.2,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search for area, street or landmark',
                                hintStyle: AppFonts.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
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
                                            onTap: _clearDropAddress,
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
                                contentPadding: EdgeInsets.only(
                                  top: 14.h,
                                  bottom: 14.h,
                                  right: 15.w,
                                ),
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
                          color: Colors.black.withValues(alpha: 0.05),
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

                        if (_placeSuggestions.isNotEmpty)
                          Expanded(
                            child: ListView.builder(
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
                                final description = place['description'] ?? '';
                                final mainText =
                                    structuredFormatting?['main_text'] ??
                                    description;
                                final secondaryText =
                                    structuredFormatting?['secondary_text'] ??
                                    '';

                                return InkWell(
                                  onTap: () {
                                    _searchController.text =
                                        description.isNotEmpty
                                        ? description
                                        : mainText;
                                    setState(() {
                                      _placeSuggestions = [];
                                      _isLocationConfirmed =
                                          true; // Auto-confirm on selection
                                    });
                                    FocusScope.of(context).unfocus();
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 10.h),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 14.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: _primaryColor.withValues(
                                          alpha: 0.20,
                                        ),
                                        width: 1.2.w,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _primaryColor.withValues(
                                            alpha: 0.04,
                                          ),
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
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily:
                                                      AppFonts.fontFamily,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF1E293B,
                                                  ),
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                              if (secondaryText.isNotEmpty) ...[
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
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(
                                                      0xFF64748B,
                                                    ),
                                                    decoration:
                                                        TextDecoration.none,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: _primaryColor.withValues(
                                            alpha: 0.7,
                                          ),
                                          size: 14.sp,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else if (_isLocationConfirmed)
                          Expanded(
                            child: Form(
                              key: _formKey,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  left: 20.w,
                                  right: 20.w,
                                  bottom: 20.h,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Location Timeline Card (Exactly like Figma)
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.only(
                                        top: 15.h,
                                        right: 15.w,
                                        bottom: 15.h,
                                        left: 20.w,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.textFieldBackground,
                                        borderRadius: BorderRadius.circular(
                                          14.r,
                                        ),
                                        border: Border.all(
                                          color: AppColors.authButtonBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          children: [
                                            // Timeline Dots and Line
                                            Column(
                                              children: [
                                                SizedBox(
                                                  height: 12.h,
                                                ), // Align with first box center
                                                // Green Dot
                                                Container(
                                                  width: 24.w,
                                                  height: 24.w,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF439A72,
                                                    ).withValues(alpha: 0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Container(
                                                      width: 14.w,
                                                      height: 14.w,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFF439A72,
                                                          ),
                                                          width: 3.5.w,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Line
                                                Expanded(
                                                  child: Container(
                                                    width: 2.w,
                                                    color: Colors.grey.shade300,
                                                    margin:
                                                        EdgeInsets.symmetric(
                                                          vertical: 4.h,
                                                        ),
                                                  ),
                                                ),
                                                // Red Location Pin
                                                Icon(
                                                  Icons.location_on,
                                                  color: const Color(
                                                    0xFF9E1000,
                                                  ), // Dark Red
                                                  size: 26.sp,
                                                ),
                                                SizedBox(
                                                  height: 12.h,
                                                ), // Align with bottom box
                                              ],
                                            ),
                                            SizedBox(width: 10.w),
                                            // Texts and Boxes
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  // Top Box (Pickup)
                                                  Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.only(
                                                      top: 10.h,
                                                      right: 14.w,
                                                      bottom: 10.h,
                                                      left: 14.w,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10.r,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Pick-up Location',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontFamily: AppFonts
                                                                    .fontFamily,
                                                                color: Colors
                                                                    .grey
                                                                    .shade500,
                                                                fontSize: 12.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                            GestureDetector(
                                                              onTap:
                                                                  _editPickupLocation,
                                                              child: Text(
                                                                'Edit',
                                                                style: TextStyle(
                                                                  fontFamily:
                                                                      AppFonts
                                                                          .fontFamily,
                                                                  color: AppColors
                                                                      .primary,
                                                                  fontSize:
                                                                      12.sp,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 2.h),
                                                        Text(
                                                          _pickupAddress,
                                                          style: TextStyle(
                                                            fontFamily: AppFonts
                                                                .fontFamily,
                                                            color:
                                                                Colors.black87,
                                                            fontSize: 14.sp,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(height: 12.h),
                                                  // Bottom Box (Delivery)
                                                  Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.only(
                                                      top: 10.h,
                                                      right: 14.w,
                                                      bottom: 10.h,
                                                      left: 14.w,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10.r,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Your Destination',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontFamily: AppFonts
                                                                    .fontFamily,
                                                                color: Colors
                                                                    .grey
                                                                    .shade500,
                                                                fontSize: 12.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                            GestureDetector(
                                                              onTap:
                                                                  _editDropLocation,
                                                              child: Text(
                                                                'Edit',
                                                                style: TextStyle(
                                                                  fontFamily:
                                                                      AppFonts
                                                                          .fontFamily,
                                                                  color: AppColors
                                                                      .primary,
                                                                  fontSize:
                                                                      12.sp,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 2.h),
                                                        Text(
                                                          _searchController
                                                                  .text
                                                                  .isNotEmpty
                                                              ? _searchController
                                                                    .text
                                                              : 'Add Receiver address',
                                                          style: TextStyle(
                                                            fontFamily: AppFonts
                                                                .fontFamily,
                                                            color:
                                                                Colors.black87,
                                                            fontSize: 14.sp,
                                                            fontWeight:
                                                                FontWeight.w800,
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
                                    SizedBox(height: 20.h),

                                    // Receiver Information Title
                                    Text(
                                      'Receiver Information',
                                      style: AppFonts.h2.copyWith(
                                        fontSize: 16.sp,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(height: 12.h),

                                    // Form Fields
                                    Text(
                                      'Receiver name *',
                                      style: _fieldLabelStyle(),
                                    ),
                                    SizedBox(height: 4.h),
                                    _buildTextField(
                                      controller: _receiverNameController,
                                      hintText: 'Enter Receiver Name',
                                      prefixIcon: Icons.person_outline,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z ]'),
                                        ),
                                      ],
                                      validator: _validateReceiverName,
                                    ),
                                    SizedBox(height: 16.h),

                                    Text(
                                      'Mobile number *',
                                      style: _fieldLabelStyle(),
                                    ),
                                    SizedBox(height: 4.h),
                                    _buildTextField(
                                      controller: _receiverMobileController,
                                      hintText: 'Enter Mobile Number',
                                      prefixIcon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: _validateMobileNumber,
                                    ),
                                    SizedBox(height: 16.h),

                                    Text(
                                      'House, flat or building  Optional',
                                      style: _fieldLabelStyle(),
                                    ),
                                    SizedBox(height: 4.h),
                                    _buildTextField(
                                      controller:
                                          _receiverAddressLine1Controller,
                                      hintText:
                                          'e.g. Flat 12, Green View Apartments',
                                      prefixIcon: Icons.map_outlined,
                                    ),
                                    SizedBox(height: 16.h),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 24.w,
                                          height: 24.w,
                                          child: Checkbox(
                                            value: _useMyInfo,
                                            onChanged: (value) =>
                                                _toggleUseMyInformation(
                                                  value ?? false,
                                                ),
                                            activeColor: const Color(
                                              0xFFF4B41A,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4.r),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Use my profile details',
                                          style: AppFonts.bodyText.copyWith(
                                            color: Colors.black,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 24.h),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent & Saved Addresses',
                                    style: AppFonts.h2.copyWith(
                                      fontSize: 16.sp,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  ..._savedAddresses.map(
                                    (address) => _buildAddressTile(address),
                                  ),
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
                                  color: Colors.black.withValues(alpha: 0.05),
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
                                    : _handleContinue,
                                child: Text(
                                  _isLocationConfirmed
                                      ? 'Continue to vehicle selection'
                                      : 'Confirm drop location',
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
      ),
    );
  }

  Widget _buildAddressTile(Map<String, dynamic> address) {
    return InkWell(
      onTap: () {
        final addrText = address['subtitle'] ?? address['title'] ?? '';
        setState(() {
          _searchController.text = addrText;
          _isLocationConfirmed = true;
        });
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
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters:
          inputFormatters ??
          (keyboardType == TextInputType.phone
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]
              : null),
      style: AppFonts.bodyText.copyWith(
        color: const Color(0xFF1E293B),
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(hintText: hintText, prefixIcon: prefixIcon),
    );
  }

  TextStyle _fieldLabelStyle() {
    return AppFonts.bodyText.copyWith(
      color: const Color(0xFF334155),
      fontWeight: FontWeight.w700,
      fontSize: 13.sp,
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: AppColors.authButtonBorder, width: 1.w),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.textFieldBackground,
      hintText: hintText,
      hintStyle: AppFonts.bodyText.copyWith(
        color: const Color(0x66000000),
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 19.sp),
      prefixIconConstraints: BoxConstraints(minWidth: 44.w),
      contentPadding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 12.w),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: _primaryColor, width: 1.5.w),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.redAccent, width: 1.w),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5.w),
      ),
      errorMaxLines: 2,
      errorStyle: TextStyle(fontSize: 10.sp, height: 1.2),
    );
  }
}
