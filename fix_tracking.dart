import 'dart:io';

void main() async {
  final file = File('lib/features/rides/driver_tracking_screen.dart');
  String content = await file.readAsString();

  content = content.replaceAll(
    "(_bookingData?['driver']?['name'] ?? widget.driverData?['booking']?['driver']?['name'] ?? widget.driverData?['driver']?['name'] ?? 'Driver').toString(),",
    "_getDriverName(),",
  );

  content = content.replaceAll(
    "final vehicle = _bookingData?['driver']?['vehicle'] ?? widget.driverData?['booking']?['driver']?['vehicle'] ?? widget.driverData?['driver']?['vehicle'] ?? widget.driverData?['vehicle'] ?? widget.driverData?['booking']?['vehicle'] ?? {};",
    "final vehicle = _getVehicleData();",
  );

  content = content.replaceAll(
    "final vehicle = _bookingData?['driver']?['vehicle'] ?? widget.driverData?['booking']?['driver']?['vehicle'] ?? widget.driverData?['driver']?['vehicle'] ?? widget.driverData?['vehicle'] ?? widget.driverData?['booking']?['vehicle'];",
    "final vehicle = _getVehicleData();",
  );

  content = content.replaceAll(
    "String _getDriverName()",
    "// Already added String _getDriverName()",
  );

  final helpers = """
  String _getDriverName() {
    final driver = _bookingData?['driver'] ?? widget.driverData?['booking']?['driver'] ?? widget.driverData?['driver'] ?? {};
    final firstName = driver['firstName'] ?? '';
    final lastName = driver['lastName'] ?? '';
    final name = '\$firstName \$lastName'.trim();
    if (name.isNotEmpty) return name;
    return driver['name']?.toString() ?? 'Unknown Driver';
  }

  Map<String, dynamic> _getVehicleData() {
    final driver = _bookingData?['driver'] ?? widget.driverData?['booking']?['driver'] ?? widget.driverData?['driver'] ?? {};
    final vehicle = driver['assignedVehicle'] ?? driver['vehicle'] ?? widget.driverData?['vehicle'] ?? widget.driverData?['booking']?['vehicle'] ?? {};
    return vehicle;
  }
""";

  content = content.replaceFirst(
    "class _DriverTrackingScreenState extends State<DriverTrackingScreen> {",
    "class _DriverTrackingScreenState extends State<DriverTrackingScreen> {\n\$helpers",
  );

  // ETA logic replace
  content = content.replaceAll(
    "                      _rideState == RideState.arriving\n                          ? 'Arriving in 3 min'\n                          : '1 min',",
    "                      _calculateETA(),",
  );

  final etaHelper = """
  String _calculateETA() {
    if (_rideState != RideState.arriving) return 'Arrived';
    if (_currentPosition == null || _driverLocation == null) return 'Estimating...';
    double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude,
      _driverLocation!.latitude, _driverLocation!.longitude,
    );
    int minutes = (distanceInMeters / 500).ceil();
    if (minutes <= 0) return 'Arriving now';
    return 'Arriving in \$minutes min';
  }
""";

  content = content.replaceFirst(
    "class _DriverTrackingScreenState extends State<DriverTrackingScreen> {\n",
    "class _DriverTrackingScreenState extends State<DriverTrackingScreen> {\n\$etaHelper",
  );

  await file.writeAsString(content);
}
