import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../game/application/game_visual_theme_provider.dart';
import '../../game/domain/game_visual_theme.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';
import '../../challenges/domain/challenge_model.dart';
import '../../game/animations/challenge_reveal_animation.dart';
import '../../game/animations/defeat_animation.dart';
import '../../game/animations/game_animation_coordinator.dart';
import '../../game/animations/king_reveal_animation.dart';
import '../../game/animations/victory_animation.dart';
import '../../game/application/game_controller.dart';
import '../../game/domain/dart_rules_engine.dart';
import '../../game/domain/room_models.dart';

/// Displays either Round Results (with King reveal + Challenge Punishment card)
/// or Final Match Standings with deterministic tie-breaking and funny Egyptian titles.
class ResultsAndChallengeScreen extends ConsumerStatefulWidget {
  const ResultsAndChallengeScreen({
    super.key,
    required this.onOpenChat,
    required this.onReturnHome,
  });

  final VoidCallback onOpenChat;
  final VoidCallback onReturnHome;

  @override
  ConsumerState<ResultsAndChallengeScreen> createState() =>
      _ResultsAndChallengeScreenState();
}

class _ResultsAndChallengeScreenState
    extends ConsumerState<ResultsAndChallengeScreen> {
  final TextEditingController _proofController = TextEditingController();
  bool _showEvidenceField = false;
  bool _isRecordingVoiceMock = false;
  bool _hasRecordedVoiceClip = false;
  bool _isUploadingEvidenceImage = false;
  String? _uploadedMediaId;
  String? _uploadedMediaChallengeId;

  Future<void> _pickAndUploadChallengeImage(String challengeInstanceId) async {
    if (_isUploadingEvidenceImage) return;
    setState(() => _isUploadingEvidenceImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = ActiveGameSessionController.inferImageMimeType(picked.name);
      final mediaId = await ref
          .read(activeGameSessionProvider.notifier)
          .uploadRoomImage(
            bytes: bytes,
            fileName: picked.name,
            contentType: mime,
            challengeInstanceId: challengeInstanceId,
          );
      if (mediaId != null && mounted) {
        setState(() {
          _uploadedMediaId = mediaId;
          _uploadedMediaChallengeId = challengeInstanceId;
        });
      }
    } finally {
      if (mounted) setState(() => _isUploadingEvidenceImage = false);
    }
  }

  @override
  void dispose() {
    _proofController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeGameSessionProvider);
    final profile = ref.watch(playerProfileProvider);
    final room = session.room;
    final pub = session.publicRound;

    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isMatchFinished = room.status == 'finished';
    final isHost = room.hostId == profile.uid;
    final loserId = pub?.loserId;
    final loserName = room.nicknameOf(loserId);
    final finishOrder = pub?.finishOrder ?? room.players.map((p) => p.uid).toList();
    final roundPts = ShayebDartRulesEngine.roundPoints(finishOrder);
    final standings = MatchStandingRow.computeFromRoom(room);
    final challenge = room.activeChallenge;
    final quality = GameEffectsQuality.fromKey(
      profile.effectsQualityKey,
      reducedMotion: profile.reducedMotion,
    );
    final loserAvatar = room.avatarOf(loserId);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isMatchFinished
                ? ArEgStrings.matchResultTitle
                : '${ArEgStrings.roundResultTitle} (${room.roundNumber} / ${room.totalRounds})',
          ),
          actions: [
            IconButton(
              tooltip: ArEgStrings.roomChatTitle,
              onPressed: widget.onOpenChat,
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: ShayebColors.goldenAccent,
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: ShayebColors.feltTableGradient),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Match Victory Celebration Banner (Section 13)
                      if (isMatchFinished && standings.isNotEmpty)
                        CinematicVictoryBanner(
                          winnerNickname: standings.first.nickname,
                          winnerAvatarId: standings.first.avatarId,
                          totalPoints: standings.first.totalPoints,
                          quality: quality,
                        ),

                      // Playful Defeat Notice (Section 13)
                      CinematicDefeatNotice(
                        loserNickname: loserName,
                        isLocalPlayerLoser: loserId == profile.uid,
                      ),

                      // 4-Stage Cinematic King of Hearts (K♥) Reveal Banner (Section 8)
                      CinematicKingRevealBanner(
                        key: ValueKey('king_cinematic_${room.roundNumber}'),
                        loserUid: loserId ?? '',
                        loserNickname: loserName,
                        loserAvatarId: loserAvatar,
                        isLocalPlayerLoser: loserId == profile.uid,
                        firstFinisherNickname: finishOrder.isNotEmpty
                            ? room.nicknameOf(finishOrder.first)
                            : null,
                        quality: quality,
                      ),
                      const SizedBox(height: 16),

                      // Animated Challenge Reveal Card ("الحكم" — Section 14)
                      if (challenge != null) ...[
                        ChallengeRevealAnimation(
                          challengeInstance: challenge,
                          quality: quality,
                          revealedBody: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: ShayebColors.primaryDarkGreen,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: ShayebColors.softGold,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Text('⚖️ ', style: TextStyle(fontSize: 22)),
                                    Expanded(
                                      child: Text(
                                        'الحكم على ${challenge.loserNickname}:',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: ShayebColors.softGold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        challenge.challenge.categoryArabic,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: ShayebColors.cream,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '«${challenge.challenge.title}»',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: ShayebColors.cardWhite,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  challenge.challenge.description,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: ShayebColors.cream,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (challenge.status == 'pending') ...[
                                  if (!session.isOnlineFirebase ||
                                      challenge.loserUid == profile.uid) ...[
                                    if (_showEvidenceField) ...[
                                      TextField(
                                        controller: _proofController,
                                        maxLength: 240,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'اكتب تنفيذ الحكم أو النكتة أو الشعر هنا (يتنشر في شات القعدة)',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (session.isOnlineFirebase)
                                            OutlinedButton.icon(
                                              onPressed: _isUploadingEvidenceImage
                                                  ? null
                                                  : () => _pickAndUploadChallengeImage(
                                                        challenge.instanceId,
                                                      ),
                                              icon: _isUploadingEvidenceImage
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.photo_camera_back_outlined,
                                                      color: ShayebColors.goldenAccent,
                                                    ),
                                              label: Text(
                                                _isUploadingEvidenceImage
                                                    ? 'جاري رفع الصورة...'
                                                    : ((_uploadedMediaId != null &&
                                                            _uploadedMediaChallengeId ==
                                                                challenge.instanceId)
                                                        ? 'تم إرفاق صورة الإثبات ✅'
                                                        : 'ارفق صورة إثبات 📷'),
                                              ),
                                            )
                                          else
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  if (_isRecordingVoiceMock) {
                                                    _isRecordingVoiceMock = false;
                                                    _hasRecordedVoiceClip = true;
                                                  } else {
                                                    _isRecordingVoiceMock = true;
                                                  }
                                                });
                                              },
                                              icon: Icon(
                                                _isRecordingVoiceMock
                                                    ? Icons.stop_circle_rounded
                                                    : Icons.mic_rounded,
                                                color: _isRecordingVoiceMock
                                                    ? ShayebColors.richRed
                                                    : ShayebColors.goldenAccent,
                                              ),
                                              label: Text(
                                                _isRecordingVoiceMock
                                                    ? 'إيقاف التسجيل التجريبي'
                                                    : (_hasRecordedVoiceClip
                                                        ? 'تم تسجيل مقطع صوتي 🎙️✅'
                                                        : 'تسجيل تجريبي (وضع التدريب)'),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                    ] else
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () =>
                                              setState(() => _showEvidenceField = true),
                                          icon: const Icon(Icons.add_comment_rounded),
                                          label: const Text(ArEgStrings.addEvidenceBtn),
                                        ),
                                      ),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            final proof = _proofController.text.trim();
                                            final mediaProofId =
                                                _uploadedMediaChallengeId ==
                                                        challenge.instanceId
                                                    ? _uploadedMediaId
                                                    : null;
                                            ref
                                                .read(
                                                  activeGameSessionProvider.notifier,
                                                )
                                                .handleChallengeAction(
                                                  action: 'complete',
                                                  proofText: proof.isNotEmpty
                                                      ? proof
                                                      : (!session.isOnlineFirebase &&
                                                              _hasRecordedVoiceClip
                                                          ? '🎙️ [مقطع صوتي لتنفيذ الحكم]'
                                                          : null),
                                                  proofMediaId: mediaProofId,
                                                );
                                          },
                                          icon: const Icon(Icons.check_circle_rounded),
                                          label: const Text('نفّذ الحكم'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: challenge.redrawCount < 2
                                              ? () {
                                                  ref
                                                      .read(
                                                        activeGameSessionProvider
                                                            .notifier,
                                                      )
                                                      .handleChallengeAction(
                                                        action: 'redraw',
                                                      );
                                                }
                                              : null,
                                          icon: const Icon(Icons.casino_rounded),
                                          label: Text(
                                            'غيّر الحكم (${2 - challenge.redrawCount})',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            ref
                                                .read(
                                                  activeGameSessionProvider.notifier,
                                                )
                                                .handleChallengeAction(action: 'skip');
                                          },
                                          child: const Text(
                                            'عدّي المرة دي',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '⏳ مستنيين ${challenge.loserNickname} ينفذ الحكم أو يغيره...',
                                        style: const TextStyle(
                                          color: ShayebColors.softGold,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ] else
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      challenge.status == 'completed'
                                          ? '✅ ${challenge.loserNickname} نفّذ الحكم برجولة! ${challenge.proofText != null ? "«${challenge.proofText}»" : ""}'
                                          : '😅 ${challenge.loserNickname} عدّى الحكم المرة دي.',
                                      style: const TextStyle(
                                        color: ShayebColors.softGold,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Match Scoreboard & Deterministic Tie-Break Standings
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                isMatchFinished
                                    ? '🏆 الترتيب النهائي للماتش وألقاب القهوة'
                                    : '📊 جدول النقط بعد الجولة ${room.roundNumber}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: ShayebColors.goldenAccent,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...standings.map((row) {
                                final emoji =
                                    ArEgStrings.avatars[row.avatarId]?['emoji'] ??
                                        '🧔🏻‍♂️';
                                final earnedThisRound = roundPts[row.uid] ?? 0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: row.placement == 1
                                        ? ShayebColors.goldenAccent
                                            .withValues(alpha: 0.18)
                                        : Colors.black26,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: row.placement == 1
                                          ? ShayebColors.goldenAccent
                                          : Colors.white12,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: ShayebColors.warmWoodBrown,
                                        child: Text(
                                          '#${row.placement}',
                                          style: const TextStyle(
                                            color: ShayebColors.goldenAccent,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(emoji, style: const TextStyle(fontSize: 22)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              row.nickname,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: ShayebColors.cardWhite,
                                              ),
                                            ),
                                            Text(
                                              '${row.titleAr} • لبس الشايب: ${row.roundsLost} مرة',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: ShayebColors.softGold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${row.totalPoints} نقطة',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: ShayebColors.goldenAccent,
                                            ),
                                          ),
                                          Text(
                                            '+$earnedThisRound في الجولة دي',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: ShayebColors.successGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Next Round / Play Again / Return Home Controls
                      if (!isMatchFinished) ...[
                        if (isHost)
                          ElevatedButton.icon(
                            onPressed: () {
                              ref
                                  .read(activeGameSessionProvider.notifier)
                                  .startNextRound();
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              '${ArEgStrings.nextRoundBtn} (${room.roundNumber + 1} من ${room.totalRounds})',
                            ),
                          )
                        else
                          const Text(
                            'مستنيين صاحب القعدة يبدأ الجولة الجاية...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ShayebColors.softGold),
                          ),
                      ] else ...[
                        if (isHost)
                          ElevatedButton.icon(
                            onPressed: () {
                              ref
                                  .read(activeGameSessionProvider.notifier)
                                  .rematch();
                            },
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text(ArEgStrings.playAgainBtn),
                          ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(activeGameSessionProvider.notifier)
                                .leaveCurrentRoom();
                            widget.onReturnHome();
                          },
                          icon: const Icon(Icons.home_rounded),
                          label: const Text(ArEgStrings.backToHomeBtn),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        icon: '🃏',
        title: '١. ورق الكوتشينة (٤٩ ورقة)',
        body:
            'بنلعب بكوتشينة ٥٢ ورقة من غير جواكر، وبنشيل ٣ شوايب ونسيب شايب واحد بس هو «شايب القلوب ♥» اللي ملوش جوز!'
      ),
      (
        icon: '🎯',
        title: '٢. تصفية الأجواز أوتوماتيك',
        body:
            'أول ما الورق يتوزع، أي ورقتين ليهم نفس الرقم (زي سبعتين أو بنتين) بينزلوا فوراً على الترابيزة. لو معاك ٤ ورقات من نفس الرقم بينزلوا جوزين!'
      ),
      (
        icon: '🤏',
        title: '٣. السحب بالدور',
        body:
            'في دورك، بتسحب ورقة واحدة مقلوبة من اللاعب اللي عليه السحب جنبك. لو عملت جوز مع ورقك بينزل أوتوماتيك!'
      ),
      (
        icon: '🏃‍♂️',
        title: '٤. الفلتان والنقط',
        body:
            'اللي ورقه يخلص الأول بيفلت من الشايب وياخد أعلى نقط (N-1)، والتاني ياخد (N-2).. لحد آخر واحد يتبقى معاه الشايب لوحده في إيده بياخد صفر!'
      ),
      (
        icon: '⚖️',
        title: '٥. حكم الشايب',
        body:
            'اللي الشايب يلبس فيه في آخر الجولة بينزل عليه حكم مصري كوميدي من ٣٠ حكم (تمثيل، تعليق كورة، شعر، أو نكتة)، ويقدر ينفذه أو يغيره!'
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          title: const Text(ArEgStrings.howToPlay),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: steps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final s = steps[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.icon, style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: ShayebColors.goldenAccent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.body,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: ShayebColors.cream,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ChallengesLibraryScreen extends StatelessWidget {
  const ChallengesLibraryScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          title: const Text(ArEgStrings.challengesLibrary),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: kEgyptianChallengesCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ch = kEgyptianChallengesCatalog[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: ShayebColors.warmWoodBrown,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: ShayebColors.goldenAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ch.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: ShayebColors.goldenAccent,
                            ),
                          ),
                        ),
                        Text(
                          ch.categoryArabic,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ShayebColors.softGold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        ch.description,
                        style: const TextStyle(
                          color: ShayebColors.cream,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    required this.onBack,
    required this.onEditProfile,
    required this.onOpenHowToPlay,
  });

  final VoidCallback onBack;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenHowToPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final notifier = ref.read(playerProfileProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          title: const Text(ArEgStrings.settings),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: Text(
                      ArEgStrings.avatars[profile.avatarId]?['emoji'] ?? '🧔🏻‍♂️',
                      style: const TextStyle(fontSize: 30),
                    ),
                    title: Text(
                      profile.nickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ShayebColors.cream,
                      ),
                    ),
                    subtitle: const Text('تغيير الاسم أو الشخصية'),
                    trailing: const Icon(
                      Icons.edit_rounded,
                      color: ShayebColors.goldenAccent,
                    ),
                    onTap: onEditProfile,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('المؤثرات الصوتية'),
                        subtitle: const Text('صوت تفنيط الورق والسحب والأحكام'),
                        value: profile.soundEnabled,
                        activeThumbColor: ShayebColors.goldenAccent,
                        onChanged: (v) => notifier.updateProfile(soundEnabled: v),
                      ),
                      if (profile.soundEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.volume_down_rounded,
                                color: ShayebColors.goldenAccent,
                              ),
                              Expanded(
                                child: Slider(
                                  value: profile.soundVolume,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 10,
                                  label: '${(profile.soundVolume * 100).round()}%',
                                  activeColor: ShayebColors.goldenAccent,
                                  onChanged: (v) =>
                                      notifier.updateProfile(soundVolume: v),
                                ),
                              ),
                              const Icon(
                                Icons.volume_up_rounded,
                                color: ShayebColors.goldenAccent,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 1, color: Colors.white12),
                      SwitchListTile(
                        title: const Text('الاهتزاز التفاعلي (Haptics)'),
                        subtitle: const Text('اهتزاز خفيف لما ييجي دورك أو تنزل جوز'),
                        value: profile.hapticsEnabled,
                        activeThumbColor: ShayebColors.goldenAccent,
                        onChanged: (v) => notifier.updateProfile(hapticsEnabled: v),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      SwitchListTile(
                        title: const Text('تقليل الحركة والأنيميشن'),
                        subtitle: const Text('مناسب للأجهزة الضعيفة وتوفير البطارية'),
                        value: profile.reducedMotion,
                        activeThumbColor: ShayebColors.goldenAccent,
                        onChanged: (v) => notifier.updateProfile(reducedMotion: v),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مستوى المؤثرات السينمائية (Game Effects)',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: ShayebColors.goldenAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tier in GameEffectsQuality.values)
                                  ChoiceChip(
                                    label: Text(tier.arabicLabel),
                                    selected:
                                        profile.effectsQualityKey == tier.key,
                                    onSelected: (_) => notifier.updateProfile(
                                      effectsQualityKey: tier.key,
                                      reducedMotion:
                                          tier == GameEffectsQuality.minimal,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('شكل الترابيزة',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 5),
                        const Text('غيّر شكل القعدة في أي وقت، من غير ما تأثر على اللعب',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final type in GameVisualThemeType.values)
                              ChoiceChip(
                                label: Text(GameVisualTheme.fromType(type).title),
                                avatar: Icon(
                                  type == GameVisualThemeType.ahwaClassic
                                      ? Icons.local_cafe_rounded
                                      : Icons.nights_stay_rounded,
                                  size: 16,
                                ),
                                selected: ref.watch(gameVisualThemeProvider) == type,
                                onSelected: (_) => ref.read(gameVisualThemeProvider.notifier)
                                    .setTheme(type),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.menu_book_rounded,
                          color: ShayebColors.goldenAccent,
                        ),
                        title: const Text(ArEgStrings.howToPlay),
                        onTap: onOpenHowToPlay,
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      const ListTile(
                        leading: Icon(
                          Icons.shield_outlined,
                          color: ShayebColors.goldenAccent,
                        ),
                        title: Text('الخصوصية والأمان'),
                        subtitle: Text(
                          'ورقك خاص بيك على السيرفر ومحدش يقدر يكشفه، والأحكام كلها اختيارية وآمنة.',
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      ListTile(
                        leading: const Icon(
                          Icons.restore_rounded,
                          color: ShayebColors.richRed,
                        ),
                        title: const Text('إعادة ضبط الإعدادات المحلية'),
                        onTap: () async {
                          await notifier.resetPreferences();
                          await ref.read(gameVisualThemeProvider.notifier)
                              .setTheme(GameVisualThemeType.ahwaClassic);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إعادة ضبط الإعدادات بنجاح'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
