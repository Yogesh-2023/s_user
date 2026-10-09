import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';
import '../core/api/api_service.dart';
import 'profile_service.dart';

enum AppSessionState { signedOut, profileIncomplete, profileComplete }

class AuthSessionService {
  const AuthSessionService._();

  static Future<AppSessionState> resolve() async {
    final headers = await ApiClient.authHeaders();
    final hasCredential =
        headers.containsKey('Cookie') || headers.containsKey('Authorization');
    if (!hasCredential) return AppSessionState.signedOut;

    try {
      await ApiService.to.get(ApiEndpoints.authSession);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await ApiClient.clearSession();
        return AppSessionState.signedOut;
      }
      return _cachedState();
    } catch (_) {
      return _cachedState();
    }

    bool complete = false;
    try {
      final response = await ApiService.to.get(ApiEndpoints.onboardingStatus);
      final raw = response.data is Map && response.data['data'] is Map
          ? response.data['data'] as Map
          : response.data is Map
          ? response.data as Map
          : const <String, dynamic>{};
      complete =
          raw['isProfileComplete'] == true ||
          raw['profileComplete'] == true ||
          raw['completed'] == true ||
          raw['isOnboarded'] == true ||
          raw['onboardingComplete'] == true;
    } catch (_) {}

    if (!complete) {
      final profile = await ProfileService().getMyProfile();
      complete =
          profile != null &&
          (profile.name.trim().isNotEmpty ||
              profile.firstname.trim().isNotEmpty);
    }

    await setProfileComplete(complete);
    return complete
        ? AppSessionState.profileComplete
        : AppSessionState.profileIncomplete;
  }

  static Future<AppSessionState> _cachedState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('profile_complete') == true
        ? AppSessionState.profileComplete
        : AppSessionState.profileIncomplete;
  }

  static Future<void> setProfileComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_complete', value);
  }
}
