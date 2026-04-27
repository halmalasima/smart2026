import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';

/// Login Screen - شاشة الدخول بتصميم 2025+
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _savePassword = false;
  bool _discovering = false;
  bool _biometricAvailable = false;
  String? _phoneError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
    _loadSavedPassword();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final bio = BiometricService.instance;
    final available = await bio.hasStoredCredentials;
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _handleBiometricLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.biometricLogin();
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/');
    } else if (mounted && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('saved_phone');
    if (savedPhone != null && mounted) {
      setState(() {
        _phoneController.text = savedPhone;
      });
    }
  }

  Future<void> _loadSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final savePassword = prefs.getBool('save_password') ?? false;
    final savedPassword = prefs.getString('saved_password');
    if (savePassword && savedPassword != null && mounted) {
      setState(() {
        _savePassword = true;
        _passwordController.text = savedPassword;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _rediscoverServer() async {
    setState(() => _discovering = true);
    try {
      final u = await ApiConfig.rediscoverLanServer();
      if (!mounted) return;
      setState(() {});
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            u != null
                ? 'تم ضبط الخادم تلقائياً: $u'
                : 'لم يُعثر على خادم على الشبكة. تأكد من تشغيل Django على المنفذ 8000.',
          ),
          backgroundColor: u != null ? AppColors.success : AppColors.warning,
        ),
      );
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _handleLogin() async {
    // مسح رسائل الخطأ القديمة
    setState(() {
      _phoneError = null;
      _passwordError = null;
    });
    
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    ScaffoldMessenger.of(context).clearSnackBars();

    bool success = false;
    try {
      success = await authProvider.login(
        _phoneController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      // Safety net: ensure any unexpected error is shown
      if (authProvider.errorMessage == null) {
        authProvider.setError('حدث خطأ غير متوقع أثناء تسجيل الدخول');
      }
      success = false;
    }

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (_rememberMe) {
        await prefs.setString('saved_phone', _phoneController.text.trim());
      } else {
        await prefs.remove('saved_phone');
      }
      if (!mounted) return;
      if (_savePassword) {
        await prefs.setBool('save_password', true);
        await prefs.setString('saved_password', _passwordController.text);
      } else {
        await prefs.remove('save_password');
        await prefs.remove('saved_password');
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to / so AuthWrapper can decide which dashboard to show
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } else if (mounted) {
      final errorMessage = authProvider.errorMessage ?? 'فشل تسجيل الدخول';
      final isNetworkError = errorMessage.contains('الاتصال') ||
          errorMessage.contains('الخادم') ||
          errorMessage.contains('مهلة');
      final isInactiveAccount = errorMessage.contains('غير مُفعّل') ||
          errorMessage.contains('تفعيل');
      final isDisabledAccount = errorMessage.contains('تعطيل') ||
          errorMessage.contains('الدعم الفني');
      final isAuthError = errorMessage.contains('رقم الهاتف') ||
          errorMessage.contains('كلمة المرور') ||
          errorMessage.contains('بيانات الدخول') ||
          errorMessage.contains('غير صحيحة') ||
          errorMessage.contains('لا يوجد حساب');

      // إذا كان الخطأ في المصادقة، اعرض رسالة تحت الحقل المناسب
      if (isAuthError && !isInactiveAccount && !isDisabledAccount) {
        setState(() {
          if (errorMessage.contains('كلمة المرور')) {
            _passwordError = 'كلمة المرور غير صحيحة';
          } else if (errorMessage.contains('لا يوجد حساب')) {
            _phoneError = 'رقم الهاتف غير مسجل';
          } else {
            _passwordError = 'رقم الهاتف أو كلمة المرور غير صحيحة';
          }
        });
      }

      // تحديد الأيقونة والرسالة واللون بناءً على نوع الخطأ
      IconData icon;
      String snackMessage;
      Color bgColor;

      if (isInactiveAccount) {
        icon = Icons.verified_user_outlined;
        snackMessage = 'الحساب غير مُفعّل - يرجى إدخال رمز التحقق';
        bgColor = AppColors.warning;
      } else if (isDisabledAccount) {
        icon = Icons.block_rounded;
        snackMessage = errorMessage;
        bgColor = AppColors.error;
      } else if (isNetworkError) {
        icon = Icons.wifi_off_rounded;
        snackMessage = errorMessage;
        bgColor = AppColors.warning;
      } else if (isAuthError) {
        icon = Icons.error_outline_rounded;
        snackMessage = 'فشل تسجيل الدخول - تحقق من البيانات';
        bgColor = AppColors.error;
      } else {
        icon = Icons.warning_amber_rounded;
        snackMessage = errorMessage;
        bgColor = AppColors.error;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  snackMessage,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          duration: isInactiveAccount ? const Duration(seconds: 6) : const Duration(seconds: 4),
          action: isInactiveAccount
              ? SnackBarAction(
                  label: 'تفعيل',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to OTP verification screen
                    Navigator.pushNamed(context, '/verify-otp', arguments: _phoneController.text.trim());
                  },
                )
              : null,
        ),
      );
    }
  }

  void _handleGuestLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.setGuestMode(true);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أهلاً بك! أنت تتصفح " منصة القضاء الذكية" كضيف (لمدة دقيقتين فقط).'),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds).scale(begin: const Offset(0.8, 0.8)),
          
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds, delay: 300.ms).scale(begin: const Offset(0.8, 0.8)),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo & Branding
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: isDark ? AppShadows.darkMd : AppShadows.lg,
                            border: Border.all(
                              color: AppColors.brand.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 60,
                            width: 60,
                          ),
                        ),
                      ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
                      
                      const SizedBox(height: AppSpacing.xl),

                      Text(
                        'منصة القضاء الذكية',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.brandLight : AppColors.brand,
                        ),
                      ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
                      
                      const SizedBox(height: AppSpacing.xs),
                      
                      Text(
                        'منصة الخدمات القضائية الذكية',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
                      
                      const SizedBox(height: AppSpacing.xxxl),

                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: const Icon(Icons.phone_rounded),
                          errorText: _phoneError,
                          errorStyle: const TextStyle(fontSize: 12),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'يرجى إدخال رقم الهاتف';
                          if (v.length != 9) return 'يجب أن يكون 9 أرقام';
                          if (!v.startsWith('7')) return 'يجب أن يبدأ بـ 7';
                          return null;
                        },
                        onChanged: (v) {
                          // مسح رسالة الخطأ عند الكتابة
                          if (_phoneError != null) {
                            setState(() => _phoneError = null);
                          }
                        },
                      ).animate().fade(delay: 600.ms).slideX(begin: 0.1),
                      
                      const SizedBox(height: AppSpacing.lg),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          errorText: _passwordError,
                          errorStyle: const TextStyle(fontSize: 12),
                        ),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
                        onChanged: (v) {
                          // مسح رسالة الخطأ عند الكتابة
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                      ).animate().fade(delay: 700.ms).slideX(begin: 0.1),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      // تم إزالة بطاقة خادم الشبكة المحلية بناءً على طلب المستخدم (تلقائي)

                      const SizedBox(height: AppSpacing.sm),

                      // Options Row
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v!),
                          ),
                          Expanded(
                            child: Text('تذكرني', style: theme.textTheme.bodyMedium),
                          ),
                          Checkbox(
                            value: _savePassword,
                            onChanged: (v) => setState(() => _savePassword = v!),
                          ),
                          Expanded(
                            child: Text(' بدون نت ', style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ).animate().fade(delay: 900.ms),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                          },
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.xl),

                      // Login Button
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('تسجيل الدخول'),
                            ),
                            if (auth.errorMessage != null && !auth.isLoading) ...[
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                    const SizedBox(width: AppSpacing.sm),
                                    Flexible(
                                      child: Text(
                                        auth.errorMessage!,
                                        style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fade(delay: 1000.ms).slideY(begin: 0.2),
                      
                      const SizedBox(height: AppSpacing.md),

                      // Biometric Button
                      if (_biometricAvailable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: OutlinedButton.icon(
                            onPressed: _handleBiometricLogin,
                            icon: const Icon(Icons.fingerprint, size: 28),
                            label: const Text('تسجيل الدخول بالبصمة'),
                          ),
                        ).animate().fade(delay: 1050.ms).slideY(begin: 0.2),

                      // Guest Button
                      OutlinedButton(
                        onPressed: _handleGuestLogin,
                        child: const Text('تصفح كضيف'),
                      ).animate().fade(delay: 1100.ms).slideY(begin: 0.2),

                      const SizedBox(height: AppSpacing.xl),
                      
                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ليس لديك حساب؟', style: theme.textTheme.bodyMedium),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/register'),
                            child: const Text('إنشاء حساب جديد'),
                          ),
                        ],
                      ).animate().fade(delay: 1200.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
