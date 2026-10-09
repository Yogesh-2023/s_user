import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_fonts.dart';

class RazorpayCheckoutSheet extends StatefulWidget {
  final double amount;
  final String businessName;
  final String description;

  const RazorpayCheckoutSheet({
    super.key,
    required this.amount,
    this.businessName = 'DOBELGO DELIVERY',
    this.description = 'Goods Booking Advance Payment',
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required double amount,
    String businessName = 'DOBELGO DELIVERY',
    String description = 'Goods Booking Advance Payment',
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RazorpayCheckoutSheet(
          amount: amount,
          businessName: businessName,
          description: description,
        ),
      ),
    );
  }

  @override
  State<RazorpayCheckoutSheet> createState() => _RazorpayCheckoutSheetState();
}

enum CheckoutStep { selectMethod, cardDetails, processing, success }

class _RazorpayCheckoutSheetState extends State<RazorpayCheckoutSheet> {
  CheckoutStep _step = CheckoutStep.selectMethod;
  String _selectedMethodLabel = '';

  // Card controllers
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardFormKey = GlobalKey<FormState>();

  String? _transactionId;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }

  void _startProcessing(String methodLabel) {
    setState(() {
      _selectedMethodLabel = methodLabel;
      _step = CheckoutStep.processing;
    });

    // Simulate payment processing logic
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        final rand = math.Random();
        final code = List.generate(9, (_) => rand.nextInt(10)).join();
        setState(() {
          _transactionId =
              'pay_${methodLabel.replaceAll(' ', '').toUpperCase().substring(0, 3)}_$code';
          _step = CheckoutStep.success;
        });

        // Delay before returning success to user
        Timer(const Duration(milliseconds: 1800), () {
          if (mounted) {
            Navigator.pop(context, {
              'success': true,
              'transactionId': _transactionId,
              'method': methodLabel,
            });
          }
        });
      }
    });
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Razorpay Dark Theme Color
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Razorpay text style
                  Text(
                    'Razorpay',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Container(
                    width: 5.w,
                    height: 5.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4B41A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.grey.shade400,
                    size: 14.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'SECURE CHECKOUT',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PAYING AMOUNT',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '₹${widget.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 18.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUPIItem({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 20.sp),
        ),
      ),
      title: Text(
        title,
        style: AppFonts.bodyText.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 13.sp,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppFonts.captionDark.copyWith(
          color: Colors.grey.shade500,
          fontSize: 11.sp,
          fontWeight: FontWeight.normal,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 12,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSelectMethodStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Text(
            'UPI PAYMENTS',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _buildUPIItem(
          icon: Icons.account_balance_wallet,
          iconBg: const Color(0xFF4285F4),
          title: 'Google Pay',
          subtitle: 'Pay directly from your bank account',
          onTap: () => _startProcessing('Google Pay'),
        ),
        const Divider(height: 1, indent: 70),
        _buildUPIItem(
          icon: Icons.phone_android,
          iconBg: const Color(0xFF5F259F),
          title: 'PhonePe',
          subtitle: 'Pay using saved cards or UPI',
          onTap: () => _startProcessing('PhonePe'),
        ),
        const Divider(height: 1, indent: 70),
        _buildUPIItem(
          icon: Icons.payment,
          iconBg: const Color(0xFF00B9F1),
          title: 'Paytm UPI',
          subtitle: 'Link UPI directly or use wallet',
          onTap: () => _startProcessing('Paytm'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Text(
            'CARDS & OTHER PAYMENT METHODS',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ListTile(
          onTap: () {
            setState(() {
              _step = CheckoutStep.cardDetails;
            });
          },
          leading: Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.credit_card, color: Colors.white, size: 20.sp),
          ),
          title: Text(
            'Card',
            style: AppFonts.bodyText.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
            ),
          ),
          subtitle: Text(
            'Pay via Visa, Mastercard, RuPay, Maestro',
            style: AppFonts.captionDark.copyWith(
              color: Colors.grey.shade500,
              fontSize: 11.sp,
              fontWeight: FontWeight.normal,
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: Colors.grey,
          ),
        ),
        const Divider(height: 1, indent: 70),
        ListTile(
          onTap: () => _startProcessing('Netbanking'),
          leading: Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.account_balance,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          title: Text(
            'Netbanking',
            style: AppFonts.bodyText.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
            ),
          ),
          subtitle: Text(
            'All major banks (HDFC, SBI, ICICI, AXIS, etc.)',
            style: AppFonts.captionDark.copyWith(
              color: Colors.grey.shade500,
              fontSize: 11.sp,
              fontWeight: FontWeight.normal,
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildCardDetailsStep() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
      child: Form(
        key: _cardFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _step = CheckoutStep.selectMethod;
                    });
                  },
                ),
                Text(
                  'Card Details',
                  style: AppFonts.h2.copyWith(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: 'Card Number',
                hintText: '4111 1111 1111 1111',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                prefixIcon: const Icon(Icons.credit_card),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                if (val.replaceAll(' ', '').length < 16) return 'Invalid Card';
                return null;
              },
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardExpiryController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: 'Expiry (MM/YY)',
                      hintText: '12/29',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || !val.contains('/')) return 'Required';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: TextFormField(
                    controller: _cardCvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      hintText: '•••',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 3)
                        return 'Required';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _cardNameController,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: 'Card Holder Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPressed: () {
                  if (_cardFormKey.currentState?.validate() ?? false) {
                    _startProcessing('Card');
                  }
                },
                child: Text(
                  'PAY ₹${widget.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 40.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48.w,
            height: 48.w,
            child: const CircularProgressIndicator(
              color: Color(0xFFF4B41A),
              strokeWidth: 4,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Processing payment via $_selectedMethodLabel',
            textAlign: TextAlign.center,
            style: AppFonts.bodyText.copyWith(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Do not press back, close this window, or reload the application.',
            textAlign: TextAlign.center,
            style: AppFonts.captionDark.copyWith(
              fontSize: 12.sp,
              fontWeight: FontWeight.normal,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 40.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated checkmark rosette
          CustomPaint(
            size: Size(64.w, 64.w),
            painter: PaymentCheckRosettePainter(),
          ),
          SizedBox(height: 24.h),
          Text(
            'Payment Successful',
            style: AppFonts.h2.copyWith(
              fontSize: 18.sp,
              color: const Color(0xFF1C9840),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          if (_transactionId != null)
            Text(
              'Transaction ID: $_transactionId',
              style: AppFonts.captionDark.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _step == CheckoutStep.selectMethod
                ? _buildSelectMethodStep()
                : _step == CheckoutStep.cardDetails
                ? _buildCardDetailsStep()
                : _step == CheckoutStep.processing
                ? _buildProcessingStep()
                : _buildSuccessStep(),
          ),
          // Footer trust text
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Colors.grey.shade500,
                  size: 14.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  '100% Safe and Secure Payment via Razorpay',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Rosette painter for payment success
class PaymentCheckRosettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C9840)
      ..style = PaintingStyle.fill;

    final double radius = size.width / 2;
    final center = Offset(radius, radius);

    // Draw rosette petals
    const int numPetals = 16;
    final Path rosettePath = Path();
    for (int i = 0; i < numPetals * 2; i++) {
      final double angle = (i * math.pi) / numPetals;
      final double r = i % 2 == 0 ? radius : radius * 0.88;
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        rosettePath.moveTo(x, y);
      } else {
        rosettePath.lineTo(x, y);
      }
    }
    rosettePath.close();
    canvas.drawPath(rosettePath, paint);

    // Draw inner white circle border and fill
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.72, paint);

    paint.color = const Color(0xFF1C9840);
    canvas.drawCircle(center, radius * 0.65, paint);

    // Draw checkmark
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = radius * 0.12;
    paint.strokeCap = StrokeCap.round;

    final checkPath = Path();
    checkPath.moveTo(center.dx - radius * 0.3, center.dy);
    checkPath.lineTo(center.dx - radius * 0.08, center.dy + radius * 0.22);
    checkPath.lineTo(center.dx + radius * 0.32, center.dy - radius * 0.18);
    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
