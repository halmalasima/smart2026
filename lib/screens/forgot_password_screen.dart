import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'otp_verification_screen.dart';

/// Forgot Password Screen - شاشة استعادة كلمة المرور
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  // 3-step flow: phone → OTP → new password
  int _step = 0; // 0=phone, 1=OTP sent (navigated), 2=new password
  String? _verifiedOtpCode;

  @override
  void dispose() {
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.requestPasswordReset(phone: _phoneController.text.trim());
      if (mounted) {
        // Navigate to OTP screen for verification
        final otpCode = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: _phoneController.text.trim(),
              purpose: 'reset_password',
            ),
          ),
        );
        if (otpCode != null && mounted) {
          setState(() {
            _verifiedOtpCode = otpCode;
            _step = 2;
          });
        }
      }
    } catch (e) {
      String msg = e.toString();
      // Extract Arabic error message from ApiException if available
      if (msg.contains('ApiException') && msg.contains(':')) {
        final parts = msg.split(': ');
        if (parts.length > 1) {
          msg = parts.sublist(1).join(': ');
        }
      } else if (msg.contains('Exception: ')) {
        msg = msg.replaceFirst('Exception: ', '');
      }
      if (mounted) {
        setState(() {
          _error = msg;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'كلمات المرور غير متطابقة');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.resetPassword(
        phone: _phoneController.text.trim(),
        code: _verifiedOtpCode!,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      String msg = e.toString();
      // Extract Arabic error message from ApiException if available
      if (msg.contains('ApiException') && msg.contains(':')) {
        final parts = msg.split(': ');
        if (parts.length > 1) {
          msg = parts.sublist(1).join(': ');
        }
      } else if (msg.contains('Exception: ')) {
        msg = msg.replaceFirst('Exception: ', '');
      }
      setState(() {
        _error = msg;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
          content: const Text(
            'تم تغيير كلمة المرور بنجاح!\nيمكنك تسجيل الدخول بكلمة المرور الجديدة.',
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
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('تسجيل الدخول', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('استعادة كلمة المرور'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: _step == 2 ? _buildNewPasswordStep() : _buildPhoneStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset_rounded, size: 40, color: AppColors.brand),
        ),
        const SizedBox(height: 24),
        const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'أدخل رقم هاتفك المسجل وسنرسل لك رمز تحقق.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'رقم الهاتف (9 أرقام)',
            prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
            filled: true,
            fillColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            errorStyle: const TextStyle(fontSize: 12),
          ),
          validator: (v) {
            if (v!.isEmpty) return 'يرجى إدخال رقم الهاتف';
            if (v.length != 9) return 'رقم الهاتف يجب أن يكون 9 أرقام';
            if (!v.startsWith('7')) return 'رقم الهاتف يجب أن يبدأ بـ 7';
            return null;
          },
          onChanged: (v) {
            // Trigger validation on change for immediate feedback
            if (v.isNotEmpty && (v.length != 9 || !v.startsWith('7'))) {
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _requestReset,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: const Text('إرسال رمز التحقق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('العودة لتسجيل الدخول', style: TextStyle(color: AppColors.brand)),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_rounded, size: 40, color: Colors.green),
        ),
        const SizedBox(height: 24),
        const Text('تعيين كلمة مرور جديدة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'تم التحقق من هويتك. أدخل كلمة المرور الجديدة.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'كلمة المرور الجديدة',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off, size: 20),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            filled: true,
            fillColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'تأكيد كلمة المرور',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off, size: 20),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            filled: true,
            fillColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'يرجى تأكيد كلمة المرور';
            if (v != _newPasswordController.text) return 'كلمات المرور غير متطابقة';
            return null;
          },
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _resetPassword,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: const Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
