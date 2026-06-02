import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import '../services/update_service.dart';
import 'mosque_setup_screen.dart';
import 'awqaf_mosque_detail_screen.dart';

class AwqafScreen extends StatefulWidget {
  const AwqafScreen({super.key});

  @override
  State<AwqafScreen> createState() => _AwqafScreenState();
}

class _AwqafScreenState extends State<AwqafScreen> {
  final SyncService _sync = SyncService();
  StreamSubscription<List<MosqueInfo>>? _sub;
  List<MosqueInfo> _mosques = [];
  String _search = '';

  String _hashAwqaf(String pw) =>
      sha256.convert(utf8.encode('awqaf:$pw')).toString();

  @override
  void initState() {
    super.initState();
    _sub = _sync.watchAllMosques().listen(
      (list) { if (mounted) setState(() => _mosques = list); },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkAndPrompt(context);
    });
  }

  Future<void> _confirmDeleteMosque(MosqueInfo mosque) async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('حذف المسجد', style: TextStyle(color: Colors.red)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  const TextSpan(text: 'سيتم حذف مسجد '),
                  TextSpan(text: mosque.name.isNotEmpty ? mosque.name : mosque.id,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' وجميع بياناته نهائياً.'),
                ],
              )),
              const SizedBox(height: 16),
              const Text('أدخل كلمة مرور الأوقاف للتأكيد:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                autofocus: true,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'كلمة مرور الأوقاف',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) { pwCtrl.dispose(); return; }

    final valid = await _sync.verifyAwqaf(_hashAwqaf(pwCtrl.text.trim()));
    pwCtrl.dispose();

    if (!valid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور غير صحيحة'), backgroundColor: Colors.red),
      );
      }
      return;
    }

    try {
      await _sync.deleteMosque(mosque.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف ${mosque.name.isNotEmpty ? mosque.name : mosque.id}'),
            backgroundColor: Colors.green),
      );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الحذف'), backgroundColor: Colors.red),
      );
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SyncService.userRoleKey);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MosqueSetupScreen()),
      );
    }
  }

  List<MosqueInfo> get _filtered {
    if (_search.isEmpty) return _mosques;
    return _mosques.where((m) =>
        m.name.toLowerCase().contains(_search.toLowerCase()) ||
        m.id.contains(_search.toUpperCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalStudents = _mosques.fold(0, (s, m) => s + m.studentCount);
    final totalHalqas = _mosques.fold(0, (s, m) => s + m.halqaCount);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.amber.shade800,
          foregroundColor: Colors.white,
          title: const Text('لوحة الأوقاف', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'خروج',
              onPressed: _logout,
            ),
          ],
        ),
        body: Column(
          children: [
            // ─── ملخص ───
            Container(
              color: Colors.amber.shade800,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(icon: Icons.mosque, value: '${_mosques.length}', label: 'مسجد'),
                  _Stat(icon: Icons.people, value: '$totalStudents', label: 'طالب'),
                  _Stat(icon: Icons.menu_book, value: '$totalHalqas', label: 'حلقة'),
                ],
              ),
            ),

            // ─── بحث ───
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'بحث باسم المسجد...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _search = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('${filtered.length} مسجد',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ),
            ),

            // ─── قائمة المساجد ───
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mosque_outlined, size: 72, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _mosques.isEmpty
                                ? 'لا توجد مساجد مسجّلة بعد'
                                : 'لا توجد نتائج مطابقة',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _MosqueCard(
                        mosque: filtered[i],
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AwqafMosqueDetailScreen(mosque: filtered[i]))),
                        onDelete: () => _confirmDeleteMosque(filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── بطاقة المسجد ─────────────────────────────────────

class _MosqueCard extends StatelessWidget {
  final MosqueInfo mosque;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const _MosqueCard({required this.mosque, this.onTap, this.onDelete});

  String get _scheduleLabel {
    switch (mosque.scheduleType) {
      case 'summerOnly': return 'صيفي فقط';
      case 'winterOnly': return 'شتوي فقط';
      default: return 'مستمر طوال العام';
    }
  }

  Color get _scheduleColor {
    switch (mosque.scheduleType) {
      case 'summerOnly': return Colors.orange;
      case 'winterOnly': return Colors.blue;
      default: return AppTheme.primaryGreen;
    }
  }

  IconData get _scheduleIcon {
    switch (mosque.scheduleType) {
      case 'summerOnly': return Icons.wb_sunny;
      case 'winterOnly': return Icons.ac_unit;
      default: return Icons.calendar_month;
    }
  }

  String get _workHours {
    final parts = <String>[];
    if (mosque.morningFrom != null && mosque.morningTo != null) {
      parts.add('صباح: ${mosque.morningFrom} - ${mosque.morningTo}');
    }
    if (mosque.eveningFrom != null && mosque.eveningTo != null) {
      parts.add('مساء: ${mosque.eveningFrom} - ${mosque.eveningTo}');
    }
    return parts.isEmpty ? 'لم تُحدد المواعيد' : parts.join('  |  ');
  }

  @override
  Widget build(BuildContext context) {
    final displayName = mosque.name.isNotEmpty
        ? mosque.name
        : 'مسجد غير مسمى';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المسجد
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mosque, color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          if (onDelete != null)
                            GestureDetector(
                              onTap: onDelete,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _formatId(mosque.id),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // إحصائيات
            Row(
              children: [
                _InfoChip(icon: Icons.people, label: '${mosque.studentCount} طالب', color: Colors.blue),
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.menu_book, label: '${mosque.halqaCount} حلقة', color: Colors.purple),
                const Spacer(),
                // نوع الدوام
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scheduleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _scheduleColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_scheduleIcon, size: 13, color: _scheduleColor),
                      const SizedBox(width: 4),
                      Text(_scheduleLabel,
                          style: TextStyle(fontSize: 11, color: _scheduleColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // مواعيد العمل
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(_workHours,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatId(String id) {
    if (id.length < 12) return id;
    return '${id.substring(0, 4)}-${id.substring(4, 8)}-${id.substring(8, 12)}';
  }
}

// ─── مكونات مساعدة ─────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
