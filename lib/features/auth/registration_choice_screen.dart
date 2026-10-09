import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../profile/privacy_policy_screen.dart';
import '../profile/terms_conditions_screen.dart';
import '../main_navigation_screen.dart';
import '../../widgets/otp_verified_dialog.dart';

class RegistrationChoiceScreen extends StatefulWidget {
  const RegistrationChoiceScreen({super.key});

  @override
  State<RegistrationChoiceScreen> createState() =>
      _RegistrationChoiceScreenState();
}

class _RegistrationChoiceScreenState extends State<RegistrationChoiceScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _showOtpStep = false;
  int _resendTimerSeconds = 30;
  Timer? _timer;

  static const Color _yellow = Color(0xFFFFC000);
  static const Color _darkButton = Color(0xFF1E232A);
  static const Color _darkText = Color(0xFF0D0D0D);
  static const Color _purpleLink = Color(0xFF635BFF);

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      final index = i;
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_otpControllers[index].text.isEmpty && index > 0) {
            _otpControllers[index - 1].clear();
            _otpFocusNodes[index - 1].requestFocus();
            setState(() {});
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimerSeconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        if (mounted) {
          setState(() {
            _resendTimerSeconds--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _onGetOtp() {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    final phoneRegExp = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegExp.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a Valid Number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _showOtpStep = true;
    });
    _startResendTimer();
  }

  void _onVerifyOtp() {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid 4-digit code')),
      );
      return;
    }

    _showOtpVerifiedDialog();
  }

  void _showOtpVerifiedDialog() {
    OtpVerifiedDialog.show(
      context,
      onClose: () {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      },
    );
  }

  String _getFormattedPhone() {
    String p = _phoneController.text.trim();
    if (p.length >= 10) {
      return '+91 ${p.substring(0, 2)}XXXXXX${p.substring(p.length - 2)}';
    }
    return '+91 98XXXXXX45';
  }

  @override
  Widget build(BuildContext context) {
    String formattedPhone = _getFormattedPhone();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Top Header Section with loginpageframe.png & fleetgologo.png
                        SizedBox(
                          width: double.infinity,
                          height: _showOtpStep ? 240.h : 382.h,
                          child: Stack(
                            children: [
                              // Background Frame Image (#FFD428)
                              Positioned.fill(
                                child: Container(
                                  color: const Color(0xFFFFD428),
                                  child: Image.asset(
                                    'assets/images/loginpageframe.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/images/frame.png',
                                      fit: BoxFit.fill,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                            color: Color(0xFFFFD428),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              SafeArea(
                                bottom: false,
                                child: Column(
                                  children: [
                                    SizedBox(height: 16.h),

                                    // White Container around FleetGo Logo (Figma specs: Hug 140.08x48px, radius 14px, padding 8x10px)
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
                                                  text: 'Fleet',
                                                  style: TextStyle(
                                                    fontFamily: 'Gilroy',
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF000000),
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: 'go',
                                                  style: TextStyle(
                                                    fontFamily: 'Gilroy',
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: _yellow,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    if (!_showOtpStep) ...[
                                      SizedBox(height: 35.h),
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form Card / OTP Card Container
                        if (_showOtpStep)
                          Transform.translate(
                            offset: Offset(0, -65.h),
                            child: _buildOtpCardView(formattedPhone),
                          )
                        else
                          Transform.translate(
                            offset: Offset(0, -95.h),
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
                                child: _buildPhoneCardView(),
                              ),
                            ),
                          ),

                        if (!_showOtpStep) const Spacer(),

                        // Footer Links for Login Screen
                        if (!_showOtpStep)
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
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const PrivacyPolicyScreen(),
                                            ),
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
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const TermsConditionsScreen(),
                                            ),
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

  Widget _buildPhoneCardView() {
    return Column(
      key: const ValueKey('phoneView'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in with your',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 21.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D0D0D),
                height: 1.0,
              ),
            ),
            SizedBox(height: 13.h),
            Text(
              'Phone number',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 21.sp,
                fontWeight: FontWeight.w800,
                color: _yellow,
                height: 1.0,
              ),
            ),
          ],
        ),

        SizedBox(height: 14.h),

        // Country/Region Box
        Container(
          width: double.infinity,
          height: 57.5.h,
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 6.5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.6.r),
            border: Border.all(color: const Color(0xFFECECEC), width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
                  Text('🇮🇳', style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 8.w),
                  Text(
                    'India(+91)',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _darkText,
                    ),
                  ),
                  const Spacer(),
                  Transform.translate(
                    offset: Offset(0, -3.h),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: _darkText,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 10.h),

        // Enter Phone Number Box
        Container(
          width: double.infinity,
          height: 57.5.h,
          padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 6.5.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.6.r),
            border: Border.all(color: const Color(0xFFECECEC), width: 1.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
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
          onTap: _onGetOtp,
          child: Container(
            width: double.infinity,
            height: 44.h,
            decoration: BoxDecoration(
              color: const Color(0xFF242A37),
              borderRadius: BorderRadius.circular(10.48.r),
            ),
            alignment: Alignment.center,
            child: Text(
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
    );
  }

  Widget _buildOtpCardView(String formattedPhone) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 657.h),
      padding: EdgeInsets.fromLTRB(20.w, 35.h, 20.w, 35.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Verify Your Number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 23.sp,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: const Color(0xFF242A37),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "We've sent a 6-digit verification code to",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF242A37),
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedPhone,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                ),
              ),
              SizedBox(width: 6.w),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showOtpStep = false;
                  });
                },
                child: Text(
                  'Change',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _purpleLink,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 35.h),

          // Enter Code Section (320px width, 20px gap)
          SizedBox(
            width: 320.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter Code',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                  ),
                ),

                SizedBox(height: 10.h),

                // 4 OTP Boxes (Figma specs: 55x55px, radius 10px, padding 9x8px, exact 10px gap between boxes)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(7, (index) {
                    if (index.isOdd) return SizedBox(width: 10.w);
                    final boxIndex = index ~/ 2;

                    bool isFilledOrFocused =
                        _otpControllers[boxIndex].text.isNotEmpty ||
                        _otpFocusNodes[boxIndex].hasFocus;

                    return Container(
                      width: 55.w,
                      height: 55.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isFilledOrFocused
                              ? _yellow
                              : const Color(0x33000000),
                          width: 1.0,
                        ),
                      ),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.backspace) {
                            if (_otpControllers[boxIndex].text.isEmpty &&
                                boxIndex > 0) {
                              _otpControllers[boxIndex - 1].clear();
                              _otpFocusNodes[boxIndex - 1].requestFocus();
                              setState(() {});
                            }
                          }
                        },
                        child: SizedBox(
                          height: 24.h,
                          child: TextField(
                            controller: _otpControllers[boxIndex],
                            focusNode: _otpFocusNodes[boxIndex],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            textAlignVertical: TextAlignVertical.center,
                            maxLength: 1,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              color: const Color(0xFF000000),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '-',
                              hintStyle: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                                color: const Color(0xFFC7C7CC),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && boxIndex < 3) {
                                _otpFocusNodes[boxIndex + 1].requestFocus();
                              } else if (value.isEmpty && boxIndex > 0) {
                                _otpControllers[boxIndex - 1].clear();
                                _otpFocusNodes[boxIndex - 1].requestFocus();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                SizedBox(height: 14.h),

                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 12.5.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                    children: [
                      const TextSpan(text: 'Resend Code ( '),
                      TextSpan(
                        text: '${_resendTimerSeconds}sec',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF242A37),
                        ),
                      ),
                      const TextSpan(text: ' )'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 35.h),

          // OTP Verify Button (Figma specs: Fill 353px, height 44px, radius 12px, #242A37, padding 15x8.8px)
          GestureDetector(
            onTap: _onVerifyOtp,
            child: Container(
              width: double.infinity,
              height: 44.h,
              padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 8.8.w),
              decoration: BoxDecoration(
                color: const Color(0xFF242A37),
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Text(
                'OTP Verify',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 15.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),

          SizedBox(height: 35.h),

          // Bottom Didn't receive code? Send Again Link (Figma specs: Gilroy 500 Medium, 12.22px, 120% height, purple link)
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 12.22.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: 0,
                  color: const Color(0xFF666666),
                ),
                children: [
                  const TextSpan(text: "Didn't receive the code? "),
                  TextSpan(
                    text: "Send Again",
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 12.22.sp,
                      fontWeight: FontWeight.w700,
                      color: _purpleLink,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = _startResendTimer,
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

class FourPointStarWidget extends StatelessWidget {
  final double size;
  final Color color;

  const FourPointStarWidget({
    Key? key,
    required this.size,
    this.color = const Color(0xFFFFB800),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FourPointStarPainter(color: color)),
    );
  }
}

class _FourPointStarPainter extends CustomPainter {
  final Color color;
  _FourPointStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    double w = size.width;
    double h = size.height;
    double cx = w / 2;
    double cy = h / 2;

    path.moveTo(cx, 0);
    path.quadraticBezierTo(cx, cy, w, cy);
    path.quadraticBezierTo(cx, cy, cx, h);
    path.quadraticBezierTo(cx, cy, 0, cy);
    path.quadraticBezierTo(cx, cy, cx, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
