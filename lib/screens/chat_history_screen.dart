import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  late ApiService _apiService;
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<AuthProvider>(context, listen: false).apiService;
    _fetchLogs();
  }

  Future<void> _fetchLogs({String? query}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final params = <String, String>{};
      if (query != null && query.isNotEmpty) {
        params['search'] = query;
      }
      
      final response = await _apiService.getAIChatLogs(queryParams: params);
      setState(() {
        _logs = response['results'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب السجلات: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الاستشارات الذكية'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث في السؤال أو الإجابة...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchLogs();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                filled: true,
                fillColor: context.isDark ? AppColors.darkSurfaceVariant : Colors.white,
              ),
              onSubmitted: (val) => _fetchLogs(query: val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: AppSpacing.md),
                            const Text('لا توجد سجلات استشارات سابقة'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final dateStr = log['created_at'];
                          final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                              side: BorderSide(color: context.colorScheme.outlineVariant),
                            ),
                            child: ExpansionTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.brand,
                                child: Icon(Icons.psychology, color: Colors.white, size: 20),
                              ),
                              title: Text(
                                log['question'] ?? 'بدون عنوان',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                DateFormat('yyyy/MM/dd | HH:mm').format(date),
                                style: const TextStyle(fontSize: 12),
                              ),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: context.isDark ? AppColors.darkBackground : Colors.grey.withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(AppSpacing.radiusLg),
                                      bottomRight: Radius.circular(AppSpacing.radiusLg),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const _Label(text: 'السؤال:', color: Colors.blue),
                                      Text(log['question'] ?? '', style: const TextStyle(height: 1.5)),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                        child: Divider(),
                                      ),
                                      const _Label(text: 'إجابة المساعد الذكي:', color: AppColors.brand),
                                      Text(log['answer'] ?? '', style: const TextStyle(height: 1.5)),
                                      const SizedBox(height: AppSpacing.sm),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color color;
  const _Label({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }
}
