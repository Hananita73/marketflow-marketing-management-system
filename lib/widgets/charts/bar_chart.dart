import 'package:flutter/material.dart';

class BarChartData {
  final String label;
  final double value;
  final String displayValue;

  const BarChartData({
    required this.label,
    required this.value,
    required this.displayValue,
  });
}

class BarChart extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<BarChartData> data;
  final double height;

  const BarChart({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.data,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data
        .map((d) => d.value)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1B1B2F),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Monthly',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Bars ───────────────────────────────────
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: data.map((item) {
                  final heightFactor =
                      maxValue == 0 ? 0.0 : item.value / maxValue;
                  final isMax = item.value == maxValue;

                  return _Bar(
                    label: item.label,
                    heightFactor: heightFactor,
                    displayValue: item.displayValue,
                    color: isMax ? color : color.withValues(alpha: 0.45),
                    maxHeight: height - 30,
                    isHighlighted: isMax,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double heightFactor;
  final String displayValue;
  final Color color;
  final double maxHeight;
  final bool isHighlighted;

  const _Bar({
    required this.label,
    required this.heightFactor,
    required this.displayValue,
    required this.color,
    required this.maxHeight,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Value label above bar
        Text(
          displayValue,
          style: TextStyle(
            fontSize: 10,
            fontWeight:
                isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted
                ? color
                : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),

        // Bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          width: 28,
          height: maxHeight * heightFactor.clamp(0.04, 1.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.7),
                color,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
        ),

        const SizedBox(height: 6),

        // Month label
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isHighlighted ? FontWeight.bold : FontWeight.normal,
            color: isHighlighted
                ? const Color(0xFF1B1B2F)
                : const Color(0xFF8A99AA),
          ),
        ),
      ],
    );
  }
}
