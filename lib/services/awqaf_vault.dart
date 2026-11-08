import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../models/sync_service.dart';
import 'vault_crypto.dart';

/// خزنة كلمات سر المساجد عند الأوقاف.
///
/// - تطبيق المعلم يشفّر كلمة سر مسجده بمفتاح الأوقاف **العام** تلقائياً (عند الدخول أو التغيير).
/// - الأوقاف تفكّها بمفتاحها **الخاص**، وهو مخزّن مشفّراً بكلمة سر الأوقاف.
/// - عند إدخال كلمة سر الأوقاف (مرة بكل تشغيل) تُفتح الخزنة وتظهر كل الكلمات فوراً.
/// - المفتاح الخاص يبقى بالذاكرة فقط، ولا يُكتب على القرص.
class AwqafVault {
  static String? _priv;
  static String? _pub;

  static bool get isUnlocked => _priv != null && _pub != null;

  static void lock() {
    _priv = null;
    _pub = null;
  }

  static String hashOf(String awqafPassword) =>
      sha256.convert(utf8.encode('awqaf:$awqafPassword')).toString();

  /// يفتح الخزنة (وينشئ المفاتيح أول مرة). false = كلمة السر لا تفك مفتاح الخزنة الحالي.
  static Future<bool> unlock(String awqafPassword) async {
    final sync = SyncService();
    final pub = await sync.getVaultPublicKey();
    final wrapped = await sync.getWrappedVaultPrivate();
    if (pub != null && wrapped != null) {
      final priv = await VaultCrypto.decrypt(wrapped, awqafPassword);
      if (priv == null) return false;
      _priv = priv;
      _pub = pub;
      return true;
    }
    await reset(awqafPassword); // أول مرة
    return true;
  }

  /// مفاتيح جديدة (أول مرة أو إعادة ضبط). الكلمات المشفّرة بالمفتاح القديم لا تُفك وتحتاج إعادة تسجيل.
  static Future<void> reset(String awqafPassword) async {
    final kp = await VaultCrypto.generateKeyPair();
    await SyncService().saveVaultKeys(
      pub: kp.pub,
      wrappedPrivate: await VaultCrypto.encrypt(kp.priv, awqafPassword),
    );
    _priv = kp.priv;
    _pub = kp.pub;
  }

  /// بعد تغيير كلمة سر الأوقاف: نعيد تغليف المفتاح الخاص بالكلمة الجديدة
  static Future<void> rewrap(String oldPassword, String newPassword) async {
    final sync = SyncService();
    final wrapped = await sync.getWrappedVaultPrivate();
    if (wrapped == null) return;
    final priv = await VaultCrypto.decrypt(wrapped, oldPassword);
    if (priv == null) return;
    await sync.saveWrappedVaultPrivate(await VaultCrypto.encrypt(priv, newPassword));
  }

  /// كلمة سر المسجد بنص صريح، أو null إذا لم تُسجَّل أو لا تُفك بهذا المفتاح
  static Future<String?> readMosquePassword(String mosqueId) async {
    if (!isUnlocked) return null;
    final blob = await SyncService().getVaultBlob(mosqueId);
    if (blob == null) return null;
    return VaultCrypto.open(blob, _priv!, _pub!);
  }

  /// تسجيل يدوي لكلمة سر مسجد (للمساجد التي لم يدخل معلمها بعد بالنسخة الجديدة)
  static Future<void> storeMosquePassword(String mosqueId, String plain) async {
    final sync = SyncService();
    final pub = _pub ?? await sync.getVaultPublicKey();
    if (pub == null) throw StateError('الخزنة غير مفتوحة');
    await sync.saveVaultBlob(mosqueId, await VaultCrypto.seal(plain, pub));
  }

  /// حوار يطلب كلمة سر الأوقاف ويفتح الخزنة. true = أصبحت مفتوحة.
  static Future<bool> promptUnlock(BuildContext context) async {
    if (isUnlocked) return true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    void toast(String msg, {bool error = false}) => messenger?.showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: error ? Colors.red.shade700 : null,
        ));

    final ctrl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('فتح خزنة كلمات السر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('أدخل كلمة سر الأوقاف لتظهر كلمات سر المساجد.', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'كلمة سر الأوقاف'),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقاً')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('فتح'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (pw == null || pw.isEmpty) return false;

    try {
      // السيرفر هو من يتحقق من كلمة سر الأوقاف
      if (!await SyncService().awqafLogin(hashOf(pw), migrate: false)) {
        toast('كلمة سر الأوقاف غير صحيحة', error: true);
        return false;
      }
      if (await unlock(pw)) return true;

      // كلمة السر صحيحة لكنها لا تفك مفتاح الخزنة (مثلاً غُيّرت من Console بعد إنشاء الخزنة)
      if (!context.mounted) return false;
      final doReset = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إعادة ضبط الخزنة؟'),
            content: const Text(
                'كلمة السر صحيحة، لكنها لا تفك مفتاح الخزنة المحفوظ (غالباً غُيّرت بعد إنشائها).\n\n'
                'إعادة الضبط تنشئ مفتاحاً جديداً، وكلمات سر المساجد المحفوظة سابقاً لن تظهر '
                'وتحتاج تسجيلاً جديداً (يتم تلقائياً عند دخول المعلم).'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إعادة ضبط')),
            ],
          ),
        ),
      );
      if (doReset != true) return false;
      await reset(pw);
      toast('تمت إعادة ضبط الخزنة');
      return true;
    } catch (_) {
      toast('تعذّر الاتصال بالخزنة. تأكد من الإنترنت وأنك داخل بجلسة الأوقاف', error: true);
      return false;
    }
  }
}
