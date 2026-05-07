import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

/// يبحث عن خادم Django على المنفذ [port] ضمن نفس شبكة Wi‑Fi الحالية
/// عبر طلب [GET /health/] دون الحاجة لإدخال IP يدويًا.
class LanBackendDiscovery {
  LanBackendDiscovery._();

  static const Duration _defaultPerRequest = Duration(milliseconds: 450);
  static const int _batchSize = 40;

  /// [allowEmulatorLoopbackFallback]: على false لا يُعاد `http://10.0.2.2` (للهاتف الحقيقي).
  /// تجرب منافذ متعددة (مثلاً 9000 للبوابة ثم 8000 لـ Django) حتى لا يختار التطبيق منفذًا خاطئًا.
  static Future<String?> discover({
    List<int> ports = const [9000, 8000],
    bool allowEmulatorLoopbackFallback = true,
    Duration? perHostTimeout,
  }) async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid && !Platform.isIOS) return null;

    final perRequest = perHostTimeout ?? _defaultPerRequest;
    final wifiIp = _normalizeWifiIp(await NetworkInfo().getWifiIP());

    // محاكي Android: تأكّد أن المنفذ يستجيب لـ GET /health/ قبل اعتماده
    if (Platform.isAndroid &&
        wifiIp != null &&
        wifiIp.startsWith('10.0.2.')) {
      for (final port in ports) {
        final hit = await _tryBase('10.0.2.2', port, perRequest);
        if (hit != null) return hit;
      }
      if (allowEmulatorLoopbackFallback && ports.isNotEmpty) {
        return 'http://10.0.2.2:${ports.first}';
      }
      return null;
    }

    for (final port in ports) {
      if (wifiIp != null && _isPrivateLanIpv4(wifiIp)) {
        final hit = await _scanSubnet24(wifiIp, port, perRequest);
        if (hit != null) return hit;
      }

      final fallback = await _scanFallbackPrefixes(port, perRequest);
      if (fallback != null) return fallback;
    }

    if (Platform.isAndroid && allowEmulatorLoopbackFallback && ports.isNotEmpty) {
      for (final port in ports) {
        final hit = await _tryBase('10.0.2.2', port, perRequest);
        if (hit != null) return hit;
      }
      return 'http://10.0.2.2:${ports.first}';
    }
    return null;
  }

  static String? _normalizeWifiIp(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty || t == '0.0.0.0') return null;
    return t;
  }

  static bool _isPrivateLanIpv4(String ip) {
    final o = _ipv4Octets(ip);
    if (o == null) return false;
    final a = o[0], b = o[1];
    if (a == 10 && b == 0 && o[2] == 2) return false;
    if (a == 192 && b == 168) return true;
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }

  static List<int>? _ipv4Octets(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return null;
      out.add(n);
    }
    return out;
  }

  /// مسح /24 حول عنوان الجهاز الحالي (أولوية لعناوين DHCP شائعة).
  static Future<String?> _scanSubnet24(
    String deviceIp,
    int port,
    Duration perRequest,
  ) async {
    final o = _ipv4Octets(deviceIp);
    if (o == null) return null;
    final prefix = '${o[0]}.${o[1]}.${o[2]}';
    final self = o[3];
    final order = _orderedLastOctets(self);

    for (var i = 0; i < order.length; i += _batchSize) {
      final slice = order.sublist(
        i,
        i + _batchSize > order.length ? order.length : i + _batchSize,
      );
      final futures = slice.map(
        (last) => _tryBase('$prefix.$last', port, perRequest),
      );
      final hits = await Future.wait(futures);
      for (final h in hits) {
        if (h != null) return h;
      }
    }
    return null;
  }

  static List<int> _orderedLastOctets(int except) {
    final priority = <int>{
      103, // أولوية قصوى للجهاز الحالي للمستخدم
      1, 2, 3, 100, 101, 102,
      for (var v = 1; v <= 40; v++) v,
      for (var v = 100; v <= 160; v++) v,
      for (var v = 200; v <= 254; v++) v,
      for (var v = 41; v <= 99; v++) v,
      for (var v = 161; v <= 199; v++) v,
    };
    final out = <int>[];
    for (final v in priority) {
      if (v != except && v >= 1 && v <= 254) out.add(v);
    }
    return out;
  }

  /// عند تعذّر قراءة IP الـ Wi‑Fi: تجربة عناوين شائعة فقط (بدون مسح كامل).
  static Future<String?> _scanFallbackPrefixes(
    int port,
    Duration perRequest,
  ) async {
    const prefixes = [
      '192.168.1',
      '192.168.0',
      '192.168.2',
      '192.168.31',
      '192.168.43',
      '10.0.0',
      '172.20.10',
    ];
    final hosts = <String>[];
    for (final p in prefixes) {
      for (final last in _fallbackLastOctets) {
        hosts.add('$p.$last');
      }
    }
    for (var i = 0; i < hosts.length; i += _batchSize) {
      final end = (i + _batchSize > hosts.length) ? hosts.length : i + _batchSize;
      final slice = hosts.sublist(i, end);
      final hits = await Future.wait(
        slice.map((h) => _tryBase(h, port, perRequest)),
      );
      for (final h in hits) {
        if (h != null) return h;
      }
    }
    return null;
  }

  static Future<String?> _tryBase(
    String host,
    int port,
    Duration perRequest,
  ) async {
    // محاولة عدة مسارات للتأكد من الوصول
    final paths = [
      '/health/',
      '/health',
      '/api/health/',
      '/api/ai/health/',
    ];

    for (final path in paths) {
      final uri = Uri.parse('http://$host:$port$path');
      try {
        final r = await http.get(uri).timeout(perRequest);
        if (r.statusCode == 200) {
          final b = r.body;
          if (b.contains('"status"') &&
              (b.contains('ok') || b.contains('"ok"'))) {
            return 'http://$host:$port';
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static const List<int> _fallbackLastOctets = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 30, 40, 50, 60, 70, 80, 90,
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113,
    114, 115, 116, 117, 118, 120, 125, 130, 140, 150, 160, 170, 180, 190,
    200, 210, 220, 230, 240, 250,
  ];
}
