import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';
import '../../game/application/game_controller.dart';
import '../../game/domain/room_models.dart';
import '../../splash/presentation/creative_splash_screen.dart';

class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({
    super.key,
    required this.onCompleted,
  });

  final VoidCallback onCompleted;

  @override
  ConsumerState<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends ConsumerState<OnboardingProfileScreen> {
  late final TextEditingController _nameController;
  String _selectedAvatar = 'avatar_1';
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider);
    _nameController = TextEditingController(text: profile.nickname);
    _selectedAvatar = profile.avatarId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile({bool useDefault = false}) async {
    final raw = useDefault ? 'معلم القهوة' : _nameController.text.trim();
    final err = PlayerProfile.validateNickname(raw);
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }
    setState(() => _validationError = null);
    await ref.read(playerProfileProvider.notifier).updateProfile(
          nickname: raw,
          avatarId: _selectedAvatar,
        );
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: ShayebColors.feltTableGradient,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: ShayebColors.primaryDarkGreen.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: ShayebColors.goldenAccent, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: BrandLogoBadge(size: 118),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          ArEgStrings.welcomeHeadline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: ShayebColors.goldenAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          ArEgStrings.welcomeBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: ShayebColors.cream,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          ArEgStrings.chooseNicknameTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ShayebColors.goldenAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          maxLength: 24,
                          style: const TextStyle(
                            color: ShayebColors.cardWhite,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: ArEgStrings.chooseNicknameHint,
                            errorText: _validationError,
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: ShayebColors.goldenAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          ArEgStrings.chooseAvatarTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ShayebColors.goldenAccent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: ArEgStrings.avatars.entries.map((entry) {
                            final isSelected = _selectedAvatar == entry.key;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedAvatar = entry.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 92,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ShayebColors.goldenAccent.withValues(alpha: 0.22)
                                      : ShayebColors.deepTableGreen,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? ShayebColors.softGold
                                        : Colors.white24,
                                    width: isSelected ? 2.4 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      entry.value['emoji'] ?? '🧔🏻‍♂️',
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.value['name'] ?? '',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? ShayebColors.softGold
                                            : ShayebColors.cream,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(ArEgStrings.saveAndEnter),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _saveProfile(useDefault: true),
                          child: const Text(
                            ArEgStrings.skipUseDefault,
                            style: TextStyle(color: ShayebColors.cream),
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
      ),
    );
  }
}
