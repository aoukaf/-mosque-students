# 🕌 تطبيق سجلات طلاب المسجد
## مع مزامنة Firebase لحظية بين الأجهزة

---

## ✨ المميزات
- ✅ إضافة وتعديل وحذف الطلاب
- 📖 تتبع الأجزاء المحفوظة (من 30)
- ⭐ نظام النجوم (0 - 5000)
- 🔥 مزامنة **لحظية** بين كل الأجهزة عبر Firebase
- 📡 يشتغل **بدون نت** ويتزامن لما يرجع الاتصال
- 📱 يتكيف مع كل أحجام الشاشات

---

## 🔥 إعداد Firebase (مرة واحدة فقط)

### الخطوة 1 — إنشاء مشروع Firebase

1. روح على: **https://console.firebase.google.com**
2. سجّل دخول بحساب Google
3. اضغط **"Add project"** أو **"إنشاء مشروع"**
4. سمّيه مثلاً: `mosque-students`
5. اضغط Continue حتى ينتهي

---

### الخطوة 2 — إضافة تطبيق Android

1. في صفحة المشروع، اضغط أيقونة **Android** `</>`
2. في حقل **Package name** اكتب: `com.mosque.students`
3. اضغط **Register app**
4. حمّل ملف **`google-services.json`**
5. ضع الملف في المسار: `android/app/google-services.json`

---

### الخطوة 3 — تفعيل Firestore Database

1. من القائمة الجانبية اختر **Firestore Database**
2. اضغط **Create database**
3. اختر **Start in test mode** (للتجربة)
4. اختر أقرب منطقة (مثلاً: `europe-west1`)
5. اضغط **Done**

---

### الخطوة 4 — إعداد قواعد الأمان في Firestore

في Firestore → Rules، استبدل القواعد بهذا:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // يسمح بالقراءة والكتابة لأي شخص (للاستخدام الداخلي)
      allow read, write: if true;
    }
  }
}
```

> ⚠️ هذه القواعد مناسبة للاستخدام الخاص. إذا أردت أمان أكثر، أضف Authentication لاحقاً.

---

### الخطوة 5 — تحديث ملف firebase_options.dart

#### الطريقة السهلة (FlutterFire CLI):
```bash
# ثبّت FlutterFire CLI
dart pub global activate flutterfire_cli

# شغّل في مجلد المشروع
flutterfire configure

# اختر مشروعك واختر Android
# سيُولّد lib/firebase_options.dart تلقائياً ✅
```

#### أو يدوياً من google-services.json:
افتح `google-services.json` وانسخ القيم لـ `lib/firebase_options.dart`:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIza...',           // من: client[0].api_key[0].current_key
  appId: '1:xxx:android:xxx', // من: client[0].client_info.mobilesdk_app_id
  messagingSenderId: 'xxx',   // من: project_info.project_number
  projectId: 'mosque-students', // من: project_info.project_id
  storageBucket: 'mosque-students.appspot.com',
);
```

---

### الخطوة 6 — تحديث android/app/build.gradle

أضف في نهاية الملف:
```gradle
apply plugin: 'com.google.gms.google-services'
```

وفي `android/build.gradle` أضف في `dependencies`:
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

---

### الخطوة 7 — البناء والتشغيل

```bash
# في مجلد المشروع
flutter pub get
flutter run

# بناء APK
flutter build apk --release
# الملف في: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 تثبيت التطبيق على أكثر من جهاز

1. ابنِ الـ APK: `flutter build apk --release`
2. ثبّت نفس الـ APK على كل الأجهزة
3. **خلاص!** — كل الأجهزة تشارك نفس البيانات تلقائياً

أي إضافة أو تعديل على أي جهاز يظهر فوراً على الأجهزة الأخرى 🔥

---

## 📁 هيكل المشروع

```
lib/
├── main.dart                      # تهيئة Firebase
├── firebase_options.dart          # إعدادات Firebase (تعبّئها أنت)
├── models/
│   ├── student.dart               # نموذج الطالب
│   ├── sync_service.dart          # خدمة المزامنة مع Firebase
│   └── app_theme.dart             # ألوان التطبيق
├── screens/
│   ├── home_screen.dart           # الشاشة الرئيسية (Stream لحظي)
│   ├── add_edit_student_screen.dart
│   ├── student_detail_screen.dart
│   ├── halqas_screen.dart
│   └── statistics_screen.dart
├── utils/
│   └── responsive.dart            # نظام التكيف مع الشاشات
└── widgets/
    ├── student_card.dart
    └── sync_status_bar.dart       # مؤشر حالة الاتصال
```
