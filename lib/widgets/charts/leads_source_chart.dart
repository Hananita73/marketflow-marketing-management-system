import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../models/dashboard_models.dart';

/// Donut chart for "Leads by Source" with center total.
/// Pure Flutter — drawn with CustomPainter.
class LeadsSourceChart extends StatelessWidget {
  final List<ChannelSlice> slices;
  final String centerValue;
  final String centerLabel;

  const LeadsSourceChart({
    super.key,
    required this.slices,
    required this.centerValue,
    this.centerLabel = 'Total Leads',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Donut ─────────────────────────────────────────────────────
        SizedBox(
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: _DonutPainter(slices: slices),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerValue,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    centerLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Legend ────────────────────────────────────────────────────
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: slices
              .map(
                (s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.name} ${s.percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut painter
// ─────────────────────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<ChannelSlice> slices;

  _DonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;
    final strokeWidth = 28.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final bgPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Draw each slice
    double startAngle = -pi / 2; // start at top
    for (final slice in slices) {
      final sweepAngle = (slice.percentage / 100) * 2 * pi;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}