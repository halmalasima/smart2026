// lib/providers/chat_provider.dart

import 'package:flutter/material.dart';
import '../services/ai_api_service.dart';

class ChatProvider with ChangeNotifier {
  final AIApiService _apiService = AIApiService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  List<String> _latestSuggestions = [];

  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  List<String> get latestSuggestions => _latestSuggestions;

  ChatProvider() {
    // Initial system message or welcome message
    // رسالة ترحيب أو رسالة نظام أولية
    _messages.add({'role': 'assistant', 'content': 'مرحباً بك في مساعدك القانوني الذكي. كيف يمكنني مساعدتك اليوم؟'});
  }

  void setAccessToken(String? token) {
    _apiService.setAccessToken(token);
  }

  Future<void> sendMessage(String userQuery) async {
    _messages.add({'role': 'user', 'content': userQuery});
    _isLoading = true;
    notifyListeners();

    try {
      // Prepare conversation history for the API call
      // إعداد سجل المحادثة لاستدعاء API
      List<Map<String, String>> historyForApi = _messages
          .where((msg) => msg['role'] != 'system')
          .map((msg) => {
                'role': msg['role'] as String,
                'content': msg['content'] as String,
              })
          .toList();
      
      final response = await _apiService.getChatResponse(
        userQuery,
        historyForApi,
      );

      // Extract ai_response from response (new API) or response (legacy)
      final aiResponse = response['ai_response'] ?? response['response'] ?? 'عذرًا، لم أتمكن من الحصول على استجابة.';
      _messages.add({'role': 'assistant', 'content': aiResponse});
      
      // حفظ الاقتراحات الجديدة
      if (response.containsKey('suggested_questions')) {
        _latestSuggestions = List<String>.from(response['suggested_questions']);
      } else {
        _latestSuggestions = [];
      }

    } catch (e) {
      _messages.add({'role': 'assistant', 'content': 'عذرًا، حدث خطأ: $e'});
      debugPrint('Error sending message: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _messages.clear();
    _messages.add({'role': 'assistant', 'content': 'مرحباً بك في مساعدك القانوني الذكي. كيف يمكنني مساعدتك اليوم؟'});
    notifyListeners();
  }
}
