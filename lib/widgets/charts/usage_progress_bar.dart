import 'package:flutter/material.dart';

class UsageProgressBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final int current;
  final int total;
  final Color color;
  final bool showCount;

  const UsageProgressBar({
    super.key,
    required this.title,
    required this.current,
    required this.total,
    required this.color,
    this.subtitle = '',
    this.showCount = true,
  });

  double get _percent => total == 0 ? 0.0 : current / total;

  Color get _progressColor {
    if (_percent >= 0.9) return const Color(0xFFEF233C);
    if (_percent >= 0.7) return const Color(0xFFF4A261);
    return color;
  }

  String get _percentLabel =>
      '${(_percent * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Row ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1B2F),
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A99AA),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (showCount)
                    Text(
                      '$current/$total',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _progressColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _percentLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _progressColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Progress Track ───────────────────────────
          Stack(
            children: [
              // Background track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: _progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Filled bar
              FractionallySizedBox(
                widthFactor: _percent.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _progressColor.withValues(alpha: 0.7),
                        _progressColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: _progressColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Warning label if nearly full ─────────────
          if (_percent >= 0.9) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: _progressColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _percent >= 1.0
                      ? 'Limit reached'
                      : 'Almost at limit',
                  style: TextStyle(
                    fontSize: 11,
                    color: _progressColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section usage summary card (wraps multiple bars) ────
class UsageSummaryCard extends StatelessWidget {
  final String title;
  final List<UsageProgressBar> bars;

  const UsageSummaryCard({
    super.key,
    required this.title,
    required this.bars,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B2F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...bars,
          ],
        ),
      ),
    );
  }
}
