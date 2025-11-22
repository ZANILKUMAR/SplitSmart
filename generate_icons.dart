import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Copy of the SplitWalletLogoPainter from app_logo.dart
class SplitWalletLogoPainter extends CustomPainter {
  final bool isDark;

  SplitWalletLogoPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final walletColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFF1A1A1A);
    final accentColor = isDark
        ? const Color(0xFF4CAF50)
        : const Color(0xFF2196F3);
    const highlightColor = Colors.white;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = walletColor;

    final accentPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final walletHeight = size.height * 0.6;
    final walletWidth = size.width * 0.55;

    // Left wallet half
    final leftWalletPath = Path();
    leftWalletPath.moveTo(
      centerX - walletWidth * 0.9,
      centerY - walletHeight * 0.45,
    );
    leftWalletPath.lineTo(
      centerX - walletWidth * 0.15,
      centerY - walletHeight * 0.45,
    );
    // Zigzag edge
    for (int i = 0; i < 4; i++) {
      final y = centerY - walletHeight * 0.45 + (walletHeight / 4) * i;
      leftWalletPath.lineTo(
        centerX - walletWidth * 0.08,
        y + walletHeight * 0.1,
      );
      leftWalletPath.lineTo(
        centerX - walletWidth * 0.15,
        y + walletHeight * 0.2,
      );
    }
    leftWalletPath.lineTo(
      centerX - walletWidth * 0.15,
      centerY + walletHeight * 0.45,
    );
    leftWalletPath.lineTo(
      centerX - walletWidth * 0.9,
      centerY + walletHeight * 0.45,
    );
    leftWalletPath.quadraticBezierTo(
      centerX - walletWidth * 0.95,
      centerY + walletHeight * 0.45,
      centerX - walletWidth * 0.95,
      centerY + walletHeight * 0.4,
    );
    leftWalletPath.lineTo(
      centerX - walletWidth * 0.95,
      centerY - walletHeight * 0.4,
    );
    leftWalletPath.quadraticBezierTo(
      centerX - walletWidth * 0.95,
      centerY - walletHeight * 0.45,
      centerX - walletWidth * 0.9,
      centerY - walletHeight * 0.45,
    );
    leftWalletPath.close();

    canvas.drawPath(leftWalletPath, paint);

    // Right wallet half
    final rightWalletPath = Path();
    rightWalletPath.moveTo(
      centerX + walletWidth * 0.15,
      centerY - walletHeight * 0.45,
    );
    rightWalletPath.lineTo(
      centerX + walletWidth * 0.9,
      centerY - walletHeight * 0.45,
    );
    rightWalletPath.quadraticBezierTo(
      centerX + walletWidth * 0.95,
      centerY - walletHeight * 0.45,
      centerX + walletWidth * 0.95,
      centerY - walletHeight * 0.4,
    );
    rightWalletPath.lineTo(
      centerX + walletWidth * 0.95,
      centerY - walletHeight * 0.1,
    );
    // Wallet clasp
    rightWalletPath.quadraticBezierTo(
      centerX + walletWidth * 0.95,
      centerY - walletHeight * 0.05,
      centerX + walletWidth * 0.9,
      centerY - walletHeight * 0.05,
    );
    rightWalletPath.lineTo(
      centerX + walletWidth * 0.8,
      centerY - walletHeight * 0.05,
    );
    rightWalletPath.quadraticBezierTo(
      centerX + walletWidth * 0.75,
      centerY - walletHeight * 0.05,
      centerX + walletWidth * 0.75,
      centerY,
    );
    rightWalletPath.quadraticBezierTo(
      centerX + walletWidth * 0.75,
      centerY + walletHeight * 0.05,
      centerX + walletWidth * 0.8,
      centerY + walletHeight * 0.05,
    );
    rightWalletPath.lineTo(
      centerX + walletWidth * 0.9,
      centerY + walletHeight * 0.05,
    );
    rightWalletPath.quadraticBezierTo(
      centerX + walletWidth * 0.95,
      centerY + walletHeight * 0.05,
      centerX + walletWidth * 0.95,
      centerY + walletHeight * 0.1,
    );
    rightWalletPath.lineTo(
      centerX + walletWidth * 0.95,
      centerY + walletHeight * 0.4,
    );
    rightWalletPath.quadraticBezierTo(
      centerX + walletWidth * 0.95,
      centerY + walletHeight * 0.45,
      centerX + walletWidth * 0.9,
      centerY + walletHeight * 0.45,
    );
    rightWalletPath.lineTo(
      centerX + walletWidth * 0.15,
      centerY + walletHeight * 0.45,
    );
    // Zigzag edge
    for (int i = 3; i >= 0; i--) {
      final y = centerY - walletHeight * 0.45 + (walletHeight / 4) * (i + 1);
      rightWalletPath.lineTo(centerX + walletWidth * 0.15, y);
      rightWalletPath.lineTo(
        centerX + walletWidth * 0.08,
        y - walletHeight * 0.1,
      );
    }
    rightWalletPath.close();

    canvas.drawPath(rightWalletPath, paint);

    // Dollar sign on left half
    final dollarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.04
      ..strokeCap = StrokeCap.round
      ..color = highlightColor;

    // Dollar sign S curve
    final dollarPath = Path();
    dollarPath.moveTo(
      centerX - walletWidth * 0.4,
      centerY - walletHeight * 0.15,
    );
    dollarPath.quadraticBezierTo(
      centerX - walletWidth * 0.55,
      centerY - walletHeight * 0.15,
      centerX - walletWidth * 0.55,
      centerY - walletHeight * 0.05,
    );
    dollarPath.quadraticBezierTo(
      centerX - walletWidth * 0.55,
      centerY,
      centerX - walletWidth * 0.4,
      centerY,
    );
    dollarPath.quadraticBezierTo(
      centerX - walletWidth * 0.25,
      centerY,
      centerX - walletWidth * 0.25,
      centerY + walletHeight * 0.05,
    );
    dollarPath.quadraticBezierTo(
      centerX - walletWidth * 0.25,
      centerY + walletHeight * 0.15,
      centerX - walletWidth * 0.4,
      centerY + walletHeight * 0.15,
    );

    canvas.drawPath(dollarPath, dollarPaint);

    // Dollar sign vertical line
    canvas.drawLine(
      Offset(centerX - walletWidth * 0.4, centerY - walletHeight * 0.22),
      Offset(centerX - walletWidth * 0.4, centerY + walletHeight * 0.22),
      dollarPaint,
    );

    // Wallet clasp circle on right
    canvas.drawCircle(
      Offset(centerX + walletWidth * 0.8, centerY),
      size.height * 0.03,
      accentPaint,
    );

    // Card lines on left wallet
    final cardPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.015
      ..color = accentColor.withOpacity(0.6);

    canvas.drawLine(
      Offset(centerX - walletWidth * 0.85, centerY - walletHeight * 0.35),
      Offset(centerX - walletWidth * 0.25, centerY - walletHeight * 0.35),
      cardPaint,
    );

    canvas.drawLine(
      Offset(centerX - walletWidth * 0.85, centerY - walletHeight * 0.25),
      Offset(centerX - walletWidth * 0.3, centerY - walletHeight * 0.25),
      cardPaint,
    );

    // Highlight details on wallet edges
    final highlightStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.01
      ..color = highlightColor.withOpacity(0.3);

    canvas.drawLine(
      Offset(centerX - walletWidth * 0.93, centerY - walletHeight * 0.4),
      Offset(centerX - walletWidth * 0.93, centerY + walletHeight * 0.4),
      highlightStroke,
    );

    canvas.drawLine(
      Offset(centerX + walletWidth * 0.93, centerY - walletHeight * 0.4),
      Offset(centerX + walletWidth * 0.93, centerY + walletHeight * 0.4),
      highlightStroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> generateIcon(
  int size,
  String filename, {
  bool transparent = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Background
  if (!transparent) {
    final bgPaint = Paint()..color = const Color(0xFF2196F3);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      bgPaint,
    );
  }

  // Draw logo
  final painter = SplitWalletLogoPainter(isDark: false);
  painter.paint(canvas, Size(size.toDouble(), size.toDouble()));

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  final file = File(filename);
  await file.writeAsBytes(byteData!.buffer.asUint8List());

  print('Generated: $filename');
}

void main() async {
  print('Generating icons...');

  // Generate favicon
  await generateIcon(64, 'web/favicon.png');

  // Generate app icons
  await generateIcon(192, 'web/icons/Icon-192.png');
  await generateIcon(512, 'web/icons/Icon-512.png');

  // Generate maskable icons (with padding for safe zone)
  await generateIcon(192, 'web/icons/Icon-maskable-192.png');
  await generateIcon(512, 'web/icons/Icon-maskable-512.png');

  print('All icons generated successfully!');
  print('Please hot reload or restart your app to see the new favicon.');
}
