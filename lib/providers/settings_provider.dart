import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import '../config/api_config.dart';

/// Settings Provider - manages app settings using SharedPreferences
class SettingsProvider with ChangeNotifier {
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyDarkMode = 'dark_mode_enabled';
  static const String _keyLanguage = 'language';
  static const String _keySessionTimeout = 'session_timeout_minutes';
  static const String _keyAutoLock = 'auto_lock_enabled';
  
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _language = 'ar';
  int _sessionTimeoutMinutes = 60; // Default 1 hour
  bool _autoLockEnabled = false;
  
  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;
  String get language => _language;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  bool get autoLockEnabled => _autoLockEnabled;
  
  /// Initialize settings from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
      _darkModeEnabled = prefs.getBool(_keyDarkMode) ?? false;
      _language = prefs.getString(_keyLanguage) ?? 'ar';
      _sessionTimeoutMinutes = prefs.getInt(_keySessionTimeout) ?? 60;
      _autoLockEnabled = prefs.getBool(_keyAutoLock) ?? false;
      notifyListeners();
      developer.log('Settings initialized: notifications=$_notificationsEnabled, darkMode=$_darkModeEnabled, language=$_language, sessionTimeout=$_sessionTimeoutMinutes, autoLock=$_autoLockEnabled', name: 'SettingsProvider');
    } catch (e) {
      developer.log('Error initializing settings: $e', name: 'SettingsProvider');
    }
  }
  
  /// Toggle notifications
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyNotifications, value);
      developer.log('Notifications setting saved: $value', name: 'SettingsProvider');
    } catch (e) {
      developer.log('Error saving notifications setting: $e', name: 'SettingsProvider');
    }
  }
  
  /// Toggle dark mode
  Future<void> setDarkModeEnabled(bool value) async {
    _darkModeEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, value);
      developer.log('Dark mode setting saved: $value', name: 'SettingsProvider');
    } catch (e) {
      developer.log('Error saving dark mode setting: $e', name: 'SettingsProvider');
    }
  }
  
  /// Set language
  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, value);
      developer.log('Language setting saved: $value', name: 'SettingsProvider');
    } catch (e) {
      developer.log('Error saving language setting: $e', name: 'SettingsProvider');
    }
  }
  
  /// Set session timeout in minutes
  Future<void> setSessionTimeoutMinutes(int value) async {
    _sessionTimeoutMinutes = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySessionTimeout, value);
      developer.log('Session timeout setting saved: $value minutes', name: 'SettingsProvider');
    } catch (e) {
      developer.log('Error saving session timeout setting: $e', name: 'SettingsProvider');
    }
  }
  
  /// Toggle auto lock
  Future<void> setAutoLockEnabled(bool value) async {
    _autoLockEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoLock, value);
      developer.log('Auto lock setting saved: $value', name: 'SettingsProvider');
    } catch (e) {
      developer.log('Error saving auto lock setting: $e', name: 'SettingsProvider');
    }
  }
  
  /// Clear all local data
  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedApi = prefs.getString(ApiConfig.prefsKeyApiBaseUrl);
      await prefs.clear();
      // Do not keep an override that points to port 9000 (control panel/portal).
      // The mobile app should default to the API gateway on port 8000.
      final keepSavedApi = savedApi != null &&
          savedApi.isNotEmpty &&
          !savedApi.contains(':9000');
      if (keepSavedApi) {
        await prefs.setString(ApiConfig.prefsKeyApiBaseUrl, savedApi);
      }
      await ApiConfig.initialize();
      // Reset to defaults
      _notificationsEnabled = true;
      _darkModeEnabled = false;
      _language = 'ar';
      _sessionTimeoutMinutes = 60;
      _autoLockEnabled = false;
      notifyListeners();
      developer.log('Local data cleared', name: 'SettingsProvider');
    } catch (e) {
      developer.log('Error clearing local data: $e', name: 'SettingsProvider');
      rethrow;
    }
  }
}

