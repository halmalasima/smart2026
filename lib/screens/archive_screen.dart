import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/lawsuit_provider.dart';
import '../models/case_model.dart';
import '../services/api_service.dart';
import '../services/local_lookup_service.dart';
import '../providers/session_provider.dart';
import '../models/hearing_model.dart';
import 'case_detail_screen.dart';
import 'session_form_screen.dart';
import 'session_detail_screen.dart';

/// Archive Screen - شاشة الأرشيف المركزية الشاملة
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;
  bool _isGridView = false;

  List _extractListFromApiResponse(dynamic response) {
    if (response == null) return const [];
    if (response is List) return response;
    if (response is Map) {
      final dynamic directResults = response['results'] ?? response['data'] ?? response['items'];
      if (directResults is List) return directResults;
      if (directResults is Map) {
        final dynamic nestedResults = directResults['results'] ?? directResults['data'] ?? directResults['items'];
        if (nestedResults is List) return nestedResults;
      }
    }
    return const [];
  }

  // Filter selections
  String? _selectedCaseType;
  String? _selectedCaseStatus;
  String? _selectedArchiveStatus;
  String? _selectedOrdering;

  static const _caseTypes = [
    {'value': 'مدنية', 'label': 'مدنية'},
    {'value': 'جزائية', 'label': 'جزائية'},
    {'value': 'شخصية', 'label': 'شخصية'},
    {'value': 'تجارية', 'label': 'تجارية'},
    {'value': 'إدارية', 'label': 'إدارية'},
    {'value': 'تنفيذ', 'label': 'تنفيذ'},
  ];

  static const _caseStatuses = [
    {'value': 'جديد', 'label': 'جديد'},
    {'value': 'قيد_النظر', 'label': 'قيد النظر'},
    {'value': 'مكتمل', 'label': 'مكتمل'},
    {'value': 'مغلق', 'label': 'مغلق'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LawsuitProvider>(context, listen: false);
      provider.loadCases(refresh: true);
      provider.loadArchiveStats();
      Provider.of<SessionProvider>(context, listen: false).loadSessions();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final provider = Provider.of<LawsuitProvider>(context, listen: false);
      switch (_tabController.index) {
        case 0:
          provider.setCaseStatusFilter(null);
          _selectedCaseStatus = null;
          break;
        case 1:
          provider.setCaseStatusFilter('جديد');
          _selectedCaseStatus = 'جديد';
          break;
        case 2:
          provider.setCaseStatusFilter('مكتمل');
          _selectedCaseStatus = 'مكتمل';
          break;
        case 3:
          // Sessions tab — no case filter
          return;
      }
      provider.loadCases(refresh: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final provider = Provider.of<LawsuitProvider>(context, listen: false);
      if (provider.casesHasMore && !provider.isLoadingCases) {
        provider.loadCases();
      }
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim();
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    provider.setSearchQuery(query.isEmpty ? null : query);
    provider.loadCases(refresh: true);
    
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    sessionProvider.setSearchQuery(query.isEmpty ? null : query);
  }

  void _applyFilters() {
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    provider.setCaseTypeFilter(_selectedCaseType);
    provider.setCaseStatusFilter(_selectedCaseStatus);
    provider.setOrdering(_selectedOrdering);
    provider.loadCases(refresh: true);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterBottomSheet(
        selectedCaseType: _selectedCaseType,
        selectedCaseStatus: _selectedCaseStatus,
        selectedArchiveStatus: _selectedArchiveStatus,
        selectedOrdering: _selectedOrdering,
        onApply: (caseType, caseStatus, archiveStatus, ordering) {
          setState(() {
            _selectedCaseType = caseType;
            _selectedCaseStatus = caseStatus;
            _selectedArchiveStatus = archiveStatus;
            _selectedOrdering = ordering;
          });
          _applyFilters();
        },
        onClear: () {
          _clearFilters();
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedCaseType = null;
      _selectedCaseStatus = null;
      _selectedArchiveStatus = null;
      _selectedOrdering = null;
      _searchController.clear();
    });
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    provider.clearFilters();
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    sessionProvider.setSearchQuery(null);
    provider.loadCases(refresh: true);
    sessionProvider.loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header with search (reduced padding when keyboard is visible)
            _buildHeader(isKeyboardVisible: isKeyboardVisible),
            // Stats bar (hidden when keyboard is visible to save space)
            if (!isKeyboardVisible) _buildStatsBar(),
            // Tabs (hidden when keyboard is visible to save space)
            if (!isKeyboardVisible) _buildTabs(),
            // Filter chips (hidden when keyboard is visible to save space)
            if (!isKeyboardVisible) _buildActiveFilterChips(),
            // Results list (takes remaining space, scrollable)
            Expanded(
              child: _tabController.index == 3
                  ? _buildSessionsTab()
                  : _buildResultsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: isKeyboardVisible
          ? null
          : _tabController.index == 3
              ? FloatingActionButton.extended(
                  heroTag: 'add_new_session',
                  backgroundColor: AppColors.brand,
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SessionFormScreen()),
                    );
                    if (result != null) {
                      Provider.of<SessionProvider>(context, listen: false).loadSessions();
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: const Text('إضافة جلسة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              : FloatingActionButton.extended(
                  heroTag: 'add_new_case',
                  backgroundColor: AppColors.brand,
                  onPressed: _showNewCaseForm,
                  icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
                  label: const Text('إنشاء ملف قضية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
    );
  }

  Widget _buildHeader({bool isKeyboardVisible = false}) {
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    return Container(
      padding: EdgeInsets.fromLTRB(6, isKeyboardVisible ? 1 : 1, 1, isKeyboardVisible ? 1 : 1),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkSurface : AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: AppColors.lightShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row (hidden when keyboard is visible)
          if (!isKeyboardVisible)
            Row(
              children: [
                // Toggle view
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, 
                    color: AppColors.lightTextSecondary),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
                ),
                // Filter button
                Consumer<LawsuitProvider>(
                  builder: (context, provider, _) {
                    return Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            color: provider.hasActiveFilters ? AppColors.brand : AppColors.lightTextSecondary,
                          ),
                          onPressed: _showFilterSheet,
                          tooltip: 'فلترة',
                        ),
                        if (provider.hasActiveFilters)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                // Purge button (Delete All)
                IconButton(
                  icon: Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                  onPressed: () => _confirmResetDatabase(provider),
                  tooltip: 'مسح الأرشيف بالكامل',
                ),
                // Refresh button
                IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.brand),
                  onPressed: () => provider.loadLawsuits(refresh: true),
                  tooltip: 'تحديث',
                ),
                Expanded(
                  child: Text(
                    'أرشيف القضايا',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightTextPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 7),
                Icon(Icons.archive_outlined, color: AppColors.brand, size: 28),
              ],
            ),
          if (!isKeyboardVisible) const SizedBox(height: 3),
          // Search bar with compact controls when keyboard is visible
          if (isKeyboardVisible) const SizedBox(height: 0.5),
          Row(
            children: [
              // Toggle view (shown when keyboard is visible)
              if (isKeyboardVisible)
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, 
                    color: AppColors.lightTextTertiary, size: 12),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
                ),
              // Filter button (shown when keyboard is visible)
              if (isKeyboardVisible)
                Consumer<LawsuitProvider>(
                  builder: (context, provider, _) {
                    return Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            color: provider.hasActiveFilters ? AppColors.brand : AppColors.lightTextTertiary,
                            size: 14,
                          ),
                          onPressed: _showFilterSheet,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'فلترة',
                        ),
                        if (provider.hasActiveFilters)
                          Positioned(
                            top: 4, right: 4,
                            child: Container(
                              width: 5, height: 5,
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (isKeyboardVisible) const SizedBox(width: 1),
              // Search bar
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textDirection: ui.TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم الدعوى، الموضوع، الأطراف...',
                    hintStyle: TextStyle(color: AppColors.lightTextTertiary, fontSize: 14),
                    prefixIcon: IconButton(
                      icon: Icon(Icons.search, color: AppColors.brand),
                      onPressed: _applySearch,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            _applySearch();
                          },
                        )
                      : null,
                    filled: true,
                    fillColor: AppColors.lightSurfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10, 
                      vertical: isKeyboardVisible ? 1 : 1,
                    ),
                  ),
                  onSubmitted: (_) => _applySearch(),
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Consumer<LawsuitProvider>(
      builder: (context, provider, _) {
        final stats = provider.archiveStats;
        final total = stats != null ? stats['total'] : provider.casesTotalCount;
        
        int activeCount = 0;
        int archivedCount = 0;
        if (stats != null && stats['by_archive_status'] != null) {
          activeCount = stats['by_archive_status']['active'] ?? 0;
          archivedCount = stats['by_archive_status']['archived'] ?? 0;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _buildStatChip('إجمالي القضايا', total, context.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, Icons.folder_copy_outlined),
                const SizedBox(width: 6),
                _buildStatChip('قيد النظر', activeCount, AppColors.brand, Icons.pending_actions_rounded),
                const SizedBox(width: 6),
                _buildStatChip('مؤرشفة', archivedCount, Colors.teal, Icons.archive_outlined),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, dynamic count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: context.isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.brand,
        labelColor: AppColors.brand,
        unselectedLabelColor: AppColors.lightTextTertiary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'جميع القضايا'),
          Tab(text: 'الجديدة'),
          Tab(text: 'المكتملة'),
          Tab(text: 'الجلسات'),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Consumer<LawsuitProvider>(
      builder: (context, provider, _) {
        if (!provider.hasActiveFilters) return const SizedBox.shrink();
        
        final chips = <Widget>[];
        
        if (provider.searchQuery != null && provider.searchQuery!.isNotEmpty) {
          chips.add(_buildChip('بحث: ${provider.searchQuery}', () {
            _searchController.clear();
            provider.setSearchQuery(null);
            provider.loadLawsuits(refresh: true);
          }));
        }
        if (provider.caseTypeFilter != null) {
          final label = _caseTypes.firstWhere(
            (t) => t['value'] == provider.caseTypeFilter,
            orElse: () => {'label': provider.caseTypeFilter!},
          )['label']!;
          chips.add(_buildChip('النوع: $label', () {
            setState(() => _selectedCaseType = null);
            provider.setCaseTypeFilter(null);
            provider.loadLawsuits(refresh: true);
          }));
        }
        if (provider.caseStatusFilter != null) {
          final label = _caseStatuses.firstWhere(
            (s) => s['value'] == provider.caseStatusFilter,
            orElse: () => {'label': provider.caseStatusFilter!},
          )['label']!;
          chips.add(_buildChip('الحالة: $label', () {
            setState(() => _selectedCaseStatus = null);
            provider.setCaseStatusFilter(null);
            provider.loadLawsuits(refresh: true);
          }));
        }

        chips.add(
          ActionChip(
            label: Text('مسح الكل', style: TextStyle(color: AppColors.error, fontSize: 12)),
            backgroundColor: AppColors.error.withOpacity(0.05),
            side: BorderSide(color: AppColors.error.withOpacity(0.3)),
            onPressed: _clearFilters,
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(children: chips.map((c) => Padding(padding: const EdgeInsets.only(left: 6), child: c)).toList()),
          ),
        );
      },
    );
  }

  Widget _buildChip(String label, VoidCallback onDelete) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDelete,
      backgroundColor: AppColors.brand.withOpacity(0.08),
      deleteIconColor: AppColors.brand,
      side: BorderSide(color: AppColors.brand.withOpacity(0.3)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildResultsList() {
    return Consumer<LawsuitProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingCases && provider.cases.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A940)));
        }

        if (provider.casesErrorMessage != null && provider.cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 14),
                Text(
                  provider.casesErrorMessage ?? 'حدث خطأ',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => provider.loadCases(refresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 80, color: AppColors.lightTextTertiary),
                const SizedBox(height: 14),
                Text(
                  provider.hasActiveFilters ? 'لا توجد نتائج مطابقة' : 'لا توجد قضايا بعد',
                  style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  provider.hasActiveFilters
                      ? 'جرّب تغيير معايير البحث أو الفلترة'
                      : 'اضغط إنشاء ملف قضية لإضافة قضية جديدة',
                  style: TextStyle(color: AppColors.lightTextTertiary, fontSize: 14),
                ),
                if (provider.hasActiveFilters) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_list_off),
                    label: const Text('مسح الفلاتر'),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async {
            await provider.loadCases(refresh: true);
            await provider.loadArchiveStats();
          },
          child: _isGridView ? _buildGridView(provider) : _buildListView(provider),
        );
      },
    );
  }

  Widget _buildListView(LawsuitProvider provider) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final cases = provider.cases;
    final itemCount = cases.length + (provider.isLoadingCases && cases.isNotEmpty ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(8, 8, 8, isKeyboardVisible ? 0 : 30),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == cases.length) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.brand),
          ));
        }
        return _CaseArchiveCard(caseModel: cases[index]);
      },
    );
  }

  Widget _buildGridView(LawsuitProvider provider) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final cases = provider.cases;

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(8, 8, 8, isKeyboardVisible ? 0 : 30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: cases.length + (provider.isLoadingCases && cases.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == cases.length) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brand));
        }
        return _CaseArchiveCard(caseModel: cases[index], isGrid: true);
      },
    );
  }

  // ─── Sessions Tab ─────────────────────────────────────────────
  Widget _buildSessionsTab() {
    return Consumer<SessionProvider>(
      builder: (context, prov, _) {
        if (prov.isLoading && prov.sessions.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.brand));
        }
        if (prov.error != null && prov.sessions.isEmpty) {
          return Center(child: Text(prov.error!, style: TextStyle(color: AppColors.error)));
        }

        final query = prov.searchQuery?.toLowerCase() ?? '';
        final filtered = prov.sessions.where((s) {
          // Date period filter
          bool matchesPeriod = true;
          final d = DateTime(s.hearingDate.year, s.hearingDate.month, s.hearingDate.day);
          switch (prov.periodFilter) {
            case 'today':
              final now = DateTime.now();
              matchesPeriod = d.isAtSameMomentAs(DateTime(now.year, now.month, now.day));
              break;
            case 'week':
              final now = DateTime.now();
              final start = now.subtract(Duration(days: now.weekday - 6));
              final startDay = DateTime(start.year, start.month, start.day);
              final endDay = startDay.add(const Duration(days: 7));
              matchesPeriod = !d.isBefore(startDay) && d.isBefore(endDay);
              break;
            case 'month':
              final now = DateTime.now();
              matchesPeriod = s.hearingDate.year == now.year && s.hearingDate.month == now.month;
              break;
            case 'custom':
              if (prov.customFrom != null && prov.customTo != null) {
                final from = DateTime(prov.customFrom!.year, prov.customFrom!.month, prov.customFrom!.day);
                final to = DateTime(prov.customTo!.year, prov.customTo!.month, prov.customTo!.day, 23, 59, 59);
                matchesPeriod = !s.hearingDate.isBefore(from) && !s.hearingDate.isAfter(to);
              }
              break;
          }
          
          // Search query filter
          bool matchesSearch = query.isEmpty ||
              (s.lawsuitNumber?.toLowerCase().contains(query) ?? false) ||
              (s.typeDisplay.toLowerCase().contains(query)) ||
              (s.sessionTypeDisplay.toLowerCase().contains(query)) ||
              (s.notes.toLowerCase().contains(query)) ||
              (s.requirements.toLowerCase().contains(query));
          
          return matchesPeriod && matchesSearch;
        }).toList();

        return Column(
          children: [
            // Period filter chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    _periodChip('اليوم', 'today', prov),
                    const SizedBox(width: 6),
                    _periodChip('الأسبوع', 'week', prov),
                    const SizedBox(width: 6),
                    _periodChip('الشهر', 'month', prov),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: Text(
                        prov.periodFilter == 'custom' && prov.customFrom != null
                            ? '${DateFormat('MM/dd').format(prov.customFrom!)} - ${DateFormat('MM/dd').format(prov.customTo!)}'
                            : 'مخصص',
                        style: TextStyle(
                          fontSize: 12,
                          color: prov.periodFilter == 'custom' ? Colors.white : AppColors.lightTextSecondary,
                        ),
                      ),
                      backgroundColor: prov.periodFilter == 'custom' ? AppColors.brand : AppColors.lightSurfaceVariant,
                      side: BorderSide(
                        color: prov.periodFilter == 'custom' ? AppColors.brand : AppColors.lightBorder,
                      ),
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (range != null) {
                          prov.setCustomRange(range.start, range.end);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Sessions count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${filtered.length} جلسة',
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: AppColors.brand),
                    onPressed: () => prov.loadSessions(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Sessions list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: AppColors.lightTextTertiary),
                          const SizedBox(height: 12),
                          Text('لا توجد جلسات في هذه الفترة',
                            style: TextStyle(color: AppColors.lightTextTertiary, fontSize: 14)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: () => prov.loadSessions(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _SessionCard(session: filtered[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _periodChip(String label, String value, SessionProvider prov) {
    final isSelected = prov.periodFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.lightTextSecondary)),
      selected: isSelected,
      selectedColor: AppColors.brand,
      backgroundColor: AppColors.lightSurfaceVariant,
      side: BorderSide(color: isSelected ? AppColors.brand : AppColors.lightBorder),
      onSelected: (_) => prov.setPeriodFilter(value),
    );
  }

  void _showNewCaseForm() {
    final outerContext = context;
    final navigator = Navigator.of(context);
    final caseNumberController = TextEditingController();
    final subjectController = TextEditingController();
    int? selectedCaseYear;

    String selectedCaseType = 'مدنية';
    String? selectedCaseSubtype;
    List<String> subtypeOptions = [];
    String selectedCaseStatus = 'جديد';
    DateTime? filingDateGregorian = DateTime.now();

    // Governorate -> Courts (local-first)
    List<Map<String, dynamic>> governorates = [];
    List<Map<String, dynamic>> courts = [];
    bool isLoadingGovernorates = false;
    bool isLoadingCourts = false;
    bool didInit = false;
    String? selectedGovernorateName;
    int? selectedGovernorateId;
    int? selectedCourtId;

    // Parties
    List<Map<String, dynamic>> clientParties = [];
    List<Map<String, dynamic>> opponentParties = [];

    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {

          // ── Load governorates (local first, then API) ──
          Future<void> loadGovernorates() async {
            if (isLoadingGovernorates) return;
            setSheetState(() => isLoadingGovernorates = true);
            try {
              // Try local cache first
              var cached = await LocalLookupService.getGovernorates();
              if (cached.isNotEmpty) {
                setSheetState(() => governorates = cached);
              }
              // Sync from API in background
              final apiService = Provider.of<ApiService>(ctx, listen: false);
              final synced = await LocalLookupService.syncGovernorates(apiService);
              if (synced.isNotEmpty) {
                setSheetState(() => governorates = synced);
              }
            } catch (_) {}
            finally { setSheetState(() => isLoadingGovernorates = false); }
          }

          Future<void> loadCourts({required int governorateId}) async {
            if (isLoadingCourts) return;
            setSheetState(() => isLoadingCourts = true);
            try {
              final gov = governorates.firstWhere(
                (g) => g['id'] == governorateId,
                orElse: () => <String, dynamic>{},
              );
              if (gov.isNotEmpty && gov['courts'] != null) {
                final courtsData = gov['courts'] as List?;
                setSheetState(() {
                  courts = (courtsData ?? [])
                      .map((e) => {'id': e['id'], 'name': e['name'] ?? e['court_name'] ?? ''})
                      .toList().cast<Map<String, dynamic>>();
                });
              } else {
                final apiService = Provider.of<ApiService>(ctx, listen: false);
                final dynamic response = await apiService.getCourts(queryParams: {'governorate': governorateId.toString()});
                final List results = _extractListFromApiResponse(response);
                setSheetState(() {
                  courts = results
                      .map((e) => {'id': e['id'], 'name': e['court_name'] ?? e['name'] ?? ''})
                      .toList().cast<Map<String, dynamic>>();
                });
              }
            } catch (_) {}
            finally { setSheetState(() => isLoadingCourts = false); }
          }

          Future<void> loadSubtypes(String caseType) async {
            final subs = await LocalLookupService.getSubtypes(caseType);
            setSheetState(() {
              subtypeOptions = subs;
              selectedCaseSubtype = null;
            });
          }

          if (!didInit) {
            didInit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadGovernorates();
              loadSubtypes(selectedCaseType);
            });
          }

          // ── Helper for input decoration ──
          InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF1B5E3B), size: 20),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          );

          // ── Party add dialog ──
          void addParty(String role) {
            final nameCtrl = TextEditingController();
            final phoneCtrl = TextEditingController();
            final idCtrl = TextEditingController();
            final idFromCtrl = TextEditingController();
            final addressCtrl = TextEditingController();
            String entityType = 'person';

            showDialog(
              context: ctx,
              builder: (dCtx) => StatefulBuilder(
                builder: (dCtx, setDState) => AlertDialog(
                  title: Text(role == 'client' ? 'إضافة موكل (طرف أول)' : 'إضافة خصم (طرف ثاني)', textAlign: TextAlign.right),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
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
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: nameCtrl, textDirection: ui.TextDirection.rtl, decoration: _inputDeco('الاسم *', Icons.person)),
                        const SizedBox(height: 10),
                        if (role == 'client')
                          TextField(controller: phoneCtrl, textDirection: ui.TextDirection.rtl, keyboardType: TextInputType.phone, decoration: _inputDeco('رقم الهاتف', Icons.phone)),
                        if (role == 'client') const SizedBox(height: 10),
                        TextField(controller: idCtrl, textDirection: ui.TextDirection.rtl, decoration: _inputDeco('رقم الهوية / السجل', Icons.badge)),
                        const SizedBox(height: 10),
                        TextField(controller: idFromCtrl, textDirection: ui.TextDirection.rtl, decoration: _inputDeco('جهة الإصدار', Icons.location_on)),
                        const SizedBox(height: 10),
                        TextField(controller: addressCtrl, textDirection: ui.TextDirection.rtl, decoration: _inputDeco('العنوان', Icons.home)),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
                    ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final p = {
                          'name': nameCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'id_number': idCtrl.text.trim(),
                          'id_issued_from': idFromCtrl.text.trim(),
                          'address': addressCtrl.text.trim(),
                          'entity_type': entityType,
                          'role': role,
                        };
                        setSheetState(() {
                          if (role == 'client') { clientParties.add(p); }
                          else { opponentParties.add(p); }
                        });
                        Navigator.pop(dCtx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E3B)),
                      child: const Text('إضافة', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          }

          Widget partyChip(Map<String, dynamic> p, String role, int idx) {
            final isOrg = p['entity_type'] == 'organization';
            return Chip(
              avatar: Icon(isOrg ? Icons.business : Icons.person, size: 18),
              label: Text(p['name'] ?? '', style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => setSheetState(() {
                if (role == 'client') clientParties.removeAt(idx);
                else opponentParties.removeAt(idx);
              }),
            );
          }

          return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Handle bar ──
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                // ── Title ──
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFD4A940).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.create_new_folder_rounded, color: Color(0xFFD4A940), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إنشاء ملف قضية جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('أدخل بيانات القضية الأساسية', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )),
                ]),
                const SizedBox(height: 24),

                // ── رقم القضية + سنة القضية (بجانب بعض) ──
                Row(children: [
                  Expanded(flex: 3, child: TextField(
                    controller: caseNumberController,
                    textDirection: ui.TextDirection.rtl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('رقم القضية', Icons.numbers_rounded),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: DropdownButtonFormField<int>(
                    value: selectedCaseYear,
                    decoration: _inputDeco('السنة', Icons.event_rounded),
                    isExpanded: true,
                    menuMaxHeight: 300,
                    items: List.generate(1447 - 1400 + 1, (i) => 1447 - i)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setSheetState(() => selectedCaseYear = v),
                  )),
                ]),
                const SizedBox(height: 14),

                // ── تاريخ الورود (ميلادي فقط) ──
                TextFormField(
                  readOnly: true,
                  decoration: _inputDeco('تاريخ الورود', Icons.calendar_today_rounded),
                  controller: TextEditingController(
                    text: filingDateGregorian != null ? DateFormat('yyyy-MM-dd').format(filingDateGregorian!) : '',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: filingDateGregorian ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setSheetState(() => filingDateGregorian = picked);
                  },
                ),
                const SizedBox(height: 14),

                // ── نوع القضية ──
                DropdownButtonFormField<String>(
                  value: selectedCaseType,
                  decoration: _inputDeco('نوع القضية', Icons.category_rounded),
                  items: LocalLookupService.caseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) {
                    setSheetState(() => selectedCaseType = v ?? 'مدنية');
                    loadSubtypes(v ?? 'مدنية');
                  },
                ),
                const SizedBox(height: 14),

                // ── النوع الفرعي ──
                if (subtypeOptions.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: selectedCaseSubtype,
                    decoration: _inputDeco('النوع الفرعي', Icons.list_alt_rounded),
                    items: subtypeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setSheetState(() => selectedCaseSubtype = v),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── المحافظة ──
                if (isLoadingGovernorates)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                else if (governorates.isEmpty)
                  SizedBox(height: 48, child: OutlinedButton.icon(
                    onPressed: loadGovernorates,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('تحميل المحافظات'),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ))
                else
                  DropdownButtonFormField<String>(
                    value: selectedGovernorateName,
                    decoration: _inputDeco('المحافظة', Icons.location_city_rounded),
                    items: governorates.where((g) => (g['name'] as String?)?.isNotEmpty ?? false)
                        .map((g) => DropdownMenuItem(value: g['name'] as String, child: Text(g['name'] as String))).toList(),
                    onChanged: (v) async {
                      setSheetState(() {
                        selectedGovernorateName = v;
                        final gov = governorates.firstWhere((g) => g['name'] == v, orElse: () => <String, dynamic>{});
                        selectedGovernorateId = gov['id'] as int?;
                        selectedCourtId = null;
                        courts = [];
                      });
                      if (selectedGovernorateId != null) await loadCourts(governorateId: selectedGovernorateId!);
                    },
                  ),
                const SizedBox(height: 14),

                // ── المحكمة ──
                isLoadingCourts
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                    : DropdownButtonFormField<int>(
                        value: selectedCourtId,
                        decoration: _inputDeco('المحكمة', Icons.gavel_rounded),
                        items: courts.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String))).toList(),
                        onChanged: (v) => setSheetState(() => selectedCourtId = v),
                      ),
                const SizedBox(height: 14),

                // ── الحالة الراهنة ──
                DropdownButtonFormField<String>(
                  value: selectedCaseStatus,
                  decoration: _inputDeco('الحالة الراهنة', Icons.flag_rounded),
                  items: _caseStatuses.map((s) => DropdownMenuItem(value: s['value'] as String, child: Text(s['label'] as String))).toList(),
                  onChanged: (v) => setSheetState(() => selectedCaseStatus = v ?? 'جديد'),
                ),
                const SizedBox(height: 14),

                // ── موضوع القضية ──
                TextField(
                  controller: subjectController,
                  textDirection: ui.TextDirection.rtl,
                  maxLines: 2,
                  decoration: _inputDeco('موضوع القضية *', Icons.subject_rounded),
                ),
                const SizedBox(height: 20),

                // ── أطراف القضية ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('أطراف القضية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),

                      // الطرف الأول – الموكل
                      Row(children: [
                        const Expanded(child: Text('الطرف الأول (الموكل)', style: TextStyle(fontSize: 13, color: Color(0xFF1B5E3B), fontWeight: FontWeight.w600))),
                        IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF1B5E3B), size: 22), onPressed: () => addParty('client')),
                      ]),
                      if (clientParties.isNotEmpty)
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          for (var i = 0; i < clientParties.length; i++) partyChip(clientParties[i], 'client', i),
                        ]),
                      if (clientParties.isEmpty)
                        Text('لم يتم إضافة موكل بعد', style: TextStyle(fontSize: 12, color: Colors.grey[500])),

                      const Divider(height: 20),

                      // الطرف الثاني – الخصم
                      Row(children: [
                        const Expanded(child: Text('الطرف الثاني (الخصم)', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600))),
                        IconButton(icon: const Icon(Icons.add_circle, color: Colors.red, size: 22), onPressed: () => addParty('opponent')),
                      ]),
                      if (opponentParties.isNotEmpty)
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          for (var i = 0; i < opponentParties.length; i++) partyChip(opponentParties[i], 'opponent', i),
                        ]),
                      if (opponentParties.isEmpty)
                        Text('لم يتم إضافة خصم بعد', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── زر الإنشاء ──
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isCreating ? null : () async {
                      final caseNumText = caseNumberController.text.trim();
                      if (caseNumText.isEmpty || int.tryParse(caseNumText) == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يرجى إدخال رقم القضية (رقم صحيح)'), backgroundColor: Colors.red));
                        return;
                      }
                      if (selectedCaseYear == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يرجى اختيار سنة القضية'), backgroundColor: Colors.red));
                        return;
                      }
                      if (subjectController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يرجى إدخال موضوع القضية'), backgroundColor: Colors.red));
                        return;
                      }
                      if (selectedCourtId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يرجى اختيار المحكمة'), backgroundColor: Colors.red));
                        return;
                      }
                      if (subtypeOptions.isNotEmpty && (selectedCaseSubtype == null || selectedCaseSubtype!.isEmpty)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('يرجى اختيار النوع الفرعي'), backgroundColor: Colors.red));
                        return;
                      }

                      setSheetState(() => isCreating = true);

                      try {
                        final apiService = Provider.of<ApiService>(ctx, listen: false);
                        final caseNumber = caseNumberController.text.trim();

                        final newCase = CaseModel(
                          caseNumber: caseNumber,
                          subject: subjectController.text.trim(),
                          filingDate: filingDateGregorian ?? DateTime.now(),
                          gregorianDate: filingDateGregorian,
                          caseYearHijri: selectedCaseYear,
                          caseStatus: selectedCaseStatus,
                          caseType: selectedCaseType,
                          caseSubtype: selectedCaseSubtype,
                          governorate: selectedGovernorateName,
                          courtId: selectedCourtId,
                        );

                        final created = await apiService.createCase(newCase);

                        // Create parties linked to this case
                        final allParties = [...clientParties, ...opponentParties];
                        final List<String> generatedPasswords = [];

                        for (final p in allParties) {
                          final party = CasePartyModel(
                            caseId: created.id!,
                            role: p['role'],
                            entityType: p['entity_type'] ?? 'person',
                            name: p['name'],
                            phone: p['phone'],
                            idNumber: p['id_number'],
                            idIssuedFrom: p['id_issued_from'],
                            address: p['address'],
                          );
                          final createdParty = await apiService.createCaseParty(party);
                          if (createdParty.generatedPassword != null && createdParty.generatedPassword!.isNotEmpty) {
                            generatedPasswords.add('${createdParty.name}: ${createdParty.phone} / ${createdParty.generatedPassword}');
                          }
                        }

                        if (mounted) {
                          Navigator.of(ctx).pop();
                          final provider = Provider.of<LawsuitProvider>(outerContext, listen: false);
                          provider.loadCases(refresh: true);

                          // Show generated passwords if any
                          if (generatedPasswords.isNotEmpty) {
                            showDialog(
                              context: outerContext,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('حسابات الموكلين', textAlign: TextAlign.right),
                                content: SingleChildScrollView(child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('تم إنشاء حسابات تلقائية للموكلين:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ...generatedPasswords.map((s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(s, textDirection: ui.TextDirection.rtl, style: const TextStyle(fontSize: 13)),
                                    )),
                                    const SizedBox(height: 8),
                                    Text('احفظ هذه البيانات - لن تظهر مرة أخرى', style: TextStyle(color: Colors.red[700], fontSize: 12)),
                                  ],
                                )),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(dCtx);
                                      navigator.push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: created.id!)));
                                    },
                                    child: const Text('حسناً'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            navigator.push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: created.id!)));
                          }
                        }
                      } catch (e) {
                        setSheetState(() => isCreating = false);
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    icon: isCreating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.folder_open_rounded),
                    label: Text(isCreating ? 'جارٍ الإنشاء...' : 'إنشاء ملف القضية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A940),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  void _confirmResetDatabase(LawsuitProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديث الأرشيف؟'),
        content: const Text('سيتم تحميل بيانات القضايا من السيرفر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.loadCases(refresh: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث البيانات بنجاح.'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('نعم، تحديث'),
          ),
        ],
      ),
    );
  }
}

/// Case Card for Archive - بطاقة ملف القضية في الأرشيف
class _CaseArchiveCard extends StatelessWidget {
  final CaseModel caseModel;
  final bool isGrid;

  const _CaseArchiveCard({required this.caseModel, this.isGrid = false});

  Color get _statusColor {
    switch (caseModel.caseStatus) {
      case 'جديد': return Colors.blue;
      case 'قيد_النظر': return Colors.orange;
      case 'مكتمل': return Colors.green;
      case 'مغلق': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: caseModel.id!)),
        ),
        onLongPress: () => _showCaseActionsSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: isGrid ? _buildGridContent() : _buildListContent(),
        ),
      ),
    );
  }

  void _showCaseActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, color: Color(0xFFD4A940)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'رقم: ${caseModel.caseNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                title: const Text('تعديل القضية', textAlign: TextAlign.right),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showEditCaseDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('حذف القضية', textAlign: TextAlign.right),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmAndDelete(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    if (caseModel.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل أنت متأكد من حذف القضية رقم ${caseModel.caseNumber}؟ لا يمكن التراجع عن هذا الإجراء.',
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
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    try {
      await provider.deleteCase(caseModel.id!);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم حذف القضية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذر حذف القضية: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditCaseDialog(BuildContext context) async {
    if (caseModel.id == null) return;
    final formKey = GlobalKey<FormState>();
    final caseNumberCtrl = TextEditingController(text: caseModel.caseNumber);
    final subjectCtrl = TextEditingController(text: caseModel.subject ?? '');
    String status = caseModel.caseStatus ?? 'جديد';
    DateTime? filingDate = caseModel.filingDate;

    const statuses = <String>['جديد', 'قيد_النظر', 'مكتمل', 'مغلق'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dCtx, setDState) => AlertDialog(
            title: const Text('تعديل القضية', textAlign: TextAlign.right),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: caseNumberCtrl,
                      textDirection: ui.TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'رقم القضية *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: subjectCtrl,
                      textDirection: ui.TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'الموضوع'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: statuses.contains(status) ? status : 'جديد',
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: statuses
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))))
                          .toList(),
                      onChanged: (v) => setDState(() => status = v ?? status),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        filingDate == null
                            ? 'تاريخ التقديم: غير محدد'
                            : 'تاريخ التقديم: ${DateFormat('yyyy-MM-dd').format(filingDate!)}',
                        textAlign: TextAlign.right,
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dCtx,
                          initialDate: filingDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDState(() => filingDate = picked);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(dCtx, true);
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    try {
      await provider.updateCaseFields(caseModel.id!, {
        'case_number': caseNumberCtrl.text.trim(),
        'subject': subjectCtrl.text.trim(),
        'case_status': status,
        if (filingDate != null)
          'filing_date': DateFormat('yyyy-MM-dd').format(filingDate!),
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم تحديث القضية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث القضية: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      caseNumberCtrl.dispose();
      subjectCtrl.dispose();
    }
  }

  Widget _buildListContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder icon
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFD4A940).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.folder_open_rounded, color: Color(0xFFD4A940), size: 26),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      caseModel.caseStatus ?? '',
                      style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  // Case number
                  Text(
                    'رقم: ${caseModel.caseNumber}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A2138)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Subject
              Text(
                caseModel.subject ?? 'بدون موضوع',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Footer: type + court + date
              Row(
                children: [
                  const Icon(Icons.chevron_right, color: Color(0xFFD4A940), size: 18),
                  const Spacer(),
                  if (caseModel.caseType != null)
                    _Tag(caseModel.caseType!),
                  if (caseModel.governorate != null) ...[
                    const SizedBox(width: 4),
                    _Tag(caseModel.governorate!),
                  ],
                  if (caseModel.filingDate != null) ...[
                    const SizedBox(width: 4),
                    _Tag('${caseModel.filingDate!.year}/${caseModel.filingDate!.month.toString().padLeft(2,'0')}/${caseModel.filingDate!.day.toString().padLeft(2,'0')}'),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(caseModel.caseStatus ?? '', style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            const Icon(Icons.folder_open_rounded, color: Color(0xFFD4A940), size: 22),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'رقم: ${caseModel.caseNumber}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A2138)),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Text(
            caseModel.subject ?? 'بدون موضوع',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        if (caseModel.caseType != null) _Tag(caseModel.caseType!),
      ],
    );
  }
}

/// Small tag chip
class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
    );
  }
}


/// Filter Bottom Sheet
class _FilterBottomSheet extends StatefulWidget {
  final String? selectedCaseType;
  final String? selectedCaseStatus;
  final String? selectedArchiveStatus;
  final String? selectedOrdering;
  final void Function(String?, String?, String?, String?) onApply;
  final VoidCallback onClear;

  const _FilterBottomSheet({
    this.selectedCaseType,
    this.selectedCaseStatus,
    this.selectedArchiveStatus,
    this.selectedOrdering,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  String? _caseType;
  String? _caseStatus;
  String? _ordering;

  static const _caseTypes = [
    {'value': 'مدنية', 'label': 'مدنية'},
    {'value': 'جزائية', 'label': 'جزائية'},
    {'value': 'شخصية', 'label': 'شخصية'},
    {'value': 'تجارية', 'label': 'تجارية'},
    {'value': 'إدارية', 'label': 'إدارية'},
    {'value': 'تنفيذ', 'label': 'تنفيذ'},
  ];

  static const _caseStatuses = [
    {'value': 'جديد', 'label': 'جديد'},
    {'value': 'قيد_النظر', 'label': 'قيد النظر'},
    {'value': 'مكتمل', 'label': 'مكتمل'},
    {'value': 'مغلق', 'label': 'مغلق'},
  ];

  static const _orderingOptions = [
    {'value': '-created_at', 'label': 'الأحدث أولاً'},
    {'value': 'created_at', 'label': 'الأقدم أولاً'},
    {'value': '-filing_date', 'label': 'تاريخ الرفع (الأحدث)'},
    {'value': 'filing_date', 'label': 'تاريخ الرفع (الأقدم)'},
    {'value': 'case_number', 'label': 'رقم الدعوى'},
    {'value': '-updated_at', 'label': 'آخر تحديث'},
  ];

  @override
  void initState() {
    super.initState();
    _caseType = widget.selectedCaseType;
    _caseStatus = widget.selectedCaseStatus;
    _ordering = widget.selectedOrdering;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onClear();
                  },
                  child: const Text('مسح الكل', style: TextStyle(color: Colors.red)),
                ),
                const Text(
                  'فلترة متقدمة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Filters - Scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDropdown(
                    label: 'نوع القضية',
                    value: _caseType,
                    items: _caseTypes.map((t) => DropdownMenuItem(
                      value: t['value'] as String,
                      child: Text(t['label'] as String),
                    )).toList(),
                    onChanged: (v) => setState(() => _caseType = v),
                  ),
                  const SizedBox(height: 14),
                  _buildDropdown(
                    label: 'حالة القضية',
                    value: _caseStatus,
                    items: _caseStatuses.map((s) => DropdownMenuItem(
                      value: s['value'] as String,
                      child: Text(s['label'] as String),
                    )).toList(),
                    onChanged: (v) => setState(() => _caseStatus = v),
                  ),
                  const SizedBox(height: 14),
                  _buildDropdown(
                    label: 'الترتيب',
                    value: _ordering,
                    items: _orderingOptions.map((o) => DropdownMenuItem(
                      value: o['value'] as String,
                      child: Text(o['label'] as String),
                    )).toList(),
                    onChanged: (v) => setState(() => _ordering = v),
                  ),
                ],
              ),
            ),
          ),
          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_caseType, _caseStatus, null, _ordering);
                  },
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text('تطبيق الفلترة', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A940),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      isExpanded: true,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Session Card Widget
// ═══════════════════════════════════════════════════════════════

class _SessionCard extends StatelessWidget {
  final HearingModel session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = session.isUpcoming;
    final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(session.hearingDate);
    final dayName = DateFormat('EEEE', 'ar').format(session.hearingDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)),
          ).then((_) {
            Provider.of<SessionProvider>(context, listen: false).loadSessions();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 52, height: 56,
                decoration: BoxDecoration(
                  gradient: isUpcoming
                      ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)])
                      : const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(session.hearingDate.day.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(DateFormat('MMM', 'ar').format(session.hearingDate),
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUpcoming ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            session.sessionTypeDisplay,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isUpcoming ? Colors.blue : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(session.typeDisplay,
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        const Spacer(),
                        Text(session.timeOfDayDisplay,
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('$dayName - $dateStr',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (session.hearingTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(session.hearingTime!,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ),
                    if (session.requirements.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(session.requirements,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                    if (session.courtDecision != null && session.courtDecision!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.balance, size: 12, color: AppColors.brandDark),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(session.courtDecision!,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.brandDark)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
