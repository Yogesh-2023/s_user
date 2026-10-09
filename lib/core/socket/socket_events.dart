class SocketEvents {
  const SocketEvents._();

  // General Connection Status & Server Events
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String connectError = 'connect_error';
  static const String error = 'error';
  static const String socketReady = 'socket:ready';
  static const String stateSync = 'state:sync';
  static const String socketError = 'socket:error';
  static const String stateSyncRequest = 'state:sync:request';

  // Canonical User Protocol Events
  static const String bookingCreated = 'booking:created';
  static const String bookingTrack = 'booking:track';
  static const String bookingUntrack = 'booking:untrack';
  static const String bookingCancel = 'booking:cancel';
  static const String bookingDriverAssigned = 'booking:driver-assigned';
  static const String bookingCancelled = 'booking:cancelled';
  static const String bookingRescheduled = 'booking:rescheduled';

  // Shared Protocol Events
  static const String sosCreate = 'sos:create';
  static const String chatJoin = 'chat:join';
  static const String chatSend = 'chat:send';

  // Admin Subscribed Events (Server Push)
  static const String adminDriverAvailabilityUpdated =
      'admin:driver:availability-updated';
  static const String adminDriverLocationUpdated =
      'admin:driver:location-updated';
  static const String adminTripLocationUpdated = 'admin:trip:location-updated';

  // ==========================================
  // PASSENGER RIDE FLOW
  // ==========================================

  // Emits (Driver Side)
  static const String driverOnline = 'driver:online';
  static const String acceptTrip = 'ACCEPT_TRIP';
  static const String driverLocationUpdate = 'DRIVER_LOCATION_UPDATE';
  static const String startTrip = 'START_TRIP';
  static const String endTrip = 'END_TRIP';

  // Listens
  static const String driverOnlineSuccess = 'driver:online:success';
  static const String rideBooked = 'RIDE_BOOKED';
  static const String newTripRequest = 'NEW_TRIP_REQUEST';
  static const String tripAccepted = 'TRIP_ACCEPTED';
  static const String driverFound = 'DRIVER_FOUND';
  static const String driverRejected = 'DRIVER_REJECTED';
  static const String driverLocation = 'DRIVER_LOCATION';
  static const String driverArrived = 'DRIVER_ARRIVED';
  static const String tripStarted = 'TRIP_STARTED';
  static const String tripCompleted = 'TRIP_COMPLETED';
  static const String tripCancelled = 'TRIP_CANCELLED';
  static const String tripCancelledByUser = 'TRIP_CANCELLED_BY_USER';
  static const String noDriverFound = 'NO_DRIVER_FOUND';

  // ==========================================
  // GOODS BOOKING FLOW
  // ==========================================

  // Emits (Driver Side)
  static const String goodsBookingAccept = 'goods:booking:accept';
  static const String goodsDriverArrivedPickup = 'goods:driver:arrived_pickup';
  static const String goodsPickupVerify = 'goods:pickup:verify';
  static const String goodsBookingStart = 'goods:booking:start';
  static const String goodsDeliveryVerify = 'goods:delivery:verify';
  static const String goodsPaymentComplete = 'goods:payment:complete';
  static const String goodsBookingComplete = 'goods:booking:complete';

  // Listens (User Side & Shared)
  static const String goodsCustomerBookingCreated =
      'goods.customer.booking.created';
  static const String goodsBookingCreated = 'goods.booking.created';
  static const String goodsDriverAssigned = 'goods.driver.assigned';
  static const String goodsBookingCancelled = 'goods.booking.cancelled';
  static const String goodsPickupOtpSent = 'goods.pickup.otp.sent';
  static const String goodsDriverArrived = 'goods.driver.arrived';
  static const String goodsPickupOtpVerified = 'goods.pickup.otp.verified';
  static const String goodsTripStarted = 'goods.trip.started';
  static const String goodsLocationUpdated = 'goods.location.updated';
  static const String goodsDriverReachedDestination =
      'goods.driver.reached.destination';
  static const String goodsDeliveryOtpSent = 'goods.delivery.otp.sent';
  static const String goodsDeliveryOtpVerified = 'goods.delivery.otp.verified';
  static const String goodsTripEnded = 'goods.trip.ended';
  static const String goodsPaymentCompleted = 'goods.payment.completed';
  static const String goodsCompleted = 'goods.completed';
}
