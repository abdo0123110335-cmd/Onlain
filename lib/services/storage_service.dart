import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _cloudName = 'lw8andem';
  static const String _uploadPreset = 'elsheikh_uploads';

  Uri get _uploadUrl => Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

  Future<String> uploadDocumentImage({
    required File file,
    required String clientKey,
    required String billNumber,
  }) async {
    final safeBill = billNumber.trim().isEmpty
        ? 'غير_محدد'
        : billNumber.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final request = http.MultipartRequest('POST', _uploadUrl)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'clients/$clientKey/$safeBill'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('فشل رفع الصورة إلى Cloudinary (كود ${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null) {
      throw Exception('لم يتم استلام رابط الصورة من Cloudinary بعد الرفع');
    }
    return url;
  }

  Future<List<String>> uploadDocumentImages({
    required List<File> files,
    required String clientKey,
    required String billNumber,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadDocumentImage(file: file, clientKey: clientKey, billNumber: billNumber);
      urls.add(url);
    }
    return urls;
  }
}
