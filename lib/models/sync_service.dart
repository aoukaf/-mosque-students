import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'student.dart';

class MosqueInfo {
  final String id;
  final String name;
  final int studentCount;
  final int halqaCount;
  final String scheduleType; // yearRound | summerOnly | winterOnly
  final List<String> days;
  final String? morningFrom;
  final String? morningTo;
  final String? eveningFrom;
  final String? eveningTo;

  const MosqueInfo({
    required this.id,
    required this.name,
    required this.studentCount,
    required this.halqaCount,
    required this.scheduleType,
    required this.days,
    this.morningFrom,
    this.morningTo,
    this.eveningFrom,
    this.eveningTo,
  });

  factory MosqueInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MosqueInfo(
      id: doc.id,
      name: data['name'] as String? ?? '',
      studentCount: (data['studentCount'] as num?)?.toInt() ?? 0,
      halqaCount: (data['halqaCount'] as num?)?.toInt() ?? 0,
      scheduleType: data['scheduleType'] as String? ?? 'yearRound',
      days: (data['days'] as List?)?.cast<String>() ?? [],
      morningFrom: data['morningFrom'] as String?,
      morningTo: data['morningTo'] as String?,
      eveningFrom: data['eveningFrom'] as String?,
      eveningTo: data['eveningTo'] as String?,
    );
  }
}

class AttendanceStatus {
  static const String present = 'present';
  static const String absent = 'absent';
  static const String excused = 'excused'; // غائب بإذن
}

/// ربط رمز ولي الأمر بالمسجد والطالب
class ParentLink {
  final String mosqueId;
  final String studentId;
  const ParentLink({required this.mosqueId, required this.studentId});
}

/// سجل يوم واحد للطالب (حضور + وظيفة) كما يراه ولي الأمر
class ParentDayRecord {
  final DateTime date;
  final String? attendance; // AttendanceStatus أو null إذا لم يُسجَّل
  final HomeworkRecord? homework;
  const ParentDayRecord({required this.date, this.attendance, this.homework});
}

class HomeworkRecord {
  final bool brought;
  final String surah;
  const HomeworkRecord({required this.brought, required this.surah});
  factory HomeworkRecord.fromMap(Map<String, dynamic> data) => HomeworkRecord(
        brought: data['brought'] as bool? ?? false,
        surah: data['surah'] as String? ?? '',
      );
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _mosqueId;

  static const String _studentsCollection = 'students';
  static const String _halqasCollection = 'halqas';
  static const String _attendanceCollection = 'attendance';
  static const String _awqafCollection = 'awqaf';
  static const String _parentCodesCollection = 'parentCodes';
  static const String _localStudentsKey = 'local_students';
  static const String _localHalqasKey = 'local_halqas';
  static const String mosqueIdKey = 'mosque_id';
  static const String userRoleKey = 'user_role';
  static const String parentCodeKey = 'parent_code';
  static const String parentMosqueIdKey = 'parent_mosque_id';
  static const String parentStudentIdKey = 'parent_student_id';

  // الجلسات: إثبات معرفة كلمة المرور/الرمز، تتحقق منها قواعد Firestore (انظر firestore.rules)
  static const String appVersion = '1.1.0';
  static const String _localHashKey = 'mosque_hash';
  static const String _localAwqafHashKey = 'awqaf_hash';
  static const String _sessionScopeKey = 'session_scope'; // "uid|scope" لآخر جلسة نجحت
  static const Duration _netTimeout = Duration(seconds: 15);

  // =================== تهيئة المسجد ===================

  void initialize(String mosqueId) {
    _mosqueId = mosqueId;
  }

  bool get isInitialized => _mosqueId != null;
  String? get currentMosqueId => _mosqueId;

  DocumentReference<Map<String, dynamic>> get _mosqueRef =>
      _db.collection('mosques').doc(_mosqueId!);

  CollectionReference<Map<String, dynamic>> get _studentsRef =>
      _mosqueRef.collection(_studentsCollection);

  CollectionReference<Map<String, dynamic>> get _halqasRef =>
      _mosqueRef.collection(_halqasCollection);

  CollectionReference<Map<String, dynamic>> _recordsRef(DateTime date) =>
      _mosqueRef.collection(_attendanceCollection).doc(_dateKey(date)).collection('records');

  // =================== الجلسات (الأمان) ===================

  Future<String> _ensureUid() async {
    var user = FirebaseAuth.instance.currentUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    return user!.uid;
  }

  Future<bool> _isPermissionDenied(Future<void> Function() op) async {
    try {
      await op().timeout(_netTimeout);
      return false;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return true;
      rethrow;
    }
  }

  Future<bool> _hasSession(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && prefs.getString(_sessionScopeKey) == '$uid|$scope';
  }

  Future<void> _markSession(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await prefs.setString(_sessionScopeKey, '$uid|$scope');
  }

  Future<void> clearSessionMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionScopeKey);
    await prefs.remove(_localHashKey);
    await prefs.remove(_localAwqafHashKey);
  }

  DocumentReference<Map<String, dynamic>> _mosqueDoc(String mosqueId) =>
      _db.collection('mosques').doc(mosqueId);

  DocumentReference<Map<String, dynamic>> _privateConfig(String mosqueId) =>
      _mosqueDoc(mosqueId).collection('private').doc('config');

  /// يفتح جلسة معلم. true = كلمة المرور صحيحة، false = رقم المسجد أو كلمة المرور خاطئة.
  /// يرمي عند فشل الاتصال. القاعدة على السيرفر هي من يتحقق من الهاش، لا التطبيق.
  Future<bool> teacherLogin(String mosqueId, String passwordHash,
      {bool migrate = true}) async {
    final String uid;
    try {
      uid = await _ensureUid();
    } catch (_) {
      // لا هوية Firebase (فشل الدخول المجهول): نعمل بالطريقة القديمة كما كان 1.0.0
      return _legacyTeacherLogin(mosqueId, passwordHash);
    }
    final denied = await _isPermissionDenied(() => _mosqueDoc(mosqueId)
        .collection('sessions')
        .doc(uid)
        .set({
      'hash': passwordHash,
      'version': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    }));
    if (denied) return _legacyTeacherLogin(mosqueId, passwordHash);

    if (migrate) {
      // نسخ الهاش القديم من وثيقة المسجد (المقروءة) إلى الوثيقة الخاصة.
      // الحذف من العلن يتأخر لمرحلة القواعد الصارمة (retireLegacyHash).
      try {
        await _privateConfig(mosqueId)
            .set({'passwordHash': passwordHash}).timeout(_netTimeout);
      } catch (_) {
        return true; // الجلسة فُتحت؛ لن نضع العلامة فيُعاد الترحيل بالتشغيل التالي
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localHashKey, passwordHash);
    await _markSession('mosque:$mosqueId');
    return true;
  }

  /// توافق مع قواعد لا تدعم الجلسات بعد (القديمة): نتحقق بقراءة الهاش القديم كما كان يفعل 1.0.0.
  /// لا ينجح إلا ما دام الهاش القديم مقروءاً، فيتوقف تلقائياً مع القواعد الصارمة.
  /// لا نضع علامة جلسة هنا، فيُعاد فتح جلسة حقيقية بالتشغيل التالي عند نشر القواعد الجديدة.
  Future<bool> _legacyTeacherLogin(String mosqueId, String passwordHash) async {
    try {
      final doc = await _mosqueDoc(mosqueId).get().timeout(_netTimeout);
      if (doc.data()?['passwordHash'] != passwordHash) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localHashKey, passwordHash);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _legacyAwqafLogin(String passwordHash) async {
    try {
      final doc = await _db.collection(_awqafCollection).doc('config').get().timeout(_netTimeout);
      if (doc.data()?['passwordHash'] != passwordHash) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localAwqafHashKey, passwordHash);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// عند تشغيل التطبيق: يتأكد أن للجهاز جلسة معلم صالحة (ويرحّل المساجد القديمة بصمت).
  /// false = لا بد من تسجيل الدخول من جديد (مثلاً تغيّرت كلمة المرور من جهاز آخر).
  Future<bool> ensureTeacherSession() async {
    final id = _mosqueId;
    if (id == null) return false;
    await _ensureUid();
    if (await _hasSession('mosque:$id')) return true;

    final prefs = await SharedPreferences.getInstance();
    var hash = prefs.getString(_localHashKey);
    if (hash == null) {
      // جهاز لم يشغّل النسخة الجديدة من قبل: نأخذ الهاش القديم إن كان ما زال مقروءاً
      try {
        final doc = await _mosqueDoc(id).get().timeout(_netTimeout);
        hash = doc.data()?['passwordHash'] as String?;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') return false; // المرحلة 2: لا بد من تسجيل دخول جديد
        rethrow;
      }
    }
    if (hash == null) return false;
    return teacherLogin(id, hash);
  }

  /// يحذف الهاش القديم المقروء علناً. يُستدعى فقط عندما يعلن version.json
  /// عن security_phase >= 2، أي بعد أن مرّت الأجهزة بالنسخة الجديدة وحفظت الهاش محلياً.
  Future<void> retireLegacyHash({required bool awqaf}) async {
    try {
      // لا نحذف إلا إذا كان لهذا الجهاز نسخة محلية من الهاش (حتى لا نُقفله خارج حسابه)
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(awqaf ? _localAwqafHashKey : _localHashKey) == null) return;
      if (awqaf) {
        await _db
            .collection(_awqafCollection)
            .doc('config')
            .update({'passwordHash': FieldValue.delete()}).timeout(_netTimeout);
      } else if (_mosqueId != null) {
        await _mosqueRef.update({'passwordHash': FieldValue.delete()}).timeout(_netTimeout);
      }
    } catch (_) {
      // سيُعاد بالتشغيل التالي
    }
  }

  // =================== إدارة المسجد ===================

  Future<void> createMosque(String mosqueId, String passwordHash, String name) async {
    final info = {
      'createdAt': FieldValue.serverTimestamp(),
      'name': name,
      'studentCount': 0,
      'halqaCount': _defaultHalqas.length,
      'scheduleType': 'yearRound',
    };
    try {
      final batch = _db.batch();
      batch.set(_mosqueDoc(mosqueId), info);
      batch.set(_privateConfig(mosqueId), {'passwordHash': passwordHash});
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // قواعد قديمة بلا مسار الهاش الخاص: نحفظ الهاش بوثيقة المسجد كما كان بـ 1.0.0
      await _mosqueDoc(mosqueId).set({...info, 'passwordHash': passwordHash});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localHashKey, passwordHash);
      await _createDefaultHalqas(mosqueId);
      return;
    }

    if (!await teacherLogin(mosqueId, passwordHash, migrate: false)) {
      throw StateError('تعذّر فتح جلسة للمسجد الجديد');
    }
    await _createDefaultHalqas(mosqueId);
  }

  Future<void> _createDefaultHalqas(String mosqueId) async {
    final halqas = _db.batch();
    for (final halqa in _defaultHalqas) {
      halqas.set(_halqasRefOf(mosqueId).doc(halqa),
          {'name': halqa, 'createdAt': FieldValue.serverTimestamp()});
    }
    await halqas.commit();
  }

  CollectionReference<Map<String, dynamic>> _halqasRefOf(String mosqueId) =>
      _mosqueDoc(mosqueId).collection(_halqasCollection);

  Future<void> updateMosqueInfo({
    String? name,
    String? passwordHash,
    String? scheduleType,
    List<String>? days,
    String? morningFrom,
    String? morningTo,
    String? eveningFrom,
    String? eveningTo,
  }) async {
    final data = <String, dynamic>{};
    if (passwordHash != null) {
      // الهاش الجديد + جلسة هذا الجهاز بنفس الدفعة، فتبقى جلسته صالحة وتسقط جلسات الأجهزة الأخرى
      final id = _mosqueId!;
      try {
        final uid = await _ensureUid();
        final batch = _db.batch();
        batch.set(_privateConfig(id), {'passwordHash': passwordHash});
        batch.set(_mosqueDoc(id).collection('sessions').doc(uid), {
          'hash': passwordHash,
          'version': appVersion,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        data['passwordHash'] = passwordHash; // قواعد قديمة: الهاش بوثيقة المسجد
      } catch (_) {
        data['passwordHash'] = passwordHash; // بدون هوية (فشل الدخول المجهول)
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localHashKey, passwordHash);
    }
    if (name != null) data['name'] = name;
    if (scheduleType != null) data['scheduleType'] = scheduleType;
    if (days != null) data['days'] = days;
    if (morningFrom != null) data['morningFrom'] = morningFrom;
    if (morningTo != null) data['morningTo'] = morningTo;
    if (eveningFrom != null) data['eveningFrom'] = eveningFrom;
    if (eveningTo != null) data['eveningTo'] = eveningTo;
    if (data.isNotEmpty) await _mosqueRef.update(data);
  }

  Stream<List<String>> watchMosqueHalqas(String mosqueId) {
    return _db
        .collection('mosques')
        .doc(mosqueId)
        .collection(_halqasCollection)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList()..sort());
  }

  Stream<List<Student>> watchMosqueStudents(String mosqueId) {
    return _db
        .collection('mosques')
        .doc(mosqueId)
        .collection(_studentsCollection)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Student.fromMap(data);
            }).toList()
              ..sort((a, b) => b.partsCompleted.compareTo(a.partsCompleted)));
  }

  Future<void> deleteMosque(String mosqueId) async {
    final mosqueRef = _db.collection('mosques').doc(mosqueId);
    // حذف الطلاب
    final students = await mosqueRef.collection(_studentsCollection).get();
    for (final doc in students.docs) {
      final code = doc.data()['parentCode'] as String? ?? '';
      if (code.isNotEmpty) {
        await _db.collection(_parentCodesCollection).doc(code).delete();
      }
      await doc.reference.delete();
    }
    // حذف الحلقات
    final halqas = await mosqueRef.collection(_halqasCollection).get();
    for (final doc in halqas.docs) {
      await doc.reference.delete();
    }
    // حذف الجلسات وأسرار المسجد
    for (final sub in ['sessions', 'parents']) {
      final snap = await mosqueRef.collection(sub).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
    await _privateConfig(mosqueId).delete();
    // حذف وثيقة المسجد (بيانات الحضور والوظائف تصبح غير قابلة للوصول بالقواعد)
    await mosqueRef.delete();
  }

  Future<MosqueInfo?> getMosqueInfo() async {
    try {
      final doc = await _mosqueRef.get();
      if (!doc.exists) return null;
      return MosqueInfo.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  // =================== الأوقاف ===================

  Future<bool> awqafExists() async {
    try {
      final doc = await _db
          .collection(_awqafCollection)
          .doc('config')
          .get(const GetOptions(source: Source.server));
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  DocumentReference<Map<String, dynamic>> get _awqafPrivate =>
      _db.collection(_awqafCollection).doc('private');

  Future<void> createAwqaf(String passwordHash) async {
    final batch = _db.batch();
    batch.set(_db.collection(_awqafCollection).doc('config'),
        {'createdAt': FieldValue.serverTimestamp()});
    batch.set(_awqafPrivate, {'passwordHash': passwordHash});
    await batch.commit();
    if (!await awqafLogin(passwordHash, migrate: false)) {
      throw StateError('تعذّر فتح جلسة الأوقاف');
    }
  }

  /// يفتح جلسة الأوقاف. true = كلمة المرور صحيحة. التحقق على السيرفر عبر القواعد.
  Future<bool> awqafLogin(String passwordHash, {bool migrate = true}) async {
    final String uid;
    try {
      uid = await _ensureUid();
    } catch (_) {
      return _legacyAwqafLogin(passwordHash); // لا هوية Firebase: الطريقة القديمة
    }
    final denied = await _isPermissionDenied(() => _db
        .collection('awqafSessions')
        .doc(uid)
        .set({
      'hash': passwordHash,
      'version': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    }));
    if (denied) return _legacyAwqafLogin(passwordHash);

    if (migrate) {
      // نسخ الهاش القديم من وثيقة config (المقروءة) إلى الوثيقة الخاصة
      try {
        await _awqafPrivate.set({'passwordHash': passwordHash}).timeout(_netTimeout);
      } catch (_) {
        return true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localAwqafHashKey, passwordHash);
    await _markSession('awqaf');
    return true;
  }

  /// عند تشغيل التطبيق بدور الأوقاف. false = لا بد من تسجيل الدخول من جديد.
  Future<bool> ensureAwqafSession() async {
    await _ensureUid();
    if (await _hasSession('awqaf')) return true;
    final prefs = await SharedPreferences.getInstance();
    var hash = prefs.getString(_localAwqafHashKey);
    hash ??= (await _db.collection(_awqafCollection).doc('config').get().timeout(_netTimeout))
        .data()?['passwordHash'] as String?; // null بعد حذف الهاش القديم
    if (hash == null) return false;
    return awqafLogin(hash);
  }

  // =================== جلسة ولي الأمر ===================

  /// true = الرمز مقبول. false = مرفوض (مثلاً أُبطل الرمز).
  Future<bool> openParentSession(String code, ParentLink link) async {
    final uid = await _ensureUid();
    final denied = await _isPermissionDenied(() => _mosqueDoc(link.mosqueId)
        .collection('parents')
        .doc(uid)
        .set({
      'code': code,
      'studentId': link.studentId,
      'createdAt': FieldValue.serverTimestamp(),
    }));
    if (denied) return false;
    await _markSession('parent:$code');
    return true;
  }

  Future<bool> ensureParentSession(String code, ParentLink link) async {
    await _ensureUid();
    if (await _hasSession('parent:$code')) return true;
    return openParentSession(code, link);
  }

  Future<void> closeParentSession(String mosqueId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _mosqueDoc(mosqueId).collection('parents').doc(uid).delete().timeout(_netTimeout);
      }
    } catch (_) {}
    await clearSessionMarker();
  }

  Stream<List<MosqueInfo>> watchAllMosques() {
    return _db.collection('mosques').snapshots().map((snap) {
      final list = snap.docs.map((doc) => MosqueInfo.fromDoc(doc)).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  // =================== أولياء الأمور ===================

  // بدون الحروف المتشابهة (I, O, 0, 1) ليسهل كتابة الرمز
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String normalizeParentCode(String input) =>
      input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  static String formatParentCode(String code) =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  /// ينشئ رمزاً جديداً للطالب ويُبطل رمزه القديم إن وُجد
  Future<String> generateParentCode(Student student) async {
    final rng = Random.secure();
    final codes = _db.collection(_parentCodesCollection);
    String code;
    do {
      code = List.generate(8, (_) => _codeAlphabet[rng.nextInt(_codeAlphabet.length)]).join();
    } while ((await codes.doc(code).get()).exists);

    final batch = _db.batch();
    batch.set(codes.doc(code), {
      'mosqueId': _mosqueId,
      'studentId': student.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_studentsRef.doc(student.id), {'parentCode': code});
    if (student.parentCode.isNotEmpty) batch.delete(codes.doc(student.parentCode));
    await batch.commit();
    return code;
  }

  /// null = الرمز غير موجود. يرمي استثناء عند فشل الاتصال.
  Future<ParentLink?> resolveParentCode(String code) async {
    final doc = await _db.collection(_parentCodesCollection).doc(code).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final mosqueId = data['mosqueId'] as String?;
    final studentId = data['studentId'] as String?;
    if (mosqueId == null || studentId == null) return null;
    return ParentLink(mosqueId: mosqueId, studentId: studentId);
  }

  Stream<Student?> watchStudentIn(String mosqueId, String studentId) {
    return _db
        .collection('mosques')
        .doc(mosqueId)
        .collection(_studentsCollection)
        .doc(studentId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;
      return Student.fromMap(data);
    });
  }

  Future<MosqueInfo?> getMosqueInfoById(String mosqueId) async {
    try {
      final doc = await _db.collection('mosques').doc(mosqueId).get();
      if (!doc.exists) return null;
      return MosqueInfo.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  /// سجل حضور ووظائف الطالب لآخر [days] يوماً (الأحدث أولاً)، الأيام الفارغة تُحذف
  Future<List<ParentDayRecord>> getStudentHistory(
      String mosqueId, String studentId, {int days = 30}) async {
    final today = DateTime.now();
    final to = DateTime(today.year, today.month, today.day);
    final from = DateTime(to.year, to.month, to.day - (days - 1));
    return (await getStudentHistoryRange(mosqueId, studentId, from, to)).records;
  }

  /// سجل حضور ووظائف الطالب بين [from] و[to] (شاملتين)، الأحدث أولاً، الأيام الفارغة تُحذف.
  /// كل يوم = قراءتان (حضور + وظيفة). [failures] = عدد القراءات التي فشلت (لا تُحسب "فارغة").
  Future<({List<ParentDayRecord> records, int failures})> getStudentHistoryRange(
      String mosqueId, String studentId, DateTime from, DateTime to) async {
    final mosque = _db.collection('mosques').doc(mosqueId);
    var failures = 0;

    Future<Map<String, dynamic>?> read(String collection, DateTime d) async {
      try {
        final doc = await mosque
            .collection(collection)
            .doc(_dateKey(d))
            .collection('records')
            .doc(studentId)
            .get();
        return doc.exists ? doc.data() : null;
      } catch (_) {
        failures++;
        return null;
      }
    }

    final dates = <DateTime>[];
    for (var d = DateTime(to.year, to.month, to.day);
        !d.isBefore(DateTime(from.year, from.month, from.day));
        d = DateTime(d.year, d.month, d.day - 1)) {
      dates.add(d); // الأحدث أولاً
    }
    final results = await Future.wait(dates.map((d) async {
      final att = await read(_attendanceCollection, d);
      final hw = await read('homework', d);
      return ParentDayRecord(
        date: d,
        attendance: att == null ? null : _statusOf(att),
        homework: hw == null ? null : HomeworkRecord.fromMap(hw),
      );
    }));
    return (
      records: results.where((r) => r.attendance != null || r.homework != null).toList(),
      failures: failures,
    );
  }

  // =================== اتصال الإنترنت ===================

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  // =================== الطلاب ===================

  Stream<Student?> watchStudent(String id) {
    return _studentsRef.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;
      return Student.fromMap(data);
    });
  }

  Stream<List<Student>> watchStudents() {
    return _studentsRef
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Student.fromMap(data);
            }).toList());
  }

  Future<List<Student>> getStudents() async {
    try {
      final snap = await _studentsRef
          .orderBy('name')
          .get(const GetOptions(source: Source.serverAndCache));

      final students = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Student.fromMap(data);
      }).toList();

      await _saveLocalStudents(students);
      return students;
    } catch (_) {
      return await _getLocalStudents();
    }
  }

  Future<void> addStudent(Student student) async {
    final data = student.toMap();
    data.remove('id');
    final batch = _db.batch();
    batch.set(_studentsRef.doc(student.id), data);
    batch.update(_mosqueRef, {'studentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> updateStudent(Student student) async {
    final data = student.toMap();
    data.remove('id');
    await _studentsRef.doc(student.id).set(data);
  }

  Future<void> deleteStudent(String id, {String parentCode = ''}) async {
    final batch = _db.batch();
    batch.delete(_studentsRef.doc(id));
    if (parentCode.isNotEmpty) {
      batch.delete(_db.collection(_parentCodesCollection).doc(parentCode));
    }
    batch.update(_mosqueRef, {'studentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  // =================== الحلقات ===================

  Stream<List<String>> watchHalqas() {
    return _halqasRef
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  Future<List<String>> getHalqas() async {
    try {
      final snap = await _halqasRef
          .get(const GetOptions(source: Source.serverAndCache));
      final halqas = snap.docs.map((doc) => doc.id).toList();
      if (halqas.isEmpty) return _defaultHalqas;
      await _saveLocalHalqas(halqas);
      return halqas;
    } catch (_) {
      return await _getLocalHalqas();
    }
  }

  Future<void> addHalqa(String halqa) async {
    final batch = _db.batch();
    batch.set(_halqasRef.doc(halqa), {'name': halqa, 'createdAt': FieldValue.serverTimestamp()});
    batch.update(_mosqueRef, {'halqaCount': FieldValue.increment(1)});
    await batch.commit();
  }

  // اسم الحلقة هو معرّف الوثيقة، فإعادة التسمية = نسخ + نقل الطلاب + حذف القديمة
  Future<void> renameHalqa(String oldName, String newName) async {
    final snap = await _studentsRef.where('halqa', isEqualTo: oldName).get();
    final batch = _db.batch();
    batch.set(_halqasRef.doc(newName), {'name': newName, 'createdAt': FieldValue.serverTimestamp()});
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'halqa': newName});
    }
    batch.delete(_halqasRef.doc(oldName));
    await batch.commit();
  }

  Future<bool> halqaExists(String name) async {
    final doc = await _halqasRef.doc(name).get();
    return doc.exists;
  }

  Future<int> countStudentsInHalqa(String halqa) async {
    final snap = await _studentsRef
        .where('halqa', isEqualTo: halqa)
        .get();
    return snap.docs.length;
  }

  Future<void> deleteHalqa(String halqa) async {
    final snap = await _studentsRef
        .where('halqa', isEqualTo: halqa)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'halqa': ''});
    }
    batch.delete(_halqasRef.doc(halqa));
    batch.update(_mosqueRef, {'halqaCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  // =================== الوظائف ===================

  CollectionReference<Map<String, dynamic>> _homeworkRef(DateTime date) =>
      _mosqueRef.collection('homework').doc(_dateKey(date)).collection('records');

  Stream<Map<String, HomeworkRecord>> watchHomework(DateTime date) {
    return _homeworkRef(date).snapshots().map((snap) => {
          for (var doc in snap.docs)
            doc.id: HomeworkRecord.fromMap(doc.data())
        });
  }

  Future<Map<String, HomeworkRecord>> getHomework(DateTime date) async {
    try {
      final snap = await _homeworkRef(date)
          .get(const GetOptions(source: Source.serverAndCache));
      return {
        for (var doc in snap.docs)
          doc.id: HomeworkRecord.fromMap(doc.data())
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> setHomework(DateTime date, String studentId, String studentName,
      String halqa, bool brought, String surah) async {
    await _homeworkRef(date).doc(studentId).set({
      'studentName': studentName,
      'halqa': halqa,
      'brought': brought,
      'surah': surah,
      'date': _dateKey(date),
    });
  }

  // =================== الحضور ===================

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // الحالة القديمة كانت 'present' فقط (bool)، نحافظ على قراءتها
  static String _statusOf(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    if (status != null) return status;
    return (data['present'] as bool? ?? false)
        ? AttendanceStatus.present
        : AttendanceStatus.absent;
  }

  Stream<Map<String, String>> watchAttendance(DateTime date) {
    return _recordsRef(date).snapshots().map((snap) => {
          for (var doc in snap.docs) doc.id: _statusOf(doc.data())
        });
  }

  Future<Map<String, String>> getAttendance(DateTime date) async {
    try {
      final snap = await _recordsRef(date)
          .get(const GetOptions(source: Source.serverAndCache));
      return {
        for (var doc in snap.docs) doc.id: _statusOf(doc.data())
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> setAttendance(DateTime date, String studentId,
      String studentName, String halqa, String status) async {
    await _recordsRef(date).doc(studentId).set({
      'studentName': studentName,
      'halqa': halqa,
      'status': status,
      'present': status == AttendanceStatus.present,
      'date': _dateKey(date),
    });
  }

  // =================== التخزين المحلي ===================

  List<String> get _defaultHalqas =>
      ['الحلقة الأولى', 'الحلقة الثانية', 'الحلقة الثالثة'];

  Future<List<Student>> _getLocalStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_localStudentsKey);
    if (data == null) return [];
    final list = json.decode(data) as List;
    return list.map((e) => Student.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveLocalStudents(List<Student> students) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _localStudentsKey, json.encode(students.map((s) => s.toMap()).toList()));
  }

  Future<List<String>> _getLocalHalqas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_localHalqasKey);
    if (data == null) return _defaultHalqas;
    return (json.decode(data) as List).cast<String>();
  }

  Future<void> _saveLocalHalqas(List<String> halqas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localHalqasKey, json.encode(halqas));
  }
}
