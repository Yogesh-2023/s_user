import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../services/profile_service.dart';
import 'receiver_details_screen.dart';

class SenderDetailsScreen extends StatefulWidget {
  final String pickupAddress;

  const SenderDetailsScreen({super.key, required this.pickupAddress});

  @override
  State<SenderDetailsScreen> createState() => _SenderDetailsScreenState();
}

class _SenderDetailsScreenState extends State<SenderDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _senderNameController;
  late final TextEditingController _senderMobileController;
  String _selectedGoodsType = 'Furniture';
  bool _helperRequired = false;
  bool _useMyInfo = false;

  final List<String> _goodsTypes = [
    'Furniture',
    'Electronics',
    'Textiles / Garments',
    'FMCG / Food',
    'Industrial Machinery',
    'Construction Material',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _senderNameController = TextEditingController();
    _senderMobileController = TextEditingController();
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderMobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sender Details',
          style: AppFonts.h1.copyWith(fontSize: 18.sp, color: Colors.black),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 20.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selected Pickup Address Display
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 14.w,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textFieldBackground,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pick-up Location',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: Colors.grey.shade500,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              widget.pickupAddress,
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: Colors.black87,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),

                      Text(
                        'Sender Information',
                        style: AppFonts.h2.copyWith(
                          fontSize: 16.sp,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      Text(
                        'Sender Name',
                        style: AppFonts.captionDark.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      _buildTextField(
                        controller: _senderNameController,
                        hintText: 'Enter Sender name',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.grey.shade400,
                          size: 20.sp,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Please enter sender name';
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      Text(
                        'Mobile Number',
                        style: AppFonts.captionDark.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      _buildTextField(
                        controller: _senderMobileController,
                        hintText: 'Enter Mobile number',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: Colors.grey.shade400,
                          size: 20.sp,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Please enter mobile number';
                          if (value.trim().length < 10)
                            return 'Valid 10-digit number required';
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      // Checkbox for using own details
                      Row(
                        children: [
                          SizedBox(
                            width: 24.w,
                            height: 24.w,
                            child: Checkbox(
                              value: _useMyInfo,
                              onChanged: (val) async {
                                setState(() {
                                  _useMyInfo = val ?? false;
                                });
                                if (_useMyInfo) {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  String phone =
                                      prefs.getString('user_phone') ?? '';
                                  String name =
                                      prefs.getString('user_name') ?? '';

                                  if (name.isEmpty || phone.isEmpty) {
                                    try {
                                      final prof = await ProfileService()
                                          .getMyProfile();
                                      if (prof != null) {
                                        if (name.isEmpty &&
                                            prof.name.isNotEmpty) {
                                          name = prof.name;
                                          await prefs.setString(
                                            'user_name',
                                            name,
                                          );
                                        }
                                        if (phone.isEmpty &&
                                            prof.phone.isNotEmpty) {
                                          phone = prof.phone;
                                          await prefs.setString(
                                            'user_phone',
                                            phone,
                                          );
                                        }
                                      }
                                    } catch (_) {}
                                  }

                                  String cleanedPhone = phone.replaceAll(
                                    RegExp(r'\D'),
                                    '',
                                  );
                                  if (cleanedPhone.length == 12 &&
                                      cleanedPhone.startsWith('91')) {
                                    cleanedPhone = cleanedPhone.substring(2);
                                  } else if (cleanedPhone.length > 10) {
                                    cleanedPhone = cleanedPhone.substring(
                                      cleanedPhone.length - 10,
                                    );
                                  }

                                  _senderNameController.text = name.isNotEmpty
                                      ? name
                                      : 'Guest User';
                                  _senderMobileController.text = cleanedPhone;
                                } else {
                                  _senderNameController.clear();
                                  _senderMobileController.clear();
                                }
                              },
                              activeColor: const Color(0xFFF4B41A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'I am the sender (use my details)',
                            style: AppFonts.bodyText.copyWith(
                              color: Colors.black87,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      Text(
                        'Goods Information',
                        style: AppFonts.h2.copyWith(
                          fontSize: 16.sp,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      Text(
                        'Type of Goods',
                        style: AppFonts.captionDark.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        height: 50.h,
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        decoration: BoxDecoration(
                          color: AppColors.textFieldBackground,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.authButtonBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGoodsType,
                            isExpanded: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey.shade600,
                            ),
                            items: _goodsTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  style: AppFonts.bodyText.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedGoodsType = val);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Helper Required Checkbox
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.w,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: const Color(0xFFF4B41A).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: Checkbox(
                                value: _helperRequired,
                                onChanged: (val) {
                                  setState(() {
                                    _helperRequired = val ?? false;
                                  });
                                },
                                activeColor: const Color(0xFFF4B41A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Helper Required?',
                                    style: AppFonts.bodyText.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Need someone to help load and unload goods? Extra charges may apply.',
                                    style: AppFonts.captionDark.copyWith(
                                      color: Colors.grey.shade600,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: EdgeInsets.only(
                left: 14.w,
                right: 14.w,
                top: 16.h,
                bottom: 20.h,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                height: 46.h,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4B41A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceiverDetailsScreen(
                            pickupAddress: widget.pickupAddress,
                            pickupContactName: _senderNameController.text
                                .trim(),
                            pickupContactPhone: _senderMobileController.text
                                .trim(),
                            goodsType: _selectedGoodsType,
                            helperRequired: _helperRequired ? 'Yes' : 'No',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Proceed to Destination',
                    style: AppFonts.buttonText.copyWith(
                      color: Colors.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Widget prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
      initialValue: controller.text,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (field) {
        final hasError = field.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52.h,
              decoration: BoxDecoration(
                color: AppColors.textFieldBackground,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: hasError
                      ? Colors.redAccent
                      : AppColors.authButtonBorder,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: 12.w),
                  prefixIcon,
                  SizedBox(width: 12.w),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      textCapitalization: textCapitalization,
                      onChanged: field.didChange,
                      inputFormatters: keyboardType == TextInputType.phone
                          ? [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ]
                          : null,
                      style: AppFonts.bodyText.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: hintText,
                        hintStyle: AppFonts.bodyText.copyWith(
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasError)
              Padding(
                padding: EdgeInsets.only(top: 4.h, left: 4.w),
                child: Text(
                  field.errorText ?? '',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10.sp),
                ),
              ),
          ],
        );
      },
    );
  }
}
