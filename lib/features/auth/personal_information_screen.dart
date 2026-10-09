import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_exception.dart';
import '../../core/utils.dart';
import '../../services/profile_service.dart';
import '../../services/auth_session_service.dart';
import '../main_navigation_screen.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _gender = 'Male';
  final String _requirement = 'PERSONAL';
  bool _isLoading = false;

  static const Color _headerYellow = Color(0xFFFFD428);
  static const Color _yellowAccent = Color(0xFFFFC000);
  static const Color _darkButton = Color(0xFF242A37);
  static const Color _darkText = Color(0xFF0D0D0D);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    String fullName = _fullNameController.text.trim();
    List<String> nameParts = fullName.split(' ');
    String firstName = nameParts.first;
    String lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';
    String email = _emailController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    String primaryPhone = prefs.getString('user_phone') ?? '';

    final Map<String, String> fields = {
      'name': fullName,
      'email': email,
      'phone': primaryPhone,
      'alternatePhone': '',
      'firstname': firstName,
      'lastname': lastName,
      'gender': _gender,
      'dob': '',
      'address': '',
      'pincode': '',
      'city': '',
      'state': '',
      'requirement': _requirement,
    };

    try {
      final profileService = ProfileService();
      final profile = await profileService.createProfile(
        fields: fields,
      );

      if (profile != null) {
        await AuthSessionService.setProfileComplete(true);
        await prefs.setString('user_name', fullName);
        AppUtils.clearSnackBar();

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ),
            (route) => false,
          );
        }
        return;
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          AppUtils.showSnackBar(
            context,
            'Failed to save profile',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String errorMessage = e is ApiException
            ? e.message
            : e.toString().replaceAll('ApiException:', '').trim();
        AppUtils.showSnackBar(context, errorMessage, isError: true);
      }
    }
  }

  Widget _buildGenderOption(String option) {
    bool isSelected = _gender == option;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _gender = option;
          });
        },
        child: Container(
          height: 46.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected ? _yellowAccent : const Color(0xFFECECEC),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _yellowAccent : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? Container(
                        width: 9.w,
                        height: 9.w,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _yellowAccent,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 8.w),
              Text(
                option,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 13.5.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? _darkText : const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // Top Yellow Header with loginpageframe.png background (#FFD428)
                  Container(
                    width: double.infinity,
                    height: 240.h,
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

                        // Top Logo Container
                        SafeArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Column(
                              children: [
                                SizedBox(height: 12.h),
                                // White Container around Sawariya Logo
                                Center(
                                  child: Container(
                                    height: 48.h,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
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
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF000000),
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'riyaa',
                                              style: TextStyle(
                                                fontFamily: 'Gilroy',
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFFFC000),
                                              ),
                                            ),
                                          ],
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
                  ),

                  // White Card Overlay matching OTP / Verify Your Number Screen
                  Transform.translate(
                    offset: Offset(0, -45.h),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(20.w, 35.h, 20.w, 35.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30.r),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Title: Complete Your Profile
                          Text(
                            'Complete Your Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 23.sp,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: _darkButton,
                            ),
                          ),
                          SizedBox(height: 8.h),

                          // Subtitle: Let's verify your basic information.
                          Text(
                            "Let's verify your basic information.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                          SizedBox(height: 28.h),

                          // Full Name Field Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Full Name',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _darkText,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              TextFormField(
                                controller: _fullNameController,
                                textCapitalization: TextCapitalization.words,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z\s]'),
                                  ),
                                ],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter full name';
                                  }
                                  if (value.trim().length < 4) {
                                    return 'Name must be at least 4 characters';
                                  }
                                  return null;
                                },
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: _darkText,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your full name',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFB0B0B0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 14.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECECEC),
                                      width: 1.0,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECECEC),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: _yellowAccent,
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20.h),

                          // Email ID Field Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email ID',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _darkText,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  final emailRegex = RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  );
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: _darkText,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your email id',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFFB0B0B0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 14.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECECEC),
                                      width: 1.0,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECECEC),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: _yellowAccent,
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20.h),

                          // Gender Selection Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gender',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _darkText,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  _buildGenderOption('Male'),
                                  SizedBox(width: 10.w),
                                  _buildGenderOption('Female'),
                                  SizedBox(width: 10.w),
                                  _buildGenderOption('Other'),
                                ],
                              ),
                            ],
                          ),

                          SizedBox(height: 32.h),

                          // Continue Button matching OTP Verify Button
                          GestureDetector(
                            onTap: _isLoading ? null : _submit,
                            child: Container(
                              width: double.infinity,
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: _darkButton,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Continue',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
