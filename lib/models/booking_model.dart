import '../core/utils.dart';

enum RideType {
  oneWay,
  returnTrip,
}

enum TripLeg {
  outbound,
  returnTrip,
}

class FareBreakdown {
  final double outbound;
  final double returnFare;
  final double total;
  final String currency;

  FareBreakdown({
    required this.outbound,
    required this.returnFare,
    required this.total,
    this.currency = 'INR',
  });

  factory FareBreakdown.fromMap(dynamic json) {
    if (json is! Map) {
      return FareBreakdown(outbound: 0.0, returnFare: 0.0, total: 0.0);
    }
    final map = Map<String, dynamic>.from(json);
    final outbound = AppUtils.parseDouble(map['outbound']) ??
        AppUtils.parseDouble(map['subtotal']) ??
        AppUtils.parseDouble(map['estimatedFare']) ??
        0.0;
    final returnFare = AppUtils.parseDouble(map['return']) ??
        AppUtils.parseDouble(map['returnFare']) ??
        outbound;
    final total = AppUtils.parseDouble(map['total']) ??
        AppUtils.parseDouble(map['totalFare']) ??
        (outbound + returnFare);
    final currency = (map['currency'] ?? 'INR').toString();

    return FareBreakdown(
      outbound: outbound,
      returnFare: returnFare,
      total: total,
      currency: currency,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'outbound': outbound,
      'return': returnFare,
      'total': total,
      'currency': currency,
    };
  }
}

class BookingModel {
  final String id;
  final String status;
  final String? type;
  final String? rideType;
  final String tripType; // "ONE_WAY" or "RETURN"
  final String? tripLeg; // "OUTBOUND" or "RETURN"
  final String? returnBookingId;
  final String? parentBookingId;
  final DateTime? returnDateTime;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final Map<String, dynamic>? pickup;
  final Map<String, dynamic>? drop;
  final FareBreakdown? fare;
  final double? estimatedFare;
  final String? currency;
  final String? paymentMethod;
  final String? categoryId;
  final String? vehicleCategoryName;
  final Map<String, dynamic>? driver;
  final Map<String, dynamic>? returnBooking;

  BookingModel({
    required this.id,
    required this.status,
    this.type,
    this.rideType,
    this.tripType = 'ONE_WAY',
    this.tripLeg,
    this.returnBookingId,
    this.parentBookingId,
    this.returnDateTime,
    this.scheduledAt,
    this.createdAt,
    this.pickup,
    this.drop,
    this.fare,
    this.estimatedFare,
    this.currency = 'INR',
    this.paymentMethod,
    this.categoryId,
    this.vehicleCategoryName,
    this.driver,
    this.returnBooking,
  });

  RideType get parsedRideType => (rideType == 'RETURN' || tripType == 'RETURN')
      ? RideType.returnTrip
      : RideType.oneWay;

  TripLeg get parsedTripLeg => tripLeg == 'RETURN' ? TripLeg.returnTrip : TripLeg.outbound;

  bool get isReturnTrip => parsedRideType == RideType.returnTrip || returnBookingId != null || parentBookingId != null;
  bool get isReturnLeg => parsedTripLeg == TripLeg.returnTrip || parentBookingId != null;
  bool get isOutboundLeg => parsedTripLeg == TripLeg.outbound || returnBookingId != null;

  double get displayTotalFare {
    if (fare != null && fare!.total > 0) {
      return fare!.total;
    }
    if (isReturnTrip && estimatedFare != null) {
      return estimatedFare! * 2;
    }
    return estimatedFare ?? 0.0;
  }

  factory BookingModel.fromMap(dynamic json) {
    if (json is! Map) {
      return BookingModel(id: '', status: 'PENDING');
    }
    final map = Map<String, dynamic>.from(json);

    final String bookingId = (map['bookingId'] ??
            map['id'] ??
            map['_id'] ??
            map['tripId'] ??
            (map['booking'] is Map ? map['booking']['id'] : null) ??
            '')
        .toString();

    final String status = (map['status'] ??
            map['bookingStatus'] ??
            (map['booking'] is Map ? map['booking']['status'] : null) ??
            'PENDING')
        .toString()
        .toUpperCase();

    final String rawRideType = (map['rideType'] ??
            map['tripType'] ??
            (map['booking'] is Map ? map['booking']['rideType'] ?? map['booking']['tripType'] : null) ??
            'ONE_WAY')
        .toString()
        .toUpperCase();

    final String tripType = rawRideType == 'RETURN' ? 'RETURN' : 'ONE_WAY';

    final String? tripLeg = (map['tripLeg'] ??
            (map['booking'] is Map ? map['booking']['tripLeg'] : null))
        ?.toString()
        .toUpperCase();

    final String? returnBookingId = (map['returnBookingId'] ??
            (map['booking'] is Map ? map['booking']['returnBookingId'] : null))
        ?.toString();

    final String? parentBookingId = (map['parentBookingId'] ??
            (map['booking'] is Map ? map['booking']['parentBookingId'] : null))
        ?.toString();

    final rawReturnDate = map['returnDateTime'] ??
        (map['booking'] is Map ? map['booking']['returnDateTime'] : null);
    final DateTime? returnDateTime = rawReturnDate == null
        ? null
        : DateTime.tryParse(rawReturnDate.toString())?.toLocal();

    final rawScheduled = map['scheduledAt'] ??
        map['scheduledDateTime'] ??
        (map['booking'] is Map ? map['booking']['scheduledAt'] : null);
    final DateTime? scheduledAt = rawScheduled == null
        ? null
        : DateTime.tryParse(rawScheduled.toString())?.toLocal();

    final rawCreated = map['createdAt'] ??
        (map['booking'] is Map ? map['booking']['createdAt'] : null);
    final DateTime? createdAt = rawCreated == null
        ? null
        : DateTime.tryParse(rawCreated.toString())?.toLocal();

    final pickup = map['pickup'] is Map
        ? Map<String, dynamic>.from(map['pickup'])
        : (map['booking'] is Map && map['booking']['pickup'] is Map
            ? Map<String, dynamic>.from(map['booking']['pickup'])
            : null);

    final drop = map['drop'] is Map
        ? Map<String, dynamic>.from(map['drop'])
        : (map['booking'] is Map && map['booking']['drop'] is Map
            ? Map<String, dynamic>.from(map['booking']['drop'])
            : null);

    FareBreakdown? fare;
    if (map['fare'] != null) {
      fare = FareBreakdown.fromMap(map['fare']);
    } else if (map['booking'] is Map && map['booking']['fare'] != null) {
      fare = FareBreakdown.fromMap(map['booking']['fare']);
    }

    final double? estimatedFare = AppUtils.parseDouble(map['estimatedFare']) ??
        AppUtils.parseDouble(map['totalFare']) ??
        AppUtils.parseDouble(map['total']) ??
        (map['booking'] is Map
            ? AppUtils.parseDouble(map['booking']['estimatedFare'])
            : null);

    final String? paymentMethod = (map['paymentMethod'] ??
            (map['booking'] is Map ? map['booking']['paymentMethod'] : null))
        ?.toString();

    final String? categoryId = (map['categoryId'] ??
            map['vehicleCategoryId'] ??
            (map['booking'] is Map ? map['booking']['categoryId'] : null))
        ?.toString();

    final driver = map['driver'] is Map
        ? Map<String, dynamic>.from(map['driver'])
        : (map['assignedDriver'] is Map
            ? Map<String, dynamic>.from(map['assignedDriver'])
            : null);

    final returnBooking = map['returnBooking'] is Map
        ? Map<String, dynamic>.from(map['returnBooking'])
        : null;

    return BookingModel(
      id: bookingId,
      status: status,
      type: (map['type'] ?? (map['booking'] is Map ? map['booking']['type'] : null))?.toString(),
      rideType: rawRideType,
      tripType: tripType,
      tripLeg: tripLeg ?? (returnBookingId != null ? 'OUTBOUND' : (parentBookingId != null ? 'RETURN' : 'OUTBOUND')),
      returnBookingId: returnBookingId,
      parentBookingId: parentBookingId,
      returnDateTime: returnDateTime,
      scheduledAt: scheduledAt,
      createdAt: createdAt,
      pickup: pickup,
      drop: drop,
      fare: fare,
      estimatedFare: estimatedFare,
      currency: (map['currency'] ?? 'INR').toString(),
      paymentMethod: paymentMethod,
      categoryId: categoryId,
      vehicleCategoryName: map['vehicleCategoryName']?.toString(),
      driver: driver,
      returnBooking: returnBooking,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': id,
      'status': status,
      'type': type,
      'rideType': rideType,
      'tripType': tripType,
      'tripLeg': tripLeg,
      'returnBookingId': returnBookingId,
      'parentBookingId': parentBookingId,
      'returnDateTime': returnDateTime?.toUtc().toIso8601String(),
      'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'pickup': pickup,
      'drop': drop,
      'fare': fare?.toMap(),
      'estimatedFare': estimatedFare,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'categoryId': categoryId,
      'driver': driver,
      'returnBooking': returnBooking,
    };
  }
}

