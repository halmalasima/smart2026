// lib/services/ai_api_service.dart
// خدمة للتواصل مع API المساعد الذكي في Django

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class AIApiService {
  String? _accessToken;

  /// تعيين رمز الوصول للمصادقة
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// الحصول على رؤوس HTTP مع المصادقة
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// الحصول على استجابة الدردشة من المساعد الذكي
  Future<Map<String, dynamic>> getChatResponse(
    String query,
    List<Map<String, String>> conversationHistory,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiChatEndpoint}');
    try {
      final response = await http
          .post(
            url,
            headers: _headers,
            body: json.encode({
              'user_query': query,  // Use user_query for new API
              'conversation_history': conversationHistory,
            }),
          )
          .timeout(const Duration(seconds: 120)); // طول المهلة لاستجابات AI

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        // Normalize response: support both ai_response (new) and response (legacy)
        if (responseData.containsKey('ai_response')) {
          return responseData;
        } else if (responseData.containsKey('response')) {
          // Convert legacy format to new format
          return {
            'ai_response': responseData['response'],
            'conversation_history': responseData['conversation_history'] ?? [],
            'source_documents': responseData['source_documents'] ?? [],
            'suggested_questions': responseData['suggested_questions'] ?? [],
          };
        }
        return responseData;
      } else {
        debugPrint(
            'Error getting chat response: ${response.statusCode} ${response.body}');
        throw Exception('فشل في الحصول على استجابة: ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception during chat response: $e');
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        throw Exception(
            'انتهت مهلة الاتصال بخدمة الذكاء الاصطناعي. يرجى المحاولة مرة أخرى.');
      }
      throw Exception('فشل الاتصال بخدمة الذكاء الاصطناعي: $e');
    }
  }

  /// رفع المستندات القانونية إلى محرك RAG عبر Django
  Future<Map<String, dynamic>> uploadLegalDocuments(
    List<http.MultipartFile> files,
  ) async {
    final url =
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiDocumentsAddEndpoint}');
    var request = http.MultipartRequest('POST', url);

    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    request.files.addAll(files);

    try {
      var response = await request.send().timeout(const Duration(seconds: 120));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        debugPrint(
            'Error uploading documents: ${response.statusCode} $responseBody');
        throw Exception('فشل في رفع المستندات: $responseBody');
      }
    } catch (e) {
      debugPrint('Exception during document upload: $e');
      throw Exception('فشل الاتصال بخدمة رفع المستندات: $e');
    }
  }

  /// حذف المستندات القانونية من محرك RAG عبر Django
  Future<Map<String, dynamic>> deleteLegalDocuments(String source) async {
    final url =
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiDocumentsDeleteEndpoint}');
    try {
      final response = await http
          .delete(
            url,
            headers: _headers,
            body: json.encode({'source': source}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
            'Error deleting documents: ${response.statusCode} ${response.body}');
        throw Exception('فشل في حذف المستندات: ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception during document deletion: $e');
      throw Exception('فشل الاتصال بخدمة حذف المستندات: $e');
    }
  }

  // ========== Chat History & Conversations ==========

  /// Get all conversations for the current user
  Future<List<Map<String, dynamic>>> getConversations({bool? archived}) async {
    String url = '${ApiConfig.baseUrl}${ApiConfig.aiConversationsEndpoint}';
    if (archived != null) {
      url += '?is_archived=$archived';
    }
    
    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) return List<Map<String, dynamic>>.from(data);
        if (data is Map && data.containsKey('results')) {
          return List<Map<String, dynamic>>.from(data['results']);
        }
        return [];
      }
      throw Exception('فشل في جلب المحادثات');
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      return [];
    }
  }

  /// Create a new conversation
  Future<Map<String, dynamic>> createConversation(String title) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiConversationsEndpoint}');
    final response = await http.post(
      url,
      headers: _headers,
      body: json.encode({'title': title}),
    );
    if (response.statusCode == 201) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('فشل في إنشاء محادثة جديدة');
  }

  /// Update a conversation (title, archived, favorite)
  Future<Map<String, dynamic>> updateConversation(int id, Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiConversationsEndpoint}$id/');
    final response = await http.patch(
      url,
      headers: _headers,
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('فشل في تحديث المحادثة');
  }

  /// Delete a conversation
  Future<void> deleteConversation(int id) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiConversationsEndpoint}$id/');
    final response = await http.delete(url, headers: _headers);
    if (response.statusCode != 204) {
      throw Exception('فشل في حذف المحادثة');
    }
  }

  /// Get messages for a specific conversation
  Future<List<Map<String, dynamic>>> getConversationMessages(int conversationId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiConversationsEndpoint}$conversationId/messages/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) return List<Map<String, dynamic>>.from(data);
        return [];
      }
      throw Exception('فشل في جلب رسائل المحادثة');
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Save a chat log (message pair)
  Future<Map<String, dynamic>> saveChatLog({
    required int conversationId,
    required String question,
    required String answer,
    String? modelVersion,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiChatLogsEndpoint}');
    final response = await http.post(
      url,
      headers: _headers,
      body: json.encode({
        'conversation': conversationId,
        'question': question,
        'answer': answer,
        'model_version': modelVersion ?? 'llama-3.3-70b',
      }),
    );
    if (response.statusCode == 201) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('فشل في حفظ سجل المحادثة');
  }
}
