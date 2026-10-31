import 'package:flutter/material.dart';
import '../models/student.dart';
import '../utils/responsive.dart';

/// شاشة اختيار الحلقة: تعرض أسماء الحلقات فقط، وعند اختيار حلقة
/// تُفتح الشاشة المطلوبة (حضور / وظائف) لطلاب هذه الحلقة وحدها.
class HalqaPickerScreen extends StatelessWidget {
  static const String noHalqaLabel = 'بدون حلقة';

  final String title;
  final Color color;
  final List<Student> students;
  final List<String> halqas;
  final Widget Function(String halqaName, List<Student> halqaStudents, List<String> halqas) builder;

  const HalqaPickerScreen({
    super.key,
    required this.title,
    required this.color,
    required this.students,
    required this.halqas,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    final entries = <MapEntry<String, List<Student>>>[];
    for (final h in halqas) {
      final list = students.where((s) => s.halqa == h).toList();
      entries.add(MapEntry(h, list));
    }
    final others = students.where((s) => s.halqa.isEmpty || !halqas.contains(s.halqa)).toList();
    if (others.isNotEmpty) entries.add(MapEntry(noHalqaLabel, others));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold)),
        toolbarHeight: r.isTablet ? 64 : 56,
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: entries.isEmpty
          ? Center(child: Text('لا توجد حلقات', style: TextStyle(fontSize: r.fontSize(15), color: Colors.grey[600])))
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.isTablet ? 600 : double.infinity),
                child: ListView.separated(
                  padding: r.pagePadding,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => SizedBox(height: r.sp(8)),
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final isNoHalqa = e.key == noHalqaLabel && !halqas.contains(e.key);
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(6)),
                        leading: CircleAvatar(
                          radius: r.sp(r.isTablet ? 22 : 18),
                          backgroundColor: color,
                          child: Icon(Icons.groups, color: Colors.white, size: r.iconSize(20)),
                        ),
                        title: Text(e.key, style: TextStyle(fontSize: r.fontSize(r.isTablet ? 17 : 15), fontWeight: FontWeight.w600)),
                        subtitle: Text('${e.value.length} طالب', style: TextStyle(fontSize: r.fontSize(12))),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => builder(e.key, e.value, isNoHalqa ? <String>[] : [e.key]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
