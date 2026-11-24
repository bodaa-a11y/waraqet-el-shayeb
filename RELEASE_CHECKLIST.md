# قائمة فحص الإطلاق والنشر | RELEASE_CHECKLIST.md

## 1. الأمان ومكافحة الغش (Security & Anti-Cheat)

- [x] لا توجد أي مفاتيح أو بيانات اعتماد إنتاجية مضمنة في الكود (`lib/config/firebase_config.dart` يعتمد على `--dart-define`).
- [x] أوراق كل لاعب معزولة في `rooms/{roomId}/hands/{uid}` بصلاحية `allow get: if isOwner(playerUid) && isRoomMember(roomId);` مع منع `list` و`write`.
- [x] حالة الجولة السرية `rooms/{roomId}/secret/round` مغلقة تماماً أمام جميع العملاء (`allow read, write: if false;`).
- [x] جميع انتقالات اللعبة (التوزيع، السحب، تصفية الأجواز، النقاط، تعيين الأحكام) تتم حصرياً عبر Cloud Functions v2 داخل Firestore Transactions.
- [x] التحقق من `expectedVersion` و`actionId` لمنع تكرار السحب أو التلاعب بالترتيب.
- [x] منع انتحال رسائل النظام (`type == 'system'`) في قواعد Firestore للشات.
- [x] تقييد رفع ملفات الأدلة في `storage.rules` لأعضاء الغرفة فقط، وبحجم أقصى ٥ ميجابايت للصور و٣ ميجابايت للصوت.

## 2. إعدادات Firebase قبل الإطلاق (Firebase Configuration)

- [ ] تفعيل **Anonymous Authentication** في Firebase Console.
- [ ] تفعيل **Firebase App Check** (ReCaptcha Enterprise للويب، Play Integrity لأندرويد، DeviceCheck/AppAttest لـ iOS).
- [ ] نشر قواعد وفهارس Firestore:
  ```bash
  firebase deploy --only firestore:rules,firestore:indexes
  ```
- [ ] نشر قواعد Storage:
  ```bash
  firebase deploy --only storage
  ```
- [ ] بناء ونشر Cloud Functions v2 (`europe-west1`):
  ```bash
  cd functions && npm install && npm run build && cd ..
  firebase deploy --only functions
  ```

## 3. التحقق من بناء التطبيقات (Build Verification)

- [ ] **Flutter Web:**
  ```bash
  flutter build web --release \
    --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID \
    --dart-define=FIREBASE_API_KEY=YOUR_API_KEY \
    --dart-define=FIREBASE_APP_ID_WEB=YOUR_WEB_APP_ID
  firebase deploy --only hosting
  ```
- [ ] **Android APK / AppBundle:**
  - مراجعة `applicationId` وإعداد مفتاح التوقيع (`key.properties`) قبل بناء الـ Release:
  ```bash
  flutter build appbundle --release
  ```
- [ ] **iOS (على جهاز macOS مع Xcode):**
  - ضبط Bundle Identifier وشهادة التوقيع وملف `GoogleService-Info.plist`:
  ```bash
  flutter build ipa --release
  ```
