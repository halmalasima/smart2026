import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final int? lawsuitId;
  final int recipientId;
  final String recipientName;

  const ChatScreen({
    super.key, 
    this.lawsuitId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      String url = '/api/messaging/messages/';
      if (widget.lawsuitId != null) {
        url = '/api/messaging/messages/lawsuit/${widget.lawsuitId}/';
      }
      final response = await apiService.get(url);
      List<dynamic> results = [];
      if (response is List) {
        results = response;
      } else if (response is Map) {
        if (response.containsKey('results')) {
          results = response['results'] as List;
        } else if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            results = data;
          } else if (data is Map && data.containsKey('results')) {
            results = data['results'] as List;
          }
        }
      }

      setState(() {
        _messages = results;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.post('/api/messaging/messages/', {
        'recipient': widget.recipientId,
        'lawsuit_id': widget.lawsuitId,
        'content': content,
      });

      setState(() {
        _messages.add(response);
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إرسال الرسالة')),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.lawsuitId != null)
              Text('بخصوص قضية رقم ${widget.lawsuitId}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['sender'] != widget.recipientId;
                    return _buildMessageBubble(msg, isMe);
                  },
                ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : (context.isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(0) : const Radius.circular(20),
            bottomRight: isMe ? const Radius.circular(20) : const Radius.circular(0),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['content'],
              style: TextStyle(
                color: isMe ? Colors.white : (context.isDark ? Colors.white : Colors.black87),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg['created_at'].toString().split('T')[1].substring(0, 5),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file, color: Colors.grey)),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك هنا...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
