import '../../../../theme/app_theme.dart';
import '../../../../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'webview_screen.dart';

/// ─────────────────────────────────────────────────────────
///  Electronic Services Screen - الخدمات الإلكترونية والروابط
///  – فتح مباشر داخل التطبيق (WebView) عند الضغط
///  – ضغط مطوّل → خيار فتح خارجي
/// ─────────────────────────────────────────────────────────
class ElectronicServicesScreen extends StatelessWidget {
  const ElectronicServicesScreen({super.key});

  // ══════════ Data ══════════

  static const _brandDark = Color(0xFF1B5E3B);
  static const _gold = Color(0xFFD4A940);

  static final List<_ServiceCategory> _categories = [
    _ServiceCategory(
      title: 'الخدمات الإلكترونية',
      subtitle: 'الأنظمة الحكومية الشرعية والقضائية',
      icon: Icons.miscellaneous_services_rounded,
      color: const Color(0xFF1B5E3B),
      items: const [
        _ServiceItem(title: 'البحث عن قضية', url: 'http://mojcitr.myftp.biz:8008/JUDDATALIST/CustomRetCaseMaster', icon: Icons.search_rounded, color: Color(0xFF0EA5E9)),
        _ServiceItem(title: 'خدمة الدعاوى الإلكترونية', url: 'https://judg.moj.gov.ye:8065/', icon: Icons.gavel_rounded, color: Color(0xFF8B5CF6)),
        _ServiceItem(title: 'البحث عن الأئمة الشرعيين', url: 'http://mojcitr.myftp.biz:8008/OMANALIST/CustomGetOmanaWithPic', icon: Icons.person_search_rounded, color: Color(0xFF14B8A6)),
        _ServiceItem(title: 'البحث عن المعاملات', url: 'http://mojcitr.myftp.biz:8008/InoutData/CustomInOutData', icon: Icons.description_rounded, color: Color(0xFFF59E0B)),
        _ServiceItem(title: 'بحث الجلسات اليومية', url: 'http://mojcitr.myftp.biz:8008/JudgmentData/CustomRetCourtSittingByDate', icon: Icons.calendar_today_rounded, color: Color(0xFFF43F5E)),
      ],
    ),
    _ServiceCategory(
      title: 'الجهات القضائية',
      subtitle: 'المواقع الرسمية للجهات ذات العلاقة',
      icon: Icons.account_balance_rounded,
      color: const Color(0xFF1E3A8A),
      items: const [
        _ServiceItem(title: 'مجلس القضاء الأعلى', url: 'http://www.sjc-yemen.com/', icon: Icons.account_balance_rounded, color: Color(0xFF1E3A8A)),
        _ServiceItem(title: 'النيابة العامة', url: 'https://agoye.gov.ye/', icon: Icons.shield_rounded, color: Color(0xFFDC2626)),
        _ServiceItem(title: 'المعهد العالي للقضاء', url: 'http://www.hji-yemen.com/', icon: Icons.school_rounded, color: Color(0xFF059669)),
        _ServiceItem(title: 'الجريدة الرسمية', url: 'https://moj.gov.ye/OfficialGazette', icon: Icons.newspaper_rounded, color: Color(0xFFCA8A04)),
      ],
    ),
    _ServiceCategory(
      title: 'وزارة العدل',
      subtitle: 'البوابة الرسمية والوثائق القانونية',
      icon: Icons.assured_workload_rounded,
      color: const Color(0xFF92400E),
      items: const [
        _ServiceItem(title: 'وزارة العدل', url: 'https://moj.gov.ye/', icon: Icons.assured_workload_rounded, color: Color(0xFF92400E)),
        _ServiceItem(title: 'تنزيل القوانين والتشريعات', url: 'https://moj.gov.ye/LawsM', icon: Icons.menu_book_rounded, color: Color(0xFF0369A1)),
      ],
    ),
  ];

  // ══════════ Actions ══════════

  void _openInApp(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebViewScreen(url: url, title: title)),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }

  void _showOptions(BuildContext context, String url, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(url, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded, color: _brandDark),
              title: const Text('فتح داخل التطبيق'),
              onTap: () { Navigator.pop(ctx); _openInApp(context, url, title); },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser_rounded, color: _gold),
              title: const Text('فتح في المتصفح الخارجي'),
              onTap: () { Navigator.pop(ctx); _openExternal(url); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════ Build ══════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (context.isDark ? AppColors.darkBackground : AppColors.lightBackground),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: _brandDark,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D3B23), Color(0xFF1B5E3B), Color(0xFF1E7A4D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(top: -30, right: -30, child: _circle(100, Colors.white, 0.06)),
                    Positioned(bottom: -40, left: -40, child: _circle(120, _gold, 0.1)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('الخدمات الإلكترونية', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('${_categories.fold<int>(0, (sum, c) => sum + c.items.length)} رابط • فتح مباشر داخل التطبيق', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Hint banner ──
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, size: 20, color: Color(0xFFB45309)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'اضغط لفتح داخل التطبيق  •  اضغط مطوّلاً لخيارات إضافية',
                    style: TextStyle(fontSize: 12, color: Colors.amber[900], height: 1.5),
                  )),
                ],
              ),
            ),
          ),

          // ── Categories ──
          ..._categories.expand((cat) => [
            SliverToBoxAdapter(child: _buildCategoryHeader(cat)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildServiceCard(context, cat.items[i]),
                  childCount: cat.items.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ]),

          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: opacity)),
    );
  }

  Widget _buildCategoryHeader(_ServiceCategory cat) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, size: 20, color: cat.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cat.color)),
                Text(cat.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text('${cat.items.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cat.color)),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, _ServiceItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openInApp(context, item.url, item.title),
          onLongPress: () => _showOptions(context, item.url, item.title),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        _shortenUrl(item.url),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  item.url.startsWith('https') ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 14,
                  color: item.url.startsWith('https') ? Colors.green[400] : Colors.orange[400],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortenUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host + (uri.path.length > 1 ? uri.path : '');
    } catch (_) {
      return url;
    }
  }
}

// ══════════ Helper models ══════════

class _ServiceCategory {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_ServiceItem> items;
  const _ServiceCategory({required this.title, required this.subtitle, required this.icon, required this.color, required this.items});
}

class _ServiceItem {
  final String title;
  final String url;
  final IconData icon;
  final Color color;
  const _ServiceItem({required this.title, required this.url, required this.icon, required this.color});
}
