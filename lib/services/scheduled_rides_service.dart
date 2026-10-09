import 'package:flutter/foundation.dart';
import '../core/api/api_service.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';

class ScheduledRidesResult {
  final List<Map<String, dynamic>> rides;
  final Map<String, dynamic> pagination;

  ScheduledRidesResult({
    required this.rides,
    required this.pagination,
  });

  factory ScheduledRidesResult.fromJson(Map<String, dynamic> json) {
    final rawRides = json['rides'] ?? json['items'] ?? json['scheduledRides'] ?? json['data'] ?? [];
    final List<Map<String, dynamic>> parsedRides = (rawRides is List ? rawRides : [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final rawPagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'])
        : <String, dynamic>{
            'page': 1,
            'limit': 20,
            'total': parsedRides.length,
            'totalPages': 1,
          };

    return ScheduledRidesResult(
      rides: parsedRides,
      pagination: rawPagination,
    );
  }
}

class ScheduledRidesService {
  /// Fetches scheduled rides.
  /// Endpoint: GET /api/v1/customer/scheduled-rides?status=UPCOMING&page=1&limit=20
  Future<ScheduledRidesResult> fetchScheduledRides({
    String status = 'UPCOMING',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiService.to.get(
        ApiEndpoints.scheduledRides,
        queryParameters: {
          'status': status,
          'page': page,
          'limit': limit,
        },
      );

      if (response.data != null) {
        final Map<String, dynamic> data = response.data['data'] is Map
            ? Map<String, dynamic>.from(response.data['data'])
            : response.data is List
                ? {'rides': response.data}
                : Map<String, dynamic>.from(response.data);
        return ScheduledRidesResult.fromJson(data);
      }

      return ScheduledRidesResult(
        rides: [],
        pagination: {'page': 1, 'limit': limit, 'total': 0, 'totalPages': 1},
      );
    } on ApiException catch (e) {
      debugPrint('[SCHEDULED_RIDES] fetchScheduledRides error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[SCHEDULED_RIDES] fetchScheduledRides error: $e');
      return ScheduledRidesResult(
        rides: [],
        pagination: {'page': 1, 'limit': limit, 'total': 0, 'totalPages': 1},
      );
    }
  }

  /// Gets details of a specific scheduled ride.
  /// Endpoint: GET /api/v1/customer/scheduled-rides/:scheduleId
  Future<Map<String, dynamic>?> getScheduledRide(String scheduleId) async {
    if (scheduleId.isEmpty) return null;

    try {
      final endpoint = ApiEndpoints.scheduledRide(scheduleId);
      final response = await ApiService.to.get(endpoint);

      if (response.data != null) {
        final Map<String, dynamic> data = response.data['data'] is Map
            ? Map<String, dynamic>.from(response.data['data'])
            : Map<String, dynamic>.from(response.data);
        return data;
      }
      return null;
    } on ApiException catch (e) {
      debugPrint('[SCHEDULED_RIDES] getScheduledRide error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[SCHEDULED_RIDES] getScheduledRide error: $e');
      rethrow;
    }
  }

  /// Reschedules a scheduled ride.
  /// Endpoint: PATCH /api/v1/customer/scheduled-rides/:scheduleId
  Future<bool> rescheduleRide({
    required String scheduleId,
    required DateTime scheduledAt,
  }) async {
    if (scheduleId.isEmpty) return false;

    try {
      final endpoint = ApiEndpoints.scheduledRide(scheduleId);
      final response = await ApiService.to.patch(
        endpoint,
        body: {'scheduledAt': scheduledAt.toUtc().toIso8601String()},
      );

      return response.data != null && response.data['success'] != false;
    } on ApiException catch (e) {
      debugPrint('[SCHEDULED_RIDES] rescheduleRide error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[SCHEDULED_RIDES] rescheduleRide error: $e');
      rethrow;
    }
  }

  /// Cancels a scheduled ride.
  /// Endpoint: DELETE /api/v1/customer/scheduled-rides/:scheduleId
  Future<bool> cancelScheduledRide({
    required String scheduleId,
    String reasonCode = 'USER_CANCELLED',
    String? reason,
  }) async {
    if (scheduleId.isEmpty) return false;

    try {
      final endpoint = ApiEndpoints.scheduledRide(scheduleId);
      final response = await ApiService.to.delete(
        endpoint,
        body: {
          'reasonCode': reasonCode,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );

      return response.data != null && response.data['success'] != false;
    } on ApiException catch (e) {
      debugPrint('[SCHEDULED_RIDES] cancelScheduledRide error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[SCHEDULED_RIDES] cancelScheduledRide error: $e');
      rethrow;
    }
  }
}
