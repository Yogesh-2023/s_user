import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_location_model.dart';

class RecentLocationService {
  static const String _storageKey = 'recent_dropoff_locations';
  static const int maxRecentCount = 5;

  /// Retrieves stored recent drop-off locations (max 5, newest first).
  Future<List<RecentLocationModel>> getRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.trim().isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      final List<RecentLocationModel> locations = jsonList
          .whereType<Map<String, dynamic>>()
          .map((item) => RecentLocationModel.fromJson(item))
          .toList();

      // Sort by timestamp descending (newest first) and limit to 5
      locations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return locations.take(maxRecentCount).toList();
    } catch (e) {
      debugPrint('[RECENT_LOCATION_SERVICE] Error reading recent locations: $e');
      return [];
    }
  }

  /// Adds or updates a recent drop-off location.
  /// Deduplicates existing matches, moves to top, and caps list at 5 items.
  Future<List<RecentLocationModel>> addRecentLocation(
    RecentLocationModel newLocation,
  ) async {
    try {
      final List<RecentLocationModel> currentList = await getRecentLocations();

      // Remove existing location if duplicate
      currentList.removeWhere((item) => item.isSameLocation(newLocation));

      // Create an updated instance with fresh timestamp
      final RecentLocationModel updatedLocation = RecentLocationModel(
        title: newLocation.title,
        address: newLocation.address,
        latitude: newLocation.latitude,
        longitude: newLocation.longitude,
        placeId: newLocation.placeId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Insert at top (index 0)
      currentList.insert(0, updatedLocation);

      // Enforce max 5 limit
      final List<RecentLocationModel> trimmedList =
          currentList.take(maxRecentCount).toList();

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        trimmedList.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encoded);

      return trimmedList;
    } catch (e) {
      debugPrint('[RECENT_LOCATION_SERVICE] Error adding recent location: $e');
      return await getRecentLocations();
    }
  }

  /// Clears stored recent locations if ever needed.
  Future<void> clearRecentLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('[RECENT_LOCATION_SERVICE] Error clearing recent locations: $e');
    }
  }
}
