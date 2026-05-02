import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/case_model.dart';
import '../models/lawsuit_model.dart';
import '../models/hearing_model.dart';
import '../models/attachment_model.dart';
import '../models/appeal_model.dart';
import '../models/payment_order_model.dart';
import '../services/api_service.dart';
import '../services/local_lookup_service.dart';
import '../providers/lawsuit_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/attachment_utils.dart';
import 'appeal_screen.dart';
import 'payment_order_screen.dart';
import 'lawsuit_detail_screen.dart';
import 'power_of_attorney_screen.dart';
import 'session_detail_screen.dart';
import 'session_form_screen.dart';
import 'document_scanner_screen.dart';

class CaseDetailScreen extends StatefulWidget {
  final int caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  bool _isLoadingRelated = false;
  bool _isCreating = false;
  String? _error;

  CaseModel? _case;
  List<LawsuitModel> _lawsuits = [];
  List<HearingModel> _hearings = [];
  List<AttachmentModel> _attachments = [];
  List<AppealModel> _appeals = [];
  List<PaymentOrderModel> _paymentOrders = [];

  // ── Search & Filter ──
  final _lawsuitsSearchCtrl = TextEditingController();
  final _docsSearchCtrl = TextEditingController();
  final _hearingsSearchCtrl = TextEditingController();
  String? _docsTypeFilter; // null = all
  bool _isUploadingDoc = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lawsuitsSearchCtrl.dispose();
    _docsSearchCtrl.dispose();
    _hearingsSearchCtrl.dispose();
    super.dispose();
  }

  List _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      final r = data['results'] ?? data['data'] ?? data['items'];
      if (r is List) return r;
    }
    return [];
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final c = await api.getCase(widget.caseId);
      final resp = await api.getLawsuits(queryParams: {'case': widget.caseId.toString(), 'include_appeals': 'true'});
      final lawsuits = _extractList(resp)
          .map((e) => LawsuitModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() { _case = c; _lawsuits = lawsuits; _isLoading = false; });
      if (lawsuits.isNotEmpty) await _loadRelatedData(lawsuits, api);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadRelatedData(List<LawsuitModel> lawsuits, ApiService api) async {
    setState(() => _isLoadingRelated = true);
    final ids = lawsuits.where((l) => l.id != null).map((l) => l.id!).toList();
    try {
      final results = await Future.wait(ids.map((id) => Future.wait([
        api.getHearings(lawsuitId: id).catchError((_) => null),
        api.getAttachments(lawsuitId: id).catchError((_) => null),
        api.get('/api/appeals/?lawsuit=$id').catchError((_) => null),
        api.get('/api/payment-orders/?lawsuit=$id').catchError((_) => null),
      ])));

      final hearings = <HearingModel>[];
      final attachments = <AttachmentModel>[];
      final appeals = <AppealModel>[];
      final payments = <PaymentOrderModel>[];

      for (final r in results) {
        if (r[0] != null) {
          hearings.addAll(_extractList(r[0]).map((e) => HearingModel.fromJson(e)));
        }
        if (r[1] != null) {
          attachments.addAll(_extractList(r[1]).map((e) => AttachmentModel.fromJson(e)));
        }
        if (r[2] != null) {
          appeals.addAll(_extractList(r[2]).map((e) => AppealModel.fromJson(e)));
        }
        if (r[3] != null) {
          payments.addAll(_extractList(r[3]).map((e) => PaymentOrderModel.fromJson(e)));
        }
      }

      List<T> _dedupe<T>(List<T> items, dynamic Function(T) keyOf) {
        final seen = <dynamic>{};
        final out = <T>[];
        for (final it in items) {
          final k = keyOf(it);
          if (k == null || seen.add(k)) out.add(it);
        }
        return out;
      }

      final dedupedHearings = _dedupe<HearingModel>(hearings, (h) => h.id);
      final dedupedAttachments = _dedupe<AttachmentModel>(attachments, (a) => a.id);
      final dedupedAppeals = _dedupe<AppealModel>(appeals, (a) => a.id);
      final dedupedPayments = _dedupe<PaymentOrderModel>(payments, (p) => p.id);

      dedupedHearings.sort((a, b) => b.hearingDate.compareTo(a.hearingDate));

      if (!mounted) return;
      setState(() {
        _hearings = dedupedHearings;
        _attachments = dedupedAttachments;
        _appeals = dedupedAppeals;
        _paymentOrders = dedupedPayments;
        _isLoadingRelated = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _createLawsuitForCase(String caseType) async {
    setState(() => _isCreating = true);
    try {
      final lawsuitProvider = Provider.of<LawsuitProvider>(context, listen: false);
      final newLawsuit = LawsuitModel(
        caseNumber: 'L-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        caseType: caseType,
        caseStatus: 'جديد',
        subject: _case?.subject ?? 'إجراء جديد',
        filingDate: DateTime.now(),
        caseId: widget.caseId,
      );
      final created = await lawsuitProvider.createLawsuit(newLawsuit);
      if (created == null || created.id == null) throw Exception('فشل إنشاء الدعوى');
      if (!mounted) return;
      Navigator.pop(context);
      switch (caseType) {
        case 'طعن':
          await Navigator.push(context, MaterialPageRoute(builder: (_) => AppealScreen(lawsuitId: created.id)));
          if (mounted) {
            await _load();
            _tabController.animateTo(4);
          }
          break;
        case 'امر_اداء':
          await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentOrderScreen(lawsuitId: created.id)));
          if (mounted) {
            await _load();
            _tabController.animateTo(4);
          }
          break;
        default:
          final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => LawsuitDetailScreen(lawsuitId: created.id)));
          if (saved != true) {
            await lawsuitProvider.deleteLawsuit(created.id!);
          }
          if (mounted) await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = _case;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: context.isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c?.caseNumber ?? 'تفاصيل القضية',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            if (c?.subject != null)
              Text(c!.subject!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        actions: [
          if (_isLoadingRelated)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            onSelected: (v) {
              if (v == 'delete') _confirmAndDeleteCase();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('حذف القضية', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'معلومات', icon: Icon(Icons.info_outline_rounded, size: 18)),
            Tab(text: 'الإجراءات', icon: Icon(Icons.gavel_rounded, size: 18)),
            Tab(text: 'الجلسات', icon: Icon(Icons.calendar_month_rounded, size: 18)),
            Tab(text: 'المستندات', icon: Icon(Icons.folder_copy_rounded, size: 18)),
            Tab(text: 'الطعون', icon: Icon(Icons.history_edu_rounded, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInfoTab(),
                    _buildLawsuitsTab(),
                    _buildHearingsTab(),
                    _buildDocsTab(),
                    _buildAppealsTab(),
                  ],
                ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    switch (_tabController.index) {
      case 1:
        return FloatingActionButton.extended(
          onPressed: _isCreating ? null : _showAddActionMenu,
          backgroundColor: AppColors.primary,
          icon: _isCreating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('إضافة إجراء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      case 3:
        return FloatingActionButton.extended(
          onPressed: _isUploadingDoc ? null : _showAddDocumentMenu,
          backgroundColor: const Color(0xFF2563EB),
          icon: _isUploadingDoc
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.note_add_rounded, color: Colors.white),
          label: const Text('إضافة مستند', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      default:
        return null;
    }
  }

  // ─── Tab: معلومات القضية ──────────────────────────────────────────────────

  Widget _buildInfoTab() {
    final c = _case;
    if (c == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'بيانات القضية',
          icon: Icons.folder_special_rounded,
          children: [
            _editableRow(
              label: 'رقم القضية',
              value: c.caseNumber,
              onEdit: () => _editTextField(
                title: 'رقم القضية',
                field: 'case_number',
                initial: c.caseNumber,
                required: true,
              ),
            ),
            _editableRow(
              label: 'موضوع القضية',
              value: c.subject ?? '-',
              onEdit: () => _editTextField(
                title: 'موضوع القضية',
                field: 'subject',
                initial: c.subject ?? '',
                maxLines: 2,
              ),
            ),
            _editableRow(
              label: 'نوع القضية',
              value: '${c.caseType ?? '-'}${c.caseSubtype != null ? ' / ${c.caseSubtype}' : ''}',
              onEdit: _editCaseType,
            ),
            _editableRow(
              label: 'حالة القضية',
              value: (c.caseStatus ?? '-').replaceAll('_', ' '),
              onEdit: _editCaseStatus,
            ),
            _editableRow(
              label: 'المحافظة / المحكمة',
              value: '${c.governorate ?? '-'}${c.courtName != null ? ' / ${c.courtName}' : ''}',
              onEdit: _editGovernorateAndCourt,
            ),
            _editableRow(
              label: 'سنة القضية (هجري)',
              value: c.caseYearHijri?.toString() ?? '-',
              onEdit: () => _editIntField(
                title: 'سنة القضية (هجري)',
                field: 'case_year_hijri',
                initial: c.caseYearHijri,
              ),
            ),
            _editableRow(
              label: 'تاريخ التقديم',
              value: c.filingDate != null ? DateFormat('yyyy-MM-dd').format(c.filingDate!) : '-',
              onEdit: _editFilingDate,
            ),
            _editableRow(
              label: 'الوصف',
              value: (c.description == null || c.description!.isEmpty) ? '-' : c.description!,
              onEdit: () => _editTextField(
                title: 'الوصف',
                field: 'description',
                initial: c.description ?? '',
                maxLines: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'أطراف القضية',
          icon: Icons.people_rounded,
          children: [
            if (c.parties == null || c.parties!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('لا يوجد أطراف مسجّلة',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              )
            else
              ...c.parties!.map((p) => _partyTile(p)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                    ),
                    icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                    label: const Text('إضافة موكل'),
                    onPressed: () => _addParty('client'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('إضافة خصم'),
                    onPressed: () => _addParty('opponent'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
            ]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _editableRow({
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  textAlign: TextAlign.right),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_rounded, size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _partyTile(CasePartyModel p) {
    final isClient = p.role == 'client';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isClient ? const Color(0xFFE8F5E9) : const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          p.entityType == 'organization' ? Icons.business : Icons.person,
          color: isClient ? Colors.green : Colors.red,
        ),
        title: Text(p.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          '${p.roleDisplay ?? (isClient ? "موكل" : "خصم")}${p.phone != null && p.phone!.isNotEmpty ? " • ${p.phone}" : ""}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
              tooltip: 'تعديل',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _editParty(p),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              tooltip: 'حذف',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _deleteParty(p),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Case/Party editing helpers ─────────────────────────────────────────

  Future<void> _patchCase(Map<String, dynamic> patch) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await api.patchCase(widget.caseId, patch);
      if (!mounted) return;
      setState(() => _case = updated);
      messenger.showSnackBar(const SnackBar(
        content: Text('تم التحديث'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('تعذر التحديث: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _editTextField({
    required String title,
    required String field,
    required String initial,
    int maxLines = 1,
    bool required = false,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final formKey = GlobalKey<FormState>();
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Text(title, textAlign: TextAlign.right),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ctrl,
              maxLines: maxLines,
              textDirection: ui.TextDirection.rtl,
              validator: (v) => (required && (v == null || v.trim().isEmpty))
                  ? 'مطلوب' : null,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(dCtx, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(dCtx, true);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      if (saved == true) {
        final v = ctrl.text.trim();
        await _patchCase({field: v.isEmpty ? null : v});
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _editIntField({
    required String title,
    required String field,
    required int? initial,
  }) async {
    final ctrl = TextEditingController(text: initial?.toString() ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Text(title, textAlign: TextAlign.right),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(dCtx, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(dCtx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      if (saved == true) {
        final n = int.tryParse(ctrl.text.trim());
        await _patchCase({field: n});
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _editCaseStatus() async {
    const statuses = <String>['جديد', 'قيد_النظر', 'مكتمل', 'مغلق'];
    String selected = _case?.caseStatus ?? 'جديد';
    if (!statuses.contains(selected)) selected = 'جديد';
    final saved = await showDialog<String>(
      context: context,
      builder: (dCtx) => SimpleDialog(
        title: const Text('حالة القضية', textAlign: TextAlign.right),
        children: statuses
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dCtx, s),
                  child: Text(s.replaceAll('_', ' '), textAlign: TextAlign.right),
                ))
            .toList(),
      ),
    );
    if (saved != null) await _patchCase({'case_status': saved});
  }

  Future<void> _editCaseType() async {
    const types = <String>['مدنية', 'جزائية', 'شخصية', 'إدارية', 'تجارية'];
    String selectedType = _case?.caseType ?? types.first;
    if (!types.contains(selectedType)) selectedType = types.first;
    List<String> subtypes = await LocalLookupService.getSubtypes(selectedType);
    String? selectedSub = _case?.caseSubtype;
    if (selectedSub != null && !subtypes.contains(selectedSub)) {
      subtypes = [selectedSub, ...subtypes];
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: const Text('نوع القضية', textAlign: TextAlign.right),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  final subs = await LocalLookupService.getSubtypes(v);
                  setDState(() {
                    selectedType = v;
                    subtypes = subs;
                    selectedSub = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: subtypes.contains(selectedSub) ? selectedSub : null,
                decoration: const InputDecoration(labelText: 'التصنيف الفرعي'),
                items: subtypes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setDState(() => selectedSub = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _patchCase({
        'case_type': selectedType,
        'case_subtype': selectedSub,
      });
    }
  }

  Future<void> _editGovernorateAndCourt() async {
    final api = Provider.of<ApiService>(context, listen: false);
    List<Map<String, dynamic>> governorates =
        await LocalLookupService.getGovernorates();
    if (governorates.isEmpty) {
      governorates = await LocalLookupService.syncGovernorates(api);
    }
    String? selectedGov = _case?.governorate;
    int? selectedGovId;
    for (final g in governorates) {
      if (g['name'] == selectedGov) {
        selectedGovId = g['id'] as int?;
        break;
      }
    }
    List<Map<String, dynamic>> courts = [];
    if (selectedGovId != null) {
      courts = await LocalLookupService.getCourts(selectedGovId);
    }
    int? selectedCourtId = _case?.courtId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: const Text('المحافظة والمحكمة', textAlign: TextAlign.right),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedGovId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المحافظة'),
                  items: governorates
                      .map((g) => DropdownMenuItem<int>(
                            value: g['id'] as int?,
                            child: Text(g['name'] ?? '', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    final loaded = await LocalLookupService.getCourts(v);
                    setDState(() {
                      selectedGovId = v;
                      selectedGov = governorates
                          .firstWhere((g) => g['id'] == v, orElse: () => {})['name'];
                      courts = loaded;
                      selectedCourtId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: courts.any((c) => c['id'] == selectedCourtId) ? selectedCourtId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المحكمة'),
                  items: courts
                      .map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int?,
                            child: Text(
                              (c['name'] ?? c['court_name'] ?? '').toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setDState(() => selectedCourtId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _patchCase({
        'governorate': selectedGov,
        'court_id': selectedCourtId,
      });
    }
  }

  Future<void> _editFilingDate() async {
    final initial = _case?.filingDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await _patchCase({
      'filing_date': DateFormat('yyyy-MM-dd').format(picked),
    });
  }

  Future<void> _confirmAndDeleteCase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('حذف القضية'),
        content: const Text(
          'هل أنت متأكد من حذف هذه القضية؟ لا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.deleteCase(widget.caseId);
      messenger.showSnackBar(const SnackBar(
        content: Text('تم حذف القضية'),
        backgroundColor: Colors.green,
      ));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('تعذر الحذف: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _addParty(String role) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final idFromCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String entityType = 'person';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: Text(
            role == 'client' ? 'إضافة موكل (طرف أول)' : 'إضافة خصم (طرف ثاني)',
            textAlign: TextAlign.right,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('شخص'),
                      selected: entityType == 'person',
                      onSelected: (_) => setDState(() => entityType = 'person'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('مؤسسة'),
                      selected: entityType == 'organization',
                      onSelected: (_) => setDState(() => entityType = 'organization'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  textDirection: ui.TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'الاسم *'),
                ),
                const SizedBox(height: 10),
                if (role == 'client')
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                if (role == 'client') const SizedBox(height: 10),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(labelText: 'رقم الهوية / السجل'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idFromCtrl,
                  textDirection: ui.TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'جهة الإصدار'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  textDirection: ui.TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(dCtx, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final party = CasePartyModel(
          caseId: widget.caseId,
          role: role,
          entityType: entityType,
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
          idNumber: idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
          idIssuedFrom: idFromCtrl.text.trim().isEmpty ? null : idFromCtrl.text.trim(),
          address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
        );
        await api.createCaseParty(party);
        await _load();
        messenger.showSnackBar(const SnackBar(
          content: Text('تمت إضافة الطرف'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('تعذر الإضافة: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    idCtrl.dispose();
    idFromCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _editParty(CasePartyModel p) async {
    if (p.id == null) return;
    final nameCtrl = TextEditingController(text: p.name);
    final phoneCtrl = TextEditingController(text: p.phone ?? '');
    final idCtrl = TextEditingController(text: p.idNumber ?? '');
    final idFromCtrl = TextEditingController(text: p.idIssuedFrom ?? '');
    final addressCtrl = TextEditingController(text: p.address ?? '');
    String entityType = p.entityType;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: Text(
            p.role == 'client' ? 'تعديل الموكل' : 'تعديل الخصم',
            textAlign: TextAlign.right,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('شخص'),
                      selected: entityType == 'person',
                      onSelected: (_) => setDState(() => entityType = 'person'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('مؤسسة'),
                      selected: entityType == 'organization',
                      onSelected: (_) => setDState(() => entityType = 'organization'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  textDirection: ui.TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'الاسم *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(labelText: 'رقم الهوية / السجل'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idFromCtrl,
                  textDirection: ui.TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'جهة الإصدار'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  textDirection: ui.TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(dCtx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await api.updateCaseParty(p.id!, {
          'name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'id_number': idCtrl.text.trim(),
          'id_issued_from': idFromCtrl.text.trim(),
          'address': addressCtrl.text.trim(),
          'entity_type': entityType,
        });
        await _load();
        messenger.showSnackBar(const SnackBar(
          content: Text('تم تحديث الطرف'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('تعذر التحديث: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    idCtrl.dispose();
    idFromCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _deleteParty(CasePartyModel p) async {
    if (p.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('حذف الطرف'),
        content: Text('هل تريد حذف "${p.name}" من أطراف القضية؟',
            textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.deleteCaseParty(p.id!);
      await _load();
      messenger.showSnackBar(const SnackBar(
        content: Text('تم حذف الطرف'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('تعذر الحذف: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ─── Tab: الإجراءات / الدعاوى ────────────────────────────────────────────

  Widget _buildLawsuitsTab() {
    final allLawsuits = _lawsuits.where(
      (l) => l.caseType != 'طعن' && l.caseType != 'استئناف' && l.caseType != 'امر_اداء',
    ).toList();
    if (allLawsuits.isEmpty) {
      return _buildEmpty('لا توجد إجراءات', Icons.gavel_rounded, 'اضغط + لإضافة دعوى أو طعن أو أمر أداء');
    }
    final query = _lawsuitsSearchCtrl.text.trim().toLowerCase();
    final displayLawsuits = query.isEmpty
        ? allLawsuits
        : allLawsuits.where((l) {
            return (l.subject?.toLowerCase().contains(query) ?? false) ||
                l.caseNumber.toLowerCase().contains(query) ||
                (l.caseTypeDisplay.toLowerCase().contains(query));
          }).toList();
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _lawsuitsSearchCtrl,
            textDirection: ui.TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'بحث في الإجراءات...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _lawsuitsSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () { _lawsuitsSearchCtrl.clear(); setState(() {}); },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('${displayLawsuits.length} إجراء', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const Spacer(),
          ]),
        ),
        // List
        Expanded(
          child: displayLawsuits.isEmpty
              ? Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: displayLawsuits.length,
                  itemBuilder: (_, i) {
                    final l = displayLawsuits[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LawsuitDetailScreen(lawsuitId: l.id)),
                        ).then((_) => _load()),
                        leading: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 22),
                        ),
                        title: Text(l.subject ?? l.caseNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('${l.caseTypeDisplay} • ${l.caseStatusDisplay}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        trailing: const Icon(Icons.chevron_left, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Tab: الجلسات ─────────────────────────────────────────────────────────

  Widget _buildHearingsTab() {
    if (_isLoadingRelated && _hearings.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_hearings.isEmpty) {
      return _buildEmpty('لا توجد جلسات', Icons.calendar_month_rounded, 'لم يتم تسجيل أي جلسات لهذه القضية');
    }
    final query = _hearingsSearchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _hearings
        : _hearings.where((h) {
            final dateStr = DateFormat('yyyy/MM/dd').format(h.hearingDate);
            return dateStr.contains(query) ||
                h.typeDisplay.toLowerCase().contains(query) ||
                h.sessionTypeDisplay.toLowerCase().contains(query) ||
                h.requirements.toLowerCase().contains(query) ||
                h.notes.toLowerCase().contains(query);
          }).toList();
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _hearingsSearchCtrl,
            textDirection: ui.TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'بحث في الجلسات...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _hearingsSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () { _hearingsSearchCtrl.clear(); setState(() {}); },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),
        // Add Session + count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Text('${filtered.length} جلسة', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const Spacer(),
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SessionFormScreen()),
                    );
                    if (result != null) _loadRelatedData(_lawsuits, Provider.of<ApiService>(context, listen: false));
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('إضافة جلسة', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final h = filtered[i];
                    final isUpcoming = h.isUpcoming;
                    return InkWell(
                      onTap: () async {
                        final deleted = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SessionDetailScreen(session: h)),
                        );
                        if (deleted == true || deleted is HearingModel) _loadRelatedData(_lawsuits, Provider.of<ApiService>(context, listen: false));
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: _timelineItem(
                        date: DateFormat('yyyy/MM/dd').format(h.hearingDate),
                        title: '${h.typeDisplay} • ${h.sessionTypeDisplay}',
                        subtitle: h.requirements.isNotEmpty
                            ? h.requirements
                            : (h.notes.isNotEmpty ? h.notes : 'لا توجد ملاحظات'),
                        isFuture: isUpcoming,
                        icon: isUpcoming ? Icons.event_available : Icons.event_busy,
                        color: isUpcoming ? Colors.blue : AppColors.primary,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _timelineItem({
    required String date,
    required String title,
    required String subtitle,
    required bool isFuture,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          Container(width: 2, height: 40, color: Colors.grey.shade200),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFuture ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isFuture ? Colors.blue.shade100 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(date, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Tab: المستندات ───────────────────────────────────────────────────────

  Future<void> _deleteAttachment(AttachmentModel a) async {
    if (a.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المستند؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
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
      final api = Provider.of<ApiService>(context, listen: false);
      await api.deleteAttachment(a.id!);
      await _loadRelatedData(_lawsuits, api);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المستند بنجاح'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حذف المستند: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _previewAttachment(AttachmentModel a) {
    if (a.fileUrl == null || a.fileUrl!.isEmpty) {
      _showAttachmentInfo(a);
      return;
    }
    AttachmentUtils.preview(
      context,
      rawFileUrl: a.fileUrl,
      fileName: a.originalFilename,
    );
  }

  void _showAttachmentInfo(AttachmentModel a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a.originalFilename ?? a.typeDisplay),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('النوع', a.typeDisplay),
            _infoRow('الحجم', a.fileSizeDisplay),
            if (a.content.isNotEmpty) _infoRow('المحتوى', a.content),
            if (a.evidenceBasis.isNotEmpty) _infoRow('الأساس', a.evidenceBasis),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  void _editAttachmentDialog(AttachmentModel a) {
    final api = Provider.of<ApiService>(context, listen: false);
    String selectedType = a.documentType;
    final contentCtrl = TextEditingController(text: a.content);
    final evidenceCtrl = TextEditingController(text: a.evidenceBasis);
    final pageCtrl = TextEditingController(text: a.pageCount.toString());
    bool isSaving = false;

    final types = [
      {'value': 'identity', 'label': 'هوية/جواز سفر'},
      {'value': 'contract', 'label': 'عقد'},
      {'value': 'certificate', 'label': 'شهادة'},
      {'value': 'evidence', 'label': 'دليل'},
      {'value': 'statement', 'label': 'بيان'},
      {'value': 'receipt', 'label': 'إيصال'},
      {'value': 'other', 'label': 'أخرى'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('تعديل المستند', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'نوع المستند',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: types.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))).toList(),
                  onChanged: (v) => setBS(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'عدد الصفحات',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'محتوى المستند',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: evidenceCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'الأساس القانوني / الدليل',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: const Text('حفظ التعديلات'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: isSaving ? null : () async {
                      setBS(() => isSaving = true);
                      try {
                        await api.updateAttachment(
                          id: a.id!,
                          documentType: selectedType,
                          gregorianDate: DateFormat('yyyy-MM-dd').format(a.gregorianDate),
                          hijriDate: a.hijriDate,
                          pageCount: int.tryParse(pageCtrl.text) ?? a.pageCount,
                          content: contentCtrl.text,
                          evidenceBasis: evidenceCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          await _loadRelatedData(_lawsuits, api);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تحديث المستند بنجاح'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setBS(() => isSaving = false);
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _docTypes = [
    {'value': 'identity', 'label': 'هوية', 'icon': Icons.badge_rounded},
    {'value': 'contract', 'label': 'عقد', 'icon': Icons.handshake_rounded},
    {'value': 'certificate', 'label': 'شهادة', 'icon': Icons.workspace_premium_rounded},
    {'value': 'evidence', 'label': 'دليل', 'icon': Icons.policy_rounded},
    {'value': 'statement', 'label': 'بيان', 'icon': Icons.article_rounded},
    {'value': 'receipt', 'label': 'إيصال', 'icon': Icons.receipt_long_rounded},
    {'value': 'other', 'label': 'أخرى', 'icon': Icons.description_rounded},
  ];

  Widget _buildDocsTab() {
    if (_isLoadingRelated && _attachments.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_attachments.isEmpty) {
      return _buildEmpty('لا توجد مستندات', Icons.folder_copy_rounded, 'اضغط + لإضافة مستند جديد');
    }
    // Filter by search query and type
    final query = _docsSearchCtrl.text.trim().toLowerCase();
    final filtered = _attachments.where((a) {
      final matchesType = _docsTypeFilter == null || a.documentType == _docsTypeFilter;
      final matchesSearch = query.isEmpty ||
          (a.originalFilename?.toLowerCase().contains(query) ?? false) ||
          a.typeDisplay.toLowerCase().contains(query) ||
          a.content.toLowerCase().contains(query);
      return matchesType && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _docsSearchCtrl,
            textDirection: ui.TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'بحث في المستندات...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF2563EB)),
              suffixIcon: _docsSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () { _docsSearchCtrl.clear(); setState(() {}); },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),
        // Type filter chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text('الكل (${_attachments.length})', style: TextStyle(fontSize: 11, color: _docsTypeFilter == null ? Colors.white : Colors.grey[600])),
                  selected: _docsTypeFilter == null,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (_) => setState(() => _docsTypeFilter = null),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ..._docTypes.where((t) => _attachments.any((a) => a.documentType == t['value'])).map((t) {
                final count = _attachments.where((a) => a.documentType == t['value']).length;
                final isSelected = _docsTypeFilter == t['value'];
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('${t['label']} ($count)', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.grey[600])),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: Colors.grey.shade100,
                    onSelected: (_) => setState(() => _docsTypeFilter = isSelected ? null : t['value'] as String),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ],
          ),
        ),
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(children: [
            Text('${filtered.length} مستند', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const Spacer(),
          ]),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey[400])))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    final color = AttachmentUtils.fileColor(a.originalFilename, fallback: AppColors.primary);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                            leading: Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(AttachmentUtils.fileIcon(a.originalFilename), color: color, size: 22),
                            ),
                            title: Text(
                              a.originalFilename ?? a.typeDisplay,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            subtitle: Text(
                              '${a.typeDisplay} • ${a.createdAt != null ? DateFormat('yyyy/MM/dd').format(a.createdAt!) : '-'} • ${a.fileSizeDisplay}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                          ),
                          if (a.content.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Text(a.content, style: TextStyle(color: Colors.grey[700], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          const Divider(height: 1),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  icon: Icon(Icons.visibility_rounded, size: 16, color: color),
                                  label: Text('معاينة', style: TextStyle(fontSize: 12, color: color)),
                                  onPressed: () => _previewAttachment(a),
                                ),
                              ),
                              Container(width: 1, height: 32, color: Colors.grey.shade200),
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.orange),
                                  label: const Text('تعديل', style: TextStyle(fontSize: 12, color: Colors.orange)),
                                  onPressed: () => _editAttachmentDialog(a),
                                ),
                              ),
                              Container(width: 1, height: 32, color: Colors.grey.shade200),
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                  label: const Text('حذف', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  onPressed: () => _deleteAttachment(a),
                                ),
                              ),
                              if (a.fileUrl != null) ...[
                                Container(width: 1, height: 32, color: Colors.grey.shade200),
                                Expanded(
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.blueGrey),
                                    label: const Text('فتح', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                    onPressed: () {
                                      final fullUrl = AttachmentUtils.resolveUrl(a.fileUrl);
                                      if (fullUrl != null) {
                                        launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Tab: الطعون وأوامر الأداء ────────────────────────────────────────────

  Widget _buildAppealsTab() {
    final hasData = _appeals.isNotEmpty || _paymentOrders.isNotEmpty;
    if (_isLoadingRelated && !hasData) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (!hasData) {
      return _buildEmpty('لا توجد طعون أو أوامر أداء', Icons.history_edu_rounded, 'لم يتم تسجيل طعون أو أوامر أداء لهذه القضية');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_appeals.isNotEmpty) ...[
          _listHeader('الطعون (${_appeals.length})', Icons.history_edu_rounded, Colors.red),
          ..._appeals.map((a) => _appealTile(a)),
          const SizedBox(height: 12),
        ],
        if (_paymentOrders.isNotEmpty) ...[
          _listHeader('أوامر الأداء (${_paymentOrders.length})', Icons.request_page_rounded, Colors.amber.shade800),
          ..._paymentOrders.map((p) => _paymentTile(p)),
        ],
      ],
    );
  }

  Widget _listHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ]),
    );
  }

  Widget _appealTile(AppealModel a) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.shade100)),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history_edu_rounded, color: Colors.red),
        title: Text(a.appealNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text('${a.appealTypeDisplay} • ${a.statusDisplay}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppealScreen(lawsuitId: a.lawsuitId))).then((_) => _load()),
      ),
    );
  }

  Widget _paymentTile(PaymentOrderModel p) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.amber.shade100)),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.request_page_rounded, color: Colors.amber.shade800),
        title: Text(p.orderNumber ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text('${p.statusDisplay} • ${NumberFormat("#,###").format(p.amount)} ر.ي', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentOrderScreen(lawsuitId: p.lawsuitId))).then((_) => _load()),
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────

  Widget _buildEmpty(String title, IconData icon, String subtitle) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 60, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 60, color: Colors.red),
        const SizedBox(height: 16),
        Text(_error ?? 'حدث خطأ', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  // ─── Add Document Menu ──────────────────────────────────────────────────
  void _showAddDocumentMenu() {
    if (_lawsuits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إضافة إجراء (دعوى) أولاً قبل رفع المستندات'), backgroundColor: Colors.orange),
      );
      return;
    }
    // Pick the first (or only) lawsuit for this case
    final targetLawsuit = _lawsuits.first;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إضافة مستند جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('اختر طريقة إضافة المستند', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Upload file
                _docActionBtn(ctx, Icons.upload_file_rounded, 'رفع ملف', const Color(0xFF2563EB), () async {
                  Navigator.pop(ctx);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx'],
                  );
                  if (result != null && result.files.isNotEmpty) {
                    final file = result.files.first;
                    if (file.path != null) {
                      _showDocMetadataForm(filePath: file.path!, lawsuitId: targetLawsuit.id!);
                    }
                  }
                }),
                // Camera (Advanced Scanner)
                if (!kIsWeb)
                  _docActionBtn(ctx, Icons.document_scanner_rounded, 'الماسح الذكي', AppColors.primary, () async {
                    Navigator.pop(ctx);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DocumentScannerScreen()),
                    );
                    if (result != null && result is String) {
                      _showDocMetadataForm(filePath: result, lawsuitId: targetLawsuit.id!);
                    }
                  }),
                  _docActionBtn(ctx, Icons.camera_alt_rounded, 'كاميرا', Colors.green, () async {
                    Navigator.pop(ctx);
                    final result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      if (file.path != null) {
                        _showDocMetadataForm(filePath: file.path!, lawsuitId: targetLawsuit.id!);
                      }
                    }
                  }),
                // Scanner
                _docActionBtn(ctx, Icons.document_scanner_rounded, 'ماسح ضوئي', Colors.deepPurple, () async {
                  Navigator.pop(ctx);
                  final scannedPath = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const DocumentScannerScreen()),
                  );
                  if (scannedPath != null && scannedPath.isNotEmpty) {
                    _showDocMetadataForm(filePath: scannedPath, lawsuitId: targetLawsuit.id!);
                  }
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _docActionBtn(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  void _showDocMetadataForm({required String filePath, required int lawsuitId}) {
    String selectedType = 'other';
    final contentCtrl = TextEditingController();
    final evidenceCtrl = TextEditingController();
    final pageCtrl = TextEditingController(text: '1');
    bool isSaving = false;

    final fileName = filePath.split('/').last.split('\\').last;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('بيانات المستند', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_rounded, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(fileName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'نوع المستند',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _docTypes.map((t) => DropdownMenuItem(value: t['value'] as String, child: Text(t['label'] as String))).toList(),
                  onChanged: (v) => setBS(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'عدد الصفحات',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  textDirection: ui.TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'وصف المستند',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: evidenceCtrl,
                  maxLines: 2,
                  textDirection: ui.TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'الأساس القانوني / الدليل',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(isSaving ? 'جارٍ الرفع...' : 'رفع المستند'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isSaving ? null : () async {
                      setBS(() => isSaving = true);
                      try {
                        final now = DateTime.now();
                        final hijri = HijriCalendar.fromDate(now);
                        final api = Provider.of<ApiService>(context, listen: false);
                        await api.uploadAttachment(
                          lawsuitId: lawsuitId,
                          filePath: filePath,
                          documentType: selectedType,
                          gregorianDate: DateFormat('yyyy-MM-dd').format(now),
                          hijriDate: '${hijri.hYear}-${hijri.hMonth.toString().padLeft(2, '0')}-${hijri.hDay.toString().padLeft(2, '0')}',
                          pageCount: int.tryParse(pageCtrl.text) ?? 1,
                          content: contentCtrl.text.trim(),
                          evidenceBasis: evidenceCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          await _loadRelatedData(_lawsuits, Provider.of<ApiService>(context, listen: false));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم رفع المستند بنجاح'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setBS(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('خطأ في رفع المستند: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddActionMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إضافة إجراء جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('اختر نوع الإجراء لإضافته إلى هذه القضية', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(ctx, Icons.gavel_rounded, 'دعوى', Colors.green, 'دعوى'),
                _actionButton(ctx, Icons.history_edu_rounded, 'طعن', Colors.red, 'طعن'),
                _actionButton(ctx, Icons.request_page_rounded, 'أمر أداء', Colors.amber.shade800, 'امر_اداء'),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PowerOfAttorneyScreen(
                    caseId: widget.caseId,
                    clientName: _case?.parties?.where((p) => p.role == 'client').firstOrNull?.name,
                    clientPhone: _case?.parties?.where((p) => p.role == 'client').firstOrNull?.phone,
                  ),
                ));
              },
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.description_rounded, color: Colors.deepPurple),
              ),
              title: const Text('إنشاء وكالة خاصة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              trailing: const Icon(Icons.chevron_left, color: Colors.grey),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext ctx, IconData icon, String label, Color color, String type) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _createLawsuitForCase(type),
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
