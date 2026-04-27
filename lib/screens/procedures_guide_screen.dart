import '../../../../theme/app_theme.dart';
import '../../../../theme/app_colors.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// ─────────────────────────────────────────────────────────────
///  دليل الإجراءات للأمين الشرعي
///  يقرأ من قاعدة بيانات legal.db المحلية
///  12 فصل  •  12,459 فقرة  •  بحث ذكي فوري
/// ─────────────────────────────────────────────────────────────
class ProceduresGuideScreen extends StatefulWidget {
  const ProceduresGuideScreen({Key? key}) : super(key: key);

  @override
  State<ProceduresGuideScreen> createState() => _ProceduresGuideScreenState();
}

class _ProceduresGuideScreenState extends State<ProceduresGuideScreen> {
  // ── ألوان ──
  static const _brand = Color(0xFF1B5E3B);
  static const _gold = Color(0xFFD4A940);

  // ── أيقونات وألوان الفصول ──
  static const _chapterMeta = <int, _ChMeta>{
    1: _ChMeta('مبادئ العلاقات القانونية', Icons.gavel_rounded, Color(0xFF1E3A8A)),
    2: _ChMeta('الخصومة الجنائية', Icons.shield_rounded, Color(0xFFDC2626)),
    3: _ChMeta('الجوانب الفنية في العقد', Icons.edit_document, Color(0xFF7C3AED)),
    4: _ChMeta('هيكل العقد / مكونات العقد', Icons.account_tree_rounded, Color(0xFF0891B2)),
    5: _ChMeta('بنود وعناصر العقد', Icons.list_alt_rounded, Color(0xFF059669)),
    6: _ChMeta('ملحق', Icons.attach_file_rounded, Color(0xFF6B7280)),
    7: _ChMeta('القواعد الإجرائية لعمل الموثق والأمين', Icons.menu_book_rounded, Color(0xFF92400E)),
    8: _ChMeta('القواعد الإجرائية العامة للتوثيق', Icons.rule_rounded, Color(0xFF1B5E3B)),
    9: _ChMeta('القواعد الإجرائية الخاصة (التصرفات العقارية)', Icons.home_work_rounded, Color(0xFFB45309)),
    10: _ChMeta('التعاميم الوزارية المتعلقة بالتوثيق', Icons.campaign_rounded, Color(0xFF7C2D12)),
    11: _ChMeta('قواعد حساب المواريث', Icons.family_restroom_rounded, Color(0xFF4338CA)),
    12: _ChMeta('قواعد الحساب والمساحة', Icons.calculate_rounded, Color(0xFF0369A1)),
  };

  Database? _db;
  bool _dbLoading = true;
  String? _dbError;

  // ── State ──
  List<_Chapter> _chapters = [];
  int? _selectedChapter; // null = show chapters list
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _query = '';
  Timer? _debounce;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    _db?.close();
    super.dispose();
  }

  // ──────────────────── DB ────────────────────

  Future<void> _initDb() async {
    try {
      final dbPath = p.join(await getDatabasesPath(), 'legal.db');

      // Copy asset to writable location (once)
      if (!File(dbPath).existsSync()) {
        final data = await rootBundle.load('legal.db');
        final bytes = data.buffer.asUint8List();
        await File(dbPath).writeAsBytes(bytes, flush: true);
      }

      _db = await openDatabase(dbPath, readOnly: true);
      await _loadChapters();
    } catch (e) {
      if (mounted) setState(() { _dbError = e.toString(); _dbLoading = false; });
    }
  }

  Future<void> _loadChapters() async {
    if (_db == null) return;
    final rows = await _db!.rawQuery('''
      SELECT p.id, p.text,
        (SELECT COUNT(*) FROM sentences WHERE paragraph_id = p.id) AS cnt
      FROM paragraphs p ORDER BY p.id
    ''');

    final chapters = <_Chapter>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final fullText = (r['text'] as String?) ?? '';
      final cnt = (r['cnt'] as int?) ?? 0;
      final meta = _chapterMeta[id];
      chapters.add(_Chapter(
        id: id,
        title: meta?.title ?? fullText.split('\n').first.trim(),
        icon: meta?.icon ?? Icons.article_rounded,
        color: meta?.color ?? _brand,
        sentenceCount: cnt,
      ));
    }

    if (mounted) setState(() { _chapters = chapters; _dbLoading = false; });
  }

  // ── Search ──

  Future<void> _search(String q) async {
    if (_db == null) return;
    _query = q.trim();
    if (_query.isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);

    try {
      // Use LIKE on sentences for smart search
      final results = await _db!.rawQuery('''
        SELECT s.id, s.paragraph_id, s.text,
          (SELECT GROUP_CONCAT(s2.text, ' ')
           FROM sentences s2
           WHERE s2.paragraph_id = s.paragraph_id
             AND s2.id BETWEEN MAX(1, s.id - 2) AND s.id + 2
          ) AS context_text
        FROM sentences s
        WHERE s.text LIKE ?
        ORDER BY s.paragraph_id, s.id
        LIMIT 100
      ''', ['%$_query%']);

      if (mounted) setState(() { _searchResults = results; _isSearching = false; });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  // ── Load chapter sentences ──

  Future<List<String>> _loadChapterSentences(int paragraphId) async {
    if (_db == null) return [];
    final rows = await _db!.rawQuery(
      'SELECT text FROM sentences WHERE paragraph_id = ? ORDER BY id', [paragraphId],
    );
    return rows.map((r) => (r['text'] as String?) ?? '').toList();
  }

  // ──────────────────── Build ────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (context.isDark ? AppColors.darkBackground : AppColors.lightBackground),
      body: _dbLoading
          ? _buildLoading()
          : _dbError != null
              ? _buildDbError()
              : CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    _buildAppBar(),
                    _buildSearchBar(),
                    if (_query.isNotEmpty)
                      _buildSearchResults()
                    else if (_selectedChapter != null)
                      _buildChapterContent()
                    else
                      _buildChaptersList(),
                  ],
                ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _brand),
          SizedBox(height: 16),
          Text('جاري تحميل الدليل...', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildDbError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            const Text('خطأ في تحميل قاعدة البيانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_dbError!, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () { setState(() { _dbLoading = true; _dbError = null; }); _initDb(); }, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }

  // ── SliverAppBar ──

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: _selectedChapter == null && _query.isEmpty ? 160 : 0,
      pinned: true,
      backgroundColor: _brand,
      foregroundColor: Colors.white,
      leading: _selectedChapter != null
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedChapter = null))
          : null,
      title: Text(
        _selectedChapter != null
            ? (_chapterMeta[_selectedChapter]?.title ?? 'فصل $_selectedChapter')
            : 'دليل الإجراءات',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      flexibleSpace: _selectedChapter == null && _query.isEmpty
          ? FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D3B23), Color(0xFF1B5E3B), Color(0xFF1E7A4D)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(top: -20, right: -20, child: _circle(80, Colors.white, 0.06)),
                    Positioned(bottom: -30, left: -30, child: _circle(100, _gold, 0.1)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('دليل الإجراءات للأمين الشرعي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${_chapters.length} فصل  •  ${_chapters.fold<int>(0, (s, c) => s + c.sentenceCount)} فقرة  •  بحث ذكي فوري',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _circle(double size, Color color, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: opacity)),
    );
  }

  // ── Search bar ──

  SliverToBoxAdapter _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: TextField(
          controller: _searchCtrl,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'بحث ذكي في الدليل...',
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
            prefixIcon: _isSearching
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _brand)))
                : const Icon(Icons.search_rounded, color: _brand),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () { _searchCtrl.clear(); setState(() { _query = ''; _searchResults = []; }); },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (q) { setState(() {}); _onSearchChanged(q); },
        ),
      ),
    );
  }

  // ── Chapters list ──

  SliverToBoxAdapter _buildChaptersList() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (final ch in _chapters) _chapterCard(ch),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _chapterCard(_Chapter ch) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _selectedChapter = ch.id);
            _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: ch.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(ch.icon, color: ch.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ch.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('${ch.sentenceCount} فقرة', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ch.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text('${ch.id}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ch.color)),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Chapter content ──

  SliverToBoxAdapter _buildChapterContent() {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<String>>(
        future: _loadChapterSentences(_selectedChapter!),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _brand)));
          }
          final sentences = snap.data ?? [];
          if (sentences.isEmpty) {
            return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('لا توجد بيانات')));
          }

          // Group sentences into readable paragraphs (every ~10 sentences)
          final fullText = sentences.join('\n');

          return Column(
            children: [
              // Copy button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Text('${sentences.length} فقرة', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fullText));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النص'), duration: Duration(seconds: 2)));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('نسخ الكل', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: _brand),
                    ),
                  ],
                ),
              ),
              // Content
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: SelectableText(
                  fullText,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 15, height: 2.0, color: Color(0xFF1A2138)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Search results ──

  SliverToBoxAdapter _buildSearchResults() {
    if (_isSearching) {
      return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _brand))));
    }
    if (_searchResults.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('لا توجد نتائج لـ "$_query"', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          )),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${_searchResults.length} نتيجة', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
            for (final r in _searchResults) _searchResultCard(r),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _searchResultCard(Map<String, dynamic> r) {
    final paraId = r['paragraph_id'] as int;
    final text = (r['text'] as String?) ?? '';
    final contextText = (r['context_text'] as String?) ?? text;
    final meta = _chapterMeta[paraId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _searchCtrl.clear();
            setState(() { _query = ''; _searchResults = []; _selectedChapter = paraId; });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: (meta?.color ?? _brand).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(meta?.icon ?? Icons.article, size: 16, color: meta?.color ?? _brand),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta?.title ?? 'فصل $paraId',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: meta?.color ?? _brand),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _highlightedText(contextText, _query),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _highlightedText(String text, String query) {
    if (query.isEmpty) return Text(text, style: const TextStyle(fontSize: 13, height: 1.7), maxLines: 4, overflow: TextOverflow.ellipsis);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: const TextStyle(backgroundColor: Color(0xFFFDE68A), fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
      ));
      start = idx + query.length;
    }

    return RichText(
      textDirection: TextDirection.rtl,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: const TextStyle(fontSize: 13, height: 1.7, color: Color(0xFF1A2138)), children: spans),
    );
  }
}

// ══════════ Models ══════════

class _Chapter {
  final int id;
  final String title;
  final IconData icon;
  final Color color;
  final int sentenceCount;
  const _Chapter({required this.id, required this.title, required this.icon, required this.color, required this.sentenceCount});
}

class _ChMeta {
  final String title;
  final IconData icon;
  final Color color;
  const _ChMeta(this.title, this.icon, this.color);
}
