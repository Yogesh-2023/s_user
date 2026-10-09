import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../main_navigation_screen.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    _buildBalanceCard(context),
                    SizedBox(height: 24.h),
                    _buildRecentTransactionsSection(),
                    SizedBox(height: 32.h),
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
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                final navState = context
                    .findAncestorStateOfType<MainNavigationScreenState>();
                if (navState != null) {
                  navState.setIndex(0); // Go to Home
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MainNavigationScreen(initialIndex: 0),
                    ),
                    (route) => false,
                  );
                }
              }
            },
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 22.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Wallet',
              style: AppFonts.h1.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF8EC), // Soft green gradient
            Color(0xFFF2FAF4),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFF28A745).withOpacity(0.25),
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF28A745).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Balance',
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                FutureBuilder(
                  future: ApiService.to.get(ApiEndpoints.wallet),
                  builder: (context, snapshot) {
                    final raw = snapshot.data?.data;
                    final data = raw is Map && raw['data'] is Map
                        ? raw['data'] as Map
                        : raw is Map
                        ? raw
                        : const <String, dynamic>{};
                    final balance =
                        data['balance'] ?? data['availableBalance'] ?? 0;
                    return Text(
                      '₹${double.tryParse(balance.toString())?.toStringAsFixed(2) ?? balance}',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28A745).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'Wallet Balance',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF28A745),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    // Add Money Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showAddMoneyDialog(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF28A745),
                            borderRadius: BorderRadius.circular(10.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF28A745).withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: Colors.white,
                                size: 12.sp,
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  'Add Money',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.fontFamily,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Send Money Button
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_outward_rounded,
                              color: AppColors.textPrimary,
                              size: 12.sp,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                'Send Money',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.fontFamily,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(flex: 4, child: _buildWallet3DGraphic()),
        ],
      ),
    );
  }

  Future<void> _showAddMoneyDialog(BuildContext context) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add money'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            hintText: 'Amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim()),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !context.mounted) return;
    try {
      await ApiService.to.post(
        ApiEndpoints.walletAddMoney,
        body: {'amount': amount},
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment order created successfully.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildWallet3DGraphic() {
    return SizedBox(
      width: 100.w,
      height: 100.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft glowing circle
          Container(
            width: 75.w,
            height: 75.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF28A745).withOpacity(0.06),
            ),
          ),
          // Stack of gold coins in front of the wallet
          Positioned(
            left: 10.w,
            bottom: 12.h,
            child: Column(
              children: [
                _buildCoin(14.w),
                SizedBox(height: 1.h),
                _buildCoin(16.w),
                SizedBox(height: 1.h),
                _buildCoin(18.w),
              ],
            ),
          ),
          // Green Wallet
          Positioned(
            right: 8.w,
            bottom: 16.h,
            child: Container(
              width: 58.w,
              height: 46.h,
              decoration: BoxDecoration(
                color: const Color(0xFF28A745),
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF28A745).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Wallet flap details
                  Positioned(
                    right: 0,
                    top: 8.h,
                    bottom: 8.h,
                    child: Container(
                      width: 20.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E7E34),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6.r),
                          bottomLeft: Radius.circular(6.r),
                          topRight: Radius.circular(10.r),
                          bottomRight: Radius.circular(10.r),
                        ),
                      ),
                    ),
                  ),
                  // Wallet buckle button (golden circle)
                  Positioned(
                    right: 8.w,
                    top: 18.h,
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC107),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Green card emerging from wallet
                  Positioned(
                    top: -5.h,
                    left: 10.w,
                    child: Container(
                      width: 25.w,
                      height: 10.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5CB85C),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Extra coin on ground
          Positioned(
            left: 28.w,
            bottom: 8.h,
            child: Transform.rotate(
              angle: 0.5,
              child: _buildCoin(14.w, isFlat: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoin(double width, {bool isFlat = false}) {
    return Container(
      width: width,
      height: isFlat ? 6.h : 5.h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFD39E00), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF28A745).withOpacity(0.25),
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionItem(
            icon: Icons.add_circle_outline_rounded,
            title: 'Add Money',
            subtitle: 'Top up your wallet',
          ),
          _buildVerticalDivider(),
          _buildQuickActionItem(
            icon: Icons.swap_horizontal_circle_outlined,
            title: 'Send Money',
            subtitle: 'Transfer to bank',
          ),
          _buildVerticalDivider(),
          _buildQuickActionItem(
            icon: Icons.history_rounded,
            title: 'Transaction History',
            subtitle: 'View all transactions',
          ),
          _buildVerticalDivider(),
          _buildQuickActionItem(
            icon: Icons.local_offer_outlined,
            title: 'Offers & Rewards',
            subtitle: 'View cashback & offers',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.w),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8EC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF28A745), size: 20.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.fontFamily,
              fontSize: 8.sp,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1.w, height: 40.h, color: Colors.grey.shade100);
  }

  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF28A745),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16.sp,
                      color: const Color(0xFF28A745),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        _buildTransactionTile(
          icon: Icons.arrow_downward_rounded,
          iconColor: const Color(0xFF28A745),
          iconBgColor: const Color(0xFFEAF8EC),
          title: 'Added to Wallet',
          subtitle: 'From HDFC Bank •••• 1234',
          amount: '+ ₹1,000.00',
          amountColor: const Color(0xFF28A745),
          date: '18 May 2024, 11:20 AM',
          isLast: false,
        ),
        _buildTransactionTile(
          icon: Icons.local_shipping_outlined,
          iconColor: const Color(0xFFFD7E14),
          iconBgColor: const Color(0xFFFFF3CD),
          title: 'Payment for Booking',
          subtitle: 'QMTRK123456',
          amount: '- ₹8,450.00',
          amountColor: AppColors.error,
          date: '18 May 2024, 01:20 PM',
          isLast: false,
        ),
        _buildTransactionTile(
          icon: Icons.arrow_downward_rounded,
          iconColor: const Color(0xFF28A745),
          iconBgColor: const Color(0xFFEAF8EC),
          title: 'Added to Wallet',
          subtitle: 'From Paytm •••• 5678',
          amount: '+ ₹500.00',
          amountColor: const Color(0xFF28A745),
          date: '15 May 2024, 09:15 AM',
          isLast: false,
        ),
        _buildTransactionTile(
          icon: Icons.local_shipping_outlined,
          iconColor: const Color(0xFFFD7E14),
          iconBgColor: const Color(0xFFFFF3CD),
          title: 'Payment for Booking',
          subtitle: 'QMTRK123123',
          amount: '- ₹4,250.00',
          amountColor: AppColors.error,
          date: '12 May 2024, 04:45 PM',
          isLast: false,
        ),
        _buildTransactionTile(
          icon: Icons.percent_rounded,
          iconColor: const Color(0xFF6F42C1),
          iconBgColor: const Color(0xFFF1EAFF),
          title: 'Cashback Received',
          subtitle: 'Offer Reward',
          amount: '+ ₹150.00',
          amountColor: const Color(0xFF28A745),
          date: '10 May 2024, 10:30 AM',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTransactionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
    required String date,
    required bool isLast,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: iconColor.withOpacity(0.4), width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 20.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: amountColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: amountColor.withOpacity(0.15),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        amount,
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w900,
                          color: amountColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: AppFonts.captionDark.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11.sp,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          date,
                          style: AppFonts.captionDark.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 52.w,
    );
  }

  Widget _buildTrustFooter() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTrustItem(
            Icons.check_circle_outline_rounded,
            '100% Secure',
            'Your money is safe',
          ),
          _buildTrustItem(
            Icons.history_toggle_off_rounded,
            'Instant Refunds',
            'Get refunds in',
          ),
          _buildTrustItem(
            Icons.shopping_bag_outlined,
            'Use for Bookings',
            'Use wallet balance for',
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF28A745), size: 16.sp),
        SizedBox(width: 4.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 7.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
