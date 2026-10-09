import 'package:flutter/material.dart';
import 'cancellation_reason_drawer.dart';

class CancelRideScreen extends StatelessWidget {
  final String tripId;
  final bool isGoods;

  const CancelRideScreen({
    super.key,
    required this.tripId,
    this.isGoods = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: CancellationReasonDrawer(
          tripId: tripId,
        ),
      ),
    );
  }
}
