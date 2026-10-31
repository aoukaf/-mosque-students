import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';
import '../models/student.dart';
import '../models/sync_service.dart';
import '../services/update_service.dart';
import '../utils/responsive.dart';
import 'mosque_setup_screen.dart';

/// واجهة ولي الأمر: عرض فقط لبيانات طالب واحد، بدخول برمز الطالب.
class ParentScreen extends StatefulWidget {
  final String code;
  final String mosqueId;
  final String studentId;

  const ParentScreen({
    super.key,
    required this.code,
    required this.mosqueId,
    required this.studentId,
  });

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final _sync = SyncService();
  StreamSubscription<Student?>? _sub;
  Student? _student;
  bool _studentLoaded = false;
  MosqueInfo? _mosque;
  List<ParentDayRecord>? _history;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
    _verifyCode();
    _sub = _sync.watchStudentIn(widget.mosqueId, widget.studentId).listen(
      (s) { if (mounted) setState(() { _student = s; _studentLoaded = true; }); },
      onError: (_) { if (mounted) setState(() => _studentLoaded = true); },
    );
    _loadExtras();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // إذا أنشأ المعلم رمزاً جديداً فالرمز القديم يتوقف، ونُخرج ولي الأمر
  Future<void> _verifyCode() async {
    try {
      final link = await _sync.resolveParentCode(widget.code);
      if (link == null && mounted) {
        await _logout(message: 'انتهت صلاحية الرمز، اطلب رمزاً جديداً من المعلم');
      }
    } catch (_) {
      // لا اتصال: نكمل بالبيانات المخزنة
    }
  }

  Future<void> _loadExtras() async {
    final mosque = await _sync.getMosqueInfoById(widget.mosqueId);
    final history = await _sync.getStudentHistory(widget.mosqueId, widget.studentId);
    if (mounted) setState(() { _mosque = mosque; _history = history; });
  }

  Future<void> _logout({String? message}) async {
    await _sync.closeParentSession(widget.mosqueId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SyncService.userRoleKey);
    await prefs.remove(SyncService.parentCodeKey);
    await prefs.remove(SyncService.parentMosqueIdKey);
    await prefs.remove(SyncService.parentStudentIdKey);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MosqueSetupScreen(notice: message)));
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('ستحتاج إلى إدخال الرمز مرة أخرى للدخول.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
        ],
      ),
    );
    if (ok == true) await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('متابعة الطالب', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17))),
        toolbarHeight: r.isTablet ? 64 : 56,
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'خروج', onPressed: _confirmLogout),
        ],
      ),
      body: !_studentLoaded
          ? const Center(child: CircularProgressIndicator())
          : _student == null
              ? _buildMissing(r)
              : _buildBody(r, _student!),
    );
  }

  Widget _buildMissing(Responsive r) {
    return Center(
      child: Padding(
        padding: r.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: r.sp(70), color: Colors.grey[400]),
            SizedBox(height: r.sp(12)),
            Text('تعذّر العثور على بيانات الطالب',
                style: TextStyle(fontSize: r.fontSize(15)), textAlign: TextAlign.center),
            SizedBox(height: r.sp(16)),
            ElevatedButton(onPressed: _logout, child: const Text('خروج')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Responsive r, Student s) {
    final progress = (s.partsCompleted / 30).clamp(0.0, 1.0);
    return RefreshIndicator(
      onRefresh: _loadExtras,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.isTablet ? 700 : double.infinity),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: r.pagePadding,
            children: [
              _header(r, s),
              SizedBox(height: r.sp(14)),
              Row(
                children: [
                  Expanded(child: _statCard(r, Icons.menu_book, '${s.partsCompleted}', 'جزء مكتمل', 'من 30', AppTheme.lightGreen)),
                  SizedBox(width: r.sp(12)),
                  Expanded(child: _statCard(r, Icons.star, '${s.stars}', 'نجمة', 'من 5000', AppTheme.accentGold)),
                ],
              ),
              SizedBox(height: r.sp(14)),
              _progressCard(r, s, progress),
              SizedBox(height: r.sp(14)),
              _attendanceSummary(r),
              SizedBox(height: r.sp(14)),
              _historyCard(r),
              if (_mosque != null && (_mosque!.days.isNotEmpty || _mosque!.morningFrom != null)) ...[
                SizedBox(height: r.sp(14)),
                _scheduleCard(r, _mosque!),
              ],
              SizedBox(height: r.sp(20)),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── البطاقات ─────────

  Widget _card(Responsive r, Widget child) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
        child: Padding(padding: r.cardPadding, child: child),
      );

  Widget _title(Responsive r, IconData icon, String text) => Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: r.iconSize(22)),
          SizedBox(width: r.sp(8)),
          Text(text, style: TextStyle(fontSize: r.fontSize(15), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
        ],
      );

  Widget _header(Responsive r, Student s) {
    return _card(
      r,
      Column(
        children: [
          CircleAvatar(
            radius: r.sp(r.isTablet ? 44 : 34),
            backgroundColor: AppTheme.primaryGreen,
            child: Text(s.name.isNotEmpty ? s.name[0] : '؟',
                style: TextStyle(color: Colors.white, fontSize: r.fontSize(r.isTablet ? 36 : 28), fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: r.sp(10)),
          Text(s.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: r.fontSize(r.isTablet ? 24 : 21), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
          SizedBox(height: r.sp(6)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: r.sp(8),
            runSpacing: r.sp(6),
            children: [
              if (s.halqa.isNotEmpty) _pill(r, Icons.groups, s.halqa),
              if (_mosque != null && _mosque!.name.isNotEmpty) _pill(r, Icons.mosque, _mosque!.name),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(Responsive r, IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(6)),
        decoration: BoxDecoration(
          color: AppTheme.lightGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.radius(20)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: r.iconSize(15), color: AppTheme.primaryGreen),
          SizedBox(width: r.sp(5)),
          Text(text, style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
        ]),
      );

  Widget _statCard(Responsive r, IconData icon, String value, String label, String sub, Color color) {
    return _card(
      r,
      Column(
        children: [
          Icon(icon, color: color, size: r.iconSize(28)),
          SizedBox(height: r.sp(6)),
          Text(value, style: TextStyle(fontSize: r.fontSize(26), fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
          Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(11))),
        ],
      ),
    );
  }

  Widget _progressCard(Responsive r, Student s, double progress) {
    return _card(
      r,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(r, Icons.menu_book, 'تقدم حفظ القرآن'),
          SizedBox(height: r.sp(12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${s.partsCompleted} / 30 جزء', style: TextStyle(fontSize: r.fontSize(16), fontWeight: FontWeight.bold)),
              Text('${(progress * 100).round()}%',
                  style: TextStyle(fontSize: r.fontSize(16), fontWeight: FontWeight.bold, color: AppTheme.lightGreen)),
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
        ],
      ),
    );
  }

  Widget _attendanceSummary(Responsive r) {
    final history = _history;
    if (history == null) {
      return _card(r, const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())));
    }
    final records = history.where((h) => h.attendance != null).toList();
    final present = records.where((h) => h.attendance == AttendanceStatus.present).length;
    final excused = records.where((h) => h.attendance == AttendanceStatus.excused).length;
    final absent = records.length - present - excused;
    final pct = records.isEmpty ? 0 : (present / records.length * 100).round();

    return _card(
      r,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(r, Icons.fact_check, 'الحضور (آخر 30 يوماً)'),
          SizedBox(height: r.sp(12)),
          if (records.isEmpty)
            Text('لا توجد سجلات حضور بعد', style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(13)))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _count(r, '$present', 'حاضر', AppTheme.lightGreen),
                _count(r, '$absent', 'غائب', Colors.red.shade400),
                _count(r, '$excused', 'غائب بإذن', Colors.orange.shade600),
              ],
            ),
            SizedBox(height: r.sp(12)),
            Text('نسبة الحضور: $pct%', style: TextStyle(fontSize: r.fontSize(13), fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _count(Responsive r, String value, String label, Color color) => Column(
        children: [
          Text(value, style: TextStyle(fontSize: r.fontSize(22), fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: r.fontSize(12), color: Colors.grey[700])),
        ],
      );

  static const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  String _fmtDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day}/${d.month}';

  Widget _historyCard(Responsive r) {
    final history = _history;
    return _card(
      r,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(r, Icons.history, 'سجل الأيام'),
          SizedBox(height: r.sp(8)),
          if (history == null)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if (history.isEmpty)
            Text('لا توجد سجلات بعد', style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(13)))
          else
            ...history.map((h) => _dayRow(r, h)),
        ],
      ),
    );
  }

  Widget _dayRow(Responsive r, ParentDayRecord h) {
    final status = h.attendance;
    final (label, color) = switch (status) {
      AttendanceStatus.present => ('حاضر', AppTheme.lightGreen),
      AttendanceStatus.excused => ('غائب بإذن', Colors.orange.shade600),
      AttendanceStatus.absent => ('غائب', Colors.red.shade400),
      _ => ('', Colors.grey),
    };
    final hw = h.homework;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.sp(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDate(h.date), style: TextStyle(fontWeight: FontWeight.w600, fontSize: r.fontSize(13))),
                if (hw != null)
                  Padding(
                    padding: EdgeInsets.only(top: r.sp(3)),
                    child: Row(children: [
                      Icon(hw.brought ? Icons.menu_book : Icons.close,
                          size: r.iconSize(14), color: hw.brought ? AppTheme.primaryGreen : Colors.red.shade300),
                      SizedBox(width: r.sp(4)),
                      Flexible(
                        child: Text(
                          hw.brought ? (hw.surah.isNotEmpty ? hw.surah : 'أحضر الوظيفة') : 'لم يحضر الوظيفة',
                          style: TextStyle(fontSize: r.fontSize(12), color: Colors.grey[700]),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          if (status != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: r.sp(10), vertical: r.sp(4)),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(r.radius(14))),
              child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(12))),
            ),
        ],
      ),
    );
  }

  Widget _scheduleCard(Responsive r, MosqueInfo m) {
    Widget time(IconData icon, String label, String from, String to) => Padding(
          padding: EdgeInsets.only(top: r.sp(6)),
          child: Row(children: [
            Icon(icon, size: r.iconSize(16), color: Colors.grey[600]),
            SizedBox(width: r.sp(6)),
            Text('$label: $from - $to', style: TextStyle(fontSize: r.fontSize(13), color: Colors.grey[800])),
          ]),
        );
    return _card(
      r,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(r, Icons.schedule, 'دوام المسجد'),
          if (m.days.isNotEmpty) ...[
            SizedBox(height: r.sp(8)),
            Wrap(
              spacing: r.sp(6),
              runSpacing: r.sp(6),
              children: m.days
                  .map((d) => Container(
                        padding: EdgeInsets.symmetric(horizontal: r.sp(10), vertical: r.sp(4)),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(r.radius(12)),
                        ),
                        child: Text(d, style: TextStyle(fontSize: r.fontSize(12), color: AppTheme.primaryGreen)),
                      ))
                  .toList(),
            ),
          ],
          if (m.morningFrom != null) time(Icons.wb_sunny_outlined, 'الصباح', m.morningFrom!, m.morningTo ?? ''),
          if (m.eveningFrom != null) time(Icons.nights_stay_outlined, 'المساء', m.eveningFrom!, m.eveningTo ?? ''),
        ],
      ),
    );
  }
}
