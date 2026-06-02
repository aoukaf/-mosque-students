import 'dart:convert';

class Student {
  String id;
  String name;
  String halqa; // الحلقة
  int partsCompleted; // عدد الأجزاء المكتملة (من 30)
  int stars; // عدد النجوم (حتى 5000)
  String notes;
  DateTime createdAt;
  DateTime updatedAt;

  Student({
    required this.id,
    required this.name,
    required this.halqa,
    this.partsCompleted = 0,
    this.stars = 0,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'halqa': halqa,
      'partsCompleted': partsCompleted,
      'stars': stars,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      halqa: map['halqa'] as String? ?? '',
      partsCompleted: (map['partsCompleted'] as num?)?.toInt() ?? 0,
      stars: (map['stars'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  String toJson() => json.encode(toMap());

  factory Student.fromJson(String source) =>
      Student.fromMap(json.decode(source));

  Student copyWith({
    String? id,
    String? name,
    String? halqa,
    int? partsCompleted,
    int? stars,
    String? notes,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      halqa: halqa ?? this.halqa,
      partsCompleted: partsCompleted ?? this.partsCompleted,
      stars: stars ?? this.stars,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
