import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/api/api_constants.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_client.dart';

class TicketService {
  String? lastErrorMessage;

  /// GET /customer/support/categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.supportCategories}');
      final response = await http.get(uri, headers: await _headers());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final raw = decoded is Map ? (decoded['data'] ?? decoded['items'] ?? decoded) : decoded;
        if (raw is List) {
          return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
    } catch (e) {
      print('Get categories error: $e');
    }
    return [];
  }

  /// Upload Attachment (POST /customer/support/attachments)
  /// Multipart file field 'attachment', max size ≤ 5 MB
  Future<Map<String, dynamic>?> uploadAttachment(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final length = await file.length();
      if (length > 5 * 1024 * 1024) {
        print('Upload attachment error: File exceeds max 5 MB limit');
        return {'error': 'File size exceeds 5 MB limit'};
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.supportAttachments}');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(await ApiClient.authHeaders(includeContentType: false));

      final ext = filePath.split('.').last.toLowerCase();
      MediaType mediaType = MediaType('image', 'jpeg');
      if (ext == 'png') mediaType = MediaType('image', 'png');
      else if (ext == 'webp') mediaType = MediaType('image', 'webp');
      else if (ext == 'pdf') mediaType = MediaType('application', 'pdf');

      request.files.add(
        await http.MultipartFile.fromPath(
          'attachment',
          filePath,
          contentType: mediaType,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : decoded;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      print('Upload attachment error: $e');
    }
    return null;
  }

  bool _isValidUuid(String? str) {
    if (str == null || str.trim().isEmpty) return false;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str.trim());
  }

  /// POST /customer/support/tickets
  Future<Map<String, dynamic>?> raiseTicket({
    required String subject,
    required String description,
    String? categoryId,
    String? bookingId,
    List<Map<String, dynamic>>? attachments,
  }) async {
    lastErrorMessage = null;
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.tickets}');
      final payload = <String, dynamic>{
        'subject': subject.trim(),
        'description': description.trim(),
        if (_isValidUuid(categoryId)) 'categoryId': categoryId,
        if (_isValidUuid(bookingId)) 'bookingId': bookingId,
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
      };

      final response = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode(payload),
      );

      print('APP LOG: Raise Ticket status -> ${response.statusCode}, body -> ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : decoded;
        if (data is Map) return Map<String, dynamic>.from(data);
      } else if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          if (decoded['errors'] is List && (decoded['errors'] as List).isNotEmpty) {
            final first = (decoded['errors'] as List).first;
            if (first is Map && first['message'] != null) {
              final path = (first['path'] as List?)?.join('.') ?? '';
              lastErrorMessage = path.isNotEmpty ? '$path: ${first['message']}' : first['message'].toString();
            }
          }
          lastErrorMessage ??= decoded['message']?.toString() ?? decoded['error']?.toString();
        }
      }
    } catch (e) {
      print('Raise ticket error: $e');
      lastErrorMessage = e.toString();
    }
    return null;
  }

  /// GET /customer/support/tickets?page=1&limit=20
  Future<Map<String, dynamic>?> getTickets({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.tickets}').replace(
        queryParameters: {
          'page': '$page',
          'limit': '$limit',
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

      final response = await http.get(uri, headers: await _headers());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'];
          final meta = decoded['meta'] ?? {};
          List items = [];
          if (data is List) items = data;
          else if (data is Map) items = (data['tickets'] ?? data['items'] ?? []) as List;
          return {
            'items': items,
            'meta': meta,
          };
        }
      }
    } catch (e) {
      print('Get tickets error: $e');
    }
    return null;
  }

  /// GET /customer/support/tickets/:ticketId
  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.ticket(ticketId)}');
      final response = await http.get(uri, headers: await _headers());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : decoded;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      print('Get ticket detail error: $e');
    }
    return null;
  }

  /// POST /customer/support/tickets/:ticketId/messages
  Future<Map<String, dynamic>?> sendMessage({
    required String ticketId,
    required String message,
    List<Map<String, dynamic>>? attachments,
    String? attachmentUrl,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.ticketMessages(ticketId)}');
      final payload = <String, dynamic>{
        'message': message.trim(),
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
        if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
      };

      final response = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 409) {
        return {'error': 'CONFLICT', 'message': 'Ticket is resolved or closed.'};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : decoded;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      print('Send message error: $e');
    }
    return null;
  }

  /// PATCH /customer/support/tickets/:ticketId/messages/read
  Future<bool> markRead(String ticketId) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.ticketMessagesRead(ticketId)}');
      final response = await http.patch(
        uri,
        headers: await _headers(),
        body: jsonEncode({}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Mark read error: $e');
      return false;
    }
  }

  /// POST /customer/support/tickets/:ticketId/close
  Future<bool> closeTicket(String ticketId) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiEndpoints.ticketClose(ticketId)}');
      final response = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode({}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Close ticket error: $e');
      return false;
    }
  }

  Future<Map<String, String>> _headers({bool contentType = true}) async {
    return ApiClient.authHeaders(includeContentType: contentType);
  }
}
