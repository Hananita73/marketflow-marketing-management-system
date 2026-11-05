import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';

class CampaignFilterDialog extends StatefulWidget {
  final String currentStatus;
  final CampaignObjective? currentObjective;
  final CampaignChannel? currentChannel;
  final double? budgetMin;
  final double? budgetMax;

  const CampaignFilterDialog({
    super.key,
    this.currentStatus = '',
    this.currentObjective,
    this.currentChannel,
    this.budgetMin,
    this.budgetMax,
  });

  @override
  State<CampaignFilterDialog> createState() => _CampaignFilterDialogState();
}

class _CampaignFilterDialogState extends State<CampaignFilterDialog> {
  late String _status;
  late CampaignObjective? _objective;
  late CampaignChannel?   _channel;
  late double? _budgetMin;
  late double? _budgetMax;

  @override
  void initState() {
    super.initState();
    _status    = widget.currentStatus;
    _objective = widget.currentObjective;
    _channel   = widget.currentChannel;
    _budgetMin = widget.budgetMin;
    _budgetMax = widget.budgetMax;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dialogBg   = AppTheme.surfaceColor(brightness);
    final headerBg   = brightness == Brightness.dark
        ? const Color(0xFF2A2650)
        : AppColors.primaryLight;
    final footerBg   = AppTheme.cardColor(brightness);
    final divCol     = AppTheme.divider(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final sectionCol = textSec;

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.only(
                  topLeft:  Radius.circular(AppConstants.radiusLarge),
                  topRight: Radius.circular(AppConstants.radiusLarge),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.filter_list_outlined, size: 17, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('Filters', style: TextStyle(color: textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: textSec),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sectionCol)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _FilterChip(label: 'All',       isSelected: _status.isEmpty,                                  onTap: () => setState(() => _status = '')),
                        _FilterChip(label: 'Active',    isSelected: _status == AppConstants.statusActive,    onTap: () => setState(() => _status = AppConstants.statusActive)),
                        _FilterChip(label: 'Paused',    isSelected: _status == AppConstants.statusPaused,    onTap: () => setState(() => _status = AppConstants.statusPaused)),
                        _FilterChip(label: 'Completed', isSelected: _status == AppConstants.statusCompleted, onTap: () => setState(() => _status = AppConstants.statusCompleted)),
                        _FilterChip(label: 'Draft',     isSelected: _status == AppConstants.statusDraft,     onTap: () => setState(() => _status = AppConstants.statusDraft)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text('Objective', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sectionCol)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CampaignObjective?>(
                      initialValue: _objective,
                      hint: Text('All Objectives', style: TextStyle(fontSize: 13, color: textSec)),
                      dropdownColor: AppTheme.surfaceColor(brightness),
                      style: TextStyle(fontSize: 13, color: textPri),
                      iconEnabledColor: textSec,
                      decoration: const InputDecoration(),
                      items: [
                        DropdownMenuItem(value: null, child: Text('All Objectives', style: TextStyle(fontSize: 13, color: textPri))),
                        ...CampaignObjective.values.map((o) => DropdownMenuItem(value: o, child: Text(o.label, style: TextStyle(fontSize: 13, color: textPri)))),
                      ],
                      onChanged: (v) => setState(() => _objective = v),
                    ),
                    const SizedBox(height: 16),

                    Text('Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sectionCol)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CampaignChannel?>(
                      initialValue: _channel,
                      hint: Text('All Channels', style: TextStyle(fontSize: 13, color: textSec)),
                      dropdownColor: AppTheme.surfaceColor(brightness),
                      style: TextStyle(fontSize: 13, color: textPri),
                      iconEnabledColor: textSec,
                      decoration: const InputDecoration(),
                      items: [
                        DropdownMenuItem(value: null, child: Text('All Channels', style: TextStyle(fontSize: 13, color: textPri))),
                        ...CampaignChannel.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label, style: TextStyle(fontSize: 13, color: textPri)))),
                      ],
                      onChanged: (v) => setState(() => _channel = v),
                    ),
                    const SizedBox(height: 16),

                    Text('Budget Range (ETB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sectionCol)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _budgetMin?.toString(),
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 13, color: textPri),
                            decoration: InputDecoration(
                              hintText: 'Min',
                              hintStyle: TextStyle(fontSize: 13, color: textSec),
                            ),
                            onChanged: (v) => _budgetMin = double.tryParse(v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _budgetMax?.toString(),
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 13, color: textPri),
                            decoration: InputDecoration(
                              hintText: 'Max',
                              hintStyle: TextStyle(fontSize: 13, color: textSec),
                            ),
                            onChanged: (v) => _budgetMax = double.tryParse(v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: footerBg,
                borderRadius: const BorderRadius.only(
                  bottomLeft:  Radius.circular(AppConstants.radiusLarge),
                  bottomRight: Radius.circular(AppConstants.radiusLarge),
                ),
                border: Border(top: BorderSide(color: divCol)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _status    = '';
                        _objective = null;
                        _channel   = null;
                        _budgetMin = null;
                        _budgetMax = null;
                      });
                    },
                    child: const Text('Clear Filters'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'status':    _status,
                        'objective': _objective,
                        'channel':   _channel,
                        'budgetMin': _budgetMin,
                        'budgetMax': _budgetMax,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final unselBg    = AppTheme.surfaceVariant(brightness);
    final unselBor   = AppTheme.border(brightness);
    final unselText  = AppTheme.textSecondary(brightness);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : unselBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: isSelected ? AppColors.primary : unselBor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : unselText,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
