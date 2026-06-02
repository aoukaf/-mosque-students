import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sync_service.dart';
import '../models/student.dart';
import '../models/app_theme.dart';

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
  List<Student> _students = [];
  List<String> _halqas = [];

  @override
  void initState() {
    super.initState();
    _studentsSub = _sync.watchMosqueStudents(widget.mosque.id).listen(
      (list) { if (mounted) setState(() => _students = list); },
    );
    _halqasSub = _sync.watchMosqueHalqas(widget.mosque.id).listen(
      (list) { if (mounted) setState(() => _halqas = list); },
    );
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _halqasSub?.cancel();
    super.dispose();
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
                          _HStat(icon: Icons.people,    value: '${mosque.studentCount}', label: 'طالب'),
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

            // ─── مواعيد الدوام ───
            if (mosque.morningFrom != null || mosque.days.isNotEmpty)
              SliverToBoxAdapter(child: _InfoCard(mosque: mosque)),

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

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final halqa = grouped.keys.elementAt(i);
                    final students = grouped[halqa]!;
                    return _HalqaCard(halqa: halqa, students: students);
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

// ─── بطاقة الحلقة قابلة للتوسيع ────────────────────────

class _HalqaCard extends StatelessWidget {
  final String halqa;
  final List<Student> students;
  const _HalqaCard({required this.halqa, required this.students});

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
            child: Row(
              children: [
                _MiniChip(icon: Icons.people,    label: '${students.length} طالب',  color: Colors.blue),
                const SizedBox(width: 6),
                _MiniChip(icon: Icons.menu_book, label: '$totalParts جزء',          color: Colors.green),
                const SizedBox(width: 6),
                _MiniChip(icon: Icons.star,      label: '$totalStars نجمة',         color: Colors.amber),
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
              : students.map((s) => _StudentRow(student: s)).toList(),
        ),
      ),
    );
  }
}

// ─── صف الطالب ──────────────────────────────────────────

class _StudentRow extends StatelessWidget {
  final Student student;
  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final progress = (student.partsCompleted / 30).clamp(0.0, 1.0);
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

