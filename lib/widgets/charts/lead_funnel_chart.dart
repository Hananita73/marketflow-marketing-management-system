import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/lead.dart';

class LeadFunnelChart extends StatelessWidget {
  final List<Lead> leads;

  const LeadFunnelChart({super.key, required this.leads});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPri    = AppTheme.textPrimary(brightness);

    final stages = <String, int>{};
    for (final l in leads) {
      stages[l.status] = (stages[l.status] ?? 0) + 1;
    }

    final ordered  = <String>[AppConstants.leadNew, AppConstants.leadContacted, AppConstants.leadQualified, AppConstants.leadConverted];
    final maxCount = stages.values.isNotEmpty ? stages.values.reduce((a, b) => a > b ? a : b) : 1;

    final colors = <String, Color>{
      AppConstants.leadNew:       AppColors.primary,
      AppConstants.leadContacted: AppColors.info,
      AppConstants.leadQualified: AppColors.success,
      AppConstants.leadConverted: AppColors.warning,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ordered.map((stage) {
        final count       = stages[stage] ?? 0;
        final widthFactor = count / maxCount;
        final color       = colors[stage] ?? AppTheme.textSecondary(brightness);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Text(stage, style: TextStyle(color: textPri, fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widthFactor,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
