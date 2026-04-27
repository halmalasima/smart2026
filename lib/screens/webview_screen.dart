import '../../../../theme/app_theme.dart';
import '../../../../theme/app_colors.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// WebView Screen – يدعم http و https مع تخزين مؤقت وتحسينات للمواقع الحكومية
class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;
  String _currentUrl = '';
  String _pageTitle = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  Timer? _timeoutTimer;

  // ── ألوان ──
  static const _brandDark = Color(0xFF1B5E3B);
  static const _gold = Color(0xFFD4A940);

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _pageTitle = widget.title;
    _initWebView();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ──────────────────── Init ────────────────────
  void _initWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params);

    const userAgent =
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(userAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p / 100;
            if (p >= 80) _isLoading = false;
          });
        },
        onPageStarted: (url) {
          developer.log('▶ $url', name: 'WV');
          _resetTimeout();
          if (!mounted) return;
          setState(() {
            _isLoading = true;
            _errorMessage = null;
            _currentUrl = url;
          });
        },
        onPageFinished: (url) {
          developer.log('✔ $url', name: 'WV');
          _timeoutTimer?.cancel();
          if (!mounted) return;
          setState(() => _isLoading = false);
          _updateNavState();
          _controller.getTitle().then((t) {
            if (t != null && t.isNotEmpty && mounted) {
              setState(() => _pageTitle = t);
            }
          });
        },
        onWebResourceError: (err) {
          developer.log('✖ ${err.errorCode}: ${err.description}', name: 'WV');
          // ignore non-fatal sub-resource errors
          if (err.errorCode == -999 || err.errorCode == -1 || err.errorCode == -2) return;
          if (err.isForMainFrame != true) return;
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage =
                'تعذر تحميل الصفحة (${err.errorCode})\n'
                'تحقق من الاتصال بالإنترنت أو حاول مرة أخرى.';
          });
        },
        onHttpError: (resp) {
          developer.log('HTTP ${resp.response?.statusCode}', name: 'WV');
        },
        onNavigationRequest: (req) {
          final url = req.url;
          if (url.startsWith('http://') || url.startsWith('https://')) {
            return NavigationDecision.navigate;
          }
          // non-http schemes → open externally (tel:, mailto:, intent:, etc.)
          _openExternally(url);
          return NavigationDecision.prevent;
        },
      ));

    // ── Android specifics: caching + SSL ──
    if (_controller.platform is AndroidWebViewController) {
      final android = _controller.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);

      // Allow mixed content (http resources on https pages)
      AndroidWebViewController.enableDebugging(false);

      // Cookies
      final cookieMgr = WebViewCookieManager();
      try {
        final host = Uri.parse(widget.url).host;
        if (host.isNotEmpty) {
          cookieMgr.setCookie(
            WebViewCookie(name: 'app', value: '1', domain: host),
          );
        }
      } catch (_) {}
    }

    _loadUrl();
  }

  void _resetTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'الموقع لم يستجب خلال المهلة المحددة.\nقد يكون الخادم متوقفاً حالياً.';
        });
      }
    });
  }

  Future<void> _updateNavState() async {
    if (!mounted) return;
    final back = await _controller.canGoBack();
    final fwd = await _controller.canGoForward();
    setState(() {
      _canGoBack = back;
      _canGoForward = fwd;
    });
  }

  void _loadUrl() {
    try {
      final uri = Uri.parse(widget.url);
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _resetTimeout();
      _controller.loadRequest(uri);
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'الرابط غير صالح';
      });
    }
  }

  // ──────────────────── UI ────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? AppColors.darkSurface : AppColors.lightSurface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pageTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _currentUrl,
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'إعادة تحميل',
            onPressed: () {
              _resetTimeout();
              setState(() { _isLoading = true; _errorMessage = null; });
              _controller.reload();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            onSelected: (v) {
              switch (v) {
                case 'external':
                  _openExternally(_currentUrl);
                  break;
                case 'share':
                  Share.share(_currentUrl);
                  break;
                case 'copy':
                  _copyUrl();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'external', child: Row(children: [
                Icon(Icons.open_in_browser, size: 20, color: Colors.black54),
                SizedBox(width: 10),
                Text('فتح في المتصفح', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'share', child: Row(children: [
                Icon(Icons.share_rounded, size: 20, color: Colors.black54),
                SizedBox(width: 10),
                Text('مشاركة الرابط', style: TextStyle(fontSize: 13)),
              ])),
              PopupMenuItem(value: 'copy', child: Row(children: [
                Icon(Icons.copy_rounded, size: 20, color: Colors.black54),
                SizedBox(width: 10),
                Text('نسخ الرابط', style: TextStyle(fontSize: 13)),
              ])),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: AnimatedOpacity(
            opacity: _isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(_gold),
              minHeight: 3,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_errorMessage != null) _buildError(),
                if (_isLoading && _progress < 0.05) _buildSplash(),
              ],
            ),
          ),
          // bottom nav bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          _navBtn(Icons.arrow_back_ios_rounded, _canGoBack, () => _controller.goBack()),
          _navBtn(Icons.arrow_forward_ios_rounded, _canGoForward, () => _controller.goForward()),
          const Spacer(),
          _navBtn(Icons.home_rounded, true, () {
            _controller.loadRequest(Uri.parse(widget.url));
            _resetTimeout();
          }),
          _navBtn(Icons.open_in_browser_rounded, true, () => _openExternally(_currentUrl)),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 52,
          height: 48,
          child: Icon(icon, size: 20, color: enabled ? _brandDark : Colors.grey[300]),
        ),
      ),
    );
  }

  Widget _buildSplash() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(strokeWidth: 3, color: _brandDark),
            ),
            const SizedBox(height: 20),
            const Text('جاري الاتصال...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _currentUrl,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _errorMessage = null);
                    _loadUrl();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة المحاولة', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandDark,
                    side: const BorderSide(color: _brandDark),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _openExternally(_currentUrl),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('فتح خارجياً', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Helpers ────────────────────
  Future<void> _openExternally(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح المتصفح الخارجي')),
        );
      }
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _currentUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ الرابط'), duration: Duration(seconds: 2)),
      );
    }
  }
}
