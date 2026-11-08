import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import '../utils/halqa_days.dart';
import '../utils/responsive.dart';

class AttendanceScreen extends StatefulWidget {
  final List<Student> students;
  final List<String> halqas;
  final String? halqaName;
  final List<String> halqaDays; // أيام دوام الحلقة (فارغة = كل الأيام)

  const AttendanceScreen({
    super.key,
    required this.students,
    required this.halqas,
    this.halqaName,
    this.halqaDays = const [],
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final SyncService _sync = SyncService();

  late DateTime _selectedDate;
  Map<String, String> _attendance = {};
  StreamSubscription<Map<String, String>>? _sub;
  bool _loading = true;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _selectedDate == _today();

  bool get _hasNext => nextHalqaDay(_selectedDate, widget.halqaDays, _today()) != null;

  @override
  void initState() {
    super.initState();
    // نبدأ بأحدث يوم دوام للحلقة (اليوم إن كان من أيامها)
    _selectedDate = latestHalqaDay(_today(), widget.halqaDays);
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
    final prev = prevHalqaDay(_selectedDate, widget.halqaDays);
    if (prev.year < 2024) return;
    setState(() => _selectedDate = prev);
    _listen();
  }

  void _goToNextDay() {
    final next = nextHalqaDay(_selectedDate, widget.halqaDays, _today());
    if (next == null) return;
    setState(() => _selectedDate = next);
    _listen();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: _today(),
      // لا يُسمح إلا بأيام دوام الحلقة
      selectableDayPredicate: (d) => isHalqaDay(d, widget.halqaDays),
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _listen();
    }
  }

  Future<void> _toggleAttendance(Student student) async {
    // التبديل: غائب ← حاضر ← غائب بإذن ← غائب
    final prev = _attendance[student.id] ?? AttendanceStatus.absent;
    final next = switch (prev) {
      AttendanceStatus.absent => AttendanceStatus.present,
      AttendanceStatus.present => AttendanceStatus.excused,
      _ => AttendanceStatus.absent,
    };
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
    final ids = widget.students.map((s) => s.id).toSet();
    final statuses = _attendance.entries.where((e) => ids.contains(e.key)).map((e) => e.value);
    final present = statuses.where((v) => v == AttendanceStatus.present).length;
    final excused = statuses.where((v) => v == AttendanceStatus.excused).length;
    final absent = total - present - excused;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.halqaName == null ? 'سجل الحضور' : 'الحضور - ${widget.halqaName}',
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
                          color: _hasNext ? Colors.white : Colors.white30,
                          size: r.iconSize(30)),
                      onPressed: _hasNext ? _goToNextDay : null,
                    ),
                  ],
                ),
                if (widget.halqaDays.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: r.sp(2)),
                    child: Text(
                      'أيام الحلقة: ${halqaDaysLabel(widget.halqaDays)}'
                      '${isHalqaDay(_today(), widget.halqaDays) ? '' : '  •  اليوم ليس من أيام الحلقة'}',
                      style: TextStyle(color: Colors.white70, fontSize: r.fontSize(11.5)),
                    ),
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
                        value: '$absent',
                        color: Colors.redAccent,
                        r: r),
                    _StatBadge(
                        icon: Icons.event_busy,
                        label: 'غائب بإذن',
                        value: '$excused',
                        color: Colors.amberAccent,
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
                      students.where((s) => _attendance[s.id] == AttendanceStatus.present).length;
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
  final Map<String, String> attendance;
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
              status: attendance[student.id] ?? AttendanceStatus.absent,
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
  final String status;
  final VoidCallback onToggle;
  final Responsive r;

  const _StudentRow({
    required this.student,
    required this.status,
    required this.onToggle,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final present = status == AttendanceStatus.present;
    final excused = status == AttendanceStatus.excused;
    final Color mainColor = present
        ? AppTheme.lightGreen
        : excused
            ? Colors.orange.shade600
            : Colors.grey.shade400;
    final String label = present ? 'حاضر' : (excused ? 'غائب بإذن' : 'غائب');
    final IconData icon = present
        ? Icons.check_circle
        : (excused ? Icons.event_busy : Icons.radio_button_unchecked);

    return Card(
      margin:
          EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(3)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.radius(10))),
      color: present
          ? Colors.green.shade50
          : excused
              ? Colors.orange.shade50
              : Colors.grey.shade50,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
            horizontal: r.sp(14), vertical: r.sp(2)),
        leading: CircleAvatar(
          radius: r.sp(20),
          backgroundColor: mainColor,
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
              color: mainColor,
              borderRadius: BorderRadius.circular(r.radius(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: r.iconSize(16)),
                SizedBox(width: r.sp(5)),
                Text(
                  label,
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
