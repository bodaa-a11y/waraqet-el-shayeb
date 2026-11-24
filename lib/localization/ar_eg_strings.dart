/// Centralized Egyptian Colloquial Arabic (المصري العامي) Localization.
/// Every player-facing string in the application is defined here.
class ArEgStrings {
  ArEgStrings._();

  // Brand & Core Titles
  static const String gameTitle = 'ورقة الشايب';
  static const String gameSubtitle = 'قعدة كوتشينة مصرية مع الصحاب ☕🃏';
  static const String playNow = 'يلا نلعب';
  static const String createRoom = 'اعمل قعدة';
  static const String joinRoomByCode = 'ادخل بكود';
  static const String publicRooms = 'قعدات مفتوحة';
  static const String howToPlay = 'بتتلعب إزاي؟';
  static const String challengesLibrary = 'دفتر الأحكام (٣٠ حكم)';
  static const String settings = 'الإعدادات';

  // Onboarding & Profile
  static const String welcomeHeadline = 'منور القهوة يا معلم!';
  static const String welcomeBody =
      'العب ورقة الشايب مع شلتك من ٢ لـ ٦ لعيبة.. صفّي أجوازك، واهرب من شايب القلوب قبل ما يلبس فيك الحكم!';
  static const String chooseNicknameTitle = 'اسمك إيه في القعدة؟';
  static const String chooseNicknameHint = 'مثلاً: المعلم رضا، حريف الدومينو...';
  static const String chooseAvatarTitle = 'اختار شكلك على الترابيزة';
  static const String saveAndEnter = 'احفظ وادخل القهوة';
  static const String skipUseDefault = 'دخول سريع باسم تلقائي';

  // Avatars
  static const Map<String, Map<String, String>> avatars = {
    'avatar_1': {'emoji': '🧔🏻‍♂️', 'name': 'المعلم الكبير'},
    'avatar_2': {'emoji': '😎', 'name': 'البرنس الرايق'},
    'avatar_3': {'emoji': '👳🏽‍♂️', 'name': 'عم الحاج'},
    'avatar_4': {'emoji': '🧕🏻', 'name': 'الست الكل'},
    'avatar_5': {'emoji': '🤠', 'name': 'حريف الورق'},
    'avatar_6': {'emoji': '🦁', 'name': 'أسد الترابيزة'},
    'avatar_7': {'emoji': '☕', 'name': 'ملك الخمسينة'},
    'avatar_8': {'emoji': '👑', 'name': 'سلطان القعدة'},
  };

  // Room Creation & Joining
  static const String roomTitleLabel = 'اسم القعدة';
  static const String maxPlayersLabel = 'عدد اللعيبة (٢ - ٦)';
  static const String roundsCountLabel = 'عدد الجولات';
  static const String drawDirectionLabel = 'اتجاه السحب';
  static const String clockwise = 'يمين (مع عقارب الساعة)';
  static const String counterclockwise = 'شمال (عكس عقارب الساعة)';
  static const String challengeModeLabel = 'نظام الأحكام';
  static const String challengeEveryRound = 'حكم بعد كل جولة 🔥';
  static const String challengeEndOfMatch = 'حكم في آخر الماتش بس 👑';
  static const String challengeDisabled = 'من غير أحكام (لعب صافي)';
  static const String roomVisibilityLabel = 'نوع القعدة';
  static const String privateRoom = 'قعدة خاصة (بكود بس)';
  static const String publicRoom = 'قعدة مفتوحة (تظهر للكل)';
  static const String turnTimerLabel = 'وقت السحبة';
  static const String timer45Sec = '٤٥ ثانية (مظبوط)';
  static const String timer30Sec = '٣٠ ثانية (سريع)';
  static const String timerOff = 'من غير وقت';
  static const String enterCodeTitle = 'اكتب كود القعدة المكون من ٦ حروف';
  static const String enterCodeHint = 'مثال: SH7K29';
  static const String joinNow = 'خش القعدة';
  static const String noPublicRooms = 'مفيش قعدات مفتوحة دلوقتي.. افتح إنت قعدة ولمّ الشلة!';
  static const String refreshRooms = 'تحديث القعدات';

  // Lobby
  static const String lobbyTitle = 'قعدة الصحاب';
  static const String roomCodePrefix = 'كود القعدة:';
  static const String copyCode = 'انسخ الكود';
  static const String codeCopied = 'الكود اتنسخ! ابعته لصحابك يلا 🔥';
  static const String shareRoom = 'ابعت الدعوة';
  static const String readyBtn = 'أنا جاهز ✅';
  static const String unreadyBtn = 'ثانية واحدة ✋';
  static const String startGameBtn = 'يلا نبدأ ووزّع الورق! 🃏';
  static const String waitingForHost = 'مستنيين صاحب القعدة يبدأ اللعب...';
  static const String waitingForPlayersReady = 'لازم على الأقل ٢ لعيبة وكلهم يبقوا جاهزين';
  static const String hostBadge = 'صاحب القعدة 👑';
  static const String readyBadge = 'جاهز';
  static const String notReadyBadge = 'لسه بيجهز';
  static const String leaveRoom = 'قوم من القعدة';

  // Game Table & Turn Flow
  static const String yourTurn = 'دورك يا معلم! اسحب ورقة';
  static const String waitingTurn = 'استنى دورك...';
  static const String drawCardBtn = 'اسحب ورقة';
  static const String pairRemoved = 'عاش! نزلت جوز 🎯';
  static const String playerEscaped = 'فلت منها! 🏃‍♂️✨';
  static const String lostRound = 'الشايب لبس فيك! 👴👑';
  static const String holdingShayebWarning = 'إوعى تفضح نفسك.. الشايب في إيدك! 🤫👴';
  static const String sortHandBtn = 'رتّب ورقي';
  static const String shuffleHandViewBtn = 'لخبط مكان ورقي';
  static const String discardPileLabel = 'الأجواز اللي نزلت';
  static const String yourHandLabel = 'ورقك';

  // Challenges & Evidence
  static const String challengeHeadline = 'الحكم عليك يا نجم! ⚖️🔥';
  static const String executeChallengeBtn = 'نفّذت الحكم برجولة ✅';
  static const String redrawChallengeBtn = 'غيّر الحكم 🎲';
  static const String skipChallengeBtn = 'عدّيها المرة دي 😅';
  static const String addEvidenceBtn = 'إرفاق دليل (نص / صورة / صوت - اختياري)';
  static const String evidenceTitle = 'توثيق تنفيذ الحكم (اختياري)';
  static const String evidenceNote =
      'الدليل اختياري تماماً للضحك مع صحابك في القعدة، وتقدر تمسحه في أي وقت.';

  // Chat & Reactions
  static const String roomChatTitle = 'شات القعدة 💬';
  static const String chatInputHint = 'اكتب حاجة للشلة...';
  static const String sendBtn = 'ابعت';
  static const List<String> quickReactions = ['😂', '😱', '👑', '💀', '☕', '👴', '🔥'];

  // Results
  static const String roundResultTitle = 'نتيجة الجولة';
  static const String matchResultTitle = 'الترتيب النهائي للماتش 🏆';
  static const String nextRoundBtn = 'يلا الجولة الجاية 🃏';
  static const String playAgainBtn = 'نعيدها؟ 🔄';
  static const String backToLobbyBtn = 'ارجع للقعدة';
  static const String backToHomeBtn = 'الرجوع للرئيسية';

  // Connection & Errors
  static const String connectionLost = 'النت فصل... بنحاول نرجعك للقعدة';
  static const String reconnectedSuccess = 'رجعت للقعدة بالسلامة! ورقتك محفوظة';
  static const String genericError = 'حصلت لخبطة بسيطة، جرّب تاني يا معلم';
  static const String invalidNicknameError =
      'الاسم لازم يكون بين حرفين و ٢٤ حرف ومن غير رموز غريبة';
  static const String invalidRoomCodeError = 'كود القعدة لازم يكون ٦ حروف أو أرقام';
}
