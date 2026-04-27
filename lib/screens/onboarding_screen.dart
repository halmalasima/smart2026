import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'مرحباً بك في SmartJudi',
      'description':
          'منصة ذكية متطورة لإدارة القضايا، متابعة الجلسات، والتواصل مع الجهات القانونية بكل احترافية.',
      'isLogo': true,
      'asset': 'assets/images/logo.png',
      'accent': AppColors.brand,
    },
    {
      'title': 'المساعد القانوني الذكي',
      'description':
          'استفد من تحليلات ذكية مستندة على الذكاء الاصطناعي واقتراحات قانونية تدعم قراراتك بخطوات بسيطة.',
      'isLogo': false,
      'icon': Icons.psychology_rounded,
      'accent': AppColors.ocean,
    },
    {
      'title': 'خدمات إلكترونية متكاملة',
      'description':
          'ابدأ إجراءاتك، راجع الجلسات، وتصفح المكتبة القانونية وتابع طلباتك القضائية بسرعة، أمان، وموثوقية.',
      'isLogo': false,
      'icon': Icons.account_balance_rounded,
      'accent': AppColors.amber,
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.brandDark,
              AppColors.brand,
            ],
          ),
        ),
        child: Stack(
          children: [
            // الديكور الخلفي العصري
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(begin: 0.9, end: 1.1, duration: 4.seconds),
            ),
            Positioned(
              bottom: -50,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brandLight.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(begin: 1.1, end: 0.9, duration: 3.seconds),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // شريط العنوان والتخطي
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SmartJudi',
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.2),
                            const SizedBox(height: 2),
                            Text(
                              'قانونك الذكي',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2),
                          ],
                        ),
                        TextButton(
                          onPressed: _completeOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('تخطي', style: TextStyle(fontWeight: FontWeight.bold)),
                        ).animate().fadeIn(delay: 500.ms),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    // الصفحات
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          final isLogo = page['isLogo'] == true;
                          
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // العنصر البصري (شعار أو أيقونة)
                              Container(
                                width: isLogo ? 200 : 160,
                                height: isLogo ? 200 : 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLogo ? Colors.transparent : Colors.white.withOpacity(0.1),
                                  boxShadow: isLogo ? null : [
                                    BoxShadow(
                                      color: (page['accent'] as Color).withOpacity(0.2),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: isLogo
                                      ? Image.asset(
                                          page['asset'] as String,
                                          width: 180,
                                          height: 180,
                                          fit: BoxFit.contain,
                                        )
                                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                          .scaleXY(begin: 0.95, end: 1.05, duration: 2.seconds, curve: Curves.easeInOut)
                                          .shimmer(duration: 2.seconds, color: Colors.white24)
                                      : Icon(
                                          page['icon'] as IconData,
                                          size: 80,
                                          color: Colors.white,
                                        )
                                          .animate()
                                          .scaleXY(begin: 0.8, end: 1.0, duration: 600.ms, curve: Curves.easeOutBack)
                                          .fadeIn(),
                                ),
                              ),
                              const SizedBox(height: 48),
                              
                              // النصوص
                              Text(
                                page['title'] as String,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ).animate(key: ValueKey('title_$index')).fadeIn(duration: 400.ms).slideY(begin: 0.2),
                              
                              const SizedBox(height: 16),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  page['description'] as String,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: Colors.white.withOpacity(0.85),
                                    height: 1.8,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ).animate(key: ValueKey('desc_$index')).fadeIn(delay: 200.ms).slideY(begin: 0.2),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    
                    // المؤشرات
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // الزر السفلي
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage == _pages.length - 1) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brand,
                          elevation: 8,
                          shadowColor: Colors.black38,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandDark,
                            fontSize: 18,
                          ),
                        ),
                      ).animate(target: _currentPage == _pages.length - 1 ? 1 : 0).scaleXY(end: 1.05),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
