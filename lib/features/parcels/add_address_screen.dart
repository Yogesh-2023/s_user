import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../core/utils.dart';
import 'receiver_details_screen.dart';

class AddAddressScreen extends StatefulWidget {
  final String? selectedAddress;
  final bool returnResult;

  const AddAddressScreen({
    super.key,
    this.selectedAddress,
    this.returnResult = false,
  });

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  static const _primaryColor = Color(0xFFF4B41A);
  static final _namePattern = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$');
  static final _indianMobilePattern = RegExp(r'^[6-9][0-9]{9}$');

  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _mobileNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _helperCountController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String _selectedAddressType = 'Other';
  String _helperRequired = 'No';
  bool _saveForFuture = true;

  @override
  void initState() {
    super.initState();
    if (widget.selectedAddress != null) {
      _addressController.text = widget.selectedAddress!;
    }
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _mobileNumberController.dispose();
    _addressController.dispose();
    _addressLine1Controller.dispose();
    _helperCountController.dispose();
    super.dispose();
  }

  static const List<_AddressTypeOption> _addressTypes = [
    _AddressTypeOption(
      'Home',
      Icons.home_outlined,
      Color(0xFF4CAF50),
      Color(0xFFE8F5E9),
    ),
    _AddressTypeOption(
      'Office',
      Icons.work_outline,
      Color(0xFF2196F3),
      Color(0xFFE3F2FD),
    ),
    _AddressTypeOption(
      'Shop',
      Icons.storefront_outlined,
      Color(0xFF9C27B0),
      Color(0xFFF3E5F5),
    ),
    _AddressTypeOption(
      'Other',
      Icons.location_on_outlined,
      Color(0xFFFFB300),
      Color(0xFFFFF8E1),
    ),
  ];

  String? _validateAddress(String? value) {
    final address = value?.trim() ?? '';
    if (address.isEmpty) return 'Pickup address is required';
    if (address.length < 5) return 'Please enter a complete pickup address';
    return null;
  }

  String? _validateContactName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Contact name is required';
    if (name.length < 2) return 'Enter at least 2 letters';
    if (!_namePattern.hasMatch(name)) {
      return 'Enter a valid name using letters only';
    }
    return null;
  }

  String? _validateMobileNumber(String? value) {
    final number = value?.trim() ?? '';
    if (number.isEmpty) return 'Mobile number is required';
    if (!_indianMobilePattern.hasMatch(number)) {
      return 'Enter a valid 10-digit Indian mobile number';
    }
    return null;
  }

  String? _validateHelperCount(String? value) {
    if (_helperRequired != 'Yes') return null;
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null) return 'Number of helpers is required';
    if (count < 1 || count > 10) return 'Enter a number between 1 and 10';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(
          0xFFEBF7FD,
        ), // Soft light blue header background
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom Header / AppBar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.w,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                          size: 20.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Address',
                          style: AppFonts.h2.copyWith(
                            fontSize: 18.sp,
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Enter the pickup location details',
                          style: AppFonts.bodyText.copyWith(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form container taking full width and bottom rounded corners
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              14.w,
                              24.h,
                              14.w,
                              20.h,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(
                                  'Pickup address',
                                  required: true,
                                ),
                                SizedBox(height: 8.h),
                                _buildAddressTextField(
                                  controller: _addressController,
                                  hintText:
                                      'Search or enter the complete address',
                                  validator: _validateAddress,
                                ),
                                SizedBox(height: 20.h),

                                _buildFieldLabel('Save address as'),
                                SizedBox(height: 12.h),

                                // Address Type Cards Row
                                Row(
                                  children: _addressTypes
                                      .map(_buildAddressTypeCard)
                                      .toList(),
                                ),
                                SizedBox(height: 20.h),

                                // Contact Person Field
                                _buildFieldLabel(
                                  'Contact person',
                                  required: true,
                                ),
                                SizedBox(height: 8.h),
                                _buildTextField(
                                  controller: _contactNameController,
                                  hintText: 'Enter name',
                                  prefixIcon: Icons.person_outline_outlined,
                                  textCapitalization: TextCapitalization.words,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r"[a-zA-Z ]"),
                                    ),
                                    _CapitalizeFirstLetterFormatter(),
                                  ],
                                  validator: _validateContactName,
                                ),
                                SizedBox(height: 16.h),

                                // Mobile Number Field
                                _buildFieldLabel(
                                  'Mobile number',
                                  required: true,
                                ),
                                SizedBox(height: 8.h),
                                _buildTextField(
                                  controller: _mobileNumberController,
                                  hintText: '10-digit mobile number',
                                  prefixIcon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  validator: _validateMobileNumber,
                                ),
                                SizedBox(height: 16.h),

                                // Address Line 1 Field
                                _buildFieldLabel(
                                  'House, flat or building',
                                  optional: true,
                                ),
                                SizedBox(height: 8.h),
                                _buildTextField(
                                  controller: _addressLine1Controller,
                                  hintText:
                                      'e.g. Flat 12, Green View Apartments',
                                  prefixIcon: Icons.map_outlined,
                                ),
                                SizedBox(height: 20.h),

                                _buildFieldLabel('Need help with loading?'),
                                SizedBox(height: 12.h),

                                // Helper Selection Row
                                Row(
                                  children: [
                                    _buildHelperCard(
                                      title: 'Yes, add helper',
                                      isSelected: _helperRequired == 'Yes',
                                      onTap: () => setState(
                                        () => _helperRequired = 'Yes',
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    _buildHelperCard(
                                      title: 'No helper needed',
                                      isSelected: _helperRequired == 'No',
                                      onTap: () => setState(
                                        () => _helperRequired = 'No',
                                      ),
                                    ),
                                  ],
                                ),
                                if (_helperRequired == 'Yes') ...[
                                  SizedBox(height: 16.h),
                                  _buildFieldLabel(
                                    'Number of helpers',
                                    required: true,
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildTextField(
                                    controller: _helperCountController,
                                    hintText: 'Enter 1 to 10',
                                    prefixIcon: Icons.group_outlined,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    validator: _validateHelperCount,
                                  ),
                                ],
                                SizedBox(height: 24.h),

                                // Save this address for future
                                Row(
                                  children: [
                                    Container(
                                      width: 36.w,
                                      height: 36.w,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEDE7F6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.bookmark_outline,
                                          color: Color(0xFF673AB7),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Save this address for future',
                                            style: AppFonts.bodyText.copyWith(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.sp,
                                              height: 1.2,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            'Easily reuse for next delivery',
                                            style: AppFonts.bodyText.copyWith(
                                              color: Colors.grey.shade500,
                                              fontSize: 11.sp,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Custom Animated Switch Toggle
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _saveForFuture = !_saveForFuture;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 44.w,
                                        height: 24.h,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2.w,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                          color: _saveForFuture
                                              ? Colors.white
                                              : Colors.white,
                                          border: Border.all(
                                            color: _saveForFuture
                                                ? const Color(0xFFF4B41A)
                                                : Colors.grey.shade300,
                                            width: 1.5.w,
                                          ),
                                        ),
                                        alignment: _saveForFuture
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          width: 16.w,
                                          height: 16.w,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _saveForFuture
                                                ? const Color(0xFFF4B41A)
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Fixed Save Address button at the bottom of the container
                        Container(
                          padding: EdgeInsets.only(
                            left: 20.w,
                            right: 20.w,
                            top: 12.h,
                            bottom: MediaQuery.of(context).padding.bottom > 0
                                ? MediaQuery.of(context).padding.bottom + 10.h
                                : 16.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey.shade100,
                                width: 1,
                              ),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 46.h,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4B41A),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                              ),
                              onPressed: _onSaveAddressPressed,
                              child: Text(
                                'Continue to drop details',
                                style: AppFonts.buttonText.copyWith(
                                  color: Colors.black,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(
    String label, {
    bool required = false,
    bool optional = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: AppFonts.bodyText.copyWith(
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w700,
            fontSize: 13.sp,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: AppFonts.bodyText.copyWith(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
            ),
          ),
        if (optional)
          Text(
            '  Optional',
            style: AppFonts.bodyText.copyWith(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
              fontSize: 11.sp,
            ),
          ),
      ],
    );
  }

  Widget _buildAddressTypeCard(_AddressTypeOption type) {
    final isSelected = _selectedAddressType == type.title;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${type.title} address',
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => setState(() => _selectedAddressType = type.title),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: EdgeInsets.symmetric(vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFFDE7) : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelected ? const Color(0xFFF4B41A) : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5.w : 1.w,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 7.w,
                  ),
                  decoration: BoxDecoration(
                    color: type.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(type.icon, color: type.color, size: 18.sp),
                ),
                SizedBox(height: 7.h),
                Text(
                  type.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodyText.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: TextInputType.streetAddress,
      minLines: 2,
      maxLines: 3,
      style: AppFonts.bodyText.copyWith(
        color: const Color(0xFF1E293B),
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        hintText: hintText,
        prefixIcon: Icons.location_on_outlined,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: AppFonts.bodyText.copyWith(
        color: const Color(0xFF1E293B),
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(hintText: hintText, prefixIcon: prefixIcon),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: AppColors.authButtonBorder, width: 1.w),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.textFieldBackground,
      hintText: hintText,
      hintStyle: AppFonts.bodyText.copyWith(
        color: const Color(0xFF94A3B8),
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 19.sp),
      prefixIconConstraints: BoxConstraints(minWidth: 44.w),
      contentPadding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 12.w),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: const Color(0xFFF4B41A), width: 1.5.w),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.redAccent, width: 1.w),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.redAccent, width: 1.5.w),
      ),
      errorMaxLines: 2,
      errorStyle: TextStyle(fontSize: 10.sp, height: 1.2),
    );
  }

  Widget _buildHelperCard({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF4B41A)
                  : Colors.grey.shade200,
              width: 1.w,
            ),
          ),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFF4B41A)
                        : Colors.grey.shade300,
                    width: 1.5.w,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF4B41A),
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodyText.copyWith(
                    color: Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 10.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSaveAddressPressed() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      String helperInfo = _helperRequired;
      if (_helperRequired == 'Yes') {
        helperInfo = 'Yes, ${_helperCountController.text.trim()} Helpers';
      }

      String fullAddress = _addressController.text.trim();
      String line1 = _addressLine1Controller.text.trim();
      if (line1.isNotEmpty && line1 != fullAddress) {
        fullAddress = '$fullAddress, $line1';
      }

      if (widget.returnResult) {
        Navigator.pop(context, {
          'address': fullAddress,
          'contactName': _contactNameController.text.trim(),
          'contactPhone': _mobileNumberController.text.trim(),
          'goodsType': 'Other',
          'helperRequired': helperInfo,
        });
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiverDetailsScreen(
            pickupAddress: fullAddress,
            pickupContactName: _contactNameController.text.trim(),
            pickupContactPhone: _mobileNumberController.text.trim(),
            goodsType: 'Other',
            helperRequired: helperInfo,
          ),
        ),
      );
    } else {
      AppUtils.showSnackBar(
        context,
        'Please fill all required fields',
        isError: true,
      );
    }
  }
}

class _AddressTypeOption {
  final String title;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _AddressTypeOption(
    this.title,
    this.icon,
    this.color,
    this.backgroundColor,
  );
}

class _CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    final words = text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();

    final capitalizedText = capitalizedWords.join(' ');

    int selectionIndex = newValue.selection.end;
    if (selectionIndex < 0) {
      selectionIndex = 0;
    }
    if (selectionIndex > capitalizedText.length) {
      selectionIndex = capitalizedText.length;
    }

    return TextEditingValue(
      text: capitalizedText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
