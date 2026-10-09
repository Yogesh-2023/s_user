class SavedAddressModel {
  final String id;
  final String label;
  final String addressLine;
  final double latitude;
  final double longitude;
  final String? landmark;
  final String? city;
  final String? state;
  final String? postalCode;
  final bool isDefault;

  SavedAddressModel({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    this.landmark,
    this.city,
    this.state,
    this.postalCode,
    this.isDefault = false,
  });

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return SavedAddressModel(
      id: json['addressId']?.toString() ?? json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Saved Address',
      addressLine: json['addressLine']?.toString() ?? json['address']?.toString() ?? '',
      latitude: parseDouble(json['latitude'] ?? json['lat']),
      longitude: parseDouble(json['longitude'] ?? json['lng']),
      landmark: json['landmark']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      postalCode: json['postalCode']?.toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'addressLine': addressLine,
      'latitude': latitude,
      'longitude': longitude,
      if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (state != null && state!.isNotEmpty) 'state': state,
      if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
      'isDefault': isDefault,
    };
  }
}
