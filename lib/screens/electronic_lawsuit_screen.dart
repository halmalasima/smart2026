import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'lawsuit_detail_screen.dart';
import 'legal_drafting_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ElectronicLawsuitScreen extends StatelessWidget {
  const ElectronicLawsuitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('رفع دعوى إلكترونية')),
        body: const Center(child: Text('يرجى تسجيل الدخول أولاً')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildIntroCard(isDark),
                  const SizedBox(height: 30),
                  Text(
                    'خطوات تقديم الدعوى',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.brandDark,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 15),
                  _buildStepItem(
                    context,
                    '1',
                    'البيانات الأساسية',
                    'تحديد المحكمة، نوع الدعوى، وموضوع النزاع بشكل دقيق.',
                    Icons.account_balance_rounded,
                    AppColors.ocean,
                  ),
                  _buildStepItem(
                    context,
                    '2',
                    'أطراف النزاع',
                    'إضافة بيانات المدعين والمدعى عليهم والهويات الشخصية.',
                    Icons.groups_rounded,
                    AppColors.violet,
                  ),
                  _buildStepItem(
                    context,
                    '3',
                    'البناء القانوني',
                    'صياغة الوقائع، الأسانيد، والطلبات باستخدام القوالب الذكية.',
                    Icons.gavel_rounded,
                    AppColors.gold,
                  ),
                  _buildStepItem(
                    context,
                    '4',
                    'المرفقات والأدلة',
                    'رفع الوثائق، العقود، والتوكيلات المؤيدة للدعوى.',
                    Icons.file_present_rounded,
                    AppColors.emerald,
                  ),
                  const SizedBox(height: 30),
                  _buildDraftingToolCard(context, isDark),
                  const SizedBox(height: 40),
                  _buildStartButton(context),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: AppColors.brand,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'التقاضي الإلكتروني',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.darkHeroGradient : AppColors.heroGradient,
          ),
          child: Stack(
            children: [
              Positioned(
                left: -20,
                top: -20,
                child: Icon(Icons.description_outlined, size: 150, color: Colors.white.withOpacity(0.05)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أتمتة الإجراءات القضائية',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'ابدأ الآن بصياغة دعواك إلكترونياً وبشكل مهني متكامل يتوافق مع متطلبات القضاء اليمني.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.gold, size: 30),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildStepItem(BuildContext context, String number, String title, String subtitle, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (int.parse(number) * 100).ms).slideX(begin: 0.05);
  }

  Widget _buildStartButton(BuildContext context) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: AppColors.brand.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LawsuitDetailScreen(),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'بدء تعبئة النموذج الإلكتروني',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.assignment_turned_in_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftingToolCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1B3D2F), const Color(0xFF0D1F18)]
            : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.emerald.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.edit_document, color: AppColors.emerald, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('المحرر القانوني الذكي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      'صياغة العرائض والطعون باستخدام القوالب القانونية الجاهزة.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LegalDraftingScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.emerald),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('افتح المحرر وابدأ الكتابة', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

