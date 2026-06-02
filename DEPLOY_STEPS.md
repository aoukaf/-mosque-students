# خطوات رفع التطبيق على GitHub Pages

## المرة الأولى فقط

### 1. أنشئ Repository على GitHub
- روح: https://github.com/new
- اسم الـ repo: `mosque-students` (أو أي اسم تريده)
- اختار: **Public** (لأن GitHub Pages مجاني فقط مع Public)
- **لا تضيف** README أو .gitignore (عندنا واحد)
- اضغط: Create repository

### 2. ارفع الكود من جهازك
افتح PowerShell في مجلد المشروع وشغّل:

```powershell
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/USERNAME/mosque-students.git
git push -u origin main
```
← **غيّر USERNAME باسم حسابك على GitHub**

### 3. فعّل GitHub Pages
- روح: Settings → Pages (في الـ repo)
- Source: اختار **GitHub Actions**
- احفظ

### 4. انتظر الـ Build
- روح: Actions tab في الـ repo
- ستشوف workflow اسمه "Build & Deploy to GitHub Pages" شتغل تلقائياً
- بعد ~3 دقائق، رابط تطبيقك:
  `https://USERNAME.github.io/mosque-students/`

---

## للتحديثات بعد كده

```powershell
git add .
git commit -m "وصف التعديل"
git push
```
GitHub يبني وينشر تلقائياً خلال 2-3 دقائق.

---

## الأمان - خطوتان مهمتان بعد الرفع

### خطوة أ: فعّل Anonymous Authentication في Firebase
1. روح: https://console.firebase.google.com → مشروعك `bn-aouf`
2. Authentication → Sign-in method
3. اضغط على **Anonymous** → فعّله → احفظ

بدون هاد، التطبيق ما يقدر يفتح.

---

### خطوة ب: انشر Firestore Security Rules
1. روح: Firestore Database → Rules
2. احذف كل النص الموجود
3. انسخ محتوى ملف `firestore.rules` من المشروع والصقه
4. اضغط **Publish**

---

### خطوة ج: قيّد Firebase API Key على دومينك فقط
1. روح: https://console.cloud.google.com
2. اختار مشروع `bn-aouf`
3. APIs & Services → Credentials
4. اضغط على الـ API key (اسمه Browser key أو مشابه)
5. Application restrictions → **HTTP referrers (websites)**
6. أضف هالسطور الثلاثة:
   ```
   https://USERNAME.github.io/*
   https://USERNAME.github.io/mosque-students/*
   http://localhost/*
   ```
   ← غيّر USERNAME باسم حسابك
7. احفظ

هاد يضمن إن مفتاح Firebase ما يُستخدم من أي موقع ثاني حتى لو شافه أحد في الكود.
