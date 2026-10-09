import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_fonts.dart';
import '../../core/utils.dart';
import '../../core/api/api_exception.dart';
import '../../models/saved_address_model.dart';
import '../../models/recent_location_model.dart';
import '../../services/customer_address_service.dart';
import '../../services/recent_location_service.dart';

class SavedAddressScreen extends StatefulWidget {
  const SavedAddressScreen({Key? key}) : super(key: key);

  @override
  State<SavedAddressScreen> createState() => _SavedAddressScreenState();
}

class _SavedAddressScreenState extends State<SavedAddressScreen> {
  final CustomerAddressService _addressService = CustomerAddressService();
  final RecentLocationService _recentLocationService = RecentLocationService();
  final List<SavedAddressModel> _addresses = [];
  final List<RecentLocationModel> _recentAddresses = [];
  bool _isLoading = true;
  bool _isLoadingRecent = true;
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadAddresses(),
      _loadRecentAddresses(),
    ]);
  }

  Future<void> _loadRecentAddresses() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecent = true;
    });

    try {
      final localList = await _recentLocationService.getRecentLocations();
      List<Map<String, dynamic>> apiMaps = [];
      try {
        apiMaps = await _addressService.fetchRecentAddresses();
      } catch (e) {
        debugPrint('[SAVED_ADDRESS] fetchRecentAddresses API error: $e');
      }

      final List<RecentLocationModel> apiList = apiMaps
          .map((m) => RecentLocationModel.fromJson(m))
          .toList();

      final List<RecentLocationModel> merged = [...apiList];
      for (final loc in localList) {
        if (!merged.any((existing) => existing.isSameLocation(loc))) {
          merged.add(loc);
        }
      }
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _recentAddresses
            ..clear()
            ..addAll(merged.take(10));
        });
      }
    } catch (e) {
      debugPrint('Error loading recent addresses: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecent = false;
        });
      }
    }
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await _addressService.fetchSavedAddresses();
      if (mounted) {
        setState(() {
          _addresses
            ..clear()
            ..addAll(list);
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Failed to load saved addresses');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeAddress(SavedAddressModel item, int index) async {
    if (_deletingIds.contains(item.id)) return;

    setState(() {
      _deletingIds.add(item.id);
    });

    try {
      final success = await _addressService.deleteAddress(item.id);
      if (success) {
        if (mounted) {
          setState(() {
            _addresses.removeWhere((element) => element.id == item.id);
          });
          AppUtils.showSnackBar(context, '${item.label} address removed.');
        }
      } else {
        if (mounted) {
          AppUtils.showSnackBar(context, 'Failed to remove address.');
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'An error occurred while deleting address');
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingIds.remove(item.id);
        });
      }
    }
  }

  void _showAddAddressDialog() {
    final labelController = TextEditingController(text: 'HOME');
    final addressLineController = TextEditingController();
    final landmarkController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final postalCodeController = TextEditingController();
    final latController = TextEditingController(text: '28.6251');
    final lngController = TextEditingController(text: '77.3732');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add New Address',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Label Selector
                    Text(
                      'Address Label',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: ['HOME', 'WORK', 'OTHER'].map((tag) {
                        final isSelected = labelController.text == tag;
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: ChoiceChip(
                            label: Text(tag),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFFC000),
                            onSelected: (selected) {
                              if (selected) {
                                setBottomSheetState(() {
                                  labelController.text = tag;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12.h),

                    // Address Line Field
                    TextField(
                      controller: addressLineController,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Address Line *',
                        labelStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade700,
                          fontSize: 13.sp,
                        ),
                        hintText: 'e.g. 123 Main Street, Sector 62',
                        hintStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade400,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Landmark Field
                    TextField(
                      controller: landmarkController,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Landmark (Optional)',
                        labelStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade700,
                          fontSize: 13.sp,
                        ),
                        hintText: 'e.g. Near Metro Station',
                        hintStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade400,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityController,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'City',
                              labelStyle: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: Colors.grey.shade700,
                                fontSize: 13.sp,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            controller: stateController,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'State',
                              labelStyle: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: Colors.grey.shade700,
                                fontSize: 13.sp,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    TextField(
                      controller: postalCodeController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Postal Code (Optional)',
                        labelStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade700,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 46.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4B41A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final addressText = addressLineController.text.trim();
                                if (addressText.isEmpty) {
                                  AppUtils.showSnackBar(
                                    ctx,
                                    'Please enter address line',
                                  );
                                  return;
                                }

                                setBottomSheetState(() {
                                  isSaving = true;
                                });

                                final lat = double.tryParse(latController.text) ?? 28.6251;
                                final lng = double.tryParse(lngController.text) ?? 77.3732;

                                try {
                                  final newAddress = await _addressService.saveAddress(
                                    label: labelController.text,
                                    addressLine: addressText,
                                    latitude: lat,
                                    longitude: lng,
                                    landmark: landmarkController.text.trim(),
                                    city: cityController.text.trim(),
                                    state: stateController.text.trim(),
                                    postalCode: postalCodeController.text.trim(),
                                  );

                                  if (newAddress != null) {
                                    if (mounted) {
                                      setState(() {
                                        _addresses.insert(0, newAddress);
                                      });
                                      Navigator.pop(ctx);
                                      AppUtils.showSnackBar(
                                        context,
                                        'Address saved successfully',
                                      );
                                    }
                                  } else {
                                    AppUtils.showSnackBar(
                                      ctx,
                                      'Failed to save address',
                                    );
                                  }
                                } on ApiException catch (e) {
                                  AppUtils.showSnackBar(ctx, e.message);
                                } catch (e) {
                                  AppUtils.showSnackBar(
                                    ctx,
                                    'Error saving address',
                                  );
                                } finally {
                                  setBottomSheetState(() {
                                    isSaving = false;
                                  });
                                }
                              },
                        child: isSaving
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Address',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: (_isLoading && _isLoadingRecent)
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF4B41A),
                      ),
                    )
                  : (_addresses.isEmpty && _recentAddresses.isEmpty && !_isLoading && !_isLoadingRecent)
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          color: const Color(0xFFF4B41A),
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 20.h,
                            ),
                            children: [
                              // Saved Addresses Section
                              if (_addresses.isNotEmpty) ...[
                                Text(
                                  'Saved Addresses',
                                  style: TextStyle(
                                    fontFamily: AppFonts.fontFamily,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _addresses.length,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(height: 16.h),
                                  itemBuilder: (context, index) {
                                    final item = _addresses[index];
                                    return _buildAddressCard(item, index);
                                  },
                                ),
                                SizedBox(height: 24.h),
                              ],

                              // Recent Addresses Section
                              _buildRecentAddressesSection(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              'Saved Address',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          IconButton(
            onPressed: _showAddAddressDialog,
            icon: Icon(
              Icons.add_location_alt_rounded,
              color: const Color(0xFFD97706),
              size: 24.sp,
            ),
            tooltip: 'Add Saved Address',
          ),
        ],
      ),
    );
  }

  Future<void> _setDefault(SavedAddressModel item) async {
    try {
      final updated = await _addressService.setDefaultAddress(item.id);
      if (updated != null && mounted) {
        AppUtils.showSnackBar(context, '${item.label} set as default.');
        _loadAddresses();
      }
    } on ApiException catch (e) {
      if (mounted) AppUtils.showSnackBar(context, e.message);
    } catch (e) {
      if (mounted) AppUtils.showSnackBar(context, 'Failed to set default address.');
    }
  }

  void _showEditAddressDialog(SavedAddressModel item) {
    final labelController = TextEditingController(text: item.label);
    final addressLineController = TextEditingController(text: item.addressLine);
    final landmarkController = TextEditingController(text: item.landmark ?? '');
    final cityController = TextEditingController(text: item.city ?? '');
    final stateController = TextEditingController(text: item.state ?? '');
    final postalCodeController = TextEditingController(text: item.postalCode ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Address',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Label Selector
                    Text(
                      'Address Label',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: ['HOME', 'WORK', 'OTHER'].map((tag) {
                        final isSelected = labelController.text.toUpperCase() == tag;
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: ChoiceChip(
                            label: Text(tag),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFFC000),
                            onSelected: (selected) {
                              if (selected) {
                                setBottomSheetState(() {
                                  labelController.text = tag;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12.h),

                    TextField(
                      controller: addressLineController,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Address Line *',
                        labelStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade700,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    TextField(
                      controller: landmarkController,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Landmark (Optional)',
                        labelStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade700,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityController,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'City',
                              labelStyle: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: Colors.grey.shade700,
                                fontSize: 13.sp,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            controller: stateController,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: 'State',
                              labelStyle: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                color: Colors.grey.shade700,
                                fontSize: 13.sp,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.r),
                                borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    TextField(
                      controller: postalCodeController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Postal Code (Optional)',
                        labelStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          color: Colors.grey.shade700,
                          fontSize: 13.sp,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(color: Color(0xFFF4B41A), width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    SizedBox(
                      width: double.infinity,
                      height: 46.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4B41A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final addressText = addressLineController.text.trim();
                                if (addressText.isEmpty) {
                                  AppUtils.showSnackBar(ctx, 'Please enter address line');
                                  return;
                                }

                                setBottomSheetState(() => isSaving = true);

                                try {
                                  final updated = await _addressService.updateAddress(
                                    addressId: item.id,
                                    label: labelController.text.trim(),
                                    addressLine: addressText,
                                    landmark: landmarkController.text.trim(),
                                    city: cityController.text.trim(),
                                    state: stateController.text.trim(),
                                    postalCode: postalCodeController.text.trim(),
                                  );

                                  if (updated != null && mounted) {
                                    Navigator.pop(ctx);
                                    AppUtils.showSnackBar(context, 'Address updated successfully.');
                                    _loadAddresses();
                                  }
                                } on ApiException catch (e) {
                                  AppUtils.showSnackBar(ctx, e.message);
                                } catch (e) {
                                  AppUtils.showSnackBar(ctx, 'Error updating address');
                                } finally {
                                  setBottomSheetState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Update Address',
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getLabelIcon(String label) {
    final upper = label.toUpperCase();
    if (upper == 'HOME') return Icons.home_rounded;
    if (upper == 'WORK') return Icons.work_rounded;
    return Icons.favorite_rounded;
  }

  Widget _buildAddressCard(SavedAddressModel item, int index) {
    final bool isDeleting = _deletingIds.contains(item.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFEEEEEE),
          width: 1.w,
        ),
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Label + Default Badge
          Row(
            children: [
              Icon(
                _getLabelIcon(item.label),
                color: const Color(0xFFFFC000),
                size: 22.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (item.isDefault) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFFFC000)),
                  ),
                  child: Text(
                    'Default',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),

          // Address Box
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.addressLine,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.35,
                  ),
                ),
                if (item.landmark != null && item.landmark!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Landmark: ${item.landmark}',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 11.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Action Buttons: Set Default, Edit, Remove
          Row(
            children: [
              if (!item.isDefault) ...[
                GestureDetector(
                  onTap: () => _setDefault(item),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFFFC000)),
                    ),
                    child: Text(
                      'Set Default',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              GestureDetector(
                onTap: () => _showEditAddressDialog(item),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: isDeleting ? null : () => _removeAddress(item, index),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: isDeleting
                      ? SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Remove',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAddressesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Addresses',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            if (_isLoadingRecent)
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFF4B41A),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.h),
        if (_recentAddresses.isEmpty && !_isLoadingRecent)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: Colors.grey.shade400, size: 22.sp),
                SizedBox(width: 10.w),
                Text(
                  'No Recent Addresses',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentAddresses.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final recent = _recentAddresses[index];
              return _buildRecentAddressCard(recent);
            },
          ),
      ],
    );
  }

  Widget _buildRecentAddressCard(RecentLocationModel recent) {
    final displayAddress = recent.address.isNotEmpty ? recent.address : recent.title;
    final subtitleInfo = [
      if (recent.landmark != null && recent.landmark!.isNotEmpty) recent.landmark,
      if (recent.city != null && recent.city!.isNotEmpty) recent.city,
    ].join(', ');

    return GestureDetector(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, {
            'address': displayAddress,
            'latitude': recent.latitude,
            'longitude': recent.longitude,
            'recent': recent,
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: const Color(0xFFEEEEEE),
            width: 1.w,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(14.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFC000).withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: const Color(0xFFD97706),
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayAddress,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                      height: 1.3,
                    ),
                  ),
                  if (subtitleInfo.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Text(
                      subtitleInfo,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.5.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: const Color(0xFFFFC000).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Recent',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 64.sp,
            color: const Color(0xFFCBD5E1),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Saved Addresses',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Your saved addresses will appear here',
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 13.sp,
              color: const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4B41A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: _showAddAddressDialog,
            icon: const Icon(Icons.add, color: Colors.black),
            label: Text(
              'Add Saved Address',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
