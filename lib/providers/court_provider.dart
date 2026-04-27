import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/court_model.dart';

class CourtProvider with ChangeNotifier {
  final ApiService _apiService;

  CourtProvider({required ApiService apiService}) : _apiService = apiService;

  List<CourtModel> _courts = [];
  List<String> _governorates = [];
  bool _isLoading = false;
  bool _isLoadingGovs = false;
  String? _errorMessage;
  int _totalCount = 0;
  int _currentPage = 1;
  bool _hasMore = true;

  // Filters
  String? _searchQuery;
  String? _governorateFilter;

  List<CourtModel> get courts => _courts;
  List<String> get governorates => _governorates;
  bool get isLoading => _isLoading;
  bool get isLoadingGovs => _isLoadingGovs;
  String? get errorMessage => _errorMessage;
  int get totalCount => _totalCount;
  bool get hasMore => _hasMore;
  String? get governorateFilter => _governorateFilter;

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setGovernorateFilter(String? governorate) {
    _governorateFilter = governorate;
    notifyListeners();
  }

  Future<void> loadGovernorates() async {
    _isLoadingGovs = true;
    notifyListeners();
    try {
      final response = await _apiService.getGovernorates();
      final List<dynamic> results = response['results'] ?? [];
      _governorates = results.map((g) => g['name'].toString()).toList();
      _isLoadingGovs = false;
      notifyListeners();
    } catch (e) {
      _isLoadingGovs = false;
      notifyListeners();
      print('Error loading governorates: $e');
    }
  }

  Future<void> loadCourts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _courts = [];
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = {
        'page': _currentPage.toString(),
        'page_size': '50', // Larger page for better indexing
      };
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        queryParams['search'] = _searchQuery!;
      }
      if (_governorateFilter != null && _governorateFilter != 'الكل') {
        queryParams['governorate__name'] = _governorateFilter!;
      }

      final response = await _apiService.getCourts(queryParams: queryParams);
      
      final List<dynamic> resultsList = response['results'] ?? [];
      final results = resultsList.map((json) => CourtModel.fromJson(json)).toList();

      if (refresh) {
        _courts = results;
      } else {
        _courts.addAll(results);
      }

      _totalCount = response['count'] ?? 0;
      _hasMore = response['next'] != null;
      _currentPage++;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
