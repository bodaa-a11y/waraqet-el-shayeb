import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/shayeb_theme.dart';
import '../domain/playing_card.dart';

/// Custom-rendered Egyptian playing card widget (Face Up + Special "الشايب" King + Arabesque Face Down).
/// Never exposes hidden card identities on face-down opponent cards.
class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 76,
    this.height = 112,
    this.isSelected = false,
    this.isInteractive = false,
    this.onTap,
  });

  final PlayingCardModel? card;
  final bool faceDown;
  final double width;
  final double height;
  final bool isSelected;
  final bool isInteractive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveFaceDown = faceDown || card == null;
    return Semantics(
      button: onTap != null,
      label: effectiveFaceDown
          ? 'ورقة مقلوبة قابلة للسحب'
          : (card!.isElShayeb
              ? 'ورقة الشايب - ملك القلوب'
              : 'ورقة ${card!.arabicRankLabel} ${card!.suit.arabicName}'),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          transform: Matrix4.translationValues(0, isSelected ? -12 : 0, 0),
          decoration: BoxDecoration(
            color: effectiveFaceDown ? ShayebColors.richRed : ShayebColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? ShayebColors.softGold
                  : (card?.isElShayeb == true && !effectiveFaceDown
                      ? ShayebColors.goldenAccent
                      : const Color(0xFFD2C09E)),
              width: isSelected || (card?.isElShayeb == true && !effectiveFaceDown) ? 2.5 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.5 : 0.32),
                blurRadius: isSelected ? 14 : 7,
                offset: Offset(0, isSelected ? 6 : 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 270),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: effectiveFaceDown
                  ? CustomPaint(
                      key: const ValueKey('back'),
                      painter: _EgyptianCardBackPainter(highlight: isInteractive),
                    )
                  : KeyedSubtree(
                      key: ValueKey('face_${card!.id}'),
                      child: _buildCardFace(card!),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(PlayingCardModel c) {
    final suitColor =
        c.suit.isRed ? ShayebColors.richRed : ShayebColors.darkCharcoal;
    if (c.isElShayeb) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFDF6),
              Color(0xFFFDF0D5),
              Color(0xFFF4D498),
            ],
          ),
        ),
        padding: const EdgeInsets.all(5),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ElShayebCharacterFramePainter(),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: _cornerBadge('K', c.suit.symbol, ShayebColors.richRed),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Transform.rotate(
                angle: math.pi,
                child: _cornerBadge('K', c.suit.symbol, ShayebColors.richRed),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: (width * 0.54).clamp(32.0, 74.0),
                    height: (height * 0.45).clamp(34.0, 76.0),
                    child: CustomPaint(
                      painter: _ElShayebPortraitPainter(),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB3251E), Color(0xFF8A1812)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ShayebColors.goldenAccent,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      'الشايب',
                      style: TextStyle(
                        color: ShayebColors.cardWhite,
                        fontSize: (width * 0.13).clamp(8.5, 13.0),
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _cornerBadge(c.rank, c.suit.symbol, suitColor),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Transform.rotate(
              angle: math.pi,
              child: _cornerBadge(c.rank, c.suit.symbol, suitColor),
            ),
          ),
          Center(
            child: Text(
              c.suit.symbol,
              style: TextStyle(
                fontSize: width * 0.42,
                color: suitColor,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cornerBadge(String rank, String symbol, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rank,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.0,
          ),
        ),
        Text(
          symbol,
          style: TextStyle(
            fontSize: 11,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

/// Decorative gold & crimson inner royal frame for the King of Hearts (الشايب).
class _ElShayebCharacterFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFFD7A84D).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      const Radius.circular(7),
    );
    canvas.drawRRect(innerRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hand-crafted custom vector portrait of the elderly Egyptian "الشايب" (King of Hearts)
/// featuring a royal crimson Tarboush with a golden crown emblem, white eyebrows,
/// warm mischievous eyes, and a grand white handlebar mustache.
class _ElShayebPortraitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.44;

    // 1. Golden halo medallion behind the character
    final medallionPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE6A3),
          const Color(0xFFD7A84D).withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy + 2), radius: r * 1.08));
    canvas.drawCircle(Offset(cx, cy + 2), r * 1.05, medallionPaint);

    final ringPaint = Paint()
      ..color = const Color(0xFFB3251E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy + 2), r * 1.05, ringPaint);

    // 2. Warm face oval
    final faceRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.14),
      width: r * 1.25,
      height: r * 1.35,
    );
    final skinPaint = Paint()..color = const Color(0xFFE5B181);
    canvas.drawOval(faceRect, skinPaint);

    // 3. Royal Egyptian Tarboush (Fez) + Golden Crown rim
    final tarboushPath = Path()
      ..moveTo(cx - r * 0.62, cy - r * 0.25)
      ..lineTo(cx - r * 0.46, cy - r * 0.95)
      ..quadraticBezierTo(cx, cy - r * 1.04, cx + r * 0.46, cy - r * 0.95)
      ..lineTo(cx + r * 0.62, cy - r * 0.25)
      ..close();
    final tarboushPaint = Paint()..color = const Color(0xFFA81D18);
    canvas.drawPath(tarboushPath, tarboushPaint);

    // Golden crown band on Tarboush
    final bandPaint = Paint()..color = const Color(0xFFE5B94E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - r * 0.28),
          width: r * 1.30,
          height: r * 0.22,
        ),
        const Radius.circular(3),
      ),
      bandPaint,
    );

    // Tiny crimson heart jewel in center of crown band
    final jewelPaint = Paint()..color = const Color(0xFFB3251E);
    canvas.drawCircle(Offset(cx, cy - r * 0.28), r * 0.08, jewelPaint);

    // 4. Expressive white eyebrows
    final hairPaint = Paint()
      ..color = const Color(0xFFFDFBF7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (r * 0.14).clamp(1.6, 3.2);
    canvas.drawLine(
      Offset(cx - r * 0.38, cy - r * 0.03),
      Offset(cx - r * 0.14, cy - r * 0.08),
      hairPaint,
    );
    canvas.drawLine(
      Offset(cx + r * 0.14, cy - r * 0.08),
      Offset(cx + r * 0.38, cy - r * 0.03),
      hairPaint,
    );

    // 5. Eyes
    final eyePaint = Paint()..color = const Color(0xFF28180E);
    canvas.drawCircle(Offset(cx - r * 0.25, cy + r * 0.10), r * 0.09, eyePaint);
    canvas.drawCircle(Offset(cx + r * 0.25, cy + r * 0.10), r * 0.09, eyePaint);

    // 6. Grand white Egyptian handlebar mustache ("شنب المعلم الشايب")
    final mustachePath = Path()
      ..moveTo(cx, cy + r * 0.34)
      ..quadraticBezierTo(
        cx - r * 0.35,
        cy + r * 0.22,
        cx - r * 0.68,
        cy + r * 0.42,
      )
      ..quadraticBezierTo(
        cx - r * 0.35,
        cy + r * 0.56,
        cx,
        cy + r * 0.45,
      )
      ..quadraticBezierTo(
        cx + r * 0.35,
        cy + r * 0.56,
        cx + r * 0.68,
        cy + r * 0.42,
      )
      ..quadraticBezierTo(
        cx + r * 0.35,
        cy + r * 0.22,
        cx,
        cy + r * 0.34,
      )
      ..close();
    final mustacheFill = Paint()..color = const Color(0xFFFDFBF7);
    canvas.drawPath(mustachePath, mustacheFill);

    final mustacheStroke = Paint()
      ..color = const Color(0xFFB7AA98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(mustachePath, mustacheStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EgyptianCardBackPainter extends CustomPainter {
  const _EgyptianCardBackPainter({required this.highlight});
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: highlight
            ? const [Color(0xFFC94444), Color(0xFF8E2222)]
            : const [Color(0xFFA32E2E), Color(0xFF6B1A1A)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final goldPaint = Paint()
      ..color = ShayebColors.goldenAccent.withValues(alpha: highlight ? 0.9 : 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 5, size.width - 10, size.height - 10),
      const Radius.circular(7),
    );
    canvas.drawRRect(innerRect, goldPaint);

    // Draw Egyptian diamond motif in center
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, center.dy - 18)
      ..lineTo(center.dx + 13, center.dy)
      ..lineTo(center.dx, center.dy + 18)
      ..lineTo(center.dx - 13, center.dy)
      ..close();
    canvas.drawPath(path, goldPaint);

    final dotPaint = Paint()
      ..color = ShayebColors.goldenAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _EgyptianCardBackPainter oldDelegate) =>
      oldDelegate.highlight != highlight;
}
