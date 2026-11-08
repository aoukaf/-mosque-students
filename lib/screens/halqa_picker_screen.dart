import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/sync_service.dart';
import '../utils/halqa_days.dart';
import '../utils/responsive.dart';

/// شاشة اختيار الحلقة: تعرض أسماء الحلقات فقط (مع أيام دوام كل حلقة)، وعند اختيار حلقة
/// تُفتح الشاشة المطلوبة (حضور / وظائف) لطلاب هذه الحلقة وحدها وبأيام دوامها فقط.
class HalqaPickerScreen extends StatefulWidget {
  static const String noHalqaLabel = 'بدون حلقة';

  final String title;
  final Color color;
  final List<Student> students;
  final List<String> halqas;
  final Widget Function(
          String halqaName, List<Student> halqaStudents, List<String> halqas, List<String> days)
      builder;

  const HalqaPickerScreen({
    super.key,
    required this.title,
    required this.color,
    required this.students,
    required this.halqas,
    required this.builder,
  });

  @override
  State<HalqaPickerScreen> createState() => _HalqaPickerScreenState();
}

class _HalqaPickerScreenState extends State<HalqaPickerScreen> {
  StreamSubscription<Map<String, List<String>>>? _sub;
  Map<String, List<String>> _days = {};

  @override
  void initState() {
    super.initState();
    _sub = SyncService().watchHalqaDays().listen(
      (m) { if (mounted) setState(() => _days = m); },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    const noHalqa = HalqaPickerScreen.noHalqaLabel;

    final entries = <MapEntry<String, List<Student>>>[];
    for (final h in widget.halqas) {
      final list = widget.students.where((s) => s.halqa == h).toList();
      entries.add(MapEntry(h, list));
    }
    final others = widget.students
        .where((s) => s.halqa.isEmpty || !widget.halqas.contains(s.halqa))
        .toList();
    if (others.isNotEmpty) entries.add(MapEntry(noHalqa, others));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold)),
        toolbarHeight: r.isTablet ? 64 : 56,
        backgroundColor: widget.color,
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
                    final isNoHalqa = e.key == noHalqa && !widget.halqas.contains(e.key);
                    final days = isNoHalqa ? const <String>[] : (_days[e.key] ?? const <String>[]);
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(6)),
                        leading: CircleAvatar(
                          radius: r.sp(r.isTablet ? 22 : 18),
                          backgroundColor: widget.color,
                          child: Icon(Icons.groups, color: Colors.white, size: r.iconSize(20)),
                        ),
                        title: Text(e.key,
                            style: TextStyle(fontSize: r.fontSize(r.isTablet ? 17 : 15), fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${e.value.length} طالب${isNoHalqa ? '' : '  •  ${halqaDaysLabel(days)}'}',
                          style: TextStyle(fontSize: r.fontSize(12)),
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => widget.builder(
                                e.key, e.value, isNoHalqa ? <String>[] : [e.key], days),
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
