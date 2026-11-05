import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/lead.dart';

class LeadSourcesChart extends StatelessWidget {
  final List<Lead> leads;
  final double size;

  const LeadSourcesChart({
    super.key,
    required this.leads,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    final sources = <String, int>{};
    for (final l in leads) {
      sources[l.source] = (sources[l.source] ?? 0) + 1;
    }

    final total  = leads.length;
    final slices = sources.entries.map((e) {
      Color color;
      switch (e.key) {
        case 'Website':      color = AppColors.primary;             break;
        case 'Social Media': color = AppColors.info;                break;
        case 'Email':        color = AppColors.success;             break;
        case 'Referrals':    color = AppColors.warning;             break;
        case 'Paid Ads':     color = const Color(0xFFBB5CF8);      break;
        default:             color = AppTheme.textSecondary(brightness);
      }
      return _Slice(name: e.key, count: e.value, color: color);
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size, height: size,
          child: CustomPaint(
            painter: _DonutPainter(slices: slices, centerTextColor: textSec),
          ),
        ),
        const SizedBox(width: AppConstants.itemSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: slices.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.name, style: TextStyle(color: textPri, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  Text(total > 0 ? '${((s.count / total) * 100).toInt()}%' : '0%', style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class _Slice {
  final String name;
  final int count;
  final Color color;
  const _Slice({required this.name, required this.count, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
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
      canvas.drawArc(rect, startAngle, sweep, false,
          Paint()..color = slice.color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.butt);
      startAngle += sweep;
    }

    final tp = TextPainter(
      text: TextSpan(text: 'Sources', style: TextStyle(color: centerTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices || old.centerTextColor != centerTextColor;
}
