import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'phone_login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  static const Color _yellow = Color(0xFFFFC000);
  static const Color _darkText = Color(0xFF0D0D0D);

  final List<Map<String, dynamic>> _onboardingPages = [
    {
      'badge': 'Ride Anytime',
      'titleSpans': [
        {'text': 'Your Journey ', 'isYellow': false},
        {'text': 'Starts\n', 'isYellow': true},
        {'text': 'With Sawariyaa', 'isYellow': false},
      ],
      'description':
          'Book a ride in seconds and reach your destination with a fast, simple, and reliable travel experience.',
    },
    {
      'badge': 'Plan Ahead',
      'titleSpans': [
        {'text': 'Schedule Your ', 'isYellow': false},
        {'text': 'Rides\n', 'isYellow': true},
        {'text': 'With ', 'isYellow': true},
        {'text': 'Confidence', 'isYellow': false},
      ],
      'description':
          'Choose your preferred date and time, and let Sawariyaa be ready whenever your journey begins.',
    },
    {
      'badge': 'Travel Safely',
      'titleSpans': [
        {'text': 'Track Every ', 'isYellow': true},
        {'text': 'Ride With\n', 'isYellow': false},
        {'text': 'Confidence', 'isYellow': false},
      ],
      'description':
          'Follow your trip in real time, share your journey with loved ones, and travel with verified drivers.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _onboardingPages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToNextScreen();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToNextScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhoneLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row (Sawariyaa Logo + Skip Button)
            _OnboardingHeader(onSkipTap: _navigateToNextScreen),

            // PageView Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingPages.length,
                itemBuilder: (context, index) {
                  final page = _onboardingPages[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Center Illustration Image (Consistent across screens)
                        Expanded(
                          child: Center(
                            child: Image.asset(
                              'assets/images/onboardingscreen.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Image.asset(
                                'assets/images/image 16.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.directions_car,
                                  size: 120.sp,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 12.h),

                        // Badge Chip Component (Identical calendar PNG for all chips)
                        _OnboardingBadge(
                          label: page['badge'] as String,
                        ),

                        SizedBox(height: 12.h),

                        // Headline Title & Description
                        _OnboardingTitleSection(
                          titleSpans: page['titleSpans'] as List<Map<String, dynamic>>,
                          description: page['description'] as String,
                        ),

                        SizedBox(height: 16.h),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Buttons
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 15.h, 20.w, 17.h),
              child: _buildBottomButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_currentPage == 0) {
      // Screen 1: Single full-width Continue button (light grey background per Figma screenshot)
      return _OnboardingButton(
        label: 'Continue',
        onTap: _nextPage,
        backgroundColor: const Color(0xFFF7F7F7),
        borderColor: const Color(0xFFE5E5E5),
      );
    } else if (_currentPage == 1) {
      // Screen 2: Back (White + Border) & Continue (#FFC000)
      return Row(
        children: [
          Expanded(
            child: _OnboardingButton(
              label: 'Back',
              onTap: _previousPage,
              backgroundColor: Colors.white,
              borderColor: const Color(0xFFE5E5E5),
              textColor: _darkText,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: _OnboardingButton(
              label: 'Continue',
              onTap: _nextPage,
              backgroundColor: _yellow,
            ),
          ),
        ],
      );
    } else {
      // Screen 3: Single full-width Get Started button (#FFC000)
      return _OnboardingButton(
        label: 'Get Started',
        onTap: _navigateToNextScreen,
        backgroundColor: _yellow,
      );
    }
  }
}

// Reusable Top Header Component (Sawariyaa Logo + Skip)
class _OnboardingHeader extends StatelessWidget {
  final VoidCallback onSkipTap;

  const _OnboardingHeader({required this.onSkipTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sawariyaa Logo (Figma asset)
          Image.asset(
            'assets/images/sawariya_login_logo.png',
            width: 140.w,
            height: 40.h,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/images/image6.png',
              width: 140.w,
              height: 40.h,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Sawariyaa',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 22.67,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Skip Button
          _SkipButton(onTap: onSkipTap),
        ],
      ),
    );
  }
}

// Reusable Skip Button Component
class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(200.r),
        ),
        child: Text(
          'Skip',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
      ),
    );
  }
}

// Reusable Feature Badge Chip Component (Pixel-perfect Figma specs with Calendar PNG icon)
class _OnboardingBadge extends StatelessWidget {
  final String label;

  const _OnboardingBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32.h,
      padding: EdgeInsets.only(
        top: 5.h,
        bottom: 5.h,
        left: 6.w,
        right: 14.w,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(35.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circle icon container with calendar PNG
          Container(
            width: 22.r,
            height: 22.r,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC000),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/calendar.png',
              width: 12.w,
              height: 12.h,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Image.asset(
                'assets/icons/Icons.png',
                width: 12.w,
                height: 12.h,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.calendar_today_rounded,
                  size: 11.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D0D0D),
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Title & Subtitle Section Component
class _OnboardingTitleSection extends StatelessWidget {
  final List<Map<String, dynamic>> titleSpans;
  final String description;

  const _OnboardingTitleSection({
    required this.titleSpans,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: titleSpans.map((span) {
              final isYellow = span['isYellow'] as bool;
              return TextSpan(
                text: span['text'] as String,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: 0,
                  color: isYellow ? const Color(0xFFFFC000) : Colors.black,
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          description,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 13.sp,
            height: 1.35,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}

// Reusable Onboarding Button Component (Figma specs: height 46px, radius 59px, color #FFC000)
class _OnboardingButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color? borderColor;
  final Color textColor;

  const _OnboardingButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    this.borderColor,
    this.textColor = const Color(0xFF0D0D0D),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46.h,
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(59.r),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
