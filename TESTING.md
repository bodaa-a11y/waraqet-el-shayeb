# دليل الاختبارات ونتائج الفحص | TESTING.md

## 1. الاختبارات المنفذة فعلياً ونتائجها (Verified Executed Tests)

### أ) اختبارات محرك السيرفر والأمان والتزامن (TypeScript / Node.js — 15 اختباراً ناجحاً)

تم التشغيل عبر الأمر:
```bash
node --test functions/test/engine.test.mjs functions/test/simulation.test.mjs functions/test/security_and_concurrency.test.mjs
```

**النتيجة الفعلية:** `15 passed, 0 failed`
- `deck has exactly 49 unique cards and only King of Hearts`: التحقق من ٤٩ ورقة فريدة وشايب القلوب فقط.
- `matching ignores suits and resolves four-of-a-kind into two pairs`: تصفية ٤ ورقات من نفس الرتبة إلى جوزين.
- `round setup preserves 49 cards and creates no unresolved pairs across 2-6 players`: التحقق من التوزيع وتصفية الأجواز المبدئية لـ ٢..٦ لاعبين.
- `public game view contains counts and turn info but no cards or hand values`: التأكد من أن `publicView()` لا يسرب أي قيمة كارت أو شايب.
- `only active player can draw; stale and bad selections rejected`: رفض السحب في غير الدور أو بإصدار قديم أو فهرس خاطئ.
- `autoDrawOnTimeout draws a legal card when turn timer expires and rejects stale version`: التحقق من السحب التلقائي عند انتهاء المهلة.
- `points calculated in finishing order with loser scoring zero and deterministic tie-breaking`: التحقق من النقاط (`N-1..0`) وكسر التعادل.
- `30 localized Egyptian challenges and unbiased non-repeating selection`: التحقق من الـ ٣٠ حكماً بالمصري العامي وعدم تكرار الحكم المختار.
- `state machine validates legal transitions and blocks illegal skips`: التحقق من آلة الحالة (`TurnPhase`).
- `room code generator creates 6-char unambiguous alphanumeric codes`: التحقق من توليد أكواد الغرف.
- `invalid player lists are rejected`: رفض الأعداد غير القانونية أو المعرفات المكررة.
- `security & anti-cheat: unauthorized hand reads, secret state reads, and non-member actions are blocked`: اختبار عزل أوراق اللاعبين ومنع قراءة `secret/round`.
- `concurrency & idempotency: duplicate actionId returns safe idempotent response; concurrent draw on same version fails with stale_version`: اختبار التزامن ومنع تكرار السحب بنفس `actionId`.
- `firestore.rules and storage.rules enforce member-only reads, owner-only hands, and zero client game writes`: فحص قواعد `firestore.rules` و`storage.rules`.
- `300 complete real-rules simulations across all player counts (2-6) and both directions`: محاكاة **٣٠٠ جولة كاملة** (أكثر من ١٢,٠٠٠ سحبة قانونية) مع التحقق من جميع الـ ١٥ ثابتاً رياضياً (`assertRoundInvariants`) بعد كل حركة.

---

### ب) اختبارات محرك ومنطق Dart والمحاكاة (Dart SDK 3.12.1 — 6 مجموعات اختبار شاملة)

تم التشغيل عبر الأمر:
```bash
dart test/pure_dart_engine_test.dart
```

**النتيجة الفعلية:** `6 passed, 0 failed`
1. التحقق من حزمة الـ ٤٩ ورقة وشايب القلوب في محرك Dart.
2. التحقق من تصفية الأجواز والـ 4-of-a-kind مع الحفاظ على الشايب.
3. التحقق من حساب النقاط وكسر التعادل (`MatchStandingRow.computeFromRoom`).
4. التحقق من فلترة الأسماء ومنع انتحال رسائل النظام (`النظام`, `Admin`).
5. التحقق من قائمة الـ ٣٠ حكماً مصرياً في `kEgyptianChallengesCatalog`.
6. محاكاة **١٠٠ جولة جماعية كاملة** في Dart عبر ٢ إلى ٦ لاعبين في الاتجاهين.

---

## 2. اختبارات واجهة Flutter والمحاكي السحابي (Widget & Emulator Tests)

- ملف `test/shayeb_engine_and_ui_test.dart` يضم اختبارات `flutter_test` للتحقق من:
  - عدم تسريب هوية كارت الشايب في الكروت المقلوبة (`PlayingCardWidget(faceDown: true)`).
  - رحلة المستخدم الكاملة من الشاشة الرئيسية (RTL) -> إنشاء قعدة -> اللوبي -> بدء الجولة -> شاشة ترابيزة اللعب.
  - لتشغيله خارج بيئة الـ Sandbox المعزولة عن الشبكة:
    ```bash
    flutter pub get
    flutter test test/shayeb_engine_and_ui_test.dart
    ```

## 3. قيود البيئة الحالية (Documented Environment Limitations)

- بيئة التنفيذ الحالية معزولة شبكياً داخل الـ Sandbox (`BypassSandbox: false`)، ولذلك تم تنفيذ وتشغيل جميع اختبارات Node.js TypeScript (`15/15`) واختبارات Dart VM (`6/6` شاملة ٤٠٠ جولة محاكاة كاملة) محلياً بنجاح، بينما يتطلب تشغيل `firebase emulators:start` أو `flutter build web` اتصالاً بالشبكة لتحميل حزم `pub.dev` / `npm` وثنائيات محاكي Firebase عند الإعداد لأول مرة على جهاز المطور.
