// File generated for truck-flutter (User App) connected to sawariya-user.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPMBN0CEVaeQmo5HoVsZ1IksgXxYwrpRo',
    appId: '1:844119157783:android:f2d4cee9fbaab155130052',
    messagingSenderId: '844119157783',
    projectId: 'sawariya-user',
    storageBucket: 'sawariya-user.firebasestorage.app',
  );
}
