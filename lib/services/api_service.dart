import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../core/errors/api_exception.dart';
import '../models/user_model.dart';
import '../models/lawsuit_model.dart';
import '../models/case_model.dart';
import '../models/hearing_model.dart';

/// API Service for communicating with Django backend
class ApiService {
  String? _accessToken;
  String? _refreshToken;
  void Function()? _onUnauthorized;

  // Set tokens after login
  void setTokens(String accessToken, String refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void setUnauthorizedHandler(void Function()? handler) {
    _onUnauthorized = handler;
  }

  // ========== Cases API ==========

  Future<Map<String, dynamic>> getCases({Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.casesEndpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<CaseModel> getCase(int id) async {
    final data = await _makeRequest('GET', '${ApiConfig.casesEndpoint}$id/');
    return CaseModel.fromJson(data);
  }

  Future<CaseModel> createCase(CaseModel c) async {
    final data = await _makeRequest('POST', ApiConfig.casesEndpoint, body: c.toJson());
    return CaseModel.fromJson(data);
  }

  Future<CaseModel> updateCase(int id, CaseModel c) async {
    final data = await _makeRequest('PATCH', '${ApiConfig.casesEndpoint}$id/', body: c.toJson());
    return CaseModel.fromJson(data);
  }

  Future<void> deleteCase(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.casesEndpoint}$id/');
  }

  Future<CaseModel> patchCase(int id, Map<String, dynamic> body) async {
    final data = await _makeRequest('PATCH', '${ApiConfig.casesEndpoint}$id/', body: body);
    return CaseModel.fromJson(data);
  }

  // ========== Case Parties API (أطراف القضية) ==========

  Future<List<CasePartyModel>> getCaseParties(int caseId) async {
    final data = await _makeRequest('GET', '${ApiConfig.casePartiesEndpoint}?case=$caseId');
    final List<dynamic> items = (data['results'] as List?) ?? (data['data'] as List?) ?? [];
    return items.map((e) => CasePartyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CasePartyModel> createCaseParty(CasePartyModel party) async {
    final data = await _makeRequest('POST', ApiConfig.casePartiesEndpoint, body: party.toJson());
    return CasePartyModel.fromJson(data);
  }

  Future<void> deleteCaseParty(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.casePartiesEndpoint}$id/');
  }

  Future<CasePartyModel> updateCaseParty(int id, Map<String, dynamic> patch) async {
    final data = await _makeRequest(
      'PATCH',
      '${ApiConfig.casePartiesEndpoint}$id/',
      body: patch,
    );
    return CasePartyModel.fromJson(data);
  }

  // ========== Hearings API ==========

  Future<HearingModel> getHearing(int id) async {
    final data = await _makeRequest('GET', '${ApiConfig.hearingsEndpoint}$id/');
    return HearingModel.fromJson(data);
  }

  // Clear tokens on logout
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  // Get access token (for other services)
  String? get accessToken => _accessToken;
  
  // Get refresh token
  String? get refreshToken => _refreshToken;

  // Get authorization header
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // Generic methods for custom endpoints
  Future<dynamic> get(String endpoint) => _makeRequest('GET', endpoint);
  
  Future<dynamic> post(String endpoint, Map<String, dynamic>? body) => 
      _makeRequest('POST', endpoint, body: body);
      
  Future<dynamic> patch(String endpoint, Map<String, dynamic>? body) => 
      _makeRequest('PATCH', endpoint, body: body);
      
  Future<dynamic> delete(String endpoint) => _makeRequest('DELETE', endpoint);

  // Make HTTP request
  Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? files,
  }) async {
    try {
      final fullUrl = '${ApiConfig.baseUrl}$endpoint';
      print('🌐 [API] Making $method request to: $fullUrl');
      final url = Uri.parse(fullUrl);
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(url, headers: _headers)
              .timeout(ApiConfig.timeout);
          break;
        case 'POST':
          if (files != null) {
            // For file uploads, use multipart
            var request = http.MultipartRequest('POST', url);
            request.headers.addAll(_headers);
            request.headers.remove('Content-Type'); // Let multipart set it
            
            body?.forEach((key, value) {
              request.fields[key] = value.toString();
            });
            
            // Add files asynchronously
            for (var entry in files.entries) {
              request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
            }
            
            var streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          } else {
            print('📤 [API] POST body: ${body != null ? jsonEncode(body) : 'null'}');
            print('📤 [API] POST headers: $_headers');
            response = await http
                .post(url, headers: _headers, body: body != null ? jsonEncode(body) : null)
                .timeout(ApiConfig.timeout);
          }
          break;
        case 'PUT':
          if (files != null) {
            // For file uploads with PUT, use multipart
            var request = http.MultipartRequest('PUT', url);
            request.headers.addAll(_headers);
            request.headers.remove('Content-Type'); // Let multipart set it
            
            body?.forEach((key, value) {
              request.fields[key] = value.toString();
            });
            
            // Add files asynchronously
            for (var entry in files.entries) {
              request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
            }
            
            var streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          } else {
            response = await http
                .put(url, headers: _headers, body: jsonEncode(body))
                .timeout(ApiConfig.timeout);
          }
          break;
        case 'PATCH':
          if (files != null) {
            // For file uploads with PATCH, use multipart
            var request = http.MultipartRequest('PATCH', url);
            request.headers.addAll(_headers);
            request.headers.remove('Content-Type'); // Let multipart set it
            
            body?.forEach((key, value) {
              request.fields[key] = value.toString();
            });
            
            // Add files asynchronously
            for (var entry in files.entries) {
              request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
            }
            
            var streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          } else {
            response = await http
                .patch(url, headers: _headers, body: body != null ? jsonEncode(body) : null)
                .timeout(ApiConfig.timeout);
          }
          break;
        case 'DELETE':
          response = await http
              .delete(url, headers: _headers)
              .timeout(ApiConfig.timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print('📡 [API] Response status: ${response.statusCode}');
      if (response.statusCode >= 300 && response.statusCode < 400) {
        print('⚠️ [API] Redirect detected: ${response.headers['location']}');
      }
      print('📡 [API] Response body: ${response.body}');
      
      // Handle empty response body
      dynamic responseData;
      if (response.body.isEmpty) {
        print('⚠️ [API] Empty response body');
        responseData = <String, dynamic>{};
      } else {
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          print('❌ [API] JSON decode error: $e');
          print('❌ [API] Response body was: ${response.body}');

          final body = response.body.trimLeft();
          final looksLikeHtml = body.startsWith('<!DOCTYPE html') || body.startsWith('<html');
          if (looksLikeHtml) {
            throw ApiException(
              message: 'الخدمة غير متاحة حالياً (رد غير متوقع من الخادم)'
                  ' [${response.statusCode}]',
              code: ApiErrorCode.serverError,
              statusCode: response.statusCode,
            );
          }

          throw ApiException(
            message: 'تعذر قراءة رد الخادم [${response.statusCode}]',
            code: ApiErrorCode.serverError,
            statusCode: response.statusCode,
          );
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ [API] Request successful');
        if (responseData is Map<String, dynamic>) return responseData;
        if (responseData is Map) return Map<String, dynamic>.from(responseData);
        // Non-map payload (e.g. List) — wrap to satisfy return type without breaking callers.
        return <String, dynamic>{'data': responseData};
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh (only for non-login requests)
        if (_refreshToken != null && endpoint != ApiConfig.loginEndpoint) {
          final refreshed = await refreshAccessToken();
          if (refreshed) {
            return _makeRequest(method, endpoint, body: body, files: files);
          }
        }

        if (endpoint != ApiConfig.loginEndpoint) {
          try {
            _onUnauthorized?.call();
          } catch (_) {}
        }
        final detail = responseData['detail']?.toString() ?? '';
        if (endpoint == ApiConfig.loginEndpoint ||
            detail.contains('No active account') ||
            detail.contains('Unable to log in') ||
            detail.isEmpty) {
          throw const ApiException(
            message: 'اسم المستخدم أو كلمة المرور غير صحيحة',
            code: ApiErrorCode.invalidCredentials,
            statusCode: 401,
          );
        }
        throw ApiException(
          message: detail,
          code: ApiErrorCode.unauthorized,
          statusCode: 401,
        );
      } else if (response.statusCode == 400 && endpoint == ApiConfig.loginEndpoint) {
        // Auth validation errors (inactive account, wrong password, etc.)
        String errorDetail = '';
        if (responseData is Map<String, dynamic>) {
          // DRF ValidationError wraps 'detail' as a list or string
          final detailField = responseData['detail'];
          if (detailField is List && detailField.isNotEmpty) {
            errorDetail = detailField.first.toString();
          } else if (detailField is String) {
            errorDetail = detailField;
          } else {
            // Non-field errors may be nested
            final nonField = responseData['non_field_errors'];
            if (nonField is List && nonField.isNotEmpty) {
              errorDetail = nonField.first.toString();
            } else {
              errorDetail = responseData.values.expand((v) => v is List ? v.map((e) => e.toString()) : [v.toString()]).join('\n');
            }
          }
        }
        print('🔐 [API] Auth validation error: $errorDetail');
        throw ApiException(
          message: errorDetail.isNotEmpty ? errorDetail : 'بيانات الدخول غير صحيحة',
          code: ApiErrorCode.invalidCredentials,
          statusCode: 400,
        );
      } else if (response.statusCode == 403) {
        throw ApiException(
          message: responseData['detail']?.toString() ?? 'Forbidden',
          code: ApiErrorCode.forbidden,
          statusCode: 403,
        );
      } else if (response.statusCode == 404) {
        throw ApiException(
          message: responseData['detail']?.toString() ?? 'Not found',
          code: ApiErrorCode.notFound,
          statusCode: 404,
        );
      } else {
        // Validation / other errors
        String errorMessage = 'Request failed';
        Map<String, dynamic>? fieldErrors;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('detail')) {
            errorMessage = responseData['detail'].toString();
          } else {
            fieldErrors = Map<String, dynamic>.from(responseData);
            final errors = <String>[];
            responseData.forEach((key, value) {
              if (value is List) {
                errors.addAll(value.map((e) => e.toString()));
              } else if (value is String) {
                errors.add(value);
              } else {
                errors.add('$key: ${value.toString()}');
              }
            });
            if (errors.isNotEmpty) errorMessage = errors.join('\n');
          }
        }
        throw ApiException(
          message: errorMessage,
          code: response.statusCode >= 500 ? ApiErrorCode.serverError : ApiErrorCode.validation,
          statusCode: response.statusCode,
          fieldErrors: fieldErrors,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      print('❌ [API] Exception in _makeRequest: $e');
      print('📋 [API] Stack trace: $stackTrace');

      final msg = e.toString();
      if (msg.contains('TimeoutException') || msg.contains('timeout')) {
        throw ApiException(
          message: 'انتهت مهلة الاتصال (${ApiConfig.baseUrl})',
          code: ApiErrorCode.timeout,
        );
      } else if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
        throw ApiException(
          message: 'فشل الاتصال بالخادم (${ApiConfig.baseUrl})',
          code: ApiErrorCode.noConnection,
        );
      } else if (msg.contains('Connection refused')) {
        throw ApiException(
          message: 'تم رفض الاتصال (${ApiConfig.baseUrl})',
          code: ApiErrorCode.connectionRefused,
        );
      }
      throw ApiException(
        message: msg,
        code: ApiErrorCode.unknown,
      );
    }
  }

  // Refresh access token
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.refreshTokenEndpoint}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print('⚠️ [API] Empty response body in refreshAccessToken');
          return false;
        }
        try {
          final data = jsonDecode(response.body);
          _accessToken = data['access'];
          // If refresh token rotation is enabled, the server returns a new refresh token
          if (data.containsKey('refresh')) {
            _refreshToken = data['refresh'];
          }
          return true;
        } catch (e) {
          print('❌ [API] JSON decode error in refreshAccessToken: $e');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('❌ [API] Error in refreshAccessToken: $e');
      return false;
    }
  }

  // Authentication with retry logic
  Future<Map<String, dynamic>> login(String phone, String password) async {
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < ApiConfig.maxRetries) {
      try {
        final response = await _makeRequest(
          'POST',
          ApiConfig.loginEndpoint,
          body: {
            'username': phone, // Backend expects 'username' according to DRF requirements
            'password': password,
          },
        );
        
        _accessToken = response['access'];
        _refreshToken = response['refresh'];
        
        return response;
      } catch (e) {
        attempts++;
        lastException = e is Exception ? e : Exception(e.toString());
        
        // Don't retry on authentication errors (401, 400 with invalid credentials)
        if (e.toString().contains('Unauthorized') || 
            e.toString().contains('Invalid credentials') ||
            e.toString().contains('Unable to log in') ||
            e.toString().contains('No active account found') ||
            e.toString().contains('Invalid username/password') ||
            e.toString().contains('401') ||
            e.toString().contains('اسم المستخدم') ||
            e.toString().contains('كلمة المرور')) {
          rethrow;
        }
        
        // Don't retry on network errors in last attempt
        if (attempts >= ApiConfig.maxRetries) {
          rethrow;
        }
        
        // Wait before retrying (except on last attempt)
        if (attempts < ApiConfig.maxRetries) {
          print('🔄 [API] Login attempt $attempts failed, retrying in ${ApiConfig.retryDelay.inSeconds}s...');
          await Future.delayed(ApiConfig.retryDelay);
        }
      }
    }
    
    // All retries failed
    if (lastException != null) {
      throw lastException;
    }
    throw Exception('فشل الاتصال بالخادم بعد ${ApiConfig.maxRetries} محاولة. يرجى التحقق من اتصال الإنترنت');
  }

  // Update user profile
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? address,
    String? role,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (email != null) body['email'] = email;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      if (role != null) body['role'] = role;
      // Note: address might need to be added to UserProfile model
      
      final response = await _makeRequest(
        'PATCH',
        '${ApiConfig.profilesEndpoint}me/',
        body: body,
      );
      
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Get current user profile
  Future<UserModel> getCurrentUser() async {
    try {
      print('🔍 [API] Calling getCurrentUser: ${ApiConfig.profilesEndpoint}me/');
      final response = await _makeRequest('GET', '${ApiConfig.profilesEndpoint}me/');
      
      print('📦 [API] Response received: $response');
      
      // Validate response
      if (response == null || response.isEmpty) {
        print('❌ [API] Response is empty');
        throw Exception('Response is empty from server');
      }
      
      // Try to parse user model
      try {
        print('🔄 [API] Parsing user model...');
        final user = UserModel.fromJson(response);
        print('✅ [API] User model parsed successfully: ${user.username}');
        return user;
      } catch (e, stackTrace) {
        print('❌ [API] Failed to parse user data: $e');
        print('📋 [API] Stack trace: $stackTrace');
        print('📋 [API] Response data: $response');
        throw Exception('Failed to parse user data: ${e.toString()}\nResponse: $response');
      }
    } catch (e, stackTrace) {
      print('❌ [API] Error in getCurrentUser: $e');
      print('📋 [API] Stack trace: $stackTrace');
      
      // Provide more specific error message
      final errorStr = e.toString();
      if (errorStr.contains('404') || errorStr.contains('Profile not found') || errorStr.contains('not found')) {
        throw Exception('ملف المستخدم غير موجود. يرجى إنشاء ملف شخصي من لوحة التحكم في Django Admin.');
      } else if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
        throw Exception('غير مصرح بالوصول. يرجى تسجيل الدخول مرة أخرى.');
      } else if (errorStr.contains('Connection') || errorStr.contains('timeout')) {
        throw Exception('فشل الاتصال بالخادم. تأكد من أن Django يعمل.');
      } else {
        throw Exception('فشل في جلب معلومات المستخدم:\n$errorStr');
      }
    }
  }

  // Lawsuits
  Future<dynamic> getLawsuits({Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.lawsuitsEndpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<LawsuitModel> getLawsuit(int id) async {
    final response = await _makeRequest('GET', '${ApiConfig.lawsuitsEndpoint}$id/');
    return LawsuitModel.fromJson(response);
  }

  Future<LawsuitModel> createLawsuit(LawsuitModel lawsuit) async {
    final response = await _makeRequest(
      'POST',
      ApiConfig.lawsuitsEndpoint,
      body: lawsuit.toJson(),
    );
    return LawsuitModel.fromJson(response);
  }

  Future<LawsuitModel> updateLawsuit(int id, LawsuitModel lawsuit) async {
    final response = await _makeRequest(
      'PATCH',
      '${ApiConfig.lawsuitsEndpoint}$id/',
      body: lawsuit.toJson(),
    );
    return LawsuitModel.fromJson(response);
  }

  Future<void> deleteLawsuit(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.lawsuitsEndpoint}$id/');
  }

  // ========== Archive API ==========

  /// Get archive statistics
  Future<Map<String, dynamic>> getArchiveStats() async {
    return await _makeRequest('GET', '${ApiConfig.lawsuitsEndpoint}stats/');
  }

  /// Archive a lawsuit
  Future<Map<String, dynamic>> archiveLawsuit(int id, {String? reason}) async {
    return await _makeRequest(
      'POST',
      '${ApiConfig.lawsuitsEndpoint}$id/archive/',
      body: {if (reason != null) 'reason': reason},
    );
  }

  /// Unarchive a lawsuit
  Future<Map<String, dynamic>> unarchiveLawsuit(int id) async {
    return await _makeRequest(
      'POST',
      '${ApiConfig.lawsuitsEndpoint}$id/unarchive/',
    );
  }

  /// Restore a soft-deleted lawsuit
  Future<Map<String, dynamic>> restoreLawsuit(int id) async {
    return await _makeRequest(
      'POST',
      '${ApiConfig.lawsuitsEndpoint}$id/restore/',
    );
  }

  // Legal Templates
  Future<Map<String, dynamic>> getLegalTemplates({String? caseType}) async {
    String endpoint = ApiConfig.legalTemplatesEndpoint;
    if (caseType != null) {
      endpoint += 'by_case_type/?case_type=${Uri.encodeComponent(caseType)}';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Get templates for lawsuit creation
  Future<Map<String, dynamic>> getLawsuitTemplates(String caseType) async {
    return await _makeRequest(
      'GET',
      '${ApiConfig.lawsuitsEndpoint}get_templates/?case_type=${Uri.encodeComponent(caseType)}',
    );
  }

  // Parties (Plaintiffs & Defendants)
  Future<Map<String, dynamic>> getPlaintiffs({int? lawsuitId}) async {
    String endpoint = ApiConfig.plaintiffsEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> createPlaintiff(Map<String, dynamic> plaintiffData) async {
    return await _makeRequest('POST', ApiConfig.plaintiffsEndpoint, body: plaintiffData);
  }

  Future<Map<String, dynamic>> updatePlaintiff(int id, Map<String, dynamic> plaintiffData) async {
    return await _makeRequest('PATCH', '${ApiConfig.plaintiffsEndpoint}$id/', body: plaintiffData);
  }

  Future<void> deletePlaintiff(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.plaintiffsEndpoint}$id/');
  }

  Future<Map<String, dynamic>> getDefendants({int? lawsuitId}) async {
    String endpoint = ApiConfig.defendantsEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> createDefendant(Map<String, dynamic> defendantData) async {
    return await _makeRequest('POST', ApiConfig.defendantsEndpoint, body: defendantData);
  }

  Future<Map<String, dynamic>> updateDefendant(int id, Map<String, dynamic> defendantData) async {
    return await _makeRequest('PATCH', '${ApiConfig.defendantsEndpoint}$id/', body: defendantData);
  }

  Future<void> deleteDefendant(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.defendantsEndpoint}$id/');
  }

  // Attachments
  Future<dynamic> getAttachments({int? lawsuitId}) async {
    String endpoint = ApiConfig.attachmentsEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit_id=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  // OCR
  Future<String> extractTextFromImage(String filePath) async {
    try {
      final response = await _makeRequest(
        'POST',
        ApiConfig.ocrExtractTextEndpoint,
        files: {'file': filePath},
      );
      if (response['text'] != null) {
        return response['text'] as String;
      }
      return '';
    } catch (e) {
      print('❌ OCR Error: $e');
      throw Exception('فشل استخراج النص: $e');
    }
  }

  Future<Map<String, dynamic>> uploadAttachment({
    required int lawsuitId,
    required String filePath,
    required String documentType,
    required String gregorianDate,
    required String hijriDate,
    required int pageCount,
    required String content,
    required String evidenceBasis,
  }) async {
    return await _makeRequest(
      'POST',
      ApiConfig.attachmentsEndpoint,
      body: {
        'lawsuit_id': lawsuitId.toString(),
        'document_type': documentType,
        'gregorian_date': gregorianDate,
        'hijri_date': hijriDate,
        'page_count': pageCount.toString(),
        'content': content,
        'evidence_basis': evidenceBasis,
      },
      files: {'file': filePath},
    );
  }

  Future<Map<String, dynamic>> updateAttachment({
    required int id,
    required String documentType,
    required String gregorianDate,
    required String hijriDate,
    required int pageCount,
    required String content,
    required String evidenceBasis,
    String? filePath,
  }) async {
    final body = {
      'document_type': documentType,
      'gregorian_date': gregorianDate,
      'hijri_date': hijriDate,
      'page_count': pageCount.toString(),
      'content': content,
      'evidence_basis': evidenceBasis,
    };

    if (filePath != null) {
      // If new file is provided, use multipart
      return await _makeRequest(
        'PATCH',
        '${ApiConfig.attachmentsEndpoint}$id/',
        body: body,
        files: {'file': filePath},
      );
    } else {
      // If no new file, just update fields
      return await _makeRequest(
        'PATCH',
        '${ApiConfig.attachmentsEndpoint}$id/',
        body: body,
      );
    }
  }

  Future<void> deleteAttachment(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.attachmentsEndpoint}$id/');
  }

  // Hearings
  Future<dynamic> getHearings({
    int? lawsuitId,
    int? caseId,
    String? hearingType,
    String? sessionType,
    int? judge,
    String? hearingDate,
    String? hearingDateFrom,
    String? hearingDateTo,
    String? createdFrom,
    String? createdTo,
    String? archiveStatus,
    bool? includeDeleted,
    String? search,
    String? ordering,
  }) async {
    String endpoint = ApiConfig.hearingsEndpoint;
    final params = <String, String>{};
    
    if (lawsuitId != null) {
      params['lawsuit_id'] = lawsuitId.toString();
    }
    if (caseId != null) {
      params['case_id'] = caseId.toString();
    }
    if (hearingType != null) {
      params['hearing_type'] = hearingType;
    }
    if (sessionType != null) {
      params['session_type'] = sessionType;
    }
    if (judge != null) {
      params['judge'] = judge.toString();
    }
    if (hearingDate != null) {
      params['hearing_date'] = hearingDate;
    }
    if (hearingDateFrom != null) {
      params['hearing_date_from'] = hearingDateFrom;
    }
    if (hearingDateTo != null) {
      params['hearing_date_to'] = hearingDateTo;
    }
    if (createdFrom != null) {
      params['created_from'] = createdFrom;
    }
    if (createdTo != null) {
      params['created_to'] = createdTo;
    }
    if (archiveStatus != null) {
      params['archive_status'] = archiveStatus;
    }
    if (includeDeleted != null) {
      params['include_deleted'] = includeDeleted.toString();
    }
    if (search != null) {
      params['search'] = search;
    }
    if (ordering != null) {
      params['ordering'] = ordering;
    }
    
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> createHearing(Map<String, dynamic> hearingData) async {
    return await _makeRequest('POST', ApiConfig.hearingsEndpoint, body: hearingData);
  }

  Future<Map<String, dynamic>> updateHearing(int id, Map<String, dynamic> hearingData) async {
    return await _makeRequest('PATCH', '${ApiConfig.hearingsEndpoint}$id/', body: hearingData);
  }

  Future<void> deleteHearing(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.hearingsEndpoint}$id/');
  }

  // ========== Hearing Archive API ==========
  
  /// Archive a hearing session
  Future<Map<String, dynamic>> archiveHearing(int id, {String? reason}) async {
    return await _makeRequest(
      'POST',
      '${ApiConfig.hearingsEndpoint}$id/archive/',
      body: {if (reason != null) 'archive_reason': reason},
    );
  }

  /// Unarchive a hearing session
  Future<Map<String, dynamic>> unarchiveHearing(int id) async {
    return await _makeRequest(
      'POST',
      '${ApiConfig.hearingsEndpoint}$id/unarchive/',
    );
  }

  /// Restore a soft-deleted hearing session
  Future<Map<String, dynamic>> restoreHearing(int id) async {
    return await _makeRequest(
      'POST',
      '${ApiConfig.hearingsEndpoint}$id/restore/',
    );
  }

  /// Get daily hearings for a specific date
  Future<dynamic> getDailyHearings(DateTime date) async {
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return await getHearings(hearingDate: dateString);
  }

  // Lawyers
  Future<dynamic> getLawyers({Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.lawyersEndpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> getLawyer(int id) async {
    return await _makeRequest('GET', '${ApiConfig.lawyersEndpoint}$id/');
  }

  Future<List<String>> getLawyerBranches() async {
    final response = await _makeRequest('GET', '${ApiConfig.lawyerFilterOptionsEndpoint}branches/');
    return List<String>.from(response['branches'] ?? []);
  }

  Future<List<String>> getLawyerGrades() async {
    final response = await _makeRequest('GET', '${ApiConfig.lawyerFilterOptionsEndpoint}grades/');
    return List<String>.from(response['grades'] ?? []);
  }

  // Judgments
  Future<dynamic> getJudgments({int? lawsuitId}) async {
    String endpoint = ApiConfig.judgmentsEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Appeals
  Future<dynamic> getAppeals({int? lawsuitId}) async {
    String endpoint = ApiConfig.appealsEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> createAppeal(Map<String, dynamic> appealData) async {
    return await _makeRequest('POST', ApiConfig.appealsEndpoint, body: appealData);
  }

  Future<Map<String, dynamic>> updateAppeal(int id, Map<String, dynamic> appealData) async {
    return await _makeRequest('PATCH', '${ApiConfig.appealsEndpoint}$id/', body: appealData);
  }

  Future<void> deleteAppeal(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.appealsEndpoint}$id/');
  }

  // Payment Orders
  Future<dynamic> getPaymentOrders({int? lawsuitId}) async {
    String endpoint = ApiConfig.paymentOrdersEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> createPaymentOrder(Map<String, dynamic> orderData) async {
    return await _makeRequest('POST', ApiConfig.paymentOrdersEndpoint, body: orderData);
  }

  Future<Map<String, dynamic>> updatePaymentOrder(int id, Map<String, dynamic> orderData) async {
    return await _makeRequest('PATCH', '${ApiConfig.paymentOrdersEndpoint}$id/', body: orderData);
  }

  Future<void> deletePaymentOrder(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.paymentOrdersEndpoint}$id/');
  }

  // ========== Financial Claims API (الأتعاب) ==========

  Future<dynamic> getFinancialClaims({int? lawsuitId}) async {
    String endpoint = ApiConfig.financialClaimsEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> createFinancialClaim(Map<String, dynamic> claimData) async {
    // Ensure lawsuit field is an int
    final body = Map<String, dynamic>.from(claimData);
    if (body['lawsuit'] is String) {
      body['lawsuit'] = int.tryParse(body['lawsuit']);
    }
    return await _makeRequest('POST', ApiConfig.financialClaimsEndpoint, body: body);
  }

  Future<Map<String, dynamic>> updateFinancialClaim(int id, Map<String, dynamic> claimData) async {
    return await _makeRequest('PATCH', '${ApiConfig.financialClaimsEndpoint}$id/', body: claimData);
  }

  Future<void> deleteFinancialClaim(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.financialClaimsEndpoint}$id/');
  }

  // ========== Case File Items API (ملف القضية) ==========

  Future<dynamic> getCaseFileItems({int? lawsuitId}) async {
    String endpoint = ApiConfig.caseFileItemsEndpoint;
    if (lawsuitId != null) {
      endpoint += '?lawsuit=$lawsuitId';
    }
    return await _makeRequest('GET', endpoint);
  }

  Future<Map<String, dynamic>> getCaseFileByLawsuit(int lawsuitId) async {
    return await _makeRequest('GET', '${ApiConfig.caseFileItemsEndpoint}by_lawsuit/?lawsuit=$lawsuitId');
  }

  Future<Map<String, dynamic>> createCaseFileItem(Map<String, dynamic> data) async {
    return await _makeRequest('POST', ApiConfig.caseFileItemsEndpoint, body: data);
  }

  Future<Map<String, dynamic>> uploadCaseFileItem({
    required int lawsuitId,
    required String filePath,
    required String itemType,
    required String title,
    String? description,
  }) async {
    return await _makeRequest(
      'POST',
      ApiConfig.caseFileItemsEndpoint,
      body: {
        'lawsuit': lawsuitId.toString(),
        'item_type': itemType,
        'title': title,
        if (description != null) 'description': description,
      },
      files: {'file': filePath},
    );
  }

  Future<void> deleteCaseFileItem(int id) async {
    await _makeRequest('DELETE', '${ApiConfig.caseFileItemsEndpoint}$id/');
  }

  Future<Map<String, dynamic>> syncCaseFileFromAttachments(int lawsuitId) async {
    return await _makeRequest(
      'POST',
      '${ApiConfig.caseFileItemsEndpoint}sync_from_attachments/',
      body: {'lawsuit': lawsuitId},
    );
  }

  // ========== Courts API ==========
  
  // Governorates
  Future<Map<String, dynamic>> getGovernorates({Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.governoratesEndpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Districts
  Future<Map<String, dynamic>> getDistricts({int? governorateId, Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.districtsEndpoint;
    final params = <String, String>{};
    if (governorateId != null) {
      params['governorate'] = governorateId.toString();
    }
    if (queryParams != null) {
      params.addAll(queryParams);
    }
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Courts
  Future<Map<String, dynamic>> getCourts({Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.courtsEndpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // ========== Laws API ==========
  
  // Legal Categories
  Future<Map<String, dynamic>> getLegalCategories({Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.legalCategoriesEndpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Laws
  Future<Map<String, dynamic>> getLaws({int? categoryId, Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.lawsEndpoint;
    final params = <String, String>{};
    if (categoryId != null) {
      params['category'] = categoryId.toString();
    }
    if (queryParams != null) {
      params.addAll(queryParams);
    }
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Law Articles
  Future<Map<String, dynamic>> getLawArticles({int? sectionId, Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.lawArticlesEndpoint;
    final params = <String, String>{};
    if (sectionId != null) {
      params['section'] = sectionId.toString();
    }
    if (queryParams != null) {
      params.addAll(queryParams);
    }
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Search Laws
  Future<Map<String, dynamic>> searchLaws(String query) async {
    return await getLaws(queryParams: {'search': query});
  }

  // ========== Legal Library API (Full-Text Search) ==========
  
  /// Get legal articles with optional search and filters
  Future<Map<String, dynamic>> getLegalLibrary({
    String? searchQuery,
    String? source,
    String? book,
    String? section,
    String? chapter,
    String? branch,
    String? articleNumber,
    String? ordering,
    int? page,
  }) async {
    String endpoint = '/api/legal-library/';
    final params = <String, String>{};
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      params['q'] = searchQuery;
    }
    if (source != null && source.isNotEmpty) {
      params['source'] = source;
    }
    if (book != null && book.isNotEmpty) {
      params['book'] = book;
    }
    if (section != null && section.isNotEmpty) {
      params['section'] = section;
    }
    if (chapter != null && chapter.isNotEmpty) {
      params['chapter'] = chapter;
    }
    if (branch != null && branch.isNotEmpty) {
      params['branch'] = branch;
    }
    if (articleNumber != null && articleNumber.isNotEmpty) {
      params['article_number'] = articleNumber;
    }
    if (ordering != null && ordering.isNotEmpty) {
      params['ordering'] = ordering;
    }
    if (page != null) {
      params['page'] = page.toString();
    }
    
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    
    return await _makeRequest('GET', endpoint);
  }
  
  /// Get legal article details
  Future<Map<String, dynamic>> getLegalArticle(int id) async {
    return await _makeRequest('GET', '/api/legal-library/$id/');
  }
  
  /// Get legal library sources (with article counts)
  Future<Map<String, dynamic>> getLegalLibrarySources() async {
    return await _makeRequest('GET', '/api/legal-library/sources/');
  }

  /// Get legal library books
  Future<Map<String, dynamic>> getLegalLibraryBooks({String? source}) async {
    String endpoint = '/api/legal-library/books/';
    if (source != null && source.isNotEmpty) {
      endpoint += '?source=${Uri.encodeComponent(source)}';
    }
    return await _makeRequest('GET', endpoint);
  }

  /// Get legal library chapters
  Future<Map<String, dynamic>> getLegalLibraryChapters({String? source, String? book}) async {
    String endpoint = '/api/legal-library/chapters/';
    final params = <String, String>{};
    if (source != null && source.isNotEmpty) {
      params['source'] = source;
    }
    if (book != null && book.isNotEmpty) {
      params['book'] = book;
    }
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }
  
  /// Search with highlighting
  Future<Map<String, dynamic>> searchLegalLibrary(String query) async {
    return await _makeRequest('GET', '/api/legal-library/search/?q=${Uri.encodeComponent(query)}');
  }
  
  /// Get legal library statistics
  Future<Map<String, dynamic>> getLegalLibraryStats() async {
    return await _makeRequest('GET', '/api/legal-library/stats/');
  }

  /// Get Law Books (from LawLibrary model)
  Future<Map<String, dynamic>> getLawBooks({String? searchQuery, String? category, int? page}) async {
    String endpoint = '/api/law-library-books/';
    final params = <String, String>{};
    if (searchQuery != null && searchQuery.isNotEmpty) params['q'] = searchQuery;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (page != null) params['page'] = page.toString();
    
    if (params.isNotEmpty) {
      endpoint += '?' + params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    }
    return await _makeRequest('GET', endpoint);
  }

  /// Get Law Book categories
  Future<Map<String, dynamic>> getLawBookCategories() async {
    return await _makeRequest('GET', '/api/law-library-books/categories/');
  }

  
  // ========== Logs API ==========
  
  // User Sessions
  Future<Map<String, dynamic>> getUserSessions({Map<String, String>? queryParams}) async {
    String endpoint = ApiConfig.userSessionsEndpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Search Logs
  Future<Map<String, dynamic>> createSearchLog(String searchQuery, {int? resultsCount}) async {
    return await _makeRequest(
      'POST',
      ApiConfig.searchLogsEndpoint,
      body: {
        'search_query': searchQuery,
        if (resultsCount != null) 'results_count': resultsCount,
      },
    );
  }

  // AI Chat Logs
  Future<Map<String, dynamic>> createAIChatLog(String question, String answer, {String? modelVersion}) async {
    return await _makeRequest(
      'POST',
      ApiConfig.aiChatLogsEndpoint,
      body: {
        'question': question,
        'answer': answer,
        if (modelVersion != null) 'model_version': modelVersion,
      },
    );
  }

  // ========== Inquiries API ==========
  
  // Search lawsuit by case number
  Future<Map<String, dynamic>> searchLawsuitByCaseNumber(String caseNumber) async {
    return await getLawsuits(queryParams: {'case_number': caseNumber});
  }

  // ========== Contact & Complaints API ==========
  
  // Submit contact message (Note: This might need a custom endpoint in Django)
  Future<Map<String, dynamic>> submitContactMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    // TODO: Create this endpoint in Django if it doesn't exist
    // For now, we'll use a placeholder
    return await _makeRequest(
      'POST',
      '/api/contact/', // This endpoint needs to be created
      body: {
        'name': name,
        'email': email,
        'subject': subject,
        'message': message,
      },
    );
  }

  // Submit complaint (Note: This might need a custom endpoint in Django)
  Future<Map<String, dynamic>> submitComplaint({
    required String subject,
    required String description,
  }) async {
    // TODO: Create this endpoint in Django if it doesn't exist
    // For now, we'll use a placeholder
    return await _makeRequest(
      'POST',
      '/api/complaints/', // This endpoint needs to be created
      body: {
        'subject': subject,
        'description': description,
      },
    );
  }

  // ========== Phone-First Auth API ==========

  /// فحص رقم الهاتف — هل مسجل في قاعدة البيانات؟
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    return await _makeRequest(
      'POST',
      ApiConfig.checkPhoneEndpoint,
      body: {'phone': phone},
    );
  }

  /// تسجيل سريع برقم الهاتف فقط + إرسال OTP
  Future<Map<String, dynamic>> quickRegister(String phone) async {
    return await _makeRequest(
      'POST',
      ApiConfig.quickRegisterEndpoint,
      body: {'phone': phone},
    );
  }

  /// التحقق من رمز OTP وتسجيل الدخول
  Future<Map<String, dynamic>> verifyOtpLogin(String phone, String code) async {
    return await _makeRequest(
      'POST',
      ApiConfig.verifyOtpLoginEndpoint,
      body: {'phone': phone, 'code': code},
    );
  }

  /// إرسال رمز OTP (إعادة إرسال)
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    return await _makeRequest(
      'POST',
      ApiConfig.sendOtpEndpoint,
      body: {'phone': phone},
    );
  }

  /// تعيين كلمة مرور جديدة (للمستخدمين الجدد بعد OTP)
  Future<Map<String, dynamic>> setPassword(String password, String confirmPassword) async {
    return await _makeRequest(
      'POST',
      ApiConfig.setPasswordEndpoint,
      body: {'password': password, 'confirm_password': confirmPassword},
    );
  }

  /// إعادة تعيين كلمة المرور عبر OTP (نسيت كلمة المرور)
  Future<Map<String, dynamic>> resetPasswordOtp(String phone, String code, String newPassword) async {
    return await _makeRequest(
      'POST',
      ApiConfig.resetPasswordEndpoint,
      body: {'phone': phone, 'code': code, 'new_password': newPassword},
    );
  }

  /// جلب الخدمات المتاحة حسب دور المستخدم (SaaS Pro)
  Future<Map<String, dynamic>> getMyServices() async {
    return await _makeRequest('GET', ApiConfig.myServicesEndpoint);
  }

  /// تسجيل استخدام خدمة (SaaS Pro)
  Future<Map<String, dynamic>> logServiceUsage(String serviceKey, {int durationSeconds = 0}) async {
    return await _makeRequest(
      'POST',
      ApiConfig.logServiceUsageEndpoint,
      body: {'service_key': serviceKey, 'duration_seconds': durationSeconds},
    );
  }

  // ========== Register API ==========
  
  // Register new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String role,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? nationalId,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/register/',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'role': role,
        if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
        if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
        if (nationalId != null && nationalId.isNotEmpty) 'national_id': nationalId,
      },
    );
  }

  // ========== Email Verification API ==========

  Future<Map<String, dynamic>> verifyEmail({
    required String phone,
    required String code,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/verify-email/',
      body: {'phone': phone, 'code': code},
    );
  }

  Future<Map<String, dynamic>> resendOtp({
    required String phone,
    String purpose = 'verify_email',
  }) async {
    return await _makeRequest(
      'POST',
      '/api/resend-otp/',
      body: {'phone': phone, 'purpose': purpose},
    );
  }

  // ========== Password Reset API ==========

  Future<Map<String, dynamic>> requestPasswordReset({
    required String phone,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/password-reset/',
      body: {'phone': phone},
    );
  }

  Future<Map<String, dynamic>> verifyResetOtp({
    required String phone,
    required String code,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/password-reset/verify/',
      body: {'phone': phone, 'code': code},
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    return await _makeRequest(
      'POST',
      '/api/password-reset/confirm/',
      body: {'phone': phone, 'code': code, 'new_password': newPassword},
    );
  }

  // ========== Subscribe API ==========
  
  // Subscribe to newsletter (Note: This might need a custom endpoint in Django)
  Future<Map<String, dynamic>> subscribe({
    required String email,
    String? name,
  }) async {
    // TODO: Create this endpoint in Django if it doesn't exist
    return await _makeRequest(
      'POST',
      '/api/subscribe/', // This endpoint needs to be created
      body: {
        'email': email,
        if (name != null) 'name': name,
      },
    );
  }

  // ========== Notifications API ==========
  
  // Get all notifications
  Future<Map<String, dynamic>> getNotifications({Map<String, String>? queryParams}) async {
    String endpoint = '/api/notifications/';
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }

  // Mark notification as read
  Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    return await _makeRequest(
      'PATCH',
      '/api/notifications/$notificationId/',
      body: {'is_read': true},
    );
  }

  // Mark all notifications as read
  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    return await _makeRequest(
      'POST',
      '/api/notifications/mark-all-read/',
    );
  }

  // Delete notification
  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    return await _makeRequest('DELETE', '/api/notifications/$notificationId/');
  }

  // ========== Legal Procedures Guide API ==========
  
  /// Get legal procedures
  Future<Map<String, dynamic>> getLegalProcedures(
      {int page = 1, String? search, String? source, String? level}) async {
    final params = <String, String>{
      'page': page.toString(),
    };
    if (search != null && search.isNotEmpty) params['q'] = search;
    if (source != null && source.isNotEmpty) params['source'] = source;
    if (level != null && level.isNotEmpty) params['level'] = level;

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
        
    String endpoint = '/api/legal-procedures/';
    if (search != null && search.isNotEmpty) {
       endpoint = '/api/legal-procedures/search/';
    }
    
    endpoint += '?$queryString';

    return await _makeRequest('GET', endpoint);
  }

  /// Get legal procedures sources
  Future<Map<String, dynamic>> getLegalProceduresSources() async {
    return await _makeRequest('GET', '/api/legal-procedures/sources/');
  }

  /// Get AI chat logs
  Future<Map<String, dynamic>> getAIChatLogs({Map<String, String>? queryParams}) async {
    String endpoint = '/api/ai-chat-logs/';
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      endpoint += '?$queryString';
    }
    return await _makeRequest('GET', endpoint);
  }
}


