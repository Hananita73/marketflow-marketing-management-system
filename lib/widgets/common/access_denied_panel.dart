import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AccessDeniedPanel
//
// Replaces a module's content when the signed-in role has no view permission
// for it. Shown by AppLayoutPage, so every route (including deep links from
// notifications or the AI assistant) is covered by one guard.
// ─────────────────────────────────────────────────────────────────────────────

class AccessDeniedPanel extends StatelessWidget {
  final String module;

  const AccessDeniedPanel({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              ),
              child: const Icon(Icons.lock_outline,
                  size: 30, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            Text('No access to $module',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Your role does not include view permission for this module.\n'
              'Ask an administrator to change your role if you need access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary(brightness),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
