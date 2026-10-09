import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_navigation_screen.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/socket/socket_service.dart';
import '../../core/utils.dart';
import '../../services/push_notification_service.dart';
import '../../services/auth_session_service.dart';
import '../../widgets/otp_verified_dialog.dart';
import 'personal_information_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;
  final SmartAuth _smartAuth = SmartAuth.instance;
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendTimerSeconds = 60;
  Timer? _timer;

  static const Color _yellow = Color(0xFFFFC000);
  static const Color _headerYellow = Color(0xFFFFD428);
  static const Color _darkButton = Color(0xFF242A37);
  static const Color _darkText = Color(0xFF0D0D0D);
  static const Color _purpleLink = Color(0xFF635BFF);

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (index) => FocusNode());
    _controllers = List.generate(4, (index) => TextEditingController());
    _startResendTimer();
    _listenForSms();

    for (int i = 0; i < 4; i++) {
      final index = i;
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_controllers[index].text.isEmpty && index > 0) {
            _controllers[index - 1].clear();
            _focusNodes[index - 1].requestFocus();
            setState(() {});
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      };
    }
  }

  List<FocusNode> get _otpFocusNodes => _focusNodes;

  void _startResendTimer() {
    _resendTimerSeconds = 60;
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

  Future<void> _resendOtp() async {
    if (_isResending || _isVerifying || _resendTimerSeconds > 0) return;
    setState(() => _isResending = true);

    try {
      await ApiService.to.post(
        ApiEndpoints.resendOtp,
        body: {'mobile': widget.phoneNumber},
      );
      for (final controller in _controllers) {
        controller.clear();
      }
      if (!mounted) return;
      _focusNodes.first.requestFocus();
      _startResendTimer();
      AppUtils.showSnackBar(context, 'OTP sent again successfully');
    } catch (error) {
      AppUtils.printLog('Resend OTP Error: $error');
      if (mounted) {
        final message = error is ApiException
            ? error.message
            : 'OTP resend failed. Please try again.';
        AppUtils.showSnackBar(context, message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _listenForSms() async {
    try {
      final res = await _smartAuth.getSmsWithUserConsentApi(matcher: r'\d{4}');
      if (res.hasData && res.data != null && res.data!.code != null) {
        String code = res.data!.code!;
        _fillAndVerifyOtp(code);
      }
    } catch (e) {
      debugPrint("Error listening for SMS: $e");
    }
  }

  void _fillAndVerifyOtp(String otp) {
    if (otp.length >= 4) {
      for (int i = 0; i < 4; i++) {
        _controllers[i].text = otp[i];
      }
      _verifyAndContinue();
    }
  }

  void _verifyAndContinue() async {
    if (_isVerifying || _isResending) return;
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length < 4) {
      AppUtils.showSnackBar(
        context,
        'Please enter complete 4‑digit OTP',
        isError: true,
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final response = await ApiService.to.post(
        ApiEndpoints.verifyOtp,
        body: {
          'mobile': widget.phoneNumber,
          'otp': otp,
          'deviceId': await _deviceId(),
        },
      );

      AppUtils.printLog('Verify OTP Response: ${response.data}');
      if (response.data != null) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_phone', widget.phoneNumber);
        String? token;
        if (data is Map) {
          if (data['sessionToken'] != null) {
            token = data['sessionToken'];
          } else if (data['token'] != null) {
            token = data['token'];
          } else if (data['accessToken'] != null) {
            token = data['accessToken'];
          } else if (data['data'] is Map) {
            final dataMap = data['data'];
            if (dataMap['sessionToken'] != null) {
              token = dataMap['sessionToken'];
            } else if (dataMap['token'] != null) {
              token = dataMap['token'];
            } else if (dataMap['accessToken'] != null) {
              token = dataMap['accessToken'];
            }
          }
        }
        token ??= await ApiClient.readAuthToken();

        if (token != null && token.isNotEmpty) {
          await prefs.setString('auth_token', token);

          String? userId;
          if (data is Map) {
            final dynamic dataVal = data['data'];
            if (dataVal is Map) {
              userId =
                  (dataVal['userId'] ??
                          dataVal['id'] ??
                          dataVal['user']?['id'] ??
                          dataVal['user']?['userId'])
                      ?.toString();
            }
            userId ??=
                (data['userId'] ??
                        data['id'] ??
                        data['user']?['id'] ??
                        data['user']?['userId'])
                    ?.toString();
          }

          if (userId != null) {
            await prefs.setString('user_id', userId);
            AppUtils.printLog('Saved User ID: $userId');
            SocketService.to.initSocket(sessionToken: token, userId: userId);
          } else {
            AppUtils.printLog(
              'Warning: No userId found in verification response',
            );
          }

          AppUtils.printLog('Authentication completed successfully');
          await PushNotificationService.instance.syncToken();
        } else {
          final hasSession = await ApiClient.hasSession();
          if (!hasSession) {
            throw const ApiException(
              message: 'Login session was not created. Please try again.',
              statusCode: 401,
              url: ApiEndpoints.verifyOtp,
            );
          }
          AppUtils.printLog('Authentication completed with session cookie');
          await PushNotificationService.instance.syncToken();
        }

        if (mounted) {
          final sessionState = await AuthSessionService.resolve();
          if (!mounted) return;
          await OtpVerifiedDialog.show(
            context,
            onClose: () {
              if (!mounted) return;
              final Widget destination =
                  sessionState == AppSessionState.profileComplete
                      ? const MainNavigationScreen()
                      : const PersonalInformationScreen();
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => destination,
                ),
                (route) => false,
              );
            },
          );
        }
      }
    } catch (e) {
      AppUtils.printLog('Verify OTP Error: $e');
      if (mounted) {
        String errorMessage = 'Wrong OTP! Please check the code and try again.';
        final errStr = e.toString();

        if (e is ApiException) {
          errorMessage = e.message;
        } else {
          errorMessage = errStr;
        }

        if (errorMessage.toLowerCase().contains('expired')) {
          errorMessage = 'OTP expired. Please tap Resend again.';
        } else if (errorMessage.toLowerCase().contains('otp') ||
            errorMessage.toLowerCase().contains('invalid') ||
            errStr.contains('400') ||
            errStr.contains('401')) {
          errorMessage = 'Wrong OTP! Please check the code and try again.';
        }

        AppUtils.showSnackBar(context, errorMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null || id.isEmpty) {
      id = 'flutter-${DateTime.now().microsecondsSinceEpoch}';
      await prefs.setString('device_id', id);
    }
    return id;
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    _timer?.cancel();
    _smartAuth.removeUserConsentApiListener();
    super.dispose();
  }

  String _getFormattedPhone() {
    String p = widget.phoneNumber.trim();
    if (p.startsWith('+91') && p.length >= 13) {
      return '+91 ${p.substring(3, 5)}XXXXXX${p.substring(p.length - 2)}';
    } else if (p.length >= 10) {
      return '+91 ${p.substring(0, 2)}XXXXXX${p.substring(p.length - 2)}';
    }
    return widget.phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    final formattedPhone = _getFormattedPhone();

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
                        // Top Header Section with loginpageframe.png background
                        SizedBox(
                          width: double.infinity,
                          height: 240.h,
                          child: Stack(
                            children: [
                              // Yellow Header Background (#FFD428)
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

                              // FleetGo Logo in White Container (Centered, NO Back Button per reference design)
                              SafeArea(
                                child: Column(
                                  children: [
                                    SizedBox(height: 26.h),
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
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF000000),
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: 'riya',
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
                            ],
                          ),
                        ),

                        // White OTP Card Container (Figma specs: Width 393px, Height 657px, Radius 30px, padding top 35px, left/right 20px, section gap 35px)
                        Transform.translate(
                          offset: Offset(0, -45.h),
                          child: Container(
                            width: double.infinity,
                            constraints: BoxConstraints(minHeight: 657.h),
                            padding: EdgeInsets.fromLTRB(
                              20.w,
                              40.h,
                              20.w,
                              35.h,
                            ),
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
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Title: Verify Your Number
                                Text(
                                  'Verify Your Number',
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

                                // Subtitle
                                Text(
                                  "We've sent a 4-digit code to",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: _darkButton,
                                  ),
                                ),
                                SizedBox(height: 6.h),

                                // Phone Number + Change Link
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
                                      onTap: () => Navigator.pop(context),
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

                                SizedBox(height: 18.h),
                                // Enter Code Parent Section
                                SizedBox(
                                  width: 320.w,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Enter Code Label
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: List.generate(7, (index) {
                                          if (index.isOdd) {
                                            return SizedBox(width: 10.w);
                                          }
                                          final boxIndex = index ~/ 2;
                                          bool isFilledOrFocused =
                                              _controllers[boxIndex]
                                                  .text
                                                  .isNotEmpty ||
                                              _focusNodes[boxIndex].hasFocus;

                                          return Container(
                                            width: 55.w,
                                            height: 55.w,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
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
                                                        LogicalKeyboardKey
                                                            .backspace) {
                                                  if (_controllers[boxIndex]
                                                          .text
                                                          .isEmpty &&
                                                      boxIndex > 0) {
                                                    _controllers[boxIndex - 1]
                                                        .clear();
                                                    _focusNodes[boxIndex - 1]
                                                        .requestFocus();
                                                    setState(() {});
                                                  }
                                                }
                                              },
                                              child: Transform.translate(
                                                offset: Offset(0, 2.h),
                                                child: SizedBox(
                                                  height: 24.h,
                                                  child: TextField(
                                                    controller:
                                                        _controllers[boxIndex],
                                                    focusNode:
                                                        _focusNodes[boxIndex],
                                                    keyboardType:
                                                        const TextInputType.numberWithOptions(),
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly,
                                                      LengthLimitingTextInputFormatter(
                                                        1,
                                                      ),
                                                    ],
                                                    textAlign: TextAlign.center,
                                                    textAlignVertical:
                                                        TextAlignVertical
                                                            .center,
                                                    maxLength: 1,
                                                    style: TextStyle(
                                                      fontFamily: 'Gilroy',
                                                      fontSize: 16.sp,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1.0,
                                                      color: const Color(
                                                        0xFF000000,
                                                      ),
                                                    ),
                                                    decoration: InputDecoration(
                                                      counterText: '',
                                                      hintText: '-',
                                                      hintStyle: TextStyle(
                                                        fontFamily: 'Gilroy',
                                                        fontSize: 16.sp,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        height: 1.0,
                                                        color: const Color(
                                                          0xFFC7C7CC,
                                                        ),
                                                      ),
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                                    onChanged: (value) {
                                                      if (value.isNotEmpty &&
                                                          boxIndex < 3) {
                                                        _focusNodes[boxIndex +
                                                                1]
                                                            .requestFocus();
                                                      } else if (value
                                                              .isEmpty &&
                                                          boxIndex > 0) {
                                                        _controllers[boxIndex -
                                                                1]
                                                            .clear();
                                                        _focusNodes[boxIndex -
                                                                1]
                                                            .requestFocus();
                                                      } else if (boxIndex ==
                                                              3 &&
                                                          value.isNotEmpty) {
                                                        FocusScope.of(
                                                          context,
                                                        ).unfocus();
                                                        _verifyAndContinue();
                                                      }
                                                      setState(() {});
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),

                                      SizedBox(height: 12.h),

                                      // 60-second countdown or simple underlined Resend OTP text link
                                      if (_resendTimerSeconds > 0)
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontSize: 13.sp,
                                              color: const Color(0xFF8E8E93),
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Resend OTP in ',
                                              ),
                                              TextSpan(
                                                text: '${_resendTimerSeconds}s',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF242A37),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: (_isVerifying || _isResending)
                                              ? null
                                              : _resendOtp,
                                          child: Text(
                                            _isResending
                                                ? 'Sending OTP...'
                                                : 'Resend OTP',
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: _purpleLink,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: _purpleLink,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 35.h),

                                // OTP Verify Button (Figma specs: Fill 353px, height 44px, radius 12px, background #242A37, padding 15x8.8px, gap 7.04px)
                                GestureDetector(
                                  onTap: _isVerifying || _isResending
                                      ? null
                                      : _verifyAndContinue,
                                  child: Container(
                                    width: double.infinity,
                                    height: 44.h,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.8.w,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _darkButton,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    alignment: Alignment.center,
                                    child: _isVerifying
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

                                // Bottom "Didn't receive the code? Resend OTP" Text
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
                                        const TextSpan(
                                          text: "Didn't receive the code? ",
                                        ),
                                        if (_resendTimerSeconds > 0)
                                          TextSpan(
                                            text:
                                                "Resend OTP in ${_resendTimerSeconds}s",
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontSize: 12.22.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF8E8E93),
                                            ),
                                          )
                                        else
                                          TextSpan(
                                            text: _isResending
                                                ? "Sending..."
                                                : "Resend OTP",
                                            style: TextStyle(
                                              fontFamily: 'Gilroy',
                                              fontSize: 12.22.sp,
                                              fontWeight: FontWeight.w700,
                                              color: (_isVerifying ||
                                                      _isResending)
                                                  ? const Color(0xFF8E8E93)
                                                  : _purpleLink,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: _purpleLink,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = (_isVerifying ||
                                                      _isResending)
                                                  ? null
                                                  : _resendOtp,
                                          ),
                                      ],
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
              );
            },
          ),
        ),
      ),
    );
  }
}
