import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lawyer_provider.dart';
import '../models/lawyer_model.dart';
import 'lawyer_details_screen.dart';
import 'dart:async';
import '../theme/app_colors.dart';

class LawyersSearchScreen extends StatefulWidget {
  const LawyersSearchScreen({super.key});

  @override
  State<LawyersSearchScreen> createState() => _LawyersSearchScreenState();
}

class _LawyersSearchScreenState extends State<LawyersSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedBranch;
  String? _selectedGrade;
  Timer? _debounce;

  final List<int> _pageSizes = [10, 20, 30, 40, 50];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LawyerProvider>(context, listen: false);
      provider.loadFilterOptions();
      provider.loadLawyers(refresh: true);
    });
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final provider = Provider.of<LawyerProvider>(context, listen: false);
      if (provider.hasMore && !provider.isLoading) {
        provider.loadLawyers();
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _performSearch() {
    final provider = Provider.of<LawyerProvider>(context, listen: false);
    provider.setSearchQuery(_searchController.text);
    provider.setBranchFilter(_selectedBranch);
    provider.setGradeFilter(_selectedGrade);
    provider.loadLawyers(refresh: true);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedBranch = null;
      _selectedGrade = null;
    });
    Provider.of<LawyerProvider>(context, listen: false).clearFilters();
    Provider.of<LawyerProvider>(context, listen: false).loadLawyers(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text('المحامين المعتمدين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLawyerInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterHeader(isDark),
          Expanded(
            child: Consumer<LawyerProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.lawyers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && provider.lawyers.isEmpty) {
                  return _buildErrorState(provider);
                }

                if (provider.lawyers.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadLawyers(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: provider.lawyers.length + (provider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.lawyers.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final lawyer = provider.lawyers[index];
                      return _LawyerCard(lawyer: lawyer, isDark: isDark);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchBar(isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: _selectedBranch ?? 'كل الفروع',
                        isSelected: _selectedBranch != null,
                        onDeleted: _selectedBranch != null ? () {
                          setState(() => _selectedBranch = null);
                          _performSearch();
                        } : null,
                        icon: Icons.business,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: _selectedGrade ?? 'كل الدرجات',
                        isSelected: _selectedGrade != null,
                        onDeleted: _selectedGrade != null ? () {
                          setState(() => _selectedGrade = null);
                          _performSearch();
                        } : null,
                        icon: Icons.workspace_premium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    VoidCallback? onDeleted,
    required IconData icon,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _openFilterSheet(),
      onDeleted: onDeleted,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.brand),
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.brand,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.brand : Colors.grey.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildFilterButton(bool isDark) {
    return InkWell(
      onTap: _openFilterSheet,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.tune_rounded, color: AppColors.brand, size: 24),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'ابحث بالاسم أو رقم القيد...',
        prefixIcon: Icon(Icons.search, color: AppColors.brand),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _performSearch();
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildPageSizeSelector() {
    return Consumer<LawyerProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'عدد النتائج: ${provider.totalCount}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  Text(
                    'حجم الصفحة:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: provider.pageSize,
                    underline: const SizedBox.shrink(),
                    items: _pageSizes.map((size) {
                      return DropdownMenuItem(
                        value: size,
                        child: Text(size.toString()),
                      );
                    }).toList(),
                    onChanged: (size) {
                      if (size != null) {
                        provider.setPageSize(size);
                        provider.loadLawyers(refresh: true);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFilterSheet() {
    final provider = Provider.of<LawyerProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'تصفية النتائج',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildFilterLabel('الفرع (المحافظة)'),
                const SizedBox(height: 8),
                _buildFilterDropdown(
                  value: _selectedBranch,
                  items: provider.availableBranches,
                  onChanged: (val) => setSheetState(() => _selectedBranch = val),
                  icon: Icons.business,
                ),
                const SizedBox(height: 20),
                _buildFilterLabel('الدرجة القضائية'),
                const SizedBox(height: 8),
                _buildFilterDropdown(
                  value: _selectedGrade,
                  items: provider.availableGrades,
                  onChanged: (val) => setSheetState(() => _selectedGrade = val),
                  icon: Icons.workspace_premium,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _selectedBranch = null;
                            _selectedGrade = null;
                          });
                          Navigator.pop(context);
                          _performSearch();
                        },
                        child: const Text('مسح الكل'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _performSearch();
                        },
                        child: const Text('تطبيق الفلاتر', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildFilterLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  Widget _buildFilterDropdown({
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: const Text('اختر خياراً'),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('الكل')),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildErrorState(LawyerProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
          const SizedBox(height: 24),
          Text(provider.errorMessage ?? 'فشل الاتصال بالسيرفر'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadLawyers(refresh: true),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 100, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text(
            'لم يتم العثور على محامين',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('حاول تغيير معايير البحث أو الفلاتر', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showLawyerInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دليل المحامين'),
        content: const Text('هذا الدليل يحتوي على قائمة المحامين المعتمدين والمقيدين لدى نقابة المحامين اليمنيين.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً')),
        ],
      ),
    );
  }

  Widget _buildPaginationInfo(LawyerProvider provider) {
    final start = (provider.lawyers.length > 0) ? 1 : 0;
    final end = provider.lawyers.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'عرض $start - $end من ${provider.totalCount}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (!provider.hasMore && provider.lawyers.isNotEmpty)
            const Text(
              'نهاية النتائج',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _LawyerCard extends StatelessWidget {
  final LawyerModel lawyer;
  final bool isDark;

  const _LawyerCard({required this.lawyer, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LawyerDetailsScreen(lawyer: lawyer),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: AppColors.brand, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lawyer.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          lawyer.gradeDisplay,
                          style: TextStyle(fontSize: 13, color: AppColors.brand, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildInfoRow(Icons.badge_outlined, 'رقم القيد:', lawyer.registrationNumber),
              const SizedBox(height: 10),
              if (lawyer.branch != null)
                _buildInfoRow(Icons.business_outlined, 'الفرع:', lawyer.branch!),
              const SizedBox(height: 10),
              if (lawyer.phone != null)
                _buildInfoRow(Icons.phone_android_outlined, 'الهاتف:', lawyer.phone!, isAction: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isAction = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isAction ? FontWeight.bold : FontWeight.normal,
              color: isAction ? AppColors.brand : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}
