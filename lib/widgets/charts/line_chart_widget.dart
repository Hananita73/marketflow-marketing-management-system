import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../models/dashboard_models.dart';

/// Pure-Flutter line chart for campaign performance (Impressions vs Conversions).
/// No external packages required — drawn with CustomPainter.
class LineChartWidget extends StatefulWidget {
  final List<CampaignPerformanceData> points;
  final double height;

  const LineChartWidget({
    super.key,
    required this.points,
    this.height = 200,
  });

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Track which point is hovered for tooltip
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.animSlow,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Legend ─────────────────────────────────────────────────────
        Row(
          children: [
            _LegendDot(color: AppColors.primary, label: 'Impressions'),
            const SizedBox(width: 20),
            _LegendDot(color: AppColors.success, label: 'Conversions'),
          ],
        ),
        const SizedBox(height: 12),

        // ── Chart canvas ───────────────────────────────────────────────
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return MouseRegion(
              onHover: (event) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localPos = box.globalToLocal(event.position);
                _updateHover(localPos, box.size);
              },
              onExit: (_) => setState(() => _hoveredIndex = -1),
              child: SizedBox(
                height: widget.height,
                child: CustomPaint(
                  painter: _LineChartPainter(
                    points: widget.points,
                    progress: _animation.value,
                    hoveredIndex: _hoveredIndex,
                  ),
                  size: Size.infinite,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // ── X-axis labels ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: widget.points
              .map(
                (p) => Text(
                  p.label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _updateHover(Offset localPos, Size size) {
    if (widget.points.isEmpty) return;
    final chartWidth = size.width;
    final step = chartWidth / (widget.points.length - 1);
    int closest = -1;
    double minDist = double.infinity;
    for (int i = 0; i < widget.points.length; i++) {
      final x = i * step;
      final dist = (localPos.dx - x).abs();
      if (dist < minDist && dist < step / 2) {
        minDist = dist;
        closest = i;
      }
    }
    if (closest != _hoveredIndex) {
      setState(() => _hoveredIndex = closest);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<CampaignPerformanceData> points;
  final double progress;
  final int hoveredIndex;

  _LineChartPainter({
    required this.points,
    required this.progress,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const double paddingTop = 12;
    const double paddingBottom = 4;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Determine y max across both series
    final double maxVal = points
        .map((p) => max(p.impressions, p.conversions))
        .reduce(max)
        .toDouble() * 1.1;

    final double step = size.width / (points.length - 1);

    // Helper: map a data value to canvas y coordinate
    double toY(double val) =>
        paddingTop + chartHeight - (val / maxVal) * chartHeight;

    // Helper: compute canvas point
    Offset pointAt(int i, bool isImpressions) {
      final x = i * step;
      final val = isImpressions ? points[i].impressions : points[i].conversions;
      return Offset(x, toY(val));
    }

    // ── Horizontal grid lines ─────────────────────────────────────────
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + (chartHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── Draw a smooth series ──────────────────────────────────────────
    void drawSeries(bool isImpressions, Color lineColor, Color fillColor) {
      final path = Path();
      final fillPath = Path();

      // Build the line up to progress
      final visibleCount = max(2, (points.length * progress).ceil());
      final pts = <Offset>[];
      for (int i = 0; i < min(visibleCount, points.length); i++) {
        pts.add(pointAt(i, isImpressions));
      }

      // Smooth bezier
      path.moveTo(pts[0].dx, pts[0].dy);
      for (int i = 0; i < pts.length - 1; i++) {
        final cp1 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i].dy);
        final cp2 = Offset((pts[i].dx + pts[i + 1].dx) / 2, pts[i + 1].dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i + 1].dx, pts[i + 1].dy);
      }

      // Fill path (area under the line)
      fillPath.addPath(path, Offset.zero);
      fillPath.lineTo(pts.last.dx, size.height - paddingBottom);
      fillPath.lineTo(pts.first.dx, size.height - paddingBottom);
      fillPath.close();

      // Draw fill
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );

      // Draw line
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Draw dots at each point
      for (int i = 0; i < pts.length; i++) {
        final isHovered = i == hoveredIndex;
        canvas.drawCircle(
          pts[i],
          isHovered ? 5.5 : 3.5,
          Paint()..color = lineColor,
        );
        canvas.drawCircle(
          pts[i],
          isHovered ? 3 : 2,
          Paint()..color = Colors.white,
        );
      }
    }

    drawSeries(
      true,
      AppColors.primary,
      AppColors.primary.withValues(alpha: 0.06),
    );
    drawSeries(
      false,
      AppColors.success,
      AppColors.success.withValues(alpha: 0.06),
    );

    // ── Hover tooltip ─────────────────────────────────────────────────
    if (hoveredIndex >= 0 && hoveredIndex < points.length) {
      final pt = points[hoveredIndex];
      final x = hoveredIndex * step;
      final yImp = toY(pt.impressions);

      // Vertical line
      canvas.drawLine(
        Offset(x, paddingTop),
        Offset(x, size.height - paddingBottom),
        Paint()
          ..color = AppColors.textSecondary.withValues(alpha: 0.3)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );

      // Tooltip box
      const double boxW = 130;
      const double boxH = 52;
      final double boxX = x + 10 > size.width - boxW ? x - boxW - 10 : x + 10;
      final double boxY = (yImp - boxH / 2).clamp(paddingTop, size.height - paddingBottom - boxH);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxW, boxH),
        const Radius.circular(8),
      );

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = AppColors.textDark
          ..style = PaintingStyle.fill,
      );

      final impPainter = TextPainter(
        text: TextSpan(
          text: 'Impressions: ${pt.impressions.toInt()}',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: boxW - 12);
      impPainter.paint(canvas, Offset(boxX + 8, boxY + 8));

      final convPainter = TextPainter(
        text: TextSpan(
          text: 'Conversions: ${pt.conversions.toInt()}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: boxW - 12);
      convPainter.paint(canvas, Offset(boxX + 8, boxY + 28));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.progress != progress || old.hoveredIndex != hoveredIndex;
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend dot
// ─────────────────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
