import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import '../utils/responsive.dart';

class StudentDetailScreen extends StatelessWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('بيانات الطالب', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17))),
        toolbarHeight: r.isTablet ? 64 : 56,
      ),
      body: StreamBuilder<Student?>(
        stream: SyncService().watchStudent(student.id),
        initialData: student,
        builder: (context, snapshot) {
          final s = snapshot.data ?? student;
          final progress = s.partsCompleted / 30;
          final starsPercent = (s.stars / 5000 * 100).clamp(0.0, 100.0).toStringAsFixed(1);
          return r.isTablet
              ? _TabletDetail(student: s, r: r, progress: progress, starsPercent: starsPercent)
              : _PhoneDetail(student: s, r: r, progress: progress, starsPercent: starsPercent);
        },
      ),
    );
  }
}

// ===== Phone Detail =====
class _PhoneDetail extends StatelessWidget {
  final Student student;
  final Responsive r;
  final double progress;
  final String starsPercent;

  const _PhoneDetail({required this.student, required this.r, required this.progress, required this.starsPercent});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: r.pagePadding,
      children: [
        _HeaderCard(student: student, r: r),
        SizedBox(height: r.sp(14)),
        Row(
          children: [
            Expanded(child: _StatCard(icon: Icons.menu_book, value: '${student.partsCompleted}', label: 'جزء مكتمل', subLabel: 'من 30', color: AppTheme.lightGreen, r: r)),
            SizedBox(width: r.sp(12)),
            Expanded(child: _StatCard(icon: Icons.star, value: '${student.stars}', label: 'نجمة', subLabel: 'من 5000', color: AppTheme.accentGold, r: r)),
          ],
        ),
        SizedBox(height: r.sp(14)),
        _QuranProgressCard(student: student, r: r, progress: progress),
        SizedBox(height: r.sp(14)),
        _StarsProgressCard(student: student, r: r, starsPercent: starsPercent),
        if (student.notes.isNotEmpty) ...[
          SizedBox(height: r.sp(14)),
          _NotesCard(student: student, r: r),
        ],
        SizedBox(height: r.sp(14)),
        _DatesCard(student: student, r: r),
        SizedBox(height: r.sp(20)),
      ],
    );
  }
}

// ===== Tablet Detail =====
class _TabletDetail extends StatelessWidget {
  final Student student;
  final Responsive r;
  final double progress;
  final String starsPercent;

  const _TabletDetail({required this.student, required this.r, required this.progress, required this.starsPercent});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.sp(24)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _HeaderCard(student: student, r: r),
              SizedBox(height: r.sp(16)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _StatCard(icon: Icons.menu_book, value: '${student.partsCompleted}', label: 'جزء مكتمل', subLabel: 'من 30', color: AppTheme.lightGreen, r: r)),
                            SizedBox(width: r.sp(12)),
                            Expanded(child: _StatCard(icon: Icons.star, value: '${student.stars}', label: 'نجمة', subLabel: 'من 5000', color: AppTheme.accentGold, r: r)),
                          ],
                        ),
                        SizedBox(height: r.sp(14)),
                        _StarsProgressCard(student: student, r: r, starsPercent: starsPercent),
                        if (student.notes.isNotEmpty) ...[
                          SizedBox(height: r.sp(14)),
                          _NotesCard(student: student, r: r),
                        ],
                        SizedBox(height: r.sp(14)),
                        _DatesCard(student: student, r: r),
                      ],
                    ),
                  ),
                  SizedBox(width: r.sp(16)),
                  Expanded(child: _QuranProgressCard(student: student, r: r, progress: progress)),
                ],
              ),
              SizedBox(height: r.sp(20)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Shared Cards =====

class _HeaderCard extends StatelessWidget {
  final Student student;
  final Responsive r;
  const _HeaderCard({required this.student, required this.r});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: Padding(
        padding: r.cardPadding,
        child: Column(
          children: [
            CircleAvatar(
              radius: r.sp(r.isTablet ? 48 : 36),
              backgroundColor: AppTheme.primaryGreen,
              child: Text(
                student.name.isNotEmpty ? student.name[0] : '؟',
                style: TextStyle(color: Colors.white, fontSize: r.fontSize(r.isTablet ? 40 : 30), fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: r.sp(12)),
            Text(
              student.name,
              style: TextStyle(fontSize: r.fontSize(r.isTablet ? 26 : 22), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.sp(6)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(6)),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.radius(20)),
              ),
              child: Text(
                student.halqa,
                style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: r.fontSize(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label, subLabel;
  final Color color;
  final Responsive r;
  const _StatCard({required this.icon, required this.value, required this.label, required this.subLabel, required this.color, required this.r});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: Padding(
        padding: r.cardPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: r.iconSize(r.isTablet ? 36 : 28)),
            SizedBox(height: r.sp(6)),
            Text(value, style: TextStyle(fontSize: r.fontSize(r.isTablet ? 32 : 26), fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
            Text(subLabel, style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(11))),
          ],
        ),
      ),
    );
  }
}

class _QuranProgressCard extends StatelessWidget {
  final Student student;
  final Responsive r;
  final double progress;
  const _QuranProgressCard({required this.student, required this.r, required this.progress});

  @override
  Widget build(BuildContext context) {
    // حساب عدد الأعمدة حسب الشاشة
    final cols = r.isTablet ? 6 : (r.isLargePhone ? 5 : 5);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: Padding(
        padding: r.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: AppTheme.primaryGreen, size: r.iconSize(22)),
                SizedBox(width: r.sp(8)),
                Text('تقدم حفظ القرآن', style: TextStyle(fontSize: r.fontSize(15), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ],
            ),
            SizedBox(height: r.sp(14)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${student.partsCompleted} / 30 جزء', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold)),
                Text('${(progress * 100).round()}%', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold, color: AppTheme.lightGreen)),
              ],
            ),
            SizedBox(height: r.sp(8)),
            ClipRRect(
              borderRadius: BorderRadius.circular(r.radius(10)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: r.sp(14),
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(AppTheme.lightGreen),
              ),
            ),
            SizedBox(height: r.sp(14)),
            // Parts grid - responsive columns
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: r.sp(4),
                mainAxisSpacing: r.sp(4),
                childAspectRatio: 1,
              ),
              itemCount: 30,
              itemBuilder: (_, i) {
                final completed = i < student.partsCompleted;
                return Container(
                  decoration: BoxDecoration(
                    color: completed ? AppTheme.lightGreen : Colors.grey[200],
                    borderRadius: BorderRadius.circular(r.radius(6)),
                    border: Border.all(color: completed ? AppTheme.primaryGreen : Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: r.fontSize(r.isTablet ? 13 : 11),
                        fontWeight: FontWeight.bold,
                        color: completed ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StarsProgressCard extends StatelessWidget {
  final Student student;
  final Responsive r;
  final String starsPercent;
  const _StarsProgressCard({required this.student, required this.r, required this.starsPercent});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: Padding(
        padding: r.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: AppTheme.accentGold, size: r.iconSize(22)),
                SizedBox(width: r.sp(8)),
                Text('النجوم المكتسبة', style: TextStyle(fontSize: r.fontSize(15), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ],
            ),
            SizedBox(height: r.sp(14)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: AppTheme.goldStar, size: r.iconSize(r.isTablet ? 36 : 28)),
                    SizedBox(width: r.sp(6)),
                    Text('${student.stars}', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 36 : 28), fontWeight: FontWeight.bold, color: AppTheme.accentGold)),
                  ],
                ),
                Text('$starsPercent% من الهدف', style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(12))),
              ],
            ),
            SizedBox(height: r.sp(8)),
            ClipRRect(
              borderRadius: BorderRadius.circular(r.radius(10)),
              child: LinearProgressIndicator(
                value: student.stars / 5000,
                minHeight: r.sp(14),
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(AppTheme.goldStar),
              ),
            ),
            SizedBox(height: r.sp(6)),
            Text('من 5000 نجمة', style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(11))),
          ],
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final Student student;
  final Responsive r;
  const _NotesCard({required this.student, required this.r});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: Padding(
        padding: r.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, color: AppTheme.primaryGreen, size: r.iconSize(22)),
                SizedBox(width: r.sp(8)),
                Text('ملاحظات', style: TextStyle(fontSize: r.fontSize(15), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ],
            ),
            SizedBox(height: r.sp(10)),
            Text(student.notes, style: TextStyle(fontSize: r.fontSize(14)), textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );
  }
}

class _DatesCard extends StatelessWidget {
  final Student student;
  final Responsive r;
  const _DatesCard({required this.student, required this.r});

  String _fmt(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: Padding(
        padding: r.cardPadding,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.calendar_today, size: r.iconSize(16), color: AppTheme.primaryGreen),
                  SizedBox(width: r.sp(6)),
                  Text('تاريخ الإضافة', style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
                ]),
                Text(_fmt(student.createdAt), style: TextStyle(color: Colors.grey[700], fontSize: r.fontSize(13))),
              ],
            ),
            Divider(height: r.sp(16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.update, size: r.iconSize(16), color: AppTheme.primaryGreen),
                  SizedBox(width: r.sp(6)),
                  Text('آخر تحديث', style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
                ]),
                Text(_fmt(student.updatedAt), style: TextStyle(color: Colors.grey[700], fontSize: r.fontSize(13))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
