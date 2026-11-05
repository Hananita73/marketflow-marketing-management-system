import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../models/opportunity.dart';

class PipelineValueData {
  final String stage;
  final double value;
  final int count;

  const PipelineValueData({
    required this.stage,
    required this.value,
    required this.count,
  });
}

class PipelineValueChart extends StatelessWidget {
  final List<Opportunity> opportunities;
  final double height;

  const PipelineValueChart({
    super.key,
    required this.opportunities,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final stageOrder = [
      'New',
      'Qualified',
      'Proposal',
      'Negotiation',
      'Won',
    ];

    final stageValues = <String, double>{};
    final stageCounts = <String, int>{};
    for (final o in opportunities) {
      stageValues[o.stage] = (stageValues[o.stage] ?? 0) + o.value;
      stageCounts[o.stage] = (stageCounts[o.stage] ?? 0) + 1;
    }

    final data = stageOrder.map((stage) {
      return PipelineValueData(
        stage: stage,
        value: stageValues[stage] ?? 0,
        count: stageCounts[stage] ?? 0,
      );
    }).toList();

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue == 0 ? 1 : maxValue * 1.15;

    final stageColors = <String, Color>{
      'New': AppColors.info,
      'Qualified': AppColors.primary,
      'Proposal': AppColors.warning,
      'Negotiation': AppColors.danger,
      'Won': AppColors.success,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Pipeline Value by Stage',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: stageOrder.map((stage) {
            final color = stageColors[stage] ?? AppColors.textSecondary;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  stage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            final groupWidth = chartWidth / data.length;

            return SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(data.length, (i) {
                  final d = data[i];
                  final heightFactor = (d.value / safeMax).clamp(0.02, 1.0);
                  final color = stageColors[d.stage] ?? AppColors.textSecondary;
                  final barWidth = groupWidth * 0.5;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          d.value >= 1000
                              ? '\$${(d.value / 1000).toStringAsFixed(1)}K'
                              : '\$${d.value.toInt()}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          width: barWidth,
                          height: (height - 50) * heightFactor,
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
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d.stage,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }
}
