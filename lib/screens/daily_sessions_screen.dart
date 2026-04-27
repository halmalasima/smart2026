import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'dart:developer' as developer;

class DailySessionsScreen extends StatefulWidget {
  const DailySessionsScreen({super.key});

  @override
  State<DailySessionsScreen> createState() => _DailySessionsScreenState();
}

class _DailySessionsScreenState extends State<DailySessionsScreen> {
  late ApiService _apiService;
  bool _isLoading = false;
  Map<String, List<Map<String, dynamic>>> _groupedSessions = {};
  List<String> _sortedDates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiService = Provider.of<AuthProvider>(context, listen: false).apiService;
      _loadAllSessions();
    });
  }

  Future<void> _loadAllSessions() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all sessions (hearings) for the user
      final response = await _apiService.get('/api/hearings/');
      final results = response['results'] as List? ?? [];
      
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      
      for (var hearing in results) {
        final dateStr = hearing['hearing_date'] ?? 'بدون تاريخ';
        if (!grouped.containsKey(dateStr)) {
          grouped[dateStr] = [];
        }
        grouped[dateStr]!.add({
          'id': hearing['id'],
          'case_number': hearing['lawsuit']?['case_number'] ?? 'غير معروف',
          'subject': hearing['lawsuit']?['subject'] ?? 'بدون عنوان',
          'court': hearing['lawsuit']?['court_detail']?['name'] ?? hearing['lawsuit']?['court'] ?? 'غير معروف',
          'time': hearing['hearing_time'] ?? '--:--',
          'judge': hearing['judge_name'] ?? 'غير محدد',
          'type': hearing['hearing_type_display'] ?? hearing['hearing_type'] ?? 'جلسة',
        });
      }

      final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // Newest first

      setState(() {
        _groupedSessions = grouped;
        _sortedDates = sortedKeys;
      });
    } catch (e) {
      developer.log('Error loading sessions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('أجندة الجلسات القضائية'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllSessions,
          ),
        ],
      ),
      body: _isLoading && _groupedSessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _groupedSessions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sortedDates.length,
                  itemBuilder: (context, index) {
                    final date = _sortedDates[index];
                    final sessions = _groupedSessions[date]!;
                    return _buildDateGroup(date, sessions, index);
                  },
                ),
    );
  }

  Widget _buildDateGroup(String date, List<Map<String, dynamic>> sessions, int index) {
    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(date);
    } catch (_) {}

    final dateDisplay = parsedDate != null 
        ? intl.DateFormat('EEEE, d MMMM yyyy', 'ar').format(parsedDate)
        : date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateDisplay,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
        ...sessions.map((s) => _buildSessionCard(s)).toList(),
        const SizedBox(height: 10),
      ],
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.pushNamed(context, '/session-detail', arguments: {'id': session['id']}),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time & Type Column
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      session['time'],
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session['type'],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['subject'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'رقم القضية: ${session['case_number']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 14, color: AppColors.emerald),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            session['court'],
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: AppColors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'القاضي: ${session['judge']}',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
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
          Icon(Icons.event_available_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'لا توجد جلسات مجدولة حالياً',
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'سيتم عرض الجلسات المضافة هنا مرتبة حسب التاريخ',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/electronic-lawsuit'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            child: const Text('إضافة قضية/جلسة جديدة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
