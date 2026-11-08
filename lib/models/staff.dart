/// الكادر: معلم، معلم مساعد، مشرف المسجد، مشرف الحلقات العام.
/// يُخزَّن بمجموعة `mosques/{id}/staff` المحمية (معلم المسجد والأوقاف فقط).
class StaffRole {
  static const String teacher = 'teacher';
  static const String assistant = 'assistant';
  static const String mosqueSupervisor = 'mosqueSupervisor';
  static const String halqaSupervisor = 'halqaSupervisor';

  /// ترتيب العرض
  static const List<String> all = [mosqueSupervisor, halqaSupervisor, teacher, assistant];

  static String label(String role) => switch (role) {
        teacher => 'معلم',
        assistant => 'معلم مساعد',
        mosqueSupervisor => 'مشرف المسجد',
        halqaSupervisor => 'مشرف الحلقات العام',
        _ => role,
      };

  static String pluralLabel(String role) => switch (role) {
        teacher => 'المعلمون',
        assistant => 'المعلمون المساعدون',
        mosqueSupervisor => 'مشرف المسجد',
        halqaSupervisor => 'مشرف الحلقات العام',
        _ => role,
      };

  /// الأدوار المرتبطة بحلقة
  static bool hasHalqa(String role) => role == teacher || role == assistant;
}

class QuranStatus {
  static const String mujaz = 'mujaz'; // مجاز
  static const String khatim = 'khatim'; // خاتم (بدون إجازة)
  static const String none = 'none'; // لا هذا ولا ذاك: نسجّل عدد المحفوظات

  static String label(String s) => switch (s) {
        mujaz => 'مجاز',
        khatim => 'خاتم',
        _ => 'غير خاتم',
      };
}

class StaffMember {
  final String id;
  final String role;
  final String fullName; // الاسم الثلاثي
  final String education; // الدراسة
  final String job; // العمل الحالي
  final String birthDate; // yyyy-MM-dd أو فارغ
  final String phone;
  final String quranStatus; // QuranStatus
  final int? memorizedParts; // عدد الأجزاء المحفوظة (عند quranStatus == none)
  final String halqa; // اسم الحلقة (للمعلم والمساعد)

  const StaffMember({
    required this.id,
    required this.role,
    required this.fullName,
    this.education = '',
    this.job = '',
    this.birthDate = '',
    this.phone = '',
    this.quranStatus = QuranStatus.none,
    this.memorizedParts,
    this.halqa = '',
  });

  Map<String, dynamic> toMap() => {
        'role': role,
        'fullName': fullName,
        'education': education,
        'job': job,
        'birthDate': birthDate,
        'phone': phone,
        'quranStatus': quranStatus,
        if (quranStatus == QuranStatus.none && memorizedParts != null) 'memorizedParts': memorizedParts,
        'halqa': halqa,
      };

  factory StaffMember.fromMap(String id, Map<String, dynamic> m) => StaffMember(
        id: id,
        role: m['role'] as String? ?? StaffRole.teacher,
        fullName: m['fullName'] as String? ?? '',
        education: m['education'] as String? ?? '',
        job: m['job'] as String? ?? '',
        birthDate: m['birthDate'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        quranStatus: m['quranStatus'] as String? ?? QuranStatus.none,
        memorizedParts: (m['memorizedParts'] as num?)?.toInt(),
        halqa: m['halqa'] as String? ?? '',
      );

  DateTime? get birthDateTime => DateTime.tryParse(birthDate);

  int? get age {
    final b = birthDateTime;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) years--;
    return years < 0 ? null : years;
  }

  /// نص الحالة القرآنية للعرض
  String get quranStatusLabel {
    if (quranStatus == QuranStatus.none) {
      return memorizedParts != null ? 'يحفظ $memorizedParts جزءاً' : 'غير خاتم';
    }
    return QuranStatus.label(quranStatus);
  }
}

/// معلومات إضافية عن الطالب (هاتف وصف). بمجموعة `mosques/{id}/studentInfo` المحمية.
class StudentInfo {
  final String phone;
  final String grade; // الصف

  const StudentInfo({this.phone = '', this.grade = ''});

  bool get isEmpty => phone.isEmpty && grade.isEmpty;

  Map<String, dynamic> toMap() => {'phone': phone, 'grade': grade};

  factory StudentInfo.fromMap(Map<String, dynamic> m) => StudentInfo(
        phone: m['phone'] as String? ?? '',
        grade: m['grade'] as String? ?? '',
      );
}
