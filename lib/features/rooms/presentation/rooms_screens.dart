import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../shayeb_game_bridge.dart';
import '../../../theme/shayeb_theme.dart';
import '../../game/application/game_controller.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({
    super.key,
    required this.onRoomCreated,
    required this.onBack,
  });

  final void Function(String roomId) onRoomCreated;
  final VoidCallback onBack;

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final TextEditingController _titleController = TextEditingController();
  int _maxPlayers = 4;
  int _totalRounds = 5;
  String _direction = 'clockwise';
  String _visibility = 'private';
  String _challengeMode = 'every_round';
  int _turnTimerSeconds = 45;
  bool _localPracticeMode = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final profile = ref.read(playerProfileProvider);
    final title = _titleController.text.trim().isEmpty
        ? 'قعدة ${profile.nickname}'
        : _titleController.text.trim();
    final roomId = await ref.read(activeGameSessionProvider.notifier).createRoom(
          title: title,
          maxPlayers: _maxPlayers,
          totalRounds: _totalRounds,
          direction: _direction,
          visibility: _visibility,
          challengeMode: _challengeMode,
          turnTimerSeconds: _turnTimerSeconds,
          localPracticeMode: _localPracticeMode,
        );
    if (roomId != null && mounted) {
      widget.onRoomCreated(roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeGameSessionProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onBack,
          ),
          title: const Text(ArEgStrings.createRoom),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        maxLength: 32,
                        decoration: const InputDecoration(
                          labelText: ArEgStrings.roomTitleLabel,
                          hintText: 'مثلاً: سهرة الخميس، شلة القهوة...',
                          prefixIcon: Icon(
                            Icons.local_cafe_rounded,
                            color: ShayebColors.goldenAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Max Players (2 - 6)
                      const Text(
                        ArEgStrings.maxPlayersLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ShayebColors.goldenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [2, 3, 4, 5, 6].map((count) {
                          final selected = _maxPlayers == count;
                          return ChoiceChip(
                            label: Text('$count لعيبة'),
                            selected: selected,
                            onSelected: (_) => setState(() => _maxPlayers = count),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Round Count (1, 3, 5)
                      const Text(
                        ArEgStrings.roundsCountLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ShayebColors.goldenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [1, 3, 5].map((rounds) {
                          final selected = _totalRounds == rounds;
                          return ChoiceChip(
                            label: Text(rounds == 1 ? 'جولة واحدة' : '$rounds جولات'),
                            selected: selected,
                            onSelected: (_) => setState(() => _totalRounds = rounds),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Draw Direction
                      const Text(
                        ArEgStrings.drawDirectionLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ShayebColors.goldenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text(ArEgStrings.clockwise),
                            selected: _direction == 'clockwise',
                            onSelected: (_) => setState(() => _direction = 'clockwise'),
                          ),
                          ChoiceChip(
                            label: const Text(ArEgStrings.counterclockwise),
                            selected: _direction == 'counterclockwise',
                            onSelected: (_) =>
                                setState(() => _direction = 'counterclockwise'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Challenge Mode
                      const Text(
                        ArEgStrings.challengeModeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ShayebColors.goldenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text(ArEgStrings.challengeEveryRound),
                            selected: _challengeMode == 'every_round',
                            onSelected: (_) =>
                                setState(() => _challengeMode = 'every_round'),
                          ),
                          ChoiceChip(
                            label: const Text(ArEgStrings.challengeEndOfMatch),
                            selected: _challengeMode == 'end_of_match',
                            onSelected: (_) =>
                                setState(() => _challengeMode = 'end_of_match'),
                          ),
                          ChoiceChip(
                            label: const Text(ArEgStrings.challengeDisabled),
                            selected: _challengeMode == 'disabled',
                            onSelected: (_) =>
                                setState(() => _challengeMode = 'disabled'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Visibility
                      const Text(
                        ArEgStrings.roomVisibilityLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ShayebColors.goldenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text(ArEgStrings.privateRoom),
                            selected: _visibility == 'private',
                            onSelected: (_) => setState(() => _visibility = 'private'),
                          ),
                          ChoiceChip(
                            label: const Text(ArEgStrings.publicRoom),
                            selected: _visibility == 'public',
                            onSelected: (_) => setState(() => _visibility = 'public'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Turn Timer
                      const Text(
                        ArEgStrings.turnTimerLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ShayebColors.goldenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text(ArEgStrings.timer45Sec),
                            selected: _turnTimerSeconds == 45,
                            onSelected: (_) => setState(() => _turnTimerSeconds = 45),
                          ),
                          ChoiceChip(
                            label: const Text(ArEgStrings.timer30Sec),
                            selected: _turnTimerSeconds == 30,
                            onSelected: (_) => setState(() => _turnTimerSeconds = 30),
                          ),
                          ChoiceChip(
                            label: const Text(ArEgStrings.timerOff),
                            selected: _turnTimerSeconds == 0,
                            onSelected: (_) => setState(() => _turnTimerSeconds = 0),
                          ),
                        ],
                      ),
                      const Divider(height: 28, color: Colors.white24),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'وضع التدريب المحلي مع بوتات القهوة (بدون إنترنت)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ShayebColors.cream,
                          ),
                        ),
                        subtitle: const Text(
                          'فعّل الاختيار ده لو عايز تجرب القعدة دلوقتي من غير سيرفر أونلاين',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        value: _localPracticeMode,
                        activeThumbColor: ShayebColors.goldenAccent,
                        onChanged: (v) => setState(() => _localPracticeMode = v),
                      ),

                      if (session.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ShayebColors.richRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ShayebColors.richRed),
                          ),
                          child: Column(
                            children: [
                              Text(
                                session.errorMessage!,
                                style: const TextStyle(
                                  color: ShayebColors.cardWhite,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() => _localPracticeMode = true);
                                  _submit();
                                },
                                icon: const Icon(Icons.bolt_rounded),
                                label: const Text('افتحها كقعدة تدريب محلية دلوقتي'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: session.isConnecting ? null : _submit,
                        icon: session.isConnecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.meeting_room_rounded),
                        label: Text(
                          session.isConnecting ? 'بنجهز الترابيزة...' : 'افتح القعدة يلا!',
                        ),
                      ),
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

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({
    super.key,
    required this.onJoined,
    required this.onBack,
  });

  final void Function(String roomId) onJoined;
  final VoidCallback onBack;

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      setState(() => _localError = ArEgStrings.invalidRoomCodeError);
      return;
    }
    setState(() => _localError = null);
    final roomId = await ref
        .read(activeGameSessionProvider.notifier)
        .joinOnlineRoom(code: code);
    if (roomId != null && mounted) {
      widget.onJoined(roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeGameSessionProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onBack,
          ),
          title: const Text(ArEgStrings.joinRoomByCode),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.vpn_key_rounded,
                        size: 48,
                        color: ShayebColors.goldenAccent,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        ArEgStrings.enterCodeTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ShayebColors.cream,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 6,
                          fontWeight: FontWeight.w900,
                          color: ShayebColors.goldenAccent,
                        ),
                        decoration: InputDecoration(
                          hintText: ArEgStrings.enterCodeHint,
                          errorText: _localError ?? session.errorMessage,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: session.isConnecting ? null : _submit,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(
                          session.isConnecting
                              ? 'بندخلك القعدة...'
                              : ArEgStrings.joinNow,
                        ),
                      ),
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

class PublicRoomsScreen extends ConsumerWidget {
  const PublicRoomsScreen({
    super.key,
    required this.onJoinRoomId,
    required this.onCreateInstead,
    required this.onBack,
  });

  final void Function(String roomId) onJoinRoomId;
  final VoidCallback onCreateInstead;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(activeGameSessionProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          title: const Text(ArEgStrings.publicRooms),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildDirectoryBody(context, ref, controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectoryBody(
    BuildContext context,
    WidgetRef ref,
    ActiveGameSessionController controller,
  ) {
    Stream<ShayebQuerySnapshot<Map<String, dynamic>>>? stream;
    try {
      stream = controller.bridge.watchPublicRooms();
    } catch (_) {
      stream = null;
    }

    if (stream == null) {
      return _emptyOrOfflineDirectory(onCreateInstead);
    }

    return StreamBuilder<ShayebQuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyOrOfflineDirectory(onCreateInstead);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return _emptyOrOfflineDirectory(onCreateInstead);
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final data = docs[idx].data() ?? const <String, dynamic>{};
            final roomId = (data['roomId'] ?? docs[idx].id).toString();
            final title = (data['title'] ?? 'قعدة مفتوحة').toString();
            final host = (data['hostNickname'] ?? 'معلم').toString();
            final count = (data['playerCount'] as num?)?.toInt() ?? 1;
            final max = (data['maxPlayers'] as num?)?.toInt() ?? 4;
            final rounds = (data['totalRounds'] as num?)?.toInt() ?? 5;
            final isFull = count >= max;

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  backgroundColor: ShayebColors.warmWoodBrown,
                  child: Text(
                    '$count/$max',
                    style: const TextStyle(
                      color: ShayebColors.goldenAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ShayebColors.cream,
                  ),
                ),
                subtitle: Text(
                  'صاحب القعدة: $host • $rounds جولات',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: ElevatedButton(
                  onPressed: isFull
                      ? null
                      : () async {
                          final joined =
                              await controller.joinOnlineRoom(roomId: roomId);
                          if (joined != null) {
                            onJoinRoomId(joined);
                          }
                        },
                  child: Text(isFull ? 'كومبليت' : 'ادخل'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyOrOfflineDirectory(VoidCallback onCreate) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('☕🃏', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              const Text(
                ArEgStrings.noPublicRooms,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ShayebColors.cream,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text(ArEgStrings.createRoom),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
