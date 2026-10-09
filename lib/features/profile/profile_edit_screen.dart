import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils.dart';
import '../auth/phone_login_screen.dart';
import 'package:flutter/services.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserProfile? profile;
  const ProfileEditScreen({Key? key, this.profile}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final ProfileService _service = ProfileService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _firstCtrl;
  late TextEditingController _lastCtrl;
  String _requirement = 'PERSONAL';
  String _originalPhone = '';
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final fullName = (p?.name ?? '').isNotEmpty
        ? p!.name
        : [p?.firstname ?? '', p?.lastname ?? ''].join(' ').trim();
    _nameCtrl = TextEditingController(text: fullName);
    _emailCtrl = TextEditingController(text: p?.email ?? '');

    String initialPhone = p?.phone ?? '';
    if (initialPhone.startsWith('+91')) {
      initialPhone = initialPhone.substring(3);
    } else if (initialPhone.startsWith('91') && initialPhone.length > 10) {
      initialPhone = initialPhone.substring(2);
    }
    _phoneCtrl = TextEditingController(text: initialPhone);
    _originalPhone = initialPhone;

    _firstCtrl = TextEditingController(text: p?.firstname ?? '');
    _lastCtrl = TextEditingController(text: p?.lastname ?? '');

    if (p != null && p.requirement.isNotEmpty) {
      _requirement = p.requirement.toUpperCase();
    }
    if (p == null) {
      _loadSavedPhone();
    }
    _phoneCtrl.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('user_phone') ?? '';
    if (phone.isNotEmpty) {
      String sanitized = phone.trim();
      if (sanitized.startsWith('+91')) {
        sanitized = sanitized.substring(3);
      } else if (sanitized.startsWith('91') && sanitized.length > 10) {
        sanitized = sanitized.substring(2);
      }
      setState(() {
        _phoneCtrl.text = sanitized;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  bool _isUploadingAvatar = false;
  String? _uploadedAvatarUrl;

  void _showAvatarOptionsBottomSheet() {
    if (_isUploadingAvatar) return;

    final currentAvatar = _uploadedAvatarUrl ?? widget.profile?.avatar;
    final hasAvatar = _selectedImage != null || (currentAvatar != null && currentAvatar.trim().isNotEmpty);

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
      final img = await _picker.pickImage(source: source);
      if (img == null) return;

      setState(() {
        _isUploadingAvatar = true;
      });

      final newUrl = await _service.uploadProfileImageFile(img);
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          _selectedImage = img;
          if (newUrl != null && newUrl.isNotEmpty) {
            _uploadedAvatarUrl = newUrl;
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
          _selectedImage = null;
          _uploadedAvatarUrl = '';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final fullName = _nameCtrl.text.trim();
    final parts = fullName.split(' ');
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final newPhone = _phoneCtrl.text.trim();
    final formattedPhone = newPhone.startsWith('+') ? newPhone : '+91$newPhone';

    final Map<String, String> fields = {
      'name': fullName,
      'email': _emailCtrl.text.trim(),
      'phone': formattedPhone,
      'firstname': first,
      'lastname': last,
      'requirement': _requirement,
    };

    if (newPhone != _originalPhone && newPhone.isNotEmpty) {
      AppUtils.showSnackBar(
        context,
        'Please verify your new phone number first.',
        isError: true,
      );
      setState(() => _isLoading = false);
      return;
    }
    _performSave(fields);
  }

  Future<void> _performSave(Map<String, String> fields) async {
    try {
      UserProfile? result;
      String? uploadedAvatarUrl;

      // If user selected a new profile image, upload it via PUT API first
      if (_selectedImage != null) {
        try {
          uploadedAvatarUrl = await _service.uploadProfileImage(
            imagePath: _selectedImage!.path,
          );
        } catch (imgErr) {
          debugPrint('Profile image upload via PUT error: $imgErr');
        }
      }

      if (widget.profile == null) {
        result = await _service.createProfile(
          fields: fields,
          avatarPath: _selectedImage?.path,
        );
      } else {
        result = await _service.updateProfile(
          fields: fields,
          avatarPath: _selectedImage?.path,
        );
      }

      if (result != null && uploadedAvatarUrl != null && uploadedAvatarUrl.isNotEmpty) {
        result = UserProfile(
          id: result.id,
          userId: result.userId,
          firstname: result.firstname,
          lastname: result.lastname,
          name: result.name,
          email: result.email,
          phone: result.phone,
          avatar: uploadedAvatarUrl,
          requirement: result.requirement,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (result != null) {
          final prefs = await SharedPreferences.getInstance();
          if (result.avatar.isNotEmpty) {
            await prefs.setString('user_avatar', result.avatar);
          }
          if (result.name.isNotEmpty) {
            await prefs.setString('user_name', result.name);
          }
          Navigator.pop(context, result);
        } else {
          AppUtils.showSnackBar(
            context,
            'Failed to save profile',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String errorMessage = e is ApiException
            ? e.message
            : e.toString().replaceAll('ApiException:', '').trim();
        AppUtils.showSnackBar(context, errorMessage, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.profile != null;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context, isEditMode),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 24.h,
                  ),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 360.w),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 8.h),
                             // Avatar Picker Placeholder
                             GestureDetector(
                               onTap: _showAvatarOptionsBottomSheet,
                               child: Stack(
                                 alignment: Alignment.center,
                                 children: [
                                   Container(
                                     width: 120.r,
                                     height: 120.r,
                                     decoration: BoxDecoration(
                                       shape: BoxShape.circle,
                                       color: Colors.white,
                                       border: Border.all(
                                         color: const Color(0xFFFFC000),
                                         width: 2.w,
                                       ),
                                     ),
                                     alignment: Alignment.center,
                                     child: Container(
                                       width: 102.r,
                                       height: 102.r,
                                       decoration: const BoxDecoration(
                                         shape: BoxShape.circle,
                                         color: Color(0xFFFFF9E6),
                                       ),
                                       child: ClipOval(
                                         child: _isUploadingAvatar
                                             ? Center(
                                                 child: SizedBox(
                                                   width: 28.r,
                                                   height: 28.r,
                                                   child: const CircularProgressIndicator(
                                                     strokeWidth: 3,
                                                     color: Colors.black,
                                                   ),
                                                 ),
                                               )
                                             : _selectedImage != null
                                                 ? Image.file(
                                                     File(_selectedImage!.path),
                                                     fit: BoxFit.cover,
                                                     width: 102.r,
                                                     height: 102.r,
                                                   )
                                                 : ((_uploadedAvatarUrl ?? widget.profile?.avatar ?? '').trim().isNotEmpty)
                                                     ? Image.network(
                                                         (_uploadedAvatarUrl ?? widget.profile!.avatar).trim(),
                                                         fit: BoxFit.cover,
                                                         width: 102.r,
                                                         height: 102.r,
                                                         loadingBuilder: (context, child, progress) {
                                                           if (progress == null) return child;
                                                           return Center(
                                                             child: SizedBox(
                                                               width: 24.r,
                                                               height: 24.r,
                                                               child: const CircularProgressIndicator(
                                                                 strokeWidth: 2.5,
                                                                 color: Colors.black,
                                                               ),
                                                             ),
                                                           );
                                                         },
                                                         errorBuilder: (context, error, stackTrace) => Center(
                                                           child: Text(
                                                             widget.profile?.initials ?? 'U',
                                                             style: TextStyle(
                                                               fontFamily: AppFonts.fontFamily,
                                                               fontSize: 32.sp,
                                                               fontWeight: FontWeight.bold,
                                                               color: Colors.black,
                                                             ),
                                                           ),
                                                         ),
                                                       )
                                                     : Center(
                                                         child: Text(
                                                           widget.profile?.initials ?? 'U',
                                                           style: TextStyle(
                                                             fontFamily: AppFonts.fontFamily,
                                                             fontSize: 32.sp,
                                                             fontWeight: FontWeight.bold,
                                                             color: Colors.black,
                                                           ),
                                                         ),
                                                       ),
                                       ),
                                     ),
                                   ),
                                   Positioned(
                                     bottom: 2.r,
                                     right: 2.r,
                                     child: Container(
                                       padding: EdgeInsets.all(6.r),
                                       decoration: const BoxDecoration(
                                         color: Colors.white,
                                         shape: BoxShape.circle,
                                         boxShadow: [
                                           BoxShadow(
                                             color: Colors.black12,
                                             blurRadius: 4,
                                           ),
                                         ],
                                       ),
                                       child: Icon(
                                         Icons.camera_alt_rounded,
                                         color: const Color(0xFFFFC000),
                                         size: 18.sp,
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                             ),SizedBox(height: 28.h),
                            // Full Name Field (Characters only)
                            _buildField(
                              label: 'Full Name',
                              controller: _nameCtrl,
                              hintText: 'Enter your name',
                              prefixIcon: Icons.person_outline_rounded,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z\s]')),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Full Name is required';
                                }
                                if (v.trim().length < 3) {
                                  return 'Name must be at least 3 characters long';
                                }
                                return null;
                              },
                              textCapitalization: TextCapitalization.words,
                            ),
                            SizedBox(height: 20.h),

                            // Email Address Field
                            _buildField(
                              label: 'Email Address',
                              controller: _emailCtrl,
                              hintText: 'abidoya@gmail.com',
                              prefixIcon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(v.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 20.h),

                            // Phone Number Field
                            _buildField(
                              label: 'Phone Number',
                              controller: _phoneCtrl,
                              hintText: '+91 (555) 123-4567',
                              prefixIcon: Icons.smartphone_outlined,
                              keyboardType: TextInputType.phone,
                              readOnly: true,
                            ),
                            SizedBox(height: 32.h),
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: const Color(0xFFEEEEEE),
                width: 1.w,
              ),
            ),
          ),
          child: SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: SizedBox(
                width: double.infinity,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC000),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.black,
                        )
                      : Text(
                          isEditMode ? 'Save Changes' : 'Create Profile',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isEditMode) {
    final canPop = Navigator.canPop(context);
    return Container(
      color: const Color(0xFFFFF9E6),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16.h,
        bottom: 16.h,
        left: 20.w,
        right: 20.w,
      ),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22.sp,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Text(
              'My Profile',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                  fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        SizedBox(
          height: 46.h,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              color: readOnly ? const Color(0xFF64748B) : AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: AppFonts.fontFamily,
                color: const Color(0xFF94A3B8),
                fontSize: 14.sp,
              ),
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: EdgeInsets.only(left: 12.w, right: 9.w),
                      child: Icon(
                        prefixIcon,
                        size: 20.sp,
                        color: const Color(0xFF64748B),
                      ),
                    )
                  : null,
              prefixIconConstraints: BoxConstraints(
                minWidth: 41.w,
                minHeight: 20.h,
              ),
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: EdgeInsets.only(right: 18.w),
                      child: suffixIcon,
                    )
                  : null,
              suffixIconConstraints: BoxConstraints(
                minWidth: 38.w,
                minHeight: 20.h,
              ),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              filled: true,
              fillColor: readOnly ? const Color(0xFFF8F9FA) : Colors.white,
              contentPadding: EdgeInsets.only(
                top: 12.h,
                right: suffixIcon != null ? 0 : 18.w,
                bottom: 12.h,
                left: prefixIcon != null ? 0 : 12.w,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: const Color(0xFFEEEEEE),
                  width: 1.w,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: const Color(0xFFEEEEEE),
                  width: 1.w,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: readOnly
                      ? const Color(0xFFEEEEEE)
                      : const Color(0xFFFFC000),
                  width: 1.w,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

