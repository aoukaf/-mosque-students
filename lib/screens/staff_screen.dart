import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/app_theme.dart';
import '../models/staff.dart';
import '../models/sync_service.dart';
import '../utils/responsive.dart';

/// المعلمون والمشرفون: معلم، معلم مساعد، مشرف المسجد، مشرف الحلقات العام.
/// أي حساب مفتوح على هذا المسجد يقدر يضيف ويعدّل، وتظهر البيانات للأوقاف.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _sync = SyncService();
  late final Stream<List<StaffMember>> _stream = _sync.watchStaff();
  List<String> _halqas = [];

  @override
  void initState() {
    super.initState();
    _sync.getHalqas().then((h) {
      if (mounted) setState(() => _halqas = h);
    });
  }

  Future<void> _open([StaffMember? member]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StaffEditScreen(member: member, halqas: _halqas)),
    );
  }

  Future<void> _delete(StaffMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف'),
        content: Text('هل تريد حذف "${m.fullName}" من القائمة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sync.deleteStaff(m.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('تعذّر الحذف، تحقق من الاتصال'), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('المعلمون والمشرفون',
            style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold)),
        toolbarHeight: r.isTablet ? 64 : 56,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        backgroundColor: AppTheme.primaryGreen,
        icon: Icon(Icons.person_add, color: Colors.white, size: r.iconSize(22)),
        label: Text('إضافة', style: TextStyle(color: Colors.white, fontSize: r.fontSize(14))),
      ),
      body: StreamBuilder<List<StaffMember>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: r.pagePadding,
                child: Text(
                  'تعذّر تحميل البيانات.\nتأكد من الاتصال، وإذا استمرت المشكلة اخرج من التطبيق وادخل من جديد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: r.fontSize(14), color: Colors.grey[700]),
                ),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final all = snap.data!;
          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: r.pagePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: r.sp(80), color: Colors.grey[400]),
                    SizedBox(height: r.sp(14)),
                    Text('لا توجد بيانات بعد', style: TextStyle(fontSize: r.fontSize(15))),
                    SizedBox(height: r.sp(6)),
                    Text('اضغط "إضافة" لتسجيل المعلمين والمشرفين',
                        style: TextStyle(fontSize: r.fontSize(12), color: Colors.grey[600])),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.isTablet ? 700 : double.infinity),
              child: ListView(
                padding: EdgeInsets.fromLTRB(r.sp(12), r.sp(12), r.sp(12), r.sp(90)),
                children: [
                  for (final role in StaffRole.all)
                    ..._section(r, role, all.where((m) => m.role == role).toList()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _section(Responsive r, String role, List<StaffMember> members) {
    if (members.isEmpty) return const [];
    members.sort((a, b) => a.fullName.compareTo(b.fullName));
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(r.sp(4), r.sp(10), r.sp(4), r.sp(6)),
        child: Text(StaffRole.pluralLabel(role),
            style: TextStyle(fontSize: r.fontSize(14), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
      ),
      for (final m in members) _card(r, m),
    ];
  }

  Widget _card(Responsive r, StaffMember m) {
    final details = <String>[
      if (StaffRole.hasHalqa(m.role) && m.halqa.isNotEmpty) 'الحلقة: ${m.halqa}',
      if (m.phone.isNotEmpty) m.phone,
      m.quranStatusLabel,
    ];
    return Card(
      margin: EdgeInsets.only(bottom: r.sp(8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
      child: ListTile(
        onTap: () => _open(m),
        contentPadding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(4)),
        leading: CircleAvatar(
          radius: r.sp(20),
          backgroundColor: AppTheme.lightGreen,
          child: Text(m.fullName.isNotEmpty ? m.fullName[0] : '؟',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(m.fullName, style: TextStyle(fontSize: r.fontSize(15), fontWeight: FontWeight.w600)),
        subtitle: Text(details.join('  •  '), style: TextStyle(fontSize: r.fontSize(12))),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red, size: r.iconSize(22)),
          tooltip: 'حذف',
          onPressed: () => _delete(m),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class StaffEditScreen extends StatefulWidget {
  final StaffMember? member;
  final List<String> halqas;
  const StaffEditScreen({super.key, this.member, required this.halqas});

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sync = SyncService();

  late String _role;
  late String _quranStatus;
  late String _halqa;
  DateTime? _birth;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _eduCtrl;
  late final TextEditingController _jobCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _partsCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _role = m?.role ?? StaffRole.teacher;
    _quranStatus = m?.quranStatus ?? QuranStatus.none;
    _halqa = m?.halqa ?? '';
    _birth = m?.birthDateTime;
    _nameCtrl = TextEditingController(text: m?.fullName ?? '');
    _eduCtrl = TextEditingController(text: m?.education ?? '');
    _jobCtrl = TextEditingController(text: m?.job ?? '');
    _phoneCtrl = TextEditingController(text: m?.phone ?? '');
    _partsCtrl = TextEditingController(text: m?.memorizedParts?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _eduCtrl.dispose();
    _jobCtrl.dispose();
    _phoneCtrl.dispose();
    _partsCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(1990),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final parts = int.tryParse(_partsCtrl.text.trim());
    final member = StaffMember(
      id: widget.member?.id ?? const Uuid().v4(),
      role: _role,
      fullName: _nameCtrl.text.trim(),
      education: _eduCtrl.text.trim(),
      job: _jobCtrl.text.trim(),
      birthDate: _birth == null ? '' : _fmtDate(_birth!),
      phone: _phoneCtrl.text.trim(),
      quranStatus: _quranStatus,
      memorizedParts: _quranStatus == QuranStatus.none ? parts : null,
      halqa: StaffRole.hasHalqa(_role) ? _halqa : '',
    );
    try {
      await _sync.saveStaff(member);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذّر الحفظ. تأكد من الاتصال، وإذا استمرت المشكلة اخرج من التطبيق وادخل من جديد'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final halqaItems = <String>{'', ...widget.halqas, if (_halqa.isNotEmpty) _halqa}.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member == null ? 'إضافة' : 'تعديل',
            style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17))),
        toolbarHeight: r.isTablet ? 64 : 56,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.isTablet ? 600 : double.infinity),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: r.pagePadding,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: _deco('الصفة'),
                  items: [
                    for (final role in StaffRole.all)
                      DropdownMenuItem(value: role, child: Text(StaffRole.label(role))),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                if (StaffRole.hasHalqa(_role)) ...[
                  SizedBox(height: r.sp(12)),
                  DropdownButtonFormField<String>(
                    initialValue: _halqa,
                    decoration: _deco('الحلقة'),
                    items: [
                      for (final h in halqaItems)
                        DropdownMenuItem(value: h, child: Text(h.isEmpty ? 'بدون حلقة' : h)),
                    ],
                    onChanged: (v) => setState(() => _halqa = v ?? ''),
                  ),
                ],
                SizedBox(height: r.sp(12)),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _deco('الاسم الثلاثي', hint: 'الاسم واسم الأب والكنية'),
                  maxLength: 120,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                ),
                SizedBox(height: r.sp(4)),
                TextFormField(
                  controller: _eduCtrl,
                  decoration: _deco('الدراسة', hint: 'مثال: معهد شرعي، بكالوريوس هندسة'),
                  maxLength: 120,
                ),
                SizedBox(height: r.sp(4)),
                TextFormField(
                  controller: _jobCtrl,
                  decoration: _deco('العمل الحالي'),
                  maxLength: 120,
                ),
                SizedBox(height: r.sp(4)),
                InkWell(
                  onTap: _pickBirth,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _deco('تاريخ الميلاد'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _birth == null ? 'اضغط للاختيار' : _fmtDate(_birth!),
                            style: TextStyle(color: _birth == null ? Colors.grey[600] : null),
                          ),
                        ),
                        if (_birth != null)
                          GestureDetector(
                            onTap: () => setState(() => _birth = null),
                            child: const Icon(Icons.clear, size: 18),
                          ),
                        const SizedBox(width: 6),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: r.sp(16)),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: _deco('رقم الهاتف'),
                  maxLength: 25,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    return RegExp(r'^[0-9+\-\s()]{6,25}$').hasMatch(t) ? null : 'رقم غير صالح';
                  },
                ),
                SizedBox(height: r.sp(8)),
                Text('الحالة القرآنية',
                    style: TextStyle(fontSize: r.fontSize(13), fontWeight: FontWeight.w600)),
                SizedBox(height: r.sp(8)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: QuranStatus.mujaz, label: Text('مجاز')),
                    ButtonSegment(value: QuranStatus.khatim, label: Text('خاتم')),
                    ButtonSegment(value: QuranStatus.none, label: Text('غير خاتم')),
                  ],
                  selected: {_quranStatus},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _quranStatus = s.first),
                ),
                if (_quranStatus == QuranStatus.none) ...[
                  SizedBox(height: r.sp(12)),
                  TextFormField(
                    controller: _partsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _deco('عدد الأجزاء المحفوظة (من 30)'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final n = int.tryParse(t);
                      return (n == null || n < 0 || n > 30) ? 'أدخل رقماً من 0 إلى 30' : null;
                    },
                  ),
                ],
                SizedBox(height: r.sp(24)),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: r.sp(20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
