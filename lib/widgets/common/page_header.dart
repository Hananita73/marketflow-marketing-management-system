import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PageHeader
//
// Consistent per-screen header rendered below the global AppTopBar.
//
// Layout (desktop ≥ 580px):
//   [icon + title + subtitle]  ··················  [actions row]
//
// Layout (narrow < 580px):
//   [icon + title]
//   [subtitle]
//   [actions — scrollable row]
//
// Usage:
//   PageHeader(
//     icon: Icons.article_outlined,
//     title: 'Content',
//     subtitle: 'Plan, manage, and track your marketing content.',
//     actions: [
//       PageHeaderAction.outlined(label: 'Filter', icon: Icons.filter_list, onPressed: ...),
//       PageHeaderAction.outlined(label: 'Export', icon: Icons.download_outlined, onPressed: ...),
//       PageHeaderAction.primary(label: 'Create Content', icon: Icons.add, onPressed: ...),
//     ],
//   )
// ─────────────────────────────────────────────────────────────────────────────

class PageHeader extends StatelessWidget {
  /// Icon shown in the purple badge beside the title.
  final IconData icon;

  /// Page title (e.g. 'Content', 'Promotions', 'Budget').
  final String title;

  /// Short descriptive subtitle rendered below the title.
  final String subtitle;

  /// Action buttons shown to the right of the title block.
  /// Build them with [PageHeaderAction.outlined] / [PageHeaderAction.primary].
  final List<Widget> actions;

  /// Optional leading widget injected between icon and title area.
  /// Used by Budget to slot in a period dropdown before the action buttons.
  final Widget? extraLeading;

  const PageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.extraLeading,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 580;

      // ── Title block ────────────────────────────────────────────────────
      final titleBlock = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Purple icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          // Title + subtitle
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary(brightness),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      // ── Actions row ────────────────────────────────────────────────────
      final actionsRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (extraLeading != null) ...[
            extraLeading!,
            const SizedBox(width: 8),
          ],
          ...actions.expand((btn) => [btn, const SizedBox(width: 8)]).toList()
            ..removeLast(), // remove trailing SizedBox
        ],
      );

      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleBlock,
            if (actions.isNotEmpty || extraLeading != null) ...[
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: actionsRow,
              ),
            ],
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 16),
          actionsRow,
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PageHeaderAction
//
// Factory helpers that produce consistently styled action buttons.
// ─────────────────────────────────────────────────────────────────────────────

class PageHeaderAction {
  PageHeaderAction._();

  /// Outlined secondary action (Filter, Export, period pickers…).
  static Widget outlined({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Filled primary action (Create, Add…).
  static Widget primary({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PageHeaderDropdown
//
// A period / dropdown selector styled to sit neatly in the actions row.
// Used by BudgetScreen for the period picker.
// ─────────────────────────────────────────────────────────────────────────────

class PageHeaderDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelBuilder;

  const PageHeaderDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border(brightness)),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        color: AppTheme.surfaceColor(brightness),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppTheme.surfaceColor(brightness),
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary(brightness),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppTheme.iconColor(brightness),
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelBuilder != null ? labelBuilder!(item) : '$item',
                      style: TextStyle(
                        color: AppTheme.textPrimary(brightness),
                        fontSize: 13,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
