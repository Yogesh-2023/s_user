import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_client.dart';
import '../../core/utils.dart';
import 'otp_screen.dart';

class CountryItem {
  final String name;
  final String code;
  final String flag;

  const CountryItem({
    required this.name,
    required this.code,
    required this.flag,
  });
}

const List<CountryItem> _allCountries = [
  CountryItem(name: 'India', code: '+91', flag: '🇮🇳'),
  CountryItem(name: 'United States', code: '+1', flag: '🇺🇸'),
  CountryItem(name: 'United Kingdom', code: '+44', flag: '🇬🇧'),
  CountryItem(name: 'United Arab Emirates', code: '+971', flag: '🇦🇪'),
  CountryItem(name: 'Canada', code: '+1', flag: '🇨🇦'),
  CountryItem(name: 'Australia', code: '+61', flag: '🇦🇺'),
  CountryItem(name: 'Saudi Arabia', code: '+966', flag: '🇸🇦'),
  CountryItem(name: 'Singapore', code: '+65', flag: '🇸🇬'),
  CountryItem(name: 'Qatar', code: '+974', flag: '🇶🇦'),
  CountryItem(name: 'Kuwait', code: '+965', flag: '🇰🇼'),
  CountryItem(name: 'Oman', code: '+968', flag: '🇴🇲'),
  CountryItem(name: 'Bahrain', code: '+973', flag: '🇧🇭'),
  CountryItem(name: 'Germany', code: '+49', flag: '🇩🇪'),
  CountryItem(name: 'France', code: '+33', flag: '🇫🇷'),
  CountryItem(name: 'Italy', code: '+39', flag: '🇮🇹'),
  CountryItem(name: 'Spain', code: '+34', flag: '🇪🇸'),
  CountryItem(name: 'Netherlands', code: '+31', flag: '🇳🇱'),
  CountryItem(name: 'Russia', code: '+7', flag: '🇷🇺'),
  CountryItem(name: 'China', code: '+86', flag: '🇨🇳'),
  CountryItem(name: 'Japan', code: '+81', flag: '🇯🇵'),
  CountryItem(name: 'South Korea', code: '+82', flag: '🇰🇷'),
  CountryItem(name: 'Bangladesh', code: '+880', flag: '🇧🇩'),
  CountryItem(name: 'Pakistan', code: '+92', flag: '🇵🇰'),
  CountryItem(name: 'Nepal', code: '+977', flag: '🇳🇵'),
  CountryItem(name: 'Sri Lanka', code: '+94', flag: '🇱🇰'),
  CountryItem(name: 'Malaysia', code: '+60', flag: '🇲🇾'),
  CountryItem(name: 'Indonesia', code: '+62', flag: '🇮🇩'),
  CountryItem(name: 'Thailand', code: '+66', flag: '🇹🇭'),
  CountryItem(name: 'Vietnam', code: '+84', flag: '🇻🇳'),
  CountryItem(name: 'Philippines', code: '+63', flag: '🇵🇭'),
  CountryItem(name: 'Brazil', code: '+55', flag: '🇧🇷'),
  CountryItem(name: 'Mexico', code: '+52', flag: '🇲🇽'),
  CountryItem(name: 'Argentina', code: '+54', flag: '🇦🇷'),
  CountryItem(name: 'South Africa', code: '+27', flag: '🇿🇦'),
  CountryItem(name: 'Nigeria', code: '+234', flag: '🇳🇬'),
  CountryItem(name: 'Egypt', code: '+20', flag: '🇪🇬'),
  CountryItem(name: 'Kenya', code: '+254', flag: '🇰🇪'),
  CountryItem(name: 'New Zealand', code: '+64', flag: '🇳🇿'),
  CountryItem(name: 'Turkey', code: '+90', flag: '🇹🇷'),
  CountryItem(name: 'Switzerland', code: '+41', flag: '🇨🇭'),
  CountryItem(name: 'Sweden', code: '+46', flag: '🇸🇪'),
  CountryItem(name: 'Norway', code: '+47', flag: '🇳🇴'),
  CountryItem(name: 'Denmark', code: '+45', flag: '🇩🇰'),
  CountryItem(name: 'Ireland', code: '+353', flag: '🇮🇪'),
  CountryItem(name: 'Portugal', code: '+351', flag: '🇵🇹'),
  CountryItem(name: 'Belgium', code: '+32', flag: '🇧🇪'),
  CountryItem(name: 'Austria', code: '+43', flag: '🇦🇹'),
  CountryItem(name: 'Greece', code: '+30', flag: '🇬🇷'),
  CountryItem(name: 'Poland', code: '+48', flag: '🇵🇱'),
  CountryItem(name: 'Ukraine', code: '+380', flag: '🇺🇦'),
];

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  bool _isLoading = false;
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryFlag = '🇮🇳';
  String _selectedCountryName = 'India';
  String _selectedCountryCode = '+91';

  static const Color _headerYellow = Color(0xFFFFD428);

  void _showCountryPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CountryPickerModal(
          selectedCountryCode: _selectedCountryCode,
          selectedCountryName: _selectedCountryName,
          onSelect: (CountryItem country) {
            setState(() {
              _selectedCountryFlag = country.flag;
              _selectedCountryName = country.name;
              _selectedCountryCode = country.code;
            });
          },
        );
      },
    );
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      AppUtils.showSnackBar(
        context,
        'Please enter a phone number',
        isError: true,
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length != 10) {
      AppUtils.showSnackBar(
        context,
        'Please enter a valid 10-digit phone number',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final formattedPhone = phone.startsWith('+')
        ? phone
        : '$_selectedCountryCode$cleanPhone';

    try {
      await ApiClient.clearSession();
      final response = await ApiService.to.post(
        ApiEndpoints.sendOtp,
        body: {'mobile': formattedPhone},
      );

      AppUtils.printLog('Send OTP Response: ${response.data}');

      if (mounted) {
        AppUtils.showSnackBar(context, 'OTP sent successfully');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(phoneNumber: formattedPhone),
          ),
        );
      }
    } catch (e) {
      AppUtils.printLog('Send OTP Error: $e');
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          AppUtils.extractErrorMessage(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Top Yellow Header with loginpageframe.png background (#FFD428)
                        Container(
                          width: double.infinity,
                          height: 350.h,
                          color: _headerYellow,
                          child: Stack(
                            children: [
                              // Background Frame Image & Color (#FFD428)
                              Positioned.fill(
                                child: Container(
                                  color: _headerYellow,
                                  child: Image.asset(
                                    'assets/images/loginpageframe.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),

                              // Top Logo Container & Welcome Section
                              SafeArea(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(height: 8.h),

                                      // White Container around Sawariya Logo
                                      Center(
                                        child: Container(
                                          height: 48.h,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              14.r,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.04,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Image.asset(
                                            'assets/images/sawariya_login_logo.png',
                                            height: 36.h,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) => RichText(
                                              text: const TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Sawa',
                                                    style: TextStyle(
                                                      fontFamily: 'Gilroy',
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF000000),
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'riya',
                                                    style: TextStyle(
                                                      fontFamily: 'Gilroy',
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFFFFC000),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: 35.h),

                                      // Welcome Back Heading
                                      Text(
                                        'Welcome Back',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 23.sp,
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                          letterSpacing: 0,
                                          color: const Color(0xFF242A37),
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        "We're so excited to have you here.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 14.5.sp,
                                          fontWeight: FontWeight.w400,
                                          height: 1.0,
                                          letterSpacing: 0,
                                          color: const Color(0xFF242A37),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // White Login Card Overlay (Figma specs)
                        Transform.translate(
                          offset: Offset(0, -85.h),
                          child: Center(
                            child: Container(
                              width: 350.w,
                              height: 350.h,
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 25.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: const Color(0xFFF0F0F0),
                                  width: 1.05,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Card Title (Figma specs: Gilroy, 26px, 600 SemiBold, 100% height, 0px letter-spacing)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sign in with your',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 25.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0D0D0D),
                                          height: 1.0,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        'Phone number',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 25.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFFFC000),
                                          height: 1.0,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 14.h),

                                  // Country/Region Field
                                  GestureDetector(
                                    onTap: _showCountryPickerBottomSheet,
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      width: double.infinity,
                                      height: 57.5.h,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 15.w,
                                        vertical: 6.5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          6.6.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFECECEC),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Country/Region',
                                                style: TextStyle(
                                                  fontFamily: 'Gilroy',
                                                  fontSize: 10.5.sp,
                                                  color: const Color(0xFF8E8E93),
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.1,
                                                ),
                                              ),
                                              SizedBox(height: 3.h),
                                              Row(
                                                children: [
                                                  Text(
                                                    _selectedCountryFlag,
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Expanded(
                                                    child: Text(
                                                      '$_selectedCountryName ($_selectedCountryCode)',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily: 'Gilroy',
                                                        fontSize: 13.5.sp,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: const Color(
                                                          0xFF0D0D0D,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Positioned(
                                            right: 0,
                                            child: Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: const Color(0xFF0D0D0D),
                                              size: 26.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: 6.h),

                                  // Phone Number Input Box
                                  Container(
                                    width: double.infinity,
                                    height: 57.5.h,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 15.w,
                                      vertical: 6.5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        6.6.r,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFECECEC),
                                        width: 1.1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Enter Phone Number',
                                          style: TextStyle(
                                            fontFamily: 'Gilroy',
                                            fontSize: 10.5.sp,
                                            color: const Color(0xFF8E8E93),
                                            fontWeight: FontWeight.w400,
                                            height: 1.1,
                                          ),
                                        ),
                                        SizedBox(height: 3.h),
                                        SizedBox(
                                          height: 18.h,
                                          child: TextField(
                                            controller: _phoneController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(),
                                            textInputAction:
                                                TextInputAction.done,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                10,
                                              ),
                                            ],
                                            maxLength: 10,
                                            onChanged: (value) {
                                              if (value.length == 10) {
                                                FocusManager
                                                    .instance
                                                    .primaryFocus
                                                    ?.unfocus();
                                              }
                                            },
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0D0D0D),
                                            ),
                                            decoration: const InputDecoration(
                                              counterText: '',
                                              hintText: '9876543210',
                                              hintStyle: TextStyle(
                                                color: Color(0xFF8E8E93),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 16.h),

                                  // Get OTP Button
                                  GestureDetector(
                                    onTap: _isLoading ? null : _sendOtp,
                                    child: Container(
                                      width: double.infinity,
                                      height: 46.h,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E232A),
                                        borderRadius: BorderRadius.circular(
                                          10.48.r,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: _isLoading
                                          ? SizedBox(
                                              width: 20.w,
                                              height: 20.w,
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                            )
                                          : Text(
                                              'Get OTP',
                                              style: TextStyle(
                                                fontFamily: 'Gilroy',
                                                fontSize: 15.5.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Bottom Agreement Text
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 24.w,
                              right: 24.w,
                              bottom: 24.h,
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 12.5.sp,
                                  color: const Color(0xFF1C1C1E),
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'By Clicking Sign in you Agree to the\n',
                                  ),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      color: Color(0xFF0D0D0D),
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        AppUtils.showSnackBar(
                                          context,
                                          'Privacy Policy',
                                        );
                                      },
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Terms of Use',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      color: Color(0xFF0D0D0D),
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        AppUtils.showSnackBar(
                                          context,
                                          'Terms of Use',
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountryPickerModal extends StatefulWidget {
  final String selectedCountryCode;
  final String selectedCountryName;
  final ValueChanged<CountryItem> onSelect;

  const _CountryPickerModal({
    required this.selectedCountryCode,
    required this.selectedCountryName,
    required this.onSelect,
  });

  @override
  State<_CountryPickerModal> createState() => _CountryPickerModalState();
}

class _CountryPickerModalState extends State<_CountryPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryItem> _filteredCountries = _allCountries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = _allCountries;
      } else {
        _filteredCountries = _allCountries.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.code.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxModalHeight = mediaQuery.size.height * 0.75;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxModalHeight,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10.h),
          // Drag Handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Country / Region',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D0D0D),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: const Color(0xFF0D0D0D),
                    size: 22.sp,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Search Field
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              height: 46.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFFECECEC),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: const Color(0xFF8E8E93),
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0D0D0D),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search country or code...',
                        hintStyle: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          color: const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                      },
                      child: Icon(
                        Icons.cancel_rounded,
                        color: const Color(0xFF8E8E93),
                        size: 18.sp,
                      ),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: 12.h),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // Country List
          Flexible(
            child: _filteredCountries.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(30.h),
                    child: Text(
                      'No countries found',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 14.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: _filteredCountries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFF5F5F5)),
                    itemBuilder: (context, index) {
                      final item = _filteredCountries[index];
                      final isSelected =
                          item.name == widget.selectedCountryName &&
                              item.code == widget.selectedCountryCode;

                      return ListTile(
                        onTap: () {
                          widget.onSelect(item);
                          Navigator.pop(context);
                        },
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 2.h,
                        ),
                        leading: Text(
                          item.flag,
                          style: TextStyle(fontSize: 22.sp),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 15.sp,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFFFFC000)
                                : const Color(0xFF0D0D0D),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.code,
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                            if (isSelected) ...[
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.check_circle_rounded,
                                color: const Color(0xFFFFC000),
                                size: 18.sp,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
