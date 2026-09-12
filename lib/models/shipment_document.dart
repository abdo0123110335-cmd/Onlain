/// أنواع المستندات المدعومة في التطبيق.
/// كل نوع مربوط بفئة رسوم مستقلة داخل الفاتورة.
class DocType {
  static const ports = 'ports'; // فاتورة رسوم هيئة الموانئ
  static const customs = 'customs'; // إشعار تقييم الجمارك (أسيكودا)
  static const storage = 'storage'; // فاتورة أرضيات الشركة
  static const permit = 'permit'; // رسوم إذن الشركة (إذن التسليم)
  static const quality = 'quality'; // رسوم الجودة (هيئة المواصفات والمقاييس)
  static const other = 'other_docs'; // مستندات أخرى (اسم مستند حر يكتبه المستخدم)

  static const all = [ports, customs, storage, permit, quality, other];

  static String label(String type) {
    switch (type) {
      case ports:
        return 'رسوم هيئة الموانئ البحرية';
      case customs:
        return 'إشعار تقييم الجمارك (أسيكودا)';
      case storage:
        return 'أرضيات الشركة';
      case permit:
        return 'إذن الشركة (إذن التسليم)';
      case quality:
        return 'رسوم الجودة';
      case other:
        return 'مستندات أخرى';
      default:
        return type;
    }
  }

  static String shortTitle(String type) {
    switch (type) {
      case ports:
        return 'فاتورة موانئ';
      case customs:
        return 'فاتورة جمارك';
      case storage:
        return 'فاتورة أرضيات';
      case permit:
        return 'فاتورة إذن';
      case quality:
        return 'فاتورة الجودة';
      case other:
        return 'مستند آخر';
      default:
        return type;
    }
  }
}

/// مستند صورة معتمَد ومربوط فعلياً ببوليصة داخل ملف عميل.
class ShipmentDocument {
  String id;
  String billOfLadingId;
  String docType;
  String imageUrl;
  double amount;
  String description;
  String date;
  String uploadedByName;

  ShipmentDocument({
    required this.id,
    required this.billOfLadingId,
    required this.docType,
    required this.imageUrl,
    required this.amount,
    this.description = '',
    required this.date,
    this.uploadedByName = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'billOfLadingId': billOfLadingId,
    'docType': docType,
    'imageUrl': imageUrl,
    'amount': amount,
    'description': description,
    'date': date,
    'uploadedByName': uploadedByName,
  };

  factory ShipmentDocument.fromMap(Map<String, dynamic> map) => ShipmentDocument(
    id: map['id'],
    billOfLadingId: map['billOfLadingId'] ?? '',
    docType: map['docType'] ?? '',
    imageUrl: map['imageUrl'] ?? '',
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    description: map['description'] ?? '',
    date: map['date'] ?? '',
    uploadedByName: map['uploadedByName'] ?? '',
  );
}
