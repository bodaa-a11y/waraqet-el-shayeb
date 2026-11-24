# ARCHITECTURE — الشايب أونلاين | El Shayeb Online

## 1. نظرة عامة على النظام (System Overview)

يتكون مشروع **الشايب أونلاين** من طبقتين مفصولتين بحدود أمان صارمة:

1. **تطبيق العميل (Flutter Client — Android / iOS / Web):**
   - مبني بمعمارية Feature-Based مع `Riverpod` لإدارة الحالة وواجهة RTL كاملة بالمصري العامي.
   - يعرض فقط الحالة العامة المسموحة (`publicView`) بالإضافة إلى أوراق اللاعب المحلي فقط (`rooms/{roomId}/hands/{uid}`).
   - لا يملك أي صلاحية للكتابة المباشرة في حالة اللعبة أو النقاط أو الأوراق.
2. **الخادم المتحكم (Firebase Cloud Functions v2 + TypeScript Engine):**
   - محرك قواعد نقي (`functions/src/engine/`) مفصول عن البنية التحتية لـ Firebase، يضمن جميع الثوابت الرياضية (49 ورقة، شايب واحد، حفظ الأوراق، تصفية الأجواز، ترتيب الفلتان).
   - دوال سحابية (`onCall` في المنطقة `europe-west1`) تنفذ جميع العمليات داخل **Firestore Transactions** مع أرقام إصدار (`version`) ومعرفات عمليات (`actionId`) لمنع التكرار والتعارض.

---

## 2. دمج موديول المحرك الموازي (`el_shayeb_engine_parallel_module.zip`) وتوحيد المخطط

تم دمج جميع ملفات `src/engine/` و`firebase/functions/src/index.ts` و`flutter/lib/shayeb_game_bridge.dart` من الموديول الموازي مع توحيد الفروقات التصميمية التالية:

| البند | الموديول الموازي (`el_shayeb_engine`) | المعمارية الموحدة النهائية في المشروع |
|---|---|---|
| **تمثيل الأعضاء في الغرفة** | مصفوفة `memberIds: string[]` و`players: Player[]` داخل وثيقة `rooms/{roomId}` | الحفاظ على `memberIds` و`players` داخل `rooms/{roomId}` **بالإضافة إلى** مزامنة `rooms/{roomId}/players/{uid}` لدعم الاستعلامات وقواعد الأمان في الحالتين |
| **مسار حالة الجولة العامة** | `rooms/{roomId}/state/current` | كتابة الحالة العامة المصفاة (`publicView`) ذرياً في **كلا المسارين** `rooms/{roomId}/state/current` و`rooms/{roomId}/gameState/current` لضمان توافق 100% مع `ShayebGameBridge` ومع المواصفات الكاملة |
| **الحالة السرية للجولة** | `rooms/{roomId}/secret/round` (Admin SDK فقط) | معتمد ومغلق بالكامل في `firestore.rules` (`allow read, write: if false;`) |
| **أوراق اللاعب الخاصة** | `rooms/{roomId}/hands/{uid}` | قراءة `get` فقط للمالك العضو (`isOwner(playerUid) && isRoomMember(roomId)`) ومنع `list` و`write` تماماً |
| **منع تكرار السحب (Idempotency)** | `rooms/{roomId}/actions/{actionId}` | معتمد داخل Transaction في `drawCard` مع التحقق من ملكية `uid` للـ `actionId` |
| **اتجاه اللعب (Direction)** | `clockwise` (+1 في ترتيب المقاعد) و`counterclockwise` (-1) | ثابت ومفصول عن اتجاه واجهة RTL حتى لا ينعكس اتجاه اللعب بصرياً |
| **الأحكام والشات والمهلة** | غير منفذة في الموديول الموازي | تمت إضافتها بالكامل (`challenges.ts`، `stateMachine.ts`، `claimTurnTimeout`، `handleChallengeAction`، `leaveRoom`، `kickPlayer`، `rematchRoom`، و`messages`) |

---

## 3. مخطط قاعدة البيانات (Firestore Data Schema)

- `users/{uid}`: الملف الشخصي (`nickname`, `avatarId`) والإحصائيات الموثوقة المحمية من تعديل العميل.
- `rooms/{roomId}`: بيانات الغرفة، الإعدادات، قائمة اللاعبين، النقاط التراكمية (`scores`)، عدد مرات الخسارة (`losses`)، عدد مرات المركز الأول (`firstFinishes`)، والحكم النشط (`activeChallenge`).
- `rooms/{roomId}/players/{uid}`: نسخة متزامنة لحالة اللاعب واتصاله.
- `rooms/{roomId}/hands/{uid}`: أوراق اللاعب الخاصة (قراءة للمالك فقط).
- `rooms/{roomId}/state/current` و`rooms/{roomId}/gameState/current`: الحالة العامة للجولة (`handCounts`, `currentPlayerId`, `drawTargetId`, `finishOrder`, `version`, `turnDeadlineMs`, `discardCount`).
- `rooms/{roomId}/secret/round`: الحالة الكاملة للجولة (Admin SDK فقط).
- `rooms/{roomId}/actions/{actionId}`: سجل العمليات المنفذة لمنع تكرار السحب عند إعادة المحاولة.
- `rooms/{roomId}/messages/{messageId}`: رسائل الشات والريأكشنات ورسائل النظام الموثوقة.
- `rooms/{roomId}/challenges/{instanceId}`: سجل الأحكام المنفذة أو المتخطاة في الغرفة.
- `publicRooms/{roomId}`: دليل الغرف المفتوحة (بيانات عامة مصفاة فقط بدون أي بيانات حساسة).
- `roomCodes/{code}`: ربط كود الدعوة المكون من ٦ حروف بمعرف الغرفة (Admin SDK فقط لمنع تخمين الغرف الخاصة).
