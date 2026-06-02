import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/student.dart';
import '../models/sync_service.dart';
import '../models/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/student_card.dart';
import '../widgets/sync_status_bar.dart';
import '../widgets/alphanet_branding.dart';
import '../services/update_service.dart';
import 'add_edit_student_screen.dart';
import 'student_detail_screen.dart';
import 'halqas_screen.dart';
import 'statistics_screen.dart';
import 'attendance_screen.dart';
import 'mosque_settings_screen.dart';
import 'homework_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SyncService _sync = SyncService();

  List<Student> _students = [];
  List<String> _halqas = [];
  StreamSubscription<List<Student>>? _studentsSub;
  StreamSubscription<List<String>>? _halqasSub;

  String _searchQuery = '';
  String _filterHalqa = 'الكل';
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _listenToData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkAndPrompt(context);
    });
  }

  void _listenToData() {
    // استماع لحظي للطلاب من Firebase
    _studentsSub = _sync.watchStudents().listen(
      (students) => setState(() => _students = students),
      onError: (_) async {
        // fallback للنسخة المحلية
        final local = await _sync.getStudents();
        setState(() => _students = local);
      },
    );

    // استماع لحظي للحلقات من Firebase (الـ stream يجلب من الـ cache فوراً)
    _halqasSub = _sync.watchHalqas().listen(
      (halqas) {
        if (halqas.isNotEmpty && mounted) setState(() => _halqas = halqas);
      },
      onError: (_) async {
        final local = await _sync.getHalqas();
        if (mounted) setState(() => _halqas = local);
      },
    );
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _halqasSub?.cancel();
    super.dispose();
  }

  List<Student> get _filteredStudents {
    var list = [..._students];
    if (_filterHalqa != 'الكل') {
      list = list.where((s) => s.halqa == _filterHalqa).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((s) =>
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.halqa.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    switch (_sortBy) {
      case 'stars': list.sort((a, b) => b.stars.compareTo(a.stars)); break;
      case 'parts': list.sort((a, b) => b.partsCompleted.compareTo(a.partsCompleted)); break;
      default: list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  Future<void> _addStudent() async {
    final result = await Navigator.push<Student>(
      context,
      MaterialPageRoute(builder: (_) => AddEditStudentScreen(
        halqas: _halqas,
        initialHalqa: _filterHalqa == 'الكل' ? null : _filterHalqa,
      )),
    );
    if (result != null) {
      try {
        await _sync.addStudent(result);
      } catch (e) {
        if (mounted) _showError('تعذّر إضافة الطالب، تحقق من الاتصال');
      }
    }
  }

  Future<void> _editStudent(Student student) async {
    final result = await Navigator.push<Student>(
      context,
      MaterialPageRoute(builder: (_) => AddEditStudentScreen(student: student, halqas: _halqas)),
    );
    if (result != null) {
      try {
        await _sync.updateStudent(result);
      } catch (e) {
        if (mounted) _showError('تعذّر تعديل البيانات، تحقق من الاتصال');
      }
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final r = Responsive(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف الطالب', style: TextStyle(fontSize: r.fontSize(18))),
        content: Text('هل تريد حذف الطالب "${student.name}"؟'),
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
        await _sync.deleteStudent(student.id);
      } catch (e) {
        if (mounted) _showError('تعذّر حذف الطالب، تحقق من الاتصال');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final filtered = _filteredStudents;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🕌 سجلات طلاب المسجد',
          style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17), fontWeight: FontWeight.bold),
        ),
        toolbarHeight: r.isTablet ? 64 : 56,
        actions: [
          // مؤشر الاتصال
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: SyncIndicator(),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, size: r.iconSize(24)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => StatisticsScreen(students: _students))),
          ),
          IconButton(
            icon: Icon(Icons.checklist, size: r.iconSize(24)),
            tooltip: 'سجل الحضور',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AttendanceScreen(students: _students, halqas: _halqas))),
          ),
          IconButton(
            icon: Icon(Icons.assignment, size: r.iconSize(24)),
            tooltip: 'سجل الوظائف',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => HomeworkScreen(students: _students, halqas: _halqas))),
          ),
          IconButton(
            icon: Icon(Icons.groups, size: r.iconSize(24)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HalqasScreen())),
          ),
          IconButton(
            icon: Icon(Icons.settings, size: r.iconSize(24)),
            tooltip: 'إعدادات المسجد',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MosqueSettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        backgroundColor: AppTheme.primaryGreen,
        icon: Icon(Icons.person_add, color: Colors.white, size: r.iconSize(22)),
        label: Text('إضافة طالب', style: TextStyle(color: Colors.white, fontSize: r.fontSize(14))),
      ),
      body: Stack(
        children: [
          Column(
            children: [
          // شريط حالة الاتصال (يظهر فقط إذا offline)
          const SyncStatusBar(),

          // Summary banner
          _SummaryBanner(students: _students, r: r),

          // Search & Filter
          Padding(
            padding: EdgeInsets.fromLTRB(r.sp(12), r.sp(8), r.sp(12), 0),
            child: Column(
              children: [
                TextField(
                  textDirection: TextDirection.rtl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(fontSize: r.fontSize(14)),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الحلقة...',
                    hintStyle: TextStyle(fontSize: r.fontSize(13)),
                    prefixIcon: Icon(Icons.search, size: r.iconSize(22)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: r.iconSize(20)),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.sp(16), vertical: r.sp(r.isTablet ? 14 : 10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                SizedBox(height: r.sp(8)),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(label: 'الكل', selected: _filterHalqa == 'الكل',
                                onTap: () => setState(() => _filterHalqa = 'الكل'), r: r),
                            ..._halqas.map((h) => _FilterChip(
                                label: h, selected: _filterHalqa == h,
                                onTap: () => setState(() => _filterHalqa = h), r: r)),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.sort, color: AppTheme.primaryGreen, size: r.iconSize(24)),
                      onSelected: (v) => setState(() => _sortBy = v),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'name', child: Text('ترتيب حسب الاسم', style: TextStyle(fontSize: r.fontSize(14)))),
                        PopupMenuItem(value: 'stars', child: Text('ترتيب حسب النجوم', style: TextStyle(fontSize: r.fontSize(14)))),
                        PopupMenuItem(value: 'parts', child: Text('ترتيب حسب الأجزاء', style: TextStyle(fontSize: r.fontSize(14)))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.sp(16), vertical: r.sp(4)),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('${filtered.length} طالب',
                  style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(13))),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: r.sp(80), color: Colors.grey[400]),
                        SizedBox(height: r.sp(16)),
                        Text(
                          _students.isEmpty
                              ? 'لا يوجد طلاب بعد\nاضغط + لإضافة طالب'
                              : 'لا توجد نتائج مطابقة',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: r.fontSize(15)),
                        ),
                      ],
                    ),
                  )
                : r.isTablet
                    ? GridView.builder(
                        padding: EdgeInsets.fromLTRB(r.sp(12), 0, r.sp(12), r.sp(80)),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: r.sp(4),
                          mainAxisSpacing: r.sp(4),
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => StudentCard(
                          student: filtered[i],
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => StudentDetailScreen(student: filtered[i]))),
                          onEdit: () => _editStudent(filtered[i]),
                          onDelete: () => _deleteStudent(filtered[i]),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: r.sp(80)),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => StudentCard(
                          student: filtered[i],
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => StudentDetailScreen(student: filtered[i]))),
                          onEdit: () => _editStudent(filtered[i]),
                          onDelete: () => _deleteStudent(filtered[i]),
                        ),
                      ),
          ),
        ],
          ),
          // شعار ألفا نت - زاوية سفلية يمنى
          const Positioned(
            bottom: 16,
            right: 16,
            child: AlphaNetBranding(),
          ),
        ],
      ),
    );
  }
}

// ===== Summary Banner =====
class _SummaryBanner extends StatelessWidget {
  final List<Student> students;
  final Responsive r;
  const _SummaryBanner({required this.students, required this.r});

  @override
  Widget build(BuildContext context) {
    final totalStars = students.fold(0, (s, st) => s + st.stars);
    final totalParts = students.fold(0, (s, st) => s + st.partsCompleted);
    return Container(
      color: AppTheme.primaryGreen,
      padding: EdgeInsets.fromLTRB(r.sp(16), 0, r.sp(16), r.sp(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BStat(icon: Icons.people, value: '${students.length}', label: 'طالب', r: r),
          _BStat(icon: Icons.menu_book, value: '$totalParts', label: 'جزء', r: r),
          _BStat(icon: Icons.star, value: '$totalStars', label: 'نجمة', r: r),
          StreamBuilder<List<ConnectivityResult>>(
            stream: Connectivity().onConnectivityChanged,
            builder: (ctx, snap) {
              final isOnline = snap.data?.any((r) => r != ConnectivityResult.none) ?? true;
              final color = isOnline ? Colors.greenAccent : Colors.orangeAccent;
              return Row(
                children: [
                  Icon(isOnline ? Icons.sync : Icons.sync_disabled, color: color, size: r.iconSize(14)),
                  SizedBox(width: r.sp(4)),
                  Text(isOnline ? 'مباشر' : 'غير متصل',
                      style: TextStyle(color: color, fontSize: r.fontSize(11))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Responsive r;
  const _BStat({required this.icon, required this.value, required this.label, required this.r});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: r.iconSize(18)),
        SizedBox(width: r.sp(5)),
        Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.fontSize(r.isTablet ? 20 : 17))),
        SizedBox(width: r.sp(3)),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: r.fontSize(12))),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Responsive r;
  const _FilterChip({required this.label, required this.selected, required this.onTap, required this.r});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: r.sp(8)),
        padding: EdgeInsets.symmetric(horizontal: r.sp(14), vertical: r.sp(6)),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(r.radius(20)),
          border: Border.all(color: selected ? AppTheme.primaryGreen : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: r.fontSize(r.isTablet ? 14 : 13),
          ),
        ),
      ),
    );
  }
}
