import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/ticket_service.dart';
import 'raise_issue_screen.dart';
import 'ticket_chat_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TicketService _ticketService = TicketService();
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final res = await _ticketService.getTickets(page: 1, limit: 30);
    if (!mounted) return;

    if (res != null) {
      final items = (res['items'] as List?) ?? [];
      setState(() {
        _tickets = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUri(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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

  String _formatRelativeDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchTickets,
                color: AppColors.fleetgoYellow,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact Channels Grid
                      _buildContactChannels(),
                      SizedBox(height: 24.h),

                      // Section Title & Raise Ticket Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Support Tickets',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final created = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => const RaiseIssueScreen()),
                              );
                              if (created == true) _fetchTickets();
                            },
                            icon: Icon(Icons.add_rounded, size: 18.sp, color: Colors.black),
                            label: Text(
                              'Raise Ticket',
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.fleetgoYellow,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Ticket List / Skeleton / Empty State
                      if (_isLoading)
                        _buildSkeletonList()
                      else if (_hasError)
                        _buildErrorState()
                      else if (_tickets.isEmpty)
                        _buildEmptyState()
                      else
                        _buildTicketList(),
                    ],
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
              onTap: () => Navigator.maybePop(context),
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22.sp,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            SizedBox(width: 8.w),
          ],
          Expanded(
            child: Text(
              'Help & Support',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactChannels() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildContactCard(
                icon: Icons.mail_rounded,
                iconColor: AppColors.fleetgoYellow,
                title: 'Email Support',
                subtitle: 'Get help via email',
                value: 'support@Sawariyaa',
                onTap: () => _launchUri('mailto:support@Sawariyaa'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildContactCard(
                icon: Icons.phone_rounded,
                iconColor: AppColors.fleetgoYellow,
                title: 'Phone Support',
                subtitle: 'Call us directly',
                value: '+91 123 456 7890',
                onTap: () => _launchUri('tel:+911234567890'),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildContactCard(
                customIconWidget: Icon(Icons.chat_bubble_rounded, color: const Color(0xFF25D366), size: 24.sp),
                title: 'WhatsApp',
                subtitle: 'Chat on WhatsApp',
                value: '+91 123 456 7890',
                onTap: () => _launchUri('https://wa.me/911234567890'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildContactCard(
                icon: Icons.access_time_filled_rounded,
                iconColor: AppColors.fleetgoYellow,
                title: 'Business Hours',
                subtitle: 'Sunday - Thursday',
                value: '9:00 AM - 6:00 PM',
                onTap: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard({
    IconData? icon,
    Color? iconColor,
    Widget? customIconWidget,
    required String title,
    required String subtitle,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: customIconWidget ?? Icon(icon, color: iconColor, size: 20.sp),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 10.sp,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 6.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: EdgeInsets.only(bottom: 10.h),
          height: 70.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: const Color(0xFFDC2626), size: 32.sp),
          SizedBox(height: 8.h),
          Text(
            'Failed to load support tickets',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
          ),
          SizedBox(height: 10.h),
          ElevatedButton(
            onPressed: _fetchTickets,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF9E6),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.confirmation_number_outlined, color: AppColors.fleetgoYellow, size: 36.sp),
          ),
          SizedBox(height: 14.h),
          Text(
            'No tickets yet',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Need help with a ride or payment? Raise a ticket and our support team will assist you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 12.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 18.h),
          ElevatedButton.icon(
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const RaiseIssueScreen()),
              );
              if (created == true) _fetchTickets();
            },
            icon: const Icon(Icons.add_rounded, color: Colors.black),
            label: const Text('Raise Ticket', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.fleetgoYellow,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final ticketId = (ticket['id'] ?? '').toString();
        final ticketNumber = (ticket['ticketNumber'] ?? ticketId).toString();
        final subject = (ticket['subject'] ?? 'Support Issue').toString();
        final rawStatus = (ticket['status'] ?? 'OPEN').toString();
        final (statusLabel, statusTextColor, statusBgColor) = _getStatusChipStyle(rawStatus);
        final dateText = _formatRelativeDate(ticket['createdAt']?.toString());
        final int unread = (ticket['unreadMessages'] is num)
            ? (ticket['unreadMessages'] as num).toInt()
            : 0;

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketChatScreen(ticketId: ticketId, ticketData: ticket),
              ),
            );
            _fetchTickets();
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ticketNumber,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontFamily: 'Gilroy',
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: statusTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 10.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    margin: EdgeInsets.only(left: 8.w),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unread',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Icon(Icons.chevron_right_rounded, color: const Color(0xFF94A3B8), size: 22.sp),
              ],
            ),
          ),
        );
      },
    );
  }
}
