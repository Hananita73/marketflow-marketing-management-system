import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';

/// Shared form widgets used by both CreateCampaignScreen, EditCampaignScreen,
/// and the inline New Campaign panel in CampaignListScreen.
/// All widgets are fully dark-mode compatible via AppTheme.

// ─────────────────────────────────────────────────────────────────────────────
// Form page header (back arrow + title + subtitle)
// ─────────────────────────────────────────────────────────────────────────────

class CampaignFormHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onCancel;

  const CampaignFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final borderCol  = AppTheme.border(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onCancel,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: borderCol),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_back, size: 18, color: textSec),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,    style: Theme.of(context).textTheme.headlineMedium),
              Text(subtitle, style: TextStyle(color: textSec, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card with title + divider
// ─────────────────────────────────────────────────────────────────────────────

class CampaignFormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const CampaignFormCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final divCol     = AppTheme.divider(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Divider(height: 1, color: divCol),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field label
// ─────────────────────────────────────────────────────────────────────────────

class CampaignFieldLabel extends StatelessWidget {
  final String text;
  const CampaignFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textPrimary(brightness),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text field
// ─────────────────────────────────────────────────────────────────────────────

class CampaignTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const CampaignTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textCol    = AppTheme.textPrimary(brightness);
    final hintCol    = AppTheme.textSecondary(brightness);

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(fontSize: 13, color: textCol),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: hintCol),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown field
// ─────────────────────────────────────────────────────────────────────────────

class CampaignDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const CampaignDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textCol    = AppTheme.textPrimary(brightness);
    final hintCol    = AppTheme.textSecondary(brightness);

    return DropdownButtonFormField<T>(
      initialValue: value,
      hint: Text(hint, style: TextStyle(fontSize: 13, color: hintCol)),
      items: items,
      onChanged: onChanged,
      validator: validator,
      dropdownColor: AppTheme.surfaceColor(brightness),
      style: TextStyle(fontSize: 13, color: textCol),
      iconEnabledColor: AppTheme.textSecondary(brightness),
      decoration: const InputDecoration(),
      isExpanded: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date picker field
// ─────────────────────────────────────────────────────────────────────────────

class CampaignDateField extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final VoidCallback onTap;

  const CampaignDateField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.inputFill(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textCol    = value == null
        ? AppTheme.textSecondary(brightness)
        : AppTheme.textPrimary(brightness);
    final iconCol    = AppTheme.textSecondary(brightness);

    final label = value == null
        ? hint
        : '${value!.day} ${_month(value!.month)} ${value!.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: iconCol),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: textCol),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _month(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m];
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel multi-selector
// ─────────────────────────────────────────────────────────────────────────────

class CampaignChannelSelector extends StatelessWidget {
  final Set<CampaignChannel> selected;
  final void Function(CampaignChannel) onToggle;

  const CampaignChannelSelector({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final unselBg    = AppTheme.inputFill(brightness);
    final unselBor   = AppTheme.border(brightness);
    final unselText  = AppTheme.textSecondary(brightness);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CampaignChannel.values.map((ch) {
        final isSelected = selected.contains(ch);
        return InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          onTap: () => onToggle(ch),
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? ch.color.withValues(alpha: 0.15)
                  : unselBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: isSelected ? ch.color : unselBor,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ch.icon,
                  size: 15,
                  color: isSelected ? ch.color : unselText,
                ),
                const SizedBox(width: 6),
                Text(
                  ch.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? ch.color : unselText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
