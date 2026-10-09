import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../core/socket/socket_service.dart';
import '../../services/ticket_service.dart';

class TicketChatScreen extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic>? ticketData;

  const TicketChatScreen({
    super.key,
    required this.ticketId,
    this.ticketData,
  });

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final TicketService _ticketService = TicketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  bool _isResolvedOrClosed = false;

  final List<Map<String, dynamic>> _pendingAttachments = [];
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    try {
      if (SocketService.to.isConnected) {
        SocketService.to.emitEvent('support:join', {'ticketId': widget.ticketId});
      }
      SocketService.to.listenTo('support:message', _onSocketMessage);
      SocketService.to.listenTo('support:ticket-updated', _onSocketTicketUpdated);
    } catch (e) {
      debugPrint('Socket support listener error: $e');
    }
  }

  void _onSocketMessage(dynamic data) {
    if (!mounted || data == null) return;
    debugPrint('Socket support:message received: $data');
    _loadTicketDetails(silent: true);
  }

  void _onSocketTicketUpdated(dynamic data) {
    if (!mounted || data == null) return;
    debugPrint('Socket support:ticket-updated received: $data');
    _loadTicketDetails(silent: true);
  }

  @override
  void dispose() {
    try {
      SocketService.to.stopListening('support:message', _onSocketMessage);
      SocketService.to.stopListening('support:ticket-updated', _onSocketTicketUpdated);
    } catch (_) {}
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTicketDetails({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    final ticket = await _ticketService.getTicket(widget.ticketId);
    await _ticketService.markRead(widget.ticketId);

    if (!mounted) return;

    if (ticket != null) {
      final rawMsgs = (ticket['messages'] as List?) ?? [];
      final status = (ticket['status'] ?? widget.ticketData?['status'] ?? 'OPEN').toString().toUpperCase();

      setState(() {
        _ticket = ticket;
        _messages = rawMsgs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isResolvedOrClosed = (status == 'RESOLVED' || status == 'CLOSED');
        _isLoading = false;
      });
      _scrollToBottom();
    } else {
      if (!silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAttachment(ImageSource source) async {
    if (_isResolvedOrClosed) return;
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;

      setState(() => _isUploadingAttachment = true);
      final uploaded = await _ticketService.uploadAttachment(file.path);
      if (!mounted) return;
      setState(() => _isUploadingAttachment = false);

      if (uploaded != null && uploaded['url'] != null) {
        setState(() {
          _pendingAttachments.add({
            'url': uploaded['url'],
            'name': uploaded['name'] ?? file.name,
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(uploaded?['error'] ?? 'Failed to upload attachment'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingAttachment = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_isResolvedOrClosed || _isSending) return;
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    setState(() => _isSending = true);

    final res = await _ticketService.sendMessage(
      ticketId: widget.ticketId,
      message: text.isNotEmpty ? text : 'Attachment',
      attachments: _pendingAttachments.isNotEmpty ? List.from(_pendingAttachments) : null,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (res != null && res['error'] == 'CONFLICT') {
      setState(() => _isResolvedOrClosed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket is resolved or closed. Cannot send message.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (res != null) {
      _messageController.clear();
      setState(() {
        _pendingAttachments.clear();
      });
      _loadTicketDetails(silent: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Retry.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _closeTicket() async {
    final success = await _ticketService.closeTicket(widget.ticketId);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket closed successfully.'), backgroundColor: Colors.green),
      );
      _loadTicketDetails(silent: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to close ticket.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  (String, Color, Color) _getStatusChipStyle(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'OPEN':
        return ('Open', const Color(0xFF2563EB), const Color(0xFFEFF6FF));
      case 'IN_PROGRESS':
        return ('In Progress', const Color(0xFFD97706), const Color(0xFFFFFBEB));
      case 'WAITING_FOR_CUSTOMER':
        return ('Waiting for You', const Color(0xFF7C3AED), const Color(0xFFF5F3FF));
      case 'RESOLVED':
        return ('Resolved', const Color(0xFF16A34A), const Color(0xFFF0FDF4));
      case 'CLOSED':
        return ('Closed', const Color(0xFF64748B), const Color(0xFFF8FAFC));
      case 'ESCALATED':
        return ('Escalated', const Color(0xFFDC2626), const Color(0xFFFEF2F2));
      default:
        return (rawStatus, const Color(0xFF64748B), const Color(0xFFF8FAFC));
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = (_ticket?['subject'] ?? widget.ticketData?['subject'] ?? 'Ticket Detail').toString();
    final ticketNumber = (_ticket?['ticketNumber'] ?? widget.ticketData?['ticketNumber'] ?? widget.ticketId).toString();
    final rawStatus = (_ticket?['status'] ?? widget.ticketData?['status'] ?? 'OPEN').toString();
    final (statusLabel, statusTextColor, statusBgColor) = _getStatusChipStyle(rawStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context, subject, ticketNumber, statusLabel, statusTextColor, statusBgColor),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.fleetgoYellow))
                  : _buildMessageList(),
            ),
            if (_pendingAttachments.isNotEmpty) _buildPendingAttachmentsBar(),
            _isResolvedOrClosed ? _buildResolvedBanner() : _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String subject,
    String ticketNumber,
    String statusLabel,
    Color statusTextColor,
    Color statusBgColor,
  ) {
    return Container(
      color: const Color(0xFFFFF9E6),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14.h,
        bottom: 12.h,
        left: 16.w,
        right: 16.w,
      ),
      child: Column(
        children: [
          Row(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          ticketNumber,
                          style: TextStyle(fontFamily: 'Gilroy', fontSize: 11.sp, color: const Color(0xFF64748B)),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(4.r)),
                          child: Text(
                            statusLabel,
                            style: TextStyle(fontFamily: 'Gilroy', fontSize: 9.sp, fontWeight: FontWeight.bold, color: statusTextColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isResolvedOrClosed)
                TextButton.icon(
                  onPressed: _closeTicket,
                  icon: Icon(Icons.check_circle_outline_rounded, size: 16.sp, color: const Color(0xFFDC2626)),
                  label: Text('Close', style: TextStyle(fontFamily: 'Gilroy', fontSize: 11.sp, color: const Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Send a message to support.',
          style: TextStyle(fontFamily: 'Gilroy', fontSize: 13.sp, color: const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final senderType = (msg['senderType'] ?? mapSenderType(msg)).toString().toUpperCase();
        final isUser = (senderType == 'USER' || senderType == 'CUSTOMER');
        final text = (msg['message'] ?? msg['text'] ?? '').toString();
        final createdAt = msg['createdAt']?.toString();
        final timeStr = _formatMessageTime(createdAt);
        final attachments = (msg['attachments'] as List?) ?? [];
        final attachmentUrl = (msg['attachmentUrl'] ?? msg['url'])?.toString();

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFFFFF9E6) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.r),
                topRight: Radius.circular(14.r),
                bottomLeft: Radius.circular(isUser ? 14.r : 0),
                bottomRight: Radius.circular(isUser ? 0 : 14.r),
              ),
              border: Border.all(color: isUser ? AppColors.fleetgoYellow.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      'Support Agent',
                      style: TextStyle(fontFamily: 'Gilroy', fontSize: 10.sp, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                    ),
                  ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: TextStyle(fontFamily: 'Gilroy', fontSize: 13.sp, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                  ),
                if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  _buildImagePreview(attachmentUrl),
                ],
                if (attachments.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  ...attachments.map((att) {
                    final url = (att is Map ? att['url'] : att).toString();
                    return _buildImagePreview(url);
                  }),
                ],
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timeStr,
                    style: TextStyle(fontFamily: 'Gilroy', fontSize: 9.sp, color: const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String mapSenderType(Map msg) {
    final role = (msg['senderRole'] ?? msg['role'] ?? '').toString().toLowerCase();
    if (role == 'admin' || role == 'support') return 'SUPPORT';
    return 'USER';
  }

  Widget _buildImagePreview(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Image.network(
        url,
        width: 180.w,
        height: 120.h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 180.w,
          height: 60.h,
          color: const Color(0xFFF1F5F9),
          child: const Center(child: Icon(Icons.insert_drive_file_outlined, color: Colors.grey)),
        ),
      ),
    );
  }

  String _formatMessageTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return DateFormat('hh:mm a').format(dt);
  }

  Widget _buildPendingAttachmentsBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      color: Colors.white,
      child: Row(
        children: [
          Text('Attachment added', style: TextStyle(fontSize: 11.sp, color: Colors.green, fontWeight: FontWeight.bold)),
          SizedBox(width: 8.w),
          Text('${_pendingAttachments.length} file', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _pendingAttachments.clear()),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      color: const Color(0xFFE2E8F0),
      child: Text(
        'This ticket is resolved/closed. Message composer is disabled.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Gilroy', fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12.w,
        right: 12.w,
        top: 8.h,
        bottom: MediaQuery.of(context).padding.bottom + 8.h,
      ),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, color: Color(0xFF64748B)),
            onPressed: _isUploadingAttachment ? null : () => _pickAttachment(ImageSource.gallery),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B)),
            onPressed: _isUploadingAttachment ? null : () => _pickAttachment(ImageSource.camera),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontFamily: 'Gilroy', fontSize: 13.sp, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: TextStyle(fontFamily: 'Gilroy', fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(color: AppColors.fleetgoYellow, shape: BoxShape.circle),
              child: _isSending
                  ? Padding(
                      padding: EdgeInsets.all(12.w),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
