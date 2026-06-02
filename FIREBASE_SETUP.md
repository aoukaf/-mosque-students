# خطوات Firebase المطلوبة

## 1. إضافة تطبيق Web

1. افتح [Firebase Console](https://console.firebase.google.com)
2. اختر مشروعك **bn-aouf**
3. اضغط على أيقونة الترس ⚙️ → **Project settings**
4. في قسم **Your apps** اضغط **Add app** ثم اختر أيقونة `</>`
5. اكتب اسم التطبيق (مثال: `mosque-web`) ثم اضغط **Register app**
6. ستظهر لك القيم التالية — انسخها:

```js
const firebaseConfig = {
  apiKey: "...",
  authDomain: "bn-aouf.firebaseapp.com",
  projectId: "bn-aouf",
  storageBucket: "bn-aouf.firebasestorage.app",
  messagingSenderId: "533389705737",
  appId: "..."   // ← هذا هو الرقم الجديد
};
```

7. افتح الملف `lib/firebase_options.dart` وضع القيم في قسم `web`:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey:            'ضع apiKey هنا',
  authDomain:        'bn-aouf.firebaseapp.com',
  projectId:         'bn-aouf',
  storageBucket:     'bn-aouf.firebasestorage.app',
  messagingSenderId: '533389705737',
  appId:             'ضع appId هنا',
);
```

---

## 2. تحديث قواعد Firestore

1. في Firebase Console → **Firestore Database** → تبويب **Rules**
2. احذف كل النص الموجود
3. انسخ محتوى ملف `firestore.rules` الموجود في المشروع والصقه
4. اضغط **Publish**

---

## 3. بعد الانتهاء

ارجع هنا وشغّل:
```bash
flutter build web --release
```
ثم ارفع المشروع على GitHub وسيبني Netlify تلقائياً.
