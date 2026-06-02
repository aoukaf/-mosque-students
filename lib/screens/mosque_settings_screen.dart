import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/sync_service.dart';
import '../models/app_theme.dart';

class MosqueSettingsScreen extends StatefulWidget {
  const MosqueSettingsScreen({super.key});

  @override
  State<MosqueSettingsScreen> createState() => _MosqueSettingsScreenState();
}

class _MosqueSettingsScreenState extends State<MosqueSettingsScreen> {
  final _sync = SyncService();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _scheduleType = 'yearRound';
  final List<String> _allDays = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
  final Set<String> _selectedDays = {};

  TimeOfDay? _morningFrom;
  TimeOfDay? _morningTo;
  TimeOfDay? _eveningFrom;
  TimeOfDay? _eveningTo;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    final info = await _sync.getMosqueInfo();
    if (info != null && mounted) {
      setState(() {
        _nameCtrl.text = info.name;
        _scheduleType = info.scheduleType;
        _selectedDays.addAll(info.days);
        _morningFrom = _parseTime(info.morningFrom);
        _morningTo   = _parseTime(info.morningTo);
        _eveningFrom = _parseTime(info.eveningFrom);
        _eveningTo   = _parseTime(info.eveningTo);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isMorning, bool isFrom) async {
    final initial = isMorning
        ? (isFrom ? _morningFrom : _morningTo)
        : (isFrom ? _eveningFrom : _eveningTo);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isMorning) {
        if (isFrom) {
          _morningFrom = picked;
        } else {
          _morningTo = picked;
        }
      } else {
        if (isFrom) {
          _eveningFrom = picked;
        } else {
          _eveningTo = picked;
        }
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم المسجد')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final pw = _passwordCtrl.text.trim();
      String? newHash;
      if (pw.isNotEmpty) {
        final mosqueId = _sync.currentMosqueId ?? '';
        newHash = sha256.convert(utf8.encode('$mosqueId:$pw')).toString();
      }
      await _sync.updateMosqueInfo(
        name: name,
        passwordHash: newHash,
        scheduleType: _scheduleType,
        days: _selectedDays.toList(),
        morningFrom: _morningFrom != null ? _formatTime(_morningFrom!) : null,
        morningTo:   _morningTo   != null ? _formatTime(_morningTo!)   : null,
        eveningFrom: _eveningFrom != null ? _formatTime(_eveningFrom!) : null,
        eveningTo:   _eveningTo   != null ? _formatTime(_eveningTo!)   : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ، تأكد من الاتصال'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات المسجد'),
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── اسم المسجد ───
                    const _SectionTitle('اسم المسجد'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: _inputDec('مثال: مسجد النور'),
                    ),


                    const SizedBox(height: 24),

                    // ─── نوع الدوام ───
                    const _SectionTitle('نوع الدوام'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ScheduleChip(label: 'مستمر', value: 'yearRound',   icon: Icons.calendar_month, selected: _scheduleType, onTap: (v) => setState(() => _scheduleType = v)),
                        const SizedBox(width: 8),
                        _ScheduleChip(label: 'صيفي فقط', value: 'summerOnly', icon: Icons.wb_sunny,       selected: _scheduleType, onTap: (v) => setState(() => _scheduleType = v)),
                        const SizedBox(width: 8),
                        _ScheduleChip(label: 'شتوي فقط', value: 'winterOnly', icon: Icons.ac_unit,        selected: _scheduleType, onTap: (v) => setState(() => _scheduleType = v)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ─── أيام الدوام ───
                    const _SectionTitle('أيام الدوام'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allDays.map((day) {
                        final sel = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day, style: TextStyle(fontSize: 13, color: sel ? Colors.white : Colors.black87)),
                          selected: sel,
                          selectedColor: AppTheme.primaryGreen,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                          }),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ─── فترة الصباح ───
                    const _SectionTitle('فترة الصباح'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _TimeButton(label: 'من', time: _morningFrom, onTap: () => _pickTime(true, true))),
                        const SizedBox(width: 12),
                        Expanded(child: _TimeButton(label: 'إلى', time: _morningTo,   onTap: () => _pickTime(true, false))),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ─── فترة المساء ───
                    Row(
                      children: [
                        const _SectionTitle('فترة المساء'),
                        const SizedBox(width: 8),
                        Text('(اختياري)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _TimeButton(label: 'من', time: _eveningFrom, onTap: () => _pickTime(false, true))),
                        const SizedBox(width: 12),
                        Expanded(child: _TimeButton(label: 'إلى', time: _eveningTo,   onTap: () => _pickTime(false, false))),
                      ],
                    ),
                    if (_eveningFrom != null || _eveningTo != null) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () => setState(() { _eveningFrom = null; _eveningTo = null; }),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('مسح فترة المساء', style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ─── زر الحفظ ───
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
}

class _ScheduleChip extends StatelessWidget {
  final String label, value, selected;
  final IconData icon;
  final void Function(String) onTap;
  const _ScheduleChip({required this.label, required this.value, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    final color = value == 'summerOnly' ? Colors.orange : value == 'winterOnly' ? Colors.blue : AppTheme.primaryGreen;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.grey.shade700, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  const _TimeButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasTime = time != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasTime ? AppTheme.primaryGreen.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasTime ? AppTheme.primaryGreen.withValues(alpha: 0.4) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text(
              hasTime ? '${time!.hour.toString().padLeft(2,'0')}:${time!.minute.toString().padLeft(2,'0')}' : '--:--',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: hasTime ? AppTheme.primaryGreen : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
