import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/customer.dart';

class CustomerSegmentData {
  final String name;
  final int count;
  final Color color;

  const CustomerSegmentData({
    required this.name,
    required this.count,
    required this.color,
  });
}

class CustomerSegmentsChart extends StatelessWidget {
  final List<Customer> customers;
  final double size;

  const CustomerSegmentsChart({
    super.key,
    required this.customers,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    final segments = <String, int>{};
    for (final c in customers) {
      segments[c.segment] = (segments[c.segment] ?? 0) + 1;
    }

    final total  = customers.length;
    final slices = segments.entries.map((e) {
      Color color;
      switch (e.key) {
        case 'VIP':       color = AppColors.primary; break;
        case 'Corporate': color = AppColors.info;    break;
        case 'Retail':    color = AppColors.success; break;
        default:          color = AppTheme.textSecondary(brightness);
      }
      return CustomerSegmentData(name: e.key, count: e.value, color: color);
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(slices: slices, centerTextColor: textSec),
          ),
        ),
        const SizedBox(width: AppConstants.itemSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: slices.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.name,
                        style: TextStyle(
                          color: textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      total > 0 ? '${((s.count / total) * 100).toInt()}%' : '0%',
                      style: TextStyle(
                        color: textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<CustomerSegmentData> slices;
  final Color centerTextColor;

  _DonutPainter({required this.slices, required this.centerTextColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final center      = Offset(size.width / 2, size.height / 2);
    final radius      = min(size.width, size.height) / 2;
    const strokeWidth = 22.0;
    final rect        = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    double startAngle = -pi / 2;
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);

    for (final slice in slices) {
      final sweep = (slice.count / total) * 2 * pi;
      final paint = Paint()
        ..color      = slice.color
        ..style      = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap  = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Segments',
        style: TextStyle(
          color: centerTextColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.centerTextColor != centerTextColor;
}
