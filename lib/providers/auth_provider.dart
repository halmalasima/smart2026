import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../models/user_model.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../providers/settings_provider.dart';

/// Authentication Provider using Provider pattern
class AuthProvider with ChangeNotifier, WidgetsBindingObserver {
  final ApiService _apiService;
  
  AuthProvider({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService() {
    WidgetsBinding.instance.addObserver(this);
  }
      
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGuest = false;
  Timer? _sessionTimer;
  Future? _guestTimer;
  bool _isAppInBackground = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null || _isGuest;
  bool get isGuest => _isGuest;

  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  void setGuestMode(bool value) {
    _isGuest = value;
    if (_isGuest) {
      // إعداد مستخدم ضيف افتراضي
      _currentUser = UserModel(
        id: 0,
        username: 'guest',
        email: 'guest@smartjudi.com',
        firstName: 'ضيف',
        lastName: 'النظام',
        role: 'guest',
      );
      
      // بدء مؤقت لمدة دقيقتين
      _guestTimer = Future.delayed(const Duration(minutes: 2), () {
        if (_isGuest) {
          logout();
        }
      });
    }
    notifyListeners();
  }
  
  // Get access token for other services
  String? get accessToken => _apiService.accessToken;

  // Initialize - check if user is already logged in
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      if (accessToken != null && refreshToken != null) {
        // Check if token is expired
        if (JwtDecoder.isExpired(accessToken)) {
          // Try to refresh
          _apiService.setTokens(accessToken, refreshToken);
          final refreshed = await _apiService.refreshAccessToken();
          if (refreshed) {
            final newAccessToken = prefs.getString('access_token');
            if (newAccessToken != null) {
              await prefs.setString('access_token', newAccessToken);
            }
          } else {
            // Refresh failed, clear tokens
            await _clearStoredTokens();
            _isLoading = false;
            notifyListeners();
            return;
          }
        } else {
          _apiService.setTokens(accessToken, refreshToken);
        }

        // Get user profile
        try {
          _currentUser = await _apiService.getCurrentUser();
          // Cache successful profile
          await _cacheUserProfile(_currentUser!);
        } catch (e) {
          print('⚠️ [Auth] Could not fetch profile from server, trying cache: $e');
          _currentUser = await _loadCachedProfile();
          if (_currentUser == null) {
            // Failed to get user from both, clear tokens
            await _clearStoredTokens();
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Caching helpers
  Future<void> _cacheUserProfile(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_profile', user.toJsonString());
    print('💾 [Auth] User profile cached for offline use');
  }

  Future<UserModel?> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('cached_user_profile');
    if (json == null) return null;
    try {
      return UserModel.fromJsonString(json);
    } catch (e) {
      return null;
    }
  }

  // Login (using phone number)
  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _currentUser = null; // Reset user
    notifyListeners();

    try {
      // Step 1: Login to get tokens
      final response = await _apiService.login(phone, password);
      
      final accessToken = response['access'];
      final refreshToken = response['refresh'];

      if (accessToken == null || refreshToken == null) {
        _errorMessage = 'فشل في الحصول على tokens من الخادم';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Store tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);

      // Set tokens in API service
      _apiService.setTokens(accessToken, refreshToken);

      // Step 2: Get user profile
      try {
        print('🔐 [Auth] Attempting to get user profile...');
        developer.log('Attempting to get user profile...', name: 'AuthProvider');
        _currentUser = await _apiService.getCurrentUser();
        await _cacheUserProfile(_currentUser!);
        print('✅ [Auth] User profile loaded: ${_currentUser?.username}, role: ${_currentUser?.role}');
        developer.log('User profile loaded: ${_currentUser?.username}', name: 'AuthProvider');
        
        // Verify user was loaded
        if (_currentUser == null) {
          print('❌ [Auth] User profile is null after loading');
          developer.log('User profile is null after loading', name: 'AuthProvider');
          await _clearStoredTokens();
          _apiService.clearTokens();
          _errorMessage = 'فشل في جلب معلومات المستخدم: البيانات فارغة';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        print('✅ [Auth] User authenticated successfully: ${_currentUser?.username}');
      } catch (e, stackTrace) {
        print('❌ [Auth] Error getting user profile: $e');
        print('📋 [Auth] Stack trace: $stackTrace');
        developer.log('Error getting user profile: $e', name: 'AuthProvider', error: e);
        
        // Try to load from cache if network error
        if (e is SocketException || 
            e.toString().contains('SocketException') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('Network is unreachable')) {
          print('📡 [Auth] Network error, trying to load from cache...');
          _currentUser = await _loadCachedProfile();
          if (_currentUser != null) {
            print('✅ [Auth] Loaded user from cache: ${_currentUser?.username}');
            _isLoading = false;
            notifyListeners();
            
            // Start session timer even when using cached data
            _startSessionTimer();
            
            return true;
          }
        }
        
        // Failed to get user profile - clear tokens and show error
        await _clearStoredTokens();
        _apiService.clearTokens();
        _currentUser = null;
        
        // Extract error message
        String errorMsg = e.toString();
        if (errorMsg.contains('404') || errorMsg.contains('Profile not found')) {
          _errorMessage = 'ملف المستخدم غير موجود. يرجى إنشاء ملف شخصي من لوحة التحكم.';
        } else if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
          _errorMessage = 'غير مصرح بالوصول. يرجى المحاولة مرة أخرى.';
        } else {
          _errorMessage = 'فشل في جلب معلومات المستخدم:\n$errorMsg';
        }
        
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Success — update biometric credentials if enabled
      try {
        final bio = BiometricService.instance;
        if (await bio.isEnabled) {
          await bio.enable(phone, password);
        }
      } catch (_) {}

      // Start session timeout timer
      _startSessionTimer();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _currentUser = null;
      
      // تحسين رسائل الخطأ بناءً على نوع الخطأ
      String errorMsg = e.toString();
      
      // أخطاء الاتصال/الإنترنت
      if (e is SocketException || 
          errorMsg.contains('SocketException') || 
          errorMsg.contains('Failed host lookup') ||
          errorMsg.contains('Network is unreachable') ||
          errorMsg.contains('ApiErrorCode.noConnection')) {
          
        // محاولة الدخول بدون شبكة إذا كانت البيانات المحفوظة مطابقة
        final prefs = await SharedPreferences.getInstance();
        final savePassword = prefs.getBool('save_password') ?? false;
        final savedPassword = prefs.getString('saved_password');
        final savedPhone = prefs.getString('saved_phone');
        
        if (savePassword && savedPhone == phone && savedPassword == password) {
          _currentUser = await _loadCachedProfile();
          if (_currentUser != null) {
            print('✅ [Auth] Logged in offline using saved credentials');
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
            _startSessionTimer();
            return true;
          }
        }
        
        _errorMessage = 'خطأ في الاتصال بالإنترنت';
      } 
      // أخطاء انتهاء المهلة
      else if (errorMsg.contains('TimeoutException') || 
               errorMsg.contains('timeout') ||
               errorMsg.contains('Connection timed out')) {
        // محاولة الدخول بدون شبكة إذا كانت البيانات المحفوظة مطابقة
        final prefs = await SharedPreferences.getInstance();
        if ((prefs.getBool('save_password') ?? false) && 
            prefs.getString('saved_phone') == phone && 
            prefs.getString('saved_password') == password) {
          _currentUser = await _loadCachedProfile();
          if (_currentUser != null) {
            _isLoading = false; _errorMessage = null; notifyListeners(); _startSessionTimer(); return true;
          }
        }
        
        _errorMessage = 'انتهت مهلة الاتصال بالخادم';
      }
      // أخطاء رفض الاتصال
      else if (errorMsg.contains('Connection refused') ||
               errorMsg.contains('Unable to connect')) {
        // محاولة الدخول بدون شبكة إذا كانت البيانات المحفوظة مطابقة
        final prefs = await SharedPreferences.getInstance();
        if ((prefs.getBool('save_password') ?? false) && 
            prefs.getString('saved_phone') == phone && 
            prefs.getString('saved_password') == password) {
          _currentUser = await _loadCachedProfile();
          if (_currentUser != null) {
            _isLoading = false; _errorMessage = null; notifyListeners(); _startSessionTimer(); return true;
          }
        }
        
        _errorMessage = 'لا يمكن الوصول للخادم';
      }
      // أخطاء المصادقة (رقم الهاتف/كلمة المرور)
      else if (errorMsg.contains('401') || 
               errorMsg.contains('Unauthorized') ||
               errorMsg.contains('Invalid credentials') ||
               errorMsg.contains('Unable to log in') ||
               errorMsg.contains('No active account found') ||
               errorMsg.contains('Invalid username/password') ||
               errorMsg.contains('لا يوجد حساب')) {
        _errorMessage = 'رقم الهاتف أو كلمة المرور غير صحيحة';
      }
      // أخطاء 400 (Bad Request)
      else if (errorMsg.contains('400') || 
               errorMsg.contains('Bad Request')) {
        _errorMessage = 'بيانات الدخول غير صحيحة';
      }
      // أخطاء 404
      else if (errorMsg.contains('404') || 
               errorMsg.contains('Not found')) {
        _errorMessage = 'الخدمة غير متاحة حالياً';
      }
      // أخطاء 500 (Server Error)
      else if (errorMsg.contains('500') || 
               errorMsg.contains('Internal Server Error')) {
        _errorMessage = 'حدث خطأ في الخادم';
      }
      // أخطاء أخرى
      else {
        String cleanError = errorMsg;
        if (cleanError.contains('Exception: ')) {
          cleanError = cleanError.replaceFirst('Exception: ', '');
        }
        _errorMessage = 'خطأ غير متوقع: $cleanError';
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    // Cancel session timer
    _sessionTimer?.cancel();
    _sessionTimer = null;
    
    await _clearStoredTokens();
    _apiService.clearTokens();
    _currentUser = null;
    _errorMessage = null;
    _isGuest = false;
    _guestTimer = null;
    
    // Clear saved phone number for auto-login
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_phone');
    
    // Disable biometric login
    try {
      final bio = BiometricService.instance;
      if (await bio.isEnabled) {
        await bio.disable();
      }
    } catch (_) {}
    
    notifyListeners();
  }
  
  // Start session timeout timer
  void _startSessionTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final timeoutMinutes = prefs.getInt('session_timeout_minutes') ?? 60;
    
    _sessionTimer?.cancel();
    _sessionTimer = Timer(Duration(minutes: timeoutMinutes), () {
      print('⏰ [Auth] Session timeout reached, logging out');
      logout();
    });
    
    print('⏰ [Auth] Session timer started: $timeoutMinutes minutes');
  }

  // App lifecycle monitoring for auto lock
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      _isAppInBackground = true;
      print('📱 [Auth] App went to background');
    } else if (state == AppLifecycleState.resumed) {
      if (_isAppInBackground && _currentUser != null) {
        _checkAutoLock();
      }
      _isAppInBackground = false;
      print('📱 [Auth] App resumed');
    }
  }
  
  // Check if auto lock is enabled and lock the app
  Future<void> _checkAutoLock() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLockEnabled = prefs.getBool('auto_lock_enabled') ?? false;
    
    if (autoLockEnabled && _currentUser != null) {
      print('🔒 [Auth] Auto lock enabled, logging out');
      await logout();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _guestTimer = null;
    super.dispose();
  }

  // Clear stored tokens
  Future<void> _clearStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('cached_user_profile');
  }
  
  // Get ApiService instance (for use in screens)
  ApiService get apiService => _apiService;
  
  /// تسجيل الدخول بالبصمة
  Future<bool> biometricLogin() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credentials =
          await BiometricService.instance.authenticateAndGetCredentials();
      if (credentials == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      return await login(credentials.phone, credentials.password);
    } catch (e) {
      _errorMessage = 'فشل تسجيل الدخول بالبصمة';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Refresh user profile
  Future<void> refreshProfile() async {
    try {
      _currentUser = await _apiService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      developer.log('Error refreshing profile: $e', name: 'AuthProvider');
    }
  }
}

