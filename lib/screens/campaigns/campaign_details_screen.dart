// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/budget.dart';
import '../../models/campaign.dart';
import '../../models/campaign_customer.dart';
import '../../models/content_item.dart';
import '../../models/customer.dart';
import '../../models/expense.dart';
import '../../models/lead.dart';
import '../../models/promotion.dart';
import '../../services/access_service.dart';
import '../../services/approval_service.dart';
import '../../services/auth_service.dart';
import '../../services/audit_log_service.dart';
import '../../widgets/campaign/campaign_status_badge.dart';
import '../../widgets/badges/status_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CampaignDetailsScreen
// Full tabbed detail view: Overview · Expenses · Leads · Customers ·
//   Content · Promotions · Activities
// ─────────────────────────────────────────────────────────────────────────────

class CampaignDetailsScreen extends StatefulWidget {
  final String campaignId;
  const CampaignDetailsScreen({super.key, required this.campaignId});

  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _tabs = [
    'Overview',
    'Expenses',
    'Leads',
    'Customers',
    'Budget',
    'Content',
    'Promotions',
    'Activities',
  ];

  Campaign? _campaign;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _reload();
  }

  void _reload() => setState(
    () => _campaign = CampaignRepository.findById(widget.campaignId),
  );

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color color = AppColors.success}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );

  // ── Add expense dialog ─────────────────────────────────────────────────────
  void _addExpense(Campaign c) {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final br = Theme.of(ctx).brightness;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: fk,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Add Expense',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(br),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close,
                            color: AppTheme.textSecondary(br),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: descCtrl,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary(br),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Description *',
                        filled: true,
                        fillColor: AppTheme.inputFill(br),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amtCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary(br),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount (ETB) *',
                        filled: true,
                        fillColor: AppTheme.inputFill(br),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null)
                          return 'Number required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (!fk.currentState!.validate()) return;
                            final exp = CampaignExpense(
                              id: CampaignRepository.nextExpenseId(c.id),
                              description: descCtrl.text.trim(),
                              amount: double.parse(amtCtrl.text.trim()),
                              date: DateTime.now(),
                              approvedBy: '',
                              status: AppConstants.expensePending,
                            );
                            CampaignRepository.addExpense(c.id, exp);
                            AuditLogService.logCreate(
                              'Campaigns',
                              c.id,
                              '${c.name} — Expense ${exp.id}',
                              details: {'amount': exp.amount},
                            );
                            _reload();
                            Navigator.pop(ctx);
                            _snack('Expense recorded and pending approval.');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Add Expense'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _campaign;
    if (c == null) {
      return Center(
        child: Text(
          'Campaign not found.',
          style: TextStyle(
            color: AppTheme.textSecondary(Theme.of(context).brightness),
          ),
        ),
      );
    }

    final br = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── breadcrumb + title
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.cardPadding,
            AppConstants.pagePadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.campaigns),
                    child: const Text(
                      'Campaigns',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ),
                  Text(
                    ' / ',
                    style: TextStyle(
                      color: AppTheme.textSecondary(br),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    c.name,
                    style: TextStyle(
                      color: AppTheme.textSecondary(br),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${c.id}  ·  ${c.objective.label}',
                          style: TextStyle(
                            color: AppTheme.textSecondary(br),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CampaignStatusBadge(status: c.status),
                  const SizedBox(width: 12),
                  // Submit for approval (staff only, when draft/changes-requested)
                  if (AccessService.isSubmitter &&
                      (c.status == AppConstants.statusDraft ||
                          c.status == AppConstants.statusChangesRequested)) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (ApprovalService.submitCampaign(context, c.id)) {
                          _reload();
                        }
                      },
                      icon: const Icon(Icons.send_outlined, size: 15),
                      label: const Text('Submit for Approval'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Approval actions (manager/admin, when pending)
                  if (AccessService.isApprover &&
                      c.status == AppConstants.statusPendingApproval) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await ApprovalService.requestChangesCampaign(
                          context,
                          c.id,
                        );
                        if (ok) _reload();
                      },
                      icon: const Icon(Icons.edit_note_outlined, size: 15),
                      label: const Text('Changes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await ApprovalService.rejectCampaign(
                          context,
                          c.id,
                        );
                        if (ok) _reload();
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 15),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await ApprovalService.approveCampaign(
                          context,
                          c.id,
                        );
                        if (ok) _reload();
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () {
                      if (!AccessService.canEdit('Campaigns')) {
                        _snack(
                          'Your role cannot edit campaigns.',
                          color: AppColors.danger,
                        );
                        return;
                      }
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.campaignEdit, arguments: c.id);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── KPI row
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            16,
            AppConstants.pagePadding,
            0,
          ),
          child: _KpiRow(campaign: c),
        ),

        // ── Tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            20,
            AppConstants.pagePadding,
            0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(br),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(color: AppTheme.border(br)),
            ),
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppTheme.textSecondary(br),
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              padding: const EdgeInsets.all(4),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),

        // ── Tab content
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _OverviewTab(campaign: c),
              _ExpensesTab(
                campaign: c,
                onAddExpense: () => _addExpense(c),
                onApprove: (expId) {
                  CampaignRepository.approveExpense(
                    c.id,
                    expId,
                    AuthService().currentName,
                  );
                  _reload();
                  _snack('Expense approved.');
                },
                onReject: (expId) {
                  CampaignRepository.rejectExpense(
                    c.id,
                    expId,
                    AuthService().currentName,
                  );
                  _reload();
                  _snack('Expense rejected.', color: AppColors.warning);
                },
              ),
              _LeadsTab(campaign: c),
              _CustomersTab(campaign: c, onReload: _reload, snack: _snack),
              _BudgetTab(campaign: c, onReload: _reload, snack: _snack),
              _ContentTab(campaign: c),
              _PromotionsTab(campaign: c),
              _ActivitiesTab(campaign: c),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Overview
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Campaign campaign;
  const _OverviewTab({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final wide = MediaQuery.of(context).size.width >= 900;

    final overview = _SectionCard(
      title: 'Campaign Overview',
      child: Column(
        children: [
          _InfoRow(
            'Description',
            campaign.description.isEmpty ? '—' : campaign.description,
          ),
          _InfoRow(
            'Target Audience',
            campaign.targetAudience.isEmpty ? '—' : campaign.targetAudience,
          ),
          _InfoRow('Objective', campaign.objective.label),
          _InfoRow('Status', campaign.status),
          _InfoRow(
            'Start Date',
            campaign.startDate != null ? _fmtDate(campaign.startDate!) : '—',
          ),
          _InfoRow(
            'End Date',
            campaign.endDate != null ? _fmtDate(campaign.endDate!) : '—',
          ),
          _InfoRow(
            'Channels',
            campaign.channels.map((c) => c.label).join(', '),
          ),
          if (campaign.approvedBy.isNotEmpty)
            _InfoRow('Approved By', campaign.approvedBy),
          if (campaign.submittedBy.isNotEmpty)
            _InfoRow('Submitted By', campaign.submittedBy),
          if (campaign.approvalComments.isNotEmpty)
            _InfoRow(
              campaign.status == AppConstants.statusChangesRequested
                  ? 'Changes Requested'
                  : 'Review Comments',
              campaign.approvalComments,
            ),
        ],
      ),
    );

    final pct = (campaign.budgetUtilization * 100).toStringAsFixed(1);
    final barC = campaign.budgetUtilization > 0.9
        ? AppColors.danger
        : campaign.budgetUtilization > 0.7
        ? AppColors.warning
        : AppColors.success;
    final budget = _SectionCard(
      title: 'Budget & Spending',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BudgetStat(
            'Total Budget',
            'ETB ${_num(campaign.budget)}',
            AppTheme.textPrimary(br),
          ),
          const SizedBox(height: 8),
          _BudgetStat(
            'Amount Spent',
            'ETB ${_num(campaign.spent)}',
            AppColors.danger,
          ),
          const SizedBox(height: 8),
          _BudgetStat(
            'Remaining',
            'ETB ${_num(campaign.remaining)}',
            AppColors.success,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Utilization',
                style: TextStyle(
                  color: AppTheme.textSecondary(br),
                  fontSize: 12,
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  color: barC,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: campaign.budgetUtilization,
              minHeight: 8,
              backgroundColor: AppTheme.border(br),
              valueColor: AlwaysStoppedAnimation<Color>(barC),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: overview),
                const SizedBox(width: AppConstants.itemSpacing),
                Expanded(flex: 2, child: budget),
              ],
            )
          : Column(
              children: [
                overview,
                const SizedBox(height: AppConstants.itemSpacing),
                budget,
              ],
            ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';
  String _month(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];
  String _num(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Expenses
// ─────────────────────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onAddExpense;
  final void Function(String) onApprove;
  final void Function(String) onReject;

  const _ExpensesTab({
    required this.campaign,
    required this.onAddExpense,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final canAp =
        AuthService().currentRole == 'admin' ||
        AuthService().currentRole == 'marketing_manager';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: _SectionCard(
        title: 'Campaign Expenses',
        action: ElevatedButton.icon(
          onPressed: onAddExpense,
          icon: const Icon(Icons.add, size: 14),
          label: const Text('Add Expense', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
        child: campaign.expenses.isEmpty
            ? _EmptyMsg('No expenses recorded for this campaign.')
            : Column(
                children: campaign.expenses.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(br),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      border: Border.all(color: AppTheme.border(br)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(br),
                                ),
                              ),
                              Text(
                                'ETB ${e.amount.toStringAsFixed(2)}  ·  ${e.date.day}/${e.date.month}/${e.date.year}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(br),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: e.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            e.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: e.statusColor,
                            ),
                          ),
                        ),
                        if (canAp &&
                            e.status == AppConstants.expensePending) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.success,
                              size: 18,
                            ),
                            tooltip: 'Approve',
                            onPressed: () => onApprove(e.id),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.danger,
                              size: 18,
                            ),
                            tooltip: 'Reject',
                            onPressed: () => onReject(e.id),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Leads
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  final Campaign campaign;
  const _LeadsTab({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    // Find leads linked to this campaign
    final leads = LeadRepository.getAll()
        .where((l) => l.assignedCampaignId == campaign.id)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: _SectionCard(
        title: 'Associated Leads (${leads.length})',
        child: leads.isEmpty
            ? _EmptyMsg('No leads are currently linked to this campaign.')
            : Column(
                children: leads.map((l) {
                  final sc = l.score >= 80
                      ? AppColors.success
                      : l.score >= 50
                      ? AppColors.warning
                      : AppColors.danger;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(br),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      border: Border.all(color: AppTheme.border(br)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: Text(
                            l.name
                                .split(' ')
                                .take(2)
                                .map((w) => w[0].toUpperCase())
                                .join(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(br),
                                ),
                              ),
                              Text(
                                '${l.company}  ·  ${l.source}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(br),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: sc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${l.score}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: sc,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: l.status),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Customers (many-to-many via CampaignCustomerRepository)
// ─────────────────────────────────────────────────────────────────────────────

class _CustomersTab extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback onReload;
  final void Function(String msg, {Color color}) snack;
  const _CustomersTab({
    required this.campaign,
    required this.onReload,
    required this.snack,
  });

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  String _search = '';
  String _statusFilter = 'All';

  void _showAssignDialog(BuildContext ctx) {
    final allCustomers = CustomerRepository.getAll();
    final searchCtrl = TextEditingController();
    final allocatedCtrl = TextEditingController();
    final campaignBudget = BudgetRepository.allocatedForCampaign(
      widget.campaign.id,
    );
    final allocationLimit = campaignBudget > 0
        ? campaignBudget
        : widget.campaign.budget;
    int? selectedId;
    bool saving = false;

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setLocal) {
          final br = Theme.of(dCtx).brightness;
          final textPri = AppTheme.textPrimary(br);
          final textSec = AppTheme.textSecondary(br);
          final fill = AppTheme.inputFill(br);
          final border = AppTheme.border(br);
          final dropBg = AppTheme.surfaceColor(br);

          final matches = searchCtrl.text.isEmpty
              ? allCustomers
              : allCustomers
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(
                            searchCtrl.text.toLowerCase(),
                          ) ||
                          c.company.toLowerCase().contains(
                            searchCtrl.text.toLowerCase(),
                          ) ||
                          c.email.toLowerCase().contains(
                            searchCtrl.text.toLowerCase(),
                          ),
                    )
                    .toList();

          return Dialog(
            backgroundColor: AppTheme.surfaceColor(br),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              side: BorderSide(color: AppTheme.border(br)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.of(dCtx).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: br == Brightness.dark
                          ? const Color(0xFF2A2650)
                          : AppColors.primaryLight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppConstants.radiusLarge),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Assign Customer',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dCtx),
                          icon: Icon(Icons.close, color: textSec, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 40,
                            child: TextField(
                              controller: searchCtrl,
                              onChanged: (_) => setLocal(() {}),
                              style: TextStyle(fontSize: 13, color: textPri),
                              decoration: InputDecoration(
                                hintText: 'Search…',
                                hintStyle: TextStyle(color: textSec),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 18,
                                  color: textSec,
                                ),
                                filled: true,
                                fillColor: fill,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMedium,
                                  ),
                                  borderSide: BorderSide(color: border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMedium,
                                  ),
                                  borderSide: BorderSide(color: border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: fill,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusMedium,
                              ),
                              border: Border.all(color: border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: selectedId,
                                isExpanded: true,
                                isDense: true,
                                dropdownColor: dropBg,
                                hint: Text(
                                  'Select a customer',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSec,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: textSec,
                                ),
                                style: TextStyle(fontSize: 13, color: textPri),
                                items: matches
                                    .map(
                                      (c) => DropdownMenuItem<int?>(
                                        value: c.id,
                                        child: Text(
                                          '${c.name} — ${c.email}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textPri,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setLocal(() => selectedId = v),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Campaign allocation: ETB ${allocationLimit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSec,
                            ),
                          ),
                          TextFormField(
                            controller: allocatedCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setLocal(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Company allocation (ETB)',
                              helperText:
                                  'Set the amount available for this company in this campaign.',
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final alreadyAllocated =
                                  CampaignCustomerRepository.getByCampaign(
                                    widget.campaign.id,
                                  ).fold<double>(
                                    0,
                                    (sum, assignment) =>
                                        sum + assignment.allocatedAmount,
                                  );
                              final amount =
                                  double.tryParse(allocatedCtrl.text.trim()) ??
                                  0;
                              final remaining = allocationLimit - alreadyAllocated;
                              final invalid =
                                  amount <= 0 ||
                                  amount > remaining ||
                                  (selectedId != null &&
                                      CampaignCustomerRepository.isAssigned(
                                        widget.campaign.id,
                                        selectedId!,
                                      ));
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  invalid
                                      ? 'Enter a positive amount no greater than the unallocated campaign budget (ETB ${remaining.clamp(0, double.infinity).toStringAsFixed(2)}).'
                                      : 'Unallocated after this assignment: ETB ${(remaining - amount).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: invalid
                                        ? AppColors.danger
                                        : AppColors.success,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (selectedId != null &&
                              CampaignCustomerRepository.isAssigned(
                                widget.campaign.id,
                                selectedId!,
                              ))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Already assigned to this campaign.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(br),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppConstants.radiusLarge),
                      ),
                      border: Border(
                        top: BorderSide(color: AppTheme.divider(br)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: saving
                              ? null
                              : () async {
                                  if (selectedId == null) return;
                                  final amount = double.tryParse(
                                    allocatedCtrl.text.trim(),
                                  );
                                  final alreadyAllocated =
                                      CampaignCustomerRepository.getByCampaign(
                                        widget.campaign.id,
                                      ).fold<double>(
                                        0,
                                        (sum, assignment) =>
                                            sum + assignment.allocatedAmount,
                                      );
                                  if (amount == null ||
                                      amount <= 0 ||
                                      amount > allocationLimit -
                                          alreadyAllocated) {
                                    return;
                                  }
                                  if (CampaignCustomerRepository.isAssigned(
                                    widget.campaign.id,
                                    selectedId!,
                                  )) {
                                    Navigator.pop(dCtx);
                                    widget.snack(
                                      'Customer already assigned.',
                                      color: AppColors.warning,
                                    );
                                    return;
                                  }
                                  setLocal(() => saving = true);
                                  final assigned =
                                      await CampaignCustomerRepository.assign(
                                        CampaignCustomer(
                                          campaignId: widget.campaign.id,
                                          customerId: selectedId!,
                                          allocatedAmount: amount,
                                          assignedDate: DateTime.now(),
                                          createdAt: DateTime.now(),
                                          updatedAt: DateTime.now(),
                                        ),
                                      );
                                  if (!mounted || !dCtx.mounted) return;
                                  if (!assigned) {
                                    setLocal(() => saving = false);
                                    widget.snack(
                                      'Customer could not be assigned. Check the database connection and try again.',
                                      color: AppColors.danger,
                                    );
                                    return;
                                  }
                                  if (mounted) setState(() {});
                                  Navigator.pop(dCtx);
                                  widget.snack(
                                    'Customer assigned to campaign.',
                                  );
                                },
                          child: Text(saving ? 'Saving…' : 'Assign'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      searchCtrl.dispose();
      allocatedCtrl.dispose();
    });
  }

  Future<void> _updateStatus(
    CampaignCustomer assoc,
    String newStatus,
  ) async {
    final saved = await CampaignCustomerRepository.update(
      assoc.copyWith(participationStatus: newStatus, updatedAt: DateTime.now()),
    );
    if (!mounted) return;
    if (saved) {
      setState(() {});
      widget.snack('Status updated to $newStatus.');
    } else {
      widget.snack(
        'Status could not be saved. Check the connection and try again.',
        color: AppColors.danger,
      );
    }
  }

  Future<void> _editCompanyAllocation(CampaignCustomer assoc) async {
    final customer = CustomerRepository.findById(assoc.customerId);
    if (customer == null) return;
    final company = customer.company.trim().isEmpty
        ? customer.name.trim()
        : customer.company.trim();
    final controller = TextEditingController(
      text: assoc.allocatedAmount.toStringAsFixed(2),
    );
    final campaignBudget = BudgetRepository.allocatedForCampaign(
      assoc.campaignId,
    );
    final allocationLimit = campaignBudget > 0
        ? campaignBudget
        : widget.campaign.budget;
    final available = allocationLimit -
        CampaignCustomerRepository.getByCampaign(assoc.campaignId)
            .fold<double>(
              0,
              (sum, assignment) => sum + assignment.allocatedAmount,
            ) +
        assoc.allocatedAmount;
    final companyAllocated = CampaignCustomerRepository.allocatedForCompany(
      assoc.campaignId,
      company,
    );
    final otherCompanyAllocation = companyAllocated - assoc.allocatedAmount;
    final spent = ExpenseRepository.spentForCompany(assoc.campaignId, company);
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Company allocation — $company'),
          content: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: 'Allocated amount (ETB)',
                helperText:
                    'Maximum available for this change: ETB ${available.toStringAsFixed(2)}',
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a positive amount';
                }
                if (parsed > available) {
                  return 'Exceeds unallocated campaign funds.';
                }
                if (otherCompanyAllocation + parsed < spent) {
                  return 'Allocation cannot be below company spending.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  double.parse(controller.text.trim()),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (amount == null) return;
    final saved = await CampaignCustomerRepository.update(
      assoc.copyWith(allocatedAmount: amount, updatedAt: DateTime.now()),
    );
    if (!mounted) return;
    if (saved) {
      setState(() {});
      widget.snack('Company allocation updated.');
    } else {
      widget.snack(
        'Allocation could not be saved. Check the connection and try again.',
        color: AppColors.danger,
      );
    }
  }

  void _showCustomerProfile(Customer customer, CampaignCustomer assoc) {
    final br = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    String dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppTheme.surfaceColor(br),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          side: BorderSide(color: AppTheme.border(br)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        customer.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
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
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            customer.company.isEmpty
                                ? 'Customer profile'
                                : customer.company,
                            style: TextStyle(color: textSec, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close profile',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close, color: textSec),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.divider(br)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _CustomerProfileField(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: customer.email.isEmpty
                          ? 'Not provided'
                          : customer.email,
                    ),
                    _CustomerProfileField(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: customer.phone.isEmpty
                          ? 'Not provided'
                          : customer.phone,
                    ),
                    _CustomerProfileField(
                      icon: Icons.category_outlined,
                      label: 'Segment',
                      value: customer.segment,
                    ),
                    _CustomerProfileField(
                      icon: Icons.verified_user_outlined,
                      label: 'Customer status',
                      value: customer.status,
                    ),
                    _CustomerProfileField(
                      icon: Icons.calendar_today_outlined,
                      label: 'Customer since',
                      value: dateLabel(customer.joinedAt),
                    ),
                    _CustomerProfileField(
                      icon: Icons.history_rounded,
                      label: 'Last activity',
                      value: dateLabel(customer.lastActivity),
                    ),
                    _CustomerProfileField(
                      icon: Icons.campaign_outlined,
                      label: 'Campaign participation',
                      value: assoc.participationStatus,
                    ),
                    _CustomerProfileField(
                      icon: Icons.event_available_outlined,
                      label: 'Assigned to this campaign',
                      value: dateLabel(assoc.assignedDate),
                    ),
                    _CustomerProfileField(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Company allocation',
                      value: 'ETB ${assoc.allocatedAmount.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeCustomer(CampaignCustomer assoc, String name) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Remove from Campaign?'),
          ],
        ),
        content: Text(
          'Remove $name from this campaign? The customer record is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final removed = await CampaignCustomerRepository.remove(
                assoc.campaignId,
                assoc.customerId,
              );
              if (!mounted) return;
              if (!removed) {
                widget.snack(
                  'Customer could not be removed. Check the connection and try again.',
                  color: AppColors.danger,
                );
                return;
              }
              setState(() {});
              Navigator.pop(dCtx);
              widget.snack(
                '$name removed from this campaign.',
                color: AppColors.warning,
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final assocs = CampaignCustomerRepository.getByCampaign(widget.campaign.id);
    var filtered = assocs;
    if (_search.isNotEmpty) {
      filtered = assocs.where((a) {
        final c = CustomerRepository.findById(a.customerId);
        return c != null &&
            (c.name.toLowerCase().contains(_search.toLowerCase()) ||
                c.email.toLowerCase().contains(_search.toLowerCase()));
      }).toList();
    }
    if (_statusFilter != 'All') {
      filtered = filtered
          .where((a) => a.participationStatus == _statusFilter)
          .toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: _SectionCard(
        title: 'Campaign Customers (${assocs.length})',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Participation status filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.inputFill(br),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: AppTheme.border(br)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _statusFilter,
                  isDense: true,
                  dropdownColor: AppTheme.surfaceColor(br),
                  icon: Icon(
                    Icons.filter_list,
                    size: 14,
                    color: AppTheme.textSecondary(br),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary(br),
                  ),
                  items:
                      [
                            'All',
                            ...const [
                              'Assigned',
                              'Active',
                              'Completed',
                              'Withdrawn',
                            ],
                          ]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _statusFilter = v!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showAssignDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 14),
              label: const Text(
                'Assign Customer',
                style: TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            // Search bar
            SizedBox(
              height: 36,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(br)),
                decoration: InputDecoration(
                  hintText: 'Search customers…',
                  hintStyle: TextStyle(color: AppTheme.textSecondary(br)),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: AppTheme.textSecondary(br),
                  ),
                  filled: true,
                  fillColor: AppTheme.inputFill(br),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    borderSide: BorderSide(color: AppTheme.border(br)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    borderSide: BorderSide(color: AppTheme.border(br)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              _EmptyMsg(
                assocs.isEmpty
                    ? 'No customers assigned to this campaign.'
                    : 'No customers match the filter.',
              )
            else
              ...filtered.map((assoc) {
                final customer = CustomerRepository.findById(assoc.customerId);
                if (customer == null) return const SizedBox.shrink();
                final dateStr =
                    '${assoc.assignedDate.day}/${assoc.assignedDate.month}/${assoc.assignedDate.year}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant(br),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    border: Border.all(color: AppTheme.border(br)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _showCustomerProfile(customer, assoc),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSmall,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary(br),
                                      ),
                                    ),
                                    Text(
                                      '${customer.email}  ·  ${customer.phone}  ·  ${customer.segment}  ·  Allocated ETB ${CampaignCustomerRepository.allocatedForCompany(assoc.campaignId, customer.company.trim().isEmpty ? customer.name.trim() : customer.company.trim()).toStringAsFixed(2)}  ·  Spent ETB ${ExpenseRepository.spentForCompany(assoc.campaignId, customer.company.trim().isEmpty ? customer.name.trim() : customer.company.trim()).toStringAsFixed(2)}  ·  Assigned $dateStr',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary(br),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Icon(
                                  Icons.open_in_new_rounded,
                                  size: 15,
                                  color: AppTheme.textSecondary(br),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit company allocation',
                        onPressed: () => _editCompanyAllocation(assoc),
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      // Participation status badge + dropdown
                      PopupMenuButton<String>(
                        tooltip: 'Change status',
                        onSelected: (v) => _updateStatus(assoc, v),
                        itemBuilder: (_) =>
                            ['Assigned', 'Active', 'Completed', 'Withdrawn']
                                .map(
                                  (s) =>
                                      PopupMenuItem(value: s, child: Text(s)),
                                )
                                .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                assoc.participationStatus,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge(status: customer.status),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(
                          Icons.link_off_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        tooltip: 'Remove from campaign',
                        onPressed: () => _removeCustomer(assoc, customer.name),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CustomerProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CustomerProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary(br),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Budget (campaign-specific budgets, allocations, and expenses)
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetTab extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback onReload;
  final void Function(String msg, {Color color}) snack;
  const _BudgetTab({
    required this.campaign,
    required this.onReload,
    required this.snack,
  });
  @override
  State<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<_BudgetTab> {
  void _addExpense(Budget budget) {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    String? selectedCompany;
    String category = budget.category;
    String paymentStatus = AppConstants.paymentPending;
    DateTime expenseDate = DateTime.now();
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final br = Theme.of(ctx).brightness;
          final textPri = AppTheme.textPrimary(br);
          final textSec = AppTheme.textSecondary(br);
          final fill = AppTheme.inputFill(br);
          final border = AppTheme.border(br);
          final companyNames =
              CampaignCustomerRepository.getByCampaign(widget.campaign.id)
                  .map(CustomerRepository.findById)
                  .whereType<Customer>()
                  .map(
                    (customer) => customer.company.trim().isEmpty
                        ? customer.name.trim()
                        : customer.company.trim(),
                  )
                  .where((company) => company.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final allocated = selectedCompany == null
              ? 0.0
              : CampaignCustomerRepository.allocatedForCompany(
                  widget.campaign.id,
                  selectedCompany!,
                );
          final spent = selectedCompany == null
              ? 0.0
              : ExpenseRepository.spentForCompany(
                  widget.campaign.id,
                  selectedCompany!,
                );
          final remaining = CampaignBudgetMath.remaining(allocated, spent);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: fk,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Add Expense — ${budget.name}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(Icons.close, color: textSec, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: companyNames.contains(selectedCompany)
                            ? selectedCompany
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Company *',
                        ),
                        items: companyNames
                            .map(
                              (company) => DropdownMenuItem(
                                value: company,
                                child: Text(company),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setLocal(() {
                          selectedCompany = value;
                          amtCtrl.clear();
                        }),
                        validator: (value) => value == null
                            ? 'Assign a company and allocate a budget first.'
                            : null,
                      ),
                      if (selectedCompany != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Allocated ETB ${allocated.toStringAsFixed(2)} · '
                          'Spent ETB ${spent.toStringAsFixed(2)} · '
                          'Unallocated ETB ${remaining.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: remaining > 0 ? textSec : AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(fontSize: 13, color: textPri),
                        decoration: InputDecoration(
                          labelText: 'Expense Name *',
                          filled: true,
                          fillColor: fill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                            borderSide: BorderSide(color: border),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amtCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (_) => setLocal(() {}),
                        style: TextStyle(fontSize: 13, color: textPri),
                        decoration: InputDecoration(
                          labelText: 'Expense amount (ETB) *',
                          filled: true,
                          fillColor: fill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                            borderSide: BorderSide(color: border),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final amount = double.tryParse(v.trim());
                          if (amount == null || amount <= 0) {
                            return 'Enter a positive number';
                          }
                          if (!CampaignBudgetMath.canRecordExpense(
                            allocated: allocated,
                            alreadySpent: spent,
                            expenseAmount: amount,
                          )) {
                            return 'Expense exceeds allocation. Available: '
                                'ETB ${remaining.toStringAsFixed(2)}';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: vendorCtrl,
                        style: TextStyle(fontSize: 13, color: textPri),
                        decoration: InputDecoration(
                          labelText: 'Vendor',
                          filled: true,
                          fillColor: fill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                            borderSide: BorderSide(color: border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Record'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (!fk.currentState!.validate()) return;
                              final saved = await ExpenseRepository.add(
                                Expense(
                                  id: ExpenseRepository.nextId(),
                                  campaignId: widget.campaign.id,
                                  budgetId: budget.id,
                                  company: selectedCompany!,
                                  name: nameCtrl.text.trim(),
                                  category: category,
                                  amount: double.parse(amtCtrl.text.trim()),
                                  expenseDate: expenseDate,
                                  vendor: vendorCtrl.text.trim(),
                                  paymentStatus: paymentStatus,
                                  status: AppConstants.expensePending,
                                  recordedBy: AuthService().currentName,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              );
                              if (!ctx.mounted) return;
                              if (!saved) {
                                widget.snack(
                                  'Expense could not be saved remotely. Check your connection and permissions.',
                                  color: AppColors.danger,
                                );
                                return;
                              }
                              AuditLogService.logCreate(
                                'Campaigns',
                                widget.campaign.id,
                                '${widget.campaign.name} — Expense',
                                details: {
                                  'budget': budget.name,
                                  'amount': amtCtrl.text.trim(),
                                },
                              );
                              if (mounted) setState(() {});
                              Navigator.pop(ctx);
                              widget.snack(
                                'Expense recorded (pending approval).',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final budgets = BudgetRepository.getByCampaign(widget.campaign.id);
    final allExpenses = ExpenseRepository.getByCampaign(widget.campaign.id);
    final totalAllocated = BudgetRepository.allocatedForCampaign(
      widget.campaign.id,
    );
    final pendingAllocated = BudgetRepository.pendingAllocationForCampaign(
      widget.campaign.id,
    );
    final actualExpenses = ExpenseRepository.actualExpensesForCampaign(
      widget.campaign.id,
    );
    final approvedExpenses = ExpenseRepository.approvedExpensesForCampaign(
      widget.campaign.id,
    );
    final remaining = totalAllocated - actualExpenses;
    final utilization = totalAllocated > 0
        ? (actualExpenses / totalAllocated).clamp(0.0, 1.0)
        : 0.0;
    final barC = utilization > 0.9
        ? AppColors.danger
        : utilization > 0.7
        ? AppColors.warning
        : AppColors.success;
    final canApprove =
        AuthService().currentRole == 'admin' ||
        AuthService().currentRole == 'marketing_manager';

    String numFmt(double v) => v >= 1000
        ? 'ETB ${(v / 1000).toStringAsFixed(1)}K'
        : 'ETB ${v.toStringAsFixed(0)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Column(
        children: [
          // ── Budget summary card ──
          _SectionCard(
            title: 'Budget Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BudgetStat(
                  'Total Allocated',
                  numFmt(totalAllocated),
                  AppTheme.textPrimary(br),
                ),
                const SizedBox(height: 6),
                _BudgetStat(
                  'Pending Allocations',
                  numFmt(pendingAllocated),
                  AppColors.warning,
                ),
                const SizedBox(height: 6),
                _BudgetStat(
                  'Actual Expenses',
                  numFmt(actualExpenses),
                  AppColors.danger,
                ),
                const SizedBox(height: 6),
                _BudgetStat(
                  'Approved Expenses',
                  numFmt(approvedExpenses),
                  AppColors.info,
                ),
                const SizedBox(height: 6),
                _BudgetStat(
                  'Remaining',
                  numFmt(remaining.clamp(0, double.infinity)),
                  AppColors.success,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Utilization',
                      style: TextStyle(
                        color: AppTheme.textSecondary(br),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(utilization * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: barC,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: utilization,
                    minHeight: 8,
                    backgroundColor: AppTheme.border(br),
                    valueColor: AlwaysStoppedAnimation<Color>(barC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.itemSpacing),

          // ── Budget allocations ──
          _SectionCard(
            title: 'Budget Allocations (${budgets.length})',
            action: budgets.isEmpty
                ? null
                : Text(
                    '${budgets.length} allocations',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(br),
                    ),
                  ),
            child: budgets.isEmpty
                ? _EmptyMsg(
                    'No budgets are allocated to this campaign yet.\nCreate a budget and assign it to this campaign.',
                  )
                : Column(
                    children: budgets.map((b) {
                      final bExpenses = ExpenseRepository.getByBudget(b.id);
                      final bSpent = bExpenses.fold(
                        0.0,
                        (s, e) => s + e.amount,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(br),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                          border: Border.all(color: AppTheme.border(br)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary(br),
                                        ),
                                      ),
                                      Text(
                                        b.category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary(br),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: b.utilizationColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    b.utilizationStatus,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: b.utilizationColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  onPressed: () => _addExpense(b),
                                  icon: const Icon(Icons.add, size: 12),
                                  label: const Text(
                                    'Expense',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _BudgetStat(
                                    'Allocated',
                                    numFmt(b.allocated),
                                    AppTheme.textPrimary(br),
                                  ),
                                ),
                                Expanded(
                                  child: _BudgetStat(
                                    'Spent',
                                    numFmt(bSpent),
                                    AppColors.danger,
                                  ),
                                ),
                                Expanded(
                                  child: _BudgetStat(
                                    'Remaining',
                                    numFmt(
                                      (b.allocated - bSpent).clamp(
                                        0,
                                        double.infinity,
                                      ),
                                    ),
                                    AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: AppConstants.itemSpacing),

          // ── Expense history ──
          _SectionCard(
            title: 'Expense History (${allExpenses.length})',
            child: allExpenses.isEmpty
                ? _EmptyMsg('No expenses recorded for this campaign.')
                : Column(
                    children: allExpenses.map((e) {
                      final budgetName = e.budgetId != null
                          ? (BudgetRepository.findById(e.budgetId!)?.name ??
                                e.budgetId!)
                          : '—';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(br),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                          border: Border.all(color: AppTheme.border(br)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary(br),
                                    ),
                                  ),
                                  Text(
                                    '${e.expenseDate.day}/${e.expenseDate.month}/${e.expenseDate.year}  ·  $budgetName  ·  ${e.recordedBy.isNotEmpty ? e.recordedBy : "—"}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary(br),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'ETB ${e.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary(br),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: e.statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                e.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: e.statusColor,
                                ),
                              ),
                            ),
                            if (canApprove &&
                                e.status == AppConstants.expensePending) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                tooltip: 'Approve',
                                onPressed: () async {
                                  final saved = await ExpenseRepository.approve(
                                    e.id,
                                    AuthService().currentName,
                                  );
                                  if (!mounted) return;
                                  if (!saved) {
                                    widget.snack(
                                      'Expense approval could not be saved remotely.',
                                      color: AppColors.danger,
                                    );
                                    return;
                                  }
                                  setState(() {});
                                  widget.snack('Expense approved.');
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                                tooltip: 'Reject',
                                onPressed: () async {
                                  final saved = await ExpenseRepository.reject(
                                    e.id,
                                    AuthService().currentName,
                                  );
                                  if (!mounted) return;
                                  if (!saved) {
                                    widget.snack(
                                      'Expense rejection could not be saved remotely.',
                                      color: AppColors.danger,
                                    );
                                    return;
                                  }
                                  setState(() {});
                                  widget.snack(
                                    'Expense rejected.',
                                    color: AppColors.warning,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Content
// ─────────────────────────────────────────────────────────────────────────────

class _ContentTab extends StatelessWidget {
  final Campaign campaign;
  const _ContentTab({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final items = ContentRepository.getAll()
        .where((ci) => ci.campaignName == campaign.name)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: _SectionCard(
        title: 'Campaign Content (${items.length})',
        child: items.isEmpty
            ? _EmptyMsg('No content is linked to this campaign yet.')
            : Column(
                children: items.map((ci) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(br),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      border: Border.all(color: AppTheme.border(br)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ci.typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            ci.typeIcon,
                            color: ci.typeColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ci.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(br),
                                ),
                              ),
                              Text(
                                '${ci.type}  ·  ${ci.channel}  ·  by ${ci.creator}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(br),
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(status: ci.status),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Promotions
// ─────────────────────────────────────────────────────────────────────────────

class _PromotionsTab extends StatelessWidget {
  final Campaign campaign;
  const _PromotionsTab({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final promos = PromotionRepository.getAll()
        .where((p) => p.campaignName == campaign.name)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: _SectionCard(
        title: 'Campaign Promotions (${promos.length})',
        child: promos.isEmpty
            ? _EmptyMsg('No promotions are linked to this campaign.')
            : Column(
                children: promos.map((p) {
                  final usagePct = p.usageLimit > 0
                      ? p.usedCount / p.usageLimit
                      : 0.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant(br),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      border: Border.all(color: AppTheme.border(br)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.local_offer_outlined,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(br),
                                ),
                              ),
                            ),
                            StatusBadge(status: p.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${p.type}  ·  ${p.discount}  ·  '
                          '${p.startDate.day}/${p.startDate.month} – ${p.endDate.day}/${p.endDate.month}/${p.endDate.year}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary(br),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: usagePct,
                                  minHeight: 6,
                                  backgroundColor: AppTheme.border(br),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    usagePct > 0.9
                                        ? AppColors.danger
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${p.usedCount}/${p.usageLimit}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary(br),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Activities
// ─────────────────────────────────────────────────────────────────────────────

class _ActivitiesTab extends StatelessWidget {
  final Campaign campaign;
  const _ActivitiesTab({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: _SectionCard(
        title: 'Activity Timeline',
        child: campaign.activities.isEmpty
            ? _EmptyMsg('No activities recorded for this campaign.')
            : Column(
                children: campaign.activities.asMap().entries.map((e) {
                  final a = e.value;
                  final isLast = e.key == campaign.activities.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: a.iconColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  a.icon,
                                  size: 14,
                                  color: a.iconColor,
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    color: AppTheme.divider(br),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary(br),
                                  ),
                                ),
                                Text(
                                  a.date,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary(br),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI row
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final Campaign campaign;
  const _KpiRow({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _KD(
        'Impressions',
        _f(campaign.impressions),
        Icons.visibility_outlined,
        AppColors.primary,
      ),
      _KD(
        'Leads',
        '${campaign.leads}',
        Icons.person_search_outlined,
        AppColors.info,
      ),
      _KD(
        'Conversions',
        '${campaign.conversions}',
        Icons.check_circle_outline,
        AppColors.success,
      ),
      _KD(
        'ROI',
        '${campaign.roi}×',
        Icons.trending_up_outlined,
        AppColors.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (_, cst) {
        final cols = cst.maxWidth >= 700 ? 4 : 2;
        final itemW =
            (cst.maxWidth - (cols - 1) * AppConstants.itemSpacing) / cols;
        return Wrap(
          spacing: AppConstants.itemSpacing,
          runSpacing: AppConstants.itemSpacing,
          children: stats
              .map(
                (s) => SizedBox(
                  width: itemW,
                  child: _KpiCard(data: s),
                ),
              )
              .toList(),
        );
      },
    );
  }

  String _f(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : '$v';
}

class _KD {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KD(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KD data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  color: AppTheme.textPrimary(br),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                data.label,
                style: TextStyle(
                  color: AppTheme.textSecondary(br),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(br),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(br)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // ignore: use_null_aware_elements
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppTheme.divider(br)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary(br),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _BudgetStat(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary(br), fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyMsg extends StatelessWidget {
  final String message;
  const _EmptyMsg(this.message);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: AppTheme.textSecondary(
              Theme.of(context).brightness,
            ).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary(Theme.of(context).brightness),
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}
