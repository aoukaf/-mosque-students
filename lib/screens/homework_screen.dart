import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import '../utils/responsive.dart';

class HomeworkScreen extends StatefulWidget {
  final List<Student> students;
  final List<String> halqas;
  const HomeworkScreen({super.key, required this.students, required this.halqas});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  final _sync = SyncService();
  DateTime _selectedDate = _today();
  Map<String, HomeworkRecord> _homework = {};
  StreamSubscription<Map<String, HomeworkRecord>>? _sub;
  bool _loading = true;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _selectedDate == _today();

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    _sub?.cancel();
    if (mounted) setState(() => _loading = true);
    _sub = _sync.watchHomework(_selectedDate).listen(
      (data) { if (mounted) setState(() { _homework = data; _loading = false; }); },
      onError: (_) async {
        final data = await _sync.getHomework(_selectedDate);
        if (mounted) setState(() { _homework = data; _loading = false; });
      },
    );
  }

  void _prevDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _listen();
  }

  void _nextDay() {
    final next = _selectedDate.add(const Duration(days: 1));
    if (!next.isAfter(_today())) { setState(() => _selectedDate = next); _listen(); }
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

  // تسجيل الوظيفة: إذا ما جاب → dialog لإدخال السورة، إذا جاب → إلغاء
  Future<void> _toggle(Student student) async {
    final prev = _homework[student.id];
    final wasBrought = prev?.brought ?? false;

    if (wasBrought) {
      // إلغاء التسجيل
      const rec = HomeworkRecord(brought: false, surah: '');
      setState(() => _homework[student.id] = rec);
      try {
        await _sync.setHomework(_selectedDate, student.id, student.name, student.halqa, false, '');
      } catch (_) {
        if (mounted) setState(() => _homework[student.id] = prev ?? const HomeworkRecord(brought: false, surah: ''));
      }
    } else {
      // طلب إدخال السورة
      final surah = await _showSurahDialog(student.name, prev?.surah ?? '');
      if (surah == null || !mounted) return;
      final rec = HomeworkRecord(brought: true, surah: surah);
      setState(() => _homework[student.id] = rec);
      try {
        await _sync.setHomework(_selectedDate, student.id, student.name, student.halqa, true, surah);
      } catch (_) {
        if (mounted) setState(() => _homework[student.id] = prev ?? const HomeworkRecord(brought: false, surah: ''));
      }
    }
  }

  // تعديل السورة للطالب الذي سجّل مسبقاً
  Future<void> _editSurah(Student student) async {
    final prev = _homework[student.id];
    if (prev == null || !prev.brought) return;
    final surah = await _showSurahDialog(student.name, prev.surah);
    if (surah == null || !mounted) return;
    final rec = HomeworkRecord(brought: true, surah: surah);
    setState(() => _homework[student.id] = rec);
    try {
      await _sync.setHomework(_selectedDate, student.id, student.name, student.halqa, true, surah);
    } catch (_) {
      if (mounted) setState(() => _homework[student.id] = prev);
    }
  }

  Future<String?> _showSurahDialog(String studentName, String currentSurah) async {
    final ctrl = TextEditingController(text: currentSurah);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تسجيل الوظيفة', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(studentName, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('السورة / عدد الصفحات', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                textDirection: TextDirection.rtl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'مثال: سورة البقرة | 3 صفحات',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return result;
  }

  String _formatDate(DateTime d) {
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Map<String, List<Student>> _grouped() {
    final Map<String, List<Student>> res = {};
    for (final h in widget.halqas) {
      final list = widget.students.where((s) => s.halqa == h).toList();
      if (list.isNotEmpty) res[h] = list;
    }
    final others = widget.students.where((s) => s.halqa.isEmpty || !widget.halqas.contains(s.halqa)).toList();
    if (others.isNotEmpty) res['بدون حلقة'] = others;
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final grouped = _grouped();
    final total = widget.students.length;
    final brought = _homework.values.where((v) => v.brought).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('سجل الوظائف', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold)),
        toolbarHeight: r.isTablet ? 64 : 56,
        backgroundColor: const Color(0xFF5C4A8F),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ─── شريط التاريخ والإحصاء ───
          Container(
            color: const Color(0xFF5C4A8F),
            padding: EdgeInsets.fromLTRB(r.sp(8), r.sp(10), r.sp(8), r.sp(14)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: Colors.white, size: r.iconSize(30)),
                      onPressed: _prevDay,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Column(
                          children: [
                            if (_isToday)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: r.sp(10), vertical: r.sp(2)),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                                child: Text('اليوم', style: TextStyle(color: Colors.white70, fontSize: r.fontSize(11))),
                              ),
                            SizedBox(height: r.sp(2)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today, color: Colors.white70, size: r.iconSize(16)),
                                SizedBox(width: r.sp(6)),
                                Text(_formatDate(_selectedDate),
                                    style: TextStyle(color: Colors.white, fontSize: r.fontSize(17), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: _isToday ? Colors.white30 : Colors.white, size: r.iconSize(30)),
                      onPressed: _isToday ? null : _nextDay,
                    ),
                  ],
                ),
                SizedBox(height: r.sp(10)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatBadge(icon: Icons.check_circle_outline, label: 'جاب', value: '$brought', color: Colors.greenAccent, r: r),
                    _StatBadge(icon: Icons.cancel_outlined, label: 'ما جاب', value: '${total - brought}', color: Colors.redAccent, r: r),
                    _StatBadge(icon: Icons.people_outline, label: 'المجموع', value: '$total', color: Colors.white70, r: r),
                  ],
                ),
              ],
            ),
          ),

          // ─── القائمة ───
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (grouped.isEmpty)
            Expanded(child: Center(child: Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(15)))))
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: r.sp(20), top: r.sp(4)),
                itemCount: grouped.length,
                itemBuilder: (ctx, i) {
                  final halqa = grouped.keys.elementAt(i);
                  final students = grouped[halqa]!;
                  final halqaBrought = students.where((s) => _homework[s.id]?.brought == true).length;
                  return _HalqaSection(
                    halqa: halqa,
                    students: students,
                    homework: _homework,
                    broughtCount: halqaBrought,
                    onToggle: _toggle,
                    onEditSurah: _editSurah,
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

// ───────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final Responsive r;
  const _StatBadge({required this.icon, required this.label, required this.value, required this.color, required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: r.iconSize(18)),
          SizedBox(width: r.sp(4)),
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(20))),
        ]),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: r.fontSize(11))),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────

class _HalqaSection extends StatelessWidget {
  final String halqa;
  final List<Student> students;
  final Map<String, HomeworkRecord> homework;
  final int broughtCount;
  final Future<void> Function(Student) onToggle;
  final Future<void> Function(Student) onEditSurah;
  final Responsive r;

  const _HalqaSection({
    required this.halqa, required this.students, required this.homework,
    required this.broughtCount, required this.onToggle, required this.onEditSurah, required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(r.sp(12), r.sp(12), r.sp(12), r.sp(4)),
          padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(8)),
          decoration: BoxDecoration(
            color: const Color(0xFF5C4A8F).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.radius(10)),
            border: Border.all(color: const Color(0xFF5C4A8F).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.groups, color: const Color(0xFF5C4A8F), size: r.iconSize(20)),
              SizedBox(width: r.sp(8)),
              Text(halqa, style: TextStyle(fontSize: r.fontSize(15), fontWeight: FontWeight.bold, color: const Color(0xFF5C4A8F))),
              const Spacer(),
              Text('$broughtCount / ${students.length}',
                  style: TextStyle(color: const Color(0xFF5C4A8F), fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
            ],
          ),
        ),
        ...students.map((s) => _StudentRow(
              student: s,
              record: homework[s.id],
              onToggle: () => onToggle(s),
              onEditSurah: () => onEditSurah(s),
              r: r,
            )),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────

class _StudentRow extends StatelessWidget {
  final Student student;
  final HomeworkRecord? record;
  final VoidCallback onToggle;
  final VoidCallback onEditSurah;
  final Responsive r;

  const _StudentRow({required this.student, required this.record, required this.onToggle, required this.onEditSurah, required this.r});

  @override
  Widget build(BuildContext context) {
    final brought = record?.brought ?? false;
    final surah = record?.surah ?? '';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.radius(10))),
      color: brought ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(8)),
        child: Row(
          children: [
            // أيقونة الطالب
            CircleAvatar(
              radius: r.sp(20),
              backgroundColor: brought ? AppTheme.lightGreen : Colors.grey[350],
              child: Text(
                student.name.isNotEmpty ? student.name[0] : '؟',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(14)),
              ),
            ),
            SizedBox(width: r.sp(12)),

            // الاسم + السورة
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: TextStyle(fontSize: r.fontSize(14), fontWeight: FontWeight.w600)),
                  if (brought && surah.isNotEmpty)
                    GestureDetector(
                      onTap: onEditSurah,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book, size: r.iconSize(13), color: AppTheme.primaryGreen),
                          SizedBox(width: r.sp(4)),
                          Text(surah,
                              style: TextStyle(fontSize: r.fontSize(12), color: AppTheme.primaryGreen, fontWeight: FontWeight.w500)),
                          SizedBox(width: r.sp(4)),
                          Icon(Icons.edit, size: r.iconSize(11), color: Colors.grey.shade400),
                        ],
                      ),
                    )
                  else if (brought)
                    GestureDetector(
                      onTap: onEditSurah,
                      child: Text('اضغط لإضافة السورة',
                          style: TextStyle(fontSize: r.fontSize(11), color: Colors.grey.shade400)),
                    ),
                ],
              ),
            ),

            // زر التسجيل
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(8)),
                decoration: BoxDecoration(
                  color: brought ? AppTheme.lightGreen : Colors.grey[400],
                  borderRadius: BorderRadius.circular(r.radius(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(brought ? Icons.check_circle : Icons.close, color: Colors.white, size: r.iconSize(16)),
                    SizedBox(width: r.sp(5)),
                    Text(
                      brought ? 'جاب' : 'ما جاب',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
