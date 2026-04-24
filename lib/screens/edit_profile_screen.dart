import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dart:developer' as developer;

/// Edit Profile Screen - تعديل الملف الشخصي
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user != null) {
        _firstNameController.text = user.firstName ?? '';
        _lastNameController.text = user.lastName ?? '';
        _phoneController.text = user.phone ?? '';
        _nationalIdController.text = user.nationalId ?? '';
        _addressController.text = user.address ?? '';
      }
    } catch (e) {
      developer.log('Error loading profile: $e', name: 'EditProfileScreen');
      if (mounted) {
        final errorStr = e.toString();
        String errorMessage = 'خطأ في تحميل الملف الشخصي';
        IconData errorIcon = Icons.error_outline;
        Color errorColor = Colors.red;
        
        if (errorStr.contains('SocketException') || 
            errorStr.contains('Failed host lookup') ||
            errorStr.contains('Network is unreachable')) {
          errorMessage = 'لا يوجد اتصال بالإنترنت\nيرجى التحقق من اتصال الإنترنت';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('TimeoutException') || 
                   errorStr.contains('timeout')) {
          errorMessage = 'انتهت مهلة الاتصال\nيرجى المحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('404') || 
                   errorStr.contains('not found')) {
          errorMessage = 'الملف الشخصي غير موجود';
          errorIcon = Icons.person_off;
        } else if (errorStr.contains('401') || 
                   errorStr.contains('Unauthorized')) {
          errorMessage = 'غير مصرح بالوصول\nيرجى تسجيل الدخول مرة أخرى';
          errorIcon = Icons.lock_outline;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(errorIcon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'حسناً',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Update profile via API using the same ApiService instance with tokens
      await authProvider.apiService.updateProfile(
        firstName: _firstNameController.text.trim().isNotEmpty 
            ? _firstNameController.text.trim() 
            : null,
        lastName: _lastNameController.text.trim().isNotEmpty 
            ? _lastNameController.text.trim() 
            : null,
        // Phone number is not editable - do not send
        address: _addressController.text.trim().isNotEmpty 
            ? _addressController.text.trim() 
            : null,
      );
      
      // Refresh user profile to get updated data
      await authProvider.refreshProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الملف الشخصي بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      developer.log('Error saving profile: $e', name: 'EditProfileScreen');
      if (mounted) {
        String errorMessage = 'خطأ في حفظ الملف الشخصي';
        final errorStr = e.toString();
        IconData errorIcon = Icons.error_outline;
        Color errorColor = Colors.red;
        
        if (errorStr.contains('email') || errorStr.contains('البريد')) {
          errorMessage = 'البريد الإلكتروني غير صحيح أو موجود بالفعل\nيرجى استخدام بريد آخر';
          errorIcon = Icons.email;
        } else if (errorStr.contains('SocketException') || 
                   errorStr.contains('Failed host lookup') ||
                   errorStr.contains('Network is unreachable')) {
          errorMessage = 'لا يوجد اتصال بالإنترنت\nيرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('TimeoutException') || 
                   errorStr.contains('timeout')) {
          errorMessage = 'انتهت مهلة الاتصال\nيرجى المحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('Network') || errorStr.contains('Connection')) {
          errorMessage = 'لا يمكن الاتصال بالخادم\nيرجى التحقق من اتصال الإنترنت';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('400') || 
                   errorStr.contains('Bad Request')) {
          errorMessage = 'البيانات المدخلة غير صحيحة\nيرجى التحقق من جميع الحقول';
          errorIcon = Icons.warning_amber_rounded;
        } else {
          String cleanError = errorStr.replaceAll('Exception: ', '').replaceAll('Failed to update profile: ', '');
          if (cleanError.length > 100) {
            errorMessage = 'خطأ في حفظ الملف الشخصي\nيرجى المحاولة مرة أخرى';
          } else {
            errorMessage = cleanError;
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(errorIcon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'حسناً',
              textColor: Colors.white,
              onPressed: () {},
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: 'حفظ',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue,
                          child: Text(
                            user.fullName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 32, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.fullName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(user.email),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(user.role == 'judge' ? 'قاضي' : 
                                     user.role == 'lawyer' ? 'محامي' :
                                     user.role == 'notary' ? 'كاتب عدل' :
                                     user.role == 'admin' ? 'مدير' : 'مواطن'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الأول',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العائلة',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                readOnly: true, // Phone number cannot be changed
                enabled: false,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationalIdController,
                decoration: const InputDecoration(
                  labelText: 'الرقم الوطني',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                readOnly: true, // National ID cannot be changed
                enabled: false,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ التغييرات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

