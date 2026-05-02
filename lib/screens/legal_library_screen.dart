import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'dart:developer' as developer;

class LegalLibraryScreen extends StatefulWidget {
  const LegalLibraryScreen({super.key});

  @override
  State<LegalLibraryScreen> createState() => _LegalLibraryScreenState();
}

class _LegalLibraryScreenState extends State<LegalLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ApiService _apiService;
  
  // State for Law Books (PDFs)
  List<Map<String, dynamic>> _lawBooks = [];
  List<String> _bookCategories = [];
  String? _selectedBookCategory;
  bool _isLoadingBooks = false;
  
  // State for Articles (Searchable)
  List<Map<String, dynamic>> _articles = [];
  List<Map<String, dynamic>> _sources = [];
  String? _selectedSource;
  bool _isLoadingArticles = false;
  
  final TextEditingController _searchController = TextEditingController();
  int _articlePage = 1;
  bool _hasMoreArticles = true;
  int _totalArticles = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiService = Provider.of<AuthProvider>(context, listen: false).apiService;
      _initialLoad();
    });
  }

  void _initialLoad() {
    _loadBooks();
    _loadBookCategories();
    _loadSources();
    _searchArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Law Books Logic ---
  Future<void> _loadBooks() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBooks = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.getLawBooks(
        searchQuery: _tabController.index == 0 ? _searchController.text : null,
        category: _selectedBookCategory,
      );
      final data = response['data'] ?? response;
      final results = data['results'] as List? ?? [];
      if (mounted) {
        setState(() {
          _lawBooks = List<Map<String, dynamic>>.from(results);
          if (_lawBooks.isEmpty) {
            _errorMessage = 'لا توجد مراجع قانونية متاحة حالياً';
          }
        });
      }
    } catch (e) {
      developer.log('Error loading law books: $e');
      if (mounted) {
        setState(() => _errorMessage = 'تعذر الاتصال بالخادم. يرجى التحقق من الاتصال.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingBooks = false);
    }
  }

  Future<void> _loadBookCategories() async {
    try {
      final response = await _apiService.getLawBookCategories();
      final cats = response['categories'] as List? ?? [];
      if (mounted) {
        setState(() {
          _bookCategories = cats.map((c) => c['category'].toString()).toList();
        });
      }
    } catch (e) {
      developer.log('Error loading categories: $e');
    }
  }

  // --- Articles Logic ---
  Future<void> _loadSources() async {
    try {
      final response = await _apiService.getLegalLibrarySources();
      final data = response['data'] ?? response;
      if (data['sources'] != null && mounted) {
        setState(() {
          _sources = List<Map<String, dynamic>>.from(data['sources']);
        });
      }
    } catch (e) {
      developer.log('Error loading sources: $e');
    }
  }

  Future<void> _searchArticles({bool loadMore = false}) async {
    if (_isLoadingArticles) return;
    if (mounted) setState(() => _isLoadingArticles = true);
    try {
      final response = await _apiService.getLegalLibrary(
        searchQuery: _tabController.index == 1 ? _searchController.text : null,
        source: _selectedSource,
        page: loadMore ? _articlePage + 1 : 1,
      );
      final data = response['data'] ?? response;
      final results = data['results'] as List? ?? [];
      final count = data['count'] as int? ?? 0;
      
      if (mounted) {
        setState(() {
          if (loadMore) {
            _articles.addAll(List<Map<String, dynamic>>.from(results));
            _articlePage++;
          } else {
            _articles = List<Map<String, dynamic>>.from(results);
            _articlePage = 1;
          }
          _totalArticles = count;
          _hasMoreArticles = _articles.length < _totalArticles;
        });
      }
    } catch (e) {
      developer.log('Error searching articles: $e');
    } finally {
      if (mounted) setState(() => _isLoadingArticles = false);
    }
  }

  void _onSearch() {
    if (_tabController.index == 0) {
      _loadBooks();
    } else {
      _searchArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F7F6),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              _buildSliverAppBar(isDark),
              _buildPersistentHeader(isDark),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildBooksTab(isDark),
              _buildArticlesTab(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.brand,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          'المكتبة القانونية الذكية',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Cairo',
          ),
        ),
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
              right: -30,
              top: -30,
              child: Icon(
                Icons.account_balance_outlined,
                size: 180,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 48, color: Colors.white)
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scale(delay: 200.ms),
                    const SizedBox(height: 8),
                    Text(
                      'أكبر مرجع للتشريعات والقوانين اليمنية',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentHeader(bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverHeaderDelegate(
        child: Container(
          color: isDark ? AppColors.darkBackground : const Color(0xFFF4F7F6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Bar
              SizedBox(
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: _tabController.index == 0 ? 'ابحث في الكتب والتشريعات...' : 'ابحث في نصوص المواد والمواد...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.brand),
                    suffixIcon: _searchController.text.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                          _searchController.clear();
                          _onSearch();
                        })
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              ),
              const SizedBox(height: 12),
              // Tab Switcher
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: AppColors.brand.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'التشريعات والكتب'),
                    Tab(text: 'البحث في المواد'),
                  ],
                ),
              ),
            ],
          ),
        ),
        minHeight: 128,
        maxHeight: 128,
      ),
    );
  }

  Widget _buildBooksTab(bool isDark) {
    return Column(
      children: [
        _buildCategoryChips(isDark),
        Expanded(
          child: _isLoadingBooks && _lawBooks.isEmpty
            ? _buildLoadingState()
            : _errorMessage != null && _lawBooks.isEmpty
              ? _buildErrorState()
              : _lawBooks.isEmpty
                ? _buildEmptyState('لم يتم العثور على تشريعات', Icons.search_off)
                : RefreshIndicator(
                    onRefresh: _loadBooks,
                    color: AppColors.brand,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _lawBooks.length,
                      itemBuilder: (context, index) => _buildBookCard(_lawBooks[index], index, isDark),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        reverse: true,
        itemCount: _bookCategories.length + 1,
        itemBuilder: (context, index) {
          final cat = index == 0 ? null : _bookCategories[index - 1];
          final isSelected = _selectedBookCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(cat ?? 'الكل', style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedBookCategory = val ? cat : null);
                _loadBooks();
              },
              selectedColor: AppColors.brand.withOpacity(0.15),
              labelStyle: TextStyle(color: isSelected ? AppColors.brand : (isDark ? Colors.white70 : Colors.black54)),
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppColors.brand : Colors.transparent)),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, int index, bool isDark) {
    final category = book['category'] ?? 'عام';
    final color = _getCategoryColor(category);
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBookDetails(book),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Area
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.7)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(Icons.menu_book, size: 80, color: Colors.white.withOpacity(0.15)),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.gavel_rounded, color: Colors.white, size: 32),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Details Area
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] ?? 'عنوان غير متوفر',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1.3),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 16),
                        Text(
                          'تصفح الآن',
                          style: TextStyle(color: AppColors.brand, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index % 6 * 100).ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildArticlesTab(bool isDark) {
    return Column(
      children: [
        _buildArticleFilter(isDark),
        Expanded(
          child: _isLoadingArticles && _articles.isEmpty
            ? _buildLoadingState()
            : _articles.isEmpty
              ? _buildEmptyState('لا توجد مواد تطابق بحثك', Icons.manage_search)
              : RefreshIndicator(
                  onRefresh: _searchArticles,
                  color: AppColors.brand,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _articles.length + (_hasMoreArticles ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _articles.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2),
                          ),
                        );
                      }
                      return _buildArticleCard(_articles[index], index, isDark);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildArticleFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedSource,
            hint: const Text('تصفية حسب القانون/المرجع', style: TextStyle(fontSize: 13)),
            isExpanded: true,
            icon: const Icon(Icons.filter_list_rounded, color: AppColors.brand),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المراجع القانونية')),
              ..._sources.map((s) => DropdownMenuItem(
                value: s['source_title'].toString(),
                child: Text(s['source_title'].toString(), style: const TextStyle(fontSize: 13)),
              )),
            ],
            onChanged: (val) {
              setState(() => _selectedSource = val);
              _searchArticles();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article, int index, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'مادة ${article['article_number'] ?? '0'}',
                style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                article['source_title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            article['article_text_preview'] ?? article['article_text'] ?? 'لا يوجد نص متاح',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.5),
            textAlign: TextAlign.right,
          ),
        ),
        onTap: () => _showArticleDetails(article),
      ),
    ).animate().fadeIn(delay: (index % 10 * 80).ms).slideX(begin: 0.1);
  }

  void _showBookDetails(Map<String, dynamic> book) {
    final category = book['category'] ?? 'عام';
    final color = _getCategoryColor(category);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'] ?? '',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(category, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 80,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 40),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoTile(Icons.info_outline, 'معلومات إضافية', book['description'] ?? 'لا يوجد وصف متاح لهذا المرجع.'),
            _buildInfoTile(Icons.history, 'تاريخ الإصدار', book['issue_year']?.toString() ?? 'غير محدد'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final url = book['pdf_url'];
                      if (url != null && url.toString().isNotEmpty) {
                        _launchURL(url);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('عفواً، رابط تحميل المرجع غير متوفر حالياً.', style: TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: Colors.redAccent,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                    label: const Text('تحميل المرجع (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showArticleDetails(Map<String, dynamic> article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  const Text('تفاصيل المادة القانونية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 48),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.brand.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Text('مادة رقم ${article['article_number']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.brand)),
                          const SizedBox(height: 8),
                          Text(article['source_title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('نص المادة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    SelectableText(
                      article['article_text'] ?? 'النص غير متوفر',
                      style: const TextStyle(fontSize: 16, height: 1.8, fontFamily: 'Cairo'),
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 30),
                    if (article['book_title'] != null && article['book_title'].isNotEmpty)
                      _buildDetailRow('الكتاب', article['book_title']),
                    if (article['chapter_title'] != null && article['chapter_title'].isNotEmpty)
                      _buildDetailRow('الباب/الفصل', article['chapter_title']),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    if (category.contains('مدني')) return Colors.blue[700]!;
    if (category.contains('جزائي') || category.contains('عقوبات')) return Colors.red[700]!;
    if (category.contains('تجاري')) return Colors.amber[800]!;
    if (category.contains('أسرة') || category.contains('شخصي')) return Colors.purple[700]!;
    if (category.contains('عمل') || category.contains('عمال')) return Colors.orange[700]!;
    return AppColors.brand;
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    try {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      developer.log('Could not launch URL: $e');
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'حدث خطأ غير متوقع',
            style: const TextStyle(fontSize: 16, fontFamily: 'Cairo'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initialLoad,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: AppColors.brand));
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('حاول تغيير كلمات البحث أو الفلاتر'),
        ],
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _SliverHeaderDelegate({required this.child, required this.minHeight, required this.maxHeight});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(_SliverHeaderDelegate oldDelegate) => 
    child != oldDelegate.child || minHeight != oldDelegate.minHeight || maxHeight != oldDelegate.maxHeight;
}
