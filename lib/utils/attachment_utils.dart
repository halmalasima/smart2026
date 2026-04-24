import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';

class AttachmentUtils {
  static bool isImageFile(String? filename) {
    final ext = (filename ?? '').split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  static IconData fileIcon(String? filename) {
    final ext = (filename ?? '').split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx'].contains(ext)) return Icons.description_rounded;
    return Icons.attach_file_rounded;
  }

  static Color fileColor(String? filename, {Color fallback = Colors.indigo}) {
    final ext = (filename ?? '').split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Colors.teal;
    if (ext == 'pdf') return Colors.red;
    if (['doc', 'docx'].contains(ext)) return Colors.blue;
    return fallback;
  }

  static String? resolveUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final base = ApiConfig.baseUrl;
    // If it's absolute, strip its scheme+host and always rebuild against the
    // current API base. This prevents broken previews when the backend built
    // file_url using a stale/unreachable host (e.g. a previous LAN IP).
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null) return rawUrl;
      final pathAndQuery = uri.hasQuery
          ? '${uri.path}?${uri.query}'
          : uri.path;
      return '$base$pathAndQuery';
    }
    return '$base$rawUrl';
  }

  /// Shows an inline image preview for images, otherwise opens the file
  /// in an external application. Falls back to a snackbar when no file URL
  /// is available.
  static Future<void> preview(
    BuildContext context, {
    required String? rawFileUrl,
    String? fileName,
    String emptyMessage = 'لا يوجد ملف مرفق لهذا المستند',
  }) async {
    final url = resolveUrl(rawFileUrl);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    if (!isImageFile(fileName)) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح هذا الملف')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(8),
          child: SizedBox(
            width: size.width,
            height: size.height * 0.9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.broken_image, color: Colors.white, size: 64),
                            SizedBox(height: 8),
                            Text(
                              'تعذر تحميل الصورة',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _previewIconButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _previewIconButton(
                    icon: Icons.open_in_new,
                    onPressed: () =>
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _previewIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
