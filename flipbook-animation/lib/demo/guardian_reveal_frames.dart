import 'dart:math';
import 'package:flutter/material.dart';

/// Generates 8 frames of a "Guardian Reveal" animation:
/// scattered fragments assembling into a shield/guardian silhouette.
class GuardianRevealFrames {
  static Widget build(int frameIndex, Size size) {
    return CustomPaint(
      size: size,
      painter: _GuardianPainter(frameIndex / 7.0),
    );
  }
}

class _GuardianPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _GuardianPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 300;

    // Background glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(
            const Color(0x00D4A574),
            const Color(0x66D4A574),
            progress,
          )!,
          const Color(0x001A1A2E),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 140 * scale));
    canvas.drawCircle(Offset(cx, cy), 140 * scale, glowPaint);

    // Guardian shield shape — defined as fragments
    final fragments = _getFragments(scale);
    
    for (int i = 0; i < fragments.length; i++) {
      final frag = fragments[i];
      // Each fragment starts scattered and converges to final position
      final delay = i / fragments.length * 0.3;
      final fragProgress = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      final eased = Curves.easeInOutCubic.transform(fragProgress);

      // Scattered position (random but deterministic per fragment)
      final rng = Random(i * 42 + 7);
      final scatterX = (rng.nextDouble() - 0.5) * size.width * 1.2;
      final scatterY = (rng.nextDouble() - 0.5) * size.height * 1.2;
      final scatterRot = (rng.nextDouble() - 0.5) * pi * 2;

      final currentX = cx + scatterX * (1 - eased);
      final currentY = cy + scatterY * (1 - eased);
      final currentRot = scatterRot * (1 - eased);

      // Opacity fades in
      final opacity = (eased * 1.5).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRot);

      final paint = Paint()
        ..color = frag.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = const Color(0xFFD4A574).withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawPath(frag.path, paint);
      canvas.drawPath(frag.path, strokePaint);

      canvas.restore();
    }

    // Overlay rune marks that appear near the end
    if (progress > 0.7) {
      final runeOpacity = ((progress - 0.7) / 0.3).clamp(0.0, 1.0);
      final runePaint = Paint()
        ..color = Color(0xFFD4A574).withValues(alpha: runeOpacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale;

      // Simple rune: circle with cross
      canvas.drawCircle(Offset(cx, cy - 20 * scale), 15 * scale, runePaint);
      canvas.drawLine(
        Offset(cx, cy - 35 * scale),
        Offset(cx, cy - 5 * scale),
        runePaint,
      );
      canvas.drawLine(
        Offset(cx - 15 * scale, cy - 20 * scale),
        Offset(cx + 15 * scale, cy - 20 * scale),
        runePaint,
      );
    }
  }

  List<_Fragment> _getFragments(double scale) {
    // Shield body (large pentagon-ish shape, split into pieces)
    final pieces = <_Fragment>[];
    final colors = [
      const Color(0xFF4A6741), // dark green
      const Color(0xFF5A7751),
      const Color(0xFF3A5731),
      const Color(0xFF6A8761),
      const Color(0xFF4A6741),
      const Color(0xFF5A7751),
      const Color(0xFF3A5731),
      const Color(0xFF4A6741),
      const Color(0xFF6A8761),
      const Color(0xFF3A5731),
      const Color(0xFF5A7751),
      const Color(0xFF4A6741),
    ];

    // Top-left shoulder
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(-50 * scale, -60 * scale),
        Offset(0, -80 * scale),
        Offset(0, -30 * scale),
        Offset(-40 * scale, -20 * scale),
      ]),
      colors[0],
    ));

    // Top-right shoulder
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(50 * scale, -60 * scale),
        Offset(0, -80 * scale),
        Offset(0, -30 * scale),
        Offset(40 * scale, -20 * scale),
      ]),
      colors[1],
    ));

    // Left side
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(-50 * scale, -60 * scale),
        Offset(-40 * scale, -20 * scale),
        Offset(-55 * scale, 20 * scale),
        Offset(-60 * scale, -10 * scale),
      ]),
      colors[2],
    ));

    // Right side
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(50 * scale, -60 * scale),
        Offset(40 * scale, -20 * scale),
        Offset(55 * scale, 20 * scale),
        Offset(60 * scale, -10 * scale),
      ]),
      colors[3],
    ));

    // Center top
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(0, -30 * scale),
        Offset(-40 * scale, -20 * scale),
        Offset(-30 * scale, 20 * scale),
        Offset(30 * scale, 20 * scale),
        Offset(40 * scale, -20 * scale),
      ]),
      colors[4],
    ));

    // Lower left
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(-55 * scale, 20 * scale),
        Offset(-30 * scale, 20 * scale),
        Offset(-20 * scale, 60 * scale),
        Offset(-40 * scale, 50 * scale),
      ]),
      colors[5],
    ));

    // Lower right
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(55 * scale, 20 * scale),
        Offset(30 * scale, 20 * scale),
        Offset(20 * scale, 60 * scale),
        Offset(40 * scale, 50 * scale),
      ]),
      colors[6],
    ));

    // Center bottom
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(-30 * scale, 20 * scale),
        Offset(30 * scale, 20 * scale),
        Offset(20 * scale, 60 * scale),
        Offset(0, 90 * scale),
        Offset(-20 * scale, 60 * scale),
      ]),
      colors[7],
    ));

    // Bottom tip
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(-20 * scale, 60 * scale),
        Offset(20 * scale, 60 * scale),
        Offset(0, 90 * scale),
      ]),
      colors[8],
    ));

    // Left wing
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(-60 * scale, -10 * scale),
        Offset(-80 * scale, -30 * scale),
        Offset(-75 * scale, 10 * scale),
        Offset(-55 * scale, 20 * scale),
      ]),
      colors[9],
    ));

    // Right wing
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(60 * scale, -10 * scale),
        Offset(80 * scale, -30 * scale),
        Offset(75 * scale, 10 * scale),
        Offset(55 * scale, 20 * scale),
      ]),
      colors[10],
    ));

    // Crown piece
    pieces.add(_Fragment(
      _pathFromPoints([
        Offset(0, -80 * scale),
        Offset(-15 * scale, -95 * scale),
        Offset(0, -105 * scale),
        Offset(15 * scale, -95 * scale),
      ]),
      colors[11],
    ));

    return pieces;
  }

  Path _pathFromPoints(List<Offset> points) {
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _GuardianPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Fragment {
  final Path path;
  final Color color;
  _Fragment(this.path, this.color);
}
