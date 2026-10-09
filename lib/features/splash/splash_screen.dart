import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../auth/onboarding_screen.dart';
import '../auth/personal_information_screen.dart';
import '../main_navigation_screen.dart';
import '../../services/auth_session_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final session = await AuthSessionService.resolve();
    if (!mounted) return;
    final Widget destination = switch (session) {
      AppSessionState.profileComplete => const MainNavigationScreen(),
      AppSessionState.profileIncomplete => const PersonalInformationScreen(),
      AppSessionState.signedOut => const OnboardingScreen(),
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/bottomsheet1.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              alignment: Alignment.bottomCenter,
            ),
          ),
          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const double designWidth = 136.0;
                  const double designHeight = 160.0;
                  const double gap = 15.0;

                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: designWidth.w,
                      height: designHeight.h,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Responsive Logo Icon (Max height 96px to complete exact 160px vertical layout)
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 96.h,
                                maxWidth: 136.w,
                              ),
                              child: Image.asset(
                                'assets/icons/splashlogo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Image.asset(
                                  'assets/images/sawariya_login_logo.png',
                                  height: 36.h,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: gap.h),

                          // 2. "Sawariyaa" Title (Figma height 21px, 30px Gilroy Bold, single line)
                          SizedBox(
                            height: 21.h,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: RichText(
                                textAlign: TextAlign.center,
                                softWrap: false,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 30.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                    letterSpacing: 0,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Sawa',
                                      style: TextStyle(
                                        color: Color(0xFF000000),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'riyaa',
                                      style: TextStyle(
                                        color: Color(0xFFFFC000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: gap.h),

                          // 3. "Book Easy, Feel Happy" Subtitle (Figma height 13px, 10px Gilroy Regular, single line)
                          SizedBox(
                            height: 13.h,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                'Book Easy, Feel Happy',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF000000),
                                  height: 1.0,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
