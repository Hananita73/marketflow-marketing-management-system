import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import 'package:flutter/services.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../models/campaign.dart';
import '../../widgets/campaign/campaign_form_widgets.dart';

/// Create Campaign screen.
/// Validated form — saves a new Campaign to the in-memory repository.
class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl   = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  CampaignObjective? _objective;
  String _status = AppConstants.statusDraft;
  final Set<CampaignChannel> _channels = {};
  DateTime? _startDate;
  DateTime? _endDate;

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
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
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (!AccessService.requireCreate(context, 'Campaigns')) return;
    if (_channels.isEmpty) {
      _showError('Please select at least one channel.');
      return;
    }

    setState(() => _saving = true);

    Future.delayed(const Duration(milliseconds: 600), () {
      final newCampaign = Campaign(
        id: CampaignRepository.nextId(),
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        targetAudience: _audienceCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        objective: _objective!,
        channels: _channels.toList(),
        status: _status,
        startDate: _startDate,
        endDate: _endDate,
        budget:
            double.tryParse(_budgetCtrl.text.replaceAll(',', '')) ?? 0,
        spent: 0,
        leads: 0,
        conversions: 0,
        impressions: 0,
        roi: 0,
        activities: [
          CampaignActivity(
            description: 'Campaign created',
            date: _fmtDate(DateTime.now()),
            icon: Icons.add_circle_outline,
            iconColor: AppColors.primary,
          ),
        ],
        coupons: [],
      expenses: const [],
      );
      CampaignRepository.add(newCampaign);

      if (mounted) {
        setState(() => _saving = false);
        _showSuccess('Campaign created successfully!');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context)
                .pushReplacementNamed(AppRoutes.campaigns);
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

  String _fmtDate(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';
  String _month(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final formMaxWidth = isDesktop ? 760.0 : double.infinity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────
        CampaignFormHeader(
          title: 'Create Campaign',
          subtitle: 'Fill in the details to launch a new marketing campaign.',
          onCancel: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.campaigns),
        ),
        const SizedBox(height: AppConstants.sectionSpacing),

        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: formMaxWidth),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Basic Information ──────────────────────────────
                  CampaignFormCard(
                    title: 'Basic Information',
                    children: [
                      const CampaignFieldLabel('Campaign Name *'),
                      CampaignTextField(
                        controller: _nameCtrl,
                        hint: 'e.g. Summer Launch 2026',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Campaign name is required'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      const CampaignFieldLabel('Description'),
                      CampaignTextField(
                        controller: _descCtrl,
                        hint: 'Brief description of the campaign goal…',
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

                  // ── Campaign Settings ──────────────────────────────
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
                                    onChanged: (v) =>
                                        setState(() => _objective = v),
                                    validator: (v) => v == null
                                        ? 'Please select an objective'
                                        : null,
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
                                    ]
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _status = v!),
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
                          _channels.contains(ch)
                              ? _channels.remove(ch)
                              : _channels.add(ch);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),

                  // ── Timeline & Budget ──────────────────────────────
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
                            return 'Enter a valid budget amount';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),

                  // ── Action buttons ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context)
                                .pushReplacementNamed(
                                    AppRoutes.campaigns),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(
                                Icons.rocket_launch_outlined,
                                size: 15),
                        label: Text(
                            _saving ? 'Creating…' : 'Create Campaign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
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
