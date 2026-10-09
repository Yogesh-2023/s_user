import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../constants/app_fonts.dart';
import '../parcels/pickup_address_screen.dart';
import 'location_search_screen.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_endpoints.dart';

class SearchVehiclesScreen extends StatefulWidget {
  final String? pickupAddress;

  const SearchVehiclesScreen({super.key, this.pickupAddress});

  @override
  State<SearchVehiclesScreen> createState() => _SearchVehiclesScreenState();
}

class _SearchVehiclesScreenState extends State<SearchVehiclesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  String _selectedCategory = 'all';
  bool _isLoading = false;
  int? _selectedVehicleIndex;

  final List<Map<String, dynamic>> _vehicles = [
    // Trucks
    {
      'title': 'Tata Ace',
      'category': 'truck',
      'time': '8 min away',
      'dropTime': 'Delivery 5:45 pm',
      'price': '₹447',
      'oldPrice': null,
      'image': 'assets/images/truck.png',
      'description': '800 kgs Capacity • 6.5ft x 5ft x 4ft',
    },
    {
      'title': 'Mini Truck',
      'category': 'truck',
      'time': '8 min away',
      'dropTime': 'Delivery 5:45 pm',
      'price': '₹599',
      'oldPrice': null,
      'image': 'assets/images/truck.png',
      'description': '2 Ton Capacity • 10ft x 6ft x 6ft',
    },
    {
      'title': 'Large Truck',
      'category': 'truck',
      'time': '10 min away',
      'dropTime': 'Delivery 6:00 pm',
      'price': '₹1499',
      'oldPrice': null,
      'image': 'assets/images/truck.png',
      'description': '5 Ton Capacity • 17ft x 7ft x 7ft',
    },
    {
      'title': 'Heavy Duty Truck',
      'category': 'truck',
      'time': '12 min away',
      'dropTime': 'Delivery 6:15 pm',
      'price': '₹2499',
      'oldPrice': null,
      'image': 'assets/images/truck.png',
      'description': '10 Ton Capacity • Heavy haulage',
    },

    // Parcels
    {
      'title': 'Small Parcel',
      'category': 'parcel',
      'time': '5 min away',
      'dropTime': 'Delivery 5:35 pm',
      'price': '₹299',
      'oldPrice': null,
      'image': 'assets/images/on1.png',
      'description': 'Perfect for boxes up to 5 kg',
    },
    {
      'title': 'Large Parcel',
      'category': 'parcel',
      'time': '5 min away',
      'dropTime': 'Delivery 5:40 pm',
      'price': '₹399',
      'oldPrice': null,
      'image': 'assets/images/on1.png',
      'description': 'Ideal for large boxes up to 20 kg',
    },
    {
      'title': 'Documents',
      'category': 'parcel',
      'time': '5 min away',
      'dropTime': 'Delivery 5:35 pm',
      'price': '₹199',
      'oldPrice': null,
      'image': 'assets/images/on1.png',
      'description': 'Secure document and key deliveries',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchCarOptions();
  }

  Future<void> _fetchCarOptions() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.to.get(ApiEndpoints.carOptions);
      if (response.data != null) {
        List<dynamic> cars = response.data is List
            ? response.data
            : (response.data['data'] is List
                  ? response.data['data']
                  : response.data['data']?['items'] ??
                        response.data['items'] ??
                        response.data['carOptions'] ??
                        []);
        if (cars.isNotEmpty) {
          // Remove old Cabs / Cars
          _vehicles.removeWhere(
            (v) =>
                v['category'] == 'cab' ||
                v['category'] == 'car' ||
                v['category'] == 'fortuner',
          );

          List<Map<String, dynamic>> fetchedCars = [];
          for (var car in cars) {
            final title =
                car['name'] ??
                car['displayName'] ??
                car['carType'] ??
                'Vehicle';
            fetchedCars.add({
              'title': title,
              'category': _categoryForCarOption(title),
              'time': '3 min away',
              'dropTime': 'Available',
              'price': null,
              'oldPrice': null,
              'image': 'assets/images/on3.png',
              'description':
                  car['description'] ??
                  '${car['capacity'] ?? ''} ${car['capacityUnit'] ?? ''}'
                      .trim(),
            });
          }
          // Insert at the beginning
          _vehicles.insertAll(0, fetchedCars);
        }
      }
    } catch (e) {
      debugPrint("Error fetching car options: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _categoryForCarOption(dynamic title) {
    final titleLower = title.toString().toLowerCase();
    if (titleLower.contains('fortuner')) return 'fortuner';
    if (titleLower.contains('cab') || titleLower.contains('taxi')) return 'cab';
    return 'car';
  }

  final List<Map<String, String>> _categories = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Cab', 'value': 'cab'},
    {'label': 'Car', 'value': 'car'},
    {'label': 'Truck', 'value': 'truck'},
    {'label': 'Fortuner', 'value': 'fortuner'},
    {'label': 'Parcel', 'value': 'parcel'},
  ];

  List<Map<String, dynamic>> _getFilteredVehicles(String category) {
    return _vehicles.where((v) {
      // Filter by selected tab
      final categoryMatch = category == 'all' || v['category'] == category;

      if (!categoryMatch) return false;

      if (_query.isEmpty) return true;

      final queryLower = _query.toLowerCase();
      final titleLower = v['title'].toString().toLowerCase();
      final categoryLower = v['category'].toString().toLowerCase();
      final descLower = v['description'].toString().toLowerCase();

      // Check synonyms
      if (queryLower == 'car' &&
          (v['category'] == 'cab' ||
              v['category'] == 'car' ||
              v['category'] == 'fortuner')) {
        return true;
      }
      if (queryLower == 'cab' &&
          (v['category'] == 'cab' ||
              v['category'] == 'car' ||
              v['category'] == 'fortuner')) {
        return true;
      }

      return titleLower.contains(queryLower) ||
          categoryLower.contains(queryLower) ||
          descLower.contains(queryLower);
    }).toList();
  }

  void _navigateToFlow(Map<String, dynamic> vehicle) {
    final cat = vehicle['category'];
    if (cat == 'truck' || cat == 'parcel') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PickupAddressScreen(initialPickupAddress: widget.pickupAddress),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LocationSearchScreen(initialPickupLocation: widget.pickupAddress),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Column(
            children: [
              // Top App Bar Area
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                color: Colors.white,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.black,
                          size: 18.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Container(
                        height: 46.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(23.r),
                          border: Border.all(
                            color: const Color(0xFFF4B41A).withValues(alpha: 0.4),
                            width: 1.5.w,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          onChanged: (val) {
                            setState(() {
                              _query = val;
                            });
                          },
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search Car, Cab, Truck, Fortuner...',
                            hintStyle: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              color: Colors.grey,
                              fontSize: 13.sp,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: const Color(0xFFF4B41A),
                              size: 20.sp,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _query = '';
                                      });
                                    },
                                    child: Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                      size: 20.sp,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Tab Bar
              _buildCategoryTabs(),

              // Results List
              Expanded(
                child: TabBarView(
                  children: _categories.map((cat) {
                    return _buildListForCategory(cat['value']!);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListForCategory(String category) {
    final results = _getFilteredVehicles(category);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF4B41A)),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer ripple
                Container(
                  width: 130.w,
                  height: 130.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B41A).withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
                // Inner ripple
                Container(
                  width: 96.w,
                  height: 96.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B41A).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                ),
                // Main Icon Container
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 18.w,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF4B41A).withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 42.sp,
                    color: const Color(0xFFF4B41A),
                  ),
                ),
                // Tiny badge icon
                Positioned(
                  bottom: 24.h,
                  right: 24.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 6.w,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 16.sp,
                      color: const Color(0xFFF4B41A),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Text(
              'No Vehicles Found',
              style: TextStyle(
                fontFamily: AppFonts.fontFamily,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Text(
                'Try searching for "Truck", "Cab", or "Fortuner"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8BA3B8),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.w),
      itemCount: results.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return _buildVehicleCard(results[index], index);
      },
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50.h,
      color: Colors.white,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        labelPadding: EdgeInsets.symmetric(horizontal: 14.w),
        indicatorColor: const Color(0xFFF4B41A),
        indicatorWeight: 3.h,
        dividerColor: Colors.grey.shade200,
        labelColor: const Color(0xFF111827),
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: TextStyle(
          fontFamily: AppFonts.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 13.sp,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppFonts.fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13.sp,
        ),
        tabs: _categories.map((cat) => Tab(text: cat['label']!)).toList(),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, int index) {
    final oldPrice = vehicle['oldPrice'];
    final bool isSelected = _selectedVehicleIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVehicleIndex = index;
        });
        _navigateToFlow(vehicle);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF4B41A)
                : const Color(0xFFEEEEEE),
            width: isSelected ? 1.5.w : 1.w,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF4B41A).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Vehicle Image Container
            Container(
              width: 58.w,
              height: 58.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                child: Image.asset(vehicle['image'], fit: BoxFit.contain),
              ),
            ),
            SizedBox(width: 14.w),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle['title'],
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Text(
                        vehicle['time'],
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        vehicle['dropTime'],
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (vehicle['description'] != null &&
                      vehicle['description'].toString().isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      vehicle['description'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 11.sp,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (vehicle['price'] != null &&
                    vehicle['price'].toString().isNotEmpty)
                  Row(
                    children: [
                      if (oldPrice != null)
                        Icon(
                          Icons.local_offer,
                          color: const Color(0xFFF4B41A),
                          size: 14.sp,
                        ),
                      if (oldPrice != null) SizedBox(width: 4.w),
                      Text(
                        vehicle['price'].toString(),
                        style: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                if (oldPrice != null)
                  Text(
                    oldPrice,
                    style: TextStyle(
                      fontFamily: AppFonts.fontFamily,
                      fontSize: 12.sp,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
