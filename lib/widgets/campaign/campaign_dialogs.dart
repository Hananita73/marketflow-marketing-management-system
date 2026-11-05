import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';
import '../../models/campaign_customer.dart';
import '../../models/customer.dart';
import '../common/custom_button.dart';
import 'campaign_form_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CampaignFormDialog — Create / Edit
// ─────────────────────────────────────────────────────────────────────────────

class CampaignFormDialog extends StatefulWidget {
  final Campaign? campaign;

  const CampaignFormDialog({super.key, this.campaign});

  @override
  State<CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends State<CampaignFormDialog> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _budgetCtrl  = TextEditingController();
  final _audienceCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();

  CampaignObjective? _objective;
  String _status = AppConstants.statusDraft;
  final Set<CampaignChannel> _channels = {};
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    if (c != null) {
      _nameCtrl.text     = c.name;
      _descCtrl.text     = c.description;
      _budgetCtrl.text   = c.budget.toStringAsFixed(0);
      _audienceCtrl.text = c.targetAudience;
      _notesCtrl.text    = c.notes;
      _objective         = c.objective;
      _status            = c.status;
      _channels.addAll(c.channels);
      _startDate         = c.startDate;
      _endDate           = c.endDate;
    }
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
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? (_startDate?.add(const Duration(days: 30)) ?? now)),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_objective == null) {
      _showError('Please select an objective.');
      return;
    }
    if (_channels.isEmpty) {
      _showError('Please select at least one channel.');
      return;
    }
    if (widget.campaign == null && (_startDate == null || _endDate == null)) {
      _showError('Please select both start and end dates.');
      return;
    }

    setState(() => _saving = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      final isEdit  = widget.campaign != null;
      final updated = (widget.campaign ??
              Campaign(
                id: CampaignRepository.nextId(),
                name: '',
                description: '',
                objective: CampaignObjective.brandAwareness,
                channels: const [],
                status: AppConstants.statusDraft,
                budget: 0,
                spent: 0,
                leads: 0,
                conversions: 0,
                impressions: 0,
                roi: 0,
                activities: const [],
                coupons: const [],
                expenses: const [],
              ))
          .copyWith(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        targetAudience: _audienceCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        objective: _objective!,
        channels: _channels.toList(),
        status: _status,
        startDate: _startDate,
        endDate: _endDate,
        budget: double.tryParse(_budgetCtrl.text.replaceAll(',', '')) ?? 0,
      );

      if (isEdit) {
        CampaignRepository.update(updated);
      } else {
        CampaignRepository.add(updated);
      }

      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop(updated);
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit     = widget.campaign != null;
    final brightness = Theme.of(context).brightness;
    final dialogBg   = AppTheme.surfaceColor(brightness);
    final headerBg   = brightness == Brightness.dark
        ? const Color(0xFF2A2650)
        : AppColors.primaryLight;
    final headerText = AppTheme.textPrimary(brightness);
    final footerBg   = AppTheme.cardColor(brightness);
    final divCol     = AppTheme.divider(brightness);
    final sectionCol = AppTheme.textPrimary(brightness);
    final width      = MediaQuery.of(context).size.width;
    final maxWidth   = width < 600 ? width * 0.95 : 720.0;

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 600 ? 16 : 80,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign_outlined, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Campaign' : 'New Campaign',
                    style: TextStyle(
                      color: headerText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppTheme.textSecondary(brightness)),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section title
                      Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sectionCol,
                        ),
                      ),
                      const SizedBox(height: 12),

                      CampaignFieldLabel('Campaign Name *'),
                      CampaignTextField(
                        controller: _nameCtrl,
                        hint: 'e.g. Summer Sale 2026',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Campaign name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      CampaignFieldLabel('Description'),
                      CampaignTextField(
                        controller: _descCtrl,
                        hint: 'Brief description of the campaign goal…',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),

                      CampaignFieldLabel('Target Audience'),
                      CampaignTextField(
                        controller: _audienceCtrl,
                        hint: 'e.g. Online shoppers, 18–45',
                      ),
                      const SizedBox(height: 12),

                      CampaignFieldLabel('Notes'),
                      CampaignTextField(
                        controller: _notesCtrl,
                        hint: 'Any additional notes…',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Campaign Settings',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sectionCol,
                        ),
                      ),
                      const SizedBox(height: 12),

                      LayoutBuilder(builder: (ctx, cst) {
                        final twoCol = cst.maxWidth > 500;
                        return Flex(
                          direction: twoCol ? Axis.horizontal : Axis.vertical,
                          children: [
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CampaignFieldLabel('Objective *'),
                                  CampaignDropdown<CampaignObjective>(
                                    value: _objective,
                                    hint: 'Select objective',
                                    items: CampaignObjective.values.map((o) {
                                      return DropdownMenuItem(
                                        value: o,
                                        child: Text(o.label, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() => _objective = v),
                                    validator: (v) => v == null ? 'Please select an objective' : null,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: twoCol ? 16 : 0, height: twoCol ? 0 : 16),
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CampaignFieldLabel('Status *'),
                                  CampaignDropdown<String>(
                                    value: _status,
                                    hint: 'Select status',
                                    items: const [
                                      AppConstants.statusDraft,
                                      AppConstants.statusActive,
                                      AppConstants.statusPaused,
                                      AppConstants.statusCompleted,
                                    ]
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s, style: const TextStyle(fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _status = v!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),

                      CampaignFieldLabel('Channels * (select all that apply)'),
                      CampaignChannelSelector(
                        selected: _channels,
                        onToggle: (ch) => setState(() {
                          _channels.contains(ch)
                              ? _channels.remove(ch)
                              : _channels.add(ch);
                        }),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Timeline & Budget',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sectionCol,
                        ),
                      ),
                      const SizedBox(height: 12),

                      LayoutBuilder(builder: (ctx, cst) {
                        final twoCol = cst.maxWidth > 500;
                        return Flex(
                          direction: twoCol ? Axis.horizontal : Axis.vertical,
                          children: [
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CampaignFieldLabel('Start Date'),
                                  CampaignDateField(
                                    value: _startDate,
                                    hint: 'Select start date',
                                    onTap: () => _pickDate(isStart: true),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: twoCol ? 16 : 0, height: twoCol ? 0 : 16),
                            Flexible(
                              flex: twoCol ? 1 : 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CampaignFieldLabel('End Date'),
                                  CampaignDateField(
                                    value: _endDate,
                                    hint: 'Select end date',
                                    onTap: () => _pickDate(isStart: false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),

                      CampaignFieldLabel('Budget (ETB) *'),
                      CampaignTextField(
                        controller: _budgetCtrl,
                        hint: 'e.g. 50000',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Budget is required';
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed <= 0) return 'Enter a valid budget amount';
                          return null;
                        },
                      ),
                    ],
                  ),
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
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    text: _saving
                        ? 'Saving…'
                        : (isEdit ? 'Save Changes' : 'Create Campaign'),
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
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

// ─────────────────────────────────────────────────────────────────────────────
// CampaignDetailsDialog — read-only view
// ─────────────────────────────────────────────────────────────────────────────

class CampaignDetailsDialog extends StatelessWidget {
  final Campaign campaign;

  const CampaignDetailsDialog({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    final assignments = CampaignCustomerRepository.getByCampaign(campaign.id);
    final customers = assignments
        .map((assignment) => (
              assignment: assignment,
              customer: CustomerRepository.findById(assignment.customerId),
            ))
        .toList();
    final brightness = Theme.of(context).brightness;
    final dialogBg   = AppTheme.surfaceColor(brightness);
    final headerBg   = brightness == Brightness.dark
        ? const Color(0xFF2A2650)
        : AppColors.primaryLight;
    final footerBg   = AppTheme.cardColor(brightness);
    final divCol     = AppTheme.divider(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return Dialog(
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign_outlined, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      campaign.name,
                      style: TextStyle(
                        color: textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                    _detailRow('Status',          campaign.status,                                         textPri, textSec),
                    _detailRow('Objective',        campaign.objective.label,                               textPri, textSec),
                    _detailRow('Description',      campaign.description,                                   textPri, textSec),
                    _detailRow('Target Audience',  campaign.targetAudience.isNotEmpty ? campaign.targetAudience : '-', textPri, textSec),
                    _detailRow('Channels',         campaign.channels.map((c) => c.label).join(', '),       textPri, textSec),
                    _detailRow('Start Date',       campaign.startDate != null ? _fmtDate(campaign.startDate!) : '-', textPri, textSec),
                    _detailRow('End Date',         campaign.endDate   != null ? _fmtDate(campaign.endDate!)   : '-', textPri, textSec),
                    _detailRow('Budget',           'ETB ${campaign.budget.toStringAsFixed(0)}',            textPri, textSec),
                    _detailRow('Spent',            'ETB ${campaign.spent.toStringAsFixed(0)}',             textPri, textSec),
                    _detailRow('ROI',              '${campaign.roi}x',                                     textPri, textSec),
                    if (campaign.notes.isNotEmpty)
                      _detailRow('Notes', campaign.notes, textPri, textSec),
                    const SizedBox(height: 8),
                    Text(
                      'Customers (${customers.length})',
                      style: TextStyle(
                        color: textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (customers.isEmpty)
                      Text(
                        'No customers assigned to this campaign.',
                        style: TextStyle(color: textSec, fontSize: 12),
                      )
                    else
                      ...customers.map((entry) {
                        final customer = entry.customer;
                        if (customer == null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Customer #${entry.assignment.customerId} — profile unavailable',
                              style: TextStyle(color: textSec, fontSize: 12),
                            ),
                          );
                        }
                        final company = customer.company.trim();
                        final details = <String>[
                          if (company.isNotEmpty) company,
                          if (customer.segment.isNotEmpty) customer.segment,
                          if (customer.email.isNotEmpty) customer.email,
                          if (customer.phone.isNotEmpty) customer.phone,
                        ];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant(brightness),
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                            border: Border.all(
                              color: AppTheme.border(brightness),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Text(
                                  customer.initials,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: TextStyle(
                                        color: textPri,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (details.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        details.join(' · '),
                                        style: TextStyle(
                                          color: textSec,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.assignment.participationStatus,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color textPri, Color textSec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textPri, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DeleteCampaignDialog — confirmation
// ─────────────────────────────────────────────────────────────────────────────

class DeleteCampaignDialog extends StatelessWidget {
  final String campaignName;
  final VoidCallback onConfirm;

  const DeleteCampaignDialog({
    super.key,
    required this.campaignName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
          const SizedBox(width: 10),
          Text(
            'Delete Campaign?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete "$campaignName"? This action cannot be undone.',
        style: TextStyle(color: textSec, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
