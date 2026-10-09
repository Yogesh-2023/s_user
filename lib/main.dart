import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/api/api_service.dart';
import 'core/socket/socket_service.dart';
import 'features/splash/splash_screen.dart';
import 'core/network/network_controller.dart';
import 'core/network/network_wrapper.dart';
import 'constants/app_dimensions.dart';
import 'services/review_service.dart';
import 'services/push_notification_service.dart';
import 'features/notifications/controllers/notification_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Platform.isAndroid) {
    final GoogleMapsFlutterPlatform mapsImplementation =
        GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      // Texture-layer composition keeps embedded maps below Flutter overlays
      // such as the app's bottom navigation and subsequently selected tabs.
      mapsImplementation.useAndroidViewSurface = false;
    }
  }

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  Get.put<ApiService>(ApiService(), permanent: permanentApiCheck());
  Get.put<SocketService>(SocketService(), permanent: true);
  Get.put<NetworkController>(NetworkController(), permanent: true);
  Get.put<ReviewService>(ReviewService(), permanent: true);
  Get.put<NotificationController>(NotificationController(), permanent: true);
  runApp(const MyApp());

  // Wait until the first frame so Android has attached the Activity before
  // notification plugins request runtime permission.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializePushNotifications());
  });
}

Future<void> _initializePushNotifications() async {
  try {
    await PushNotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Push notification initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

bool permanentApiCheck() => true;

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil for responsive design
    // We use a common size like 375x812 (iPhone X/11/12/13/14 Pro)
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Sawariyaa',
          scrollBehavior: const AppScrollBehavior(),
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Gilroy',
            timePickerTheme: TimePickerThemeData(
              hourMinuteTextStyle: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 42.sp,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              timeSelectorSeparatorTextStyle: WidgetStateProperty.all(
                TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 40.sp,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00ABE4),
              primary: const Color(0xFF00ABE4),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(0, AppDimensions.controlHeight.h),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, AppDimensions.controlHeight.h),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              constraints: BoxConstraints(
                minHeight: AppDimensions.controlHeight.h,
              ),
            ),
            textTheme: Typography.englishLike2018.apply(
              fontFamily: 'Gilroy',
            ),
          ),
          builder: (context, appChild) {
            final mediaQueryData = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  final currentFocus = FocusManager.instance.primaryFocus;
                  if (currentFocus != null && !currentFocus.hasPrimaryFocus) {
                    currentFocus.unfocus();
                  }
                },
                child: NetworkWrapper(
                  child: appChild ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: child,
        );
      },
      child: const SplashScreen(), // Starts with Splash Screen
    );
  }
}
