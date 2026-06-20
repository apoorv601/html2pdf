import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A circular progress ring showing calories consumed vs. target.
class CalorieRing extends StatelessWidget {
  final int consumed;
  final int target;
  final int burned;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.burned = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final remaining = (target - consumed).clamp(-9999, 9999);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: progress >= 1.0 ? Colors.orange : scheme.primary,
                background: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$consumed',
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold)),
              Text('of $target kcal',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(
                remaining >= 0 ? '$remaining left' : '${-remaining} over',
                style: TextStyle(
                  color: remaining >= 0 ? scheme.primary : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (burned > 0)
                Text('🔥 $burned burned',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color background;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final bg = Paint()
      ..color = background
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
