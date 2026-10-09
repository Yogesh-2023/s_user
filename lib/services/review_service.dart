import 'package:get/get.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_service.dart';

class ReviewService extends GetxService {
  final ApiService _apiService = ApiService.to;

  Future<bool> submitReview({
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    try {
      final cleanComment = comment?.trim();
      final body = <String, dynamic>{
        'score': rating.round().clamp(1, 5),
      };
      if (cleanComment != null && cleanComment.isNotEmpty) {
        body['comment'] = cleanComment;
      }

      final response = await _apiService.post(
        ApiEndpoints.bookingRating(bookingId),
        body: body,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error submitting review: $e');
      return false;
    }
  }

  Future<List<dynamic>?> getBookingReviews(String bookingId) async {
    try {
      final response = await _apiService.get(
        ApiEndpoints.getBookingReview(bookingId),
      );
      if (response.statusCode == 200) {
        return response.data['data'] ?? response.data;
      }
      return null;
    } catch (e) {
      print('Error getting booking reviews: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getAllMyReviews() async {
    try {
      final response = await _apiService.get(ApiEndpoints.allUserReviews);
      if (response.statusCode == 200) {
        return response.data['data'] ?? response.data;
      }
      return null;
    } catch (e) {
      print('Error getting all reviews: $e');
      return null;
    }
  }
}
