import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/lawsuit_provider.dart';
import '../models/appeal_model.dart';
import '../models/lawsuit_model.dart';
import 'dart:developer' as developer;

/// Appeal Screen - الطعون
/// Uses same format as lawsuit_detail_screen with legal templates
class AppealScreen extends StatefulWidget {
  final int? appealId;
  final int? lawsuitId; // Optional: pre-fill lawsuit

  const AppealScreen({super.key, this.appealId, this.lawsuitId});

  @override
  State<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends State<AppealScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _appealNumberController;
  late TextEditingController _appealReasonsController;
  late TextEditingController _appealRequestsController;
  late TextEditingController _higherCourtController;
  late TextEditingController _submittedByController;
  
  // Legal text controllers (for appeal templates)
  final Map<String, TextEditingController> _legalTextControllers = {};
  
  String? _selectedLawsuitNumber;
  int? _selectedLawsuitId;
  String? _selectedAppealType;
  String? _selectedStatus;
  List<LawsuitModel> _lawsuits = [];
  DateTime? _selectedAppealDate;
  
  bool _isLoadingTemplates = false;
  bool _isSaving = false;
  Map<String, dynamic>? _templates;
  List<String> _templateKeys = [];
  
  bool get _isEditMode => widget.appealId != null;

  @override
  void initState() {
    super.initState();
    _appealNumberController = TextEditingController();
    _appealReasonsController = TextEditingController();
    _appealRequestsController = TextEditingController();
    _higherCourtController = TextEditingController();
    _submittedByController = TextEditingController();
    
    _selectedAppealType = 'appeal';
    _selectedStatus = 'pending';
    _selectedAppealDate = DateTime.now();
    _selectedLawsuitId = widget.lawsuitId;

    // Load templates for appeal/challenge
    _loadTemplates('طعن');
    
    if (_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAppeal();
      });
    }
  }

  @override
  void dispose() {
    _appealNumberController.dispose();
    _appealReasonsController.dispose();
    _appealRequestsController.dispose();
    _higherCourtController.dispose();
    _submittedByController.dispose();
    for (var controller in _legalTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAppeal() async {
    // TODO: Implement loading appeal
  }

  Future<void> _loadTemplates(String caseType) async {
    setState(() {
      _isLoadingTemplates = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await authProvider.apiService.getLawsuitTemplates(caseType);
      
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
    } catch (e) {
      developer.log('Error loading templates: $e', name: 'AppealScreen');
    } finally {
      setState(() {
        _isLoadingTemplates = false;
      });
    }
  }

  Future<void> _saveAppeal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // If no lawsuit is selected, create a dummy one first
      if (_selectedLawsuitId == null) {
        final lawsuitProvider = Provider.of<LawsuitProvider>(context, listen: false);
        String sub = 'طعن - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
        if (_appealReasonsController.text.isNotEmpty) {
           sub = _appealReasonsController.text.length > 50
              ? _appealReasonsController.text.substring(0, 50)
              : _appealReasonsController.text;
        }

        final newLawsuit = LawsuitModel(
          caseNumber: 'L-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
          caseType: 'طعن',
          caseStatus: 'جديد',
          subject: sub,
          filingDate: DateTime.now(),
        );

        final created = await lawsuitProvider.createLawsuit(newLawsuit);
        if (created != null && created.id != null) {
          _selectedLawsuitId = created.id;
        } else {
           throw Exception('فشل إنشاء ملف الدعوى التلقائي');
        }
      }
      
      // Build legal texts from controllers
      String? grounds;
      if (_legalTextControllers.containsKey('grounds')) {
        grounds = _legalTextControllers['grounds']!.text.trim();
      }
      
      String appealNumber = _appealNumberController.text.trim();
      if (appealNumber.isEmpty) {
        appealNumber = 'A-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      }
      
      final appeal = AppealModel(
        id: widget.appealId,
        lawsuitId: _selectedLawsuitId!,
        appealType: _selectedAppealType ?? 'appeal',
        appealNumber: appealNumber,
        appealReasons: grounds ?? _appealReasonsController.text.trim(),
        appealRequests: _appealRequestsController.text.trim(),
        higherCourt: _higherCourtController.text.trim(),
        status: _selectedStatus ?? 'pending',
        appealDate: _selectedAppealDate ?? DateTime.now(),
        submittedBy: _submittedByController.text.trim(),
      );

      // Save appeal
      if (_isEditMode) {
        await authProvider.apiService.updateAppeal(
          widget.appealId!,
          appeal.toJson(),
        );
      } else {
        final createdAppeal = await authProvider.apiService.createAppeal(appeal.toJson());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditMode ? 'تم تحديث الطعن بنجاح' : 'تم إنشاء الطعن بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, createdAppeal);
        }
        return;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'تم تحديث الطعن بنجاح' : 'تم إنشاء الطعن بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      developer.log('Error saving appeal: $e', name: 'AppealScreen');
      if (mounted) {
        final errorStr = e.toString();
        String errorMessage = 'خطأ في حفظ الطعن';
        IconData errorIcon = Icons.error_outline;
        Color errorColor = Colors.red;
        
        if (errorStr.contains('SocketException') || 
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
        } else if (errorStr.contains('Connection refused') ||
                   errorStr.contains('Network') || 
                   errorStr.contains('Connection')) {
          errorMessage = 'لا يمكن الاتصال بالخادم\nيرجى التحقق من اتصال الإنترنت';
          errorIcon = Icons.wifi_off;
          errorColor = Colors.orange.shade700;
        } else if (errorStr.contains('400') || 
                   errorStr.contains('Bad Request')) {
          errorMessage = 'البيانات المدخلة غير صحيحة\nيرجى التحقق من جميع الحقول';
          errorIcon = Icons.warning_amber_rounded;
        } else {
          String cleanError = errorStr.replaceAll('Exception: ', '');
          if (cleanError.length > 100) {
            errorMessage = 'خطأ في حفظ الطعن\nيرجى المحاولة مرة أخرى';
          } else {
            errorMessage = 'خطأ في حفظ الطعن: $cleanError';
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
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'تعديل الطعن' : 'إضافة طعن جديد'),
      ),
      body: _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Appeal Type
            DropdownButtonFormField<String>(
              value: _selectedAppealType,
              decoration: const InputDecoration(
                labelText: 'نوع الطعن',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'primary', child: Text('ابتدائي')),
                DropdownMenuItem(value: 'appeal', child: Text('استئناف')),
                DropdownMenuItem(value: 'cassation', child: Text('تمييز')),
                DropdownMenuItem(value: 'constitutional', child: Text('دستوري')),
                DropdownMenuItem(value: 'other', child: Text('أخرى')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAppealType = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Higher Court
            TextFormField(
              controller: _higherCourtController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'المحكمة الأعلى *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال المحكمة الأعلى';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Appeal Date
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedAppealDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() {
                    _selectedAppealDate = date;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الطعن *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedAppealDate != null
                      ? DateFormat('yyyy-MM-dd').format(_selectedAppealDate!)
                      : 'اختر التاريخ',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'حالة الطعن',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                DropdownMenuItem(value: 'under_review', child: Text('قيد المراجعة')),
                DropdownMenuItem(value: 'accepted', child: Text('مقبول')),
                DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                DropdownMenuItem(value: 'withdrawn', child: Text('مسحوب')),
                DropdownMenuItem(value: 'closed', child: Text('مغلق')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Submitted By
            TextFormField(
              controller: _submittedByController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'مقدم الطعن *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال اسم مقدم الطعن';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Appeal Reasons
            TextFormField(
              controller: _appealReasonsController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'أسباب الطعن *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال أسباب الطعن';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Appeal Requests
            TextFormField(
              controller: _appealRequestsController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'طلبات الطعن',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.list_alt),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Legal Templates Section
            if (_isLoadingTemplates)
              const Center(child: CircularProgressIndicator())
            else if (_templates != null && _templateKeys.isNotEmpty)
              ..._buildLegalTextFields()
            else
              const SizedBox.shrink(),

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: (_isSaving || _isLoadingTemplates) ? null : _saveAppeal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditMode ? 'حفظ التغييرات' : 'إنشاء الطعن',
                      style: const TextStyle(fontSize: 16),
                    ),
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
    
    widgets.add(const Divider());
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
}

