import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/ai_chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/ai_conversation_model.dart';
import '../services/voice_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class SmartAssistantScreen extends StatefulWidget {
  const SmartAssistantScreen({super.key});

  @override
  State<SmartAssistantScreen> createState() => _SmartAssistantScreenState();
}

class _SmartAssistantScreenState extends State<SmartAssistantScreen> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> _suggestions = [
    'ما هي شروط رفع دعوى قضائية في اليمن؟',
    'كيف يتم احتساب الميراث في القانون اليمني؟',
    'ما هي إجراءات الطلاق للضرر؟',
    'ما هي عقوبة التزوير في القانون اليمني؟',
  ];

  @override
  void initState() {
    super.initState();
    _voiceService.init();
    // تأكد من تحميل المحادثات عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AIChatProvider>(context, listen: false).loadConversations();
    });
  }

  @override
  void dispose() {
    _voiceService.stop();
    _questionController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendQuestion(String questionText) async {
    final question = questionText.trim();
    if (question.isEmpty) return;

    _questionController.clear();
    _focusNode.unfocus();
    
    final provider = Provider.of<AIChatProvider>(context, listen: false);
    await provider.sendMessage(question);

    _scrollToBottom();
    
    // التحدث بالرد تلقائياً
    if (provider.messages.isNotEmpty) {
      final lastMsg = provider.messages.last;
      if (lastMsg['role'] == 'assistant') {
        _voiceService.speak(lastMsg['content']!);
      }
    }
  }

  Future<void> _toggleVoiceRecording() async {
    final available = await _voiceService.toggleListening(
      onResult: (text) {
        setState(() {
          _questionController.text = text;
        });
      },
    );

    if (available) {
      setState(() {
        _isRecording = _voiceService.isListening;
      });
      if (!_isRecording && _questionController.text.isNotEmpty) {
        _sendQuestion(_questionController.text);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تفعيل صلاحية الميكروفون')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AIChatProvider>(context);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        drawer: _buildHistoryDrawer(context, provider),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('المساعد الذكي (AI)', style: TextStyle(fontSize: 16)),
              if (provider.currentConversation != null)
                Text(
                  provider.currentConversation!.title,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu_open_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_comment_rounded),
              tooltip: 'محادثة جديدة',
              onPressed: () => provider.clearChat(),
            ),
          ],
        ),
        body: Column(
          children: [
            // منطقة الرسائل
            Expanded(
              child: provider.messages.length <= 1 && provider.isLoading == false && provider.currentConversation == null
                  ? _buildEmptyState()
                  : _buildMessagesList(provider),
            ),
            
            // مؤشر التحميل والتفكير
            if (provider.isLoading)
              _buildThinkingIndicator(isDark),

            // اقتراحات البحث
            if (provider.messages.length <= 1 && !provider.isLoading)
              _buildSuggestionsRow(isDark),

            // منطقة إدخال النص
            _buildInputArea(context, isDark, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer(BuildContext context, AIChatProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.brand),
                  const SizedBox(width: 8),
                  const Text('سجل المحادثات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_box_rounded, color: AppColors.brand),
                    onPressed: () {
                      provider.newConversation();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextField(
                onChanged: (val) => provider.searchConversations(val),
                decoration: InputDecoration(
                  hintText: 'ابحث في المحادثات...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: provider.isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : provider.conversations.isEmpty
                      ? _buildEmptyHistory(isDark)
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: provider.conversations.length,
                          itemBuilder: (context, index) {
                            final conv = provider.conversations[index];
                            final isSelected = provider.currentConversation?.id == conv.id;
                            return ListTile(
                              dense: true,
                              title: Text(
                                conv.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.brand : null,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('yyyy/MM/dd').format(conv.updatedAt ?? DateTime.now()),
                                style: const TextStyle(fontSize: 10),
                              ),
                              selected: isSelected,
                              onTap: () {
                                provider.selectConversation(conv);
                                Navigator.pop(context);
                              },
                              trailing: isSelected ? PopupMenuButton(
                                icon: const Icon(Icons.more_vert, size: 18),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Row(children: [Icon(Icons.archive, size: 18), SizedBox(width: 8), Text('أرشفة')]),
                                    onTap: () => provider.archiveConversation(conv),
                                  ),
                                  PopupMenuItem(
                                    child: const Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))]),
                                    onTap: () => provider.deleteConversation(conv),
                                  ),
                                ],
                              ) : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('لا توجد محادثات سابقة', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('ابدأ محادثة جديدة مع المساعد الذكي', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }


  Widget _buildMessagesList(AIChatProvider provider) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final message = provider.messages[index];
        final isUser = message['role'] == 'user';
        return _buildMessageBubble(
          message['content']!,
          isUser,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildThinkingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'جاري التفكير...',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(begin: 0.5, end: 1),
        ],
      ),
    );
  }

  Widget _buildSuggestionsRow(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: ActionChip(
              label: Text(_suggestions[index], style: const TextStyle(fontSize: 11)),
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              side: BorderSide(color: AppColors.brand.withOpacity(0.3)),
              onPressed: () => _sendQuestion(_suggestions[index]),
            ).animate().fade(delay: (100 * index).ms).slideX(begin: 0.1),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, bool isDark, AIChatProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _questionController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'اسأل عن أي معلومة قانونية...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: _isRecording ? Colors.red : AppColors.brand),
            onPressed: _toggleVoiceRecording,
          ),
          const SizedBox(width: 4),
          Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: provider.isLoading ? null : () => _sendQuestion(_questionController.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser 
              ? AppColors.brand 
              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.smart_toy_rounded, size: 14, color: AppColors.brand),
                    const SizedBox(width: 4),
                    const Text('المساعد الذكي', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.brand)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                      onPressed: () {}, // TODO: Copy logic
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              SelectableText(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, size: 64, color: AppColors.brand),
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          const Text(
            'مرحباً بك في مستشارك القانوني',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            child: Text(
              'اطرح أي سؤال حول القانون اليمني وسأقوم بالإجابة عليك فوراً وبدقة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
