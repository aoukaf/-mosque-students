import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _halqasSub = _sync.watchHalqas().listen((halqas) {
      if (mounted) setState(() { _halqas = halqas.isNotEmpty ? halqas : _halqas; _loading = false; });
    }, onError: (_) async {
      final local = await _sync.getHalqas();
      if (mounted) setState(() { _halqas = local; _loading = false; });
    });
  }

  @override
  void dispose() {
    _halqasSub?.cancel();
    super.dispose();
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
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red, size: r.iconSize(22)),
                              onPressed: () => _deleteHalqa(halqa),
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
