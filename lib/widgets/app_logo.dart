import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AppLogo({super.key, this.size = 100, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Split Wallet Logo
        CustomPaint(
          size: Size(size * 1.5, size),
          painter: SplitWalletPainter(
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.2),
          // App Name
          Text(
            'SplitSmart',
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1A1A1A),
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: size * 0.03),
          Text(
            'Split Expenses, Stay Smart',
            style: TextStyle(
              fontSize: size * 0.12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

// Split wallet logo painter based on the shared design
class SplitWalletPainter extends CustomPainter {
  final bool isDark;

  SplitWalletPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? Colors.white : Colors.black;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.08
      ..color = isDark ? Colors.white : Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final width = size.width;
    final height = size.height;
    final centerX = width / 2;

    // Left wallet half
    final leftWallet = Path();
    leftWallet.moveTo(width * 0.15, height * 0.2);
    leftWallet.lineTo(centerX * 0.85, height * 0.2);
    leftWallet.lineTo(centerX * 0.85, height * 0.8);
    leftWallet.lineTo(width * 0.15, height * 0.8);
    leftWallet.close();
    canvas.drawPath(leftWallet, paint);

    // Right wallet half with clasp
    final rightWallet = Path();
    rightWallet.moveTo(centerX * 1.15, height * 0.2);
    rightWallet.lineTo(width * 0.85, height * 0.2);
    rightWallet.lineTo(width * 0.85, height * 0.8);
    rightWallet.lineTo(centerX * 1.15, height * 0.8);
    rightWallet.close();
    canvas.drawPath(rightWallet, paint);

    // Zigzag split line
    final zigzag = Path();
    final zigzagSteps = 5;
    final stepHeight = height * 0.6 / zigzagSteps;
    zigzag.moveTo(centerX, height * 0.2);

    for (int i = 0; i < zigzagSteps; i++) {
      final y1 = height * 0.2 + (stepHeight * i);
      final y2 = y1 + stepHeight / 2;
      final y3 = y1 + stepHeight;

      if (i % 2 == 0) {
        zigzag.lineTo(centerX - width * 0.06, y2);
        zigzag.lineTo(centerX, y3);
      } else {
        zigzag.lineTo(centerX + width * 0.06, y2);
        zigzag.lineTo(centerX, y3);
      }
    }
    canvas.drawPath(zigzag, strokePaint);

    // Dollar sign on left wallet
    final dollarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.08
      ..color = isDark ? Colors.black : Colors.white
      ..strokeCap = StrokeCap.round;

    // S curve
    final dollarPath = Path();
    dollarPath.moveTo(width * 0.38, height * 0.35);
    dollarPath.cubicTo(
      width * 0.25,
      height * 0.35,
      width * 0.25,
      height * 0.45,
      width * 0.38,
      height * 0.45,
    );
    dollarPath.cubicTo(
      width * 0.48,
      height * 0.45,
      width * 0.48,
      height * 0.55,
      width * 0.38,
      height * 0.55,
    );
    dollarPath.cubicTo(
      width * 0.25,
      height * 0.55,
      width * 0.25,
      height * 0.65,
      width * 0.38,
      height * 0.65,
    );
    canvas.drawPath(dollarPath, dollarPaint);

    // Vertical line through dollar
    canvas.drawLine(
      Offset(width * 0.38, height * 0.3),
      Offset(width * 0.38, height * 0.7),
      dollarPaint,
    );

    // Clasp circle on right wallet
    canvas.drawCircle(Offset(width * 0.7, height * 0.5), height * 0.08, paint);
    canvas.drawCircle(
      Offset(width * 0.7, height * 0.5),
      height * 0.04,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDark ? Colors.black : Colors.white,
    );

    // Card lines on top of left wallet
    final cardPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = height * 0.02
      ..color = isDark ? Colors.black : Colors.white
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(width * 0.2, height * 0.28),
      Offset(width * 0.45, height * 0.28),
      cardPaint,
    );
    canvas.drawLine(
      Offset(width * 0.2, height * 0.34),
      Offset(width * 0.42, height * 0.34),
      cardPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Smaller version of the logo for app bars and small spaces
class AppLogoIcon extends StatelessWidget {
  final double size;

  const AppLogoIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.5, size),
      painter: SplitWalletPainter(
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }
}
