import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// يوفّر تحميل/مشاركة الصور المرفوعة (روابط Cloudinary) وملفات PDF من داخل
/// التطبيق. نستخدم نافذة المشاركة القياسية بالنظام (Share Sheet) بدل الكتابة
/// المباشرة على التخزين، لأنها تعمل بدون أي أذونات إضافية على كل الأجهزة
/// وتتيح للمستخدم اختيار "حفظ في الملفات" أو أي تطبيق آخر يريده.
class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  Future<void> downloadImageFromUrl(String url, {String fileName = 'document'}) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل الصورة (كود ${response.statusCode})');
    }
    final ext = _guessImageExtension(url, response.headers['content-type']);
    await _shareBytes(response.bodyBytes, '$fileName$ext');
  }

  Future<void> sharePdfBytes(Uint8List bytes, {String fileName = 'invoice.pdf'}) async {
    await _shareBytes(bytes, fileName);
  }

  Future<void> _shareBytes(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }

  String _guessImageExtension(String url, String? contentType) {
    if (contentType != null) {
      if (contentType.contains('png')) return '.png';
      if (contentType.contains('webp')) return '.webp';
      if (contentType.contains('jpeg') || contentType.contains('jpg')) return '.jpg';
    }
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return '.png';
    if (lower.contains('.webp')) return '.webp';
    return '.jpg';
  }
}
