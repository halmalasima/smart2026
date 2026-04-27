import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/lawsuit_model.dart';
import 'chat_screen.dart';

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _myCases = [];

  @override
  void initState() {
    super.initState();
    _loadMyCases();
  }

  Future<void> _loadMyCases() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('/api/lawsuits/');
      List<dynamic> results = [];
      if (response is List) {
        results = response;
      } else if (response is Map) {
         if (response.containsKey('results')) {
           results = (response['results'] as List?) ?? [];
         } else if (response.containsKey('data')) {
           final data = response['data'];
           if (data is Map && data.containsKey('results')) {
             results = (data['results'] as List?) ?? [];
           } else if (data is List) {
             results = data;
           }
         }
      }
      
      setState(() {
        _myCases = results.map((json) => LawsuitModel.fromJson(json)).whereType<LawsuitModel>().toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(user),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('قضاياي ومتابعاتي'),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_myCases.isEmpty)
                    _buildEmptyState()
                  else
                    ..._myCases.map((lawsuit) => _buildCaseItem(lawsuit)).toList(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('روابط سريعة'),
                  const SizedBox(height: 12),
                  _buildQuickAction(
                    'تواصل مع المحامي', 
                    'مراسلة فورية بخصوص القضية', 
                    Icons.chat_bubble_rounded, 
                    Colors.teal,
                    () => Navigator.pushNamed(context, '/messages'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: const Text(
          'بوابة المواطن',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.brandGradient,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brand.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.brand),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تتبع قضاياك لحظة بلحظة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'يمكنك هنا الاطلاع على آخر مستجدات قضاياك المرفوعة وتواصلك مع المحامي.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد قضايا مرتبطة بك حالياً',
            style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseItem(LawsuitModel lawsuit) {
    final statusColor = _getStatusColor(lawsuit.caseStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          lawsuit.subject ?? 'بدون عنوان',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('رقم القضية: ${lawsuit.caseNumber}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lawsuit.caseStatusDisplay,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (lawsuit.createdById != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            lawsuitId: lawsuit.id,
                            recipientId: lawsuit.createdById!,
                            recipientName: lawsuit.createdByName ?? 'المحامي',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                    label: const Text('تواصل مع المحامي', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          // Navigate to a simplified case view for citizen
        },
      ),
    );
  }

  Widget _buildQuickAction(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'new': return Colors.green;
      case 'pending': return Colors.orange;
      case 'closed': return Colors.grey;
      default: return AppColors.primary;
    }
  }
}
