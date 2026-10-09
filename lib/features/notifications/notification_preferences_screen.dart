import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import 'controllers/notification_preferences_controller.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({Key? key}) : super(key: key);

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final NotificationPreferencesController _controller = Get.put(
    NotificationPreferencesController(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fleetgoSurface,
      appBar: AppBar(
        backgroundColor: AppColors.fleetgoTint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Notification Settings',
          style: AppFonts.semiBold(size: 20, color: Colors.black),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.fleetgoYellow),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSwitchTile(
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              value: _controller.emailNotifications.value,
              onChanged: (val) {
                _controller.emailNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Receive push notifications on this device',
              value: _controller.pushNotifications.value,
              onChanged: (val) {
                _controller.pushNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'SMS Notifications',
              subtitle: 'Receive text messages for important updates',
              value: _controller.smsNotifications.value,
              onChanged: (val) {
                _controller.smsNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'Promotional Notifications',
              subtitle: 'Receive offers and promotional messages',
              value: _controller.promotionalNotifications.value,
              onChanged: (val) {
                _controller.promotionalNotifications.value = val;
                _controller.updatePreferences();
              },
            ),
            _buildSwitchTile(
              title: 'System Notifications',
              subtitle: 'Critical system updates (cannot be disabled)',
              value: _controller.systemNotifications.value,
              onChanged: null, // Disabled
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fleetgoYellow.withOpacity(0.14)),
      ),
      child: SwitchListTile(
        title: Text(title, style: AppFonts.medium(size: 16)),
        subtitle: Text(
          subtitle,
          style: AppFonts.regular(size: 14, color: Colors.grey[600]!),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.fleetgoYellow,
        activeTrackColor: AppColors.fleetgoYellow.withOpacity(0.35),
      ),
    );
  }
}
