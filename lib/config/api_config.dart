import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lan_backend_discovery.dart';

/// API Configuration — يدعم سيرفرًا محليًا على نفس الشبكة (الهاتف لا يصل إلى `localhost`).
class ApiConfig {
  ApiConfig._();

  static const String prefsKeyApiBaseUrl = 'api_base_url';

  /// تمرير عند البناء: `--dart-define=API_BASE_URL=http://192.168.0.147:8000`
  static const String _fromEnvironment =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String? _savedOverride;

  /// `true` = هاتف حقيقي — لا يُستخدم `10.0.2.2` كافتراضي.
  static bool? _androidIsPhysicalDevice;

  static const int _defaultBackendPort = 8000;

  static Future<void> _loadAndroidPhysicalFlag() async {
    if (!Platform.isAndroid) {
      _androidIsPhysicalDevice = null;
      return;
    }
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      _androidIsPhysicalDevice = a.isPhysicalDevice;
    } catch (_) {
      _androidIsPhysicalDevice = true;
    }
  }

  static bool _isAndroidEmulatorHost(String url) {
    final n = _normalizeUrl(url);
    return Platform.isAndroid && n == 'http://10.0.2.2:$_defaultBackendPort';
  }

  /// يُستدعى من [main] بعد [WidgetsFlutterBinding.ensureInitialized].
  /// عند عدم وجود عنوان محفوظ أو من البيئة: يحاول اكتشاف الخادم على الشبكة الحالية.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (Platform.isAndroid) {
      await _loadAndroidPhysicalFlag();
    }
    // If --dart-define=API_BASE_URL is provided, it takes priority and replaces
    // any stale saved override (e.g. when moving to a different WiFi).
    final envUrl = _fromEnvironment.trim();
    if (envUrl.isNotEmpty) {
      final normalized = _normalizeUrl(envUrl);
      _savedOverride = normalized;
      await prefs.setString(prefsKeyApiBaseUrl, normalized);
      return;
    }
    final saved = prefs.getString(prefsKeyApiBaseUrl)?.trim();
    if (saved != null && saved.isNotEmpty) {
      _savedOverride = _normalizeUrl(saved);
      return;
    }

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final allowEmuFallback = _androidIsPhysicalDevice == false;
      // محاولة الاكتشاف التلقائي
      var discovered = await LanBackendDiscovery.discover(
        port: _defaultBackendPort,
        allowEmulatorLoopbackFallback: allowEmuFallback,
      );
      if (discovered != null) {
        _savedOverride = _normalizeUrl(discovered);
        await prefs.setString(prefsKeyApiBaseUrl, _savedOverride!);
        return;
      }
    }
  }

  /// إعادة البحث عن الخادم على الشبكة الحالية (يستبدل العنوان المحفوظ تلقائيًا).
  static Future<String?> rediscoverLanServer() async {
    await persistBaseUrl('');
    await _loadAndroidPhysicalFlag();
    final allowEmu = _androidIsPhysicalDevice == false;
    var url = await LanBackendDiscovery.discover(
      port: _defaultBackendPort,
      allowEmulatorLoopbackFallback: allowEmu,
    );
    if (url == null && _androidIsPhysicalDevice != false) {
      url = await LanBackendDiscovery.discover(
        port: _defaultBackendPort,
        allowEmulatorLoopbackFallback: false,
        perHostTimeout: const Duration(milliseconds: 900),
      );
    }
    if (url != null && !_isAndroidEmulatorHost(url)) {
      await persistBaseUrl(url);
    }
    return url;
  }

  /// عنوان الـ API الفعّال (بدون شرطة مائلة أخيرة).
  static String get baseUrl {
    if (_savedOverride != null && _savedOverride!.isNotEmpty) {
      return _savedOverride!;
    }
    final env = _fromEnvironment.trim();
    if (env.isNotEmpty) return _normalizeUrl(env);
    if (kIsWeb) return 'http://localhost:$_defaultBackendPort';
    if (Platform.isAndroid) {
      if (_androidIsPhysicalDevice == false) {
        return 'http://10.0.2.2:$_defaultBackendPort';
      }
      // Physical device: LAN discovery should have set _savedOverride.
      // If it failed, return loopback as safe fallback (user can change in settings).
      return 'http://127.0.0.1:$_defaultBackendPort';
    }
    if (Platform.isIOS) return 'http://localhost:$_defaultBackendPort';
    return 'http://localhost:$_defaultBackendPort';
  }

  /// حفظ عنوان الخادم (مثلاً `http://192.168.1.10:8000`) أو مسحه لاستخدام الافتراضي.
  static Future<void> persistBaseUrl(String url) async {
    final trimmed = url.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      _savedOverride = null;
      await prefs.remove(prefsKeyApiBaseUrl);
      return;
    }
    final normalized = _normalizeUrl(trimmed);
    _savedOverride = normalized;
    await prefs.setString(prefsKeyApiBaseUrl, normalized);
  }

  static String _normalizeUrl(String u) {
    var s = u.trim();
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isNotEmpty && !s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    if (s.isNotEmpty && !RegExp(r':\d+$').hasMatch(Uri.parse(s).host.isEmpty ? '' : s)) {
      final uri = Uri.tryParse(s);
      if (uri != null && uri.port == 0) {
        s = '$s:$_defaultBackendPort';
      }
    }
    return s;
  }

  static const String loginEndpoint = '/api/token/';
  static const String refreshTokenEndpoint = '/api/token/refresh/';
  static const String profilesEndpoint = '/api/profiles/';
  static const String lawLibraryBooksEndpoint = '/api/law-library-books/';
  static const String lawLibraryCategoriesEndpoint = '/api/law-library-books/categories/';
  static const String casesEndpoint = '/api/cases/';
  static const String casePartiesEndpoint = '/api/case-parties/';
  static const String lawsuitsEndpoint = '/api/lawsuits/';
  static const String plaintiffsEndpoint = '/api/plaintiffs/';
  static const String defendantsEndpoint = '/api/defendants/';
  static const String attachmentsEndpoint = '/api/attachments/';
  static const String responsesEndpoint = '/api/responses/';
  static const String appealsEndpoint = '/api/appeals/';
  static const String hearingsEndpoint = '/api/hearings/';
  static const String judgmentsEndpoint = '/api/judgments/';
  static const String lawyersEndpoint = '/api/lawyers/';
  static const String lawyerFilterOptionsEndpoint = '/api/lawyer-filter-options/';
  static const String auditLogsEndpoint = '/api/audit-logs/';

  static const String governoratesEndpoint = '/api/governorates/';
  static const String districtsEndpoint = '/api/districts/';
  static const String courtTypesEndpoint = '/api/court-types/';
  static const String courtSpecializationsEndpoint =
      '/api/court-specializations/';
  static const String courtsEndpoint = '/api/courts/';

  static const String legalCategoriesEndpoint = '/api/legal-categories/';
  static const String lawsEndpoint = '/api/laws/';
  static const String lawChaptersEndpoint = '/api/law-chapters/';
  static const String lawSectionsEndpoint = '/api/law-sections/';
  static const String lawArticlesEndpoint = '/api/law-articles/';
  static const String caseLegalReferencesEndpoint =
      '/api/case-legal-references/';

  static const String userSessionsEndpoint = '/api/user-sessions/';
  static const String searchLogsEndpoint = '/api/search-logs/';
  static const String aiChatLogsEndpoint = '/api/ai-chat-logs/';
  static const String aiConversationsEndpoint = '/api/ai-conversations/';

  static const String paymentOrdersEndpoint = '/api/payment-orders/';

  static const String legalTemplatesEndpoint = '/api/legal-templates/';
  static const String financialClaimsEndpoint = '/api/financial-claims/';
  static const String caseFileItemsEndpoint = '/api/case-file-items/';

  static const String aiChatEndpoint = '/api/ai/chat/';
  static const String aiDocumentsAddEndpoint = '/api/ai/documents/add/';
  static const String aiDocumentsDeleteEndpoint = '/api/ai/documents/delete/';

  static const Duration timeout = Duration(seconds: 15);

  static const int maxRetries = 1;
  static const Duration retryDelay = Duration(seconds: 1);
}
