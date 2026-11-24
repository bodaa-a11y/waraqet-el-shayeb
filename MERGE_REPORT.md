# تقرير الدمج الشامل والمراجعة الفنية | MERGE_REPORT.md

يوضح هذا التقرير كيفية فحص ودمج وتوحيد الكود المصدري من الأرشيفين المستقلين:
- **Archive A:** `shayeb-online-engine.zip` (المحرك الأساسي، اختبارات التوزيع الموحد، ٢,٠٠٠ جولة محاكاة، كسر التعادل، وبذرة الـ ٣٠ حكماً مصرياً).
- **Archive B:** `el_shayeb_engine_parallel_module.zip` (محرك السحب بالإصدارات `version`، دوال Firebase Cloud Functions v2، وجسر Flutter `shayeb_game_bridge.dart` مع شاشة الترابيزة التجريبية `shayeb_table_screen.dart`).

---

## 1. القرارات الهندسية وتوحيد المحرك (Canonical Engine Decisions)

| الملف / الوحدة | المصدر الأساسي | الإجراء المتخذ (Preserved / Modified / Merged) | سبب القرار الهندسي |
|---|---|---|---|
| `functions/src/engine/deck.ts` & `cards.ts` | Archive A + B | **Merged & Unified** | توحيد تمثيل الورقة (`id: "${rank}:${suit}"`, `rank`, `suit`) ليتوافق مباشرةً مع تسلسل JSON في Firestore وFlutter مع الحفاظ على دوال `createDeck` (Archive A) و`makeDeck` (Archive B) و`DECK_SIZE = 49`. |
| `functions/src/engine/shuffle.ts` & `random.ts` | Archive A + B | **Merged & Unified** | دمج `crypto.randomInt` / Rejection Sampling مع دعم تمرير `rand?: RandomInt` الاختياري من Archive A للاختبارات الحتمية (`seeded PRNG`)، بالإضافة إلى `generateRoomCode(6)` لأكواد الغرف الخالية من الحروف الملتبسة. |
| `functions/src/engine/deal.ts` | Archive A | **Preserved** | توزيع دوري (`dealCards`) ورقة بورقة يدعم تفاوت حجم اليد (`13, 12, 12, 12`). |
| `functions/src/engine/pairing.ts` & `pairs.ts` | Archive A + B | **Merged & Unified** | خوارزمية موحدة (`removePairs` / `resolvePairs`) تصفي كل جوز متماثل في الرتبة (بما فيها ٤ ورقات = جوزين) ولا تصفي الشايب أبداً، وتُرجع كلاً من `pairs: [Card, Card][]` و`discarded: Card[]` و`pairCount`. |
| `functions/src/engine/turns.ts` | Archive A | **Preserved** | دالة `nextActive` لتحديد أقرب لاعب نشط في الاتجاهين (`clockwise` و`counterclockwise`) بمعزل عن اتجاه واجهة RTL. |
| `functions/src/engine/round.ts` | Archive A + B | **Merged & Refactored** | توحيد `startRound` (Archive A) و`makeRound` (Archive B) و`applyDraw` / `drawCard` في آلة حالة واحدة تضيف: ١) تدوير مقعد البداية حسب `roundNumber` لمنع انحياز مقعد المضيف، ٢) رقم إصدار `version` لمنع التزامن القديم، ٣) `turnDeadlineMs` و`autoDrawOnTimeout` لمعالجة انقطاع الاتصال، ٤) `publicView()` لتجريد حالة الجولة من أي هويات كروت سرية. |
| `functions/src/engine/scoring.ts` | Archive A + B | **Merged & Unified** | الحفاظ على `roundPoints` (`N-1..0`)، و`emptyTotals`، و`applyRound`، و`rankMatch` (كسر التعادل: النقاط، ثم أقل خسائر، ثم أكثر مركز أول، ثم مشاركة المركز `1, 1, 3`) مع إضافة الألقاب المصرية الكوميدية (`معلم القهوة الكبير 👑`, `شايب القعدة الرسمي 👴`). |
| `functions/src/engine/gameInvariants.ts` | Archive A + B | **Merged & Unified** | توحيد `assertInvariants` و`assertRoundInvariants` لفحص جميع الـ ١٥ ثابتاً رياضياً وأمنياً بعد كل نقلة. |
| `functions/src/challenges/challenges.ts` & `data/challenges.json` | Archive A | **Preserved & Integrated** | الحفاظ على ملف `challenges.json` (٣٠ حكماً مصرياً) ودالة `pickChallenge(all, recentIds, rand)` ودمجها مع Cloud Functions (`assignChallenge`, `redrawChallenge`, `completeChallenge`). |
| `functions/src/index.ts` | Archive B (Extended) | **Refactored & Expanded** | توسيع الدوال السحابية من ٦ دوال أولية في Archive B إلى **١٤ دالة سحابية كاملة** (`createRoom`, `joinRoomByCode`, `leaveRoom`, `setPlayerReady`, `updateRoomSettings`, `startGame`, `drawCard`, `getRoomState`, `advanceToNextRound`, `assignChallenge`, `completeChallenge`, `redrawChallenge`, `sendRoomMessage`, `restartMatch` + `kickPlayer`, `claimTurnTimeout`, `cleanupExpiredRooms`). |
| `firestore.rules` & `storage.rules` | Archive A + B | **Audited & Deduplicated** | إزالة التكرار غير الضروري في Firestore: اعتماد `rooms/{roomId}` (`memberIds` و`players`) كمصدر وحيد للأعضاء، و`rooms/{roomId}/state/current` كمصدر وحيد للحالة العامة، و`rooms/{roomId}/hands/{uid}` كمسار خاص للمالك فقط، و`rooms/{roomId}/secret/round` للـ Admin SDK فقط. |
| `lib/shayeb_game_bridge.dart` | Archive B | **Preserved & Extended** | الحفاظ على جميع دوال Archive B الأصلية وإضافة دوال الـ ١٤ Callable الجديدة ورفع أدلة الأحكام (`uploadChallengeEvidence`) ومستمعي الشات. |
| `lib/shayeb_table_screen.dart` | Archive B | **Preserved** | محفوظ كما هو للتوافق العكسي، بينما تم بناء الترابيزة الكاملة متعددة المقاعد (٢–٦ لاعبين) في `lib/features/game/presentation/game_table_screen.dart`. |

---

## 2. إزالة التكرار في Firestore (Audit Task 7 — Deduplication)

خلال مراجعة الجاهزية للإنتاج، تم رصد وإزالة التكرارين التاليين في تمثيل حالة Firestore:
1. **إلغاء ازدواجية `rooms/{roomId}/gameState/current` و`rooms/{roomId}/state/current`:** تم توحيد الكتابة والقراءة على المسار القياسي `rooms/{roomId}/state/current` فقط، مما يقلل عمليات الكتابة في كل سحبة ورقة.
2. **إلغاء ازدواجية `rooms/{roomId}/players/{uid}` مع مصفوفة `rooms/{roomId}.players`:** تم اعتماد مصفوفة `players` و`memberIds` داخل وثيقة `rooms/{roomId}` كمصدر وحيد متزامن ذرياً، مما يوفر ما يصل إلى ٦ عمليات كتابة إضافية في كل Transaction ويمنع أي تضارب في البيانات.
