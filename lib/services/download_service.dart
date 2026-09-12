import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  Future<void> downloadImageFromUrl(String url, {String fileName = 'document'}) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل الصورة (كود ${response.statusCode})');
    }
    final pdfBytes = await _wrapImageInPdf(response.bodyBytes);
    await Printing.sharePdf(bytes: pdfBytes, filename: '$fileName.pdf');
  }

  Future<void> sharePdfBytes(Uint8List bytes, {String fileName = 'invoice.pdf'}) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<Uint8List> _wrapImageInPdf(Uint8List imageBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
    return doc.save();
  }
}
