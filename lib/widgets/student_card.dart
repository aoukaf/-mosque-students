import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/student.dart';
import '../models/app_theme.dart';
import '../utils/responsive.dart';

class StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(5)),
      child: Slidable(
        key: ValueKey(student.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'تعديل',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'حذف',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.cardBorderRadius),
            ),
            child: Padding(
              padding: r.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main content row
                  Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: r.avatarRadius,
                        backgroundColor: AppTheme.primaryGreen,
                        child: Text(
                          student.name.isNotEmpty ? student.name[0] : '؟',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fontSize(r.isTablet ? 26 : 20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: r.sp(12)),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontSize: r.fontSize(r.isTablet ? 19 : 16),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: r.sp(3)),
                            Row(
                              children: [
                                Icon(Icons.circle, size: r.iconSize(8), color: AppTheme.lightGreen),
                                SizedBox(width: r.sp(5)),
                                Flexible(
                                  child: Text(
                                    student.halqa,
                                    style: TextStyle(fontSize: r.fontSize(12), color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: r.sp(6)),
                            Wrap(
                              spacing: r.sp(6),
                              runSpacing: r.sp(4),
                              children: [
                                _InfoBadge(icon: Icons.menu_book, label: '${student.partsCompleted}/30 جزء', color: AppTheme.lightGreen, r: r),
                                _InfoBadge(icon: Icons.star, label: '${student.stars} ⭐', color: AppTheme.accentGold, r: r),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: r.sp(8)),

                      // Progress ring
                      SizedBox(
                        width: r.sp(r.isTablet ? 60 : 48),
                        height: r.sp(r.isTablet ? 60 : 48),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: student.partsCompleted / 30,
                              strokeWidth: r.sp(5),
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation(AppTheme.lightGreen),
                            ),
                            Text(
                              '${((student.partsCompleted / 30) * 100).round()}%',
                              style: TextStyle(
                                fontSize: r.fontSize(r.isTablet ? 12 : 10),
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Swipe hint
                  SizedBox(height: r.sp(6)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'اسحب للتعديل أو الحذف',
                        style: TextStyle(fontSize: r.fontSize(10), color: Colors.grey.shade400),
                      ),
                      SizedBox(width: r.sp(2)),
                      Icon(Icons.chevron_left, size: r.iconSize(14), color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Responsive r;

  const _InfoBadge({required this.icon, required this.label, required this.color, required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.sp(8), vertical: r.sp(3)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(r.radius(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.iconSize(13), color: color),
          SizedBox(width: r.sp(4)),
          Text(label, style: TextStyle(fontSize: r.fontSize(11), color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
