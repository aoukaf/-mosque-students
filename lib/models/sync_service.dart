import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const String _localStudentsKey = 'local_students';
  static const String _localHalqasKey = 'local_halqas';
  static const String mosqueIdKey = 'mosque_id';
  static const String userRoleKey = 'user_role';

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

  // =================== إدارة المسجد ===================

  Future<void> createMosque(String mosqueId, String passwordHash, String name, String password) async {
    await _db.collection('mosques').doc(mosqueId).set({
      'createdAt': FieldValue.serverTimestamp(),
      'passwordHash': passwordHash,
      'name': name,
      'studentCount': 0,
      'halqaCount': _defaultHalqas.length,
      'scheduleType': 'yearRound',
    });
    for (final halqa in _defaultHalqas) {
      await _db
          .collection('mosques')
          .doc(mosqueId)
          .collection(_halqasCollection)
          .doc(halqa)
          .set({'name': halqa, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  Future<bool> verifyMosque(String mosqueId, String passwordHash) async {
    try {
      final doc = await _db
          .collection('mosques')
          .doc(mosqueId)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return false;
      return doc.data()?['passwordHash'] == passwordHash;
    } catch (_) {
      return false;
    }
  }

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
    if (name != null) data['name'] = name;
    if (passwordHash != null) data['passwordHash'] = passwordHash;
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
      await doc.reference.delete();
    }
    // حذف الحلقات
    final halqas = await mosqueRef.collection(_halqasCollection).get();
    for (final doc in halqas.docs) {
      await doc.reference.delete();
    }
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

  Future<void> createAwqaf(String passwordHash) async {
    await _db.collection(_awqafCollection).doc('config').set({
      'passwordHash': passwordHash,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> verifyAwqaf(String passwordHash) async {
    try {
      final doc = await _db
          .collection(_awqafCollection)
          .doc('config')
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return false;
      return doc.data()?['passwordHash'] == passwordHash;
    } catch (_) {
      return false;
    }
  }

  Stream<List<MosqueInfo>> watchAllMosques() {
    return _db.collection('mosques').snapshots().map((snap) {
      final list = snap.docs.map((doc) => MosqueInfo.fromDoc(doc)).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
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

  Future<void> deleteStudent(String id) async {
    final batch = _db.batch();
    batch.delete(_studentsRef.doc(id));
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

  Stream<Map<String, bool>> watchAttendance(DateTime date) {
    return _recordsRef(date).snapshots().map((snap) => {
          for (var doc in snap.docs)
            doc.id: (doc.data()['present'] as bool? ?? false)
        });
  }

  Future<Map<String, bool>> getAttendance(DateTime date) async {
    try {
      final snap = await _recordsRef(date)
          .get(const GetOptions(source: Source.serverAndCache));
      return {
        for (var doc in snap.docs)
          doc.id: (doc.data()['present'] as bool? ?? false)
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> setAttendance(DateTime date, String studentId,
      String studentName, String halqa, bool present) async {
    await _recordsRef(date).doc(studentId).set({
      'studentName': studentName,
      'halqa': halqa,
      'present': present,
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
