import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../models/campaign.dart';

/// Filter bar for the campaign list.
/// Exposes status filter chips and channel filter dropdown.
/// All state is managed by the parent via callbacks.
class CampaignFilterBar extends StatelessWidget {
  final String selectedStatus;          // '' means "All"
  final CampaignChannel? selectedChannel;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<CampaignChannel?> onChannelChanged;

  const CampaignFilterBar({
    super.key,
    required this.selectedStatus,
    required this.selectedChannel,
    required this.onStatusChanged,
    required this.onChannelChanged,
  });

  static const List<String> _statuses = [
    '',
    AppConstants.statusActive,
    AppConstants.statusDraft,
    AppConstants.statusPaused,
    AppConstants.statusCompleted,
    AppConstants.statusCancelled,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // ── Status chips ──────────────────────────────────────────────
        ..._statuses.map((s) => _StatusChip(
              label: s.isEmpty ? 'All' : s,
              isSelected: selectedStatus == s,
              onTap: () => onStatusChanged(s),
            )),

        // ── Channel dropdown ──────────────────────────────────────────
        _ChannelDropdown(
          value: selectedChannel,
          onChanged: onChannelChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSelected
        ? AppColors.primary
        : _hovered
            ? AppColors.primaryLighter
            : AppColors.surface;
    final textColor = widget.isSelected ? Colors.white : AppColors.textSecondary;
    final border = widget.isSelected ? AppColors.primary : AppColors.border;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _ChannelDropdown extends StatelessWidget {
  final CampaignChannel? value;
  final ValueChanged<CampaignChannel?> onChanged;

  const _ChannelDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CampaignChannel?>(
          value: value,
          hint: const Text(
            'All Channels',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
          isDense: true,
          items: [
            const DropdownMenuItem<CampaignChannel?>(
              value: null,
              child: Text('All Channels', style: TextStyle(fontSize: 12)),
            ),
            ...CampaignChannel.values.map(
              (c) => DropdownMenuItem<CampaignChannel?>(
                value: c,
                child: Row(
                  children: [
                    Icon(c.icon, size: 14, color: c.color),
                    const SizedBox(width: 6),
                    Text(c.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
