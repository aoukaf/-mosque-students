class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String halqa;
  final bool present;
  final String date;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.halqa,
    required this.present,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'studentName': studentName,
        'halqa': halqa,
        'present': present,
        'date': date,
      };

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      studentId: id,
      studentName: map['studentName'] as String? ?? '',
      halqa: map['halqa'] as String? ?? '',
      present: map['present'] as bool? ?? false,
      date: map['date'] as String? ?? '',
    );
  }
}
