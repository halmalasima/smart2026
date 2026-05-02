import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import '../services/api_service.dart';

/// Professional Document Scanner Screen
/// Supports:
/// - Multi-page scanning via camera or file picker
/// - Image filters (Original, B&W, Grayscale, Enhanced Contrast, Brighten, Darken)
/// - Save as Image (JPG) or PDF
/// - Preview before save
/// - OCR text extraction (via server API)
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<_ScannedPage> _pages = [];
  int _currentPage = 0;
  String _selectedFilter = 'original';
  bool _isProcessing = false;
  bool _isSaving = false;

  static const _filters = [
    {'key': 'original', 'label': 'أصلي', 'icon': Icons.image_rounded},
    {'key': 'bw', 'label': 'أبيض وأسود', 'icon': Icons.contrast},
    {'key': 'grayscale', 'label': 'رمادي', 'icon': Icons.gradient_rounded},
    {'key': 'enhanced', 'label': 'تحسين تباين', 'icon': Icons.auto_fix_high_rounded},
    {'key': 'brighten', 'label': 'تفتيح', 'icon': Icons.wb_sunny_rounded},
    {'key': 'darken', 'label': 'تعتيم', 'icon': Icons.nights_stay_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('الماسح الضوئي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          if (_pages.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.save_alt_rounded, color: Colors.white, size: 20),
              label: Text('حفظ (${_pages.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _isSaving ? null : _showSaveDialog,
            ),
        ],
      ),
      body: _pages.isEmpty ? _buildEmptyState() : _buildScannerView(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.document_scanner_rounded, color: Colors.deepPurple, size: 60),
          ),
          const SizedBox(height: 24),
          const Text(
            'ماسح ضوئي احترافي',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'التقط صور المستندات أو اختر من المعرض\nوأضف فلاتر احترافية ثم احفظ كصورة أو PDF',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!kIsWeb)
                _primaryBtn(Icons.camera_alt_rounded, 'التقاط صورة', Colors.deepPurple, _captureFromCamera),
              const SizedBox(width: 16),
              _primaryBtn(Icons.photo_library_rounded, 'من المعرض', const Color(0xFF2563EB), _pickFromGallery),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Scanner View ─────────────────────────────────────────────────────────
  Widget _buildScannerView() {
    final page = _pages[_currentPage];
    return Column(
      children: [
        // Page indicator
        if (_pages.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
                Text(
                  'صفحة ${_currentPage + 1} من ${_pages.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _currentPage < _pages.length - 1 ? () => setState(() => _currentPage++) : null,
                ),
                const SizedBox(width: 8),
                // Delete page
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'حذف الصفحة',
                  onPressed: () {
                    setState(() {
                      _pages.removeAt(_currentPage);
                      if (_currentPage >= _pages.length && _pages.isNotEmpty) {
                        _currentPage = _pages.length - 1;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        // Image preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                  : page.filteredBytes != null
                      ? Image.memory(page.filteredBytes!, fit: BoxFit.contain)
                      : Image.file(File(page.originalPath), fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Filters
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _filters.length,
            itemBuilder: (_, i) {
              final f = _filters[i];
              final isActive = _selectedFilter == f['key'];
              return GestureDetector(
                onTap: () => _applyFilter(f['key'] as String),
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.deepPurple : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: isActive ? Border.all(color: Colors.deepPurple.shade200, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(f['icon'] as IconData, color: isActive ? Colors.white : Colors.grey[400], size: 22),
                      const SizedBox(height: 4),
                      Text(
                        f['label'] as String,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[400],
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!kIsWeb)
            _bottomBtn(Icons.camera_alt_rounded, 'التقاط', Colors.deepPurple, _captureFromCamera),
          _bottomBtn(Icons.photo_library_rounded, 'المعرض', const Color(0xFF2563EB), _pickFromGallery),
          if (_pages.isNotEmpty) ...[
            _bottomBtn(Icons.rotate_right_rounded, 'تدوير', Colors.orange, _rotatePage),
            _bottomBtn(Icons.document_scanner_outlined, 'نص (OCR)', Colors.teal, _extractText),
          ],
        ],
      ),
    );
  }

  Widget _bottomBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  Future<void> _captureFromCamera() async {
    try {
      // Using advanced document scanner with edge detection
      final List<String>? images = await CunningDocumentScanner.getPictures();
      
      if (images != null && images.isNotEmpty) {
        setState(() {
          for (var path in images) {
            _pages.add(_ScannedPage(originalPath: path));
          }
          _currentPage = _pages.length - 1;
          _selectedFilter = 'original';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في الماسح الضوئي: $e', style: const TextStyle(fontFamily: 'Cairo')), 
            backgroundColor: Colors.redAccent
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      if (kIsWeb) {
        // On web, use file picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result != null) {
          for (final file in result.files) {
            if (file.path != null) {
              setState(() {
                _pages.add(_ScannedPage(originalPath: file.path!));
              });
            }
          }
          if (_pages.isNotEmpty) setState(() => _currentPage = _pages.length - 1);
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage(
          imageQuality: 95,
          maxWidth: 3000,
          maxHeight: 4000,
        );
        if (images.isNotEmpty) {
          setState(() {
            for (final img in images) {
              _pages.add(_ScannedPage(originalPath: img.path));
            }
            _currentPage = _pages.length - 1;
            _selectedFilter = 'original';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _applyFilter(String filterKey) async {
    if (_pages.isEmpty || _isProcessing) return;
    setState(() {
      _selectedFilter = filterKey;
      _isProcessing = true;
    });

    try {
      final page = _pages[_currentPage];
      if (filterKey == 'original') {
        setState(() {
          page.filteredBytes = null;
          page.activeFilter = 'original';
          _isProcessing = false;
        });
        return;
      }

      // Process in isolate-like way
      final bytes = await File(page.originalPath).readAsBytes();
      final processed = await _processImage(bytes, filterKey);

      if (mounted) {
        setState(() {
          page.filteredBytes = processed;
          page.activeFilter = filterKey;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في معالجة الصورة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Uint8List> _processImage(Uint8List bytes, String filter) async {
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('فشل في قراءة الصورة');

    img.Image processed;
    switch (filter) {
      case 'bw':
        processed = img.grayscale(original);
        // Apply threshold for B&W
        for (int y = 0; y < processed.height; y++) {
          for (int x = 0; x < processed.width; x++) {
            final pixel = processed.getPixel(x, y);
            final luminance = img.getLuminanceRgb(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
            final bw = luminance > 128 ? 255 : 0;
            processed.setPixelRgb(x, y, bw, bw, bw);
          }
        }
        break;
      case 'grayscale':
        processed = img.grayscale(original);
        break;
      case 'enhanced':
        processed = img.adjustColor(original, contrast: 1.5, saturation: 1.2);
        break;
      case 'brighten':
        processed = img.adjustColor(original, brightness: 1.3);
        break;
      case 'darken':
        processed = img.adjustColor(original, brightness: 0.7);
        break;
      default:
        processed = original;
    }

    return Uint8List.fromList(img.encodeJpg(processed, quality: 90));
  }

  void _rotatePage() {
    if (_pages.isEmpty) return;
    setState(() => _isProcessing = true);

    final page = _pages[_currentPage];
    final sourceBytes = page.filteredBytes ?? File(page.originalPath).readAsBytesSync();
    
    final original = img.decodeImage(sourceBytes);
    if (original == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final rotated = img.copyRotate(original, angle: 90);
    final encoded = Uint8List.fromList(img.encodeJpg(rotated, quality: 90));

    // Save rotated as new original
    final file = File(page.originalPath);
    file.writeAsBytesSync(encoded);

    setState(() {
      page.filteredBytes = page.activeFilter != 'original' ? encoded : null;
      _isProcessing = false;
    });
  }

  Future<void> _extractText() async {
    if (_pages.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final page = _pages[_currentPage];
      final bytes = page.filteredBytes ?? await File(page.originalPath).readAsBytes();
      
      final dir = await getTemporaryDirectory();
      final tempPath = '${dir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(tempPath).writeAsBytes(bytes);

      final api = Provider.of<ApiService>(context, listen: false);
      final text = await api.extractTextFromImage(tempPath);

      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showExtractedTextDialog(text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('خطأ في استخراج النص: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showExtractedTextDialog(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('النص المستخرج (OCR)', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: text.isEmpty
              ? const Text('لم يتم العثور على نص واضح.', style: TextStyle(color: Colors.grey))
              : SelectableText(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
        ),
        actions: [
          if (text.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy, color: Colors.blue, size: 18),
              label: const Text('نسخ', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النص')));
                Navigator.pop(ctx);
              },
            ),
          TextButton(
            child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ─── Save Dialog ──────────────────────────────────────────────────────────
  void _showSaveDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('حفظ المستند', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '${_pages.length} صفحة - اختر صيغة الحفظ',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _saveOptionBtn(ctx, Icons.image_rounded, 'صورة (JPG)', Colors.green, _saveAsImage),
                const SizedBox(width: 16),
                _saveOptionBtn(ctx, Icons.picture_as_pdf_rounded, 'مستند (PDF)', Colors.red, _saveAsPdf),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _saveOptionBtn(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(ctx);
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsImage() async {
    setState(() => _isSaving = true);
    try {
      // Save the first page (or current page) as image
      final page = _pages[_currentPage];
      final bytes = page.filteredBytes ?? await File(page.originalPath).readAsBytes();
      
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(filePath).writeAsBytes(bytes);

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الصورة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAsPdf() async {
    setState(() => _isSaving = true);
    try {
      final pdf = pw.Document();

      for (final page in _pages) {
        final bytes = page.filteredBytes ?? await File(page.originalPath).readAsBytes();
        final image = pw.MemoryImage(bytes);
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(8),
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

/// Internal model for a scanned page
class _ScannedPage {
  final String originalPath;
  Uint8List? filteredBytes;
  String activeFilter;

  _ScannedPage({
    required this.originalPath,
    this.filteredBytes,
    this.activeFilter = 'original',
  });
}
