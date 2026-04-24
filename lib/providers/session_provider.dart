import 'package:flutter/foundation.dart';
import '../models/hearing_model.dart';
import '../models/case_model.dart';
import '../services/api_service.dart';

/// Provider for managing sessions (hearings with session extensions)
class SessionProvider extends ChangeNotifier {
  final ApiService _api;
  SessionProvider(this._api);

  // ─── State ──────────────────────────────────────────────
  List<HearingModel> _sessions = [];
  List<HearingModel> get sessions => _sessions;

  List<CaseModel> _cases = [];
  List<CaseModel> get cases => _cases;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Filter
  String _periodFilter = 'today'; // today | week | month | custom
  String get periodFilter => _periodFilter;

  DateTime? _customFrom;
  DateTime? _customTo;
  DateTime? get customFrom => _customFrom;
  DateTime? get customTo => _customTo;

  // ─── Helpers ────────────────────────────────────────────
  List _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      final r = data['results'] ?? data['data'] ?? data['items'];
      if (r is List) return r;
    }
    return [];
  }

  // ─── Filtered lists ─────────────────────────────────────
  List<HearingModel> get todaySessions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _sessions.where((s) {
      final d = DateTime(s.hearingDate.year, s.hearingDate.month, s.hearingDate.day);
      return d.isAtSameMomentAs(today);
    }).toList();
  }

  List<HearingModel> get weekSessions {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 6)); // Saturday (Arabic week start)
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = startDay.add(const Duration(days: 7));
    return _sessions.where((s) {
      final d = DateTime(s.hearingDate.year, s.hearingDate.month, s.hearingDate.day);
      return !d.isBefore(startDay) && d.isBefore(endDay);
    }).toList();
  }

  List<HearingModel> get monthSessions {
    final now = DateTime.now();
    return _sessions.where((s) =>
        s.hearingDate.year == now.year && s.hearingDate.month == now.month).toList();
  }

  List<HearingModel> get customSessions {
    if (_customFrom == null || _customTo == null) return _sessions;
    final from = DateTime(_customFrom!.year, _customFrom!.month, _customFrom!.day);
    final to = DateTime(_customTo!.year, _customTo!.month, _customTo!.day, 23, 59, 59);
    return _sessions.where((s) =>
        !s.hearingDate.isBefore(from) && !s.hearingDate.isAfter(to)).toList();
  }

  List<HearingModel> get filteredSessions {
    switch (_periodFilter) {
      case 'today': return todaySessions;
      case 'week': return weekSessions;
      case 'month': return monthSessions;
      case 'custom': return customSessions;
      default: return _sessions;
    }
  }

  List<HearingModel> get upcomingSessions =>
      filteredSessions.where((s) => s.isUpcoming).toList();
  List<HearingModel> get previousSessions =>
      filteredSessions.where((s) => s.isPrevious).toList();

  // ─── Actions ────────────────────────────────────────────

  void setPeriodFilter(String filter) {
    _periodFilter = filter;
    notifyListeners();
  }

  void setCustomRange(DateTime from, DateTime to) {
    _customFrom = from;
    _customTo = to;
    _periodFilter = 'custom';
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _api.getHearings();
      final list = _extractList(resp);
      _sessions = list.map((e) => HearingModel.fromJson(e as Map<String, dynamic>)).toList();
      _sessions.sort((a, b) => b.hearingDate.compareTo(a.hearingDate));
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCases() async {
    try {
      final resp = await _api.getCases();
      final list = _extractList(resp);
      _cases = list.map((e) => CaseModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
    notifyListeners();
  }

  Future<HearingModel?> createSession(Map<String, dynamic> data) async {
    try {
      final resp = await _api.createHearing(data);
      final session = HearingModel.fromJson(resp);
      _sessions.insert(0, session);
      notifyListeners();
      return session;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<HearingModel?> updateSession(int id, Map<String, dynamic> data) async {
    try {
      final resp = await _api.updateHearing(id, data);
      final updated = HearingModel.fromJson(resp);
      final idx = _sessions.indexWhere((s) => s.id == id);
      if (idx != -1) _sessions[idx] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteSession(int id) async {
    try {
      await _api.deleteHearing(id);
      _sessions.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Record court decision on an upcoming session, then create next session
  Future<HearingModel?> recordDecisionAndCreateNext({
    required int sessionId,
    required String courtDecision,
    required DateTime nextDate,
    required int lawsuitId,
    int? caseId,
  }) async {
    // 1. Update current session with decision
    final updated = await updateSession(sessionId, {
      'court_decision': courtDecision,
      'next_session_date': nextDate.toIso8601String().split('T')[0],
      'session_type': 'previous',
    });
    if (updated == null) return null;

    // 2. Create next session
    final next = await createSession({
      'lawsuit_id': lawsuitId,
      if (caseId != null) 'case_id': caseId,
      'hearing_date': nextDate.toIso8601String().split('T')[0],
      'session_type': 'upcoming',
      'hearing_type': 'main',
      'notes': '',
      'requirements': '',
    });
    return next;
  }

  List<HearingModel> sessionsForCase(int caseId) =>
      _sessions.where((s) => s.caseId == caseId).toList();
}
