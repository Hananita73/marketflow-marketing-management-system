import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

/// Campaign-specific status badge — fully dark-mode compatible.
class CampaignStatusBadge extends StatelessWidget {
  final String status;

  const CampaignStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cfg = _config(status, brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: cfg.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cfg.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _Cfg _config(String s, Brightness brightness) {
    switch (s) {
      case AppConstants.statusActive:
        return _Cfg(
          bg:   AppTheme.successBg(brightness),
          text: AppColors.success,
          dot:  AppColors.success,
        );
      case AppConstants.statusDraft:
        return _Cfg(
          bg:   AppTheme.surfaceVariant(brightness),
          text: AppTheme.textSecondary(brightness),
          dot:  AppTheme.textSecondary(brightness),
        );
      case AppConstants.statusPaused:
        return _Cfg(
          bg:   AppTheme.warningBg(brightness),
          text: AppColors.warning,
          dot:  AppColors.warning,
        );
      case AppConstants.statusCompleted:
        return _Cfg(
          bg:   AppTheme.infoBg(brightness),
          text: AppColors.info,
          dot:  AppColors.info,
        );
      case AppConstants.statusCancelled:
        return _Cfg(
          bg:   AppTheme.dangerBg(brightness),
          text: AppColors.danger,
          dot:  AppColors.danger,
        );
      default:
        return _Cfg(
          bg:   AppTheme.surfaceVariant(brightness),
          text: AppTheme.textSecondary(brightness),
          dot:  AppTheme.textSecondary(brightness),
        );
    }
  }
}

class _Cfg {
  final Color bg;
  final Color text;
  final Color dot;
  const _Cfg({required this.bg, required this.text, required this.dot});
}
