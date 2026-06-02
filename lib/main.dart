import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'models/app_theme.dart';
import 'models/sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/mosque_setup_screen.dart';
import 'screens/awqaf_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تسجيل دخول مجهول - يمنع الوصول المباشر لـ Firestore بدون المرور بالتطبيق
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final mosqueId = prefs.getString(SyncService.mosqueIdKey);
  final userRole = prefs.getString(SyncService.userRoleKey);

  if (mosqueId != null) {
    SyncService().initialize(mosqueId);
  }

  runApp(MosqueStudentsApp(
    setupDone: mosqueId != null,
    isAwqaf: userRole == 'awqaf',
  ));
}

class MosqueStudentsApp extends StatelessWidget {
  final bool setupDone;
  final bool isAwqaf;
  const MosqueStudentsApp({super.key, required this.setupDone, required this.isAwqaf});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سجلات طلاب المسجد',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: isAwqaf
          ? const AwqafScreen()
          : setupDone
              ? const HomeScreen()
              : const MosqueSetupScreen(),
    );
  }
}
