import 'package:flutter/foundation.dart';
import '../core/api/api_service.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';
import '../core/api/api_response.dart';
import '../core/utils.dart';

class TripHistoryResult {
  final List<Map<String, dynamic>> trips;
  final Map<String, dynamic> pagination;
  final Map<String, int> counts;

  TripHistoryResult({
    required this.trips,
    required this.pagination,
    required this.counts,
  });

  factory TripHistoryResult.fromJson(Map<String, dynamic> json) {
    final rawTrips = json['trips'] ?? json['items'] ?? json['data'] ?? [];
    final List<Map<String, dynamic>> parsedTrips = (rawTrips is List ? rawTrips : [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final rawPagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'])
        : <String, dynamic>{};

    final rawCounts = json['counts'] is Map
        ? Map<String, dynamic>.from(json['counts'])
        : <String, dynamic>{};

    final pagination = {
      'page': AppUtils.parseInt(rawPagination['page']) ?? 1,
      'limit': AppUtils.parseInt(rawPagination['limit']) ?? 20,
      'total': AppUtils.parseInt(rawPagination['total']) ?? parsedTrips.length,
      'totalPages': AppUtils.parseInt(rawPagination['totalPages']) ?? 1,
    };

    final counts = {
      'all': AppUtils.parseInt(rawCounts['all']) ?? 0,
      'accepted': AppUtils.parseInt(rawCounts['accepted']) ?? 0,
      'ongoing': AppUtils.parseInt(rawCounts['ongoing']) ?? 0,
      'completed': AppUtils.parseInt(rawCounts['completed']) ?? 0,
      'cancelled': AppUtils.parseInt(rawCounts['cancelled']) ?? 0,
      'noShow': AppUtils.parseInt(rawCounts['noShow']) ?? 0,
    };

    return TripHistoryResult(
      trips: parsedTrips,
      pagination: pagination,
      counts: counts,
    );
  }
}

class TripHistoryService {
  /// Fetches trip history for customer.
  /// Endpoint: GET /api/v1/customer/trips
  Future<TripHistoryResult> fetchTrips({
    String status = 'COMPLETED',
    int page = 1,
    int limit = 20,
    String order = 'desc',
    String? dateFrom,
    String? dateTo,
    String? search,
    String? vehicleCategoryId,
  }) async {
    final queryParams = <String, dynamic>{
      'status': status,
      'page': page,
      'limit': limit,
      'order': order,
      if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      if (search != null && search.isNotEmpty) 'search': search,
      if (vehicleCategoryId != null && vehicleCategoryId.isNotEmpty)
        'vehicleCategoryId': vehicleCategoryId,
    };

    try {
      ApiResponse<dynamic> response;
      try {
        response = await ApiService.to.get(
          ApiEndpoints.bookings,
          queryParameters: queryParams,
        );
      } catch (_) {
        response = await ApiService.to.get(
          ApiEndpoints.trips,
          queryParameters: queryParams,
        );
      }

      if (response.data != null) {
        final raw = response.data;
        final Map<String, dynamic> data;
        if (raw is Map<String, dynamic>) {
          if (raw['data'] is Map) {
            data = Map<String, dynamic>.from(raw['data']);
          } else if (raw['data'] is List) {
            data = {'trips': raw['data']};
          } else {
            data = Map<String, dynamic>.from(raw);
          }
        } else {
          data = {'trips': []};
        }
        return TripHistoryResult.fromJson(data);
      }

      return TripHistoryResult(
        trips: [],
        pagination: {'page': 1, 'limit': limit, 'total': 0, 'totalPages': 1},
        counts: {'all': 0, 'accepted': 0, 'ongoing': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0},
      );
    } on ApiException catch (e) {
      debugPrint('[TRIP_HISTORY] fetchTrips API error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[TRIP_HISTORY] fetchTrips error: $e');
      return TripHistoryResult(
        trips: [],
        pagination: {'page': 1, 'limit': limit, 'total': 0, 'totalPages': 1},
        counts: {'all': 0, 'accepted': 0, 'ongoing': 0, 'completed': 0, 'cancelled': 0, 'noShow': 0},
      );
    }
  }
}

