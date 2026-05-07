import 'package:flutter/material.dart';
import '../services/ai_api_service.dart';
import '../models/ai_conversation_model.dart';

class AIChatProvider with ChangeNotifier {
  final AIApiService _apiService = AIApiService();
  List<Map<String, String>> _messages = [];
  List<AIConversationModel> _conversations = [];
  AIConversationModel? _currentConversation;
  
  bool _isLoading = false;
  bool _isConversationsLoading = false;
  String? _errorMessage;

  List<Map<String, String>> get messages => _messages;
  List<AIConversationModel> get conversations => _filteredQuery.isEmpty ? _conversations : _filteredConversations;
  AIConversationModel? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isConversationsLoading => _isConversationsLoading;
  bool get isLoadingHistory => _isConversationsLoading;
  String? get errorMessage => _errorMessage;

  String _filteredQuery = '';
  List<AIConversationModel> _filteredConversations = [];

  void searchConversations(String query) {
    _filteredQuery = query.trim();
    if (_filteredQuery.isEmpty) {
      _filteredConversations = [];
    } else {
      _filteredConversations = _conversations
          .where((c) => c.title.contains(_filteredQuery))
          .toList();
    }
    notifyListeners();
  }

  AIChatProvider() {
    _setInitialWelcome();
  }

  void _setInitialWelcome() {
    _messages = [
      {
        'role': 'assistant',
        'content': 'مرحبًا بك في مساعدك القانوني الذكي. كيف يمكنني مساعدتك اليوم؟',
      }
    ];
  }

  void setAccessToken(String? token) {
    _apiService.setAccessToken(token);
    if (token != null) {
      loadConversations();
    }
  }

  /// تحميل جميع المحادثات
  Future<void> loadConversations() async {
    _isConversationsLoading = true;
    notifyListeners();
    try {
      final list = await _apiService.getConversations();
      _conversations = list.map((e) => AIConversationModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      _isConversationsLoading = false;
      notifyListeners();
    }
  }

  /// إنشاء محادثة جديدة
  Future<void> newConversation({String title = 'محادثة جديدة'}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.createConversation(title);
      _currentConversation = AIConversationModel.fromJson(data);
      _conversations.insert(0, _currentConversation!);
      _messages = [];
      _setInitialWelcome();
    } catch (e) {
      _errorMessage = 'فشل في إنشاء محادثة جديدة: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// التبديل إلى محادثة موجودة وتحميل رسائلها
  Future<void> selectConversation(AIConversationModel conversation) async {
    _currentConversation = conversation;
    _isLoading = true;
    _messages = [];
    notifyListeners();
    
    try {
      final logs = await _apiService.getConversationMessages(conversation.id!);
      _messages = [];
      for (var log in logs) {
        final msg = AIChatMessageModel.fromJson(log);
        _messages.add({'role': 'user', 'content': msg.question});
        _messages.add({'role': 'assistant', 'content': msg.answer});
      }
      if (_messages.isEmpty) _setInitialWelcome();
    } catch (e) {
      _errorMessage = 'فشل في تحميل الرسائل: $e';
      _setInitialWelcome();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// أرشفة محادثة
  Future<void> archiveConversation(AIConversationModel conversation) async {
    try {
      await _apiService.updateConversation(conversation.id!, {'is_archived': !conversation.isArchived});
      await loadConversations();
      if (_currentConversation?.id == conversation.id) {
        _currentConversation = null;
        _setInitialWelcome();
      }
    } catch (e) {
      debugPrint('Error archiving conversation: $e');
    }
  }

  /// حذف محادثة
  Future<void> deleteConversation(AIConversationModel conversation) async {
    try {
      await _apiService.deleteConversation(conversation.id!);
      _conversations.removeWhere((c) => c.id == conversation.id);
      if (_currentConversation?.id == conversation.id) {
        _currentConversation = null;
        _messages = [];
        _setInitialWelcome();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  /// إرسال رسالة وحفظ السجل
  Future<void> sendMessage(String query) async {
    // 1. إذا لم تكن هناك محادثة حالية، أنشئ واحدة تلقائياً بعنوان مستخلص من السؤال
    if (_currentConversation == null) {
      final title = query.length > 30 ? '${query.substring(0, 30)}...' : query;
      await newConversation(title: title);
    }

    _messages.add({'role': 'user', 'content': query});
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // إرسال السجل للحصول على إجابة ذكية (بدون رسالة الترحيب)
      final history = _messages
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
          .toList();
      
      if (history.isNotEmpty) history.removeLast();

      final response = await _apiService.getChatResponse(query, history);
      final aiResponse = response['ai_response'] ?? response['response'] ?? 'لم يتم الحصول على استجابة.';
      
      _messages.add({'role': 'assistant', 'content': aiResponse});
      
      // 2. حفظ السجل في قاعدة البيانات
      if (_currentConversation != null) {
        await _apiService.saveChatLog(
          conversationId: _currentConversation!.id!,
          question: query,
          answer: aiResponse,
        );
        // تحديث عنوان المحادثة إذا كان لا يزال "محادثة جديدة"
        if (_currentConversation!.title == 'محادثة جديدة') {
           final newTitle = query.length > 30 ? '${query.substring(0, 30)}...' : query;
           await _apiService.updateConversation(_currentConversation!.id!, {'title': newTitle});
           await loadConversations();
           _currentConversation = _conversations.firstWhere((c) => c.id == _currentConversation!.id);
        }
      }
    } catch (e) {
      final detail = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _errorMessage = detail;
      _messages.add({
        'role': 'assistant',
        'content':
            'عذرًا، حدث خطأ أثناء معالجة طلبك. راجع شريط التنبيه أسفل الشاشة للتفاصيل.',
      });
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _currentConversation = null;
    _setInitialWelcome();
    _errorMessage = null;
    notifyListeners();
  }
}
