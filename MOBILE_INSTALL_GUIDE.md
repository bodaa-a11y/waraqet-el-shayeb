# دليل تثبيت لعبة «ورقة الشايب» على الموبايل 📱🃏

اسم التطبيق الرسمي: **ورقة الشايب**  
أيقونة التطبيق وشاشة التحميل التفاعلية (`CreativeSplashScreen`) مجهزة بالكامل باللوجو المخصص لـ «ورقة الشايب».

---

## الطريقة 1: تثبيت APK مباشرة على أندرويد (من جهازك بضغطة واحدة)

1. تأكد أن **Android SDK** مثبت على جهازك (من خلال **Android Studio** أو command-line tools + قبول الرخص `flutter doctor --android-licenses`).
2. شغّل الملف [build_mobile_apk.bat](build_mobile_apk.bat) أو افتح PowerShell في مجلد المشروع وشغّل:
   ```powershell
   flutter pub get
   flutter build apk --release
   ```
3. سينتج ملف التثبيت:
   - `build\app\outputs\flutter-apk\app-release.apk`
   - ويُنسخ تلقائيًا باسم `waraqet_el_shayeb_release.apk` في جذر المشروع.
4. انقل الملف إلى هاتفك الأندرويد وافتحه للتثبيت (فعّل «تثبيت من مصادر غير معروفة» عند الطلب)، أو وصّل الموبايل بكابل USB مع تفعيل USB Debugging وشغّل:
   ```powershell
   flutter run --release
   ```

---

## الطريقة 2: استخراج ملف APK جاهز سحابيًا بدون Android Studio (GitHub Actions)

إذا لم يكن **Android SDK** مثبتًا على جهازك:
1. ارفع مجلد المشروع إلى مستودع GitHub خاص أو عام.
2. سيعمل ملف [.github/workflows/build_android_apk.yml](.github/workflows/build_android_apk.yml) تلقائيًا (أو شغّله من تبويب **Actions → Build Android APK → Run workflow**).
3. حمّل ملف **`waraqet-el-shayeb-apk`** (`waraqet_el_shayeb_release.apk`) وثبّته مباشرة على موبايلك.

---

## الطريقة 3: التثبيت السريع كتطبيق ويب (PWA) على Android وiPhone

يمكن تثبيت اللعبة بدون APK على أندرويد وآيفون:
1. ابنِ نسخة الويب:
   ```powershell
   flutter build web --release
   ```
2. ارفع مجلد `build/web` على أي استضافة HTTPS مجانية (مثل Cloudflare Pages أو Netlify أو Vercel).
3. افتح الرابط من موبايلك واضغط **«إضافة إلى الشاشة الرئيسية / Add to Home Screen»** — ستظهر أيقونة **ورقة الشايب** وشاشة البداية بالكامل على هاتفك.
