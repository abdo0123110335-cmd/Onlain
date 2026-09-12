import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ElsheikhCustomsApp());
}

class ElsheikhCustomsApp extends StatelessWidget {
  const ElsheikhCustomsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أعمال الشيخ مختار للتخليص الجمركي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SD'),
      supportedLocales: const [
        Locale('ar', 'SD'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF003366),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          primary: const Color(0xFF003366),
          secondary: const Color(0xFF0099CC),
          background: const Color(0xFFF4F6F9),
        ),
        fontFamily: GoogleFonts.cairo().fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003366),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// يحدد الشاشة المناسبة حسب حالة تسجيل الدخول: شاشة الدخول، أو الرئيسية بعد
/// تحميل ملف تعريف المستخدم (الدور + الصلاحيات) من Firestore.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }
        return FutureBuilder<AppUser>(
          future: AuthService.instance.loadOrBootstrapProfile(firebaseUser),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (userSnap.hasError || !userSnap.hasData) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('تعذر تحميل بيانات الحساب. تحقق من اتصال الإنترنت.'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => AuthService.instance.logout(),
                          child: const Text('تسجيل الخروج والمحاولة مجدداً'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final appUser = userSnap.data!;
            if (!appUser.active) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.block, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        const Text('تم إيقاف هذا الحساب. تواصل مع المدير.'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => AuthService.instance.logout(),
                          child: const Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return HomeScreen(appUser: appUser);
          },
        );
      },
    );
  }
}
