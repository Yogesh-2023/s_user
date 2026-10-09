// import 'package:dobelgodelivery/features/activity/activity_screen.dart';
import 'package:dobelgodelivery/features/support/help_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../widgets/common_app_bar.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../core/socket/socket_service.dart';
import 'profile_edit_screen.dart';
import '../auth/phone_login_screen.dart';
import 'terms_conditions_screen.dart';
import 'saved_address_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils.dart';
import '../../services/push_notification_service.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_response.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();
  UserProfile? _profile;
  bool _isUploadingAvatar = false;

  void _showAvatarOptionsBottomSheet() {
    if (_isUploadingAvatar) return;

    final hasAvatar = _profile != null && _profile!.avatar.trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.only(
          top: 14.h,
          left: 20.w,
          right: 20.w,
          bottom: MediaQuery.of(context).padding.bottom + 20.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Profile Photo',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16.h),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9E6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: const Color(0xFFF4B41A),
                  size: 22.sp,
                ),
              ),
              title: Text(
                'Change photo',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showImagePickerSourceSheet();
              },
            ),
            if (hasAvatar) ...[
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 22.sp,
                  ),
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleRemovePhoto();
                },
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.grey.shade700,
                  size: 22.sp,
                ),
              ),
              title: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.only(
          top: 14.h,
          left: 20.w,
          right: 20.w,
          bottom: MediaQuery.of(context).padding.bottom + 20.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Select Image Source',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _handlePickAndUploadPhoto(ImageSource.camera);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: const Color(0xFFF4B41A),
                            size: 32.sp,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Camera',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _handlePickAndUploadPhoto(ImageSource.gallery);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_library_rounded,
                            color: const Color(0xFFF4B41A),
                            size: 32.sp,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Gallery',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePickAndUploadPhoto(ImageSource source) async {
    if (_isUploadingAvatar) return;

    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: source);
      if (img == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final newUrl = await _service.uploadProfileImageFile(img);
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          if (newUrl != null && newUrl.isNotEmpty) {
            if (_profile != null) {
              _profile = _profile!.copyWith(avatar: newUrl);
            } else {
              _profile = UserProfile(
                id: '',
                userId: '',
                firstname: '',
                lastname: '',
                name: 'User',
                email: '',
                phone: '',
                avatar: newUrl,
                requirement: '',
              );
            }
          }
        });
        if (newUrl != null && newUrl.isNotEmpty) {
          AppUtils.showSnackBar(context, 'Profile picture updated successfully.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        if (e is ApiException && e.statusCode == 401) {
          AppUtils.showSnackBar(context, 'Session expired. Please login again.', isError: true);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
            (route) => false,
          );
        } else {
          final msg = e is ApiException ? e.message : e.toString().replaceAll('ApiException:', '').trim();
          AppUtils.showSnackBar(context, msg, isError: true);
        }
      }
    }
  }

  Future<void> _handleRemovePhoto() async {
    if (_isUploadingAvatar) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final success = await _service.deleteProfileImage();
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          if (success && _profile != null) {
            _profile = _profile!.copyWith(avatar: '');
          }
        });
        if (success) {
          AppUtils.showSnackBar(context, 'Profile photo removed.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
        if (e is ApiException && e.statusCode == 401) {
          AppUtils.showSnackBar(context, 'Session expired. Please login again.', isError: true);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
            (route) => false,
          );
        } else {
          final msg = e is ApiException ? e.message : e.toString().replaceAll('ApiException:', '').trim();
          AppUtils.showSnackBar(context, msg, isError: true);
        }
      }
    }
  }

  UserProfile _mergeProfile(UserProfile api, UserProfile? existing) {
    String prefer(String value, String fallback) =>
        value.trim().isNotEmpty ? value : fallback;

    return UserProfile(
      id: prefer(api.id, existing?.id ?? ''),
      userId: prefer(api.userId, existing?.userId ?? ''),
      firstname: prefer(api.firstname, existing?.firstname ?? ''),
      lastname: prefer(api.lastname, existing?.lastname ?? ''),
      name: prefer(api.name, existing?.name ?? ''),
      email: prefer(api.email, existing?.email ?? ''),
      phone: prefer(api.phone, existing?.phone ?? ''),
      avatar: prefer(api.avatar, existing?.avatar ?? ''),
      requirement: prefer(api.requirement, existing?.requirement ?? ''),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    await _loadCachedProfile();
    _fetchBackgroundApis();
  }

  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('user_name') ?? '';
      final cachedPhone = prefs.getString('user_phone') ?? '';
      final cachedEmail = prefs.getString('user_email') ?? '';
      final cachedUserId = prefs.getString('user_id') ?? '';
      final cachedAvatar = prefs.getString('user_avatar') ?? '';

      if (cachedName.isNotEmpty || cachedPhone.isNotEmpty || cachedUserId.isNotEmpty) {
        if (mounted) {
          setState(() {
            _profile = UserProfile(
              id: cachedUserId,
              userId: cachedUserId,
              firstname: cachedName.split(' ').first,
              lastname: cachedName.contains(' ')
                  ? cachedName.split(' ').sublist(1).join(' ')
                  : '',
              name: cachedName,
              email: cachedEmail,
              phone: cachedPhone,
              avatar: cachedAvatar,
              requirement: '',
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading cached profile: $e");
    }
  }

  void _fetchBackgroundApis() {
    _fetchProfileApi();
    _fetchUnreadNotificationsApi();
    _fetchActiveBookingApi();
  }

  Future<void> _fetchProfileApi() async {
    try {
      final prof = await _service.getMyProfile().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (prof != null) {
        final resolvedProfile = _mergeProfile(prof, _profile);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', resolvedProfile.userId);
        if (resolvedProfile.name.isNotEmpty) {
          await prefs.setString('user_name', resolvedProfile.name);
        }
        if (resolvedProfile.phone.isNotEmpty) {
          await prefs.setString('user_phone', resolvedProfile.phone);
        }
        if (resolvedProfile.email.isNotEmpty) {
          await prefs.setString('user_email', resolvedProfile.email);
        }
        if (resolvedProfile.avatar.isNotEmpty) {
          await prefs.setString('user_avatar', resolvedProfile.avatar);
        }
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          if (!SocketService.to.isConnected && !SocketService.to.isConnecting) {
            SocketService.to.initSocket(
              sessionToken: token,
              userId: resolvedProfile.userId,
            );
          }
        }
        if (mounted) {
          setState(() {
            _profile = resolvedProfile;
          });
        }
      }
    } catch (e) {
      debugPrint("Silent background profile fetch error: $e");
    }
  }

  Future<void> _fetchUnreadNotificationsApi() async {
    try {
      await ApiService.to.get(ApiEndpoints.unreadNotificationCount).timeout(
        const Duration(seconds: 4),
        onTimeout: () => ApiResponse(
          data: null,
          statusCode: 408,
          message: 'Request Timeout',
        ),
      );
    } catch (e) {
      debugPrint("Silent background unread notifications count error: $e");
    }
  }

  Future<void> _fetchActiveBookingApi() async {
    try {
      await ApiService.to.get(ApiEndpoints.activeBooking).timeout(
        const Duration(seconds: 4),
        onTimeout: () => ApiResponse(
          data: null,
          statusCode: 408,
          message: 'Request Timeout',
        ),
      );
    } catch (e) {
      debugPrint("Silent background active booking error: $e");
    }
  }

  Future<void> _loadProfile() async {
    await _fetchProfileApi();
  }

  Future<void> _logout() async {
    try {
      await ApiService.to.post(ApiEndpoints.logout);
    } catch (_) {
      // Local logout must still complete when the session is already expired.
    }
    await PushNotificationService.instance.removeToken();
    await ApiClient.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    SocketService.to.closeSocket();

    if (mounted) {
      AppUtils.showSnackBar(context, 'Logged out successfully');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PhoneLoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmLogout() async {
    var isLoggingOut = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24.r),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20.w,
            28.h,
            20.w,
            MediaQuery.of(context).padding.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logout Icon Circle
              Container(
                width: 72.w,
                height: 72.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9E6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: const Color(0xFFF4B41A),
                    size: 32.sp,
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Title: Logout Account ?
              Text(
                'Logout Account ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8.h),

              // Description
              Text(
                'Are you sure you want to logout from your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFF7E7E7E),
                ),
              ),
              SizedBox(height: 28.h),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: OutlinedButton(
                        onPressed: isLoggingOut
                            ? null
                            : () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: const Color(0xFFEEEEEE),
                            width: 1.w,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: isLoggingOut
                            ? null
                            : () async {
                                setSheetState(() => isLoggingOut = true);
                                await _logout();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4B41A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: isLoggingOut
                            ? SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Logout',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToEdit() async {
    final result = await Navigator.push<UserProfile?>(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(profile: _profile),
      ),
    );
    if (result != null) {
      setState(() {
        _profile = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = _profile != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.fleetgoYellow,
                      onRefresh: _loadProfile,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                        child: Center(
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 360.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Profile Container Card (Figma style)
                                GestureDetector(
                                  onTap: _navigateToEdit,
                                  child: Container(
                                    width: double.infinity,
                                    constraints: BoxConstraints(
                                      minHeight: 74.h,
                                    ),
                                    padding: EdgeInsets.all(12.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9F9FA),
                                      borderRadius: BorderRadius.circular(15.r),
                                      border: Border.all(
                                        color: const Color(0xFFEEEEEE),
                                        width: 1.w,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                         // Left profile image/icon container with Tap to edit/remove photo
                                         GestureDetector(
                                           onTap: _showAvatarOptionsBottomSheet,
                                           child: Container(
                                             width: 52.w,
                                             height: 52.w,
                                             decoration: BoxDecoration(
                                               color: const Color(0xFFFFF9E6),
                                               borderRadius: BorderRadius.circular(12.r),
                                               border: Border.all(
                                                 color: const Color(0xFFFFC000),
                                                 width: 1.5.w,
                                               ),
                                             ),
                                             child: ClipRRect(
                                               borderRadius: BorderRadius.circular(10.r),
                                               child: _isUploadingAvatar
                                                   ? Center(
                                                       child: SizedBox(
                                                         width: 20.w,
                                                         height: 20.w,
                                                         child: const CircularProgressIndicator(
                                                           strokeWidth: 2,
                                                           color: Colors.black,
                                                         ),
                                                       ),
                                                     )
                                                   : (hasProfile && _profile!.avatar.trim().isNotEmpty)
                                                       ? Image.network(
                                                           _profile!.avatar.trim(),
                                                           width: 52.w,
                                                           height: 52.w,
                                                           fit: BoxFit.cover,
                                                           loadingBuilder: (context, child, progress) {
                                                             if (progress == null) return child;
                                                             return Center(
                                                               child: SizedBox(
                                                                 width: 18.w,
                                                                 height: 18.w,
                                                                 child: const CircularProgressIndicator(
                                                                   strokeWidth: 2,
                                                                   color: Colors.black,
                                                                 ),
                                                               ),
                                                             );
                                                           },
                                                           errorBuilder: (context, error, stackTrace) => Center(
                                                             child: Text(
                                                               hasProfile ? _profile!.initials : 'U',
                                                               style: TextStyle(
                                                                 fontFamily: AppFonts.fontFamily,
                                                                 fontSize: 18.sp,
                                                                 fontWeight: FontWeight.bold,
                                                                 color: Colors.black,
                                                               ),
                                                             ),
                                                           ),
                                                         )
                                                       : Center(
                                                           child: Text(
                                                             hasProfile ? _profile!.initials : 'U',
                                                             style: TextStyle(
                                                               fontFamily: AppFonts.fontFamily,
                                                               fontSize: 18.sp,
                                                               fontWeight: FontWeight.bold,
                                                               color: Colors.black,
                                                             ),
                                                           ),
                                                         ),
                                             ),
                                           ),
                                         ),
                                        SizedBox(width: 12.w),
                                        // User Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                (hasProfile &&
                                                        (_profile!
                                                                .name
                                                                .isNotEmpty ||
                                                            _profile!
                                                                .firstname
                                                                .isNotEmpty ||
                                                            _profile!
                                                                .lastname
                                                                .isNotEmpty))
                                                    ? (_profile!.name.isNotEmpty
                                                          ? _profile!.name
                                                          : '${_profile!.firstname} ${_profile!.lastname}'
                                                                .trim())
                                                    : 'Guest User',
                                                style: TextStyle(
                                                  fontFamily:
                                                      AppFonts.fontFamily,
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (hasProfile &&
                                                  _profile!.phone
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                SizedBox(height: 4.h),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      color: const Color(
                                                        0xFFFFB800,
                                                      ),
                                                      size: 14.sp,
                                                    ),
                                                    SizedBox(width: 4.w),
                                                    Text(
                                                      _profile!.phone.trim(),
                                                      style: TextStyle(
                                                        fontFamily:
                                                            AppFonts.fontFamily,
                                                        fontSize: 13.sp,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: const Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24.h),

                                // Account Info Section
                                _buildAccountSection(context),
                                SizedBox(height: 24.h),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return CommonAppBar(
      title: 'My Profile',
      trailingAction: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.notifications_none_rounded,
          size: 18.sp,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Info',
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 20.h),
        _buildProfileCard(
          icon: Icons.person_outline_rounded,
          iconAsset: 'assets/icons/profile_menu_icon.png',
          title: 'My Profile',
          subtitle: 'Manage your account',
          onTap: _navigateToEdit,
        ),
        _buildProfileCard(
          icon: Icons.favorite_border_rounded,
          title: 'Saved Address',
          subtitle: 'Here you can manage addresses',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedAddressScreen(),
              ),
            );
          },
        ),
        _buildProfileCard(
          icon: Icons.description_outlined,
          title: 'Terms & Conditions',
          subtitle: 'Read our terms of service',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TermsConditionsScreen(),
              ),
            );
          },
        ),
        _buildProfileCard(
          icon: Icons.support_agent_rounded,
          title: 'Help & Support',
          subtitle: 'Raise tickets & track support issues',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HelpSupportScreen(),
              ),
            );
          },
        ),
        _buildLogoutCard(),
        _buildDeleteAccountCard(context),
      ],
    );
  }

  Widget _buildProfileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    String? iconAsset,
    Color? borderColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      constraints: BoxConstraints(minHeight: 56.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: borderColor ?? const Color(0xFFEEEEEE), width: 1.w),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.only(
            top: 8.h,
            right: 15.w,
            bottom: 8.h,
            left: 8.w,
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FA),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: iconAsset != null
                      ? Image.asset(
                          iconAsset,
                          width: 22.w,
                          height: 22.w,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          icon,
                          color: iconColor ?? const Color(0xFF475569),
                          size: 20.sp,
                        ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        letterSpacing: 0.0,
                        color: textColor ?? const Color(0xFF000000),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color:
                            textColor?.withOpacity(0.8) ??
                            const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: textColor ?? const Color(0xFF64748B),
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return _buildProfileCard(
      icon: Icons.logout_outlined,
      title: 'Logout',
      subtitle: 'Sign out of your account',
      onTap: _confirmLogout,
    );
  }

  Widget _buildDeleteAccountCard(BuildContext context) {
    return _buildProfileCard(
      icon: Icons.delete_forever_outlined,
      title: 'Delete Account',
      subtitle: 'Permanently remove your data',
      textColor: Colors.red,
      iconColor: Colors.red,
      borderColor: Colors.red,
      onTap: () => _confirmDeleteAccount(context),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.all(24.w),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Delete Account',
                style: AppFonts.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Are you sure you want to delete your account? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: AppFonts.bodyText.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.bodyText.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ApiService.to.post(
                            ApiEndpoints.deletionRequest,
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          AppUtils.showSnackBar(
                            context,
                            error.toString(),
                            isError: true,
                          );
                          return;
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context); // Close the dialog

                        // Show success pop up
                        AppUtils.showSnackBar(
                          context,
                          'Your Request has been Submitted Successfully',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'Delete',
                        style: AppFonts.bodyText.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
