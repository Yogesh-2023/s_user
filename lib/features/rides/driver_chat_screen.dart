import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../constants/app_assets.dart';
import '../../core/socket/socket_service.dart';
import '../../core/socket/socket_events.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_constants.dart';

class DriverChatScreen extends StatefulWidget {
  final Map<String, dynamic>? driverData;

  const DriverChatScreen({super.key, this.driverData});

  @override
  State<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<DriverChatScreen> {
  final Color themeColor = const Color(0xFF00ABE4);
  final Color lightThemeColor = const Color(0xFFE6F7FD);
  final Color chatBgColor = const Color(0xFFE4ECEF);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];

  String? get tripId => widget.driverData?['tripId']?.toString();

  dynamic _readValue(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  Map<String, dynamic> get _driver {
    final data = widget.driverData;
    final value =
        data?['driver'] ??
        data?['assignedDriver'] ??
        data?['driverDetails'] ??
        data?['booking']?['driver'] ??
        data?['booking']?['assignedDriver'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> get _vehicle {
    final data = widget.driverData;
    final driver = _driver;
    final value =
        driver['assignedVehicle'] ??
        driver['vehicle'] ??
        data?['vehicle'] ??
        data?['assignedVehicle'] ??
        data?['booking']?['vehicle'] ??
        data?['booking']?['assignedVehicle'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String? get _driverImageUrl {
    final driver = _driver;
    String? image = _readValue([
      driver['profileImage'],
      driver['profilePicture'],
      driver['image'],
      driver['avatar'],
      driver['driverProfile']?['profileImage'],
      driver['driverProfile']?['profilePicture'],
      driver['driverProfile']?['image'],
      driver['driverProfile']?['avatar'],
      driver['user']?['profileImage'],
      driver['user']?['profilePicture'],
      driver['user']?['image'],
      driver['user']?['avatar'],
      widget.driverData?['driverImage'],
      widget.driverData?['booking']?['driverImage'],
    ])?.toString().trim();

    if (image == null || image.isEmpty) return null;
    final uri = Uri.tryParse(image);
    final isOldOrLocalHost =
        uri != null &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == 'cars.carosa.in');
    if (isOldOrLocalHost && uri.path.isNotEmpty) {
      return '${ApiConstants.baseUrl}${uri.path}';
    }
    if (!image.startsWith('http')) {
      return '${ApiConstants.baseUrl}${image.startsWith('/') ? image : '/$image'}';
    }
    return image;
  }

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
  }

  DateTime _localMessageTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toLocal() ?? DateTime.now();
  }

  void _handleChatHistory(dynamic data) {
    if (!mounted) return;
    final payload = (data is List && data.isNotEmpty) ? data.first : data;
    if (payload is Map && payload['messages'] is List) {
      setState(() {
        _messages.clear();
        for (var msg in payload['messages']) {
          final role = msg['senderRole']?.toString().toLowerCase();
          _messages.add({
            'sender': (role == 'customer' || role == 'user')
                ? 'user'
                : 'driver',
            'text': msg['message'] ?? '',
            'time': _localMessageTime(msg['createdAt']),
          });
        }
      });
      _scrollToBottom();
    }
  }

  void _handleReceiveMessage(dynamic data) {
    if (!mounted) return;
    final payload = (data is List && data.isNotEmpty) ? data.first : data;
    if (payload is Map && payload['message'] != null) {
      setState(() {
        final role = payload['senderRole']?.toString().toLowerCase();
        _messages.add({
          'sender': (role == 'customer' || role == 'user') ? 'user' : 'driver',
          'text': payload['message'],
          'time': _localMessageTime(payload['createdAt']),
        });
      });
      _scrollToBottom();
    }
  }

  void _setupSocketListeners() {
    if (tripId == null) return;

    // Join chat room and request chat history
    SocketService.to.joinChat(bookingId: tripId!);
    SocketService.to.emitEvent('TRIP_CHAT', {'tripId': tripId});

    SocketService.to.listenTo('CHAT_HISTORY', _handleChatHistory);
    SocketService.to.listenTo('RECEIVE_MESSAGE', _handleReceiveMessage);
  }

  @override
  void dispose() {
    SocketService.to.stopListening('CHAT_HISTORY', _handleChatHistory);
    SocketService.to.stopListening('RECEIVE_MESSAGE', _handleReceiveMessage);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || tripId == null) return;

    final clientMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    SocketService.to.sendChat(
      bookingId: tripId!,
      message: text,
      clientMessageId: clientMsgId,
    );
    SocketService.to.emitEvent('TRIP_CHAT', {
      'tripId': tripId,
      'message': text,
    });

    _messageController.clear();
  }


  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _messages.add({
            'sender': 'user',
            'text': '',
            'time': DateTime.now(),
            'attachment': image.path,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _launchDialer(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not launch dialer for $phoneNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildChatBody()),
          _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final driver = _driver;
    final vehicle = _vehicle;

    final driverName = driver['name'] ?? 'Driver';
    final vehicleName =
        _readValue([
          vehicle['vehicleName'],
          vehicle['name'],
          vehicle['type'],
          vehicle['vehicleType'],
          widget.driverData?['vehicleName'],
          widget.driverData?['vehicleType'],
          widget.driverData?['carName'],
        ]) ??
        'Vehicle';
    final vehicleNo =
        _readValue([
          vehicle['plateNumber'],
          vehicle['vehicleNumber'],
          vehicle['registrationNumber'],
          vehicle['registrationNo'],
          widget.driverData?['vehicleNumber'],
          widget.driverData?['registrationNumber'],
          widget.driverData?['booking']?['vehicleNumber'],
          widget.driverData?['booking']?['registrationNumber'],
        ])?.toString() ??
        '';
    final phone = driver['phone']?.toString();

    final driverImage = _driverImageUrl;

    return Container(
      color: const Color(0xFFE6F7FD),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(Icons.arrow_back, size: 20, color: Colors.black),
            ),
          ),
          SizedBox(width: 16.w),
          ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: driverImage != null && driverImage.startsWith('http')
                ? Image.network(
                    driverImage,
                    width: 40.r,
                    height: 40.r,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      AppAssets.profileImage,
                      width: 40.r,
                      height: 40.r,
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    AppAssets.profileImage,
                    width: 40.r,
                    height: 40.r,
                    fit: BoxFit.cover,
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  vehicleNo.isEmpty
                      ? '$vehicleName'
                      : '$vehicleName • $vehicleNo',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 11.sp,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _launchDialer(phone),
            icon: Icon(Icons.phone_outlined, color: Colors.black, size: 24.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody() {
    if (_messages.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 36.w),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 32.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: lightThemeColor,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: themeColor,
                  size: 28.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Start a conversation',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Send a message to your driver.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildDateDivider('TODAY');
        }

        final msgIndex = _messages.length - 1 - index;
        final msg = _messages[msgIndex];
        final bool isUser = msg['sender'] == 'user';
        final String timeString = DateFormat(
          'hh:mm a',
        ).format(_localMessageTime(msg['time']));

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 4.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? themeColor : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isUser ? 20.r : 0),
                topRight: Radius.circular(isUser ? 0 : 20.r),
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              ),
              border: isUser ? null : Border.all(color: Colors.grey.shade200),
              boxShadow: [
                if (!isUser)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg['attachment'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.file(
                      File(msg['attachment']),
                      width: 200.w,
                      height: 150.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],
                if (msg['text'] != null && msg['text'].isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      msg['text'],
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        color: isUser ? Colors.white : const Color(0xFF212529),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 9.sp,
                        color: isUser ? Colors.white70 : Colors.grey.shade600,
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

  Widget _buildDateDivider(String label) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: const Color(0xFFD6E2E6),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReplies() {
    final List<String> quickReplies = [
      "I am here",
      "On my way",
      "Where are you?",
      "Ok",
    ];

    return Container(
      height: 40.h,
      margin: EdgeInsets.only(top: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: quickReplies.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _messageController.text = quickReplies[index];
              _sendMessage();
            },
            child: Container(
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: themeColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  quickReplies[index],
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    color: themeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 8.w,
        right: 8.w,
        top: 8.h,
        bottom: MediaQuery.of(context).padding.bottom + 8.h,
      ),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.insert_emoticon_outlined,
                      color: Colors.grey.shade500,
                      size: 22.sp,
                    ),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: Colors.grey.shade500,
                      size: 20.sp,
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.grey.shade500,
                      size: 20.sp,
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                  SizedBox(width: 4.w),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.25),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
