import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';

class CampaignPerformanceChart extends StatelessWidget {
  final List<Campaign> campaigns;

  const CampaignPerformanceChart({super.key, required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final gridCol    = AppTheme.divider(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    final lineBarsData = [
      _buildLine(AppColors.primary, [0, 30, 45, 35, 50, 40, 55, 48]),
      _buildLine(AppColors.info, [0, 20, 35, 25, 40, 30, 45, 38]),
      _buildLine(AppColors.success, [0, 10, 18, 15, 25, 20, 30, 22]),
    ];

    final dates = ['May 12', 'May 13', 'May 14', 'May 15', 'May 16', 'May 17', 'May 18'];

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Campaign Performance Overview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _buildDropdown(context, brightness),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: gridCol,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < dates.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              dates[index],
                              style: TextStyle(
                                color: textSec,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt() == 0 ? '0' : '${value.toInt()}K',
                          style: TextStyle(
                            color: textSec,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 7,
                minY: 0,
                maxY: 60,
                lineBarsData: lineBarsData,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => AppTheme.elevatedSurface(brightness),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final colors = [AppColors.primary, AppColors.info, AppColors.success];
                        final labels = ['Impressions', 'Clicks', 'Conversions'];
                        return LineTooltipItem(
                          '${labels[spot.barIndex]}: ${spot.y.toInt()}K',
                          TextStyle(
                            color: colors[spot.barIndex],
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppColors.primary, label: 'Impressions', brightness: brightness),
              const SizedBox(width: 20),
              _LegendItem(color: AppColors.info, label: 'Clicks', brightness: brightness),
              const SizedBox(width: 20),
              _LegendItem(color: AppColors.success, label: 'Conversions', brightness: brightness),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(Color color, List<double> values) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true),
      spots: values.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value);
      }).toList(),
    );
  }

  Widget _buildDropdown(BuildContext context, Brightness brightness) {
    final cardBg    = AppTheme.surfaceVariant(brightness);
    final borderCol = AppTheme.border(brightness);
    final textPri   = AppTheme.textPrimary(brightness);
    final textSec   = AppTheme.textSecondary(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderCol),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: 'Last 7 Days',
          dropdownColor: AppTheme.surfaceColor(brightness),
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
          style: TextStyle(fontSize: 12, color: textPri),
          items: [
            DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days', style: TextStyle(fontSize: 12, color: textPri))),
            DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days', style: TextStyle(fontSize: 12, color: textPri))),
            DropdownMenuItem(value: 'Last 90 Days', child: Text('Last 90 Days', style: TextStyle(fontSize: 12, color: textPri))),
          ],
          onChanged: (_) {},
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final Brightness brightness;

  const _LegendItem({required this.color, required this.label, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary(brightness), fontSize: 11),
        ),
      ],
    );
  }
}

class CampaignStatusDonutChart extends StatelessWidget {
  final List<Campaign> campaigns;

  const CampaignStatusDonutChart({super.key, required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    final total = campaigns.length;
    final active = campaigns.where((c) => c.status == AppConstants.statusActive).length;
    final paused = campaigns.where((c) => c.status == AppConstants.statusPaused).length;
    final completed = campaigns.where((c) => c.status == AppConstants.statusCompleted).length;
    final draft = campaigns.where((c) => c.status == AppConstants.statusDraft).length;

    final sections = [
      _DonutSection('Active', active.toDouble(), AppColors.success, total),
      _DonutSection('Paused', paused.toDouble(), AppColors.warning, total),
      _DonutSection('Completed', completed.toDouble(), AppColors.info, total),
      _DonutSection('Draft', draft.toDouble(), AppColors.textSecondary, total),
    ];

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campaign Status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final donut = SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 44,
                        sections: sections.map((s) {
                          return PieChartSectionData(
                            color: s.color,
                            value: s.count == 0 ? 0.001 : s.count,
                            radius: 28,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: TextStyle(
                            color: textPri,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(
                            color: textSec,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              Widget legendList(CrossAxisAlignment alignment) => Column(
                crossAxisAlignment: alignment,
                children: sections.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.label,
                          style: TextStyle(
                            color: textPri,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.percent,
                          style: TextStyle(
                            color: textSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              if (constraints.maxWidth >= 340) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: legendList(CrossAxisAlignment.start)),
                    const SizedBox(width: 16),
                    donut,
                  ],
                );
              }

              return Column(
                children: [
                  Center(child: donut),
                  const SizedBox(height: 16),
                  legendList(CrossAxisAlignment.start),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DonutSection {
  final String label;
  final double count;
  final Color color;
  final int total;
  const _DonutSection(this.label, this.count, this.color, this.total);

  String get percent {
    if (total == 0) return '0%';
    final pct = (count / total * 100);
    return '${pct.toStringAsFixed(1)}%';
  }
}

class CampaignChannelProgress extends StatelessWidget {
  final List<Campaign> campaigns;

  const CampaignChannelProgress({super.key, required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final trackCol   = AppTheme.divider(brightness);

    final channels = _computeChannels();

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Top Campaign Channels',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _buildDropdown(context, brightness),
            ],
          ),
          const SizedBox(height: 20),
          ...channels.map((ch) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ch.label,
                        style: TextStyle(
                          color: textPri,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${ch.percentage.toInt()}%',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ch.percentage / 100,
                      minHeight: 8,
                      backgroundColor: trackCol,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_ChannelPercent> _computeChannels() {
    final total = campaigns.length.toDouble();
    if (total == 0) {
      return const [
        _ChannelPercent(label: 'Social Media', percentage: 0),
        _ChannelPercent(label: 'Email', percentage: 0),
        _ChannelPercent(label: 'Paid Ads', percentage: 0),
        _ChannelPercent(label: 'Website', percentage: 0),
        _ChannelPercent(label: 'Others', percentage: 0),
      ];
    }

    final counts = <CampaignChannel, int>{};
    for (final c in campaigns) {
      for (final ch in c.channels) {
        counts[ch] = (counts[ch] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <_ChannelPercent>[];
    for (final entry in sorted.take(4)) {
      final pct = (entry.value / total * 100);
      result.add(_ChannelPercent(label: entry.key.label, percentage: pct));
    }
    if (result.length < 5) {
      result.add(const _ChannelPercent(label: 'Others', percentage: 0));
    }

    return result;
  }

  Widget _buildDropdown(BuildContext context, Brightness brightness) {
    final cardBg    = AppTheme.surfaceVariant(brightness);
    final borderCol = AppTheme.border(brightness);
    final textPri   = AppTheme.textPrimary(brightness);
    final textSec   = AppTheme.textSecondary(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderCol),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: 'This Month',
          dropdownColor: AppTheme.surfaceColor(brightness),
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
          style: TextStyle(fontSize: 12, color: textPri),
          items: [
            DropdownMenuItem(value: 'This Month', child: Text('This Month', style: TextStyle(fontSize: 12, color: textPri))),
            DropdownMenuItem(value: 'Last Month', child: Text('Last Month', style: TextStyle(fontSize: 12, color: textPri))),
          ],
          onChanged: (_) {},
        ),
      ),
    );
  }
}

class _ChannelPercent {
  final String label;
  final double percentage;
  const _ChannelPercent({required this.label, required this.percentage});
}
