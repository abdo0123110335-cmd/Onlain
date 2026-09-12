import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  /// نستخدم مصادقة البريد/الباسورد في Firebase لكن نعرضها للمستخدم كـ
  /// "اسم مستخدم" بسيط بإضافة نطاق وهمي ثابت خلف الكواليس.
  static const _fakeDomain = 'elsheikh.customsapp';
  String _usernameToEmail(String username) => '${username.trim().toLowerCase()}@$_fakeDomain';

  Future<String?> login(String username, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: _usernameToEmail(username), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e.code);
    } catch (e) {
      return 'حدث خطأ غير متوقع أثناء تسجيل الدخول';
    }
  }

  Future<void> logout() => _auth.signOut();

  /// يجلب ملف تعريف المستخدم من Firestore. إن لم يوجد ملف بعد (أول تسجيل
  /// دخول على الإطلاق)، يُعتبر هذا المستخدم أول حساب في النظام فيُنشأ له
  /// تلقائياً ملف بصلاحية "مدير" (bootstrap) بدون الحاجة لأي إعداد يدوي إضافي.
  Future<AppUser> loadOrBootstrapProfile(User firebaseUser) async {
    final doc = await _db.collection('users').doc(firebaseUser.uid).get();
    if (doc.exists) {
      return AppUser.fromMap(firebaseUser.uid, doc.data()!);
    }

    final anyUsers = await _db.collection('users').limit(1).get();
    final isFirstEver = anyUsers.docs.isEmpty;

    final profile = AppUser(
      uid: firebaseUser.uid,
      name: firebaseUser.email?.split('@').first ?? 'مستخدم',
      email: firebaseUser.email ?? '',
      role: isFirstEver ? 'manager' : 'employee',
      permissions: const {},
      active: true,
      createdAt: DateFormat('yyyy/MM/dd').format(DateTime.now()),
    );
    await _db.collection('users').doc(firebaseUser.uid).set(profile.toMap());
    return profile;
  }

  Future<AppUser?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  /// ينشئ حساب جديد (موظف أو مدير) بصلاحيات محددة، دون تسجيل خروج المدير
  /// الحالي. يعتمد على تطبيق Firebase ثانوي مؤقت لهذا الغرض فقط.
  Future<String?> createEmployeeAccount({
    required String name,
    required String username,
    required String password,
    required Map<String, bool> permissions,
    String role = 'employee',
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'secondaryAuthApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: _usernameToEmail(username),
        password: password,
      );
      final newUid = cred.user!.uid;

      final profile = AppUser(
        uid: newUid,
        name: name.trim(),
        email: _usernameToEmail(username),
        role: role,
        permissions: permissions,
        active: true,
        createdAt: DateFormat('yyyy/MM/dd').format(DateTime.now()),
      );
      await _db.collection('users').doc(newUid).set(profile.toMap());

      await secondaryAuth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuthError(e.code);
    } catch (e) {
      return 'تعذر إنشاء الحساب: $e';
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    final snap = await _db.collection('users').orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  Future<void> updateUserPermissions(String uid, Map<String, bool> permissions) async {
    await _db.collection('users').doc(uid).update({'permissions': permissions});
  }

  Future<void> setUserActive(String uid, bool active) async {
    await _db.collection('users').doc(uid).update({'active': active});
  }

  /// يرقّي موظفاً إلى مدير أو ينزّل مديراً إلى موظف. القيمة المقبولة: 'manager' أو 'employee'.
  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection('users').doc(uid).update({'role': role});
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد/اسم المستخدم مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً (6 أحرف على الأقل)';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت';
      case 'user-disabled':
        return 'هذا الحساب موقوف حالياً';
      default:
        return 'خطأ: $code';
    }
  }
}
