import 'package:get/get.dart';
import '../../../services/notification_api_service.dart';

class NotificationPreferencesController extends GetxController {
  var emailNotifications = true.obs;
  var pushNotifications = true.obs;
  var smsNotifications = true.obs;
  var promotionalNotifications = true.obs;
  var systemNotifications = true.obs;

  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPreferences();
  }

  Future<void> fetchPreferences() async {
    isLoading.value = true;
    try {
      final prefs = await NotificationApiService.fetchPreferences();
      emailNotifications.value = prefs['email'] ?? true;
      pushNotifications.value = prefs['push'] ?? true;
      smsNotifications.value = prefs['sms'] ?? true;
      promotionalNotifications.value = prefs['promotional'] ?? true;
      systemNotifications.value =
          prefs['system'] ?? true; // often enforced by backend
    } catch (e) {
      Get.snackbar('Error', 'Failed to load preferences.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updatePreferences() async {
    final data = {
      'email': emailNotifications.value,
      'push': pushNotifications.value,
      'sms': smsNotifications.value,
      'promotional': promotionalNotifications.value,
    };
    try {
      await NotificationApiService.updatePreferences(data);
      Get.snackbar('Success', 'Preferences updated successfully.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update preferences.');
    }
  }
}
