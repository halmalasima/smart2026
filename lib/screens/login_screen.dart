import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// مراحل شاشة الدخول
enum _LoginStep { phoneInput, existingUser, newUserOtp, completeProfile, createPassword, setupBiometric, forgotPassword }

/// Login Screen - شاشة الدخول بتدفق Phone-First
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  _LoginStep _step = _LoginStep.phoneInput;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _biometricAvailable = false;
  String? _errorText;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'citizen';

  // OTP
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
    _checkBiometric();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_phone');
    if (saved != null && mounted) {
      setState(() => _phoneController.text = saved);
    }
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.instance.hasStoredCredentials;
    if (mounted) setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────

  Future<void> _handlePhoneSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorText = null; });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.checkPhone(_phoneController.text.trim());
      if (!mounted) return;

      if (result['exists'] == true) {
        setState(() => _step = _LoginStep.existingUser);
      } else {
        // تسجيل سريع + OTP
        await api.quickRegister(_phoneController.text.trim());
        if (!mounted) return;
        _startCooldown();
        setState(() => _step = _LoginStep.newUserOtp);
      }
    } catch (e) {
      setState(() => _errorText = _cleanError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordLogin() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorText = 'يرجى إدخال كلمة المرور');
      return;
    }
    setState(() { _isLoading = true; _errorText = null; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(_phoneController.text.trim(), _passwordController.text);

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_phone', _phoneController.text.trim());
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } else if (mounted) {
      setState(() => _errorText = auth.errorMessage ?? 'فشل تسجيل الدخول');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleBiometricLogin() async {
    setState(() { _isLoading = true; _errorText = null; });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.biometricLogin();
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/');
    } else if (mounted) {
      setState(() => _errorText = auth.errorMessage);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleOtpVerify() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _errorText = 'يرجى إدخال رمز التحقق كاملاً');
      return;
    }
    setState(() { _isLoading = true; _errorText = null; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithOtp(_phoneController.text.trim(), code);

    if (success && mounted) {
      // هل المستخدم جديد؟ اعرض استكمال البيانات
      final user = auth.currentUser;
      if (user != null && (user.firstName == null || user.firstName!.isEmpty)) {
        setState(() { _step = _LoginStep.completeProfile; _isLoading = false; });
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    } else if (mounted) {
      setState(() { _errorText = auth.errorMessage; _isLoading = false; });
    }
  }

  Future<void> _handleCompleteProfile() async {
    setState(() { _isLoading = true; _errorText = null; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final nameParts = _nameController.text.trim().split(' ');
      await api.updateProfile(
        firstName: nameParts.first,
        lastName: nameParts.length > 1 ? nameParts.skip(1).join(' ') : null,
      );
      if (mounted) setState(() { _step = _LoginStep.createPassword; _isLoading = false; });
    } catch (e) {
      setState(() => _errorText = _cleanError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipProfile() {
    setState(() => _step = _LoginStep.createPassword);
  }

  Future<void> _handleCreatePassword() async {
    final pw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (pw.isEmpty || pw.length < 8) {
      setState(() => _errorText = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (pw != confirm) {
      setState(() => _errorText = 'كلمات المرور غير متطابقة');
      return;
    }
    setState(() { _isLoading = true; _errorText = null; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.setPassword(pw, confirm);
      // تحديث الـ tokens بعد تغيير كلمة المرور
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (result['access'] != null && result['refresh'] != null) {
        auth.apiService.setTokens(result['access'], result['refresh']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', result['access']);
        await prefs.setString('refresh_token', result['refresh']);
      }
      if (mounted) {
        // التحقق من دعم البصمة
        final bioSupported = await BiometricService.instance.isDeviceSupported;
        if (bioSupported) {
          setState(() { _step = _LoginStep.setupBiometric; _isLoading = false; });
        } else {
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } catch (e) {
      setState(() => _errorText = _cleanError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipCreatePassword() async {
    final bioSupported = await BiometricService.instance.isDeviceSupported;
    if (bioSupported && mounted) {
      setState(() => _step = _LoginStep.setupBiometric);
    } else if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _handleSetupBiometric() async {
    setState(() { _isLoading = true; _errorText = null; });
    try {
      final phone = _phoneController.text.trim();
      final password = _newPasswordController.text;
      final success = await BiometricService.instance.enable(phone, password);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تفعيل تسجيل الدخول بالبصمة ✅'), backgroundColor: Colors.green),
          );
        }
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _skipBiometric() => Navigator.pushReplacementNamed(context, '/');

  Future<void> _handleForgotPassword() async {
    setState(() { _isLoading = true; _errorText = null; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.sendOtp(_phoneController.text.trim());
      _startCooldown();
      if (mounted) setState(() { _step = _LoginStep.forgotPassword; _isLoading = false; });
    } catch (e) {
      setState(() => _errorText = _cleanError(e.toString()));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final code = _otpControllers.map((c) => c.text).join();
    final newPw = _newPasswordController.text;
    if (code.length < 6) {
      setState(() => _errorText = 'يرجى إدخال رمز التحقق كاملاً');
      return;
    }
    if (newPw.isEmpty || newPw.length < 8) {
      setState(() => _errorText = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    setState(() { _isLoading = true; _errorText = null; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.resetPasswordOtp(
        _phoneController.text.trim(), code, newPw,
      );
      if (result['access'] != null && result['refresh'] != null) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        auth.apiService.setTokens(result['access'], result['refresh']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', result['access']);
        await prefs.setString('refresh_token', result['refresh']);
        await prefs.setString('saved_phone', _phoneController.text.trim());
        // Reload user profile
        await auth.initialize();
        if (mounted) Navigator.pushReplacementNamed(context, '/');
      } else {
        setState(() => _errorText = result['message'] ?? 'تم تغيير كلمة المرور. سجل دخولك.');
        setState(() => _step = _LoginStep.existingUser);
      }
    } catch (e) {
      setState(() => _errorText = _cleanError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGuestLogin() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.setGuestMode(true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أهلاً بك! أنت تتصفح كضيف (لمدة دقيقتين فقط).'),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goBackToPhone() {
    setState(() {
      _step = _LoginStep.phoneInput;
      _errorText = null;
      _passwordController.clear();
      for (final c in _otpControllers) { c.clear(); }
    });
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 0) { t.cancel(); } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.sendOtp(_phoneController.text.trim());
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رمز جديد'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _errorText = _cleanError(e.toString()));
    }
  }

  String _cleanError(String e) {
    String msg = e.replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
    if (msg.contains("'error':")) {
      final match = RegExp(r"'error':\s*'([^']+)'").firstMatch(msg);
      if (match != null) return match.group(1)!;
    }
    return msg;
  }

  // ─── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Background circles (same theme)
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds).scale(begin: const Offset(0.8, 0.8)),
          Positioned(
            bottom: -50, left: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds, delay: 300.ms),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(theme, isDark),
                      const SizedBox(height: AppSpacing.xxxl),
                      ..._buildStepContent(theme, isDark),
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

  Widget _buildLogo(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark ? AppShadows.darkMd : AppShadows.lg,
              border: Border.all(color: AppColors.brand.withOpacity(0.2), width: 2),
            ),
            child: Image.asset('assets/images/logo.png', height: 60, width: 60),
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
      ],
    );
  }

  List<Widget> _buildStepContent(ThemeData theme, bool isDark) {
    switch (_step) {
      case _LoginStep.phoneInput:
        return _buildPhoneStep(theme);
      case _LoginStep.existingUser:
        return _buildExistingUserStep(theme);
      case _LoginStep.newUserOtp:
        return _buildOtpStep(theme, isDark);
      case _LoginStep.completeProfile:
        return _buildCompleteProfileStep(theme);
      case _LoginStep.createPassword:
        return _buildCreatePasswordStep(theme);
      case _LoginStep.setupBiometric:
        return _buildSetupBiometricStep(theme);
      case _LoginStep.forgotPassword:
        return _buildForgotPasswordStep(theme, isDark);
    }
  }

  // ─── Step 1: Phone Input ──────────────────────────────

  List<Widget> _buildPhoneStep(ThemeData theme) {
    return [
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'رقم الهاتف',
          prefixIcon: Icon(Icons.phone_rounded),
          hintText: '7XXXXXXXX',
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'يرجى إدخال رقم الهاتف';
          if (v.length != 9) return 'يجب أن يكون 9 أرقام';
          if (!v.startsWith('7')) return 'يجب أن يبدأ بـ 7';
          return null;
        },
      ).animate().fade(delay: 600.ms).slideX(begin: 0.1),

      if (_errorText != null) _buildErrorWidget(),

      const SizedBox(height: AppSpacing.xl),

      // زر المتابعة
      ElevatedButton(
        onPressed: _isLoading ? null : _handlePhoneSubmit,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('متابعة'),
      ).animate().fade(delay: 800.ms).slideY(begin: 0.2),

      const SizedBox(height: AppSpacing.md),

      // البصمة (إذا متاحة)
      if (_biometricAvailable)
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _handleBiometricLogin,
          icon: const Icon(Icons.fingerprint, size: 28),
          label: const Text('تسجيل الدخول بالبصمة'),
        ).animate().fade(delay: 850.ms).slideY(begin: 0.2),

      if (_biometricAvailable) const SizedBox(height: AppSpacing.md),

      // ضيف
      OutlinedButton(
        onPressed: _handleGuestLogin,
        child: const Text('تصفح كضيف'),
      ).animate().fade(delay: 900.ms).slideY(begin: 0.2),

      const SizedBox(height: AppSpacing.xl),

      // طرق دخول أخرى (قريباً)
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildComingSoonChip(Icons.email_outlined, 'بريد إلكتروني'),
          const SizedBox(width: AppSpacing.sm),
          _buildComingSoonChip(Icons.apple, 'Apple'),
        ],
      ).animate().fade(delay: 1000.ms),
    ];
  }

  Widget _buildComingSoonChip(IconData icon, String label) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.grey),
      label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      backgroundColor: Colors.grey.withOpacity(0.1),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label — قريباً'), duration: const Duration(seconds: 1)),
        );
      },
    );
  }

  // ─── Step 2: Existing User (Password + Biometric) ─────

  List<Widget> _buildExistingUserStep(ThemeData theme) {
    return [
      // رقم الهاتف (قراءة فقط)
      _buildReadOnlyPhone(),
      const SizedBox(height: AppSpacing.lg),

      // كلمة المرور
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'كلمة المرور',
          prefixIcon: const Icon(Icons.lock_rounded),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),

      if (_errorText != null) _buildErrorWidget(),

      const SizedBox(height: AppSpacing.xl),

      ElevatedButton(
        onPressed: _isLoading ? null : _handlePasswordLogin,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('تسجيل الدخول'),
      ),

      const SizedBox(height: AppSpacing.md),

      if (_biometricAvailable)
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _handleBiometricLogin,
          icon: const Icon(Icons.fingerprint, size: 28),
          label: const Text('الدخول بالبصمة'),
        ),

      const SizedBox(height: AppSpacing.md),

      TextButton(
        onPressed: _goBackToPhone,
        child: const Text('← تغيير رقم الهاتف'),
      ),

      const SizedBox(height: AppSpacing.sm),

      TextButton(
        onPressed: _isLoading ? null : _handleForgotPassword,
        child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: AppColors.brand)),
      ),
    ];
  }

  // ─── Step 3: OTP Verification ─────────────────────────

  List<Widget> _buildOtpStep(ThemeData theme, bool isDark) {
    return [
      _buildReadOnlyPhone(),
      const SizedBox(height: AppSpacing.lg),

      // أيقونة SMS
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.sms_rounded, size: 32, color: AppColors.brand),
      ),
      const SizedBox(height: AppSpacing.md),
      const Text('أدخل رمز التحقق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('تم إرسال رمز مكون من 6 أرقام', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      const SizedBox(height: AppSpacing.lg),

      // OTP Fields
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _buildOtpField(i, isDark)),
        ),
      ),

      if (_errorText != null) _buildErrorWidget(),

      const SizedBox(height: AppSpacing.xl),

      ElevatedButton(
        onPressed: _isLoading ? null : _handleOtpVerify,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('تحقق'),
      ),

      const SizedBox(height: AppSpacing.md),

      // إعادة إرسال
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('لم تستلم الرمز؟', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 4),
          _resendCooldown > 0
              ? Text('($_resendCooldown ث)', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold))
              : TextButton(
                  onPressed: _resendOtp,
                  child: const Text('إعادة الإرسال', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand)),
                ),
        ],
      ),

      const SizedBox(height: AppSpacing.md),
      TextButton(onPressed: _goBackToPhone, child: const Text('← تغيير رقم الهاتف')),
    ];
  }

  Widget _buildOtpField(int index, bool isDark) {
    return Container(
      width: 44, height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand, width: 2)),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
          if (val.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
          if (_otpControllers.map((c) => c.text).join().length == 6) _handleOtpVerify();
        },
      ),
    );
  }

  // ─── Step 4: Complete Profile ─────────────────────────

  List<Widget> _buildCompleteProfileStep(ThemeData theme) {
    return [
      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
      const SizedBox(height: AppSpacing.md),
      const Text('مرحباً بك!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('أكمل بياناتك (اختياري)', style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: AppSpacing.xl),

      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'الاسم الكامل',
          prefixIcon: Icon(Icons.person_rounded),
        ),
      ),

      const SizedBox(height: AppSpacing.lg),

      // اختيار نوع الحساب
      const Text('نوع الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          _roleChip('citizen', 'مواطن', Icons.person_rounded),
          const SizedBox(width: 8),
          _roleChip('lawyer', 'محامي', Icons.gavel_rounded),
          const SizedBox(width: 8),
          _roleChip('notary', 'موثق', Icons.assignment_rounded),
        ],
      ),

      if (_errorText != null) _buildErrorWidget(),

      const SizedBox(height: AppSpacing.xl),

      ElevatedButton(
        onPressed: _isLoading ? null : _handleCompleteProfile,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('حفظ والمتابعة'),
      ),

      const SizedBox(height: AppSpacing.md),

      TextButton(
        onPressed: _skipProfile,
        child: const Text('تخطي →'),
      ),
    ];
  }

  Widget _roleChip(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.brand : Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step 5: Create Password ───────────────────────────

  List<Widget> _buildCreatePasswordStep(ThemeData theme) {
    return [
      const Icon(Icons.lock_rounded, color: AppColors.brand, size: 56),
      const SizedBox(height: AppSpacing.md),
      const Text('إنشاء كلمة مرور', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('أنشئ كلمة مرور لتسجيل الدخول لاحقاً', style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: AppSpacing.xl),

      TextFormField(
        controller: _newPasswordController,
        obscureText: _obscureNewPassword,
        decoration: InputDecoration(
          labelText: 'كلمة المرور الجديدة',
          prefixIcon: const Icon(Icons.lock_rounded),
          suffixIcon: IconButton(
            icon: Icon(_obscureNewPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
          helperText: '8 أحرف على الأقل',
        ),
      ),

      const SizedBox(height: AppSpacing.md),

      TextFormField(
        controller: _confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        decoration: InputDecoration(
          labelText: 'تأكيد كلمة المرور',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ),
      ),

      if (_errorText != null) _buildErrorWidget(),

      const SizedBox(height: AppSpacing.xl),

      ElevatedButton(
        onPressed: _isLoading ? null : _handleCreatePassword,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('حفظ كلمة المرور'),
      ),

      const SizedBox(height: AppSpacing.md),

      TextButton(
        onPressed: _skipCreatePassword,
        child: const Text('تخطي →'),
      ),
    ];
  }

  // ─── Step 6: Setup Biometric ──────────────────────────

  List<Widget> _buildSetupBiometricStep(ThemeData theme) {
    return [
      const Icon(Icons.fingerprint, color: AppColors.brand, size: 64),
      const SizedBox(height: AppSpacing.md),
      const Text('تفعيل البصمة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('سجل دخولك بسرعة باستخدام بصمة الإصبع أو الوجه', style: TextStyle(color: Colors.grey[600])),
      const SizedBox(height: AppSpacing.xxxl),

      ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleSetupBiometric,
        icon: const Icon(Icons.fingerprint, size: 28),
        label: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('تفعيل البصمة الآن'),
      ),

      const SizedBox(height: AppSpacing.lg),

      TextButton(
        onPressed: _skipBiometric,
        child: const Text('تخطي →'),
      ),
    ];
  }

  // ─── Shared Widgets ───────────────────────────────────

  // ─── Forgot Password: OTP + New Password ───────────────

  List<Widget> _buildForgotPasswordStep(ThemeData theme, bool isDark) {
    return [
      _buildReadOnlyPhone(),
      const SizedBox(height: AppSpacing.lg),

      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_reset_rounded, size: 32, color: AppColors.brand),
      ),
      const SizedBox(height: AppSpacing.md),
      const Text('إعادة تعيين كلمة المرور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('أدخل رمز التحقق وكلمة المرور الجديدة', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      const SizedBox(height: AppSpacing.lg),

      // OTP Fields
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _buildOtpField(i, isDark)),
        ),
      ),

      const SizedBox(height: AppSpacing.lg),

      // New password
      TextFormField(
        controller: _newPasswordController,
        obscureText: _obscureNewPassword,
        decoration: InputDecoration(
          labelText: 'كلمة المرور الجديدة',
          prefixIcon: const Icon(Icons.lock_rounded),
          suffixIcon: IconButton(
            icon: Icon(_obscureNewPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
          helperText: '8 أحرف على الأقل',
        ),
      ),

      if (_errorText != null) _buildErrorWidget(),

      const SizedBox(height: AppSpacing.xl),

      ElevatedButton(
        onPressed: _isLoading ? null : _handleResetPassword,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('تغيير كلمة المرور'),
      ),

      const SizedBox(height: AppSpacing.md),

      // Resend OTP
      TextButton(
        onPressed: _resendCooldown > 0 ? null : () async {
          try {
            final api = Provider.of<ApiService>(context, listen: false);
            await api.sendOtp(_phoneController.text.trim());
            _startCooldown();
          } catch (e) {
            setState(() => _errorText = _cleanError(e.toString()));
          }
        },
        child: Text(_resendCooldown > 0 ? 'إعادة الإرسال بعد $_resendCooldown ثانية' : 'إعادة إرسال الرمز'),
      ),

      TextButton(
        onPressed: _goBackToPhone,
        child: const Text('← العودة'),
      ),
    ];
  }

  Widget _buildReadOnlyPhone() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_rounded, color: AppColors.brand, size: 20),
          const SizedBox(width: 12),
          Text(
            _phoneController.text.trim(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.brand),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _goBackToPhone,
            child: const Icon(Icons.edit, color: AppColors.brand, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
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
                _errorText!,
                style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
