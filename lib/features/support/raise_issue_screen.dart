import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../services/ticket_service.dart';

class RaiseIssueScreen extends StatefulWidget {
  final String? preselectedBookingId;

  const RaiseIssueScreen({super.key, this.preselectedBookingId});

  @override
  State<RaiseIssueScreen> createState() => _RaiseIssueScreenState();
}

class _RaiseIssueScreenState extends State<RaiseIssueScreen> {
  final TicketService _ticketService = TicketService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _bookingIdController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _loadingCategories = true;

  final List<File> _attachmentFiles = [];
  final List<Map<String, dynamic>> _uploadedAttachments = [];
  bool _isUploadingAttachment = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedBookingId != null) {
      _bookingIdController.text = widget.preselectedBookingId!;
    }
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final cats = await _ticketService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loadingCategories = false;
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first['id']?.toString();
      }
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descController.dispose();
    _bookingIdController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(ImageSource source) async {
    if (_attachmentFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 attachments allowed.'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;

      final ioFile = File(file.path);
      final size = await ioFile.length();
      if (size > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File size exceeds max 5 MB limit.'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      setState(() {
        _isUploadingAttachment = true;
      });

      final uploaded = await _ticketService.uploadAttachment(file.path);
      if (!mounted) return;

      setState(() {
        _isUploadingAttachment = false;
      });

      if (uploaded != null && uploaded['url'] != null) {
        setState(() {
          _attachmentFiles.add(ioFile);
          _uploadedAttachments.add({
            'url': uploaded['url'],
            'name': uploaded['name'] ?? file.name,
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploaded?['error'] ?? 'Attachment upload failed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentFiles.removeAt(index);
      _uploadedAttachments.removeAt(index);
    });
  }

  Future<void> _submitTicket() async {
    final subject = _subjectController.text.trim();
    final description = _descController.text.trim();
    final bookingId = _bookingIdController.text.trim();

    if (subject.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket subject must be at least 3 characters.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (description.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your issue in more detail (at least 5 characters).'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final created = await _ticketService.raiseTicket(
      subject: subject,
      description: description,
      categoryId: _selectedCategoryId,
      bookingId: bookingId.isNotEmpty ? bookingId : null,
      attachments: _uploadedAttachments.isNotEmpty ? _uploadedAttachments : null,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket raised successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_ticketService.lastErrorMessage ?? 'Failed to submit ticket. Please check fields and try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select Category Chips
                      Text(
                        'Select Category',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (_loadingCategories)
                        const LinearProgressIndicator(color: AppColors.fleetgoYellow)
                      else if (_categories.isEmpty)
                        Text('General Support', style: TextStyle(fontSize: 12.sp, color: Colors.grey))
                      else
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: _categories.map((cat) {
                            final id = cat['id']?.toString() ?? '';
                            final name = (cat['name'] ?? cat['code'] ?? 'Category').toString();
                            final isSelected = _selectedCategoryId == id;
                            return ChoiceChip(
                              label: Text(name),
                              selected: isSelected,
                              selectedColor: AppColors.fleetgoYellow,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 12.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.black : const Color(0xFF475569),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedCategoryId = id);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      SizedBox(height: 20.h),

                      // Subject Field
                      Text(
                        'Subject',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _subjectController,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Refund request for booking',
                          hintStyle: TextStyle(fontFamily: 'Gilroy', fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.fleetgoYellow, width: 1.5)),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Description Field
                      Text(
                        'Description',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _descController,
                        maxLines: 4,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Provide details about your issue...',
                          hintStyle: TextStyle(fontFamily: 'Gilroy', fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.fleetgoYellow, width: 1.5)),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Booking ID Optional Field
                      Text(
                        'Booking / Ride ID (Optional)',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _bookingIdController,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
                          hintStyle: TextStyle(fontFamily: 'Gilroy', fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.fleetgoYellow, width: 1.5)),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Attachments Section
                      Text(
                        'Attachments (${_attachmentFiles.length}/5, max 5MB each)',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 8.h),

                      if (_attachmentFiles.isNotEmpty) ...[
                        Wrap(
                          spacing: 10.w,
                          runSpacing: 10.h,
                          children: List.generate(_attachmentFiles.length, (index) {
                            final file = _attachmentFiles[index];
                            return Stack(
                              children: [
                                Container(
                                  width: 70.w,
                                  height: 70.w,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.r),
                                    image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => _removeAttachment(index),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        SizedBox(height: 10.h),
                      ],

                      if (_isUploadingAttachment)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Row(
                            children: [
                              SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.fleetgoYellow)),
                              SizedBox(width: 8.w),
                              Text('Uploading attachment...', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),

                      if (_attachmentFiles.length < 5)
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickAttachment(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, color: Colors.black),
                              label: const Text('Add Photo', style: TextStyle(color: Colors.black)),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            OutlinedButton.icon(
                              onPressed: () => _pickAttachment(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined, color: Colors.black),
                              label: const Text('Camera', style: TextStyle(color: Colors.black)),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ],
                        ),

                      SizedBox(height: 30.h),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.fleetgoYellow,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.black)
                              : Text(
                                  'Submit Ticket',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(Icons.arrow_back_rounded, size: 22.sp, color: const Color(0xFF1E293B)),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Raise Support Ticket',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
