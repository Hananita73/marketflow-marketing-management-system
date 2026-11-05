import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/dashboard_models.dart';

/// Compact KPI stat card used on the dashboard.
/// Reduced padding and font sizes vs the original to fit more cards per row.
class StatCard extends StatelessWidget {
  final KpiStat stat;

  const StatCard({super.key, required this.stat});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;

    final cardBg     = AppTheme.cardColor(brightness);
    final cardBorder = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.border;
    final textPrimary   = AppTheme.textPrimary(brightness);
    final textSecondary = AppTheme.textSecondary(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stat.label,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: stat.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stat.icon, size: 15, color: stat.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _ChangeBadge(change: stat.change, isPositive: stat.isPositive),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  stat.subtitle,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final String change;
  final bool isPositive;

  const _ChangeBadge({required this.change, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final bg    = isPositive ? AppTheme.successBg(brightness) : AppTheme.dangerBg(brightness);
    final icon  = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(
            change,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
