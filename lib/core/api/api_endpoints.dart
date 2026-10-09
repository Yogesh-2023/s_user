/// Endpoints from Fleet-Management-User-APIs.postman_collection.
///
/// Keep every customer URL here so UI code never contains API paths.
class ApiEndpoints {
  const ApiEndpoints._();

  static const String _customer = '/api/v1/customer';

  // Authentication
  static const String sendOtp = '$_customer/auth/send-otp';
  static const String resendOtp = '$_customer/auth/resend-otp';
  static const String verifyOtp = '$_customer/auth/verify-otp';
  static const String authSession = '$_customer/auth/session';
  static const String authSessions = '$_customer/auth/sessions';
  static String revokeSession(String id) => '$authSessions/$id';
  static const String logout = '$_customer/auth/logout';
  static const String logoutAll = '$_customer/auth/logout-all';
  static const String account = '$_customer/auth/account';

  // Profile and settings
  static const String profile = '$_customer/profile';
  static const String profileCreate = profile;
  static const String profileMe = profile;
  static const String profileUpdate = profile;
  static const String profilePreferences = '$profile/preferences';
  static const String profileImage = '$profile/image';
  static const String profileImageUploadUrl = '$profileImage/upload-url';
  static const String onboardingStatus = '$_customer/onboarding-status';
  static const String settings = '$_customer/settings';
  static const String deletionRequest = '$_customer/account/deletion-request';
  static const String cancelDeletionRequest = '$deletionRequest/cancel';
  static const String dataExport = '$_customer/account/data-export';
  static String dataExportStatus(String id) =>
      '$_customer/account/data-exports/$id';

  // Addresses and location
  static const String addresses = '$_customer/addresses';
  static String address(String id) => '$addresses/$id';
  static String defaultAddress(String id) => '${address(id)}/default';
  static const String recentAddresses = '$addresses/recent';
  static const String locationSearch = '$_customer/locations/search';
  static const String reverseGeocode = '$_customer/locations/reverse-geocode';
  static const String serviceability = '$_customer/locations/serviceability';
  static const String serviceAreas = '$_customer/service-areas';
  static String locationsPincode(String pincode) => '/locations/pincodes/$pincode';

  // Categories, fares and bookings
  static const String vehicleCategories = '$_customer/vehicle-categories';
  static String vehicleCategory(String id) => '$vehicleCategories/$id';
  static const String fareEstimate = '$_customer/fares/estimate';
  static const String bookings = '$_customer/bookings';
  static const String bookRide = bookings;
  static const String scheduledBooking = '$bookings/scheduled';
  static String rescheduleBooking(String id) => '$bookings/$id/reschedule';
  static const String scheduledRides = '$_customer/scheduled-rides';
  static String scheduledRide(String id) => '$scheduledRides/$id';
  static const String activeBooking = '$bookings/active';
  static String bookingDetails(String id) => '$bookings/$id';
  static String bookingTimeline(String id) => '$bookings/$id/timeline';
  static String bookingDriver(String id) => '$bookings/$id/driver';
  static String bookingFare(String id) => '$bookings/$id/fare';
  static String bookingPayment(String id) => '$bookings/$id/payment';
  static String liveDriverLocation(String id) =>
      '$bookings/$id/live-driver-location';
  static String bookingStatus(String id) => '$bookings/$id/status';
  static String bookingVehicle(String id) => '$bookings/$id/vehicle';
  static String driverLocation(String id) => '$bookings/$id/driver-location';
  static String pickupEta(String id) => '$bookings/$id/pickup-eta';
  static String retryDriverSearch(String id) => '$bookings/$id/retry-search';
  static String pickupOtp(String id) => '$bookings/$id/pickup-otp';
  static String sendPickupOtp(String id) => '${pickupOtp(id)}/send';
  static String resendTripOtp(String tripId) => '/api/v1/trips/$tripId/otp';
  static String fareBreakdown(String id) => '$bookings/$id/fare-breakdown';
  static String bookingInvoice(String id) => '$bookings/$id/invoice';
  static String bookingInvoiceDownload(String id) =>
      '${bookingInvoice(id)}/download';
  static String cancelBooking(String id) => '$bookings/$id/cancel';
  static const String home = '$_customer/home';
  static const String nearbyVehicles = '$_customer/nearby-vehicles';
  static String nearbyDrivers(String id) => '$bookings/$id/nearby-drivers';

  // Trips and tracking
  static const String trips = '$_customer/trips';
  static const String activeTrip = '$trips/active';
  static String trip(String id) => '$trips/$id';
  static String tripLiveLocation(String id) => '$trips/$id/live-location';
  static String tripTimeline(String id) => '$trips/$id/timeline';
  static String tripInvoice(String id) => '$trips/$id/invoice';
  static String tripShare(String id) => '$trips/$id/share';
  static String tripOtpStatus(String id) => '$trips/$id/start-otp-status';
  static String bookingTracking(String id) => '$bookings/$id/tracking';
  static String bookingRoute(String id) => '$bookings/$id/route';
  static String bookingLive(String id) => '$bookings/$id/live';
  static String bookingShare(String id) => '$bookings/$id/share';

  // Payments and wallet
  static const String payments = '/api/v1/payments';
  static const String paymentsVerify = '/api/v1/payments/verify';
  static String paymentOptions(String id) => '$bookings/$id/payment-options';
  static String changePaymentMethod(String id) =>
      '$bookings/$id/change-payment-method';
  static const String createPaymentOrder = '$_customer/payments/create-order';
  static const String verifyPayment = '$_customer/payments/verify';
  static String payBooking(String id) => '$bookings/$id/pay';
  static String paymentStatus(String id) => '$bookings/$id/payment-status';
  static String retryPayment(String id) => '$bookings/$id/retry-payment';
  static String refund(String id) => '$bookings/$id/refund';
  static const String wallet = '$_customer/wallet';
  static const String walletAddMoney = '$wallet/add-money';
  static const String walletVerify = '$wallet/verify';

  // Offers, referrals and ratings
  static const String offers = '$_customer/offers';
  static const String coupons = '$_customer/coupons/available';
  static const String validateCoupon = '$_customer/coupons/validate';
  static const String couponHistory = '$_customer/coupons/history';
  static const String referralCode = '$_customer/referrals/code';
  static const String applyReferral = '$_customer/referrals/apply';
  static const String referrals = '$_customer/referrals';
  static const String referralRewards = '$referrals/rewards';
  static const String ratings = '$_customer/ratings';
  static String tripRating(String id) => '$trips/$id/rating';
  static String rating(String id) => '$ratings/$id';
  static String bookingRating(String id) => '$bookings/$id/rating';
  static String bookingTip(String id) => '$bookings/$id/tip';

  // Notifications
  static const String notifications = '$_customer/notifications';
  static String notificationDetail(String id) => '$notifications/$id';
  static String markNotificationRead(String id) => '$notifications/$id/read';
  static const String markAllNotificationsRead = '$notifications/read-all';
  static const String unreadNotificationCount = '$notifications/unread-count';
  static const String deviceTokens = '$_customer/device-tokens';
  static String deviceToken(String id) => '$deviceTokens/$id';
  static const String notificationPreferences = settings;
  static String markNotificationUnread(String id) => notificationDetail(id);

  // Support
  static const String supportCategories = '$_customer/support/categories';
  static const String tickets = '$_customer/support/tickets';
  static String ticket(String id) => '$tickets/$id';
  static String ticketMessages(String id) => '$tickets/$id/messages';
  static String ticketMessagesRead(String id) => '$tickets/$id/messages/read';
  static String ticketClose(String id) => '$tickets/$id/close';
  static const String supportAttachments = '$_customer/support/attachments';
  static String bookingMessages(String id) => '$bookings/$id/messages';
  static String reportBooking(String id) => '$bookings/$id/report';
  static String reportLostItem(String id) => '$bookings/$id/lost-item';

  // Safety
  static const String sos = '$_customer/safety/sos';
  static String sosDetails(String id) => '$sos/$id';
  static String cancelSos(String id) => '$sos/$id/cancel';
  static const String incidents = '$_customer/safety/incidents';
  static const String emergencyContacts = '$_customer/emergency-contacts';
  static String emergencyContact(String id) => '$emergencyContacts/$id';
  static String bookingSos(String id) => '$bookings/$id/sos';
  static String bookingSafetyReport(String id) => '$bookings/$id/safety-report';

  // Compatibility aliases used by the current UI while screens are unified.
  static const String userRideHistory = bookings;
  static const String ongoingBooking = activeBooking;
  static const String rideDriverLocation = activeTrip;
  static const String carOptions = vehicleCategories;
  static const String premiumCars = vehicleCategories;
  static const String createPremiumBooking = bookings;
  static const String userBookings = bookings;
  static const String bookingRequests = bookings;
  static const String userPremiumBookings = bookings;
  static const String pendingUserPremiumBookings = bookings;
  static const String rejectedUserPremiumBookings = bookings;
  static const String expiredUserPremiumBookings = bookings;
  static const String goodsVehicleBrands = vehicleCategories;
  static const String goodsEstimate = fareEstimate;
  static const String goodsBookings = bookings;
  static String goodsBookingDetails(String id) => bookingDetails(id);
  static String goodsAdvancePayment(String id) => payBooking(id);
  static String goodsCancel(String id) => cancelBooking(id);
  static String goodsPayment(String id) => payBooking(id);
  static String goodsPaymentStatus(String id) => paymentStatus(id);
  static String goodsReachedPickup(String id) => bookingStatus(id);
  static String goodsStart(String id) => bookingStatus(id);
  static String goodsVerifyPickupOtp(String id) => pickupOtp(id);
  static String goodsVerifyDeliveryOtp(String id) => pickupOtp(id);
  static String goodsStatus(String id) => bookingStatus(id);
  static String goodsTracking(String id) => bookingTracking(id);
  static const String registerToken = deviceTokens;
  static const String notificationToken = deviceTokens;
  static String getBookingReview(String id) => bookingRating(id);
  static const String submitUserReview = ratings;
  static const String allUserReviews = ratings;
}
