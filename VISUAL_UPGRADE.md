# الشايب أونلاين | حزمة تطوير الكروت والمؤثرات — 24 نوفمبر 2026

هذه نسخة **el_shayeb_online_merged_complete.zip** الأصلية، مع تعديلات Flutter والأصول الصوتية الفعلية التي تمت إضافتها في هذه الجلسة. لا تحذف أو تعيد كتابة Cloud Functions / Firestore أو منطق اللعبة.

## ما تم تنفيذه داخل الكود

1. `lib/features/game/presentation/widgets/cafe_table_surface.dart` — ترابيزة قهوة مرسومة بـ CustomPainter (ملمس جوخ، زخرفة ذهبية، كوباية شاي)، وإضاءة ذهبية عند الدور.
2. `lib/features/game/presentation/widgets/animated_card_fan.dart` — مروحة كروت اليد بحركات دخول وإعادة ترتيب، ومروحة أوراق الخصم المقلوبة مع اختيار الورقة؛ لا تتلقى بيانات أوراق الخصم السرية.
3. `lib/features/game/presentation/game_table_screen.dart` — دمج المكونات الجديدة، تحريك عداد الأزواج والإشعارات، ومنع إرسال طلب انتهاء الدور أكثر من مرة لنفس إصدار الحالة/الجولة.
4. `lib/features/cards/presentation/playing_card_widget.dart` — انتقال مرئي بين وجه وظهر الورقة، مع الإبقاء على إخفاء معلومات الكروت المقلوبة.
5. `lib/features/results/presentation/widgets/king_reveal_fx.dart` — تقليب ثلاثي الأبعاد لكارت الشايب عند عرض النتائج فقط، مع احترام وضع تقليل الحركة.
6. `lib/features/results/presentation/results_and_challenges_screens.dart` — عرض مؤثر تقليب الشايب في النتائج.
7. `lib/core/sound/sound_service.dart` — تشغيل ملفات WAV أصلية للأحداث بدل الاعتماد على SystemSound وحده، مع الحفاظ على إعدادات كتم الصوت والاهتزاز.
8. `assets/sounds/` — عشرة ملفات WAV قصيرة تم توليدها خصيصًا للمشروع، ولا تستخدم محتوى موسيقي محفوظ الحقوق.
9. `pubspec.yaml` — إضافة `audioplayers: ^6.8.1` وأصول الصوت.
10. `test/game_visual_effects_test.dart` — اختبارات Widgets جديدة للكروت المقلوبة، واختيار الورق، ولمسة الترابيزة، ووضع تقليل الحركة عند ظهور الشايب.

## ما لم يتم ادعاؤه أو تنفيذه

- لا يوجد Flutter SDK في بيئة إنشاء هذا التحديث؛ لم يتم تنفيذ `flutter pub get` أو `flutter analyze` أو `flutter test` أو بناء APK/Web هنا.
- لم يتم تجربة ملفات الصوت على أجهزة أندرويد/iPhone/متصفح حقيقي.
- لم يتم تغيير المحرك أو اختبار Firebase على حساب فعلي؛ اختبارات Node التي تم تشغيلها هي اختبارات المحرك والمحاكاة فقط، وليست اختبار Firebase Emulator حقيقي.
- أنيميشن الكروت هنا دخول وإعادة ترتيب وتقليب؛ الحركة الكاملة من مقعد لاعب إلى الآخر مع مسارات طيران وكشف أزواج متزامن مع السيرفر تصلح لمرحلة ثانية.

## اختبارات backend الفعلية

تم تنفيذ:

```bash
node --experimental-strip-types --test functions/test/*.test.mjs
```

النتيجة: **28 passed, 0 failed** على Node v22.16.0. وقد استُخدم `--experimental-strip-types` لدعم ملفات TypeScript مباشرة من الاختبارات بدون بناء مسبق.

## التشغيل لدى المطوّر على ويندوز

```powershell
cd <PATH_TO_PROJECT>
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

شغّل كذلك `npm install` و`npm run build` داخل `functions/` بعد توفر الإنترنت وحزم Firebase.

## توجيه لمن يدمج المشروع مع نسخة verified

**مهم:** الملف الأصلي هنا هو `el_shayeb_online_merged_complete.zip` وليس بالضرورة `el_shayeb_online_verified.zip` الأحدث.

قارن ملفات الإصدارات قبل النسخ. عند دمج هذه التعديلات في verified، احتفظ بتغييرات الأمن وCloud Functions في verified، وخذ فقط ملفات الواجهة، والصوت، والاختبارات الجديدة، وتحديث `pubspec.yaml`. راجع الاختلافات في `game_table_screen.dart` و`game_controller.dart` قبل الاستبدال.
