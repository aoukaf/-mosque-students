/// أيام دوام الحلقة (فئة الحلقة): تُحدَّد من إعدادات كل حلقة، ويقتصر تسجيل الحضور والوظائف عليها.
/// قائمة فارغة = لم تُحدَّد أيام، فكل الأيام مسموحة.
const List<String> kWeekDays = [
  'السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'
];

String weekdayName(DateTime d) => switch (d.weekday) {
      DateTime.monday => 'الاثنين',
      DateTime.tuesday => 'الثلاثاء',
      DateTime.wednesday => 'الأربعاء',
      DateTime.thursday => 'الخميس',
      DateTime.friday => 'الجمعة',
      DateTime.saturday => 'السبت',
      _ => 'الأحد',
    };

bool isHalqaDay(DateTime d, List<String> days) => days.isEmpty || days.contains(weekdayName(d));

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// أحدث يوم دوام <= [from] (أو [from] نفسه إذا لا قيود)
DateTime latestHalqaDay(DateTime from, List<String> days) {
  var d = _dayOnly(from);
  for (var i = 0; i < 7; i++) {
    if (isHalqaDay(d, days)) return d;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return _dayOnly(from);
}

/// يوم الدوام السابق مباشرة لـ[d]
DateTime prevHalqaDay(DateTime d, List<String> days) {
  var p = DateTime(d.year, d.month, d.day - 1);
  for (var i = 0; i < 7 && !isHalqaDay(p, days); i++) {
    p = DateTime(p.year, p.month, p.day - 1);
  }
  return p;
}

/// يوم الدوام التالي لـ[d] بشرط ألا يتجاوز [max]، وإلا null
DateTime? nextHalqaDay(DateTime d, List<String> days, DateTime max) {
  var n = DateTime(d.year, d.month, d.day + 1);
  for (var i = 0; i < 7 && !isHalqaDay(n, days); i++) {
    n = DateTime(n.year, n.month, n.day + 1);
  }
  return n.isAfter(_dayOnly(max)) ? null : n;
}

/// نص للعرض: "السبت، الاثنين" أو "كل الأيام"
String halqaDaysLabel(List<String> days) {
  if (days.isEmpty) return 'كل الأيام';
  final ordered = kWeekDays.where(days.contains).toList();
  return ordered.join('، ');
}
