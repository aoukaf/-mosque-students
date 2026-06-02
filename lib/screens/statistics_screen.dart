import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/app_theme.dart';
import '../utils/responsive.dart';

class StatisticsScreen extends StatelessWidget {
  final List<Student> students;

  const StatisticsScreen({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    if (students.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('الإحصائيات', style: TextStyle(fontSize: r.fontSize(18)))),
        body: const Center(child: Text('لا يوجد طلاب بعد')),
      );
    }

    final totalStudents = students.length;
    final totalParts = students.fold(0, (sum, s) => sum + s.partsCompleted);
    final totalStars = students.fold(0, (sum, s) => sum + s.stars);
    final avgParts = (totalParts / totalStudents).toStringAsFixed(1);
    final avgStars = (totalStars / totalStudents).toStringAsFixed(1);
    final completedQuran = students.where((s) => s.partsCompleted == 30).length;

    final Map<String, List<Student>> halqaMap = {};
    for (final s in students) {
      halqaMap.putIfAbsent(s.halqa, () => []).add(s);
    }

    final topByStars = [...students]..sort((a, b) => b.stars.compareTo(a.stars));
    final top5 = topByStars.take(5).toList();
    final topByParts = [...students]..sort((a, b) => b.partsCompleted.compareTo(a.partsCompleted));
    final top5Parts = topByParts.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('الإحصائيات', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17))),
        toolbarHeight: r.isTablet ? 64 : 56,
      ),
      body: SingleChildScrollView(
        padding: r.pagePadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'ملخص عام', r: r),
                SizedBox(height: r.sp(10)),

                // Summary grid - responsive columns
                GridView.count(
                  crossAxisCount: r.gridColumns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: r.sp(10),
                  mainAxisSpacing: r.sp(10),
                  childAspectRatio: r.gridAspectRatio,
                  children: [
                    _SummaryCard(icon: Icons.people, value: '$totalStudents', label: 'إجمالي الطلاب', color: AppTheme.primaryGreen, r: r),
                    _SummaryCard(icon: Icons.emoji_events, value: '$completedQuran', label: 'أتموا الحفظ', color: const Color(0xFF7B1FA2), r: r),
                    _SummaryCard(icon: Icons.menu_book, value: avgParts, label: 'متوسط الأجزاء', color: AppTheme.lightGreen, r: r),
                    _SummaryCard(icon: Icons.star, value: avgStars, label: 'متوسط النجوم', color: AppTheme.accentGold, r: r),
                    _SummaryCard(icon: Icons.library_books, value: '$totalParts', label: 'مجموع الأجزاء', color: Colors.teal, r: r),
                    _SummaryCard(icon: Icons.stars, value: '$totalStars', label: 'مجموع النجوم', color: Colors.orange, r: r),
                  ],
                ),
                SizedBox(height: r.sp(20)),

                // Halqa breakdown
                _SectionHeader(title: 'إحصائيات الحلقات', r: r),
                SizedBox(height: r.sp(10)),
                ...halqaMap.entries.map((e) {
                  final halqaStudents = e.value;
                  final halqaStars = halqaStudents.fold(0, (s, st) => s + st.stars);
                  final halqaParts = halqaStudents.fold(0, (s, st) => s + st.partsCompleted);
                  return Card(
                    margin: EdgeInsets.only(bottom: r.sp(10)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
                    child: Padding(
                      padding: r.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: TextStyle(fontSize: r.fontSize(15), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: r.sp(10), vertical: r.sp(4)),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(r.radius(12)),
                                ),
                                child: Text(
                                  '${halqaStudents.length} طالب',
                                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: r.fontSize(13)),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.sp(8)),
                          Wrap(
                            spacing: r.sp(16),
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.menu_book, size: r.iconSize(15), color: AppTheme.lightGreen),
                                SizedBox(width: r.sp(5)),
                                Text('مجموع الأجزاء: $halqaParts', style: TextStyle(fontSize: r.fontSize(13))),
                              ]),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.star, size: r.iconSize(15), color: AppTheme.accentGold),
                                SizedBox(width: r.sp(5)),
                                Text('النجوم: $halqaStars', style: TextStyle(fontSize: r.fontSize(13))),
                              ]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: r.sp(20)),

                // Top lists - on tablet show side by side
                if (r.isTablet)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _TopSection(title: '🏆 أعلى 5 بالنجوم', students: top5, valueBuilder: (s) => '⭐ ${s.stars}', color: AppTheme.accentGold, r: r)),
                      SizedBox(width: r.sp(16)),
                      Expanded(child: _TopSection(title: '📖 أعلى 5 بالأجزاء', students: top5Parts, valueBuilder: (s) => '${s.partsCompleted}/30', color: AppTheme.lightGreen, r: r)),
                    ],
                  )
                else ...[
                  _TopSection(title: '🏆 أعلى 5 طلاب بالنجوم', students: top5, valueBuilder: (s) => '⭐ ${s.stars}', color: AppTheme.accentGold, r: r),
                  SizedBox(height: r.sp(20)),
                  _TopSection(title: '📖 أعلى 5 طلاب بالأجزاء', students: top5Parts, valueBuilder: (s) => '${s.partsCompleted}/30 جزء', color: AppTheme.lightGreen, r: r),
                ],
                SizedBox(height: r.sp(20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Responsive r;
  const _SectionHeader({required this.title, required this.r});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  final Responsive r;
  const _SummaryCard({required this.icon, required this.value, required this.label, required this.color, required this.r});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: Padding(
        padding: EdgeInsets.all(r.sp(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: r.iconSize(r.isTablet ? 32 : 26)),
            SizedBox(height: r.sp(4)),
            Text(value, style: TextStyle(fontSize: r.fontSize(r.isTablet ? 26 : 20), fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: r.fontSize(r.isTablet ? 13 : 11)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TopSection extends StatelessWidget {
  final String title;
  final List<Student> students;
  final String Function(Student) valueBuilder;
  final Color color;
  final Responsive r;
  const _TopSection({required this.title, required this.students, required this.valueBuilder, required this.color, required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, r: r),
        SizedBox(height: r.sp(8)),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
          child: Column(
            children: students.asMap().entries.map((e) {
              final idx = e.key;
              final student = e.value;
              final medalColor = idx == 0
                  ? const Color(0xFFFFD700)
                  : idx == 1 ? const Color(0xFFC0C0C0)
                  : idx == 2 ? const Color(0xFFCD7F32)
                  : AppTheme.lightGreen;
              return ListTile(
                dense: r.isSmallPhone,
                leading: CircleAvatar(
                  radius: r.sp(r.isTablet ? 20 : 16),
                  backgroundColor: medalColor,
                  child: Text('${idx + 1}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(13))),
                ),
                title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(r.isTablet ? 15 : 13))),
                subtitle: Text(student.halqa, style: TextStyle(fontSize: r.fontSize(11))),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: r.sp(8), vertical: r.sp(4)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.radius(10)),
                  ),
                  child: Text(valueBuilder(student), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: r.fontSize(12))),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
