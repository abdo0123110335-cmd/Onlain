/// صلاحيات الأقسام التي يمكن لموظف معين رفع مستندات فيها.
/// المفاتيح تطابق قيم DocType (ports, customs, storage, permit).
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // 'manager' أو 'employee'
  final Map<String, bool> permissions; // {ports: true, customs: false, ...}
  final bool active;
  final String createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    this.active = true,
    this.createdAt = '',
  });

  bool get isManager => role == 'manager';

  String get username => email.contains('@') ? email.split('@').first : email;

  bool canUpload(String docType) => isManager || (permissions[docType] ?? false);

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role,
    'permissions': permissions,
    'active': active,
    'createdAt': createdAt,
  };

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
    uid: uid,
    name: map['name'] ?? '',
    email: map['email'] ?? '',
    role: map['role'] ?? 'employee',
    permissions: Map<String, bool>.from(map['permissions'] ?? {}),
    active: map['active'] ?? true,
    createdAt: map['createdAt'] ?? '',
  );
}
