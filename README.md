# ورقة الشايب | Waraqet El Shayeb 👴👑🃏

<p align="center">
  <img src="assets/images/logo/waraqet_el_shayeb_logo.png" alt="ورقة الشايب" width="180" />
</p>

📱 **تحميل مباشر للأندرويد (APK):** [اضغط هنا لتحميل لعبة ورقة الشايب](https://github.com/bodaa-a11y/waraqet-el-shayeb/releases/latest/download/waraqet_el_shayeb_release.apk)

لعبة الكوتشينة المصرية الجماعية أونلاين (٢ إلى ٦ لاعبين) مبنية باستخدام **Flutter** (RTL، المصري العامي، شاشة بداية متحركة باللوجو، ثيمات قهوة البلد وليالي النيل) و**Supabase** (PostgreSQL + RLS + Edge Functions + Realtime + Anonymous Auth + Private Storage).

---

## 🌟 المميزات الرئيسية (Features)

1. **منطق الكوتشينة المصري الأصلي (٤٩ ورقة):**
   - حزمة ٥٢ ورقة بدون جواكر، مع حذف ٣ شوايب والإبقاء على **شايب القلوب (`K:hearts`)** فقط بدون جوز.
   - تصفية تلقائية للأجواز المتشابهة في الرتبة (Rank) بغض النظر عن النوع (Suit)، بما في ذلك ٤ ورقات من نفس الرتبة = جوزين.
   - سحب ورقة مقلوبة من أقرب لاعب نشط حسب اتجاه اللعب (مع أو عكس عقارب الساعة) مع تخطي اللاعبين الذين صفّوا ورقهم.
2. **سيرفر متحكم بالكامل ومضاد للغش (Server-Authoritative Anti-Cheat):**
   - التوزيع والتفنيط (`crypto.getRandomValues` + Rejection Sampling بدون `Math.random`) وتصفية الأجواز والسحب وحساب النقط وتعيين الأحكام كلها تتم حصرياً داخل **Cloud Functions v2** عبر Transactions.
   - أوراق كل لاعب محفوظة في مسار خاص `rooms/{roomId}/hands/{uid}` لا يقرؤه إلا صاحبه فقط، بينما الحالة العامة `rooms/{roomId}/state/current` و`rooms/{roomId}/gameState/current` تعرض عدد الأوراق والدور فقط (`publicView()`).
3. **الغرف الخاصة والعامة واللوبي المباشر:**
   - إنشاء قعدة خاصة بكود من ٦ حروف وأرقام واضحة (مثل `SH7K29`) أو قعدة مفتوحة تظهر في دليل `publicRooms`.
   - مشاركة الكود ونسخه، نظام الجاهزية (`أنا جاهز`)، نقل ملكية القعدة تلقائياً إذا غادر المضيف، وطرد اللاعبين قبل البدء.
4. **نظام الأحكام المصرية (٣٠ حكم كوميدي آمن) وتوثيق الدليل:**
   - ٣٠ حكم بالمصري العامي (تمثيل، أداء صوتي، شعر، كوميديا، وتفاعل مع الشلة).
   - إمكانية تنفيذ الحكم، تغييره (`redraw` حتى مرتين بدون تكرار فوري)، أو تخطيه، مع إرفاق نص أو صورة أو تسجيل صوتي اختياري.
5. **شات القعدة والريأكشنات السريعة:**
   - شات لحظي مع رسائل النظام الموثوقة (`قهوة الشايب`) وريأكشنات سريعة (`😂 😱 👑 💀 ☕ 👴 🔥`).

---

## 🛠️ المتطلبات والتثبيت (Requirements & Installation)

- **Flutter SDK:** الإصدار المستقر (`>=3.22` / Dart `>=3.4`)
- **Node.js:** الإصدار `20+` (تم التحقق والاختبار على Node `22+` و`26.13.1`)
- **Firebase CLI:** `npm install -g firebase-tools`
- **FlutterFire CLI:** `dart pub global activate flutterfire_cli`

### 1. تجهيز وتشغيل اختبارات محرك اللعبة (Backend & Game Engine)

```bash
cd functions
npm install
npm test
```

> ملاحظة: على Node 22.6+ / Node 26+ يمكنك أيضاً تشغيل اختبارات المحرك مباشرة بدون تثبيت حزم إضافية عبر:
> `node --test functions/test/*.test.mjs`

### 2. تجهيز تطبيق Flutter

```bash
flutter pub get
flutter test
```

### 3. إعداد Firebase والمحاكي المحلي (Firebase Emulator Suite)

1. سجّل الدخول إلى Firebase وأنشئ مشروعاً جديداً:
   ```bash
   firebase login
   firebase projects:create el-shayeb-online
   firebase use el-shayeb-online
   ```
2. فعّل من لوحة تحكم Firebase:
   - **Authentication** -> Sign-in method -> **Anonymous** (مجاني على خطة Spark).
   - **Cloud Firestore** و**Firebase Hosting** (مجانيان ضمن حدود خطة Spark).
   - **Cloud Functions v2** و**Cloud Storage** (يتطلبان ترقية المشروع لخطة **Blaze Pay-as-you-go** عند النشر السحابي، بينما يعملان **مجاناً بالكامل محلياً** عبر Firebase Emulator Suite).
3. اربط تطبيق Flutter بمشروعك عبر FlutterFire:
   ```bash
   flutterfire configure --project=el-shayeb-online
   ```
4. لتشغيل المحاكي المحلي (Emulators):
   ```bash
   firebase emulators:start
   ```
5. لتشغيل تطبيق Flutter متصلاً بالمحاكي المحلي:
   ```bash
   flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
   ```

---

## 🚀 النشر والإصدار (Deployment)

### نشر قواعد الأمان والفهارس والـ Cloud Functions

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

### بناء ونشر نسخة الويب (Flutter Web + Firebase Hosting)

```bash
flutter build web --release
firebase deploy --only hosting
```

### بناء نسخة أندرويد (Android APK / AppBundle)

```bash
flutter build apk --release
# أو للنشر على Google Play:
flutter build appbundle --release
```
