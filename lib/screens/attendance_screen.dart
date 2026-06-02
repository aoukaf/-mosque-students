import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import '../utils/responsive.dart';

class AttendanceScreen extends StatefulWidget {
  final List<Student> students;
  final List<String> halqas;

  const AttendanceScreen({
    super.key,
    required this.students,
    required this.halqas,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final SyncService _sync = SyncService();

  DateTime _selectedDate = _today();
  Map<String, bool> _attendance = {};
  StreamSubscription<Map<String, bool>>? _sub;
  bool _loading = true;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _selectedDate == _today();

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub?.cancel();
    if (mounted) setState(() => _loading = true);
    _sub = _sync.watchAttendance(_selectedDate).listen(
      (data) {
        if (mounted) setState(() { _attendance = data; _loading = false; });
      },
      onError: (_) async {
        final data = await _sync.getAttendance(_selectedDate);
        if (mounted) setState(() { _attendance = data; _loading = false; });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _goToPrevDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _listen();
  }

  void _goToNextDay() {
    if (_isToday) return;
    final next = _selectedDate.add(const Duration(days: 1));
    if (!next.isAfter(_today())) {
      setState(() => _selectedDate = next);
      _listen();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: _today(),
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _listen();
    }
  }

  Future<void> _toggleAttendance(Student student) async {
    final prev = _attendance[student.id] ?? false;
    final next = !prev;
    setState(() => _attendance[student.id] = next);
    try {
      await _sync.setAttendance(
          _selectedDate, student.id, student.name, student.halqa, next);
    } catch (_) {
      if (mounted) setState(() => _attendance[student.id] = prev);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Map<String, List<Student>> _groupByHalqa() {
    final Map<String, List<Student>> result = {};
    for (final h in widget.halqas) {
      final list = widget.students.where((s) => s.halqa == h).toList();
      if (list.isNotEmpty) result[h] = list;
    }
    final others = widget.students
        .where((s) => s.halqa.isEmpty || !widget.halqas.contains(s.halqa))
        .toList();
    if (others.isNotEmpty) result['بدون حلقة'] = others;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final grouped = _groupByHalqa();
    final total = widget.students.length;
    final present = _attendance.values.where((v) => v).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('سجل الحضور',
            style: TextStyle(
                fontSize: r.fontSize(r.isTablet ? 20 : 17),
                fontWeight: FontWeight.bold)),
        toolbarHeight: r.isTablet ? 64 : 56,
      ),
      body: Column(
        children: [
          // ===== شريط التاريخ والإحصاء =====
          Container(
            color: AppTheme.primaryGreen,
            padding: EdgeInsets.fromLTRB(r.sp(8), r.sp(10), r.sp(8), r.sp(14)),
            child: Column(
              children: [
                // التنقل بين الأيام
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_right,
                          color: Colors.white, size: r.iconSize(30)),
                      onPressed: _goToPrevDay,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Column(
                          children: [
                            if (_isToday)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.sp(10), vertical: r.sp(2)),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(r.radius(12)),
                                ),
                                child: Text('اليوم',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: r.fontSize(11))),
                              ),
                            SizedBox(height: r.sp(2)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today,
                                    color: Colors.white70, size: r.iconSize(16)),
                                SizedBox(width: r.sp(6)),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fontSize(17),
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: _isToday ? Colors.white30 : Colors.white,
                          size: r.iconSize(30)),
                      onPressed: _isToday ? null : _goToNextDay,
                    ),
                  ],
                ),
                SizedBox(height: r.sp(10)),
                // إحصاء الحضور
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatBadge(
                        icon: Icons.check_circle_outline,
                        label: 'حاضر',
                        value: '$present',
                        color: Colors.greenAccent,
                        r: r),
                    _StatBadge(
                        icon: Icons.cancel_outlined,
                        label: 'غائب',
                        value: '${total - present}',
                        color: Colors.redAccent,
                        r: r),
                    _StatBadge(
                        icon: Icons.people_outline,
                        label: 'المجموع',
                        value: '$total',
                        color: Colors.white70,
                        r: r),
                  ],
                ),
              ],
            ),
          ),

          // ===== قائمة الطلاب =====
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (grouped.isEmpty)
            Expanded(
              child: Center(
                child: Text('لا يوجد طلاب',
                    style: TextStyle(
                        fontSize: r.fontSize(15), color: Colors.grey[600])),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: r.sp(20), top: r.sp(4)),
                itemCount: grouped.length,
                itemBuilder: (ctx, i) {
                  final halqa = grouped.keys.elementAt(i);
                  final students = grouped[halqa]!;
                  final halqaPresent =
                      students.where((s) => _attendance[s.id] == true).length;
                  return _HalqaSection(
                    halqa: halqa,
                    students: students,
                    attendance: _attendance,
                    presentCount: halqaPresent,
                    onToggle: _toggleAttendance,
                    r: r,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ===== شارة إحصاء =====
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final Responsive r;
  const _StatBadge(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: r.iconSize(18)),
            SizedBox(width: r.sp(4)),
            Text(value,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: r.fontSize(20))),
          ],
        ),
        Text(label,
            style:
                TextStyle(color: Colors.white70, fontSize: r.fontSize(11))),
      ],
    );
  }
}

// ===== قسم الحلقة =====
class _HalqaSection extends StatelessWidget {
  final String halqa;
  final List<Student> students;
  final Map<String, bool> attendance;
  final int presentCount;
  final Future<void> Function(Student) onToggle;
  final Responsive r;

  const _HalqaSection({
    required this.halqa,
    required this.students,
    required this.attendance,
    required this.presentCount,
    required this.onToggle,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // رأس الحلقة
        Container(
          margin: EdgeInsets.fromLTRB(r.sp(12), r.sp(12), r.sp(12), r.sp(4)),
          padding:
              EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(8)),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(r.radius(10)),
            border:
                Border.all(color: AppTheme.lightGreen.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.groups,
                  color: AppTheme.primaryGreen, size: r.iconSize(20)),
              SizedBox(width: r.sp(8)),
              Text(halqa,
                  style: TextStyle(
                      fontSize: r.fontSize(15),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen)),
              const Spacer(),
              Text('$presentCount / ${students.length}',
                  style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: r.fontSize(13))),
            ],
          ),
        ),
        // الطلاب
        ...students.map((student) => _StudentRow(
              student: student,
              present: attendance[student.id] ?? false,
              onToggle: () => onToggle(student),
              r: r,
            )),
      ],
    );
  }
}

// ===== صف الطالب =====
class _StudentRow extends StatelessWidget {
  final Student student;
  final bool present;
  final VoidCallback onToggle;
  final Responsive r;

  const _StudentRow({
    required this.student,
    required this.present,
    required this.onToggle,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(3)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.radius(10))),
      color: present ? Colors.green.shade50 : Colors.grey.shade50,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
            horizontal: r.sp(14), vertical: r.sp(2)),
        leading: CircleAvatar(
          radius: r.sp(20),
          backgroundColor:
              present ? AppTheme.lightGreen : Colors.grey[350],
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '؟',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: r.fontSize(14)),
          ),
        ),
        title: Text(student.name,
            style: TextStyle(
                fontSize: r.fontSize(14), fontWeight: FontWeight.w600)),
        trailing: GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
                horizontal: r.sp(14), vertical: r.sp(7)),
            decoration: BoxDecoration(
              color: present ? AppTheme.lightGreen : Colors.grey[400],
              borderRadius: BorderRadius.circular(r.radius(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    present ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: r.iconSize(16)),
                SizedBox(width: r.sp(5)),
                Text(
                  present ? 'حاضر' : 'غائب',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: r.fontSize(13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
