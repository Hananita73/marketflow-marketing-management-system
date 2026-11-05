import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../models/dashboard_models.dart';

/// Grouped bar chart for campaign performance (Impressions, Clicks, Conversions).
/// Pure Flutter — no external packages required.
class CampaignPerformanceChart extends StatefulWidget {
  final List<CampaignPerformanceData> data;
  final double height;

  const CampaignPerformanceChart({
    super.key,
    required this.data,
    this.height = 240,
  });

  @override
  State<CampaignPerformanceChart> createState() =>
      _CampaignPerformanceChartState();
}

class _CampaignPerformanceChartState extends State<CampaignPerformanceChart> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    // The layout divides the width by the number of groups, so an empty
    // dataset (every campaign deleted, database cleared) must short-circuit.
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No campaign data yet',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Legend ─────────────────────────────────────────────────────
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: const [
            _LegendItem(color: AppColors.primary, label: 'Impressions'),
            _LegendItem(color: AppColors.info, label: 'Leads'),
            _LegendItem(color: AppColors.success, label: 'Conversions'),
          ],
        ),
        const SizedBox(height: 16),

        // ── Chart ──────────────────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            final groupWidth = chartWidth / widget.data.length;
            final barWidth = (groupWidth * 0.6) / 3;

            // Find max value across all series for scaling
            double maxVal = 0;
            for (final d in widget.data) {
              maxVal = [
                maxVal,
                d.impressions,
                d.leads,
                d.conversions.toDouble(),
              ].reduce((a, b) => a > b ? a : b);
            }
            maxVal *= 1.15; // headroom

            return SizedBox(
              height: widget.height,
              child: MouseRegion(
                onExit: (_) => setState(() => _hoveredIndex = -1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(widget.data.length, (i) {
                    final d = widget.data[i];
                    return Expanded(
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Tooltip on hover
                            if (_hoveredIndex == i)
                              _TooltipCard(data: d)
                            else
                              const SizedBox(height: 40),
                            const SizedBox(height: 4),
                            // Bars
                            SizedBox(
                              height: widget.height - 70,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _Bar(
                                    value: d.impressions,
                                    maxVal: maxVal,
                                    color: AppColors.primary,
                                    width: barWidth,
                                    displayValue:
                                        '${d.impressions.toStringAsFixed(1)}K',
                                  ),
                                  const SizedBox(width: 3),
                                  _Bar(
                                    value: d.leads,
                                    maxVal: maxVal,
                                    color: AppColors.info,
                                    width: barWidth,
                                    displayValue:
                                        '${d.leads.toStringAsFixed(1)}K',
                                  ),
                                  const SizedBox(width: 3),
                                  _Bar(
                                    value: d.conversions.toDouble(),
                                    maxVal: maxVal,
                                    color: AppColors.success,
                                    width: barWidth,
                                    displayValue: '${d.conversions}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // X-axis label
                            Text(
                              d.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual bar
// ─────────────────────────────────────────────────────────────────────────────

class _Bar extends StatelessWidget {
  final double value;
  final double maxVal;
  final Color color;
  final double width;
  final String displayValue;

  const _Bar({
    required this.value,
    required this.maxVal,
    required this.color,
    required this.width,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    final heightFactor = maxVal == 0 ? 0.0 : (value / maxVal).clamp(0.02, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Value label
        Text(
          displayValue,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        // Bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          width: width,
          height: 140 * heightFactor,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.6),
                color,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tooltip card shown on hover
// ─────────────────────────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final CampaignPerformanceData data;
  const _TooltipCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textDark,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Imp: ${data.impressions.toStringAsFixed(1)}K  ·  '
            'Leads: ${data.leads.toStringAsFixed(1)}  ·  '
            'Conv: ${data.conversions}',
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend item
// ─────────────────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}