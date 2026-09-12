/// بند مبلغ داخل مستند معلّق (نفس فكرة InvoiceItem لكن قبل الاعتماد).
class PendingItem {
  String description;
  double amount;
  PendingItem({required this.description, required this.amount});

  Map<String, dynamic> toMap() => {'description': description, 'amount': amount};
  factory PendingItem.fromMap(Map<String, dynamic> map) => PendingItem(
    description: map['description'] ?? '',
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
  );
}

/// مستند رفعه موظف (مواني/جمارك/أرضيات/إذن/جودة/أخرى) وينتظر مراجعة واعتماد
/// المدير قبل أن يُحفظ فعلياً داخل ملف العميل وقسم الفواتير.
class PendingDocument {
  String id;
  String docType;
  String clientNameInput; // الاسم كما كتبه الموظف
  String? existingClientId; // إن كان مطابقاً لعميل معتمد سابقاً
  String billNumber;
  int containerCount;
  String commodityType;
  List<PendingItem> items;
  List<String> imageUrls;
  String uploadedByUid;
  String uploadedByName;
  String date;
  String status; // pending / approved / rejected
  String rejectionReason;
  String reviewedByName;
  String reviewedDate;

  PendingDocument({
    required this.id,
    required this.docType,
    required this.clientNameInput,
    this.existingClientId,
    required this.billNumber,
    this.containerCount = 0,
    this.commodityType = '',
    required this.items,
    required this.imageUrls,
    required this.uploadedByUid,
    required this.uploadedByName,
    required this.date,
    this.status = 'pending',
    this.rejectionReason = '',
    this.reviewedByName = '',
    this.reviewedDate = '',
  });

  double get totalAmount => items.fold<double>(0, (s, i) => s + i.amount);

  Map<String, dynamic> toMap() => {
    'docType': docType,
    'clientNameInput': clientNameInput,
    'existingClientId': existingClientId,
    'billNumber': billNumber,
    'containerCount': containerCount,
    'commodityType': commodityType,
    'items': items.map((i) => i.toMap()).toList(),
    'imageUrls': imageUrls,
    'uploadedByUid': uploadedByUid,
    'uploadedByName': uploadedByName,
    'date': date,
    'status': status,
    'rejectionReason': rejectionReason,
    'reviewedByName': reviewedByName,
    'reviewedDate': reviewedDate,
  };

  factory PendingDocument.fromMap(String id, Map<String, dynamic> map) => PendingDocument(
    id: id,
    docType: map['docType'] ?? '',
    clientNameInput: map['clientNameInput'] ?? '',
    existingClientId: map['existingClientId'],
    billNumber: map['billNumber'] ?? '',
    containerCount: (map['containerCount'] as num?)?.toInt() ?? 0,
    commodityType: map['commodityType'] ?? '',
    items: ((map['items'] as List?) ?? []).map((e) => PendingItem.fromMap(Map<String, dynamic>.from(e))).toList(),
    imageUrls: List<String>.from(map['imageUrls'] ?? []),
    uploadedByUid: map['uploadedByUid'] ?? '',
    uploadedByName: map['uploadedByName'] ?? '',
    date: map['date'] ?? '',
    status: map['status'] ?? 'pending',
    rejectionReason: map['rejectionReason'] ?? '',
    reviewedByName: map['reviewedByName'] ?? '',
    reviewedDate: map['reviewedDate'] ?? '',
  );
}
