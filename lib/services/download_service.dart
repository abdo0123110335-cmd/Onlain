import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

<<<<<<< HEAD
=======
/// يوفّر تنزيل/مشاركة الصور المرفوعة (روابط Cloudinary) وملفات الفاتورة PDF
/// من داخل التطبيق.
///
/// ملاحظة تقنية: نتعمّد عدم استخدام مكتبة مشاركة ملفات منفصلة (مثل share_plus)
/// لأنها تجرّ مكتبات أندرويد داخلية (androidx.window, activity, lifecycle...)
/// تتطلب رفع إصدار compileSdk باستمرار مع كل تحديث لقناة Flutter، وهو ما كان
/// يعطّل بناء الـ APK. بدلاً من ذلك نعتمد فقط على مكتبتي pdf وprinting
/// الموجودتين بالفعل في المشروع (ومُثبت أنهما تعملان بلا مشاكل)، فنضع الصورة
/// داخل صفحة PDF واحدة ثم نفتح نافذة المشاركة القياسية بالنظام لهذا الملف.
>>>>>>> c60be71 (update)
class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  Future<void> downloadImageFromUrl(String url, {String fileName = 'document'}) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل الصورة (كود ${response.statusCode})');
    }
<<<<<<< HEAD
    final pdfBytes = await _wrapImageInPdf(response.bodyBytes);
=======
    final pdfBytes = await _wrapImageInPdf([response.bodyBytes]);
    await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');
  }

  /// يحمّل عدة صور معاً في ملف PDF واحد متعدد الصفحات (صفحة لكل صورة)، بدل ما
  /// يحمّل كل صورة في ملف منفصل.
  Future<void> downloadImagesFromUrls(List<String> urls, {String fileName = 'documents'}) async {
    final allBytes = <Uint8List>[];
    for (final url in urls) {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        allBytes.add(response.bodyBytes);
      }
    }
    if (allBytes.isEmpty) {
      throw Exception('تعذر تحميل أي من الصور المحددة');
    }
    final pdfBytes = await _wrapImageInPdf(allBytes);
>>>>>>> c60be71 (update)
    await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');
  }

  Future<void> sharePdfBytes(Uint8List bytes, {String fileName = 'invoice.pdf'}) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

<<<<<<< HEAD
  Future<Uint8List> _wrapImageInPdf(Uint8List imageBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
=======
  Future<Uint8List> _wrapImageInPdf(List<Uint8List> imagesBytes) async {
    final doc = pw.Document();
    for (final imageBytes in imagesBytes) {
      final image = pw.MemoryImage(imageBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
>>>>>>> c60be71 (update)
    return doc.save();
  }
}
