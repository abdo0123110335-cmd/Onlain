import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// ملف إعدادات Firebase. هذا الملف "عنصر نائب" مؤقت فقط — عند تفعيل الـ CI
/// (بعد إضافة GOOGLE_SERVICES_JSON كـ Secret في مستودع GitHub) سيقوم خط
/// البناء تلقائياً باستبدال هذا الملف بالقيم الحقيقية المستخرجة من ملف
/// google-services.json الخاص بمشروعك على Firebase قبل كل عملية بناء.
///
/// لا حاجة لتعديله يدوياً طالما تبني التطبيق عبر GitHub Actions.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('هذا الإعداد مخصص لتطبيق أندرويد فقط.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('منصة غير مدعومة حالياً - التطبيق مُعد لأندرويد فقط.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME_API_KEY',
    appId: 'REPLACE_ME_APP_ID',
    messagingSenderId: 'REPLACE_ME_SENDER_ID',
    projectId: 'REPLACE_ME_PROJECT_ID',
    storageBucket: 'REPLACE_ME_PROJECT_ID.appspot.com',
  );
}
