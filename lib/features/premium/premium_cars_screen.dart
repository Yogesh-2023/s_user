import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_fonts.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_service.dart';
import 'premium_car_booking_screen.dart';

class PremiumCarsScreen extends StatefulWidget {
  const PremiumCarsScreen({super.key});

  @override
  State<PremiumCarsScreen> createState() => _PremiumCarsScreenState();
}

class _PremiumCarsScreenState extends State<PremiumCarsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cars = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchCars();
  }

  Future<void> _fetchCars() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.to.get(ApiEndpoints.premiumCars);
      final payload = response.data is Map && response.data['data'] != null
          ? response.data['data']
          : response.data;
      final raw = payload is List
          ? payload
          : payload is Map
          ? payload['items'] ?? payload['categories'] ?? payload['cars']
          : null;
      if (!mounted) return;
      setState(() {
        _cars = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().split(':').last.trim();
        _loading = false;
      });
    }
  }

  dynamic _nested(Map<String, dynamic> car, String key, String child) {
    final value = car[key];
    return value is Map ? value[child] : null;
  }

  String? _image(Map<String, dynamic> car) =>
      _nested(car, 'model', 'imageUrl')?.toString();

  @override
  Widget build(BuildContext context) {
    final filteredCars = _searchQuery.isEmpty
        ? _cars
        : _cars.where((car) {
            final brand =
                _nested(car, 'brand', 'name')?.toString().toLowerCase() ?? '';
            final model =
                _nested(car, 'model', 'name')?.toString().toLowerCase() ?? '';
            final search = _searchQuery.toLowerCase();
            return brand.contains(search) || model.contains(search);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF4B41A)),
                  )
                : _error != null
                ? _errorState()
                : RefreshIndicator(
                    color: const Color(0xFFF4B41A),
                    onRefresh: _fetchCars,
                    child: filteredCars.isEmpty
                        ? ListView(children: const [_PremiumEmptyState()])
                        : ListView.builder(
                            padding: EdgeInsets.all(14.w),
                            itemCount: filteredCars.length,
                            itemBuilder: (_, index) =>
                                _carCard(filteredCars[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
    color: const Color(0xFFFFF9E6),
    padding: EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + 16.h,
      bottom: 16.h,
      left: 20.w,
      right: 20.w,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Cars',
                    style: AppFonts.h1.copyWith(
                      fontSize: 20.sp,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Luxury rides, booked by the hour',
                    style: AppFonts.captionDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: const Color(0xFFF4B41A).withValues(alpha: 0.3),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search cars (e.g., Audi, BMW)...',
              hintStyle: AppFonts.bodyText.copyWith(
                color: Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: const Color(0xFFF4B41A),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 40.w),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14.h),
            ),
            style: AppFonts.bodyText,
          ),
        ),
      ],
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: EdgeInsets.all(30.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48.sp, color: Colors.grey),
          SizedBox(height: 12.h),
          Text(_error!, textAlign: TextAlign.center),
          SizedBox(height: 14.h),
          ElevatedButton(
            onPressed: _fetchCars,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4B41A),
              foregroundColor: Colors.black,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    ),
  );

  Widget _carCard(Map<String, dynamic> car) {
    final brand = _nested(car, 'brand', 'name')?.toString() ?? 'Premium';
    final model = _nested(car, 'model', 'name')?.toString() ?? 'Car';
    final price = _nested(car, 'price', 'hourlyPrice') ?? 0;
    final provider = _nested(car, 'provider', 'name')?.toString();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PremiumCarBookingScreen(car: car)),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1.w),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: 80.w,
                height: 80.w,
                color: const Color(0xFFFFF9E6),
                child: _image(car) == null
                    ? Icon(
                        Icons.directions_car_filled_rounded,
                        size: 38.sp,
                        color: const Color(0xFFF4B41A),
                      )
                    : Image.network(
                        _image(car)!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.directions_car_filled_rounded,
                          size: 38.sp,
                          color: const Color(0xFFF4B41A),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$brand $model',
                    style: AppFonts.h2.copyWith(
                      fontSize: 16.sp,
                      color: const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    provider == null ? 'Verified provider' : 'By $provider',
                    style: AppFonts.captionDark,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹$price',
                        style: AppFonts.h2.copyWith(
                          color: const Color(0xFF111827),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('/ hour', style: AppFonts.captionDark),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFFF4B41A),
                        size: 22.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  const _PremiumEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 90.h),
    child: Column(
      children: [
        Icon(
          Icons.directions_car_outlined,
          size: 64.sp,
          color: const Color(0xFFF4B41A),
        ),
        SizedBox(height: 14.h),
        Text('No premium cars available', style: AppFonts.h2),
        SizedBox(height: 6.h),
        Text(
          'Please check again later.',
          style: AppFonts.bodyText,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
