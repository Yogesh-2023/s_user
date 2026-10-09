import 'package:flutter/foundation.dart';
import '../core/api/api_service.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';
import '../models/saved_address_model.dart';

class CustomerAddressService {
  /// Fetches saved addresses for the authenticated customer.
  /// Endpoint: GET /api/v1/customer/addresses
  Future<List<SavedAddressModel>> fetchSavedAddresses() async {
    try {
      final response = await ApiService.to.get(ApiEndpoints.addresses);
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> list = response.data['data'] ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map((json) => SavedAddressModel.fromJson(json))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('[ADDRESS_SERVICE] fetchSavedAddresses API error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ADDRESS_SERVICE] fetchSavedAddresses unexpected error: $e');
      return [];
    }
  }

  /// Saves a new address for the authenticated customer.
  /// Endpoint: POST /api/v1/customer/addresses
  Future<SavedAddressModel?> saveAddress({
    required String label,
    required String addressLine,
    required double latitude,
    required double longitude,
    String? landmark,
    String? city,
    String? state,
    String? postalCode,
    bool isDefault = false,
  }) async {
    final body = {
      'label': label,
      'addressLine': addressLine,
      'latitude': latitude,
      'longitude': longitude,
      if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
      if (city != null && city.isNotEmpty) 'city': city,
      if (state != null && state.isNotEmpty) 'state': state,
      if (postalCode != null && postalCode.isNotEmpty) 'postalCode': postalCode,
      'isDefault': isDefault,
    };

    try {
      final response = await ApiService.to.post(
        ApiEndpoints.addresses,
        body: body,
      );

      if (response.data != null && response.data['success'] == true) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data['data'] as Map);
        return SavedAddressModel.fromJson(data);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('[ADDRESS_SERVICE] saveAddress API error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ADDRESS_SERVICE] saveAddress error: $e');
      rethrow;
    }
  }

  /// Updates an existing address for the authenticated customer.
  /// Endpoint: PATCH /api/v1/customer/addresses/:addressId
  Future<SavedAddressModel?> updateAddress({
    required String addressId,
    String? label,
    String? addressLine,
    double? latitude,
    double? longitude,
    String? landmark,
    String? city,
    String? state,
    String? postalCode,
    bool? isDefault,
  }) async {
    if (addressId.isEmpty) return null;

    final body = {
      if (label != null) 'label': label,
      if (addressLine != null) 'addressLine': addressLine,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (landmark != null) 'landmark': landmark,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (postalCode != null) 'postalCode': postalCode,
      if (isDefault != null) 'isDefault': isDefault,
    };

    try {
      final endpoint = ApiEndpoints.address(addressId);
      final response = await ApiService.to.patch(
        endpoint,
        body: body,
      );

      if (response.data != null && response.data['success'] == true) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data['data'] as Map);
        return SavedAddressModel.fromJson(data);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('[ADDRESS_SERVICE] updateAddress API error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ADDRESS_SERVICE] updateAddress error: $e');
      rethrow;
    }
  }

  /// Sets an address as the default address.
  /// Endpoint: PATCH /api/v1/customer/addresses/:addressId/default
  Future<SavedAddressModel?> setDefaultAddress(String addressId) async {
    if (addressId.isEmpty) return null;

    try {
      final endpoint = ApiEndpoints.defaultAddress(addressId);
      final response = await ApiService.to.patch(endpoint);

      if (response.data != null && response.data['success'] == true) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data['data'] as Map);
        return SavedAddressModel.fromJson(data);
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('[ADDRESS_SERVICE] setDefaultAddress API error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ADDRESS_SERVICE] setDefaultAddress error: $e');
      rethrow;
    }
  }

  /// Deletes a saved address by addressId.
  /// Endpoint: DELETE /api/v1/customer/addresses/:addressId
  Future<bool> deleteAddress(String addressId) async {
    if (addressId.isEmpty) return false;

    try {
      final endpoint = ApiEndpoints.address(addressId);
      final response = await ApiService.to.delete(endpoint);

      if (response.data != null && response.data['success'] == true) {
        return true;
      }
      return false;
    } on ApiException catch (e) {
      debugPrint('[ADDRESS_SERVICE] deleteAddress API error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ADDRESS_SERVICE] deleteAddress error: $e');
      rethrow;
    }
  }

  /// Fetches recently completed locations.
  /// Endpoint: GET /api/v1/customer/addresses/recent
  Future<List<Map<String, dynamic>>> fetchRecentAddresses() async {
    try {
      final response = await ApiService.to.get(ApiEndpoints.recentAddresses);
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> list = response.data['data'] ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map((json) => Map<String, dynamic>.from(json))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('[ADDRESS_SERVICE] fetchRecentAddresses API error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[ADDRESS_SERVICE] fetchRecentAddresses unexpected error: $e');
      return [];
    }
  }

  /// Saves a recent address to the API.
  /// Endpoint: POST /api/v1/customer/addresses/recent
  Future<Map<String, dynamic>?> saveRecentAddress({
    required String addressLine,
    required double latitude,
    required double longitude,
    String? label,
    String? landmark,
    String? city,
    String? state,
    String? postalCode,
  }) async {
    final body = {
      'addressLine': addressLine,
      'address': addressLine,
      'latitude': latitude,
      'longitude': longitude,
      if (label != null && label.isNotEmpty) 'label': label,
      if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
      if (city != null && city.isNotEmpty) 'city': city,
      if (state != null && state.isNotEmpty) 'state': state,
      if (postalCode != null && postalCode.isNotEmpty) 'postalCode': postalCode,
    };

    try {
      final response = await ApiService.to.post(
        ApiEndpoints.recentAddresses,
        body: body,
      );

      if (response.data != null && (response.data['success'] == true || response.statusCode == 200 || response.statusCode == 201)) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(response.data['data'] as Map? ?? response.data as Map);
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('[ADDRESS_SERVICE] saveRecentAddress error (non-fatal): $e');
      return null;
    }
  }
}


