import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

/// A small coloured pill badge for status labels used throughout the app.
/// Fully dark-mode compatible — backgrounds use AppTheme tinted accessors.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final config     = _configFor(status, brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: config.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  _BadgeConfig _configFor(String s, Brightness brightness) {
    switch (s) {
      case AppConstants.statusActive:
        return _BadgeConfig(bg: AppTheme.successBg(brightness), text: AppColors.success);
      case AppConstants.statusDraft:
        return _BadgeConfig(bg: AppTheme.surfaceVariant(brightness), text: AppTheme.textSecondary(brightness));
      case AppConstants.statusPaused:
        return _BadgeConfig(bg: AppTheme.warningBg(brightness), text: AppColors.warning);
      case AppConstants.statusCompleted:
        return _BadgeConfig(bg: AppTheme.infoBg(brightness), text: AppColors.info);
      case AppConstants.statusCancelled:
        return _BadgeConfig(bg: AppTheme.dangerBg(brightness), text: AppColors.danger);
      // Lead statuses
      case AppConstants.leadNew:
        return _BadgeConfig(bg: AppTheme.primaryLighter(brightness), text: AppColors.primary);
      case AppConstants.leadContacted:
        return _BadgeConfig(bg: AppTheme.infoBg(brightness), text: AppColors.info);
      case AppConstants.leadQualified:
        return _BadgeConfig(bg: AppTheme.successBg(brightness), text: AppColors.success);
      case AppConstants.leadUnqualified:
        return _BadgeConfig(bg: AppTheme.dangerBg(brightness), text: AppColors.danger);
      case AppConstants.leadConverted:
        return _BadgeConfig(bg: AppTheme.successBg(brightness), text: AppColors.success);
      // Customer-specific
      case 'Pending':
        return _BadgeConfig(bg: AppTheme.warningBg(brightness), text: AppColors.warning);
      default:
        return _BadgeConfig(bg: AppTheme.surfaceVariant(brightness), text: AppTheme.textSecondary(brightness));
    }
  }
}

class _BadgeConfig {
  final Color bg;
  final Color text;
  const _BadgeConfig({required this.bg, required this.text});
}
