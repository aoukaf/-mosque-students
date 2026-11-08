import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sync_service.dart';
import '../models/staff.dart';
import '../models/student.dart';
import '../models/app_theme.dart';
import '../services/awqaf_vault.dart';
import '../utils/halqa_days.dart';

String _mosqueHash(String id, String pw) => sha256.convert(utf8.encode('$id:$pw')).toString();

String _formatId(String id) =>
    id.length == 12 ? '${id.substring(0, 4)}-${id.substring(4, 8)}-${id.substring(8)}' : id;

enum _VaultView { locked, loading, found, missing, error }

class AwqafMosqueDetailScreen extends StatefulWidget {
  final MosqueInfo mosque;
  const AwqafMosqueDetailScreen({super.key, required this.mosque});

  @override
  State<AwqafMosqueDetailScreen> createState() => _AwqafMosqueDetailScreenState();
}

class _AwqafMosqueDetailScreenState extends State<AwqafMosqueDetailScreen> {
  final _sync = SyncService();
  StreamSubscription<List<Student>>? _studentsSub;
  StreamSubscription<List<String>>? _halqasSub;
  StreamSubscription<List<StaffMember>>? _staffSub;
  StreamSubscription<Map<String, StudentInfo>>? _infosSub;
  StreamSubscription<Map<String, List<String>>>? _daysSub;
  List<Student> _students = [];
  List<String> _halqas = [];
  List<StaffMember> _staff = [];
  Map<String, StudentInfo> _infos = {};
  Map<String, List<String>> _halqaDays = {};
  bool _staffError = false;
  bool _infosError = false;
  String? _clearPassword;
  _VaultView _vaultView = _VaultView.locked;
  bool _vaultBusy = false;

  @override
  void initState() {
    super.initState();
    final id = widget.mosque.id;
    _studentsSub = _sync.watchMosqueStudents(id).listen(
      (list) { if (mounted) setState(() => _students = list); },
    );
    _halqasSub = _sync.watchMosqueHalqas(id).listen(
      (list) { if (mounted) setState(() => _halqas = list); },
    );
    _staffSub = _sync.watchStaff(mosqueId: id).listen(
      (list) { if (mounted) setState(() { _staff = list; _staffError = false; }); },
      onError: (_) { if (mounted) setState(() => _staffError = true); },
    );
    _infosSub = _sync.watchStudentInfos(mosqueId: id).listen(
      (map) { if (mounted) setState(() { _infos = map; _infosError = false; }); },
      onError: (_) { if (mounted) setState(() => _infosError = true); },
    );
    _daysSub = _sync.watchHalqaDays(mosqueId: id).listen(
      (m) { if (mounted) setState(() => _halqaDays = m); },
      onError: (_) {},
    );
    _loadVault();
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _halqasSub?.cancel();
    _staffSub?.cancel();
    _infosSub?.cancel();
    _daysSub?.cancel();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  String get _scheduleLabel {
    switch (widget.mosque.scheduleType) {
      case 'summerOnly': return 'صيفي فقط';
      case 'winterOnly': return 'شتوي فقط';
      default: return 'مستمر';
    }
  }

  Map<String, List<Student>> get _grouped {
    final Map<String, List<Student>> res = {};
    for (final h in _halqas) {
      final list = _students.where((s) => s.halqa == h).toList();
      res[h] = list;
    }
    final others = _students.where((s) => s.halqa.isEmpty || !_halqas.contains(s.halqa)).toList();
    if (others.isNotEmpty) res['بدون حلقة'] = others;
    return res;
  }

  // ───────── خزنة كلمة السر ─────────

  /// تُعرض كلمة السر بنص صريح تلقائياً متى كانت الخزنة مفتوحة
  Future<void> _loadVault() async {
    if (!AwqafVault.isUnlocked) {
      if (mounted) setState(() => _vaultView = _VaultView.locked);
      return;
    }
    if (mounted) setState(() => _vaultView = _VaultView.loading);
    try {
      final p = await AwqafVault.readMosquePassword(widget.mosque.id);
      if (!mounted) return;
      setState(() {
        _clearPassword = p;
        _vaultView = p == null ? _VaultView.missing : _VaultView.found;
      });
    } catch (_) {
      if (mounted) setState(() => _vaultView = _VaultView.error);
    }
  }

  Future<void> _unlock() async {
    if (await AwqafVault.promptUnlock(context)) await _loadVault();
  }

  /// تسجيل يدوي لكلمة سر المسجد (للمساجد التي لم يدخل معلمها بعد بالنسخة الجديدة)
  Future<void> _savePassword() async {
    if (!AwqafVault.isUnlocked && !await AwqafVault.promptUnlock(context)) return;
    if (!mounted) return;

    final ctrl = TextEditingController();
    final mosquePw = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل كلمة سر المسجد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تُحفظ مشفّرة، ولا يفكها إلا الأوقاف.\n'
                  'مسجد: ${widget.mosque.name.isNotEmpty ? widget.mosque.name : _formatId(widget.mosque.id)}',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: 'كلمة سر المسجد'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (mosquePw == null || mosquePw.isEmpty || !mounted) return;

    // تحقق اختياري: إذا الهاش القديم لسه مقروءاً نقارن، لننبّه إذا الكلمة قديمة أو خاطئة
    final legacy = await _sync.legacyMosqueHashOf(widget.mosque.id);
    if (legacy != null && legacy != _mosqueHash(widget.mosque.id, mosquePw)) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('كلمة السر لا تطابق'),
            content: const Text('هذه الكلمة لا تطابق كلمة سر المسجد المسجّلة (ربما غيّرها المعلم). هل تحفظها رغم ذلك؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ على أي حال')),
            ],
          ),
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _vaultBusy = true);
    try {
      await AwqafVault.storeMosquePassword(widget.mosque.id, mosquePw);
      _toast(legacy == null ? 'تم الحفظ (لم أستطع التحقق من صحة الكلمة)' : 'تم الحفظ وتبيّن أن الكلمة صحيحة');
      await _loadVault();
    } catch (_) {
      _toast('تعذّر الحفظ، تأكد من الاتصال وأنك داخل بجلسة الأوقاف', error: true);
    }
    if (mounted) setState(() => _vaultBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final mosque = widget.mosque;
    final grouped = _grouped;
    final totalStars = _students.fold(0, (s, st) => s + st.stars);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: CustomScrollView(
          slivers: [
            // ─── Header ───
            SliverAppBar(
              expandedHeight: 190,
              pinned: true,
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppTheme.primaryGreen,
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        mosque.name.isNotEmpty ? mosque.name : 'مسجد غير مسمى',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _HStat(icon: Icons.people,    value: '${_students.length}', label: 'طالب'),
                          const SizedBox(width: 20),
                          _HStat(icon: Icons.menu_book, value: '${_halqas.length}',      label: 'حلقة'),
                          const SizedBox(width: 20),
                          _HStat(icon: Icons.star,      value: '$totalStars',             label: 'نجمة'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_scheduleLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── رقم المسجد وكلمة السر ───
            SliverToBoxAdapter(
              child: _CredentialsCard(
                mosqueId: mosque.id,
                view: _vaultView,
                password: _clearPassword,
                busy: _vaultBusy,
                onUnlock: _unlock,
                onSave: _savePassword,
                onRetry: _loadVault,
                onCopy: (text, what) {
                  Clipboard.setData(ClipboardData(text: text));
                  _toast('تم نسخ $what');
                },
              ),
            ),

            // ─── مواعيد الدوام ───
            if (mosque.morningFrom != null || mosque.days.isNotEmpty)
              SliverToBoxAdapter(child: _InfoCard(mosque: mosque)),

            // ─── الكادر ───
            SliverToBoxAdapter(
              child: _StaffSection(
                staff: _staff,
                error: _staffError,
                onToast: _toast,
              ),
            ),

            // ─── الحلقات ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'الحلقات (${grouped.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            if (_infosError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('تعذّر تحميل هواتف الطلاب وصفوفهم (تحتاج جلسة الأوقاف).',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                ),
              ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final halqa = grouped.keys.elementAt(i);
                    final students = grouped[halqa]!;
                    final teachers = _staff
                        .where((s) => StaffRole.hasHalqa(s.role) && s.halqa == halqa)
                        .map((s) => s.fullName)
                        .toList();
                    return _HalqaCard(
                      halqa: halqa,
                      students: students,
                      infos: _infos,
                      teachers: teachers,
                      days: _halqaDays[halqa] ?? const [],
                    );
                  },
                  childCount: grouped.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── رقم المسجد وكلمة السر ──────────────────────────────

class _CredentialsCard extends StatelessWidget {
  final String mosqueId;
  final _VaultView view;
  final String? password;
  final bool busy;
  final VoidCallback onUnlock;
  final VoidCallback onSave;
  final VoidCallback onRetry;
  final void Function(String text, String what) onCopy;

  const _CredentialsCard({
    required this.mosqueId,
    required this.view,
    required this.password,
    required this.busy,
    required this.onUnlock,
    required this.onSave,
    required this.onRetry,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.vpn_key, size: 18, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text('بيانات الدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('رقم المسجد: ', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              Expanded(
                child: Text(_formatId(mosqueId),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'نسخ الرقم',
                onPressed: () => onCopy(_formatId(mosqueId), 'رقم المسجد'),
              ),
            ],
          ),
          _passwordRow(),
        ],
      ),
    );
  }

  Widget _passwordRow() {
    final label = Text('كلمة السر: ', style: TextStyle(color: Colors.grey.shade700, fontSize: 13));
    switch (view) {
      case _VaultView.loading:
        return Row(children: [
          label,
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]);
      case _VaultView.found:
        return Row(children: [
          label,
          Expanded(
            child: SelectableText(password ?? '',
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'نسخ كلمة السر',
            onPressed: () => onCopy(password ?? '', 'كلمة السر'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'تسجيل كلمة جديدة',
            onPressed: busy ? null : onSave,
          ),
        ]);
      case _VaultView.missing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              label,
              Text('غير مسجّلة بعد', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text('تُسجَّل تلقائياً أول ما يدخل معلم المسجد بالنسخة الجديدة، أو سجّلها بنفسك.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: busy ? null : onSave,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('تسجيل كلمة السر'),
            ),
          ],
        );
      case _VaultView.error:
        return Row(children: [
          label,
          Expanded(child: Text('تعذّر القراءة', style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
          TextButton(onPressed: onRetry, child: const Text('إعادة')),
        ]);
      case _VaultView.locked:
        return Row(children: [
          label,
          Text('مقفلة 🔒', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
            onPressed: onUnlock,
            icon: const Icon(Icons.lock_open, size: 18),
            label: const Text('فتح'),
          ),
        ]);
    }
  }
}

// ─── الكادر ───────────────────────────────────────────

class _StaffSection extends StatelessWidget {
  final List<StaffMember> staff;
  final bool error;
  final void Function(String msg, {bool error}) onToast;
  const _StaffSection({required this.staff, required this.error, required this.onToast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('الكادر (${staff.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          if (error)
            Text('تعذّر تحميل بيانات الكادر (تحتاج جلسة الأوقاف).',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700))
          else if (staff.isEmpty)
            Text('لم يُسجَّل كادر بعد. يضيفه معلم المسجد من الإعدادات ← المعلمون والمشرفون.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          else
            for (final role in StaffRole.all)
              for (final m in (staff.where((s) => s.role == role).toList()
                ..sort((a, b) => a.fullName.compareTo(b.fullName))))
                _StaffCard(member: m, onToast: onToast),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final void Function(String msg, {bool error}) onToast;
  const _StaffCard({required this.member, required this.onToast});

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok) onToast('تعذّر فتح الاتصال');
  }

  @override
  Widget build(BuildContext context) {
    final m = member;
    final age = m.age;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                child: Text(m.fullName.isNotEmpty ? m.fullName[0] : '؟',
                    style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      StaffRole.hasHalqa(m.role) && m.halqa.isNotEmpty
                          ? '${StaffRole.label(m.role)} • ${m.halqa}'
                          : StaffRole.label(m.role),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(m.quranStatusLabel,
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (m.education.isNotEmpty) _kv(Icons.school, 'الدراسة', m.education),
          if (m.job.isNotEmpty) _kv(Icons.work_outline, 'العمل', m.job),
          if (m.birthDate.isNotEmpty)
            _kv(Icons.cake_outlined, 'الميلاد', age == null ? m.birthDate : '${m.birthDate}  (العمر $age)'),
          if (m.phone.isNotEmpty)
            Row(
              children: [
                Expanded(child: _kv(Icons.phone, 'الهاتف', m.phone, ltr: true)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 17),
                  tooltip: 'نسخ',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: m.phone));
                    onToast('تم نسخ الرقم');
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.call, size: 17, color: Colors.green),
                  tooltip: 'اتصال',
                  onPressed: () => _call(m.phone),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String label, String value, {bool ltr = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text('$label: ', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            Expanded(
              child: Text(value,
                  textDirection: ltr ? TextDirection.ltr : null,
                  textAlign: ltr ? TextAlign.right : null,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

// ─── بطاقة الحلقة قابلة للتوسيع ────────────────────────

class _HalqaCard extends StatelessWidget {
  final String halqa;
  final List<Student> students;
  final Map<String, StudentInfo> infos;
  final List<String> teachers;
  final List<String> days; // أيام دوام الحلقة
  const _HalqaCard({
    required this.halqa,
    required this.students,
    required this.infos,
    required this.teachers,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final totalParts = students.fold(0, (s, st) => s + st.partsCompleted);
    final totalStars = students.fold(0, (s, st) => s + st.stars);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.groups, color: AppTheme.primaryGreen, size: 22),
          ),
          title: Text(halqa,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    Icon(Icons.event_repeat, size: 13, color: Colors.teal.shade600),
                    const SizedBox(width: 4),
                    Text('الدوام: ${halqaDaysLabel(days)}',
                        style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (teachers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('المعلم: ${teachers.join('، ')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                Row(
                  children: [
                    _MiniChip(icon: Icons.people,    label: '${students.length} طالب',  color: Colors.blue),
                    const SizedBox(width: 6),
                    _MiniChip(icon: Icons.menu_book, label: '$totalParts جزء',          color: Colors.green),
                    const SizedBox(width: 6),
                    _MiniChip(icon: Icons.star,      label: '$totalStars نجمة',         color: Colors.amber),
                  ],
                ),
              ],
            ),
          ),
          children: students.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('لا يوجد طلاب في هذه الحلقة',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  )
                ]
              : students.map((s) => _StudentRow(student: s, info: infos[s.id])).toList(),
        ),
      ),
    );
  }
}

// ─── صف الطالب ──────────────────────────────────────────

class _StudentRow extends StatelessWidget {
  final Student student;
  final StudentInfo? info;
  const _StudentRow({required this.student, this.info});

  @override
  Widget build(BuildContext context) {
    final progress = (student.partsCompleted / 30).clamp(0.0, 1.0);
    final extra = <String>[
      if (info != null && info!.grade.isNotEmpty) 'الصف: ${info!.grade}',
      if (info != null && info!.phone.isNotEmpty) info!.phone,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
            child: Text(
              student.name.isNotEmpty ? student.name[0] : '؟',
              style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (extra.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(extra.join('  •  '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${student.partsCompleted}/30',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Row(children: [
                Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                const SizedBox(width: 2),
                Text('${student.stars}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── بطاقة المعلومات ────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final MosqueInfo mosque;
  const _InfoCard({required this.mosque});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mosque.days.isNotEmpty) ...[
            Wrap(spacing: 6, runSpacing: 6,
              children: mosque.days.map((d) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(d, style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          if (mosque.morningFrom != null)
            _TimeRow(icon: Icons.wb_sunny_outlined, label: 'الصباح',
                from: mosque.morningFrom!, to: mosque.morningTo ?? ''),
          if (mosque.eveningFrom != null)
            _TimeRow(icon: Icons.nights_stay_outlined, label: 'المساء',
                from: mosque.eveningFrom!, to: mosque.eveningTo ?? ''),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label, from, to;
  const _TimeRow({required this.icon, required this.label, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text('$label: $from - $to',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ]),
    );
  }
}

// ─── مساعدات ────────────────────────────────────────────

class _HStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _HStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: Colors.white70, size: 16),
    const SizedBox(width: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ],
  );
}
