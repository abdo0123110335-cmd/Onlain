class BillOfLading {
  String id;
  String billNumber;
  String clientId;
  String clientName;
  String vesselName;
  int containerCount;
  String commodityType; // الصنف (نوع البضاعة)
  String date;

  BillOfLading({
    required this.id,
    required this.billNumber,
    required this.clientId,
    required this.clientName,
    required this.vesselName,
    required this.containerCount,
    this.commodityType = '',
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'billNumber': billNumber,
    'clientId': clientId,
    'clientName': clientName,
    'vesselName': vesselName,
    'containerCount': containerCount,
    'commodityType': commodityType,
    'date': date,
  };

  factory BillOfLading.fromMap(Map<String, dynamic> map) => BillOfLading(
    id: map['id'],
    billNumber: map['billNumber'] ?? '',
    clientId: map['clientId'] ?? '',
    clientName: map['clientName'] ?? '',
    vesselName: map['vesselName'] ?? '',
    containerCount: (map['containerCount'] as num?)?.toInt() ?? 0,
    commodityType: map['commodityType'] ?? '',
    date: map['date'] ?? '',
  );
}
