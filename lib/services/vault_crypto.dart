import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

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

  /// اشتقاق المفتاح (PBKDF2) ثقيل، فيعمل بمعزل (isolate) حتى لا يجمّد الواجهة
  static Future<String> encrypt(String plaintext, String awqafPassword) =>
      compute(_encryptTop, [plaintext, awqafPassword]);

  static Future<String> _encryptImpl(String plaintext, String awqafPassword) async {
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

  // ───────── تشفير بمفتاح عام (X25519 + HKDF + AES-GCM) ─────────
  // تطبيق المعلم يشفّر كلمة سر المسجد بمفتاح الأوقاف العام (لا يحتاج أي سر)، ولا يفكها إلا
  // مفتاح الأوقاف الخاص. المفتاح الخاص نفسه يُخزَّن مشفّراً بكلمة سر الأوقاف (encrypt أعلاه).

  static final _x25519 = X25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static const List<int> _sealInfo = [109, 111, 115, 113, 117, 101, 45, 118, 97, 117, 108, 116, 45, 118, 50]; // "mosque-vault-v2"

  /// مفتاحان جديدان: العام للنشر، والخاص للأوقاف فقط (base64)
  static Future<({String pub, String priv})> generateKeyPair() async {
    final kp = await _x25519.newKeyPair();
    final data = await kp.extract();
    final pub = await data.extractPublicKey();
    return (
      pub: base64.encode(pub.bytes),
      priv: base64.encode(await data.extractPrivateKeyBytes()),
    );
  }

  /// تشفير [plaintext] لمستلم مفتاحه العام [recipientPubB64]
  static Future<String> seal(String plaintext, String recipientPubB64) async {
    final eph = await _x25519.newKeyPair();
    final ephPub = await eph.extractPublicKey();
    final shared = await _x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(base64.decode(recipientPubB64), type: KeyPairType.x25519),
    );
    final key = await _hkdf.deriveKey(secretKey: shared, info: _sealInfo);
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    return jsonEncode({
      'v': 2,
      'e': base64.encode(ephPub.bytes),
      'n': base64.encode(box.nonce),
      'c': base64.encode(box.cipherText),
      'm': base64.encode(box.mac.bytes),
    });
  }

  /// null = لا يطابق هذا المفتاح، أو بيانات تالفة
  static Future<String?> open(String blob, String privB64, String pubB64) async {
    try {
      final m = jsonDecode(blob) as Map<String, dynamic>;
      if (m['v'] != 2) return null;
      final kp = SimpleKeyPairData(
        base64.decode(privB64),
        publicKey: SimplePublicKey(base64.decode(pubB64), type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      final shared = await _x25519.sharedSecretKey(
        keyPair: kp,
        remotePublicKey: SimplePublicKey(base64.decode(m['e'] as String), type: KeyPairType.x25519),
      );
      final key = await _hkdf.deriveKey(secretKey: shared, info: _sealInfo);
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

  /// null = كلمة السر خاطئة أو البيانات تالفة
  static Future<String?> decrypt(String blob, String awqafPassword) =>
      compute(_decryptTop, [blob, awqafPassword]);

  static Future<String?> _decryptImpl(String blob, String awqafPassword) async {
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

// دوال المستوى الأعلى المطلوبة لـ compute() (تعمل بمعزل عن خيط الواجهة)
Future<String> _encryptTop(List<String> a) => VaultCrypto._encryptImpl(a[0], a[1]);
Future<String?> _decryptTop(List<String> a) => VaultCrypto._decryptImpl(a[0], a[1]);
