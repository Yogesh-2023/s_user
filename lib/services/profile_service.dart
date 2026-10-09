import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/api/api_service.dart';
import '../../core/api/api_constants.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/api_client.dart';
import '../models/user_profile.dart';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  Future<UserProfile?> getMyProfile() async {
    try {
      final response = await ApiService.to.get(ApiEndpoints.profileMe);
      if (response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final payload = data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : Map<String, dynamic>.from(data);
          final user = payload['user'] is Map
              ? Map<String, dynamic>.from(payload['user'] as Map)
              : const <String, dynamic>{};
          final profile = payload['profile'] is Map
              ? Map<String, dynamic>.from(payload['profile'] as Map)
              : const <String, dynamic>{};

          return UserProfile.fromJson({...user, ...profile, ...payload});
        }
      }
    } catch (e) {
      print('Error getting profile: $e');
    }
    return null;
  }

  Future<UserProfile?> _multipartRequest({
    required String method,
    required String endpoint,
    required Map<String, String> fields,
    String? avatarPath,
    String? fileKey,
  }) async {
    try {
      // Refresh the server session first; this also captures a rotated cookie
      // or CSRF token before the protected multipart mutation.
      try {
        await ApiService.to.get(ApiEndpoints.authSession);
      } catch (_) {}
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest(method, uri);

      request.headers.addAll(
        await ApiClient.authHeaders(includeContentType: false),
      );

      // Add form fields
      request.fields.addAll(_profileFields(fields));

      // Add avatar file if available
      if (avatarPath != null && avatarPath.isNotEmpty) {
        final key = fileKey ?? 'avatar';
        final extension = avatarPath.split('.').last.toLowerCase();

        MediaType? contentType;
        if (extension == 'jpg' || extension == 'jpeg') {
          contentType = MediaType('image', 'jpeg');
        } else if (extension == 'png') {
          contentType = MediaType('image', 'png');
        } else if (extension == 'pdf') {
          contentType = MediaType('application', 'pdf');
        } else {
          // Fallback to jpeg
          contentType = MediaType('image', 'jpeg');
        }

        final filename = avatarPath.split('/').last;

        request.files.add(
          await http.MultipartFile.fromPath(
            key,
            avatarPath,
            filename: filename,
            contentType: contentType,
          ),
        );
      }

      print('APP LOG: Multipart $method Request to -> $uri');
      print('APP LOG: Multipart Request Fields -> $fields');
      print(
        'APP LOG: Multipart auth -> '
        'cookie=${request.headers.containsKey('Cookie')}, '
        'bearer=${request.headers.containsKey('Authorization')}, '
        'csrf=${request.headers.containsKey('x-csrf-token')}',
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(
        'APP LOG: Multipart Response Status Code -> ${response.statusCode}',
      );
      print('APP LOG: Multipart Response Body -> ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody is Map) {
          final data = jsonBody['data'] ?? jsonBody;
          if (data != null) {
            return UserProfile.fromJson(Map<String, dynamic>.from(data));
          }
        }
      } else {
        print(
          'Multipart request failed: ${response.statusCode} - ${response.body}',
        );
        dynamic body;
        try {
          if (response.body.isNotEmpty) {
            body = jsonDecode(response.body);
          }
        } catch (_) {}

        String message = 'Failed to save profile';
        if (body is Map<String, dynamic>) {
          message = body['message'] ?? body['error'] ?? message;
        }

        throw ApiException(
          message: message,
          statusCode: response.statusCode,
          responseBody: body,
        );
      }
    } catch (e) {
      print('Multipart request error: $e');
      rethrow;
    }
    return null;
  }

  Map<String, String> _profileFields(Map<String, String> fields) {
    final fullName =
        fields['fullName'] ??
        fields['name'] ??
        '${fields['firstname'] ?? ''} ${fields['lastname'] ?? ''}'.trim();
    return {
      'fullName': fullName,
      if ((fields['email'] ?? '').isNotEmpty) 'email': fields['email']!,
      if ((fields['dob'] ?? fields['dateOfBirth'] ?? '').isNotEmpty)
        'dateOfBirth': fields['dateOfBirth'] ?? fields['dob']!,
      if ((fields['gender'] ?? '').isNotEmpty)
        'gender': fields['gender']!.toUpperCase(),
      'preferredLanguage': fields['preferredLanguage'] ?? 'en',
    };
  }

  Future<UserProfile?> createProfile({
    required Map<String, String> fields,
    String? avatarPath,
  }) async {
    try {
      return await _multipartRequest(
        method: 'POST',
        endpoint: ApiEndpoints.profileCreate,
        fields: fields,
        avatarPath: avatarPath,
        fileKey: 'profileImage',
      );
    } catch (e) {
      if (e is ApiException && (e.statusCode == 409 || (e.statusCode == 400 && e.message.toLowerCase().contains('already exists')))) {
        print('Profile creation conflict (409/400), attempting updateProfile as fallback');
        return updateProfile(fields: fields, avatarPath: avatarPath);
      }
      rethrow;
    }
  }

  Future<UserProfile?> updateProfile({
    required Map<String, String> fields,
    String? avatarPath,
  }) async {
    return _multipartRequest(
      method: 'PATCH',
      endpoint: ApiEndpoints.profileUpdate,
      fields: fields,
      avatarPath: avatarPath,
      fileKey: 'profileImage',
    );
  }

  Future<String?> uploadProfileImageFile(XFile imageFile) async {
    final filename = imageFile.name.toLowerCase();
    final ext = filename.contains('.') ? filename.split('.').last : '';
    final isJpeg = ext == 'jpg' || ext == 'jpeg' || imageFile.mimeType == 'image/jpeg';
    final isPng = ext == 'png' || imageFile.mimeType == 'image/png';

    if (!isJpeg && !isPng) {
      throw ApiException(
        message: 'Image must be JPEG or PNG',
        statusCode: 400,
      );
    }

    final bytes = await imageFile.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw ApiException(
        message: 'Max size 5 MB',
        statusCode: 400,
      );
    }

    try {
      try {
        await ApiService.to.get(ApiEndpoints.authSession);
      } catch (_) {}

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.profileImage}');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(
        await ApiClient.authHeaders(includeContentType: false),
      );

      final contentType = isPng ? MediaType('image', 'png') : MediaType('image', 'jpeg');
      final uploadFilename = isPng ? 'profile.png' : 'profile.jpg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'profileImage',
          bytes,
          filename: uploadFilename,
          contentType: contentType,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody is Map) {
          final data = jsonBody['data'] ?? jsonBody;
          if (data is Map) {
            final imageUrl = (data['profileImageUrl'] ?? data['profileImage'] ?? data['avatar'])?.toString();
            if (imageUrl != null && imageUrl.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_avatar', imageUrl);
              return imageUrl;
            }
          }
        }
        return null;
      } else {
        dynamic body;
        try {
          if (response.body.isNotEmpty) {
            body = jsonDecode(response.body);
          }
        } catch (_) {}

        String message = 'Failed to upload profile image';
        if (body is Map<String, dynamic>) {
          message = body['message'] ?? body['error'] ?? message;
        }

        throw ApiException(
          message: message,
          statusCode: response.statusCode,
          responseBody: body,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString(), statusCode: 0);
    }
  }

  Future<String?> uploadProfileImage({
    required String imagePath,
  }) async {
    return uploadProfileImageFile(XFile(imagePath));
  }

  Future<bool> deleteProfileImage() async {
    try {
      final response = await ApiService.to.delete(ApiEndpoints.profileImage);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_avatar');
        return true;
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString(), statusCode: 0);
    }
    return false;
  }
}
