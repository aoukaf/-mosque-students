import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/student.dart';
import '../models/app_theme.dart';
import '../utils/responsive.dart';

class AddEditStudentScreen extends StatefulWidget {
  final Student? student;
  final List<String> halqas;
  final String? initialHalqa;

  const AddEditStudentScreen({super.key, this.student, required this.halqas, this.initialHalqa});

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _starsCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _halqaCtrl;
  late int _partsCompleted;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _starsCtrl = TextEditingController(text: s?.stars.toString() ?? '0');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _halqaCtrl = TextEditingController(text: s?.halqa ?? widget.initialHalqa ?? '');
    _partsCompleted = s?.partsCompleted ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _starsCtrl.dispose();
    _notesCtrl.dispose();
    _halqaCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    int stars = int.tryParse(_starsCtrl.text) ?? 0;
    stars = stars.clamp(0, 5000);

    final student = Student(
      id: widget.student?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      halqa: _halqaCtrl.text.trim(),
      partsCompleted: _partsCompleted,
      stars: stars,
      notes: _notesCtrl.text.trim(),
      createdAt: widget.student?.createdAt,
    );
    Navigator.pop(context, student);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isEdit = widget.student != null;

    // تابلت: نستخدم مخطط عمودين
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'تعديل بيانات الطالب' : 'إضافة طالب جديد',
          style: TextStyle(fontSize: r.fontSize(r.isTablet ? 20 : 17)),
        ),
        toolbarHeight: r.isTablet ? 64 : 56,
      ),
      body: Form(
        key: _formKey,
        child: r.isTablet
            ? _TabletLayout(
                r: r,
                isEdit: isEdit,
                nameCtrl: _nameCtrl,
                starsCtrl: _starsCtrl,
                notesCtrl: _notesCtrl,
                halqaCtrl: _halqaCtrl,
                partsCompleted: _partsCompleted,
                onPartsChanged: (v) => setState(() => _partsCompleted = v),
                onStarsChanged: () => setState(() {}),
                onSave: _save,
              )
            : _PhoneLayout(
                r: r,
                isEdit: isEdit,
                nameCtrl: _nameCtrl,
                starsCtrl: _starsCtrl,
                notesCtrl: _notesCtrl,
                halqaCtrl: _halqaCtrl,
                partsCompleted: _partsCompleted,
                onPartsChanged: (v) => setState(() => _partsCompleted = v),
                onStarsChanged: () => setState(() {}),
                onSave: _save,
              ),
      ),
    );
  }
}

// ===================== Phone Layout =====================
class _PhoneLayout extends StatelessWidget {
  final Responsive r;
  final bool isEdit;
  final TextEditingController nameCtrl, starsCtrl, notesCtrl, halqaCtrl;
  final int partsCompleted;
  final void Function(int) onPartsChanged;
  final VoidCallback onStarsChanged;
  final VoidCallback onSave;

  const _PhoneLayout({
    required this.r, required this.isEdit,
    required this.nameCtrl, required this.starsCtrl, required this.notesCtrl,
    required this.halqaCtrl, required this.partsCompleted,
    required this.onPartsChanged, required this.onStarsChanged, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: r.pagePadding,
      children: [
        _AvatarHeader(r: r),
        SizedBox(height: r.sp(20)),
        _NameField(r: r, ctrl: nameCtrl),
        SizedBox(height: r.sp(16)),
        _HalqaField(r: r, ctrl: halqaCtrl),
        SizedBox(height: r.sp(16)),
        _PartsField(r: r, parts: partsCompleted, onChanged: onPartsChanged),
        SizedBox(height: r.sp(16)),
        _StarsField(r: r, ctrl: starsCtrl, onChanged: onStarsChanged),
        SizedBox(height: r.sp(16)),
        _NotesField(r: r, ctrl: notesCtrl),
        SizedBox(height: r.sp(28)),
        _SaveButton(r: r, isEdit: isEdit, onSave: onSave),
        SizedBox(height: r.sp(20)),
      ],
    );
  }
}

// ===================== Tablet Layout =====================
class _TabletLayout extends StatelessWidget {
  final Responsive r;
  final bool isEdit;
  final TextEditingController nameCtrl, starsCtrl, notesCtrl, halqaCtrl;
  final int partsCompleted;
  final void Function(int) onPartsChanged;
  final VoidCallback onStarsChanged;
  final VoidCallback onSave;

  const _TabletLayout({
    required this.r, required this.isEdit,
    required this.nameCtrl, required this.starsCtrl, required this.notesCtrl,
    required this.halqaCtrl, required this.partsCompleted,
    required this.onPartsChanged, required this.onStarsChanged, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.sp(24)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              _AvatarHeader(r: r),
              SizedBox(height: r.sp(24)),
              // Row 1: Name + Halqa
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _NameField(r: r, ctrl: nameCtrl)),
                  SizedBox(width: r.sp(16)),
                  Expanded(child: _HalqaField(r: r, ctrl: halqaCtrl)),
                ],
              ),
              SizedBox(height: r.sp(16)),
              // Row 2: Parts + Stars
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _PartsField(r: r, parts: partsCompleted, onChanged: onPartsChanged)),
                  SizedBox(width: r.sp(16)),
                  Expanded(child: _StarsField(r: r, ctrl: starsCtrl, onChanged: onStarsChanged)),
                ],
              ),
              SizedBox(height: r.sp(16)),
              _NotesField(r: r, ctrl: notesCtrl),
              SizedBox(height: r.sp(28)),
              _SaveButton(r: r, isEdit: isEdit, onSave: onSave),
              SizedBox(height: r.sp(20)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Shared Sub-widgets =====================

class _AvatarHeader extends StatelessWidget {
  final Responsive r;
  const _AvatarHeader({required this.r});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: r.sp(r.isTablet ? 90 : 72),
        height: r.sp(r.isTablet ? 90 : 72),
        decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
        child: Icon(Icons.person_add, color: Colors.white, size: r.iconSize(r.isTablet ? 48 : 36)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Responsive r;
  const _SectionTitle({required this.title, required this.r});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: r.fontSize(r.isTablet ? 16 : 14), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
    );
  }
}

class _NameField extends StatelessWidget {
  final Responsive r;
  final TextEditingController ctrl;
  const _NameField({required this.r, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'اسم الطالب', r: r),
        SizedBox(height: r.sp(8)),
        TextFormField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: r.fontSize(14)),
          decoration: InputDecoration(
            hintText: 'أدخل اسم الطالب',
            hintStyle: TextStyle(fontSize: r.fontSize(13)),
            prefixIcon: Icon(Icons.person, size: r.iconSize(22)),
            contentPadding: EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(14)),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم' : null,
        ),
      ],
    );
  }
}

class _HalqaField extends StatelessWidget {
  final Responsive r;
  final TextEditingController ctrl;
  const _HalqaField({required this.r, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'الحلقة', r: r),
        SizedBox(height: r.sp(8)),
        TextFormField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: r.fontSize(14)),
          decoration: InputDecoration(
            hintText: 'أدخل اسم الحلقة',
            hintStyle: TextStyle(fontSize: r.fontSize(13)),
            prefixIcon: Icon(Icons.groups, size: r.iconSize(22)),
            contentPadding: EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(14)),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الحلقة' : null,
        ),
      ],
    );
  }
}

class _PartsField extends StatelessWidget {
  final Responsive r;
  final int parts;
  final void Function(int) onChanged;
  const _PartsField({required this.r, required this.parts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'عدد الأجزاء المكتملة (من 30)', r: r),
        SizedBox(height: r.sp(8)),
        Container(
          padding: r.cardPadding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.radius(12)),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$parts / 30',
                    style: TextStyle(fontSize: r.fontSize(20), fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                  Row(
                    children: [
                      _RoundBtn(label: '-', color: AppTheme.primaryGreen, r: r, onTap: () { if (parts > 0) onChanged(parts - 1); }),
                      SizedBox(width: r.sp(10)),
                      _RoundBtn(label: '+', color: AppTheme.primaryGreen, r: r, onTap: () { if (parts < 30) onChanged(parts + 1); }),
                    ],
                  ),
                ],
              ),
              SizedBox(height: r.sp(8)),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.lightGreen,
                  thumbColor: AppTheme.primaryGreen,
                  inactiveTrackColor: Colors.grey[300],
                ),
                child: Slider(
                  value: parts.toDouble(),
                  min: 0, max: 30, divisions: 30,
                  label: '$parts',
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StarsField extends StatelessWidget {
  final Responsive r;
  final TextEditingController ctrl;
  final VoidCallback onChanged;
  const _StarsField({required this.r, required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'عدد النجوم ⭐ (0 - 5000)', r: r),
        SizedBox(height: r.sp(8)),
        Container(
          padding: r.cardPadding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.radius(12)),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: AppTheme.goldStar, size: r.iconSize(26)),
                      SizedBox(width: r.sp(6)),
                      Text(
                        ctrl.text,
                        style: TextStyle(fontSize: r.fontSize(20), fontWeight: FontWeight.bold, color: AppTheme.accentGold),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: r.sp(4),
                    children: [
                      _RoundBtn(label: '-5', color: AppTheme.accentGold, r: r, onTap: () {
                        int v = int.tryParse(ctrl.text) ?? 0;
                        if (v >= 5) { ctrl.text = (v - 5).toString(); onChanged(); }
                      }),
                      _RoundBtn(label: '-1', color: AppTheme.accentGold, r: r, onTap: () {
                        int v = int.tryParse(ctrl.text) ?? 0;
                        if (v > 0) { ctrl.text = (v - 1).toString(); onChanged(); }
                      }),
                      _RoundBtn(label: '+1', color: AppTheme.accentGold, r: r, onTap: () {
                        int v = int.tryParse(ctrl.text) ?? 0;
                        if (v < 5000) { ctrl.text = (v + 1).toString(); onChanged(); }
                      }),
                      _RoundBtn(label: '+5', color: AppTheme.accentGold, r: r, onTap: () {
                        int v = int.tryParse(ctrl.text) ?? 0;
                        if (v + 5 <= 5000) { ctrl.text = (v + 5).toString(); onChanged(); }
                      }),
                    ],
                  ),
                ],
              ),
              SizedBox(height: r.sp(10)),
              TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: r.fontSize(14)),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'أو اكتب العدد مباشرة',
                  hintStyle: TextStyle(fontSize: r.fontSize(12)),
                  suffixText: '/ 5000',
                  contentPadding: EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(10)),
                ),
                onChanged: (v) {
                  int val = int.tryParse(v) ?? 0;
                  if (val > 5000) {
                    ctrl.text = '5000';
                    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                  }
                  onChanged();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotesField extends StatelessWidget {
  final Responsive r;
  final TextEditingController ctrl;
  const _NotesField({required this.r, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'ملاحظات (اختياري)', r: r),
        SizedBox(height: r.sp(8)),
        TextFormField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          maxLines: r.isTablet ? 4 : 3,
          style: TextStyle(fontSize: r.fontSize(14)),
          decoration: InputDecoration(
            hintText: 'أي ملاحظات إضافية...',
            hintStyle: TextStyle(fontSize: r.fontSize(13)),
            prefixIcon: Icon(Icons.notes, size: r.iconSize(22)),
            contentPadding: EdgeInsets.symmetric(horizontal: r.sp(12), vertical: r.sp(12)),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final Responsive r;
  final bool isEdit;
  final VoidCallback onSave;
  const _SaveButton({required this.r, required this.isEdit, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onSave,
        icon: Icon(Icons.save, size: r.iconSize(22)),
        label: Text(
          isEdit ? 'حفظ التعديلات' : 'إضافة الطالب',
          style: TextStyle(fontSize: r.fontSize(r.isTablet ? 18 : 15)),
        ),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: r.sp(r.isTablet ? 18 : 14)),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Responsive r;
  final VoidCallback onTap;
  const _RoundBtn({required this.label, required this.color, required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.sp(10), vertical: r.sp(6)),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(r.radius(20))),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: r.fontSize(13))),
      ),
    );
  }
}
