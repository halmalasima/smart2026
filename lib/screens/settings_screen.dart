import '../../../../theme/app_theme.dart';
import '../../../../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/biometric_service.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

/// Settings Screen - الإعدادات
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricSupported = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final bio = BiometricService.instance;
    final supported = await bio.isDeviceSupported;
    final enabled = await bio.isEnabled;
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final bio = BiometricService.instance;
    if (value) {
      // التفعيل — نطلب من المستخدم إدخال كلمة المرور لحفظ البيانات
      final result = await _showEnableBiometricDialog();
      if (result == true && mounted) {
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل تسجيل الدخول بالبصمة'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // الإلغاء
      await bio.disable();
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء تسجيل الدخول بالبصمة'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<bool> _showEnableBiometricDialog() async {
    final passwordController = TextEditingController();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = authProvider.currentUser?.username;

    if (username == null) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل الدخول بالبصمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل كلمة المرور لحفظ بيانات الدخول بشكل آمن:'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );

    if (confirmed != true || passwordController.text.isEmpty) {
      passwordController.dispose();
      return false;
    }

    final bio = BiometricService.instance;
    final success = await bio.enable(username, passwordController.text);
    passwordController.dispose();
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        children: [
          if (user != null) ...[
            // User Info Section
            UserAccountsDrawerHeader(
              accountName: Text(user.fullName),
              accountEmail: Text(user.email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: context.isDark ? AppColors.darkSurface : AppColors.lightSurface,
                child: Text(
                  user.fullName[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24, color: Colors.blue),
                ),
              ),
            ),
            const Divider(),
          ],

          // Account Settings
          _buildSectionHeader('إعدادات الحساب'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('الملف الشخصي'),
            subtitle: const Text('عرض وتعديل معلوماتك الشخصية'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('تغيير كلمة المرور'),
            subtitle: const Text('تحديث كلمة المرور الخاصة بك'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
              );
            },
          ),
          const Divider(),

          // Security Settings
          _buildSectionHeader('الأمان والخصوصية'),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait),
            title: const Text('قفل التطبيق تلقائياً'),
            subtitle: const Text('قفل التطبيق عند الخروج من الشاشة'),
            value: settingsProvider.autoLockEnabled,
            onChanged: (value) {
              settingsProvider.setAutoLockEnabled(value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'تم تفعيل القفل التلقائي' : 'تم إلغاء القفل التلقائي'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('التحقق بخطوتين'),
            subtitle: const Text('تفعيل التحقق بخطوتين (قريباً)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً: التحقق بخطوتين')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('سجل الأمان'),
            subtitle: const Text('عرض سجل الأنشطة الأمنية'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً: سجل الأمان')),
              );
            },
          ),
          const Divider(),

          // App Settings
          _buildSectionHeader('إعدادات التطبيق'),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('مدة الجلسة'),
            subtitle: Text(_getSessionTimeoutText(settingsProvider.sessionTimeoutMinutes)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showSessionTimeoutDialog(context, settingsProvider),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('الإشعارات'),
            subtitle: const Text('تلقي إشعارات حول الدعاوى والجلسات'),
            value: settingsProvider.notificationsEnabled,
            onChanged: (value) {
              settingsProvider.setNotificationsEnabled(value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'تم تفعيل الإشعارات' : 'تم إلغاء تفعيل الإشعارات'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('الوضع الليلي'),
            subtitle: const Text('تفعيل الوضع الليلي'),
            value: settingsProvider.darkModeEnabled,
            onChanged: (value) {
              settingsProvider.setDarkModeEnabled(value);
            },
          ),
          if (_biometricSupported)
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('تسجيل الدخول بالبصمة'),
              subtitle: const Text('استخدم بصمتك لتسجيل الدخول بسرعة'),
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('اللغة'),
            subtitle: const Text('العربية'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show language selection dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً: تغيير اللغة')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('عنوان خادم API'),
            subtitle: Text(
              ApiConfig.baseUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showApiBaseUrlDialog(context),
          ),
          const Divider(),

          // Data & Storage
          _buildSectionHeader('البيانات والتخزين'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('تحميل البيانات'),
            subtitle: const Text('تحميل جميع بياناتك'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Implement data download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً: تحميل البيانات')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('حذف البيانات المحلية'),
            subtitle: const Text('حذف جميع البيانات المحفوظة محلياً'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showDeleteDataDialog(context, settingsProvider);
            },
          ),
          const Divider(),

          // About & Support
          _buildSectionHeader('حول التطبيق والدعم'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('من نحن'),
            subtitle: const Text('معلومات عن منصة SmartJudi'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutUsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('مساعدة'),
            subtitle: const Text('الأسئلة الشائعة والدعم'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/faq');
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: const Text('تواصل بنا'),
            subtitle: const Text('اتصل بنا أو أرسل رسالة'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactUsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('شروط الاستخدام'),
            subtitle: const Text('اقرأ شروط استخدام التطبيق'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show terms and conditions
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً: شروط الاستخدام')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('سياسة الخصوصية'),
            subtitle: const Text('اقرأ سياسة الخصوصية'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Show privacy policy
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قريباً: سياسة الخصوصية')),
              );
            },
          ),
          const Divider(),

          // App Info
          _buildSectionHeader('معلومات التطبيق'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('الإصدار'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.update),
            title: Text('آخر تحديث'),
            subtitle: Text('2025-01-27'),
          ),
          const Divider(),

          // Logout
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'تسجيل الخروج',
              
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                _showLogoutDialog(context, authProvider);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await authProvider.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDataDialog(BuildContext context, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('حذف البيانات المحلية'),
          content: const Text(
            'هل أنت متأكد من رغبتك في حذف جميع البيانات المحفوظة محلياً؟\n\n'
            'سيتم حذف:\n'
            '• بيانات تسجيل الدخول\n'
            '• الإعدادات المحلية\n'
            '• البيانات المؤقتة\n\n'
            'لن يتم حذف البيانات من الخادم.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await settingsProvider.clearLocalData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف البيانات المحلية بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في حذف البيانات: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showApiBaseUrlDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final initial = prefs.getString(ApiConfig.prefsKeyApiBaseUrl) ?? '';
    if (!context.mounted) return;
    final controller = TextEditingController(text: initial);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('عنوان خادم API'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'يُفضَّل ترك الحقل فارغًا: التطبيق يبحث تلقائيًا عن الخادم على Wi‑Fi.\n\n'
                  'للتعديل اليدوي فقط (مثال):\nhttp://192.168.1.10:8000',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.0.147:8000',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            if (!kIsWeb)
              TextButton(
                onPressed: () async {
                  // إظهار مؤشر تحميل بسيط
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('جاري البحث عن الخادم في الشبكة المحلية...'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  
                  final discoveredUrl = await ApiConfig.rediscoverLanServer();
                  
                  if (discoveredUrl != null) {
                    controller.text = discoveredUrl;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم العثور على الخادم: $discoveredUrl'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لم يتم العثور على خادم SmartJudi. تأكد من تشغيله على الكمبيوتر بنفس الشبكة.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
                child: const Text('اكتشاف تلقائي'),
              ),
            TextButton(
              onPressed: () async {
                await ApiConfig.persistBaseUrl(controller.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ عنوان الخادم'),
                    ),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  String _getSessionTimeoutText(int minutes) {
    if (minutes == 30) return '30 دقيقة';
    if (minutes == 60) return 'ساعة واحدة';
    if (minutes == 120) return 'ساعتان';
    if (minutes == 240) return '4 ساعات';
    if (minutes == 480) return '8 ساعات';
    if (minutes == 1440) return 'يوم واحد';
    return '$minutes دقيقة';
  }

  void _showSessionTimeoutDialog(BuildContext context, SettingsProvider settingsProvider) {
    const options = [30, 60, 120, 240, 480, 1440];
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مدة الجلسة'),
        content: const Text('اختر مدة الجلسة قبل تسجيل الخروج تلقائياً:'),
        actions: [
          ...options.map((minutes) => ListTile(
            title: Text(_getSessionTimeoutText(minutes)),
            trailing: settingsProvider.sessionTimeoutMinutes == minutes 
                ? const Icon(Icons.check, color: Colors.green) 
                : null,
            onTap: () {
              settingsProvider.setSessionTimeoutMinutes(minutes);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم تحديد مدة الجلسة: ${_getSessionTimeoutText(minutes)}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          )),
        ],
      ),
    );
  }
}

