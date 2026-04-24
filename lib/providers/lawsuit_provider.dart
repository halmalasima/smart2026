import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/lawsuit_model.dart';
import '../models/case_model.dart';

/// Lawsuit Provider for managing lawsuits state - with archive support
class LawsuitProvider with ChangeNotifier {
  final ApiService _apiService;
  
  LawsuitProvider({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService();

  List<LawsuitModel> _lawsuits = [];
  List<CaseModel> _cases = [];
  LawsuitModel? _selectedLawsuit;
  bool _isLoading = false;
  bool _isLoadingCases = false;
  String? _errorMessage;
  String? _casesErrorMessage;
  int _totalCount = 0;
  int _currentPage = 1;
  bool _hasMore = true;

  // Cases pagination
  int _casesCurrentPage = 1;
  bool _casesHasMore = true;
  int _casesTotalCount = 0;

  // Archive stats
  Map<String, dynamic>? _archiveStats;

  // Current filters
  String? _searchQuery;
  String? _caseTypeFilter;
  String? _caseStatusFilter;
  String? _archiveStatusFilter;
  String? _governorateFilter;
  String? _filingDateFrom;
  String? _filingDateTo;
  String? _ordering;

  List<CaseModel> get cases => _cases;
  bool get isLoadingCases => _isLoadingCases;
  String? get casesErrorMessage => _casesErrorMessage;
  int get casesTotalCount => _casesTotalCount;
  bool get casesHasMore => _casesHasMore;
  List<LawsuitModel> get lawsuits => _lawsuits;
  LawsuitModel? get selectedLawsuit => _selectedLawsuit;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalCount => _totalCount;
  bool get hasMore => _hasMore;
  Map<String, dynamic>? get archiveStats => _archiveStats;

  // Filter getters
  String? get searchQuery => _searchQuery;
  String? get caseTypeFilter => _caseTypeFilter;
  String? get caseStatusFilter => _caseStatusFilter;
  String? get archiveStatusFilter => _archiveStatusFilter;
  String? get governorateFilter => _governorateFilter;
  String? get ordering => _ordering;

  bool get hasActiveFilters =>
      (_searchQuery != null && _searchQuery!.isNotEmpty) ||
      _caseTypeFilter != null ||
      _caseStatusFilter != null ||
      _archiveStatusFilter != null ||
      _governorateFilter != null ||
      _filingDateFrom != null ||
      _filingDateTo != null;

  // Set filters
  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCaseTypeFilter(String? type) {
    _caseTypeFilter = type;
    notifyListeners();
  }

  void setCaseStatusFilter(String? status) {
    _caseStatusFilter = status;
    notifyListeners();
  }

  void setArchiveStatusFilter(String? status) {
    _archiveStatusFilter = status;
    notifyListeners();
  }

  void setGovernorateFilter(String? governorate) {
    _governorateFilter = governorate;
    notifyListeners();
  }

  void setDateRange(String? from, String? to) {
    _filingDateFrom = from;
    _filingDateTo = to;
    notifyListeners();
  }

  void setOrdering(String? ordering) {
    _ordering = ordering;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = null;
    _caseTypeFilter = null;
    _caseStatusFilter = null;
    _archiveStatusFilter = null;
    _governorateFilter = null;
    _filingDateFrom = null;
    _filingDateTo = null;
    _ordering = null;
    notifyListeners();
  }

  /// Build query params from current filters
  Map<String, String> _buildQueryParams() {
    final params = <String, String>{
      'page': _currentPage.toString(),
    };

    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      params['search'] = _searchQuery!;
    }
    if (_caseTypeFilter != null) {
      params['case_type'] = _caseTypeFilter!;
    }
    if (_caseStatusFilter != null) {
      params['case_status'] = _caseStatusFilter!;
    }
    if (_archiveStatusFilter != null) {
      params['archive_status'] = _archiveStatusFilter!;
    }
    if (_governorateFilter != null) {
      params['governorate'] = _governorateFilter!;
    }
    if (_filingDateFrom != null) {
      params['filing_date_from'] = _filingDateFrom!;
    }
    if (_filingDateTo != null) {
      params['filing_date_to'] = _filingDateTo!;
    }
    if (_ordering != null) {
      params['ordering'] = _ordering!;
    }

    return params;
  }

  // Load lawsuits with filters
  Future<void> loadLawsuits({bool refresh = false, Map<String, String>? filters}) async {
    if (refresh) {
      _currentPage = 1;
      _lawsuits = [];
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Fetch from API only (no local DB)
    try {
      final queryParams = _buildQueryParams();
      if (filters != null) {
        queryParams.addAll(filters);
      }

      final response = await _apiService.getLawsuits(queryParams: queryParams);
      
      List<dynamic> resultsList = [];
      int totalCount = 0;
      bool hasMore = false;
      
      if (response is List) {
        resultsList = response;
        totalCount = response.length;
        hasMore = false;
      } else if (response is Map) {
        if (response.containsKey('data')) {
          final data = response['data'];
          if (data is Map && data.containsKey('results')) {
            resultsList = data['results'] as List? ?? [];
            totalCount = data['count'] as int? ?? 0;
            hasMore = data['next'] != null;
          } else if (data is List) {
            resultsList = data;
            totalCount = data.length;
            hasMore = false;
          } else {
            final pagination = response['pagination'] as Map?;
            if (pagination != null) {
              totalCount = pagination['count'] as int? ?? 0;
              hasMore = pagination['next'] != null;
            }
            resultsList = [];
          }
        } else if (response.containsKey('results')) {
          resultsList = (response['results'] as List?) ?? [];
          totalCount = response['count'] as int? ?? 0;
          hasMore = response['next'] != null;
        }
      }
      
      final results = resultsList
          .map((json) {
            try {
              return LawsuitModel.fromJson(json);
            } catch (e) {
              print('Error parsing lawsuit: $e');
              return null;
            }
          })
          .whereType<LawsuitModel>()
          .toList();

      if (refresh) {
        _lawsuits = results;
      } else {
        _lawsuits.addAll(results);
      }
      
      // Remove duplicates based on ID
      _lawsuits = _lawsuits.where((l) => l.id != null).toSet().toList();
      _lawsuits.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      _lawsuits = _lawsuits.where((l) => !l.isDeleted).toList();

      _totalCount = totalCount ?? 0;
      _hasMore = hasMore;
      _currentPage++;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = _lawsuits.isEmpty ? e.toString() : null;
      _isLoading = false;
      notifyListeners();
      print('API Fetch error: $e');
    }
  }

  // Load archive stats
  Future<void> loadArchiveStats() async {
    try {
      _archiveStats = await _apiService.getArchiveStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading archive stats: $e');
    }
  }

  // Load single lawsuit
  Future<void> loadLawsuit(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedLawsuit = await _apiService.getLawsuit(id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create lawsuit
  Future<LawsuitModel?> createLawsuit(LawsuitModel lawsuit) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Sync to Backend only (no local save)
      final createdLawsuit = await _apiService.createLawsuit(lawsuit);
      
      // Update local list
      await loadLawsuits(refresh: true);

      _isLoading = false;
      notifyListeners();
      return createdLawsuit; 
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Update lawsuit
  Future<bool> updateLawsuit(int id, LawsuitModel lawsuit) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedLawsuit = await _apiService.updateLawsuit(id, lawsuit);
      final index = _lawsuits.indexWhere((l) => l.id == id);
      if (index != -1) {
        _lawsuits[index] = updatedLawsuit;
      }
      if (_selectedLawsuit?.id == id) {
        _selectedLawsuit = updatedLawsuit;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete lawsuit (soft delete)
  Future<bool> deleteLawsuit(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteLawsuit(id);
      _lawsuits.removeWhere((l) => l.id == id);
      if (_selectedLawsuit?.id == id) {
        _selectedLawsuit = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Archive lawsuit
  Future<bool> archiveLawsuit(int id, {String? reason}) async {
    try {
      await _apiService.archiveLawsuit(id, reason: reason);
      await loadLawsuits(refresh: true);
      await loadArchiveStats();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Unarchive lawsuit
  Future<bool> unarchiveLawsuit(int id) async {
    try {
      await _apiService.unarchiveLawsuit(id);
      await loadLawsuits(refresh: true);
      await loadArchiveStats();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Cases ──

  Future<void> loadCases({bool refresh = false}) async {
    if (refresh) {
      _casesCurrentPage = 1;
      _cases = [];
      _casesHasMore = true;
      _casesErrorMessage = null;
    }
    if (!_casesHasMore && !refresh) return;

    _isLoadingCases = true;
    notifyListeners();

    try {
      final params = <String, String>{'page': _casesCurrentPage.toString()};
      if (_searchQuery != null && _searchQuery!.isNotEmpty) params['search'] = _searchQuery!;
      if (_caseTypeFilter != null) params['case_type'] = _caseTypeFilter!;
      if (_caseStatusFilter != null) params['case_status'] = _caseStatusFilter!;
      if (_ordering != null) params['ordering'] = _ordering!;

      final response = await _apiService.getCases(queryParams: params);

      List<dynamic> resultsList = [];
      int totalCount = 0;
      bool hasMore = false;

      if (response.containsKey('results')) {
        resultsList = (response['results'] as List?) ?? [];
        totalCount = response['count'] as int? ?? 0;
        hasMore = response['next'] != null;
      } else if (response.containsKey('data')) {
        final data = response['data'];
        if (data is Map && data.containsKey('results')) {
          resultsList = (data['results'] as List?) ?? [];
          totalCount = data['count'] as int? ?? 0;
          hasMore = data['next'] != null;
        } else if (data is List) {
          resultsList = data;
          totalCount = data.length;
        }
      }

      final parsed = resultsList
          .map((json) { try { return CaseModel.fromJson(json); } catch (_) { return null; } })
          .whereType<CaseModel>()
          .toList();

      if (refresh) {
        _cases = parsed;
      } else {
        _cases.addAll(parsed);
        _cases = _cases.where((c) => c.id != null).toSet().toList();
      }

      _casesTotalCount = totalCount;
      _casesHasMore = hasMore;
      _casesCurrentPage++;
    } catch (e) {
      _casesErrorMessage = _cases.isEmpty ? e.toString() : null;
      debugPrint('Error loading cases: $e');
    } finally {
      _isLoadingCases = false;
      notifyListeners();
    }
  }

  // Clear selected lawsuit
  void clearSelectedLawsuit() {
    _selectedLawsuit = null;
    notifyListeners();
  }

  /// Deletes a case via the API and removes it from the local list.
  Future<void> deleteCase(int caseId) async {
    await _apiService.deleteCase(caseId);
    _cases.removeWhere((c) => c.id == caseId);
    if (_casesTotalCount > 0) _casesTotalCount--;
    notifyListeners();
  }

  /// Patches a subset of fields on a case and replaces the item in-list.
  Future<CaseModel> updateCaseFields(int caseId, Map<String, dynamic> patch) async {
    final updated = await _apiService.patchCase(caseId, patch);
    final idx = _cases.indexWhere((c) => c.id == caseId);
    if (idx != -1) {
      _cases[idx] = updated;
      notifyListeners();
    }
    return updated;
  }
}
