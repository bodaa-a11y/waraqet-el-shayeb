import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'features/chat/presentation/room_chat_sheet.dart';
import 'features/game/application/game_controller.dart';
import 'features/game/application/game_visual_theme_provider.dart';
import 'features/game/presentation/game_table_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/lobby/presentation/lobby_screen.dart';
import 'features/profile/presentation/onboarding_profile_screen.dart';
import 'features/results/presentation/results_and_challenges_screens.dart';
import 'features/rooms/presentation/rooms_screens.dart';
import 'features/splash/presentation/creative_splash_screen.dart';
import 'localization/ar_eg_strings.dart';
import 'theme/shayeb_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeSupabaseIfConfigured();
  runApp(const ProviderScope(child: ElShayebOnlineApp()));
}

Future<void> _initializeSupabaseIfConfigured() async {
  try {
    await Supabase.initialize(
      url: SupabaseConfig.activeUrl,
      anonKey: SupabaseConfig.activeAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  } catch (error, stack) {
    debugPrint('Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}

enum AppRouteStage {
  splash,
  onboarding,
  home,
  createRoom,
  joinByCode,
  publicRooms,
  activeRoom,
  howToPlay,
  challengesLibrary,
  settings,
}

class ElShayebOnlineApp extends ConsumerStatefulWidget {
  const ElShayebOnlineApp({
    super.key,
    this.skipOnboarding = false,
    this.skipSplash,
  });

  final bool skipOnboarding;
  final bool? skipSplash;

  @override
  ConsumerState<ElShayebOnlineApp> createState() => _ElShayebOnlineAppState();
}

class _ElShayebOnlineAppState extends ConsumerState<ElShayebOnlineApp> {
  late AppRouteStage _stage;

  @override
  void initState() {
    super.initState();
    final effectiveSkipSplash = widget.skipSplash ?? widget.skipOnboarding;
    _stage = effectiveSkipSplash
        ? (widget.skipOnboarding ? AppRouteStage.home : AppRouteStage.onboarding)
        : AppRouteStage.splash;
    Future.microtask(() {
      ref.read(playerProfileProvider.notifier).loadSavedPreferences();
      ref.read(gameVisualThemeProvider.notifier).loadSavedTheme();
    });
  }

  void _openChatModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RoomChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeGameSessionProvider);

    return MaterialApp(
      title: ArEgStrings.gameTitle,
      debugShowCheckedModeBanner: false,
      theme: ShayebTheme.buildTheme(),
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Builder(
        builder: (innerContext) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: KeyedSubtree(
            key: ValueKey(_stage == AppRouteStage.splash ? 'splash' : 'main'),
            child: _buildActiveScreen(innerContext, session),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveScreen(BuildContext context, ActiveGameSessionState session) {
    final profile = ref.watch(playerProfileProvider);
    if (_stage == AppRouteStage.splash) {
      return CreativeSplashScreen(
        reducedMotion: profile.reducedMotion,
        onCompleted: () {
          if (!mounted) return;
          setState(() {
            _stage = widget.skipOnboarding
                ? AppRouteStage.home
                : AppRouteStage.onboarding;
          });
        },
      );
    }

    // If a multiplayer room is active, route dynamically based on authoritative room status
    if (_stage == AppRouteStage.activeRoom && session.room != null) {
      final status = session.room!.status;
      if (status == 'playing') {
        return GameTableScreen(
          onOpenChat: () => _openChatModal(context),
          onLeaveMatch: () => setState(() => _stage = AppRouteStage.home),
        );
      }
      if (status == 'round_results' || status == 'finished') {
        return ResultsAndChallengeScreen(
          onOpenChat: () => _openChatModal(context),
          onReturnHome: () => setState(() => _stage = AppRouteStage.home),
        );
      }
      return LobbyScreen(
        onLeaveLobby: () => setState(() => _stage = AppRouteStage.home),
        onOpenChat: () => _openChatModal(context),
      );
    }

    switch (_stage) {
      case AppRouteStage.splash:
      case AppRouteStage.onboarding:
        return OnboardingProfileScreen(
          onCompleted: () => setState(() => _stage = AppRouteStage.home),
        );
      case AppRouteStage.createRoom:
        return CreateRoomScreen(
          onRoomCreated: (_) => setState(() => _stage = AppRouteStage.activeRoom),
          onBack: () => setState(() => _stage = AppRouteStage.home),
        );
      case AppRouteStage.joinByCode:
        return JoinRoomScreen(
          onJoined: (_) => setState(() => _stage = AppRouteStage.activeRoom),
          onBack: () => setState(() => _stage = AppRouteStage.home),
        );
      case AppRouteStage.publicRooms:
        return PublicRoomsScreen(
          onJoinRoomId: (_) => setState(() => _stage = AppRouteStage.activeRoom),
          onCreateInstead: () => setState(() => _stage = AppRouteStage.createRoom),
          onBack: () => setState(() => _stage = AppRouteStage.home),
        );
      case AppRouteStage.howToPlay:
        return HowToPlayScreen(
          onBack: () => setState(() => _stage = AppRouteStage.home),
        );
      case AppRouteStage.challengesLibrary:
        return ChallengesLibraryScreen(
          onBack: () => setState(() => _stage = AppRouteStage.home),
        );
      case AppRouteStage.settings:
        return SettingsScreen(
          onBack: () => setState(() => _stage = AppRouteStage.home),
          onEditProfile: () => setState(() => _stage = AppRouteStage.onboarding),
          onOpenHowToPlay: () => setState(() => _stage = AppRouteStage.howToPlay),
        );
      case AppRouteStage.home:
      case AppRouteStage.activeRoom:
        return HomeScreen(
          onCreateRoom: () => setState(() => _stage = AppRouteStage.createRoom),
          onJoinByCode: () => setState(() => _stage = AppRouteStage.joinByCode),
          onBrowsePublicRooms: () =>
              setState(() => _stage = AppRouteStage.publicRooms),
          onStartQuickPractice: () async {
            final profile = ref.read(playerProfileProvider);
            final roomId =
                await ref.read(activeGameSessionProvider.notifier).createRoom(
                      title: 'قعدة ${profile.nickname}',
                      maxPlayers: 4,
                      totalRounds: 3,
                      direction: 'clockwise',
                      visibility: 'private',
                      challengeMode: 'every_round',
                      turnTimerSeconds: 45,
                      localPracticeMode: true,
                    );
            if (roomId != null && mounted) {
              setState(() => _stage = AppRouteStage.activeRoom);
            }
          },
          onOpenHowToPlay: () => setState(() => _stage = AppRouteStage.howToPlay),
          onOpenChallenges: () =>
              setState(() => _stage = AppRouteStage.challengesLibrary),
          onOpenSettings: () => setState(() => _stage = AppRouteStage.settings),
          onEditProfile: () => setState(() => _stage = AppRouteStage.onboarding),
        );
    }
  }
}
