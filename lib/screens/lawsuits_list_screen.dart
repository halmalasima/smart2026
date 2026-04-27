import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/lawsuit_provider.dart';
import '../models/lawsuit_model.dart';
import '../theme/app_colors.dart';
import 'lawsuit_detail_screen.dart';

class LawsuitsListScreen extends StatefulWidget {
  const LawsuitsListScreen({super.key});

  @override
  State<LawsuitsListScreen> createState() => _LawsuitsListScreenState();
}

class _LawsuitsListScreenState extends State<LawsuitsListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LawsuitProvider>(context, listen: false).loadLawsuits(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final provider = Provider.of<LawsuitProvider>(context, listen: false);
      if (provider.hasMore && !provider.isLoading) {
        provider.loadLawsuits();
      }
    }
  }

  void _onSearch() {
    final provider = Provider.of<LawsuitProvider>(context, listen: false);
    provider.setSearchQuery(_searchController.text);
    provider.loadLawsuits(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Premium SliverAppBar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.brand,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'إدارة الدعاوى الإلكترونية',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Cairo',
                ),
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [AppColors.brand, Color(0xFF1E5F3B)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.folder_copy_rounded,
                      size: 150,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => Provider.of<LawsuitProvider>(context, listen: false).loadLawsuits(refresh: true),
              ),
            ],
          ),

          // Search and Filter Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'البحث برقم الدعوى أو الموضوع...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.brand),
                        suffixIcon: _searchController.text.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18), 
                              onPressed: () {
                                _searchController.clear();
                                _onSearch();
                              }
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', null),
                        const SizedBox(width: 8),
                        _buildFilterChip('جديد', 'new'),
                        const SizedBox(width: 8),
                        _buildFilterChip('قيد النظر', 'pending'),
                        const SizedBox(width: 8),
                        _buildFilterChip('مكتمل', 'completed'),
                        const SizedBox(width: 8),
                        _buildFilterChip('مغلق', 'closed'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lawsuits List
          Consumer<LawsuitProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.lawsuits.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (provider.errorMessage != null && provider.lawsuits.isEmpty) {
                return SliverFillRemaining(
                  child: _buildErrorState(provider),
                );
              }

              if (provider.lawsuits.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == provider.lawsuits.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final lawsuit = provider.lawsuits[index];
                      return _LawsuitCard(lawsuit: lawsuit, index: index);
                    },
                    childCount: provider.lawsuits.length + (provider.isLoading ? 1 : 0),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LawsuitDetailScreen()),
          ).then((_) {
            Provider.of<LawsuitProvider>(context, listen: false).loadLawsuits(refresh: true);
          });
        },
        backgroundColor: AppColors.brand,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('دعوى جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 400.ms),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        final provider = Provider.of<LawsuitProvider>(context, listen: false);
        setState(() => _selectedStatus = val ? status : null);
        provider.setCaseStatusFilter(val ? status : null);
        provider.loadLawsuits(refresh: true);
      },
      selectedColor: AppColors.brand.withOpacity(0.2),
      checkmarkColor: AppColors.brand,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد دعاوى إلكترونية',
            style: TextStyle(color: Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('ابدأ بإضافة أول دعوى لك الآن'),
        ],
      ),
    );
  }

  Widget _buildErrorState(LawsuitProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(provider.errorMessage ?? 'حدث خطأ غير متوقع'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadLawsuits(refresh: true),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _LawsuitCard extends StatelessWidget {
  final LawsuitModel lawsuit;
  final int index;

  const _LawsuitCard({required this.lawsuit, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LawsuitDetailScreen(lawsuitId: lawsuit.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatusChip(status: lawsuit.caseStatus ?? lawsuit.status),
                  Expanded(
                    child: Text(
                      lawsuit.caseNumber,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1, thickness: 0.5),
              ),
              Row(
                children: [
                  _buildIconInfo(Icons.category_outlined, lawsuit.caseTypeDisplay, Colors.blue),
                  const Spacer(),
                  _buildIconInfo(Icons.calendar_today_outlined, 
                    lawsuit.filingDate != null ? DateFormat('yyyy-MM-dd').format(lawsuit.filingDate!) : '-', 
                    Colors.orange),
                ],
              ),
              const SizedBox(height: 10),
              if (lawsuit.courtName != null)
                _buildIconInfo(Icons.gavel_outlined, lawsuit.courtName!, AppColors.brand),
              if (lawsuit.description != null && lawsuit.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lawsuit.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                  textAlign: TextAlign.right,
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
  }

  Widget _buildIconInfo(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 16, color: color),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String? status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusMap = {
      'new': ('جديد', Colors.blue),
      'جديد': ('جديد', Colors.blue),
      'pending': ('قيد النظر', Colors.orange),
      'قيد_النظر': ('قيد النظر', Colors.orange),
      'completed': ('مكتمل', Colors.green),
      'مكتمل': ('مكتمل', Colors.green),
      'closed': ('مغلق', Colors.grey),
      'مغلق': ('مغلق', Colors.grey),
    };

    final data = statusMap[status] ?? (status ?? 'غير معروف', Colors.grey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: data.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.$2.withOpacity(0.3)),
      ),
      child: Text(
        data.$1,
        style: TextStyle(color: data.$2, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

