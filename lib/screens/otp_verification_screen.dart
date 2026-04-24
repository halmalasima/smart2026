import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// OTP Verification Screen - شاشة التحقق من رمز OTP
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String purpose; // 'verify_email' or 'reset_password'

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.purpose = 'verify_email',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _otpCode;
    if (code.length < 6) {
      setState(() => _error = 'يرجى إدخال رمز التحقق كاملاً (6 أرقام)');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      if (widget.purpose == 'verify_email') {
        await apiService.verifyEmail(
          phone: widget.phoneNumber,
          code: code,
        );
        if (mounted) {
          _showSuccessAndPop('تم تفعيل حسابك بنجاح!\nيمكنك تسجيل الدخول الآن.');
        }
      } else {
        final resp = await apiService.verifyResetOtp(
          phone: widget.phoneNumber,
          code: code,
        );
        if (resp['valid'] == true && mounted) {
          Navigator.pop(context, code); // Return OTP code to password reset screen
        }
      }
    } catch (e) {
      setState(() => _error = _cleanError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;
    setState(() {
      _isResending = true;
      _error = null;
    });
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.resendOtp(
        phone: widget.phoneNumber,
        purpose: widget.purpose,
      );
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز جديد إلى هاتفك'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = _cleanError(e.toString()));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showSuccessAndPop(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
          content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  String _cleanError(String e) {
    String msg = e.replaceFirst('Exception: ', '');
    if (msg.contains('{') && msg.contains('}')) {
      // Try to extract Arabic message
      final match = RegExp(r"'error':\s*'([^']+)'").firstMatch(msg);
      if (match != null) return match.group(1)!;
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(widget.purpose == 'verify_email' ? 'تفعيل الحساب' : 'التحقق من الرمز'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // SMS icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sms_rounded, size: 40, color: AppColors.brand),
              ),
              const SizedBox(height: 24),
              const Text(
                'أدخل رمز التحقق',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'تم إرسال رمز مكون من 6 أرقام إلى هاتفك',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '+967${widget.phoneNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brand),
              ),
              const SizedBox(height: 32),

              // OTP Input Fields
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => _buildOtpField(i)),
                  ),
                ),
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

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تحقق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),

              // Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('لم تستلم الرمز؟', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 4),
                  _resendCooldown > 0
                      ? Text(
                          'إعادة الإرسال ($_resendCooldown ث)',
                          style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold),
                        )
                      : TextButton(
                          onPressed: _isResending ? null : _resendOtp,
                          child: _isResending
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('إعادة الإرسال', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand)),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return Container(
      width: 48, height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: context.isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brand, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          // Auto-verify when all 6 digits entered
          if (_otpCode.length == 6) {
            _verify();
          }
        },
      ),
    );
  }
}
