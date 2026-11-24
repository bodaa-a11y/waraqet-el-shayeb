# الواجهتين الرسميتين — قهوة البلد / ليالي النيل

## التنفيذ المنجز

- **قهوة البلد:** صورة التصميم الأولى كخلفية جوية + ترابيزة خشب مرسومة بشكل تفاعلي + كوباية شاي + إطارات ذهبية.
- **ليالي النيل:** صورة التصميم الثانية كخلفية جوية + ترابيزة خضراء بيضاوية بإطار خشب وذهب.
- زر تبديل داخل شاشة اللعب؛ الاختيار محفوظ محليًا عبر `SharedPreferences`.
- أماكن اللاعبين (من 2 إلى 6): توزيع حول الترابيزة على الشاشات الواسعة، وشريط قابل للتمرير على الموبايل.
- صور الشخصيات مقصوصة من التصورين المقدمين، كأفاتارات مرئية؛ لا توجد بيانات شخصية حقيقية في الصور.
- نفس شاشة اللعبة مرتبطة بـ `activeGameSessionProvider`: أوراق اللاعب الحقيقية، عدد ورق الخصوم فقط، السحب من اللاعب المحدد، الشات، الريأكشنات، الترتيب، المؤقت، وترك القعدة.
- لا يوجد تغيير في محرك TypeScript أو بيانات Firebase أو قواعد اللعبة؛ تبديل الشكل لا يرسل أي تغيير للسيرفر.

## ملفات جديدة أساسية

- `lib/features/game/domain/game_visual_theme.dart`
- `lib/features/game/application/game_visual_theme_provider.dart`
- `lib/features/game/presentation/widgets/theme_switcher.dart`
- `lib/features/game/presentation/widgets/egyptian_scene_background.dart`
- `lib/features/game/presentation/widgets/cinematic_table_surface.dart`
- `lib/features/game/presentation/widgets/player_seat_layout.dart`
- `assets/images/themes/ahwa_classic_bg.jpg`
- `assets/images/themes/nile_royal_bg.jpg`
- `assets/images/avatars/avatar_1.jpg` ... `avatar_6.jpg`
- `test/dual_game_themes_test.dart`

## ملفات معدلة

- `lib/features/game/presentation/game_table_screen.dart` — إعادة بناء واجهة الترابيزة مع الحفاظ على ربط السيرفر.
- `lib/main.dart` — استرجاع الثيم المحفوظ عند فتح التطبيق.
- `pubspec.yaml` — إضافة مسارات الصور.

## مهم بخصوص التصميمين المرجعيين

الصور المقدمة من المستخدم عبارة عن *concept art* تحتوي أصلًا على كروت وأزرار ثابتة. تُستخدم فقط كخلفيات للمشهد، وتغطيها ترابيزة Flutter معتمة في مساحة اللعب. العناصر القابلة للسحب والنقر واللاعبون في اللعبة هي Widgets منفصلة مرتبطة بحالة اللاعب؛ لا يجب اعتبار الصورة الثابتة بديلاً عن واجهة تفاعلية. الدقة البصرية لرسوم CustomPainter ليست نسخة ثلاثية الأبعاد مطابقة للصورة، وإنما تفسير Flutter عملي وقابل للتوسعة.

## الفحص والتشغيل

```powershell
flutter pub get
flutter analyze
flutter test test/dual_game_themes_test.dart
flutter test
flutter run -d chrome
```

لاختبار اللعب أونلاين لازم تكوين Firebase وتشغيل المحاكيات أو المشروع الحقيقي (راجع `README.md`).

**حالة التحقق:** اختبارات Node لمحرك اللعبة تعمل في البيئة الحالية. تعذر اختبار Flutter أو توليد APK هنا لعدم توفر Flutter SDK؛ شغّل الأوامر السابقة على جهاز ويندوز الذي عليه Flutter.
