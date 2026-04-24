import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/hearing_model.dart';
import '../models/case_model.dart';
import '../models/attachment_model.dart';
import '../providers/session_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/attachment_utils.dart';
import 'session_form_screen.dart';
import 'case_detail_screen.dart';

/// Session Detail Screen - شاشة تفاصيل الجلسة
class SessionDetailScreen extends StatefulWidget {
  final HearingModel session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HearingModel _session;

  CaseModel? _case;
  List<AttachmentModel> _attachments = [];
  List<HearingModel> _caseSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    // Load case info
    if (_session.caseId != null) {
      try {
        _case = await api.getCase(_session.caseId!);
      } catch (e) {
        debugPrint('Error loading case: $e');
      }
    }
    // Load attachments for the lawsuit
    if (_session.lawsuitId > 0) {
      try {
        final attResp = await api.getAttachments(lawsuitId: _session.lawsuitId);
        _attachments = _extractList(attResp)
            .map((e) => AttachmentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading attachments: $e');
      }
    }
    // Load all sessions for this case
    if (_session.caseId != null) {
      try {
        final sessResp = await api.getHearings(caseId: _session.caseId!);
        _caseSessions = _extractList(sessResp)
            .map((e) => HearingModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _caseSessions.sort((a, b) => b.hearingDate.compareTo(a.hearingDate));
      } catch (e) {
        debugPrint('Error loading sessions: $e');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Smart Advisor Tips ────────────────────────────────
  List<_Tip> _buildTips() {
    final tips = <_Tip>[];
    // 1. Missing requirements
    if (_session.isUpcoming && _session.requirements.isEmpty) {
      final daysLeft = _session.hearingDate.difference(DateTime.now()).inDays;
      if (daysLeft <= 3) {
        tips.add(_Tip(
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
          text: 'اقترب موعد الجلسة ولم يتم إدخال المطلوب!',
        ));
      }
    }
    // 2. Previous sessions without decision
    for (final s in _caseSessions) {
      if (s.id != _session.id && s.isPrevious && (s.courtDecision == null || s.courtDecision!.isEmpty)) {
        tips.add(_Tip(
          icon: Icons.info_outline,
          color: AppColors.info,
          text: 'يوجد جلسة سابقة (${DateFormat('yyyy/MM/dd').format(s.hearingDate)}) بدون قرار مسجل',
        ));
        break;
      }
    }
    // 3. Missing attachments
    if (_attachments.isEmpty && _session.isUpcoming) {
      tips.add(_Tip(
        icon: Icons.attach_file,
        color: AppColors.coral,
        text: 'لم يتم رفع أي مرفقات بعد — تأكد من جاهزية المستندات',
      ));
    }
    return tips;
  }

  // ─── Record Decision Dialog ────────────────────────────
  void _showRecordDecisionDialog() {
    final decisionCtrl = TextEditingController();
    DateTime? nextDate;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تسجيل القرار والجلسة القادمة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: decisionCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'قرار المحكمة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: AppColors.brand),
                    title: Text(nextDate != null
                        ? DateFormat('yyyy/MM/dd').format(nextDate!)
                        : 'اختر موعد الجلسة القادمة'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 14)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) setDialogState(() => nextDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                onPressed: () async {
                  if (decisionCtrl.text.trim().isEmpty || nextDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال القرار واختيار تاريخ الجلسة القادمة')),
                    );
                    return;
                  }
                  Navigator.pop(dCtx);
                  final provider = Provider.of<SessionProvider>(context, listen: false);
                  final next = await provider.recordDecisionAndCreateNext(
                    sessionId: _session.id!,
                    courtDecision: decisionCtrl.text.trim(),
                    nextDate: nextDate!,
                    lawsuitId: _session.lawsuitId,
                    caseId: _session.caseId,
                  );
                  if (next != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل القرار وإنشاء الجلسة القادمة')),
                    );
                    await _load();
                    // Update local session
                    final idx = _caseSessions.indexWhere((s) => s.id == _session.id);
                    if (idx != -1) setState(() => _session = _caseSessions[idx]);
                  }
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tips = _buildTips();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _session.isUpcoming
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _session.sessionTypeDisplay,
                                  style: TextStyle(
                                    color: _session.isUpcoming ? Colors.blue[100] : Colors.orange[100],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _session.typeDisplay,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('yyyy/MM/dd - EEEE', 'ar').format(_session.hearingDate),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (_session.hearingTime != null)
                            Text(
                              '${_session.hearingTime} • ${_session.timeOfDayDisplay}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final result = await Navigator.push<HearingModel>(
                      context,
                      MaterialPageRoute(builder: (_) => SessionFormScreen(session: _session)),
                    );
                    if (result != null && mounted) {
                      setState(() => _session = result);
                      _load();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => Directionality(
                        textDirection: ui.TextDirection.rtl,
                        child: AlertDialog(
                          title: const Text('حذف الجلسة'),
                          content: const Text('هل أنت متأكد من حذف هذه الجلسة؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('حذف', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (confirm == true && mounted) {
                      final provider = Provider.of<SessionProvider>(context, listen: false);
                      final ok = await provider.deleteSession(_session.id!);
                      if (ok && mounted) Navigator.pop(context, true);
                    }
                  },
                ),
              ],
            ),
            // Smart Advisor Tips
            if (tips.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates, color: AppColors.gold, size: 18),
                          SizedBox(width: 6),
                          Text('نصائح ذكية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.goldDark)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...tips.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(t.icon, size: 16, color: t.color),
                            const SizedBox(width: 6),
                            Expanded(child: Text(t.text, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            // Record Decision Button
            if (_session.isUpcoming)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: ElevatedButton.icon(
                    onPressed: _showRecordDecisionDialog,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تسجيل القرار والجلسة القادمة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            // Requirements card
            SliverToBoxAdapter(
              child: _buildRequirementsCard(),
            ),
            // TabBar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.brand,
                  labelColor: AppColors.brand,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'ملف القضية'),
                    Tab(text: 'الجلسات'),
                    Tab(text: 'المرفقات'),
                    Tab(text: 'السجل'),
                  ],
                ),
              ),
            ),
          ],
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCaseFileTab(),
                    _buildSessionsListTab(),
                    _buildAttachmentsTab(),
                    _buildLogTab(),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Requirements Card ─────────────────────────────────
  Widget _buildRequirementsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment, size: 18, color: AppColors.brand),
              const SizedBox(width: 6),
              const Text('المطلوب في الجلسة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              InkWell(
                onTap: _editRequirements,
                child: const Icon(Icons.edit, size: 16, color: AppColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _session.requirements.isEmpty ? 'لم يحدد بعد' : _session.requirements,
            style: TextStyle(fontSize: 13, color: _session.requirements.isEmpty ? Colors.grey : Colors.black87),
          ),
          if (_session.courtDecision != null && _session.courtDecision!.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.balance, size: 16, color: AppColors.goldDark),
                const SizedBox(width: 6),
                const Text('قرار المحكمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(_session.courtDecision!, style: const TextStyle(fontSize: 13)),
          ],
          if (_session.nextSessionDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_repeat, size: 16, color: AppColors.info),
                const SizedBox(width: 6),
                Text('الجلسة القادمة: ${DateFormat('yyyy/MM/dd').format(_session.nextSessionDate!)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.info)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _editRequirements() {
    final ctrl = TextEditingController(text: _session.requirements);
    showDialog(
      context: context,
      builder: (dCtx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل المطلوب'),
          content: TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () { FocusScope.of(dCtx).unfocus(); Navigator.pop(dCtx); }, child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () async {
                FocusScope.of(dCtx).unfocus();
                Navigator.pop(dCtx);
                final prov = Provider.of<SessionProvider>(context, listen: false);
                final updated = await prov.updateSession(_session.id!, {'requirements': ctrl.text.trim()});
                if (updated != null && mounted) setState(() => _session = updated);
              },
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab: ملف القضية ──────────────────────────────────
  Widget _buildCaseFileTab() {
    if (_case == null) {
      return const Center(child: Text('لا توجد بيانات قضية'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoRow('رقم القضية', _case!.caseNumber),
        _infoRow('الموضوع', _case!.subject ?? '-'),
        _infoRow('الوصف', _case!.description ?? '-'),
        _infoRow('نوع القضية', _case!.caseType ?? '-'),
        _infoRow('حالة القضية', _case!.caseStatus ?? '-'),
        _infoRow('المحكمة', _case!.courtName ?? '-'),
        _infoRow('المحافظة', _case!.governorate ?? '-'),
        if (_case!.clientName != null) _infoRow('الموكل', _case!.clientName!),
        const SizedBox(height: 16),
        if (_case!.id != null)
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CaseDetailScreen(caseId: _case!.id!),
              ));
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('فتح ملف القضية'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.brand),
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ─── Tab: الجلسات ─────────────────────────────────────
  Widget _buildSessionsListTab() {
    if (_caseSessions.isEmpty) {
      return const Center(child: Text('لا توجد جلسات أخرى'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _caseSessions.length,
      itemBuilder: (_, i) {
        final s = _caseSessions[i];
        final isCurrent = s.id == _session.id;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.brand.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isCurrent ? AppColors.brand : Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: isCurrent
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
                  ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: s.isUpcoming ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    s.isUpcoming ? Icons.event_available : Icons.event_busy,
                    size: 18,
                    color: s.isUpcoming ? Colors.blue : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('yyyy/MM/dd').format(s.hearingDate),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${s.typeDisplay} • ${s.sessionTypeDisplay}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('الحالية', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Tab: المرفقات ────────────────────────────────────
  Widget _buildAttachmentsTab() {
    if (_attachments.isEmpty) {
      return const Center(child: Text('لا توجد مرفقات'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _attachments.length,
      itemBuilder: (_, i) {
        final att = _attachments[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AttachmentUtils.fileColor(att.fileUrl).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                AttachmentUtils.fileIcon(att.fileUrl),
                color: AttachmentUtils.fileColor(att.fileUrl),
                size: 22,
              ),
            ),
            title: Text(att.documentType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(att.content, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () => AttachmentUtils.preview(context, rawFileUrl: att.fileUrl, fileName: att.documentType),
            ),
            onTap: () => AttachmentUtils.preview(context, rawFileUrl: att.fileUrl, fileName: att.documentType),
          ),
        );
      },
    );
  }

  // ─── Tab: السجل ───────────────────────────────────────
  Widget _buildLogTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _logItem('تاريخ الإنشاء', _session.createdAt != null ? DateFormat('yyyy/MM/dd HH:mm').format(_session.createdAt!) : '-'),
        _logItem('آخر تحديث', _session.updatedAt != null ? DateFormat('yyyy/MM/dd HH:mm').format(_session.updatedAt!) : '-'),
        _logItem('نوع الجلسة', _session.typeDisplay),
        _logItem('تصنيف الجلسة', _session.sessionTypeDisplay),
        _logItem('الفترة', _session.timeOfDayDisplay),
        _logItem('حالة الأرشفة', _session.archiveStatusDisplay),
        if (_session.courtDecision != null && _session.courtDecision!.isNotEmpty)
          _logItem('القرار', _session.courtDecision!),
        if (_session.nextSessionDate != null)
          _logItem('الجلسة القادمة', DateFormat('yyyy/MM/dd').format(_session.nextSessionDate!)),
      ],
    );
  }

  Widget _logItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.brand),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// ─── Helper classes ──────────────────────────────────────

class _Tip {
  final IconData icon;
  final Color color;
  final String text;
  const _Tip({required this.icon, required this.color, required this.text});
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
