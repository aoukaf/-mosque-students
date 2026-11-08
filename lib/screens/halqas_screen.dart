import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import '../utils/halqa_days.dart';
import '../utils/responsive.dart';

class HalqasScreen extends StatefulWidget {
  const HalqasScreen({super.key});

  @override
  State<HalqasScreen> createState() => _HalqasScreenState();
}

class _HalqasScreenState extends State<HalqasScreen> {
  final SyncService _sync = SyncService();
  List<String> _halqas = [];
  bool _loading = true;
  StreamSubscription<List<String>>? _halqasSub;
  StreamSubscription<Map<String, List<String>>>? _daysSub;
  Map<String, List<String>> _days = {};

  @override
  void initState() {
    super.initState();
    _halqasSub = _sync.watchHalqas().listen((halqas) {
      if (mounted) setState(() { _halqas = halqas.isNotEmpty ? halqas : _halqas; _loading = false; });
    }, onError: (_) async {
      final local = await _sync.getHalqas();
      if (mounted) setState(() { _halqas = local; _loading = false; });
    });
    _daysSub = _sync.watchHalqaDays().listen(
      (m) { if (mounted) setState(() => _days = m); },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _halqasSub?.cancel();
    _daysSub?.cancel();
    super.dispose();
  }

  /// تحديد أيام دوام الحلقة: عليها يقتصر تسجيل الحضور والوظائف وتظهر عند الأوقاف
  Future<void> _editDays(String halqa) async {
    final selected = <String>{...(_days[halqa] ?? const <String>[])};
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text('أيام دوام "$halqa"'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in kWeekDays)
                      FilterChip(
                        label: Text(day, style: TextStyle(color: selected.contains(day) ? Colors.white : Colors.black87)),
                        selected: selected.contains(day),
                        selectedColor: AppTheme.primaryGreen,
                        checkmarkColor: Colors.white,
                        onSelected: (v) => setLocal(() => v ? selected.add(day) : selected.remove(day)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'تسجيل الحضور والوظائف لهذه الحلقة بيظهر بهالأيام فقط. '
                  'إذا ما اخترت أي يوم بتظهر كل الأيام.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, kWeekDays.where(selected.contains).toList()),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      await _sync.setHalqaDays(halqa, result);
    } catch (_) {
      if (mounted) _showError('تعذّر حفظ الأيام، تحقق من الاتصال');
    }
  }

  Future<void> _addHalqa() async {
    final r = Responsive(context);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة حلقة جديدة', style: TextStyle(fontSize: r.fontSize(17))),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: r.fontSize(14)),
          decoration: InputDecoration(hintText: 'اسم الحلقة', hintStyle: TextStyle(fontSize: r.fontSize(13))),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await _sync.addHalqa(result);
      } catch (e) {
        if (mounted) _showError('تعذّر إضافة الحلقة، تحقق من الاتصال');
      }
    }
  }

  Future<void> _renameHalqa(String oldName) async {
    final r = Responsive(context);
    final ctrl = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل اسم الحلقة', style: TextStyle(fontSize: r.fontSize(17))),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: r.fontSize(14)),
          decoration: InputDecoration(hintText: 'الاسم الجديد', hintStyle: TextStyle(fontSize: r.fontSize(13))),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty || result == oldName) return;
    try {
      if (await _sync.halqaExists(result)) {
        if (mounted) _showError('يوجد حلقة بهذا الاسم مسبقاً');
        return;
      }
      await _sync.renameHalqa(oldName, result);
    } catch (e) {
      if (mounted) _showError('تعذّر تعديل الاسم، تحقق من الاتصال');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  Future<void> _deleteHalqa(String halqa) async {
    final r = Responsive(context);

    // نعدّ الطلاب المنتسبين للحلقة أولاً
    int studentCount = 0;
    try {
      studentCount = await _sync.countStudentsInHalqa(halqa);
    } catch (_) {}

    final content = studentCount > 0
        ? 'سيتم حذف الحلقة "$halqa" وإلغاء ارتباط $studentCount ${studentCount == 1 ? "طالب" : "طلاب"} بها.'
        : 'هل تريد حذف حلقة "$halqa"؟';

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف الحلقة', style: TextStyle(fontSize: r.fontSize(17))),
        content: Text(content, style: TextStyle(fontSize: r.fontSize(14))),
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
    if (confirm == true) {
      try {
        await _sync.deleteHalqa(halqa);
      } catch (e) {
        if (mounted) _showError('تعذّر حذف الحلقة، تحقق من الاتصال');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الحلقات', style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17))),
        toolbarHeight: r.isTablet ? 64 : 56,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHalqa,
        backgroundColor: AppTheme.primaryGreen,
        icon: Icon(Icons.add, color: Colors.white, size: r.iconSize(22)),
        label: Text('إضافة حلقة', style: TextStyle(color: Colors.white, fontSize: r.fontSize(14))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _halqas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups, size: r.sp(80), color: Colors.grey[400]),
                      SizedBox(height: r.sp(16)),
                      Text('لا توجد حلقات بعد', style: TextStyle(fontSize: r.fontSize(15))),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: r.isTablet ? 600 : double.infinity),
                    child: ListView.separated(
                      padding: r.pagePadding,
                      itemCount: _halqas.length,
                      separatorBuilder: (_, __) => SizedBox(height: r.sp(8)),
                      itemBuilder: (ctx, i) {
                        final halqa = _halqas[i];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.cardBorderRadius)),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(4)),
                            leading: CircleAvatar(
                              radius: r.sp(r.isTablet ? 22 : 18),
                              backgroundColor: AppTheme.lightGreen,
                              child: Text('${i + 1}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(14))),
                            ),
                            title: Text(halqa, style: TextStyle(fontSize: r.fontSize(r.isTablet ? 17 : 15), fontWeight: FontWeight.w600)),
                            subtitle: Text('الدوام: ${halqaDaysLabel(_days[halqa] ?? const <String>[])}',
                                style: TextStyle(fontSize: r.fontSize(12))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.event_repeat, color: Colors.teal[700], size: r.iconSize(22)),
                                  tooltip: 'أيام الدوام',
                                  onPressed: () => _editDays(halqa),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: AppTheme.primaryGreen, size: r.iconSize(22)),
                                  tooltip: 'تعديل الاسم',
                                  onPressed: () => _renameHalqa(halqa),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: Colors.red, size: r.iconSize(22)),
                                  tooltip: 'حذف',
                                  onPressed: () => _deleteHalqa(halqa),
                                ),
                              ],
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
