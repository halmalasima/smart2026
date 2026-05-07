import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'dart:ui' as ui;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        '/login',
        arguments: {
          'phone': _phoneController.text.trim(),
          'startNewUserOtp': true,
        },
      );
    } catch (e) {
      String errorMsg = e.toString();
      // Extract Arabic error message from ApiException if available
      if (errorMsg.contains('ApiException') && errorMsg.contains(':')) {
        final parts = errorMsg.split(': ');
        if (parts.length > 1) {
          errorMsg = parts.sublist(1).join(': ');
        }
      }
      _showError(errorMsg);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
          content: const Text(
            'تم إنشاء الحساب وتفعيله بنجاح! يمكنك الآن تسجيل الدخول.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('دخول الآن', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text('خطأ: $error'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('انضم إلى SmartJudi', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ابدأ تجربتك القانونية الذكية اليوم عن طريق إنشاء حساب جديد',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle('المعلومات الشخصية'),
              const SizedBox(height: 12),
              _buildTextField('الاسم الكامل (رباعي)', _fullNameController, Icons.person_outline_rounded),
              const SizedBox(height: 16),
              _buildTextField('رقم الهاتف (مطلوب للتحقق)', _phoneController, Icons.phone_android_rounded, keyboard: TextInputType.phone, required: true),
              const SizedBox(height: 16),
              _buildTextField('الرقم الوطني / الهوية', _nationalIdController, Icons.badge_outlined),
              
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSubmitting ? null : _register,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إرسال رمز التحقق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboard, bool required = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        filled: true,
        fillColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        errorStyle: const TextStyle(fontSize: 12),
      ),
      validator: (v) {
        if (required && v!.isEmpty) return 'هذا الحقل مطلوب';
        if (required && keyboard == TextInputType.phone) {
          if (v!.length != 9) return 'رقم الهاتف يجب أن يكون 9 أرقام';
          if (!v.startsWith('7')) return 'رقم الهاتف يجب أن يبدأ بـ 7';
        }
        return null;
      },
      onChanged: (v) {
        // Trigger validation on change for immediate feedback
        if (required && v.isNotEmpty && keyboard == TextInputType.phone) {
          if (v.length != 9 || !v.startsWith('7')) {
            setState(() {});
          }
        }
      },
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscure, VoidCallback toggle) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primary),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, size: 20), onPressed: toggle),
        filled: true,
        fillColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) => v!.length < 6 ? 'كلمة المرور قصيرة جداً' : null,
    );
  }
}
