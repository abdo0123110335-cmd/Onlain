class Client {
  final String id;
  final String name;
  final String phone;
  final String taxNumber;
  final String address;
  final double advanceBalance;
  final String createdByName;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.taxNumber,
    required this.address,
    this.advanceBalance = 0.0,
    this.createdByName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'taxNumber': taxNumber,
      'address': address,
      'advanceBalance': advanceBalance,
      'createdByName': createdByName,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      phone: map['phone'] ?? '',
      taxNumber: map['taxNumber'] ?? '',
      address: map['address'] ?? '',
      advanceBalance: (map['advanceBalance'] as num?)?.toDouble() ?? 0.0,
      createdByName: map['createdByName'] ?? '',
    );
  }
}
