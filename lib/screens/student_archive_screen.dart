import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../models/sync_service.dart';
import '../utils/responsive.dart';

/// أرشيف طالب واحد: سجل الحضور وسجل الحفظ (الوظائف والسور) شهراً بشهر.
/// يُحمَّل شهر واحد عند الطلب (قراءتان لكل يوم) ويُخزَّن مؤقتاً أثناء بقاء الشاشة.
class StudentArchiveScreen extends StatefulWidget {
  final String mosqueId;
  final String studentId;
  final String studentName;

  const StudentArchiveScreen({
    super.key,
    required this.mosqueId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentArchiveScreen> createState() => _StudentArchiveScreenState();
}

class _StudentArchiveScreenState extends State<StudentArchiveScreen> {
  final _sync = SyncService();
  static final _firstMonth = DateTime(2024, 1);
  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];
  static const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  late DateTime _month = _thisMonth();
  final Map<String, List<ParentDayRecord>> _cache = {};
  final Map<String, int> _failures = {};
  bool _loading = true;

  static DateTime _thisMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  String _key(DateTime m) => '${m.year}-${m.month}';
  bool get _isCurrentMonth => _month == _thisMonth();
  bool get _isFirstMonth => !_month.isAfter(_firstMonth);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final month = _month;
    final key = _key(month);
    if (!force && _cache.containsKey(key)) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final today = DateTime.now();
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.isAfter(today) ? DateTime(today.year, today.month, today.day) : last;
    final res = await _sync.getStudentHistoryRange(widget.mosqueId, widget.studentId, month, end);
    if (!mounted) return;
    setState(() {
      _cache[key] = res.records;
      _failures[key] = res.failures;
      if (key == _key(_month)) _loading = false;
    });
  }

  void _goTo(DateTime month) {
    setState(() => _month = month);
    _load();
  }

  String _fmtDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}/${d.month}';

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final key = _key(_month);
    final records = _cache[key] ?? const <ParentDayRecord>[];
    final failures = _failures[key] ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: r.isTablet ? 64 : 56,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('أرشيف الطالب', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 19 : 16), fontWeight: FontWeight.bold)),
              Text(widget.studentName, style: TextStyle(fontSize: r.fontSize(12), color: Colors.white70)),
            ],
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'الحضور'), Tab(text: 'الحفظ والوظائف')],
          ),
        ),
        body: Column(
          children: [
            _monthBar(r),
            if (failures > 0)
              Container(
                width: double.infinity,
                color: Colors.amber.shade100,
                padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(8)),
                child: Text('تعذّر تحميل بعض الأيام ($failures). تأكد من الاتصال واسحب للأسفل للتحديث.',
                    style: TextStyle(fontSize: r.fontSize(12), color: Colors.amber.shade900)),
              ),
            Expanded(
              child: _loading && !_cache.containsKey(key)
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _attendanceTab(r, records),
                        _homeworkTab(r, records),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthBar(Responsive r) {
    return Container(
      color: AppTheme.primaryGreen,
      padding: EdgeInsets.fromLTRB(r.sp(8), 0, r.sp(8), r.sp(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_right, size: r.iconSize(28), color: _isFirstMonth ? Colors.white30 : Colors.white),
            onPressed: _isFirstMonth ? null : () => _goTo(DateTime(_month.year, _month.month - 1)),
          ),
          Expanded(
            child: Text('${_months[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: r.fontSize(17), fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: Icon(Icons.chevron_left, size: r.iconSize(28), color: _isCurrentMonth ? Colors.white30 : Colors.white),
            onPressed: _isCurrentMonth ? null : () => _goTo(DateTime(_month.year, _month.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _card(Responsive r, Widget child) => Card(
        margin: EdgeInsets.only(bottom: r.sp(10)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
        child: Padding(padding: r.cardPadding, child: child),
      );

  Widget _count(Responsive r, String value, String label, Color color) => Column(
        children: [
          Text(value, style: TextStyle(fontSize: r.fontSize(22), fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: r.fontSize(12), color: Colors.grey[700])),
        ],
      );

  Widget _empty(Responsive r, String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: r.sp(30)),
        child: Center(child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(14)))),
      );

  Widget _scrollable(Responsive r, List<Widget> children) => RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.isTablet ? 700 : double.infinity),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: r.pagePadding,
              children: children,
            ),
          ),
        ),
      );

  // ───────── تبويب الحضور ─────────

  Widget _attendanceTab(Responsive r, List<ParentDayRecord> all) {
    final records = all.where((h) => h.attendance != null).toList();
    final present = records.where((h) => h.attendance == AttendanceStatus.present).length;
    final excused = records.where((h) => h.attendance == AttendanceStatus.excused).length;
    final absent = records.length - present - excused;
    final pct = records.isEmpty ? 0 : (present / records.length * 100).round();

    return _scrollable(r, [
      _card(
        r,
        records.isEmpty
            ? Text('لا توجد سجلات حضور بهذا الشهر', style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(13)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _count(r, '$present', 'حاضر', AppTheme.lightGreen),
                      _count(r, '$absent', 'غائب', Colors.red.shade400),
                      _count(r, '$excused', 'غائب بإذن', Colors.orange.shade600),
                    ],
                  ),
                  SizedBox(height: r.sp(10)),
                  Text('نسبة الحضور: $pct% من ${records.length} يوماً مسجّلاً',
                      style: TextStyle(fontSize: r.fontSize(13), fontWeight: FontWeight.w600)),
                  SizedBox(height: r.sp(4)),
                  Text('الأيام التي لم يُسجَّل فيها حضور لا تظهر هنا.',
                      style: TextStyle(fontSize: r.fontSize(11), color: Colors.grey[600])),
                ],
              ),
      ),
      if (records.isNotEmpty)
        _card(
          r,
          Column(
            children: [
              for (final h in records) ...[
                _attendanceRow(r, h),
                if (h != records.last) Divider(height: r.sp(14)),
              ],
            ],
          ),
        )
      else
        _empty(r, 'لا يوجد أرشيف حضور'),
    ]);
  }

  Widget _attendanceRow(Responsive r, ParentDayRecord h) {
    final (label, color) = switch (h.attendance) {
      AttendanceStatus.present => ('حاضر', AppTheme.lightGreen),
      AttendanceStatus.excused => ('غائب بإذن', Colors.orange.shade600),
      _ => ('غائب', Colors.red.shade400),
    };
    return Row(
      children: [
        Expanded(child: Text(_fmtDate(h.date), style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(13)))),
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.sp(10), vertical: r.sp(4)),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(r.radius(14))),
          child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(12))),
        ),
      ],
    );
  }

  // ───────── تبويب الحفظ والوظائف ─────────

  Widget _homeworkTab(Responsive r, List<ParentDayRecord> all) {
    final records = all.where((h) => h.homework != null).toList();
    final brought = records.where((h) => h.homework!.brought).length;
    final missed = records.length - brought;

    return _scrollable(r, [
      _card(
        r,
        records.isEmpty
            ? Text('لا توجد سجلات وظائف بهذا الشهر', style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(13)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _count(r, '$brought', 'جاب الوظيفة', AppTheme.lightGreen),
                      _count(r, '$missed', 'ما جاب', Colors.red.shade400),
                    ],
                  ),
                  SizedBox(height: r.sp(10)),
                  Text('الأيام المسجّلة: ${records.length}',
                      style: TextStyle(fontSize: r.fontSize(13), fontWeight: FontWeight.w600)),
                ],
              ),
      ),
      if (records.isNotEmpty)
        _card(
          r,
          Column(
            children: [
              for (final h in records) ...[
                _homeworkRow(r, h),
                if (h != records.last) Divider(height: r.sp(14)),
              ],
            ],
          ),
        )
      else
        _empty(r, 'لا يوجد أرشيف حفظ'),
    ]);
  }

  Widget _homeworkRow(Responsive r, ParentDayRecord h) {
    final hw = h.homework!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(hw.brought ? Icons.menu_book : Icons.close,
            size: r.iconSize(18), color: hw.brought ? AppTheme.primaryGreen : Colors.red.shade300),
        SizedBox(width: r.sp(10)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fmtDate(h.date), style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
              SizedBox(height: r.sp(2)),
              Text(
                hw.brought ? (hw.surah.isNotEmpty ? hw.surah : 'أحضر الوظيفة') : 'لم يحضر الوظيفة',
                style: TextStyle(fontSize: r.fontSize(12.5), color: hw.brought ? AppTheme.primaryGreen : Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
