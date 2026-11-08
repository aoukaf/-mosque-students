import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// تشفير "خزنة الأوقاف": كلمات سر المساجد تُخزَّن مشفّرة بمفتاح مشتق من كلمة سر الأوقاف.
/// PBKDF2-HMAC-SHA256 لاشتقاق المفتاح، وAES-256-GCM للتشفير (مع ملح وnonce عشوائيين لكل قيمة).
/// لا يمكن فك أي قيمة بدون كلمة سر الأوقاف، حتى لو قُرئت الوثيقة.
class VaultCrypto {
  static const int _iterations = 120000;
  static const int _version = 1;

  static final _aes = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  static Future<String> encrypt(String plaintext, String awqafPassword) async {
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _kdf.deriveKeyFromPassword(password: awqafPassword, nonce: salt);
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    return jsonEncode({
      'v': _version,
      's': base64.encode(salt),
      'n': base64.encode(box.nonce),
      'c': base64.encode(box.cipherText),
      'm': base64.encode(box.mac.bytes),
    });
  }

  /// null = كلمة السر خاطئة أو البيانات تالفة
  static Future<String?> decrypt(String blob, String awqafPassword) async {
    try {
      final m = jsonDecode(blob) as Map<String, dynamic>;
      if (m['v'] != _version) return null;
      final salt = base64.decode(m['s'] as String);
      final key = await _kdf.deriveKeyFromPassword(password: awqafPassword, nonce: salt);
      final box = SecretBox(
        base64.decode(m['c'] as String),
        nonce: base64.decode(m['n'] as String),
        mac: Mac(base64.decode(m['m'] as String)),
      );
      return utf8.decode(await _aes.decrypt(box, secretKey: key));
    } catch (_) {
      return null;
    }
  }
}
