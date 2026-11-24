# الشايب أونلاين — Firebase Backend & Database Testing (V2 source baseline)

> هذا تحديث عملي على ملفات **V2 المتاحة**؛ لم يصل أرشيف Cinematic V3 إلى جلسة التطوير هذه. إذا كانت V3 أحدث، انقل الملفات المتغيرة عن طريق دمج Git/مقارنة يدوية. لا تستبدل V3 بملف V2 كامل.

## ماذا أُنجز؟

- حصر الدخول إلى الغرف الخاصة بكود الدعوة: معرف الغرفة `roomId` يكفي فقط للغرفة العامة أو العضو الذي يعيد الاتصال.
- قفل الكتابة المباشرة في `rooms/{roomId}/messages` وإرسال الرسائل عبر `sendRoomMessage` مع تحقق من العضوية والهوية ومعدل الرسائل (فاصل 750 ملّي ثانية لكل مستخدم).
- منع إرفاق رابط خارجي تعسفي في رسائل الشات؛ رفع الإثباتات من مسار التحديات المنفصل.
- حماية دالة `seedChallengesCatalog` بصفة `admin`؛ ليست متاحة لأي لاعب.
- منع `restartMatch` قبل انتهاء المباراة، وحذف حالة الجولة القديمة وأيدي اللاعبين بعد الإعادة.
- دعم تهيئة Firebase وهمية *للمحاكيات المحلية فقط* من دون الحاجة لربط مشروع Firebase حقيقي قبل تجربة الويب.
- إصلاح تنظيف حالة الجولة واليد من واجهة Flutter بعد إعادة المباراة وإظهار خطأ فشل إرسال الشات.
- كتابة اختبار اتصال حقيقي `functions/test/firebase_emulator_smoke.mjs`: ثلاثة مستخدمين مسجلين بشكل مستقل، إنشاء غرفة خاصة، الدخول بكود، رسائل ومطالعة قاعدة البيانات، منع التزوير، بدء اللعب، 3 جولات كاملة، عزل أوراق اللاعبين، وحذف الحالة عند إعادة المباراة.

## المتطلبات على ويندوز

- Flutter stable + Chrome.
- Node.js 22 أو إصدار متوافق مع Firebase CLI.
- Java 21+.
- Firebase CLI (`npm install -g firebase-tools`).
- لا تحتاج مشروع Firebase حقيقي أو خطة Blaze **للاختبار المحلي**؛ جميع الخدمات تبدأ على مشروع `demo-el-shayeb` الوهمي.

## أ) اختبار الأونلاين المحلي آليًا (Firebase Emulator Suite)

افتح PowerShell في مجلد `el_shayeb_online`:

```powershell
.\scripts\test_backend_emulator.ps1
```

هذا السكربت يثبت تبعيات Cloud Functions ويترجم TypeScript، ثم يشغّل محاكيات Auth / Firestore / Functions / Storage وينفذ اختبارا حقيقيا، وليس Mock.

إذا فشل، ستظهر الخطوة التي فشلت. لم يتم تشغيل هذا الاختبار في البيئة الحالية بسبب غياب `firebase` CLI وتبعيات المشروع.

## ب) تجربة اللعبة باثنين لاعبين في المتصفح

**النافذة الأولى من PowerShell:**

```powershell
.\scripts\run_emulators.ps1
```

ستظهر لوحة Firebase Emulator UI غالبًا على `http://127.0.0.1:4000`.

**النافذة الثانية من PowerShell:**

لو مجلد المنصات عندك ناقص، السكربت هيستخدم `flutter create . --platforms=web --project-name el_shayeb_online` لإنشاء ملفات تشغيل الويب الناقصة من غير حذف كود اللعبة.

```powershell
.\scripts\run_flutter_emulator.ps1
```

الخطوات:
1. افتح Chrome بنوافذ منفصلة عادية وIncognito (أو ملفَي مستخدم مختلفين). النافذتان العاديتان اللتان تشتركان في نفس التخزين قد تستخدمان نفس جلسة Firebase Auth؛ لذلك لا تصلحان للاختبار كلاعبين مستقلين.
2. نافذة 1: اختر اسمًا «أحمد»، واضغط «اعمل قعدة» ثم «خاصة». انسخ الكود.
3. نافذة 2: اختر اسمًا «محمد»، و«ادخل بكود».
4. تأكد من ظهور الاثنين في اللوبي، وأرسل رسائل بالشات.
5. اضغط «أنا جاهز» من محمد، ثم «يلا نبدأ» من أحمد.
6. جرّب السحب من اللاعب الذي يحدده السيرفر حتى انتهاء الجولة.
7. في لوحة Emulator UI راقب `rooms`, `rooms/{id}/state/current`, `rooms/{id}/hands/{uid}`, `rooms/{id}/messages`.
8. كرر تجربة ثلاث لاعبين واختبر تقطع الشبكة والعودة بنفس حساب المتصفح.

**مهم:** محاكي `127.0.0.1` يعمل على *جهاز المطوّر نفسه*؛ لا تستخدم نفس عنوانه من موبايل حقيقي أو جهاز آخر. استخدام جهاز آخر يحتاج IP جهاز المطوّر، إعدادات جدار ناري آمنة، وربما HTTPS/إعدادات منصة إضافية. للعب من أماكن متفرقة، انتقل لاحقًا إلى مشروع Firebase حقيقي.

## ج) نقل التجربة إلى Firebase حقيقي

1. أنشئ مشروعًا جديدًا على Firebase Console.
2. فعّل Anonymous Authentication، وFirestore، وStorage.
3. مشروع Flutter الحالي يقرأ إعداداته من `--dart-define` داخل `lib/config/firebase_config.dart`. خذ القيم من Firebase Console / FlutterFire وأدخل `FIREBASE_PROJECT_ID` و`FIREBASE_API_KEY` و`FIREBASE_APP_ID_WEB` و`FIREBASE_MESSAGING_SENDER_ID` و`FIREBASE_AUTH_DOMAIN` و`FIREBASE_STORAGE_BUCKET` و`FIREBASE_FUNCTIONS_REGION` أثناء تشغيل التطبيق. **تشغيل `flutterfire configure` وحده لا يكفي لهذا الإصدار حتى لو ولّد `firebase_options.dart`**؛ يلزم توصيل الملف المولّد يدويًا أو استخدام متغيرات التعريف المذكورة. لا ترفع مفاتيح حساب خدمة أو بيانات خاصة.
4. أنشئ خطة ميزانية وتنبيهات استخدام؛ Cloud Functions/Storage قد يتطلبان تفعيل خطة Blaze.
5. شغّل اختبارات المحاكي كاملة قبل نشر قواعد الأمان.
6. بعدها انشر Cloud Functions وقواعد Firestore/Storage عبر Firebase CLI على مشروعك الحقيقي فقط بعد مراجعة رقم المشروع.
7. اعمل اختبار موبايلين عبر الإنترنت على مشروع التجربة (staging) قبل الإنتاج.

## هيكل قاعدة البيانات

```text
users/{uid}                             (بروفايل اللاعب)
rooms/{roomId}                         (إعدادات وعضوية الغرفة)
roomCodes/{code}                       (الكود → معرف الغرفة؛ سيرفر فقط)
publicRooms/{roomId}                    (دليل القعدات المفتوحة)
rooms/{roomId}/state/current           (الحالة العامة للّعب؛ للأعضاء)
rooms/{roomId}/hands/{uid}              (اليد الخاصة لصاحبها)
rooms/{roomId}/secret/round            (حالة المحرك السرية؛ سيرفر فقط)
rooms/{roomId}/actions/{actionId}        (منع تكرار السحب؛ سيرفر فقط)
rooms/{roomId}/messages/{messageId}     (الشات؛ قراءة أعضاء وكتابة السيرفر)
rooms/{roomId}/chatRate/{uid}           (حد إرسال الرسائل؛ سيرفر فقط)
rooms/{roomId}/challenges/{id}          (الأحكام)
```

## حدود ما تم التحقق منه

- `node --experimental-strip-types --test functions/test/*.test.mjs`: **28 ناجحًا / 0 فشل** في بيئة Node 22.16 الحالية.
- السكربت الجديد اجتاز `node --check` (فحص البنية النصية).
- لم نتمكن من تشغيل `firebase emulators:exec` أو `npm run build` أو `flutter run` داخل هذه البيئة؛ لذلك نجاح الربط الحقيقي وFlutter **غير مثبت بعد**.
- الشات النصي يعمل على مسار Callable؛ *ملفات إثبات الأحكام* تحتاج اختبار صلاحيات Storage والرفع الحقيقي بشكل منفصل.
- اختبارات Node القديمة أغلبها محاكاة بدون اتصال Firestore؛ الاختبار الجديد هو الذي سيؤكد العمل على الخدمات المحلية بعد تشغيله.
