import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../localization/ar_eg_strings.dart';
import '../../../theme/shayeb_theme.dart';

/// Creative animated splash & loading screen featuring the «ورقة الشايب» emblem,
/// vintage 4-suit card fan, rotating lantern sunburst halo, specular gold sheen,
/// curling tea steam, and Egyptian café loading captions.
class CreativeSplashScreen extends StatefulWidget {
  const CreativeSplashScreen({
    super.key,
    required this.onCompleted,
    this.minimumDuration = const Duration(milliseconds: 2800),
    this.reducedMotion = false,
  });

  final VoidCallback onCompleted;
  final Duration minimumDuration;
  final bool reducedMotion;

  @override
  State<CreativeSplashScreen> createState() => _CreativeSplashScreenState();
}

class _CreativeSplashScreenState extends State<CreativeSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _loopController;
  late final AnimationController _progressController;
  bool _completed = false;

  static const List<String> _captions = [
    'بنفرش الترابيزة ونرصّ الورق... 🃏',
    'بنصبّ الشاي بالنعناع على مية بيضا... ☕',
    'خد بالك.. شايب القلوب مستني صاحب النصيب! 👴♥',
  ];

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: widget.reducedMotion
          ? const Duration(milliseconds: 250)
          : const Duration(milliseconds: 1100),
    )..forward();

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (!widget.reducedMotion) {
      _loopController.repeat();
    }

    final loadDuration = widget.reducedMotion
        ? const Duration(milliseconds: 650)
        : widget.minimumDuration;
    _progressController = AnimationController(
      vsync: this,
      duration: loadDuration,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish();
        }
      })
      ..forward();
  }

  void _finish() {
    if (_completed || !mounted) return;
    _completed = true;
    widget.onCompleted();
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shortest = math.min(media.size.width, media.size.height);
    final logoSize = math.max(150.0, math.min(236.0, shortest * 0.44));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0603),
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _introController,
            _loopController,
            _progressController,
          ]),
          builder: (context, _) {
            final introT = Curves.easeOutCubic.transform(_introController.value);
            final bounceT = Curves.easeOutBack.transform(
              (_introController.value * 1.05).clamp(0.0, 1.0),
            );
            final loopT = _loopController.value;
            final progress = Curves.easeInOut.transform(_progressController.value);
            final breathe = widget.reducedMotion
                ? 0.0
                : math.sin(loopT * math.pi * 2);

            final captionIdx = (progress * _captions.length)
                .floor()
                .clamp(0, _captions.length - 1);

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Rich café radial backdrop + rotating sunburst & golden embers
                CustomPaint(
                  painter: _CafeSplashPainter(
                    loopT: loopT,
                    introT: introT,
                    reducedMotion: widget.reducedMotion,
                  ),
                ),

                SafeArea(
                  child: Stack(
                    children: [
                      // Subtle skip affordance after initial reveal
                      if (progress >= 0.32 && !_completed)
                        Positioned(
                          top: 10,
                          left: 14,
                          child: TextButton.icon(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: ShayebColors.softGold,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.skip_next_rounded, size: 18),
                            label: const Text(
                              'تخطي',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),

                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 2. Choreographed card fan + hero emblem + steam + shimmer
                                SizedBox(
                                  width: logoSize * 1.42,
                                  height: logoSize * 1.18,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Pulsing ruby-gold backlight aura
                                      Container(
                                        width: logoSize * (1.06 + 0.06 * breathe),
                                        height: logoSize * (1.06 + 0.06 * breathe),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              ShayebColors.goldenAccent
                                                  .withValues(alpha: 0.34),
                                              ShayebColors.richRed
                                                  .withValues(alpha: 0.18),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),

                                      // 4 fanning vintage card silhouettes behind the logo
                                      ..._buildCardFan(
                                        logoSize: logoSize,
                                        fanT: introT,
                                        breathe: breathe,
                                      ),

                                        // 3D perspective hero emblem with diagonal gold sheen
                                      Transform(
                                        alignment: Alignment.center,
                                        transform: () {
                                          final s = 0.65 + 0.35 * bounceT;
                                          return Matrix4.identity()
                                            ..setEntry(3, 2, 0.0012)
                                            ..rotateY(breathe * 0.045)
                                            ..rotateX(-breathe * 0.025)
                                            ..scaleByDouble(s, s, s, 1.0);
                                        }(),
                                        child: Opacity(
                                          opacity: _introController.value
                                              .clamp(0.0, 1.0),
                                          child: BrandLogoBadge(
                                            size: logoSize,
                                            overlay: widget.reducedMotion
                                                ? null
                                                : IgnorePointer(
                                                    child: CustomPaint(
                                                      painter:
                                                          _DiagonalSheenPainter(
                                                        t: loopT,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),

                                      // Rising curling steam wisps near the tea glass (bottom-right)
                                      if (!widget.reducedMotion)
                                        Positioned(
                                          right: logoSize * 0.15,
                                          bottom: logoSize * 0.30,
                                          child: CustomPaint(
                                            size: const Size(38, 64),
                                            painter: _TeaSteamPainter(t: loopT),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // 3. Title badge & Egyptian café tagline
                                Opacity(
                                  opacity: introT,
                                  child: Transform.translate(
                                    offset: Offset(0, 14 * (1 - introT)),
                                    child: Column(
                                      children: [
                                        const Text(
                                          ArEgStrings.gameTitle,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: ShayebColors.goldenAccent,
                                            letterSpacing: 0.4,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black87,
                                                blurRadius: 14,
                                                offset: Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ArEgStrings.gameSubtitle,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: ShayebColors.cream
                                                .withValues(alpha: 0.92),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // 4. Sequential 4-suit pulse indicator + ruby-gold progress bar
                                _SuitPulseStrip(
                                  progress: _progressController.value,
                                  loopT: loopT,
                                ),
                                const SizedBox(height: 12),

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      border: Border.all(
                                        color: ShayebColors.goldenAccent
                                            .withValues(alpha: 0.45),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final w = constraints.maxWidth *
                                            progress.clamp(0.04, 1.0);
                                        return Align(
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            width: w,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF9F1D1D),
                                                  Color(0xFFD9A441),
                                                  Color(0xFFFFE598),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: ShayebColors.goldenAccent
                                                      .withValues(alpha: 0.55),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // 5. Rotating Egyptian café caption + percent
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  child: Text(
                                    '${_captions[captionIdx]} (${(progress * 100).round()}%)',
                                    key: ValueKey(captionIdx),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ShayebColors.softGold,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCardFan({
    required double logoSize,
    required double fanT,
    required double breathe,
  }) {
    const specs = [
      (suit: '♦', red: true, targetAngle: -0.44, dx: -0.48, dy: 0.04),
      (suit: '♣', red: false, targetAngle: -0.22, dx: -0.32, dy: -0.05),
      (suit: '♠', red: false, targetAngle: 0.22, dx: 0.32, dy: -0.05),
      (suit: '♥', red: true, targetAngle: 0.44, dx: 0.48, dy: 0.04),
    ];

    final cardW = logoSize * 0.34;
    final cardH = cardW * 1.44;
    return [
      for (final s in specs)
        Transform.translate(
          offset: Offset(
            logoSize * s.dx * fanT,
            logoSize * s.dy * fanT + breathe * 2.5,
          ),
          child: Transform.rotate(
            angle: s.targetAngle * fanT + (breathe * 0.02),
            child: Opacity(
              opacity: (fanT * 0.92).clamp(0.0, 1.0),
              child: Container(
                width: cardW,
                height: cardH,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F1E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ShayebColors.goldenAccent.withValues(alpha: 0.8),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    s.suit,
                    style: TextStyle(
                      fontSize: cardW * 0.28,
                      fontWeight: FontWeight.w900,
                      color: s.red
                          ? ShayebColors.richRed
                          : const Color(0xFF1A1614),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// Reusable rounded-corner glowing «ورقة الشايب» emblem badge used across
/// splash, onboarding, and home screens.
class BrandLogoBadge extends StatelessWidget {
  const BrandLogoBadge({
    super.key,
    required this.size,
    this.overlay,
  });

  final double size;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.185);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: ShayebColors.goldenAccent.withValues(alpha: 0.34),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/logo/waraqet_el_shayeb_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF3E0F0F),
                child: Center(
                  child: Text(
                    '👴👑🃏',
                    style: TextStyle(fontSize: size * 0.24),
                  ),
                ),
              ),
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}

class _SuitPulseStrip extends StatelessWidget {
  const _SuitPulseStrip({
    required this.progress,
    required this.loopT,
  });

  final double progress;
  final double loopT;

  @override
  Widget build(BuildContext context) {
    const suits = [
      (glyph: '♠', red: false),
      (glyph: '♥', red: true),
      (glyph: '♣', red: false),
      (glyph: '♦', red: true),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(suits.length, (i) {
        final s = suits[i];
        final active = progress >= (i / suits.length);
        final pulse = 0.5 + 0.5 * math.sin((loopT * math.pi * 2) - i * 1.1);
        final scale = active ? (1.0 + 0.14 * pulse) : 0.88;

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? ShayebColors.warmWoodBrown
                  : Colors.black38,
              border: Border.all(
                color: active
                    ? ShayebColors.goldenAccent
                    : Colors.white24,
                width: 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: ShayebColors.goldenAccent
                            .withValues(alpha: 0.35 * pulse),
                        blurRadius: 10,
                      ),
                    ]
                  : const [],
            ),
            alignment: Alignment.center,
            child: Text(
              s.glyph,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: active
                    ? (s.red
                        ? const Color(0xFFFF6B6B)
                        : ShayebColors.goldenAccent)
                    : Colors.white38,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CafeSplashPainter extends CustomPainter {
  const _CafeSplashPainter({
    required this.loopT,
    required this.introT,
    required this.reducedMotion,
  });

  final double loopT;
  final double introT;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final bgRect = Offset.zero & size;

    // Deep coffee-house radial background
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.16),
        radius: 0.95,
        colors: [
          Color(0xFF3A1A0D),
          Color(0xFF190C06),
          Color(0xFF0A0402),
        ],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Rotating 12-ray arabesque lantern sunburst behind the logo
    const rayCount = 12;
    final baseAngle = reducedMotion ? 0.0 : loopT * math.pi * 2;
    final maxR = math.max(size.width, size.height) * 0.72;
    final rayPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < rayCount; i++) {
      final a0 = baseAngle + (i * math.pi * 2 / rayCount);
      final a1 = a0 + (math.pi / rayCount) * 0.55;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(a0) * maxR,
          center.dy + math.sin(a0) * maxR,
        )
        ..lineTo(
          center.dx + math.cos(a1) * maxR,
          center.dy + math.sin(a1) * maxR,
        )
        ..close();

      rayPaint.shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          ShayebColors.goldenAccent.withValues(alpha: 0.11 * introT),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
      canvas.drawPath(path, rayPaint);
    }

    if (reducedMotion) return;

    // Floating warm golden lantern-ember sparks
    final emberPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 24; i++) {
      final seedX = ((i * 73 + 19) % 100) / 100.0;
      final speed = 0.6 + ((i * 31) % 7) * 0.14;
      final phase = (loopT * speed + (i * 0.137)) % 1.0;
      final x = size.width * seedX + math.sin(phase * math.pi * 4 + i) * 14;
      final y = size.height * (1.06 - phase * 1.15);
      final alpha = math.sin(phase * math.pi).clamp(0.0, 1.0) * 0.45 * introT;
      final r = 1.4 + (i % 3) * 0.9;
      emberPaint.color = ShayebColors.goldenAccent.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CafeSplashPainter oldDelegate) =>
      oldDelegate.loopT != loopT ||
      oldDelegate.introT != introT ||
      oldDelegate.reducedMotion != reducedMotion;
}

class _DiagonalSheenPainter extends CustomPainter {
  const _DiagonalSheenPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Active sweep in the middle window of each cycle
    final sweep = (t * 1.8) - 0.4;
    if (sweep < -0.5 || sweep > 1.5) return;

    final start = Offset(size.width * (sweep - 0.35), -size.height * 0.2);
    final end = Offset(size.width * (sweep + 0.35), size.height * 1.2);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          ShayebColors.softGold.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.28),
          ShayebColors.softGold.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(Rect.fromPoints(start, end));

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalSheenPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _TeaSteamPainter extends CustomPainter {
  const _TeaSteamPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final p = (t + i * 0.33) % 1.0;
      final alpha = math.sin(p * math.pi).clamp(0.0, 1.0) * 0.42;
      paint
        ..strokeWidth = 2.0
        ..color = Colors.white.withValues(alpha: alpha);

      final baseX = size.width * (0.28 + i * 0.22);
      final startY = size.height * (0.95 - p * 0.45);
      final endY = startY - size.height * 0.42;
      final sway = math.sin(p * math.pi * 3 + i) * 5.0;

      final path = Path()
        ..moveTo(baseX, startY)
        ..quadraticBezierTo(
          baseX + sway,
          (startY + endY) * 0.5,
          baseX - sway * 0.6,
          endY,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TeaSteamPainter oldDelegate) =>
      oldDelegate.t != t;
}
