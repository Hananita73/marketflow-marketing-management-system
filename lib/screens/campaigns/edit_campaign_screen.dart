import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import 'package:flutter/services.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';
import '../../widgets/campaign/campaign_form_widgets.dart';

/// Edit Campaign screen.
/// Pre-populates all form fields from the existing campaign data.
/// Receives the campaign id via route arguments.
class EditCampaignScreen extends StatefulWidget {
  final String campaignId;

  const EditCampaignScreen({super.key, required this.campaignId});

  @override
  State<EditCampaignScreen> createState() => _EditCampaignScreenState();
}

class _EditCampaignScreenState extends State<EditCampaignScreen> {
  late Campaign _original;
  bool _notFound = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _budgetCtrl;
  late TextEditingController _audienceCtrl;
  late TextEditingController _notesCtrl;

  late CampaignObjective _objective;
  late String _status;
  late Set<CampaignChannel> _channels;
  late DateTime? _startDate;
  late DateTime? _endDate;

  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final campaign = CampaignRepository.findById(widget.campaignId);

    if (campaign == null) {
      _notFound = true;
      _nameCtrl   = TextEditingController();
      _descCtrl   = TextEditingController();
      _budgetCtrl = TextEditingController();
      _audienceCtrl = TextEditingController();
      _notesCtrl = TextEditingController();
      _objective  = CampaignObjective.brandAwareness;
      _status     = AppConstants.statusDraft;
      _channels   = {};
      _startDate  = null;
      _endDate    = null;
      return;
    }

    _original   = campaign;
    _nameCtrl   = TextEditingController(text: campaign.name);
    _descCtrl   = TextEditingController(text: campaign.description);
    _budgetCtrl = TextEditingController(
        text: campaign.budget.toStringAsFixed(0));
    _audienceCtrl = TextEditingController(text: campaign.targetAudience);
    _notesCtrl = TextEditingController(text: campaign.notes);
    _objective  = campaign.objective;
    _status     = campaign.status;
    _channels   = Set.from(campaign.channels);
    _startDate  = campaign.startDate;
    _endDate    = campaign.endDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _audienceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    // showDatePicker requires a non-nullable initialDate.
    // _startDate and _endDate are both DateTime? — guard every path.
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate?.add(const Duration(days: 1)) ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _hasChanges = true;
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (!AccessService.requireEdit(context, 'Campaigns')) return;
    if (_channels.isEmpty) {
      _showError('Please select at least one channel.');
      return;
    }

    setState(() => _saving = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      final updated = _original.copyWith(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        targetAudience: _audienceCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        objective: _objective,
        channels: _channels.toList(),
        status: _status,
        startDate: _startDate,
        endDate: _endDate,
        budget:
            double.tryParse(_budgetCtrl.text) ?? _original.budget,
      );
      CampaignRepository.update(updated);

      if (mounted) {
        setState(() => _saving = false);
        _showSuccess('Campaign updated successfully!');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.campaignDetail,
              arguments: _original.id,
            );
          }
        });
      }
    });
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (_notFound) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Campaign not found.',
                style: TextStyle(
                    color: AppTheme.textSecondary(brightness), fontSize: 14)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacementNamed(AppRoutes.campaigns),
              child: const Text('Back to Campaigns'),
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final formMaxWidth = isDesktop ? 760.0 : double.infinity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampaignFormHeader(
          title: 'Edit Campaign',
          subtitle: 'Update the details for "${_original.name}".',
          onCancel: () => Navigator.of(context).pushReplacementNamed(
            AppRoutes.campaignDetail,
            arguments: _original.id,
          ),
        ),
        const SizedBox(height: AppConstants.sectionSpacing),

        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: formMaxWidth),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() => _hasChanges = true),
              child: Column(
                children: [
                  // ── Basic Information ────────────────────────────
                  CampaignFormCard(
                    title: 'Basic Information',
                    children: [
                      const CampaignFieldLabel('Campaign Name *'),
                      CampaignTextField(
                        controller: _nameCtrl,
                        hint: 'Campaign name',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Campaign name is required'
                                : null,
                      ),
                       const SizedBox(height: 16),
                       const CampaignFieldLabel('Description'),
                       CampaignTextField(
                         controller: _descCtrl,
                         hint: 'Campaign description…',
                         maxLines: 3,
                       ),
                       const SizedBox(height: 16),
                       const CampaignFieldLabel('Target Audience'),
                       CampaignTextField(
                         controller: _audienceCtrl,
                         hint: 'e.g. Online shoppers, 18-45',
                       ),
                       const SizedBox(height: 16),
                       const CampaignFieldLabel('Notes'),
                       CampaignTextField(
                         controller: _notesCtrl,
                         hint: 'Any additional notes…',
                         maxLines: 2,
                       ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),

                  // ── Campaign Settings ────────────────────────────
                  CampaignFormCard(
                    title: 'Campaign Settings',
                    children: [
                      LayoutBuilder(builder: (ctx, cst) {
                        final twoCol = cst.maxWidth > 500;
                        return Flex(
                          direction:
                              twoCol ? Axis.horizontal : Axis.vertical,
                          children: [
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const CampaignFieldLabel('Objective *'),
                                  CampaignDropdown<CampaignObjective>(
                                    value: _objective,
                                    hint: 'Select objective',
                                    items: CampaignObjective.values
                                        .map((o) => DropdownMenuItem(
                                              value: o,
                                              child: Text(o.label,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _objective  = v!;
                                      _hasChanges = true;
                                    }),
                                    validator: (v) =>
                                        v == null ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                                width: twoCol ? 16 : 0,
                                height: twoCol ? 0 : 16),
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const CampaignFieldLabel('Status *'),
                                  CampaignDropdown<String>(
                                    value: _status,
                                    hint: 'Select status',
                                    items: const [
                                      AppConstants.statusDraft,
                                      AppConstants.statusActive,
                                      AppConstants.statusPaused,
                                      AppConstants.statusCompleted,
                                      AppConstants.statusCancelled,
                                    ]
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _status     = v!;
                                      _hasChanges = true;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                      const CampaignFieldLabel(
                          'Channels * (select all that apply)'),
                      CampaignChannelSelector(
                        selected: _channels,
                        onToggle: (ch) => setState(() {
                          _hasChanges = true;
                          _channels.contains(ch)
                              ? _channels.remove(ch)
                              : _channels.add(ch);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),

                  // ── Timeline & Budget ────────────────────────────
                  CampaignFormCard(
                    title: 'Timeline & Budget',
                    children: [
                      LayoutBuilder(builder: (ctx, cst) {
                        final twoCol = cst.maxWidth > 500;
                        return Flex(
                          direction:
                              twoCol ? Axis.horizontal : Axis.vertical,
                          children: [
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const CampaignFieldLabel('Start Date *'),
                                  CampaignDateField(
                                    value: _startDate,
                                    hint: 'Select start date',
                                    onTap: () =>
                                        _pickDate(isStart: true),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                                width: twoCol ? 16 : 0,
                                height: twoCol ? 0 : 16),
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const CampaignFieldLabel('End Date *'),
                                  CampaignDateField(
                                    value: _endDate,
                                    hint: 'Select end date',
                                    onTap: () =>
                                        _pickDate(isStart: false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                      const CampaignFieldLabel('Budget (ETB) *'),
                      CampaignTextField(
                        controller: _budgetCtrl,
                        hint: 'e.g. 150000',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Budget is required';
                          }
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),

                  // ── Action buttons ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () =>
                                Navigator.of(context).pushReplacementNamed(
                                  AppRoutes.campaignDetail,
                                  arguments: _original.id,
                                ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed:
                            (_saving || !_hasChanges) ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 15),
                        label:
                            Text(_saving ? 'Saving…' : 'Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
