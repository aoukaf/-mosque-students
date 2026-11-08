import 'package:flutter_test/flutter_test.dart';
import 'package:mosque_students/models/staff.dart';
import 'package:mosque_students/services/vault_crypto.dart';

void main() {
  group('VaultCrypto', () {
    test('تشفير ثم فك بنفس كلمة السر يعيد النص', () async {
      final blob = await VaultCrypto.encrypt('كلمة-سر-المسجد 123', 'awqaf-password');
      expect(blob.contains('كلمة'), isFalse, reason: 'النص يجب ألا يظهر صريحاً');
      expect(await VaultCrypto.decrypt(blob, 'awqaf-password'), 'كلمة-سر-المسجد 123');
    });

    test('كلمة سر خاطئة ترجع null', () async {
      final blob = await VaultCrypto.encrypt('secret', 'right-password');
      expect(await VaultCrypto.decrypt(blob, 'wrong-password'), isNull);
    });

    test('نفس النص يعطي نصاً مشفّراً مختلفاً كل مرة (ملح وnonce عشوائيان)', () async {
      final a = await VaultCrypto.encrypt('same', 'pw');
      final b = await VaultCrypto.encrypt('same', 'pw');
      expect(a, isNot(b));
    });

    test('بيانات تالفة ترجع null بدون استثناء', () async {
      expect(await VaultCrypto.decrypt('not json', 'pw'), isNull);
      expect(await VaultCrypto.decrypt('{"v":9}', 'pw'), isNull);
    });
  });

  group('VaultCrypto sealed box (مفتاح عام)', () {
    test('تشفير بالعام وفك بالخاص', () async {
      final kp = await VaultCrypto.generateKeyPair();
      final sealed = await VaultCrypto.seal('كلمة سر مسجد 456', kp.pub);
      expect(sealed.contains('كلمة'), isFalse);
      expect(await VaultCrypto.open(sealed, kp.priv, kp.pub), 'كلمة سر مسجد 456');
    });

    test('مفتاح خاص مختلف لا يفك', () async {
      final a = await VaultCrypto.generateKeyPair();
      final b = await VaultCrypto.generateKeyPair();
      final sealed = await VaultCrypto.seal('secret', a.pub);
      expect(await VaultCrypto.open(sealed, b.priv, b.pub), isNull);
    });

    test('المفتاح الخاص يُحمى بكلمة سر ثم يُفتح ويفك', () async {
      final kp = await VaultCrypto.generateKeyPair();
      final wrapped = await VaultCrypto.encrypt(kp.priv, 'awqaf-pw');
      final priv = await VaultCrypto.decrypt(wrapped, 'awqaf-pw');
      expect(priv, kp.priv);
      final sealed = await VaultCrypto.seal('mosque-pw', kp.pub);
      expect(await VaultCrypto.open(sealed, priv!, kp.pub), 'mosque-pw');
      expect(await VaultCrypto.decrypt(wrapped, 'bad'), isNull);
    });

    test('بيانات تالفة ترجع null', () async {
      final kp = await VaultCrypto.generateKeyPair();
      expect(await VaultCrypto.open('x', kp.priv, kp.pub), isNull);
      expect(await VaultCrypto.open('{"v":2}', kp.priv, kp.pub), isNull);
    });
  });

  group('StaffMember', () {
    test('toMap/fromMap يحافظان على القيم، وعدد المحفوظات فقط لغير الخاتم', () {
      const none = StaffMember(
        id: 'a', role: StaffRole.assistant, fullName: 'أحمد محمد علي', education: 'بكالوريوس',
        job: 'مهندس', birthDate: '1995-03-10', phone: '0999', quranStatus: QuranStatus.none,
        memorizedParts: 12, halqa: 'الأولى',
      );
      expect(none.toMap()['memorizedParts'], 12);
      final back = StaffMember.fromMap('a', none.toMap());
      expect(back.fullName, 'أحمد محمد علي');
      expect(back.quranStatusLabel, 'يحفظ 12 جزءاً');

      const mujaz = StaffMember(
        id: 'b', role: StaffRole.teacher, fullName: 'x', quranStatus: QuranStatus.mujaz, memorizedParts: 5,
      );
      expect(mujaz.toMap().containsKey('memorizedParts'), isFalse);
      expect(mujaz.quranStatusLabel, 'مجاز');
    });

    test('حساب العمر', () {
      final now = DateTime.now();
      final b = DateTime(now.year - 30, now.month, now.day);
      final m = StaffMember(
        id: 'c', role: StaffRole.teacher, fullName: 'x',
        birthDate: '${b.year}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
      );
      expect(m.age, 30);
      expect(const StaffMember(id: 'd', role: StaffRole.teacher, fullName: 'x').age, isNull);
    });
  });
}
