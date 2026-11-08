import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_service.dart';

/// بعد تحديث التطبيق، المعلم المسجَّل مسبقاً لا يعرف التطبيق إلا هاش كلمة سره، فلا يمكنه
/// تشفير نسخة للأوقاف. نطلب منه مرة واحدة إدخال كلمة سر مسجده (نتحقق منها عبر السيرفر)،
/// ثم تُحفظ نسخة مشفّرة لا يفكها إلا الأوقاف.
class VaultPrompt {
  static String _doneKey(String id) => 'vault_done_$id';
  static String _snoozeKey(String id) => 'vault_snooze_$id';

  static Future<void> maybeAsk(BuildContext context) async {
    final sync = SyncService();
    final id = sync.currentMosqueId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey(id)) == true) return;
    if (DateTime.now().millisecondsSinceEpoch < (prefs.getInt(_snoozeKey(id)) ?? 0)) return;

    // لا نزعج المعلم قبل أن تجهّز الأوقاف خزنتها (لا يوجد مفتاح عام بعد)
    try {
      if (await sync.getVaultPublicKey().timeout(const Duration(seconds: 8)) == null) return;
    } catch (_) {
      return;
    }
    if (!context.mounted) return;

    final ctrl = TextEditingController();
    String? error;
    bool busy = false;
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('تأكيد كلمة سر المسجد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'لنساعدك إذا نسيت كلمة السر، تُحفظ نسخة منها مشفّرة، ولا يراها إلا الأوقاف. '
                  'أدخلها مرة واحدة فقط.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'كلمة سر المسجد'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx, false),
                child: const Text('لاحقاً'),
              ),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final pw = ctrl.text.trim();
                        if (pw.isEmpty) return;
                        setLocal(() { busy = true; error = null; });
                        try {
                          final hash = sha256.convert(utf8.encode('$id:$pw')).toString();
                          // السيرفر يتحقق من صحة الكلمة (يرفض الجلسة إن كانت خاطئة)
                          if (!await sync.teacherLogin(id, hash, migrate: false)) {
                            setLocal(() { busy = false; error = 'كلمة السر غير صحيحة'; });
                            return;
                          }
                          if (await sync.uploadMosquePasswordToVault(id, pw)) {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } else {
                            setLocal(() { busy = false; error = 'تعذّر الحفظ، تأكد من الاتصال وحاول لاحقاً'; });
                          }
                        } catch (_) {
                          setLocal(() { busy = false; error = 'تعذّر الاتصال، تأكد من الإنترنت'; });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('تأكيد'),
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();

    if (done == true) {
      await prefs.setBool(_doneKey(id), true);
    } else {
      // "لاحقاً": نعيد السؤال بعد يومين
      await prefs.setInt(_snoozeKey(id),
          DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch);
    }
  }
}
