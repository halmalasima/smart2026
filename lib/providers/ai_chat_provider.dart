// lib/providers/ai_chat_provider.dart
// مزود الحالة لإدارة واجهة الدردشة مع المساعد الذكي

import 'package:flutter/material.dart';
import '../services/ai_api_service.dart';

class AIChatProvider with ChangeNotifier {
  final AIApiService _apiService = AIApiService();
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, String>> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// الوصول إلى خدمة API (للاستخدام من شاشات أخرى مثل تحليل القضايا)
  AIApiService get apiService => _apiService;

  AIChatProvider() {
    // رسالة الترحيب الأولية
    _messages.add({
      'role': 'assistant',
      'content': 'مرحبًا بك في مساعدك القانوني الذكي. كيف يمكنني مساعدتك اليوم؟',
    });
  }

  /// تعيين رمز الوصول للمصادقة
  void setAccessToken(String? token) {
    _apiService.setAccessToken(token);
  }

  /// إرسال رسالة المستخدم والحصول على استجابة المساعد
  Future<void> sendMessage(String query) async {
    _messages.add({'role': 'user', 'content': query});
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // إرسال سجل المحادثة بدون رسالة الترحيب الأولى
      final history = _messages
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
          .skip(1) // تخطي رسالة الترحيب
          .toList();

      // إزالة آخر رسالة للمستخدم من السجل (لأنها ستُرسل كـ query)
      if (history.isNotEmpty) {
        history.removeLast();
      }

      final response = await _apiService.getChatResponse(query, history);
      final aiResponse = response['ai_response'] ?? response['response'] ?? 'لم يتم الحصول على استجابة.';
      _messages.add({'role': 'assistant', 'content': aiResponse});
    } catch (e) {
      _errorMessage = 'فشل في الحصول على استجابة: $e';
      _messages.add({
        'role': 'assistant',
        'content': 'عذرًا، حدث خطأ أثناء معالجة طلبك. يرجى المحاولة مرة أخرى.',
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// مسح سجل الدردشة
  void clearChat() {
    _messages = [
      {
        'role': 'assistant',
        'content': 'مرحبًا بك في مساعدك القانوني الذكي. كيف يمكنني مساعدتك اليوم؟',
      }
    ];
    _errorMessage = null;
    notifyListeners();
  }
}
