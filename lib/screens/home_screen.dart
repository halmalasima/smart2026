import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/sj_widgets.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

// Screens
import 'archive_screen.dart';
import 'inquiries_screen.dart';
import 'settings_screen.dart';
import 'payment_order_screen.dart';
import 'appeal_screen.dart';
import 'daily_sessions_screen.dart';
import 'calendar_screen.dart';
import 'ai_case_analysis_screen.dart';
import 'citizen_dashboard_screen.dart';
import 'notary_dashboard_screen.dart';
import 'legal_library_screen.dart';
import 'services_screen.dart';
import 'lawyers_search_screen.dart';
import 'contracts_agencies_screen.dart';
import 'inheritance_calculation_screen.dart';
import '../providers/lawsuit_provider.dart';

/// الشاشة الرئيسية المبنية بتصميم 2025+
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 5; // يبدأ من الرئيسية (Index 5)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: context.colorScheme.primary),
        ),
      );
    }

    final isDark = context.isDark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // الجهة اليسرى: الأيقونات
              Row(
                children: [
                  _buildTopIcon(
                    icon: Icons.psychology,
                    onTap: () => Navigator.pushNamed(context, '/chat'),
                    isAi: true,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Consumer<NotificationProvider>(
                    builder: (context, notifProvider, _) {
                      return _buildTopIcon(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => Navigator.pushNamed(context, '/notifications'),
                        badge: notifProvider.unreadCount > 0
                            ? notifProvider.unreadCount.toString()
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _buildTopIcon(
                    icon: Icons.search_rounded,
                    onTap: () => Navigator.pushNamed(context, '/services'),
                  ),
                ],
              ),
              // الجهة اليمنى: الشعار والاسم
              Row(
                children: [
                  Text(
                    'منصة القضاء الذكية',
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.brandLight : AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Image.asset(
                    'assets/images/logo.png',
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(user, authProvider),
      body: IndexedStack(
        index: _selectedIndex,
        children: user.isNotary
          ? [
              _buildMainDashboard(user, isNotary: true),
              const InheritanceCalculationScreen(),
              const ContractsAgenciesScreen(),
              LegalLibraryScreen(),
              ServicesScreen(),
              _buildMainDashboard(user, isNotary: true),
            ]
          : [
              _buildMainDashboard(user, isClient: user.role == 'citizen' || user.role == 'mokel'),
              const CalendarScreen(),
              ArchiveScreen(),
              LegalLibraryScreen(),
              ServicesScreen(),
              _buildMainDashboard(user, isClient: user.role == 'citizen' || user.role == 'mokel'),
            ],
      ),
      bottomNavigationBar: _buildBottomNav(isNotary: user.isNotary),
    );
  }

  // أيقونات النافبار العلوية بتصميم عصري (Glass/Soft)
  Widget _buildTopIcon({
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
    bool isAi = false,
  }) {
    final isDark = context.isDark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isAi 
              ? (isDark ? AppColors.gold.withOpacity(0.2) : AppColors.gold.withOpacity(0.15))
              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
          shape: BoxShape.circle,
          border: Border.all(
            color: isAi ? AppColors.gold.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isAi 
                  ? AppColors.gold 
                  : (isDark ? AppColors.darkIcon : AppColors.lightIcon),
            ),
            if (badge != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // لوحة التحكم الرئيسية مع الأنيميشن
  Widget _buildMainDashboard(dynamic user, {bool isClient = false, bool isNotary = false}) {
    if (isClient) return CitizenDashboardScreen();
    if (isNotary) return const NotaryDashboardScreen();
    
    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. بطاقة الترحيب
          SJHeroCard(
            title: 'مرحباً، ${user.fullName}',
            subtitle: 'جميع الخدمات القضائية في متناول يدك',
            trailing: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person, color: Colors.white, size: 30),
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Lawyer Dashboard Shortcut (Only for Pro Roles)
          if (user.role == 'lawyer' || user.role == 'admin' || user.role == 'assistant')
            SJServiceCard(
              icon: Icons.dashboard_customize_rounded,
              label: 'لوحة تحكم المكتب الاحترافية',
              subtitle: 'إدارة القضايا، الموكلين، والإحصائيات المتقدمة',
              iconColor: AppColors.gold,
              onTap: () => Navigator.pushNamed(context, '/lawyer-dashboard'),
            ).animate().fade(delay: 100.ms).slideX(begin: 0.1),
          
          const SizedBox(height: AppSpacing.xl),
          const SJSectionHeader(title: 'الخدمات السريعة')
              .animate().fade(delay: 200.ms).slideX(begin: 0.05),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            children: [
              SJQuickActionCard(
                icon: Icons.gavel_rounded,
                label: 'رفع دعوى',
                color: AppColors.coral,
                onTap: () => Navigator.pushNamed(context, '/electronic-lawsuit'),
              ),
              SJQuickActionCard(
                icon: Icons.search_rounded,
                label: 'بحث الخدمات',
                color: AppColors.ocean,
                onTap: () => Navigator.pushNamed(context, '/services'),
              ),
              SJQuickActionCard(
                icon: Icons.calendar_month_rounded,
                label: 'الجلسات',
                color: AppColors.emerald,
                onTap: () => Navigator.pushNamed(context, '/daily-sessions'),
              ),
              SJQuickActionCard(
                icon: Icons.receipt_long_rounded,
                label: 'أمر الأداء',
                color: AppColors.amber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentOrderScreen()),
                ),
              ),
              SJQuickActionCard(
                icon: Icons.compare_arrows_rounded,
                label: 'الطعون',
                color: AppColors.violet,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AppealScreen()),
                  );
                  if (result != null && mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('تم إنشاء الطعن بنجاح'),
                        content: Text('رقم الطعن: ${result['appeal_number']}\nنوع الطعن: ${result['appeal_type_display']}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('حسناً'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              SJQuickActionCard(
                icon: Icons.smart_toy_rounded,
                label: 'المساعد الذكي',
                color: AppColors.teal,
                onTap: () => Navigator.pushNamed(context, '/chat'),
                badge: 'AI',
              ),
            ]
            .animate(interval: 50.ms)
            .fade(delay: 300.ms)
            .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // 3. المزيد من الخدمات
          const SJSectionHeader(title: 'المزيد')
              .animate().fade(delay: 400.ms).slideX(begin: 0.05),
          
          Column(
            children: [
              SJServiceCard(
                icon: Icons.menu_book_rounded,
                label: 'المكتبة القانونية',
                subtitle: 'تصفح القوانين والمراجع',
                iconColor: AppColors.indigo,
                onTap: () => Navigator.pushNamed(context, '/legal-library'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SJServiceCard(
                icon: Icons.balance_rounded,
                label: 'المحكمة العليا',
                subtitle: 'قرارات ومبادئ المحكمة العليا',
                iconColor: AppColors.brand,
                onTap: () => Navigator.pushNamed(context, '/supreme-court'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SJServiceCard(
                icon: Icons.analytics_rounded,
                label: 'تحليل ذكي للقضايا',
                subtitle: 'احتمالات النجاح بالذكاء الاصطناعي',
                iconColor: AppColors.rose,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AICaseAnalysisScreen()),
                ),
              ),
            ]
            .animate(interval: 50.ms)
            .fade(delay: 500.ms)
            .slideY(begin: 0.1),
          ),
          
          const SizedBox(height: 100), // مساحة للتنقل السفلي
        ],
      ),
    );
  }

  Widget _buildDrawer(dynamic user, AuthProvider authProvider) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: context.isDark ? AppColors.darkHeroGradient : AppColors.heroGradient,
            ),
            accountName: Text(
              user.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(user.email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user.fullName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.home_rounded, 'الرئيسية', () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 5);
                }),
                _drawerItem(Icons.gavel_rounded, 'البحث عن المحامين', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LawyersSearchScreen()),
                  );
                }),
                if (user.role == 'lawyer' || user.role == 'admin' || user.role == 'assistant')
                  _drawerItem(Icons.dashboard_customize_rounded, 'لوحة تحكم المكتب', () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/lawyer-dashboard');
                  }, color: AppColors.gold),
                _drawerItem(Icons.person_rounded, 'الملف الشخصي', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                }),
                _drawerItem(Icons.settings_rounded, 'الإعدادات', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }),
                const Divider(),
                _drawerItem(Icons.contact_support_rounded, 'تواصل معنا', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/contact-us');
                }),
                _drawerItem(Icons.logout_rounded, 'تسجيل الخروج', () async {
                  Navigator.pop(context);
                  await authProvider.logout();
                }, color: AppColors.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? context.colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: context.textTheme.titleMedium?.copyWith(
          color: color ?? context.colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }

  // النافبار السفلي العائم (Floating Bottom Nav) لعام 2025
  Widget _buildBottomNav({bool isNotary = false}) {
    final isDark = context.isDark;
    
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: isDark ? AppShadows.darkMd : AppShadows.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: isNotary
          ? [
              _navItem(0, Icons.menu_rounded, 'القائمة', onTap: () => _scaffoldKey.currentState?.openDrawer()),
              _navItem(1, Icons.calculate_rounded, 'المواريث'),
              _navItem(2, Icons.description_rounded, 'العقود'),
              _navItem(3, Icons.menu_book_rounded, 'المكتبة'),
              _navItem(4, Icons.layers_rounded, 'المزيد'),
              _navItem(5, Icons.home_rounded, 'الرئيسية'),
            ]
          : [
              _navItem(0, Icons.menu_rounded, 'القائمة', onTap: () => _scaffoldKey.currentState?.openDrawer()),
              _navItem(1, Icons.calendar_month_rounded, 'الجلسات'),
              _navItem(2, Icons.folder_special_rounded, 'أرشيف'),
              _navItem(3, Icons.menu_book_rounded, 'المكتبة'),
              _navItem(4, Icons.layers_rounded, 'المزيد'),
              _navItem(5, Icons.home_rounded, 'الرئيسية'),
            ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {VoidCallback? onTap}) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant;
    
    return GestureDetector(
      onTap: onTap ?? () {
        setState(() => _selectedIndex = index);
        if (index == 2) {
          final provider = Provider.of<LawsuitProvider>(context, listen: false);
          provider.loadCases(refresh: true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
