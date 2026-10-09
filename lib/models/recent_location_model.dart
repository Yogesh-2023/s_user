class RecentLocationModel {
  final String? id;
  final String title;
  final String address;
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? landmark;
  final String? city;
  final String? state;
  final String? postalCode;
  final int timestamp;

  RecentLocationModel({
    this.id,
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.landmark,
    this.city,
    this.state,
    this.postalCode,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory RecentLocationModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseTimestamp(dynamic val, dynamic createdAt, dynamic updatedAt) {
      if (val is int) return val;
      if (val != null) {
        final parsed = int.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
      final dateStr = (updatedAt ?? createdAt)?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        final dt = DateTime.tryParse(dateStr);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
      return DateTime.now().millisecondsSinceEpoch;
    }

    final rawAddress = (json['address'] ?? json['addressLine'] ?? '').toString();
    final rawTitle = (json['label'] ?? json['title'] ?? 'Recent Location').toString();

    return RecentLocationModel(
      id: (json['addressId'] ?? json['id'] ?? json['_id'])?.toString(),
      title: rawTitle.isNotEmpty ? rawTitle : 'Recent Location',
      address: rawAddress,
      latitude: parseDouble(json['latitude'] ?? json['lat']),
      longitude: parseDouble(json['longitude'] ?? json['lng']),
      placeId: json['placeId']?.toString(),
      landmark: json['landmark']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      postalCode: json['postalCode']?.toString(),
      timestamp: parseTimestamp(json['timestamp'], json['createdAt'], json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (placeId != null) 'placeId': placeId,
      if (landmark != null) 'landmark': landmark,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (postalCode != null) 'postalCode': postalCode,
      'timestamp': timestamp,
    };
  }

  /// Checks if another location matches this one (for deduplication).
  bool isSameLocation(RecentLocationModel other) {
    if (placeId != null &&
        placeId!.isNotEmpty &&
        other.placeId != null &&
        other.placeId!.isNotEmpty) {
      if (placeId == other.placeId) return true;
    }

    final double latDiff = (latitude - other.latitude).abs();
    final double lngDiff = (longitude - other.longitude).abs();
    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      return true;
    }

    final String cleanAddr = address.trim().toLowerCase();
    final String cleanOtherAddr = other.address.trim().toLowerCase();
    if (cleanAddr.isNotEmpty && cleanAddr == cleanOtherAddr) {
      return true;
    }

    return false;
  }
}

