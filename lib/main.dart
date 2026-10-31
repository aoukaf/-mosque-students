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
import 'screens/parent_screen.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تسجيل دخول مجهول - يمنع الوصول المباشر لـ Firestore بدون المرور بالتطبيق
  String? authError; // تشخيص مؤقت: يظهر سبب فشل الدخول المجهول بدل تجاهله بصمت
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      // إذا فشل Auth لا نوقف التطبيق
      authError = e is FirebaseAuthException ? '${e.code}: ${e.message}' : '$e';
      debugPrint('AUTH FAILED: $authError');
    }
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

  final parentCode = prefs.getString(SyncService.parentCodeKey);
  final parentMosqueId = prefs.getString(SyncService.parentMosqueIdKey);
  final parentStudentId = prefs.getString(SyncService.parentStudentIdKey);
  final isParent = userRole == 'parent' &&
      parentCode != null &&
      parentMosqueId != null &&
      parentStudentId != null;
  final isAwqaf = !isParent && userRole == 'awqaf';

  // التأكد من وجود جلسة صالحة لهذا الجهاز (تتحقق منها قواعد Firestore).
  // الغالب أنها موجودة ولا يكلّف هذا شيئاً؛ عند عدم وجود اتصال نكمل بما هو محفوظ.
  String? notice;
  try {
    final sync = SyncService();
    final bool ok;
    if (isParent) {
      ok = await sync.ensureParentSession(
          parentCode, ParentLink(mosqueId: parentMosqueId, studentId: parentStudentId));
    } else if (isAwqaf) {
      ok = await sync.ensureAwqafSession();
    } else if (mosqueId != null) {
      ok = await sync.ensureTeacherSession();
    } else {
      ok = true;
    }
    if (!ok) {
      await prefs.remove(SyncService.mosqueIdKey);
      await prefs.remove(SyncService.userRoleKey);
      await prefs.remove(SyncService.parentCodeKey);
      await prefs.remove(SyncService.parentMosqueIdKey);
      await prefs.remove(SyncService.parentStudentIdKey);
      await sync.clearSessionMarker();
      notice = 'يرجى تسجيل الدخول من جديد';
    }
  } catch (_) {
    // لا اتصال أو انتهت المهلة: نكمل
  }

  final loggedOut = notice != null;

  // بعد إعلان المرحلة 2 يُحذف الهاش القديم المقروء علناً (مرة واحدة لكل مسجد)
  if (!loggedOut && !isParent && (isAwqaf || mosqueId != null)) {
    UpdateService.fetchSecurityPhase().then((phase) {
      if (phase >= 2) SyncService().retireLegacyHash(awqaf: isAwqaf);
    });
  }

  runApp(MosqueStudentsApp(
    setupDone: !loggedOut && mosqueId != null,
    isAwqaf: !loggedOut && isAwqaf,
    notice: notice,
    authError: authError,
    parent: !loggedOut && isParent
        ? ParentScreen(code: parentCode, mosqueId: parentMosqueId, studentId: parentStudentId)
        : null,
  ));
}

class MosqueStudentsApp extends StatefulWidget {
  final bool setupDone;
  final bool isAwqaf;
  final Widget? parent;
  final String? notice;
  final String? authError;
  const MosqueStudentsApp(
      {super.key,
      required this.setupDone,
      required this.isAwqaf,
      this.parent,
      this.notice,
      this.authError});

  @override
  State<MosqueStudentsApp> createState() => _MosqueStudentsAppState();
}

class _MosqueStudentsAppState extends State<MosqueStudentsApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  bool get setupDone => widget.setupDone;
  bool get isAwqaf => widget.isAwqaf;
  Widget? get parent => widget.parent;
  String? get notice => widget.notice;

  @override
  void initState() {
    super.initState();
    final err = widget.authError;
    if (err != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(SnackBar(
          duration: const Duration(seconds: 30),
          backgroundColor: Colors.red.shade800,
          content: SelectableText('فشل تسجيل الدخول المجهول:\n$err',
              style: const TextStyle(color: Colors.white)),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
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
      home: parent ??
          (isAwqaf
          ? const AwqafScreen()
          : setupDone
              ? const HomeScreen()
              : MosqueSetupScreen(notice: notice)),
    );
  }
}
