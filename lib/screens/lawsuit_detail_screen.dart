import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../providers/lawsuit_provider.dart';
import '../providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/lawsuit_model.dart';
import '../models/party_model.dart';
import '../config/api_config.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../presentation/widgets/party_display_row.dart';
import '../presentation/widgets/party_input_row.dart';
import '../theme/app_colors.dart';
import '../utils/attachment_utils.dart';

/// Lawsuit Detail Screen - Updated to support legal templates
class LawsuitDetailScreen extends StatefulWidget {
  final int? lawsuitId;
  final int? parentLawsuitId;

  const LawsuitDetailScreen({super.key, this.lawsuitId, this.parentLawsuitId});

  @override
  State<LawsuitDetailScreen> createState() => _LawsuitDetailScreenState();
}

class _LawsuitDetailScreenState extends State<LawsuitDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _caseNumberController;
  late TextEditingController _subjectController;
  late TextEditingController _descriptionController;
  
  // Legal text controllers (dynamic based on case type)
  final Map<String, TextEditingController> _legalTextControllers = {};
  
  // Rich text controllers for facts, legal reasons, and requests
  late TextEditingController _factsController;
  late TextEditingController _legalReasonsController;
  late TextEditingController _requestsController;
  
  // Date controllers
  late TextEditingController _hijriDateController;
  
  String? _selectedCaseType;
  String? _selectedCaseStatus;
  String? _selectedGovernorate;
  int? _selectedGovernorateId; // إضافة ID المحافظة
  int? _selectedCourtId;
  DateTime? _filingDateGregorian;
  String? _filingDateHijri;
  
  // Lists for dropdowns
  List<Map<String, dynamic>> _governorates = [];
  List<Map<String, dynamic>> _courts = [];
  bool _isLoadingGovernorates = false;
  bool _isLoadingCourts = false;
  
  bool _isLoadingTemplates = false;
  Map<String, dynamic>? _templates;
  List<String> _templateKeys = [];
  
  // Parties data (now available in create mode too)
  List<Map<String, dynamic>> _plaintiffsData = []; // Local data for new lawsuit
  List<Map<String, dynamic>> _defendantsData = []; // Local data for new lawsuit
  List<PlaintiffModel> _plaintiffs = [];
  List<DefendantModel> _defendants = [];
  bool _isLoadingParties = false;
  
  // Attachments data
  List<Map<String, dynamic>> _attachments = [];
  List<Map<String, dynamic>> _attachmentsData = []; // Local data for new lawsuit
  bool _isLoadingAttachments = false;
  bool _isUploadingAttachment = false;
  
  bool get _isEditMode => widget.lawsuitId != null;

  @override
  void initState() {
    super.initState();
    _caseNumberController = TextEditingController();
    _subjectController = TextEditingController();
    _descriptionController = TextEditingController();
    _factsController = TextEditingController();
    _legalReasonsController = TextEditingController();
    _requestsController = TextEditingController();
    
    // Default case type
    _selectedCaseType = 'دعوى';
    _selectedCaseStatus = 'جديد';
    _filingDateGregorian = DateTime.now();
    _filingDateHijri = _convertToHijri(_filingDateGregorian!);
    _hijriDateController = TextEditingController(text: _filingDateHijri ?? '');
    
    // Initialize with one empty row for parties and attachments with default values
    if (!_isEditMode) {
      _plaintiffsData.add({
        'gender': 'ذكر',
        'nationality': 'يمني',
        'address': 'صنعاء',
      });
      _defendantsData.add({
        'gender': 'ذكر',
        'nationality': 'يمني',
        'address': 'صنعاء',
      });
      _attachmentsData.add({});
    }

    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLawsuit();
        _loadParties();
        _loadAttachments();
      });
    } else {
      // Load templates for default case type
      _loadTemplates(_selectedCaseType!);
    }
    
    // Load governorates only (courts will be loaded when governorate is selected)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGovernorates();
      // في وضع التعديل، سيتم تحميل المحاكم من _loadLawsuit
    });
  }

  @override
  void dispose() {
    _caseNumberController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _factsController.dispose();
    _legalReasonsController.dispose();
    _requestsController.dispose();
    _hijriDateController.dispose();
    for (var controller in _legalTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  String _convertToHijri(DateTime date) {
    try {
      final hijri = HijriCalendar.fromDate(date);
      return '${hijri.hYear}/${hijri.hMonth}/${hijri.hDay}';
    } catch (e) {
      return '';
    }
  }
  
  Future<void> _loadGovernorates() async {
    if (!mounted) return;
    
    // التحقق من تسجيل الدخول أولاً
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (kDebugMode) {
        developer.log('User not authenticated. Cannot load governorates.', name: 'LawsuitDetailScreen');
      }
      setState(() {
        _isLoadingGovernorates = false;
        _governorates = [];
      });
      return;
    }
    
    setState(() {
      _isLoadingGovernorates = true;
    });
    
    try {
      final response = await authProvider.apiService.getGovernorates();
      
      if (kDebugMode) {
        developer.log('🔍 [Governorates] Response type: ${response.runtimeType}', name: 'LawsuitDetailScreen');
        developer.log('🔍 [Governorates] Response keys: ${response is Map ? (response as Map).keys.toList() : 'N/A'}', name: 'LawsuitDetailScreen');
        developer.log('🔍 [Governorates] Full response: $response', name: 'LawsuitDetailScreen');
      }
      
      if (mounted) {
        List<dynamic>? data;
        
        // معالجة الاستجابة - قد تأتي كـ List مباشرة أو كـ Map مع 'results'
        if (response is List) {
          data = response as List<dynamic>;
          if (kDebugMode) {
            developer.log('✅ [Governorates] Response is List with ${data.length} items', name: 'LawsuitDetailScreen');
          }
        } else if (response is Map<String, dynamic>) {
          // معالجة الاستجابة - Pagination class المخصص يعيد: {"success": true, "data": {"results": [...]}, ...}
          // أو DRF standard: {"count": X, "next": null, "previous": null, "results": [...]}
          
          // الحالة 1: Pagination class المخصص (smartju.pagination.StandardResultsSetPagination)
          // الاستجابة: {"success": true, "data": {"count": X, "results": [...]}, ...}
          if (response.containsKey('data') && response['data'] is Map<String, dynamic>) {
            final dataMap = response['data'] as Map<String, dynamic>;
            if (dataMap.containsKey('results')) {
              final results = dataMap['results'];
              if (results is List) {
                data = results as List<dynamic>;
                if (kDebugMode) {
                  developer.log('✅ [Governorates] Found data.results with ${data.length} items (Custom Pagination)', name: 'LawsuitDetailScreen');
                }
              }
            }
          }
          // الحالة 2: DRF Standard Pagination
          // الاستجابة: {"count": X, "next": null, "previous": null, "results": [...]}
          else if (response.containsKey('results')) {
            final results = response['results'];
            if (results is List) {
              data = results as List<dynamic>;
              if (kDebugMode) {
                developer.log('✅ [Governorates] Found results key with ${data.length} items (DRF Standard)', name: 'LawsuitDetailScreen');
              }
            }
          }
          // الحالة 3: data مباشرة كـ List (غير متوقع لكن ممكن)
          else if (response.containsKey('data') && response['data'] is List) {
            data = response['data'] as List<dynamic>;
            if (kDebugMode) {
              developer.log('✅ [Governorates] Found data as List with ${data.length} items', name: 'LawsuitDetailScreen');
            }
          }
          // الحالة 4: لا توجد بيانات
          else {
            if (kDebugMode) {
              developer.log('⚠️ [Governorates] Response is Map but no results/data found', name: 'LawsuitDetailScreen');
              developer.log('⚠️ [Governorates] Map keys: ${response.keys.toList()}', name: 'LawsuitDetailScreen');
              developer.log('⚠️ [Governorates] Full response: $response', name: 'LawsuitDetailScreen');
            }
          }
        } else {
          if (kDebugMode) {
            developer.log('❌ [Governorates] Unexpected response type: ${response.runtimeType}', name: 'LawsuitDetailScreen');
            developer.log('❌ [Governorates] Response value: $response', name: 'LawsuitDetailScreen');
          }
        }
        
        if (kDebugMode) {
          developer.log('📊 [Governorates] Final data count: ${data?.length ?? 0}', name: 'LawsuitDetailScreen');
        }
        
        final mappedGovernorates = (data ?? []).map((e) {
          try {
            return {
              'id': e['id'],
              'name': e['name'] ?? '',
              'courts': e['courts'] ?? [], // حفظ المحاكم مع كل محافظة
              'courts_count': e['courts_count'] ?? 0,
            };
          } catch (err) {
            developer.log('Error mapping governorate: $err', name: 'LawsuitDetailScreen');
            return null;
          }
        }).where((e) => e != null).cast<Map<String, dynamic>>().toList();
        
        setState(() {
          _governorates = mappedGovernorates;
          _isLoadingGovernorates = false;
        });
        
        if (kDebugMode) {
          if (_governorates.isEmpty) {
            developer.log('Warning: No governorates loaded. Response type: ${response.runtimeType}', name: 'LawsuitDetailScreen');
            developer.log('Response: $response', name: 'LawsuitDetailScreen');
          } else {
            developer.log('Successfully loaded ${_governorates.length} governorates', name: 'LawsuitDetailScreen');
          }
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error loading governorates: $e\n$stackTrace', name: 'LawsuitDetailScreen');
      if (mounted) {
        setState(() {
          _isLoadingGovernorates = false;
          // في حالة الخطأ، تأكد من أن القائمة فارغة
          if (_governorates.isEmpty) {
            // قد يكون المستخدم غير مسجل دخول أو هناك خطأ في الاتصال
            developer.log('No governorates loaded. Error: $e', name: 'LawsuitDetailScreen');
          }
        });
      }
    }
  }
  
  Future<void> _loadCourts({int? governorateId}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingCourts = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // إذا تم تحديد محافظة، استخدم المحاكم من استجابة المحافظة
      if (governorateId != null) {
        // البحث عن المحافظة في القائمة المحملة
        final governorate = _governorates.firstWhere(
          (gov) => gov['id'] == governorateId,
          orElse: () => {},
        );
        
        if (governorate.isNotEmpty && governorate['courts'] != null) {
          // استخدام المحاكم من استجابة المحافظة
          final courtsData = governorate['courts'] as List?;
          if (mounted) {
            setState(() {
              _courts = (courtsData ?? []).map((e) => {
                'id': e['id'],
                'name': e['name'] ?? '',
              }).toList();
              _isLoadingCourts = false;
              // إعادة تعيين المحكمة المختارة إذا لم تكن موجودة في القائمة الجديدة
              if (_selectedCourtId != null && 
                  !_courts.any((c) => c['id'] == _selectedCourtId)) {
                _selectedCourtId = null;
              }
            });
          }
          return;
        }
      }
      
      // إذا لم تكن المحاكم متوفرة من المحافظة، جلبها من API
      Map<String, String>? queryParams;
      if (governorateId != null) {
        queryParams = {'governorate': governorateId.toString()};
      }
      
      final response = await authProvider.apiService.getCourts(queryParams: queryParams);
      
      if (mounted) {
        List<dynamic>? data;
        if (response is Map<String, dynamic>) {
          if (response['results'] != null) {
            data = response['results'] as List?;
          }
        }
        
        setState(() {
          _courts = (data ?? []).map((e) => {
            'id': e['id'],
            'name': e['court_name'] ?? e['name'] ?? '',
          }).toList();
          _isLoadingCourts = false;
          // إعادة تعيين المحكمة المختارة إذا لم تكن موجودة في القائمة الجديدة
          if (_selectedCourtId != null && 
              !_courts.any((c) => c['id'] == _selectedCourtId)) {
            _selectedCourtId = null;
          }
        });
      }
    } catch (e) {
      developer.log('Error loading courts: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        setState(() {
          _isLoadingCourts = false;
        });
      }
    }
  }

  Future<void> _loadLawsuit() async {
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    await provider.loadLawsuit(widget.lawsuitId!);
    final lawsuit = provider.selectedLawsuit;
    if (lawsuit != null) {
      // انتظار تحميل المحافظات أولاً
      if (_governorates.isEmpty) {
        await _loadGovernorates();
      }
      
      _caseNumberController.text = lawsuit.caseNumber;
      _subjectController.text = lawsuit.subject ?? '';
      _descriptionController.text = lawsuit.description ?? '';
      
      // Safe assignment for Case Type Dropdown
      const validCaseTypes = ['امر_اداء', 'دعوى', 'رد_على_دعوى', 'استئناف', 'طعن', 'civil', 'criminal', 'commercial', 'administrative', 'family'];
      _selectedCaseType = validCaseTypes.contains(lawsuit.caseType) ? lawsuit.caseType : 'دعوى';
      
      _selectedCaseStatus = lawsuit.caseStatus ?? 'جديد';
      _selectedGovernorate = lawsuit.governorate;
      
      // البحث عن ID المحافظة من القائمة المحملة
      if (_selectedGovernorate != null) {
        final selectedGov = _governorates.firstWhere(
          (gov) => gov['name'] == _selectedGovernorate,
          orElse: () => {},
        );
        _selectedGovernorateId = selectedGov['id'] as int?;
        // تحميل المحاكم الخاصة بالمحافظة
        if (_selectedGovernorateId != null) {
          await _loadCourts(governorateId: _selectedGovernorateId);
        }
      }
      _selectedCourtId = lawsuit.courtId;
      _filingDateGregorian = lawsuit.filingDate;
      if (_filingDateGregorian != null) {
        _filingDateHijri = _convertToHijri(_filingDateGregorian!);
        _hijriDateController.text = _filingDateHijri ?? '';
      }
      
      // Populate rich text fields
      _factsController.text = lawsuit.facts ?? '';
      _legalReasonsController.text = lawsuit.legalReasons ?? '';
      _requestsController.text = lawsuit.requests ?? '';
      
      // Load templates and populate legal text fields
      await _loadTemplates(_selectedCaseType!);
      
      // Populate legal text fields from lawsuit (for template-based fields)
      if (lawsuit.facts != null && _legalTextControllers.containsKey('facts')) {
        _legalTextControllers['facts']!.text = lawsuit.facts!;
      }
      if (lawsuit.legalBasis != null && _legalTextControllers.containsKey('legal')) {
        _legalTextControllers['legal']!.text = lawsuit.legalBasis!;
      }
      if (lawsuit.requests != null && _legalTextControllers.containsKey('requests')) {
        _legalTextControllers['requests']!.text = lawsuit.requests!;
      }
    }
  }

  Future<void> _loadParties() async {
    if (widget.lawsuitId == null || !mounted) return;
    
    if (mounted) {
      setState(() {
        _isLoadingParties = true;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final plaintiffsResponse = await authProvider.apiService.getPlaintiffs(
        lawsuitId: widget.lawsuitId,
      );
      final defendantsResponse = await authProvider.apiService.getDefendants(
        lawsuitId: widget.lawsuitId,
      );

      developer.log('Plaintiffs response: $plaintiffsResponse', name: 'LawsuitDetailScreen');
      developer.log('Defendants response: $defendantsResponse', name: 'LawsuitDetailScreen');

      if (mounted) {
        // Handle different response structures: could be {'results': [...]} or {'data': {'results': [...]}}
        List<dynamic>? plaintiffsData;
        if (plaintiffsResponse['results'] != null) {
          plaintiffsData = plaintiffsResponse['results'] as List?;
        } else if (plaintiffsResponse['data'] != null && plaintiffsResponse['data'] is Map) {
          plaintiffsData = (plaintiffsResponse['data'] as Map<String, dynamic>)['results'] as List?;
        }
        
        final plaintiffsList = (plaintiffsData ?? [])
            .map((json) {
              try {
                return PlaintiffModel.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                developer.log('Error parsing plaintiff: $e, json: $json', name: 'LawsuitDetailScreen');
                return null;
              }
            })
            .whereType<PlaintiffModel>()
            .toList();
        
        // Handle different response structures for defendants
        List<dynamic>? defendantsData;
        if (defendantsResponse['results'] != null) {
          defendantsData = defendantsResponse['results'] as List?;
        } else if (defendantsResponse['data'] != null && defendantsResponse['data'] is Map) {
          defendantsData = (defendantsResponse['data'] as Map<String, dynamic>)['results'] as List?;
        }
        
        final defendantsList = (defendantsData ?? [])
            .map((json) {
              try {
                return DefendantModel.fromJson(json as Map<String, dynamic>);
              } catch (e) {
                developer.log('Error parsing defendant: $e, json: $json', name: 'LawsuitDetailScreen');
                return null;
              }
            })
            .whereType<DefendantModel>()
            .toList();
        
        developer.log('Parsed ${plaintiffsList.length} plaintiffs and ${defendantsList.length} defendants from server', name: 'LawsuitDetailScreen');

        setState(() {
          // Merge server data with local data to avoid losing newly added parties
          // On initial load (_plaintiffs and _defendants are empty), use server data directly
          // On subsequent loads (after adding parties), merge to preserve newly added ones
          
          final isInitialLoad = _plaintiffs.isEmpty && _defendants.isEmpty;
          
          if (isInitialLoad) {
            // Initial load: use server data directly
            developer.log('Initial load: using server data directly', name: 'LawsuitDetailScreen');
            _plaintiffs = plaintiffsList;
            _defendants = defendantsList;
          } else {
            // Subsequent load: merge server data with local data
            // If server returned empty lists but we have local data, don't overwrite
            if (plaintiffsList.isEmpty && _plaintiffs.isNotEmpty) {
              developer.log('Server returned empty plaintiffs but we have local data, keeping local', name: 'LawsuitDetailScreen');
              // Keep local data, don't overwrite
            } else {
              // For plaintiffs: merge by ID, keeping local ones that aren't in server response
              final serverPlaintiffIds = plaintiffsList.map((p) => p.id).whereType<int>().toSet();
              final serverPlaintiffNames = plaintiffsList.map((p) => p.name.toLowerCase().trim()).toSet();
              
              // Start with server data (most up-to-date)
              final mergedPlaintiffs = <PlaintiffModel>[...plaintiffsList];
              
              // Add local parties that aren't in server response yet (newly added, pending sync)
              for (var localPlaintiff in _plaintiffs) {
                final hasId = localPlaintiff.id != null;
                final idNotInServer = hasId && !serverPlaintiffIds.contains(localPlaintiff.id);
                final nameNotInServer = !serverPlaintiffNames.contains(localPlaintiff.name.toLowerCase().trim());
                
                // Keep if: has ID but not in server, OR no ID and name not in server (newly added, pending)
                if (idNotInServer || (!hasId && nameNotInServer)) {
                  mergedPlaintiffs.add(localPlaintiff);
                }
              }
              
              _plaintiffs = mergedPlaintiffs;
            }
            
            // Same for defendants
            if (defendantsList.isEmpty && _defendants.isNotEmpty) {
              developer.log('Server returned empty defendants but we have local data, keeping local', name: 'LawsuitDetailScreen');
              // Keep local data, don't overwrite
            } else {
              final serverDefendantIds = defendantsList.map((d) => d.id).whereType<int>().toSet();
              final serverDefendantNames = defendantsList.map((d) => d.name.toLowerCase().trim()).toSet();
              
              final mergedDefendants = <DefendantModel>[...defendantsList];
              
              for (var localDefendant in _defendants) {
                final hasId = localDefendant.id != null;
                final idNotInServer = hasId && !serverDefendantIds.contains(localDefendant.id);
                final nameNotInServer = !serverDefendantNames.contains(localDefendant.name.toLowerCase().trim());
                
                if (idNotInServer || (!hasId && nameNotInServer)) {
                  mergedDefendants.add(localDefendant);
                }
              }
              
              _defendants = mergedDefendants;
            }
          }
          
          _isLoadingParties = false;
        });
        
        developer.log('Loaded ${_plaintiffs.length} plaintiffs and ${_defendants.length} defendants', name: 'LawsuitDetailScreen');
      }
    } catch (e, stackTrace) {
      developer.log('Error loading parties: $e', name: 'LawsuitDetailScreen');
      developer.log('Stack trace: $stackTrace', name: 'LawsuitDetailScreen');
      if (mounted) {
        setState(() {
          // Don't clear existing lists on error - keep what we have
          _isLoadingParties = false;
        });
        
        // Extract error message
        String errorMessage = e.toString();
        // Remove "Exception: " prefix if present
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        
        // Only show error if lists are empty (initial load failed)
        // If we have local data, the error might be from a background sync
        if (_plaintiffs.isEmpty && _defendants.isEmpty) {
          final errorStr = errorMessage.toLowerCase();
          IconData errorIcon = Icons.error_outline;
          Color errorColor = Colors.red;
          String displayMessage = 'خطأ في تحميل الأطراف';
          
          if (errorStr.contains('socket') || 
              errorStr.contains('network') ||
              errorStr.contains('connection')) {
            displayMessage = 'لا يوجد اتصال بالإنترنت\nيرجى التحقق من اتصال الإنترنت';
            errorIcon = Icons.wifi_off;
            errorColor = Colors.orange.shade700;
          } else if (errorStr.contains('timeout')) {
            displayMessage = 'انتهت مهلة الاتصال\nيرجى المحاولة مرة أخرى';
            errorIcon = Icons.wifi_off;
            errorColor = Colors.orange.shade700;
          } else {
            displayMessage = 'خطأ في تحميل الأطراف\n$errorMessage';
            if (displayMessage.length > 150) {
              displayMessage = 'خطأ في تحميل الأطراف\nيرجى المحاولة مرة أخرى';
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
                      displayMessage,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: errorColor,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              action: SnackBarAction(
                label: 'إعادة المحاولة',
                textColor: Colors.white,
                onPressed: () {
                  _loadParties();
                },
              ),
            ),
          );
        } else {
          // We have local data, so this might be a background sync error
          // Show a less intrusive message
          developer.log('Background sync failed but we have local data', name: 'LawsuitDetailScreen');
        }
      }
    }
  }

  Future<void> _loadTemplates(String caseType) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingTemplates = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await authProvider.apiService.getLawsuitTemplates(caseType);
      
      if (mounted) {
        setState(() {
          _templates = response;
          _templateKeys = (response['templates'] as List)
              .map((t) => t['section_key'] as String)
              .toList();
          
          // Create controllers for each template
          for (var template in response['templates']) {
            final key = template['section_key'] as String;
            if (!_legalTextControllers.containsKey(key)) {
              _legalTextControllers[key] = TextEditingController(
                text: template['default_text'] as String? ?? '',
              );
            }
          }
        });
      }
    } catch (e) {
      developer.log('Error loading templates: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        final errorStr = e.toString().toLowerCase();
        String errorMessage = 'خطأ في تحميل النصوص القانونية';
        IconData errorIcon = Icons.warning_amber_rounded;
        Color errorColor = Colors.orange.shade700;
        
        if (errorStr.contains('socket') || 
            errorStr.contains('network') ||
            errorStr.contains('connection')) {
          errorMessage = 'لا يوجد اتصال بالإنترنت\nلا يمكن تحميل النصوص القانونية';
          errorIcon = Icons.wifi_off;
        } else if (errorStr.contains('timeout')) {
          errorMessage = 'انتهت مهلة الاتصال\nيرجى المحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
        } else {
          String cleanError = e.toString().replaceAll('Exception: ', '');
          if (cleanError.length > 100) {
            errorMessage = 'خطأ في تحميل النصوص القانونية\nيرجى المحاولة مرة أخرى';
          } else {
            errorMessage = 'خطأ في تحميل النصوص القانونية: $cleanError';
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
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTemplates = false;
        });
      }
    }
  }

  void _onCaseTypeChanged(String? value) {
    setState(() {
      _selectedCaseType = value;
    });
    if (value != null) {
      _loadTemplates(value);
    }
  }

  Future<void> _saveLawsuit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    
    // Build legal texts from controllers (prioritize rich text controllers)
    String? facts = _factsController.text.trim().isNotEmpty 
        ? _factsController.text.trim() 
        : (_legalTextControllers.containsKey('facts') 
            ? _legalTextControllers['facts']!.text.trim() 
            : null);
    String? legalBasis = _legalTextControllers.containsKey('legal')
        ? _legalTextControllers['legal']!.text.trim()
        : null;
    String? legalReasons = _legalReasonsController.text.trim().isNotEmpty
        ? _legalReasonsController.text.trim()
        : null;
    String? requests = _requestsController.text.trim().isNotEmpty
        ? _requestsController.text.trim()
        : (_legalTextControllers.containsKey('requests')
            ? _legalTextControllers['requests']!.text.trim()
            : null);
    
    // Convert hijri date if needed
    String? hijriDate = _filingDateHijri;
    if (_filingDateGregorian != null && (hijriDate == null || hijriDate.isEmpty)) {
      hijriDate = _convertToHijri(_filingDateGregorian!);
    }
    
    String caseNumber = _caseNumberController.text.trim();
    if (caseNumber.isEmpty) {
      caseNumber = 'Q-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    }
    
    final lawsuit = LawsuitModel(
      id: widget.lawsuitId,
      caseNumber: caseNumber,
      caseType: _selectedCaseType!,
      caseStatus: _selectedCaseStatus,
      subject: _subjectController.text.trim().isEmpty 
          ? null 
          : _subjectController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      facts: facts?.isEmpty ?? true ? null : facts,
      legalBasis: legalBasis?.isEmpty ?? true ? null : legalBasis,
      legalReasons: legalReasons?.isEmpty ?? true ? null : legalReasons,
      requests: requests?.isEmpty ?? true ? null : requests,
      governorate: _selectedGovernorate,
      filingDate: _filingDateGregorian ?? DateTime.now(),
      gregorianDate: _filingDateGregorian,
      hijriDate: hijriDate,
      courtId: _selectedCourtId,
      parentLawsuitId: widget.parentLawsuitId,
    );

    if (_isEditMode) {
      final success = await provider.updateLawsuit(widget.lawsuitId!, lawsuit);
      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الدعوى بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        final errorMessage = provider.errorMessage ?? 'حدث خطأ في تحديث الدعوى';
        final errorStr = errorMessage.toLowerCase();
        IconData errorIcon = Icons.error_outline;
        Color errorColor = Colors.red;
        String displayMessage = errorMessage;
        
        if (errorStr.contains('لا يوجد اتصال') || 
            errorStr.contains('network') ||
            errorStr.contains('connection')) {
          displayMessage = 'لا يوجد اتصال بالإنترنت\nيرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('انتهت مهلة') || 
                   errorStr.contains('timeout')) {
          displayMessage = 'انتهت مهلة الاتصال\nيرجى المحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(errorIcon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayMessage,
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
    } else {
      // Create new lawsuit
      final createdLawsuit = await provider.createLawsuit(lawsuit);
      if (createdLawsuit != null && createdLawsuit.id != null && mounted) {
        // Save parties if any
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        try {
          // Save plaintiffs
          for (var plaintiffData in _plaintiffsData) {
            if (plaintiffData['name'] != null && (plaintiffData['name'] as String).isNotEmpty) {
              await authProvider.apiService.createPlaintiff({
                'lawsuit': createdLawsuit.id!,
                'name': plaintiffData['name'],
                'gender': plaintiffData['gender'] == 'ذكر' ? 'male' : 'female',
                'nationality': plaintiffData['nationality'] ?? '',
                'occupation': plaintiffData['occupation'],
                'address': plaintiffData['address'] ?? '',
                'phone': plaintiffData['phone'],
                'attorney_name': plaintiffData['attorney_name'],
              });
            }
          }
          
          // Save defendants
          for (var defendantData in _defendantsData) {
            if (defendantData['name'] != null && (defendantData['name'] as String).isNotEmpty) {
              await authProvider.apiService.createDefendant({
                'lawsuit': createdLawsuit.id!,
                'name': defendantData['name'],
                'gender': defendantData['gender'] == 'ذكر' ? 'male' : 'female',
                'nationality': defendantData['nationality'] ?? '',
                'occupation': defendantData['occupation'],
                'address': defendantData['address'] ?? '',
                'phone': defendantData['phone'],
                'attorney_name': defendantData['attorney_name'],
              });
            }
          }
        } catch (e) {
          developer.log('Error saving parties: $e', name: 'LawsuitDetailScreen');
        }
        
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LawsuitDetailScreen(lawsuitId: createdLawsuit.id!),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الدعوى بنجاح. يمكنك الآن إضافة المستندات'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        // PREVENT CLOSING THE SCREEN ON FAILURE so user doesn't lose data
        // Navigator.pop(context); // Removed this line

        final errorMessage = provider.errorMessage ?? 'حدث خطأ في إنشاء الدعوى';
        final errorStr = errorMessage.toLowerCase();
        IconData errorIcon = Icons.error_outline;
        Color errorColor = Colors.red;
        String displayMessage = errorMessage;
        
        // Better error parsing for common backend errors
        if (errorStr.contains('400') || errorStr.contains('bad request')) {
          displayMessage = 'البيانات المدخلة غير صحيحة. يرجى مراجعة الحقول.';
          if (errorStr.contains('already exists') || errorStr.contains('موجود مسبقاً')) {
            displayMessage = 'رقم الدعوى موجود مسبقاً. يرجى استخدام رقم آخر.';
          }
          errorIcon = Icons.warning_amber_rounded;
        } else if (errorStr.contains('لا يوجد اتصال') || 
            errorStr.contains('network') ||
            errorStr.contains('connection')) {
          displayMessage = 'لا يوجد اتصال بالإنترنت\nيرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('انتهت مهلة') || 
                   errorStr.contains('timeout')) {
          displayMessage = 'انتهت مهلة الاتصال\nيرجى المحاولة مرة أخرى';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(errorIcon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayMessage,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'تعديل الدعوى' : 'إضافة دعوى جديدة'),
      ),
      body: _isEditMode
          ? Consumer<LawsuitProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.selectedLawsuit == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildForm();
              },
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 24.0 : 12.0,
        vertical: 16.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.description, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEditMode ? 'تعديل الدعوى' : 'إنشاء دعوى جديدة',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Parties Section (Plaintiffs and Defendants) - Now available in create mode
            _buildPartiesSection(),
            const SizedBox(height: 24),
            
            // Case Details Section
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'بيانات الدعوى',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            
            // Filing Dates
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: _filingDateGregorian != null
                                ? DateFormat('yyyy-MM-dd').format(_filingDateGregorian!)
                                : '',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'تاريخ تقديم الدعوى بالميلادي',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _filingDateGregorian ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                _filingDateGregorian = picked;
                                _filingDateHijri = _convertToHijri(picked);
                                _hijriDateController.text = _filingDateHijri ?? '';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _hijriDateController,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ تقديم الدعوى بالهجري',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                            hintText: '1447/09/22',
                          ),
                          onChanged: (value) {
                            _filingDateHijri = value;
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      TextFormField(
                        readOnly: true,
                        controller: TextEditingController(
                          text: _filingDateGregorian != null
                              ? DateFormat('yyyy-MM-dd').format(_filingDateGregorian!)
                              : '',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'تاريخ تقديم الدعوى بالميلادي',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filingDateGregorian ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppColors.brand, // Navy header
                                    onPrimary: Colors.white, // Text inside header
                                    onSurface: AppColors.brandDark, // Text on layout
                                    secondary: AppColors.gold,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.brand, // button text color
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _filingDateGregorian = picked;
                              _filingDateHijri = _convertToHijri(picked);
                              _hijriDateController.text = _filingDateHijri ?? '';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _hijriDateController,
                        decoration: const InputDecoration(
                          labelText: 'تاريخ تقديم الدعوى بالهجري',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                          hintText: '1447/09/22',
                        ),
                        onChanged: (value) {
                          _filingDateHijri = value;
                        },
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Case Type
            DropdownButtonFormField<String>(
              value: _selectedCaseType,
              decoration: const InputDecoration(
                labelText: 'نوع الدعوى',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'امر_اداء', child: Text('أمر أداء')),
                DropdownMenuItem(value: 'دعوى', child: Text('دعوى')),
                DropdownMenuItem(value: 'رد_على_دعوى', child: Text('رد على دعوى')),
                DropdownMenuItem(value: 'استئناف', child: Text('استئناف')),
                DropdownMenuItem(value: 'طعن', child: Text('طعن')),
                DropdownMenuItem(value: 'civil', child: Text('مدنية')),
                DropdownMenuItem(value: 'criminal', child: Text('جنائية')),
                DropdownMenuItem(value: 'commercial', child: Text('تجارية')),
                DropdownMenuItem(value: 'administrative', child: Text('إدارية')),
                DropdownMenuItem(value: 'personal_status', child: Text('أحوال شخصية')),
              ],
              onChanged: _onCaseTypeChanged,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى اختيار نوع الدعوى';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Governorate and Court
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // محاذاة من الأعلى
                    children: [
                      Expanded(
                        flex: 1, // مساحة متساوية
                        child: _isLoadingGovernorates
                            ? const Center(child: CircularProgressIndicator())
                            : _governorates.isEmpty
                                ? const Text('لا توجد محافظات متاحة', style: TextStyle(color: Colors.grey))
                                : DropdownButtonFormField<String>(
                                value: _governorates.any((g) => g['name'] == _selectedGovernorate) ? _selectedGovernorate : null,
                                isExpanded: true, // مهم: يضمن استخدام المساحة الكاملة
                                decoration: InputDecoration(
                                  labelText: 'المحافظة',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.location_city, size: 20), // تقليل حجم الأيقونة
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // تقليل padding
                                  isDense: true,
                                  constraints: const BoxConstraints(), // إزالة constraints الافتراضية
                                ),
                                menuMaxHeight: 300, // حد أقصى لارتفاع القائمة - مهم للويب
                                items: _governorates.map((gov) {
                                  return DropdownMenuItem(
                                    value: gov['name'] as String,
                                    child: Text(
                                      gov['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                selectedItemBuilder: (context) {
                                  // عرض النص المختار مع ellipsis - مهم لمنع overflow
                                  return _governorates.map((gov) {
                                    return SizedBox(
                                      width: double.infinity, // استخدام العرض الكامل
                                      child: Text(
                                        gov['name'] as String,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(fontSize: 13), // تقليل حجم الخط قليلاً
                                        softWrap: false,
                                      ),
                                    );
                                  }).toList();
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGovernorate = value;
                                    // البحث عن ID المحافظة المختارة
                                    final selectedGov = _governorates.firstWhere(
                                      (gov) => gov['name'] == value,
                                      orElse: () => {},
                                    );
                                    _selectedGovernorateId = selectedGov['id'] as int?;
                                    // إعادة تعيين المحكمة المختارة
                                    _selectedCourtId = null;
                                  });
                                  // تحميل المحاكم الخاصة بالمحافظة المختارة
                                  if (_selectedGovernorateId != null) {
                                    _loadCourts(governorateId: _selectedGovernorateId);
                                  } else {
                                    // إذا لم يتم العثور على المحافظة، مسح قائمة المحاكم
                                    setState(() {
                                      _courts = [];
                                    });
                                  }
                                },
                              ),
                      ),
                      const SizedBox(width: 12), // تقليل المسافة
                      Expanded(
                        flex: 1, // مساحة متساوية
                        child: _isLoadingCourts
                            ? const Center(child: CircularProgressIndicator())
                            : _courts.isEmpty && _selectedGovernorateId == null
                                ? const Text('اختر المحافظة أولاً', style: TextStyle(color: Colors.grey))
                                : _courts.isEmpty
                                    ? const Text('لا توجد محاكم متاحة', style: TextStyle(color: Colors.grey))
                                    : DropdownButtonFormField<int>(
                                value: _courts.any((c) => c['id'] == _selectedCourtId) ? _selectedCourtId : null,
                                isExpanded: true, // مهم: يضمن استخدام المساحة الكاملة
                                decoration: InputDecoration(
                                  labelText: 'المحكمة *',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.gavel, size: 20), // تقليل حجم الأيقونة
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // تقليل padding
                                  isDense: true, // يقلل من المساحة المستخدمة
                                  constraints: const BoxConstraints(), // إزالة constraints الافتراضية
                                ),
                                menuMaxHeight: 300, // حد أقصى لارتفاع القائمة
                                items: _courts.map((court) {
                                  return DropdownMenuItem(
                                    value: court['id'] as int,
                                    child: Text(
                                      court['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2, // سطرين للسماح بعرض أسماء طويلة
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                selectedItemBuilder: (context) {
                                  // عرض النص المختار مع ellipsis - مهم لمنع overflow
                                  return _courts.map((court) {
                                    return SizedBox(
                                      width: double.infinity, // استخدام العرض الكامل
                                      child: Text(
                                        court['name'] as String,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(fontSize: 13), // تقليل حجم الخط قليلاً
                                        softWrap: false,
                                      ),
                                    );
                                  }).toList();
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCourtId = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'يرجى ملء هذا الحقل';
                                  }
                                  return null;
                                },
                              ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _isLoadingGovernorates
                          ? const Center(child: CircularProgressIndicator())
                          : _governorates.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                                    const SizedBox(height: 8),
                                    const Text('لا توجد محافظات متاحة', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    TextButton.icon(
                                      onPressed: () => _loadGovernorates(),
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('إعادة المحاولة'),
                                    ),
                                  ],
                                )
                              : DropdownButtonFormField<String>(
                              value: _governorates.any((g) => g['name'] == _selectedGovernorate) ? _selectedGovernorate : null,
                              isExpanded: true, // مهم: يضمن استخدام المساحة الكاملة
                              decoration: InputDecoration(
                                labelText: 'المحافظة',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.location_city, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                isDense: true,
                                constraints: const BoxConstraints(),
                              ),
                              menuMaxHeight: 300, // حد أقصى لارتفاع القائمة - مهم للويب
                              items: _governorates.map((gov) {
                                return DropdownMenuItem(
                                  value: gov['name'] as String,
                                  child: Text(
                                    gov['name'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              selectedItemBuilder: (context) {
                                // عرض النص المختار مع ellipsis - مهم لمنع overflow
                                return _governorates.map((gov) {
                                  return SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      gov['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 13),
                                      softWrap: false,
                                    ),
                                  );
                                }).toList();
                              },
                              onChanged: (value) {
                                setState(() {
                                  _selectedGovernorate = value;
                                  // البحث عن ID المحافظة المختارة
                                  final selectedGov = _governorates.firstWhere(
                                    (gov) => gov['name'] == value,
                                    orElse: () => {},
                                  );
                                  _selectedGovernorateId = selectedGov['id'] as int?;
                                  // إعادة تعيين المحكمة المختارة
                                  _selectedCourtId = null;
                                });
                                // تحميل المحاكم الخاصة بالمحافظة المختارة
                                if (_selectedGovernorateId != null) {
                                  _loadCourts(governorateId: _selectedGovernorateId);
                                } else {
                                  // إذا لم يتم العثور على المحافظة، مسح قائمة المحاكم
                                  setState(() {
                                    _courts = [];
                                  });
                                }
                              },
                            ),
                      const SizedBox(height: 16),
                      _isLoadingCourts
                          ? const Center(child: CircularProgressIndicator())
                          : _courts.isEmpty && _selectedGovernorateId == null
                              ? const Text('اختر المحافظة أولاً', style: TextStyle(color: Colors.grey))
                              : _courts.isEmpty
                                  ? const Text('لا توجد محاكم متاحة', style: TextStyle(color: Colors.grey))
                                  : DropdownButtonFormField<int>(
                              value: _courts.any((c) => c['id'] == _selectedCourtId) ? _selectedCourtId : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'المحكمة *',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.gavel, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                isDense: true,
                                constraints: const BoxConstraints(),
                              ),
                              menuMaxHeight: 300,
                              items: _courts.map((court) {
                                return DropdownMenuItem(
                                  value: court['id'] as int,
                                  child: Text(
                                    court['name'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              selectedItemBuilder: (context) {
                                return _courts.map((court) {
                                  return SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      court['name'] as String,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 13),
                                      softWrap: false,
                                    ),
                                  );
                                }).toList();
                              },
                              onChanged: (value) {
                                setState(() {
                                  _selectedCourtId = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'يرجى ملء هذا الحقل';
                                }
                                return null;
                              },
                            ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            
            const SizedBox(height: 16),

            // Subject
            TextFormField(
              controller: _subjectController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'موضوع الدعوى',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
                helperText: 'الحد الأقصى 150 حرف',
              ),
              maxLength: 150,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return Text('$maxLength حرف متبقية');
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال موضوع الدعوى';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Facts of the Case (Rich Text Editor)
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'وقائع الدعوى',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            Text(
              'الحد الأقصى 150 حرف ${150 - _factsController.text.length} حرف متبقية',
              style: TextStyle(
                color: (150 - _factsController.text.length) < 0 ? Colors.red : Colors.green,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _factsController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'وقائع الدعوى',
                border: OutlineInputBorder(),
                hintText: 'أدخل وقائع الدعوى...',
              ),
              maxLines: 10,
              maxLength: 150,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),

            // Legal Reasons and Grounds (Rich Text Editor)
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'الاسباب والاسانيد القانونية',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _legalReasonsController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'الاسباب والاسانيد القانونية',
                border: OutlineInputBorder(),
                hintText: 'أدخل الأسباب والأسانيد القانونية...',
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 24),

            // Requests (Rich Text Editor)
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'طلبات الدعوى',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _requestsController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'طلبات الدعوى',
                border: OutlineInputBorder(),
                hintText: 'أدخل طلبات الدعوى...',
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 24),

            // Legal Templates Section (if available)
            if (_isLoadingTemplates)
              const Center(child: CircularProgressIndicator())
            else if (_templates != null && _templateKeys.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              ..._buildLegalTextFields(),
            ],

            const SizedBox(height: 24),

            // Attachments Section (now available in create mode too)
            if (!_isEditMode || widget.lawsuitId != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              _buildAttachmentsSection(),
              const SizedBox(height: 16),
            ],

            // Save button
            Consumer<LawsuitProvider>(
              builder: (context, provider, child) {
                return ElevatedButton.icon(
                  onPressed: (provider.isLoading || _isLoadingTemplates) ? null : _saveLawsuit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: provider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'حفظ التغييرات' : 'حفظ جميع البيانات',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLegalTextFields() {
    if (_templates == null) return [];
    
    final templates = _templates!['templates'] as List;
    final widgets = <Widget>[];
    
    widgets.add(
      const Divider(),
    );
    widgets.add(
      const Text(
        'النصوص القانونية',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
    widgets.add(const SizedBox(height: 16));
    
    for (var template in templates) {
      final key = template['section_key'] as String;
      final title = template['section_title'] as String;
      final isRequired = template['is_required'] as bool? ?? false;
      
      if (!_legalTextControllers.containsKey(key)) {
        _legalTextControllers[key] = TextEditingController(
          text: template['default_text'] as String? ?? '',
        );
      }
      
      widgets.add(
        TextFormField(
          controller: _legalTextControllers[key],
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: title + (isRequired ? ' *' : ''),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.gavel),
            helperText: 'يمكنك تعديل النص الافتراضي',
          ),
          maxLines: 8,
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'هذا الحقل إجباري';
                  }
                  return null;
                }
              : null,
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }
    
    return widgets;
  }

  Widget _buildPartiesSection() {
    // In create mode, use local data; in edit mode, use loaded parties
    final plaintiffsToShow = _isEditMode ? _plaintiffs : [];
    final defendantsToShow = _isEditMode ? _defendants : [];
    final plaintiffsDataToShow = _isEditMode ? [] : _plaintiffsData;
    final defendantsDataToShow = _isEditMode ? [] : _defendantsData;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Plaintiffs Section
        Text(
          'المدعون',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 60, child: Text('خيارات', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('اسم الوكيل', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('العنوان', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('رقم الهاتف', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('العمل', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('الجنس', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('الجنسية', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('اسم المدعى', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  // Table Rows
                  if (_isEditMode)
                    ...(_isLoadingParties && plaintiffsToShow.isEmpty
                        ? [const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )]
                        : plaintiffsToShow.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      const Text('لم يتم تحديد أي مدعين لهذه الدعوى بعد', style: TextStyle(color: Colors.grey)),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () => _showAddPartyDialog(isPlaintiff: true),
                                        icon: const Icon(Icons.person_add_outlined),
                                        label: const Text('أضف المدعي الأول الآن'),
                                      )
                                    ],
                                  ),
                                )
                              ]
                            : plaintiffsToShow.map((p) => PartyDisplayRow(
                                  party: p,
                                  isPlaintiff: true,
                                  onEdit: () => _showAddPartyDialog(isPlaintiff: true, party: p),
                                  onDelete: () => _deleteParty(p, isPlaintiff: true),
                                )).toList()),
                  if (!_isEditMode)
                    ...plaintiffsDataToShow.asMap().entries.map((entry) {
                      return PartyInputRow(
                        data: entry.value,
                        index: entry.key,
                        isPlaintiff: true,
                        onDelete: () {
                          setState(() {
                            _plaintiffsData.removeAt(entry.key);
                          });
                        },
                        onChanged: () => setState(() {}),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                if (_isEditMode) {
                  _showAddPartyDialog(isPlaintiff: true);
                } else {
                  _plaintiffsData.add({});
                }
              });
            },
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text('+ إضافة مدعي', style: TextStyle(color: Colors.white, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Defendants Section
        Text(
          'المدعى عليهم',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 80, child: Text('خيارات', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('اسم الوكيل', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('العنوان', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('رقم الهاتف', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('العمل', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('الجنس', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('الجنسية', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('اسم المدعى عليه', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  // Table Rows
                  if (_isEditMode)
                    ...(_isLoadingParties && defendantsToShow.isEmpty
                        ? [const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )]
                        : defendantsToShow.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      const Text('لم يتم تحديد أي مدعى عليهم لهذه الدعوى بعد', style: TextStyle(color: Colors.grey)),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () => _showAddPartyDialog(isPlaintiff: false),
                                        icon: const Icon(Icons.person_add_outlined),
                                        label: const Text('أضف المدعى عليه الأول الآن'),
                                      )
                                    ],
                                  ),
                                )
                              ]
                            : defendantsToShow.map((d) => PartyDisplayRow(
                                  party: d,
                                  isPlaintiff: false,
                                  onEdit: () => _showAddPartyDialog(isPlaintiff: false, party: d),
                                  onDelete: () => _deleteParty(d, isPlaintiff: false),
                                )).toList()),
                  if (!_isEditMode)
                    ...defendantsDataToShow.asMap().entries.map((entry) {
                      return PartyInputRow(
                        data: entry.value,
                        index: entry.key,
                        isPlaintiff: false,
                        onDelete: () {
                          setState(() {
                            _defendantsData.removeAt(entry.key);
                          });
                        },
                        onChanged: () => setState(() {}),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                if (_isEditMode) {
                  _showAddPartyDialog(isPlaintiff: false);
                } else {
                  _defendantsData.add({});
                }
              });
            },
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text('+ إضافة مدعى عليه', style: TextStyle(color: Colors.white, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  

  Widget _buildPartyCard(PartyModel party, {required bool isPlaintiff}) {
    return ListTile(
      title: Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الجنس: ${party.genderDisplay}'),
          Text('الجنسية: ${party.nationality}'),
          if (party.occupation != null) Text('المهنة: ${party.occupation}'),
          Text('العنوان: ${party.address}'),
          if (party.phone != null) Text('الهاتف: ${party.phone}'),
          if (party.attorneyName != null) Text('الوكيل: ${party.attorneyName}'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showAddPartyDialog(
              isPlaintiff: isPlaintiff,
              party: party,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteParty(party, isPlaintiff: isPlaintiff),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPartyDialog({
    required bool isPlaintiff,
    PartyModel? party,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: party?.name ?? '');
    final nationalityController = TextEditingController(text: party?.nationality ?? (party == null ? 'يمني' : ''));
    final occupationController = TextEditingController(text: party?.occupation ?? '');
    final addressController = TextEditingController(text: party?.address ?? '');
    final phoneController = TextEditingController(text: party?.phone ?? '');
    final attorneyNameController = TextEditingController(text: party?.attorneyName ?? '');
    final attorneyPhoneController = TextEditingController(text: party?.attorneyPhone ?? '');
    String? selectedGender = party?.gender ?? 'male';

    bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(party == null 
              ? (isPlaintiff ? 'إضافة مدعي' : 'إضافة مدعى عليه')
              : (isPlaintiff ? 'تعديل مدعي' : 'تعديل مدعى عليه')),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'الاسم *'),
                    validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(labelText: 'الجنس *'),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black),
                    items: const [
                      DropdownMenuItem(
                        value: 'male',
                        child: Text(
                          'ذكر',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text(
                          'أنثى',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        selectedGender = v;
                      });
                    },
                  ),
                TextFormField(
                  controller: nationalityController,
                  decoration: const InputDecoration(labelText: 'الجنسية *'),
                  validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: occupationController,
                  decoration: const InputDecoration(labelText: 'المهنة'),
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'العنوان *'),
                  maxLines: 2,
                  validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: attorneyNameController,
                  decoration: const InputDecoration(labelText: 'اسم الوكيل'),
                ),
                TextFormField(
                  controller: attorneyPhoneController,
                  decoration: const InputDecoration(labelText: 'هاتف الوكيل'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(party == null ? 'إضافة' : 'حفظ'),
          ),
        ],
        ),
      ),
    );
    
    // Save party data before disposing controllers
    final partyName = nameController.text;
    final partyGender = selectedGender!;
    final partyNationality = nationalityController.text;
    final partyOccupation = occupationController.text.isEmpty ? null : occupationController.text;
    final partyAddress = addressController.text;
    final partyPhone = phoneController.text.isEmpty ? null : phoneController.text;
    final partyAttorneyName = attorneyNameController.text.isEmpty ? null : attorneyNameController.text;
    final partyAttorneyPhone = attorneyPhoneController.text.isEmpty ? null : attorneyPhoneController.text;
    
    // Dispose controllers after dialog is fully closed
    // Use post-frame callback to ensure dialog widgets are completely disposed before disposing controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait one more frame to ensure all dialog widgets are fully disposed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
        nationalityController.dispose();
        occupationController.dispose();
        addressController.dispose();
        phoneController.dispose();
        attorneyNameController.dispose();
        attorneyPhoneController.dispose();
      });
    });
    
    // Save party if dialog returned true and widget is still mounted
    if (shouldSave == true && mounted) {
      await _saveParty(
        isPlaintiff: isPlaintiff,
        party: party,
        name: partyName,
        gender: partyGender,
        nationality: partyNationality,
        occupation: partyOccupation,
        address: partyAddress,
        phone: partyPhone,
        attorneyName: partyAttorneyName,
        attorneyPhone: partyAttorneyPhone,
      );
    }
  }

  Future<void> _saveParty({
    required bool isPlaintiff,
    PartyModel? party,
    required String name,
    required String gender,
    required String nationality,
    String? occupation,
    required String address,
    String? phone,
    String? attorneyName,
    String? attorneyPhone,
  }) async {
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final lawsuitId = widget.lawsuitId!;
      
      final partyData = {
        'lawsuit': lawsuitId,
        'name': name,
        'gender': gender,
        'nationality': nationality,
        if (occupation != null && occupation.isNotEmpty) 'occupation': occupation,
        'address': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (attorneyName != null && attorneyName.isNotEmpty) 'attorney_name': attorneyName,
        if (attorneyPhone != null && attorneyPhone.isNotEmpty) 'attorney_phone': attorneyPhone,
      };

      developer.log('Saving party: $partyData', name: 'LawsuitDetailScreen');

      Map<String, dynamic>? responseData;
      
      if (party == null) {
        // Create new party
        if (isPlaintiff) {
          final response = await authProvider.apiService.createPlaintiff(partyData);
          developer.log('Create plaintiff response: $response', name: 'LawsuitDetailScreen');
          responseData = response;
          
          // Add to local list immediately for better UX
          if (mounted && responseData != null) {
            try {
              final newPlaintiff = PlaintiffModel.fromJson(responseData);
              setState(() {
                _plaintiffs.add(newPlaintiff);
              });
            } catch (e) {
              developer.log('Error parsing new plaintiff: $e', name: 'LawsuitDetailScreen');
            }
          }
        } else {
          final response = await authProvider.apiService.createDefendant(partyData);
          developer.log('Create defendant response: $response', name: 'LawsuitDetailScreen');
          responseData = response;
          
          // Add to local list immediately for better UX
          if (mounted && responseData != null) {
            try {
              final newDefendant = DefendantModel.fromJson(responseData);
              setState(() {
                _defendants.add(newDefendant);
              });
            } catch (e) {
              developer.log('Error parsing new defendant: $e', name: 'LawsuitDetailScreen');
            }
          }
        }
      } else {
        // Update existing party
        if (isPlaintiff) {
          final response = await authProvider.apiService.updatePlaintiff(party.id!, partyData);
          developer.log('Update plaintiff response: $response', name: 'LawsuitDetailScreen');
          responseData = response;
          
          // Update local list immediately
          if (mounted && responseData != null) {
            try {
              final updatedPlaintiff = PlaintiffModel.fromJson(responseData);
              setState(() {
                final index = _plaintiffs.indexWhere((p) => p.id == party.id);
                if (index != -1) {
                  _plaintiffs[index] = updatedPlaintiff;
                }
              });
            } catch (e) {
              developer.log('Error parsing updated plaintiff: $e', name: 'LawsuitDetailScreen');
            }
          }
        } else {
          final response = await authProvider.apiService.updateDefendant(party.id!, partyData);
          developer.log('Update defendant response: $response', name: 'LawsuitDetailScreen');
          responseData = response;
          
          // Update local list immediately
          if (mounted && responseData != null) {
            try {
              final updatedDefendant = DefendantModel.fromJson(responseData);
              setState(() {
                final index = _defendants.indexWhere((d) => d.id == party.id);
                if (index != -1) {
                  _defendants[index] = updatedDefendant;
                }
              });
            } catch (e) {
              developer.log('Error parsing updated defendant: $e', name: 'LawsuitDetailScreen');
            }
          }
        }
      }

      // Show success message first
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(party == null 
                ? (isPlaintiff ? 'تم إضافة المدعي بنجاح' : 'تم إضافة المدعى عليه بنجاح')
                : 'تم التحديث بنجاح'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // For new parties: we already added them locally with the server response,
      // so no need to reload immediately. Only reload for updates to ensure sync.
      // We'll do a background sync after a longer delay to catch any edge cases.
      if (mounted) {
        if (party == null) {
          // New party: do a background sync after delay, but merging will preserve local data
          // This is just to ensure we're in sync with server, not to replace local data
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _loadParties().catchError((e) {
                developer.log('Error syncing parties: $e', name: 'LawsuitDetailScreen');
              });
            }
          });
        } else {
          // Updated party: reload after short delay to get latest data
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _loadParties().catchError((e) {
                developer.log('Error reloading parties: $e', name: 'LawsuitDetailScreen');
              });
            }
          });
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error saving party: $e', name: 'LawsuitDetailScreen');
      developer.log('Stack trace: $stackTrace', name: 'LawsuitDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الطرف: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteParty(PartyModel party, {required bool isPlaintiff}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف ${party.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (isPlaintiff) {
        await authProvider.apiService.deletePlaintiff(party.id!);
      } else {
        await authProvider.apiService.deleteDefendant(party.id!);
      }

      // Reload parties only if still mounted
      if (mounted) {
        await _loadParties();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحذف بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('Error deleting party: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildAttachmentsSection() {
    final attachmentsToShow = _isEditMode ? _attachments : [];
    final attachmentsDataToShow = _isEditMode ? [] : _attachmentsData;

    if (_isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مرفقات الدعوى (ترفق صورة من الوثائق)',
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          if (_isLoadingAttachments && attachmentsToShow.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (attachmentsToShow.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'لا توجد مرفقات',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ...attachmentsToShow.map((a) => _buildAttachmentCard(a)).toList(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddAttachmentDialog,
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text('+ إضافة مرفق', style: TextStyle(color: Colors.white, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مرفقات الدعوى (ترفق صورة من الوثائق)',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 60, child: Text('خيارات', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('عدد الصفحات', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 150, child: Text('مضمون المستند ووجه الاستدلال', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 120, child: Text('تاريخه هجري - ليس إجباري', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 120, child: Text('تاريخه ميلادي', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('نوع المستند', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  if (!_isEditMode)
                    ...attachmentsDataToShow.asMap().entries.map((entry) {
                      return _buildAttachmentRowData(entry.value, entry.key);
                    }).toList(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _attachmentsData.add({});
              });
            },
            icon: const Icon(Icons.add, color: Colors.white, size: 20),
            label: const Text('+ إضافة مرفق', style: TextStyle(color: Colors.white, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAttachmentRow(Map<String, dynamic> attachment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showEditAttachmentDialog(attachment),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteAttachment(attachment['id']),
                ),
              ],
            ),
          ),
          SizedBox(width: 80, child: Text('${attachment['page_count'] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
          SizedBox(width: 150, child: Text(attachment['content'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 120, child: Text(attachment['hijri_date'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 120, child: Text(
            attachment['gregorian_date'] != null 
                ? DateFormat('yyyy-MM-dd').format(DateTime.parse(attachment['gregorian_date']))
                : '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
          SizedBox(width: 100, child: Text(attachment['document_type_display'] ?? attachment['document_type'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentRowData(Map<String, dynamic> data, int index) {
    final docTypeController = TextEditingController(text: data['document_type'] ?? '');
    final contentController = TextEditingController(text: data['content'] ?? '');
    final pageCountController = TextEditingController(text: (data['page_count'] ?? '').toString());
    final hijriDateController = TextEditingController(text: data['hijri_date'] ?? '1447/01/01');
    DateTime? gregorianDate = data['gregorian_date'] != null 
        ? DateTime.tryParse(data['gregorian_date'])
        : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _attachmentsData.removeAt(index);
                });
              },
            ),
          ),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: pageCountController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'عدد الصفحات',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 10),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                data['page_count'] = int.tryParse(value);
              },
            ),
          ),
          SizedBox(
            width: 150,
            child: TextFormField(
              controller: contentController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'مضمون المستند ووجه',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 10),
              maxLength: 70,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return const SizedBox.shrink();
              },
              onChanged: (value) {
                data['content'] = value;
              },
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: hijriDateController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '1447/01/01',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 10),
              onChanged: (value) {
                data['hijri_date'] = value;
              },
            ),
          ),
          SizedBox(
            width: 120,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: gregorianDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    gregorianDate = picked;
                    data['gregorian_date'] = DateFormat('yyyy-MM-dd').format(picked);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  gregorianDate != null 
                      ? DateFormat('yyyy-MM-dd').format(gregorianDate!)
                      : 'yyyy/MM/dd',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: gregorianDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: docTypeController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'نوع المستند',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 10),
              maxLength: 70,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                return const SizedBox.shrink();
              },
              onChanged: (value) {
                data['document_type'] = value;
              },
            ),
          ),
        ],
      ),
    );
  }

  void _previewAttachmentCard(Map<String, dynamic> attachment) {
    final rawFileUrl = (attachment['file_url'] ?? attachment['file'])?.toString();
    final fileName = (attachment['original_filename'] ?? '').toString();
    AttachmentUtils.preview(
      context,
      rawFileUrl: rawFileUrl,
      fileName: fileName,
    );
  }

  Future<void> _openAttachmentExternal(String rawFileUrl, String fileName) async {
    final resolved = AttachmentUtils.resolveUrl(rawFileUrl);
    if (resolved == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد ملف مرفق')),
        );
      }
      return;
    }
    final uri = Uri.parse(resolved);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح الملف'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      developer.log('Error opening attachment: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAttachmentCard(Map<String, dynamic> attachment) {
    final docTypeDisplay = attachment['document_type_display'] ?? attachment['document_type'] ?? 'غير محدد';
    final fileName = attachment['original_filename'] ?? attachment['file'] ?? 'ملف';
    final content = attachment['content'] ?? '';
    final evidenceBasis = attachment['evidence_basis'] ?? '';
    final pageCount = attachment['page_count'] ?? 0;
    final fileSize = attachment['file_size_display'] ?? '';
    final createdAt = attachment['created_at'] != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(attachment['created_at']))
        : '';
    final fileUrl = attachment['file_url'] ?? attachment['file'] ?? '';
    final color = AttachmentUtils.fileColor(fileName);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            leading: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(AttachmentUtils.fileIcon(fileName), color: color, size: 22),
            ),
            title: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              '$docTypeDisplay${pageCount > 0 ? " • $pageCount صفحة" : ""}${fileSize.isNotEmpty ? " • $fileSize" : ""}${createdAt.isNotEmpty ? " • $createdAt" : ""}',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(content, style: TextStyle(color: Colors.grey[700], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          if (evidenceBasis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text('الأساس: $evidenceBasis', style: TextStyle(color: Colors.grey[600], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: Icon(Icons.visibility_rounded, size: 16, color: color),
                  label: Text('معاينة', style: TextStyle(fontSize: 12, color: color)),
                  onPressed: () => _previewAttachmentCard(attachment),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.orange),
                  label: const Text('تعديل', style: TextStyle(fontSize: 12, color: Colors.orange)),
                  onPressed: () => _showEditAttachmentDialog(attachment),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                  label: const Text('حذف', style: TextStyle(fontSize: 12, color: Colors.red)),
                  onPressed: () => _deleteAttachment(attachment['id']),
                ),
              ),
              if (fileUrl.isNotEmpty) ...[
                Container(width: 1, height: 32, color: Colors.grey.shade200),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.blueGrey),
                    label: const Text('فتح', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    onPressed: () => _openAttachmentExternal(fileUrl, fileName),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAttachment(int? attachmentId) async {
    if (attachmentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المستند؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.apiService.deleteAttachment(attachmentId);
      
      await _loadAttachments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المستند بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('Error deleting attachment: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف المستند: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAttachments() async {
    if (widget.lawsuitId == null || !mounted) return;
    
    setState(() {
      _isLoadingAttachments = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await authProvider.apiService.getAttachments(lawsuitId: widget.lawsuitId);
      
      if (mounted) {
        List<dynamic>? attachmentsData;
        if (response['results'] != null) {
          attachmentsData = response['results'] as List?;
        } else if (response['data'] != null && response['data'] is Map) {
          attachmentsData = (response['data'] as Map<String, dynamic>)['results'] as List?;
        } else if (response is List) {
          attachmentsData = response as List<dynamic>;
        } else {
          attachmentsData = null;
        }
        
        setState(() {
          _attachments = (attachmentsData ?? []).cast<Map<String, dynamic>>();
          _isLoadingAttachments = false;
        });
      }
    } catch (e) {
      developer.log('Error loading attachments: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        setState(() {
          _isLoadingAttachments = false;
        });
      }
    }
  }

  Future<void> _showAddAttachmentDialog() async {
    if (widget.lawsuitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب حفظ الدعوى أولاً قبل إضافة المستندات'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final contentController = TextEditingController();
    final evidenceBasisController = TextEditingController();
    final pageCountController = TextEditingController(text: '1');
    String? selectedDocType = 'other';
    DateTime? selectedDate = DateTime.now();
    File? selectedFile;

    final docTypes = [
      {'value': 'identity', 'label': 'هوية/جواز سفر'},
      {'value': 'contract', 'label': 'عقد'},
      {'value': 'certificate', 'label': 'شهادة'},
      {'value': 'evidence', 'label': 'دليل'},
      {'value': 'statement', 'label': 'بيان'},
      {'value': 'receipt', 'label': 'إيصال'},
      {'value': 'other', 'label': 'أخرى'},
    ];

    bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة مستند جديد'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDocType,
                    decoration: const InputDecoration(labelText: 'نوع المستند *'),
                    items: docTypes.map((t) => DropdownMenuItem(
                      value: t['value'] as String,
                      child: Text(t['label'] as String),
                    )).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedDocType = v;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'مضمون المستند *',
                      hintText: 'وصف محتوى المستند',
                    ),
                    maxLines: 3,
                    validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: evidenceBasisController,
                    decoration: const InputDecoration(
                      labelText: 'وجه الاستدلال *',
                      hintText: 'كيف يستدل بهذا المستند',
                    ),
                    maxLines: 2,
                    validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pageCountController,
                    decoration: const InputDecoration(labelText: 'عدد الصفحات *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'مطلوب';
                      if (int.tryParse(v!) == null || int.parse(v) < 1) {
                        return 'يجب أن يكون رقماً أكبر من 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('التاريخ الميلادي: ${selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : 'غير محدد'}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                        allowMultiple: false,
                      );
                      if (result != null && result.files.single.path != null) {
                        setDialogState(() {
                          selectedFile = File(result!.files.single.path!);
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(selectedFile != null 
                        ? 'تم اختيار: ${selectedFile!.path.split('/').last}'
                        : 'اختر ملف *'),
                  ),
                  if (selectedFile != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFile!.path.split('/').last,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                Text(
                                  'الحجم: ${_formatFileSize(selectedFile!.lengthSync())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setDialogState(() {
                                selectedFile = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: _isUploadingAttachment ? null : () {
                if (formKey.currentState!.validate() && selectedDate != null && selectedFile != null) {
                  Navigator.pop(dialogContext, true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى ملء جميع الحقول المطلوبة واختيار ملف'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: _isUploadingAttachment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true && selectedFile != null && selectedDate != null) {
      await _uploadAttachment(
        file: selectedFile!,
        documentType: selectedDocType!,
        content: contentController.text,
        evidenceBasis: evidenceBasisController.text,
        pageCount: int.parse(pageCountController.text),
        gregorianDate: selectedDate!,
      );
    }

    contentController.dispose();
    evidenceBasisController.dispose();
    pageCountController.dispose();
  }

  Future<void> _showEditAttachmentDialog(Map<String, dynamic> attachment) async {
    if (widget.lawsuitId == null) return;

    final formKey = GlobalKey<FormState>();
    final contentController = TextEditingController(text: attachment['content'] ?? '');
    final evidenceBasisController = TextEditingController(text: attachment['evidence_basis'] ?? '');
    final pageCountController = TextEditingController(text: (attachment['page_count'] ?? 1).toString());
    String? selectedDocType = attachment['document_type'] ?? 'other';
    DateTime? selectedDate = attachment['gregorian_date'] != null
        ? DateTime.parse(attachment['gregorian_date'])
        : DateTime.now();
    File? selectedFile;

    final docTypes = [
      {'value': 'identity', 'label': 'هوية/جواز سفر'},
      {'value': 'contract', 'label': 'عقد'},
      {'value': 'certificate', 'label': 'شهادة'},
      {'value': 'evidence', 'label': 'دليل'},
      {'value': 'statement', 'label': 'بيان'},
      {'value': 'receipt', 'label': 'إيصال'},
      {'value': 'other', 'label': 'أخرى'},
    ];

    bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تعديل المستند'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDocType,
                    decoration: const InputDecoration(labelText: 'نوع المستند *'),
                    items: docTypes.map((t) => DropdownMenuItem(
                      value: t['value'] as String,
                      child: Text(t['label'] as String),
                    )).toList(),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedDocType = v;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'مضمون المستند *',
                      hintText: 'وصف محتوى المستند',
                    ),
                    maxLines: 3,
                    validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: evidenceBasisController,
                    decoration: const InputDecoration(
                      labelText: 'وجه الاستدلال *',
                      hintText: 'كيف يستدل بهذا المستند',
                    ),
                    maxLines: 2,
                    validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pageCountController,
                    decoration: const InputDecoration(labelText: 'عدد الصفحات *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'مطلوب';
                      if (int.tryParse(v!) == null || int.parse(v) < 1) {
                        return 'يجب أن يكون رقماً أكبر من 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('التاريخ الميلادي: ${selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : 'غير محدد'}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ملف جديد (اختياري - اتركه فارغاً للاحتفاظ بالملف الحالي)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                        allowMultiple: false,
                      );
                      if (result != null && result.files.single.path != null) {
                        setDialogState(() {
                          selectedFile = File(result!.files.single.path!);
                        });
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(selectedFile != null 
                        ? 'تم اختيار: ${selectedFile!.path.split('/').last}'
                        : 'اختر ملف جديد (اختياري)'),
                  ),
                  if (selectedFile != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFile!.path.split('/').last,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                Text(
                                  'الحجم: ${_formatFileSize(selectedFile!.lengthSync())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setDialogState(() {
                                selectedFile = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: _isUploadingAttachment ? null : () {
                if (formKey.currentState!.validate() && selectedDate != null) {
                  Navigator.pop(dialogContext, true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('يرجى ملء جميع الحقول المطلوبة'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: _isUploadingAttachment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave == true && selectedDate != null) {
      await _updateAttachment(
        attachmentId: attachment['id'],
        documentType: selectedDocType!,
        content: contentController.text,
        evidenceBasis: evidenceBasisController.text,
        pageCount: int.parse(pageCountController.text),
        gregorianDate: selectedDate!,
        newFile: selectedFile,
      );
    }

    contentController.dispose();
    evidenceBasisController.dispose();
    pageCountController.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _downloadOrOpenAttachment(String fileUrl, String fileName) async {
    try {
      final uri = Uri.parse(fileUrl);
      
      // If it's a full URL, try to open it directly
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن فتح الملف'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // If it's a relative URL, construct full URL
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final fullUrl = '${ApiConfig.baseUrl}$fileUrl';
        final fullUri = Uri.parse(fullUrl);
        
        if (await canLaunchUrl(fullUri)) {
          await launchUrl(fullUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لا يمكن فتح الملف'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error opening attachment: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الملف: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAttachment({
    required File file,
    required String documentType,
    required String content,
    required String evidenceBasis,
    required int pageCount,
    required DateTime gregorianDate,
  }) async {
    if (widget.lawsuitId == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Convert gregorian date to hijri
      final hijriDate = HijriCalendar.fromDate(gregorianDate);
      final hijriDateString = '${hijriDate.hYear}/${hijriDate.hMonth}/${hijriDate.hDay}';

      // Upload file
      await authProvider.apiService.uploadAttachment(
        lawsuitId: widget.lawsuitId!,
        filePath: file.path,
        documentType: documentType,
        gregorianDate: DateFormat('yyyy-MM-dd').format(gregorianDate),
        hijriDate: hijriDateString,
        pageCount: pageCount,
        content: content,
        evidenceBasis: evidenceBasis,
      );

      // Reload attachments
      await _loadAttachments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع المستند بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('Error uploading attachment: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع المستند: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  Future<void> _updateAttachment({
    required int attachmentId,
    required String documentType,
    required String content,
    required String evidenceBasis,
    required int pageCount,
    required DateTime gregorianDate,
    File? newFile,
  }) async {
    if (widget.lawsuitId == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Convert gregorian date to hijri
      final hijriDate = HijriCalendar.fromDate(gregorianDate);
      final hijriDateString = '${hijriDate.hYear}/${hijriDate.hMonth}/${hijriDate.hDay}';

      // Update attachment
      await authProvider.apiService.updateAttachment(
        id: attachmentId,
        documentType: documentType,
        gregorianDate: DateFormat('yyyy-MM-dd').format(gregorianDate),
        hijriDate: hijriDateString,
        pageCount: pageCount,
        content: content,
        evidenceBasis: evidenceBasis,
        filePath: newFile?.path,
      );

      // Reload attachments
      await _loadAttachments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المستند بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('Error updating attachment: $e', name: 'LawsuitDetailScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث المستند: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }
}
