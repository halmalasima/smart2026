import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/hearing_model.dart';
import '../models/case_model.dart';
import '../providers/session_provider.dart';
import '../theme/app_colors.dart';

/// Add / Edit Session Screen - شاشة إضافة / تعديل جلسة
class SessionFormScreen extends StatefulWidget {
  final HearingModel? session; // null → create mode

  const SessionFormScreen({super.key, this.session});

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Fields
  CaseModel? _selectedCase;
  DateTime _hearingDate = DateTime.now();
  TimeOfDay _hearingTime = const TimeOfDay(hour: 9, minute: 0);
  String _sessionType = 'upcoming';
  String _timeOfDay = 'morning';
  String _hearingType = 'main';
  final _notesController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _courtDecisionController = TextEditingController();
  DateTime? _nextSessionDate;

  bool get isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final s = widget.session!;
      _hearingDate = s.hearingDate;
      if (s.hearingTime != null) {
        final parts = s.hearingTime!.split(':');
        if (parts.length >= 2) {
          _hearingTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      _sessionType = s.sessionType;
      _timeOfDay = s.timeOfDay;
      _hearingType = s.hearingType;
      _notesController.text = s.notes;
      _requirementsController.text = s.requirements;
      _courtDecisionController.text = s.courtDecision ?? '';
      _nextSessionDate = s.nextSessionDate;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SessionProvider>(context, listen: false);
      provider.loadCases().then((_) {
        if (isEditing && widget.session!.caseId != null) {
          final match = provider.cases.where((c) => c.id == widget.session!.caseId);
          if (match.isNotEmpty && mounted) {
            setState(() => _selectedCase = match.first);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _requirementsController.dispose();
    _courtDecisionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hearingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _hearingDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hearingTime,
    );
    if (picked != null) setState(() => _hearingTime = picked);
  }

  Future<void> _pickNextSessionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextSessionDate ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _nextSessionDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار القضية')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<SessionProvider>(context, listen: false);
    final timeStr = '${_hearingTime.hour.toString().padLeft(2, '0')}:${_hearingTime.minute.toString().padLeft(2, '0')}:00';

    // Resolve lawsuit_id from case's lawsuits
    // For now, we use 0 as placeholder — the backend allows it
    final data = <String, dynamic>{
      'case_id': _selectedCase!.id,
      'lawsuit_id': 0,
      'hearing_date': _hearingDate.toIso8601String().split('T')[0],
      'hearing_time': timeStr,
      'hearing_type': _hearingType,
      'session_type': _sessionType,
      'time_of_day': _timeOfDay,
      'notes': _notesController.text.trim(),
      'requirements': _requirementsController.text.trim(),
    };

    if (_sessionType == 'previous') {
      data['court_decision'] = _courtDecisionController.text.trim();
      if (_nextSessionDate != null) {
        data['next_session_date'] = _nextSessionDate!.toIso8601String().split('T')[0];
      }
    }

    HearingModel? result;
    if (isEditing) {
      result = await provider.updateSession(widget.session!.id!, data);
    } else {
      result = await provider.createSession(data);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'تم تحديث الجلسة بنجاح' : 'تم إنشاء الجلسة بنجاح')),
      );
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'حدث خطأ أثناء الحفظ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الجلسة' : 'إضافة جلسة جديدة'),
          centerTitle: true,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Case Picker ──
              _sectionTitle('القضية'),
              Consumer<SessionProvider>(
                builder: (_, prov, __) {
                  final cases = prov.cases;
                  return DropdownButtonFormField<int>(
                    value: _selectedCase?.id,
                    decoration: _inputDecoration('اختر القضية', Icons.folder_open),
                    isExpanded: true,
                    items: cases.map((c) => DropdownMenuItem<int>(
                      value: c.id,
                      child: Text('${c.caseNumber} - ${c.subject ?? "بدون عنوان"}',
                        overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (id) {
                      setState(() {
                        _selectedCase = cases.firstWhere((c) => c.id == id);
                      });
                    },
                    validator: (v) => v == null ? 'اختر القضية' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // ── Session Type ──
              _sectionTitle('نوع الجلسة'),
              _segmentedSelector(
                options: const {'upcoming': 'قادمة', 'previous': 'سابقة'},
                value: _sessionType,
                onChanged: (v) => setState(() => _sessionType = v),
              ),
              const SizedBox(height: 16),

              // ── Date & Time ──
              _sectionTitle('التاريخ والوقت'),
              Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      label: 'تاريخ الجلسة',
                      value: DateFormat('yyyy/MM/dd').format(_hearingDate),
                      icon: Icons.calendar_today,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateTile(
                      label: 'وقت الجلسة',
                      value: _hearingTime.format(context),
                      icon: Icons.access_time,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Time of Day ──
              _segmentedSelector(
                options: const {'morning': 'صباحية ☀️', 'evening': 'مسائية 🌙'},
                value: _timeOfDay,
                onChanged: (v) => setState(() => _timeOfDay = v),
              ),
              const SizedBox(height: 16),

              // ── Hearing Type ──
              _sectionTitle('تصنيف الجلسة'),
              DropdownButtonFormField<String>(
                value: _hearingType,
                decoration: _inputDecoration('نوع الجلسة', Icons.gavel),
                items: const [
                  DropdownMenuItem(value: 'preliminary', child: Text('تمهيدية')),
                  DropdownMenuItem(value: 'main', child: Text('رئيسية')),
                  DropdownMenuItem(value: 'decision', child: Text('قرار')),
                  DropdownMenuItem(value: 'adjourned', child: Text('مؤجلة')),
                  DropdownMenuItem(value: 'other', child: Text('أخرى')),
                ],
                onChanged: (v) => setState(() => _hearingType = v!),
              ),
              const SizedBox(height: 16),

              // ── Requirements ──
              _sectionTitle('المطلوب في الجلسة'),
              TextFormField(
                controller: _requirementsController,
                maxLines: 3,
                decoration: _inputDecoration('أدخل المتطلبات', Icons.assignment),
              ),
              const SizedBox(height: 16),

              // ── Notes ──
              _sectionTitle('ملاحظات'),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration('ملاحظات إضافية', Icons.note),
              ),
              const SizedBox(height: 16),

              // ── Previous-only fields ──
              if (_sessionType == 'previous') ...[
                _sectionTitle('قرار المحكمة'),
                TextFormField(
                  controller: _courtDecisionController,
                  maxLines: 3,
                  decoration: _inputDecoration('أدخل قرار المحكمة', Icons.balance),
                ),
                const SizedBox(height: 16),
                _sectionTitle('موعد الجلسة القادمة'),
                _dateTile(
                  label: _nextSessionDate != null
                      ? DateFormat('yyyy/MM/dd').format(_nextSessionDate!)
                      : 'اختر التاريخ',
                  value: _nextSessionDate != null
                      ? DateFormat('yyyy/MM/dd').format(_nextSessionDate!)
                      : 'لم يحدد',
                  icon: Icons.event_repeat,
                  onTap: _pickNextSessionDate,
                ),
                const SizedBox(height: 16),
              ],

              // ── Save Button ──
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'جاري الحفظ...' : (isEditing ? 'حفظ التعديلات' : 'إنشاء الجلسة'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.brand)),
  );

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.brand, size: 20),
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _dateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _segmentedSelector({
    required Map<String, String> options,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.entries.map((e) {
          final isSelected = e.key == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
