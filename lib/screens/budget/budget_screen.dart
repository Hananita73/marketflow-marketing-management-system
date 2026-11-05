import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/supabase_config.dart';
import '../../services/access_service.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/budget.dart';
import '../../models/budget_request.dart';
import '../../models/campaign.dart';
import '../../models/campaign_customer.dart';
import '../../models/customer.dart';
import '../../models/expense.dart';
import '../../models/notification_model.dart';
import '../../services/approval_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../widgets/common/approval_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data source: BudgetRepository (Supabase-backed). The former local
// Budget model and seed list moved into lib/models/budget.dart.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// BudgetScreen
// ─────────────────────────────────────────────────────────────────────────────

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  /// Working copy of the repository data, refreshed after every mutation so
  /// setState picks up changes made through [BudgetRepository].
  List<Budget> _budgets = List.from(BudgetRepository.getAll());
  List<BudgetRequest> _requests = List.from(BudgetRequestRepository.getAll());

  void _reload() {
    _budgets = List.from(BudgetRepository.getAll());
    _requests = List.from(BudgetRequestRepository.getAll());
  }

  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _statusFilter = 'All';
  String _campaignFilter = 'All';
  String _selectedPeriod = 'This Year';
  int _currentPage = 1;
  static const int _pageSize = 6;

  static String _campaignName(String? id) =>
      (id == null || id.isEmpty) ? '' : (CampaignRepository.findById(id)?.name ?? id);

  static const List<String> _categories = [
    'All', 'Advertising', 'Content', 'Influencer Marketing', 'Events', 'Email/SMS', 'Other',
  ];
  static const List<String> _statusOptions = [
    'All', 'Active', 'Paused', 'Completed', 'Draft',
  ];
  static const List<String> _periods = [
    'This Month', 'Last Month', 'This Quarter', 'This Year', 'Custom Range',
  ];

  // Permission checks for budget module
  bool _canManageBudgets() {
    return AuthService().isAdmin ||
        AccessService.canCreate('Budget') ||
        AccessService.canEdit('Budget');
  }

  bool _canViewBudgets() {
    final auth = AuthService();
    if (auth.currentProfile == null) return true;
    final role = auth.currentRole;
    if (role == AppConstants.dbRoleAdmin)            return true;
    if (role == AppConstants.dbRoleMarketingManager) return true;
    if (role == AppConstants.dbRoleMarketingClerk)   return true;
    if (role == AppConstants.dbRoleViewer)           return true; // viewers can see budgets per spec
    return false;
  }

  List<Budget> get _filtered => _budgets.where((b) {
    final q = _searchQuery.toLowerCase();
    final matchQ = q.isEmpty || b.name.toLowerCase().contains(q) ||
        b.category.toLowerCase().contains(q) || b.description.toLowerCase().contains(q);
    final matchC = _categoryFilter == 'All' || b.category == _categoryFilter;
    final matchS = _statusFilter == 'All' || b.status == _statusFilter;
    final matchCamp = _campaignFilter == 'All' || b.campaignId == _campaignFilter;
    return matchQ && matchC && matchS && matchCamp;
  }).toList();

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Budget Request workflow ───────────────────────────────────────────────

  List<BudgetRequest> get _pendingRequests =>
      _requests.where((r) => r.status == 'Pending').toList();

  bool get _canApproveBudgetRequests {
    return AuthService().isAdmin || AccessService.canApprove('Budget');
  }

  void _openRequestForm({Budget? linkedBudget}) {
    final amtCtrl  = TextEditingController();
    final descCtrl = TextEditingController();
    String category = linkedBudget?.category ?? 'Advertising';
    String? budgetId = linkedBudget?.id;
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final br      = Theme.of(ctx).brightness;
        final textPri = AppTheme.textPrimary(br);
        final textSec = AppTheme.textSecondary(br);
        final fill    = AppTheme.inputFill(br);
        final border  = AppTheme.border(br);

        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: fk,
                child: Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      child: const Icon(Icons.request_page_outlined,
                          color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('Budget Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close, color: textSec, size: 20)),
                  ]),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 14),

                  // Budget link
                  if (_budgets.isNotEmpty) ...[
                    Text('Link to Budget', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: fill,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: budgetId,
                          isExpanded: true, isDense: true,
                          dropdownColor: AppTheme.surfaceColor(br),
                          hint: Text('Select budget (optional)',
                              style: TextStyle(fontSize: 13, color: textSec)),
                          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
                          style: TextStyle(fontSize: 13, color: textPri),
                          items: [
                            DropdownMenuItem<String>(value: null,
                                child: Text('None', style: TextStyle(fontSize: 13, color: textSec))),
                            ..._budgets.map((b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(b.name, style: TextStyle(fontSize: 13, color: textPri),
                                    overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (v) => setLocal(() {
                            budgetId = v;
                            if (v != null) {
                              final b = BudgetRepository.findById(v);
                              if (b != null) category = b.category;
                            }
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Amount
                  Text('Requested Amount (ETB) *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 13, color: textPri),
                    decoration: InputDecoration(
                      hintText: 'e.g. 50000',
                      hintStyle: TextStyle(color: textSec),
                      filled: true, fillColor: fill,
                      prefixIcon: const Icon(Icons.attach_money_rounded, size: 18, color: AppColors.warning),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) return 'Must be a number';
                      if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Description
                  Text('Purpose / Description *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: TextStyle(fontSize: 13, color: textPri),
                    decoration: InputDecoration(
                      hintText: 'Describe what the budget will be used for…',
                      hintStyle: TextStyle(color: textSec),
                      filled: true, fillColor: fill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (!fk.currentState!.validate()) return;
                        final req = BudgetRequest(
                          id: BudgetRequestRepository.nextId(),
                          budgetId: budgetId,
                          campaignId: null,
                          requestedBy: AuthService().currentName,
                          requestedAmount: double.parse(amtCtrl.text.trim()),
                          category: category,
                          description: descCtrl.text.trim(),
                          status: 'Pending',
                          reviewedBy: '',
                          reviewComments: '',
                          createdAt: DateTime.now(),
                        );
                        final saved = await BudgetRequestRepository.add(req);
                        if (!ctx.mounted) return;
                        if (!saved) {
                          _showSnack(
                            'Budget request could not be saved remotely. Check your connection and permissions.',
                            error: true,
                          );
                          return;
                        }
                        AuditLogService.logSubmit('Budget', req.id, 'Budget Request ${req.id}',
                            details: {'amount': req.requestedAmount});
                        NotificationRepository.add(
                          title: 'Budget Request Submitted',
                          message: 'Request for ETB ${req.requestedAmount.toStringAsFixed(0)} is pending approval.',
                          category: NotificationCategory.budget,
                        );
                        setState(_reload);
                        Navigator.pop(ctx);
                        _showSnack(
                          SupabaseConfig.isConfigured
                              ? 'Budget request submitted for approval.'
                              : 'Budget request saved locally (remote database is not configured).',
                        );
                      },
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Submit Request'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _approveRequest(BudgetRequest req) async {
    final ok = await ApprovalService.approveBudgetRequest(context, req.id);
    if (ok) setState(_reload);
  }

  Future<void> _rejectRequest(BudgetRequest req) async {
    final ok = await ApprovalService.rejectBudgetRequest(context, req.id);
    if (ok) setState(_reload);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void _openForm({Budget? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final allocatedCtrl = TextEditingController(
        text: existing != null ? existing.allocated.toStringAsFixed(0) : '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String category = existing?.category ?? 'Advertising';
    String status = existing?.status ?? AppConstants.statusActive;
    String? campaignId = existing?.campaignId;
    final allCampaigns = CampaignRepository.getAll();
    DateTime startDate = existing?.startDate ?? DateTime(2026, 1, 1);
    DateTime endDate = existing?.endDate ?? DateTime(2026, 12, 31);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final brightness = Theme.of(ctx).brightness;
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: AppTheme.primaryLighter(brightness),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
                        child: Icon(
                            isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(isEdit ? 'Edit Budget' : 'Add Budget',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(brightness))),
                    ]),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    _formLabel('Budget Name *', brightness),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: _inputDec('e.g. Digital Advertising Q3', brightness),
                      style: _inputStyle(brightness),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    // Campaign assignment (required for new budgets)
                    _formLabel(isEdit ? 'Campaign' : 'Assign to Campaign *', brightness),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.inputFill(brightness),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        border: Border.all(color: AppTheme.border(brightness)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: campaignId, isExpanded: true, isDense: true,
                          dropdownColor: AppTheme.surfaceColor(brightness),
                          hint: Text('Select a campaign', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness))),
                          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.textSecondary(brightness)),
                          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
                          items: [
                            if (isEdit) DropdownMenuItem<String?>(value: null, child: Text('— Unassigned —', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness)))),
                            ...allCampaigns.map((c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text('${c.name} (${c.status})', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)), overflow: TextOverflow.ellipsis),
                            )),
                          ],
                          onChanged: (v) => setLocal(() => campaignId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (_, bc) {
                      final narrow = bc.maxWidth < 420;
                      final categoryField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _formLabel('Category', brightness),
                          const SizedBox(height: 6),
                          _DropdownInput(value: category,
                              items: _categories.where((c) => c != 'All').toList(),
                              onChanged: (v) => setLocal(() => category = v)),
                        ],
                      );
                      final statusField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _formLabel('Status', brightness),
                          const SizedBox(height: 6),
                          _DropdownInput(value: status,
                              items: _statusOptions.where((s) => s != 'All').toList(),
                              onChanged: (v) => setLocal(() => status = v)),
                        ],
                      );
                      if (narrow) {
                        return Column(children: [categoryField, const SizedBox(height: 14), statusField]);
                      }
                      return Row(children: [
                        Expanded(child: categoryField), const SizedBox(width: 12), Expanded(child: statusField),
                      ]);
                    }),
                    const SizedBox(height: 14),
                    _formLabel('Allocated Amount (ETB) *', brightness),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: allocatedCtrl,
                      decoration: _inputDec('e.g. 250000', brightness),
                      style: _inputStyle(brightness),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (_, bc) {
                      final narrow = bc.maxWidth < 420;
                      Future<void> pickDate(bool isStart) async {
                        final picked = await showDatePicker(
                          context: ctx, initialDate: isStart ? startDate : endDate,
                          firstDate: DateTime(2025), lastDate: DateTime(2030),
                        );
                        if (picked != null) setLocal(() { if (isStart) { startDate = picked; } else { endDate = picked; } });
                      }
                      final startField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _formLabel('Start Date', brightness), const SizedBox(height: 6),
                        _DatePickerButton(date: startDate, onTap: () => pickDate(true)),
                      ]);
                      final endField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _formLabel('End Date', brightness), const SizedBox(height: 6),
                        _DatePickerButton(date: endDate, onTap: () => pickDate(false)),
                      ]);
                      if (narrow) return Column(children: [startField, const SizedBox(height: 14), endField]);
                      return Row(children: [Expanded(child: startField), const SizedBox(width: 12), Expanded(child: endField)]);
                    }),
                    const SizedBox(height: 14),
                    _formLabel('Description', brightness),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: descCtrl,
                      decoration: _inputDec('Brief description of this budget…', brightness),
                      style: _inputStyle(brightness),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        onPressed: () async {
                          // Only admins and marketing managers can add budgets
                          if (!_canManageBudgets()) {
                            _showSnack('You do not have permission to add budgets', error: true);
                            return;
                          }
                          if (!formKey.currentState!.validate()) return;
                          if (!isEdit && (campaignId == null || campaignId!.isEmpty)) {
                            _showSnack('Please assign the budget to a campaign', error: true);
                            return;
                          }
                          final item = Budget(
                            id: isEdit ? existing.id : BudgetRepository.nextId(),
                            name: nameCtrl.text.trim(), category: category,
                            allocated: double.parse(allocatedCtrl.text.trim()),
                            spent: isEdit ? existing.spent : 0,
                            startDate: startDate, endDate: endDate,
                            description: descCtrl.text.trim(), status: status,
                            lastUpdated: DateTime.now(),
                            campaignId: campaignId,
                          );
                          // Re-link expenses before moving the budget allocation.
                          if (isEdit && existing.campaignId != campaignId) {
                            final newCampId = campaignId ?? '';
                            for (final e in ExpenseRepository.getByBudget(existing.id)) {
                              if (newCampId.isNotEmpty) {
                                final savedExpense = await ExpenseRepository.update(Expense(
                                  id: e.id, campaignId: newCampId, budgetId: e.budgetId,
                                  company: e.company,
                                  name: e.name, description: e.description, category: e.category,
                                  amount: e.amount, expenseDate: e.expenseDate, vendor: e.vendor,
                                  paymentStatus: e.paymentStatus, status: e.status,
                                  recordedBy: e.recordedBy, createdAt: e.createdAt, updatedAt: DateTime.now(),
                                ));
                                if (!savedExpense) {
                                  if (ctx.mounted) {
                                    _showSnack(
                                      'The budget could not be reassigned because one or more expenses failed validation or persistence.',
                                      error: true,
                                    );
                                  }
                                  return;
                                }
                              }
                            }
                          }
                          final saved = isEdit
                              ? await BudgetRepository.update(item)
                              : await BudgetRepository.add(item);
                          if (!ctx.mounted) return;
                          if (!saved) {
                            _showSnack(
                              'Budget could not be saved remotely. Check your connection and permissions.',
                              error: true,
                            );
                            return;
                          }
                          setState(() {
                            _reload();
                          });
                          Navigator.pop(ctx);
                          _showSnack(
                            '${isEdit ? 'Budget updated' : 'Budget added'}${SupabaseConfig.isConfigured ? '.' : ' locally; remote database is not configured.'}',
                          );
                        },
                        child: Text(isEdit ? 'Save Changes' : 'Add Budget'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _confirmDelete(Budget b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLarge)),
        title: const Text('Delete Budget', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        content: Text('Delete "${b.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              if (!AccessService.requireDelete(context, 'Budget')) return;
              final deleted = await BudgetRepository.remove(b.id);
              if (!ctx.mounted) return;
              if (!deleted) {
                _showSnack(
                  'Budget could not be deleted remotely. Check your connection and permissions.',
                  error: true,
                );
                return;
              }
              setState(_reload);
              Navigator.pop(ctx);
              _showSnack('Budget deleted.');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Expense workflow per budget allocation ───────────────────────────────
  void _openExpenseDialog(Budget budget) {
    // Expenses must belong to a campaign; an unassigned budget cannot record
    // expenses until it is linked to a campaign.
    if (budget.campaignId == null || budget.campaignId!.isEmpty) {
      _showSnack('Assign this budget to a campaign before recording expenses.', error: true);
      return;
    }
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = budget.category;
    String? selectedCompany;
    String paymentStatus = AppConstants.paymentPending;
    DateTime expenseDate = DateTime.now();
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final br = Theme.of(ctx).brightness;
        final textPri = AppTheme.textPrimary(br);
        final textSec = AppTheme.textSecondary(br);
        final fill = AppTheme.inputFill(br);
        final border = AppTheme.border(br);
        final expenses = ExpenseRepository.getByBudget(budget.id);
        final companyNames =
            CampaignCustomerRepository.getByCampaign(budget.campaignId!)
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
        final companyAllocated = selectedCompany == null
            ? 0.0
            : CampaignCustomerRepository.allocatedForCompany(
                budget.campaignId!,
                selectedCompany!,
              );
        final companySpent = selectedCompany == null
            ? 0.0
            : ExpenseRepository.spentForCompany(
                budget.campaignId!,
                selectedCompany!,
              );
        final companyRemaining = CampaignBudgetMath.remaining(
          companyAllocated,
          companySpent,
        );

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: fk,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
                      child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Expenses — ${budget.name}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri)),
                      Text('Campaign: ${_campaignName(budget.campaignId)}', style: TextStyle(fontSize: 12, color: textSec)),
                    ])),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close, color: textSec, size: 20)),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Existing expenses for this allocation
                  if (expenses.isEmpty)
                    Text('No expenses recorded for this allocation yet.', style: TextStyle(fontSize: 12, color: textSec))
                  else ...[
                    Text('Recorded Expenses (${expenses.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                    const SizedBox(height: 8),
                    ...expenses.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.surfaceVariant(br),
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          border: Border.all(color: border)),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPri)),
                          Text('ETB ${e.amount.toStringAsFixed(2)}  ·  ${e.expenseDate.day}/${e.expenseDate.month}/${e.expenseDate.year}  ·  ${e.paymentStatus}',
                              style: TextStyle(fontSize: 11, color: textSec)),
                        ])),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: e.statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Text(e.status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: e.statusColor))),
                      ]),
                    )),
                    const SizedBox(height: 12),
                  ],
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('Add Expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPri)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: companyNames.contains(selectedCompany)
                        ? selectedCompany
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Company *',
                      filled: true,
                      fillColor: fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMedium,
                        ),
                        borderSide: BorderSide(color: border),
                      ),
                    ),
                    items: companyNames
                        .map(
                          (companyName) => DropdownMenuItem(
                            value: companyName,
                            child: Text(companyName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocal(() {
                      selectedCompany = value;
                      amtCtrl.clear();
                    }),
                    validator: (value) => value == null
                        ? 'Assign a company to the campaign and allocate a budget first.'
                        : null,
                  ),
                  if (selectedCompany != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Allocated ETB ${companyAllocated.toStringAsFixed(2)}  ·  '
                      'Spent ETB ${companySpent.toStringAsFixed(2)}  ·  '
                      'Unallocated ETB ${companyRemaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: companyRemaining > 0
                            ? textSec
                            : AppColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    style: TextStyle(fontSize: 13, color: textPri),
                    decoration: InputDecoration(labelText: 'Expense Name *', filled: true, fillColor: fill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border))),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(fontSize: 13, color: textPri),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => setLocal(() {}),
                      decoration: InputDecoration(labelText: 'Expense amount (ETB) *', filled: true, fillColor: fill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border))),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final amount = double.tryParse(v.trim());
                        if (amount == null || amount <= 0) {
                          return 'Enter a positive number';
                        }
                        if (!CampaignBudgetMath.canRecordExpense(
                          allocated: companyAllocated,
                          alreadySpent: companySpent,
                          expenseAmount: amount,
                        )) {
                          return 'Spent amount exceeds the company allocation. '
                              'Available: ETB ${companyRemaining.toStringAsFixed(2)}';
                        }
                        return null;
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ExpenseDropdown(label: 'Category', value: category, items: AppConstants.expenseCategories, fillColor: fill, borderColor: border, textColor: textPri, secColor: textSec, onChanged: (v) => setLocal(() => category = v))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: vendorCtrl, style: TextStyle(fontSize: 13, color: textPri),
                    decoration: InputDecoration(labelText: 'Vendor', filled: true, fillColor: fill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium), borderSide: BorderSide(color: border))),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _ExpenseDropdown(label: 'Payment Status', value: paymentStatus, items: const ['Pending','Paid','Partial'], fillColor: fill, borderColor: border, textColor: textPri, secColor: textSec, onChanged: (v) => setLocal(() => paymentStatus = v))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPri)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: expenseDate, firstDate: DateTime(2025), lastDate: DateTime(2030));
                        if (picked != null) setLocal(() => expenseDate = picked);
                      }, icon: const Icon(Icons.calendar_today_outlined, size: 14), label: Text('${expenseDate.day}/${expenseDate.month}/${expenseDate.year}', style: const TextStyle(fontSize: 12))),
                    ])),
                  ]),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16), label: const Text('Record Expense'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      onPressed: () async {
                        if (!fk.currentState!.validate()) return;
                        final amount = double.parse(amtCtrl.text.trim());
                        final saved = await ExpenseRepository.add(Expense(
                          id: ExpenseRepository.nextId(),
                          campaignId: budget.campaignId!,
                          budgetId: budget.id,
                          company: selectedCompany!,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          category: category,
                          amount: amount,
                          expenseDate: expenseDate,
                          vendor: vendorCtrl.text.trim(),
                          paymentStatus: paymentStatus,
                          status: AppConstants.expensePending,
                          recordedBy: AuthService().currentName,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ));
                        if (!ctx.mounted) return;
                        if (!saved) {
                          _showSnack(
                            'Expense could not be saved remotely. Check your connection and permissions.',
                            error: true,
                          );
                          return;
                        }
                        setLocal(() {
                          nameCtrl.clear(); amtCtrl.clear(); vendorCtrl.clear();
                        });
                        _showSnack(
                          SupabaseConfig.isConfigured
                              ? 'Expense saved (pending approval).'
                              : 'Expense saved locally (remote database is not configured).',
                        );
                      },
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Viewers have no budget permission — show an access panel instead of
    // leaking the numbers (permission was previously computed but never used).
    if (!_canViewBudgets()) return _NoAccessPanel(brightness: brightness);

    final filtered = _filtered;
    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final page = _currentPage.clamp(1, pageCount);
    final pageItems = filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Plain sticky header (no SliverPersistentHeader) ───────────────
        _BudgetHeaderSurface(
          brightness: brightness,
          selectedPeriod: _selectedPeriod,
          onPeriodChanged: (p) => setState(() => _selectedPeriod = p),
          onAddBudget: () => _openForm(),
          onExport: () => ExportService.export(
              context, module: 'Budget', format: ExportFormat.csv),
          onRequestBudget: () => _openRequestForm(),
          periods: _periods,
        ),

        // ── Scrollable content ────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.sectionSpacing,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompanyAllocationSection(
                  campaigns: CampaignRepository.getAll(),
                  assignments: CampaignCustomerRepository.getAll(),
                  expenses: ExpenseRepository.getAll(),
                  campaignFilter: _campaignFilter,
                ),
                const SizedBox(height: AppConstants.sectionSpacing),
                // ── Budget Requests Approval Panel (managers/admins only)
                if (_canApproveBudgetRequests && _pendingRequests.isNotEmpty) ...[
                  ApprovalPanel<BudgetRequest>(
                    title: 'Budget Requests',
                    subtitle: 'Pending approval from Marketing Clerks',
                    icon: Icons.request_page_outlined,
                    items: _pendingRequests,
                    itemBuilder: (ctx, req) => _BudgetRequestTile(
                      request: req,
                      onApprove: () => _approveRequest(req),
                      onReject: () => _rejectRequest(req),
                    ),
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),
                ],
                _BudgetTableSection(
                  items: pageItems, allFiltered: filtered,
                  searchQuery: _searchQuery, categoryFilter: _categoryFilter, statusFilter: _statusFilter,
                  campaignFilter: _campaignFilter, campaigns: CampaignRepository.getAll(),
                  currentPage: page, pageCount: pageCount,
                  categories: _categories, statusOptions: _statusOptions,
                  onSearchChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
                  onCategoryChanged: (v) => setState(() { _categoryFilter = v; _currentPage = 1; }),
                  onStatusChanged: (v) => setState(() { _statusFilter = v; _currentPage = 1; }),
                  onCampaignChanged: (v) => setState(() { _campaignFilter = v; _currentPage = 1; }),
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  onEdit: (b) => _openForm(existing: b),
                  onDelete: _confirmDelete,
                  onView: (b) => _openForm(existing: b),
                  onAddExpense: _openExpenseDialog,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NoAccessPanel — shown when the signed-in role may not view budgets.
// ─────────────────────────────────────────────────────────────────────────────

class _NoAccessPanel extends StatelessWidget {
  final Brightness brightness;
  const _NoAccessPanel({required this.brightness});

  @override
  Widget build(BuildContext context) {
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
            Text('No access to Budgets',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Your role does not include budget view permission.\n'
              'Contact an administrator if you need access.',
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

class _CompanyAllocationSection extends StatelessWidget {
  final List<Campaign> campaigns;
  final List<CampaignCustomer> assignments;
  final List<Expense> expenses;
  final String campaignFilter;

  const _CompanyAllocationSection({
    required this.campaigns,
    required this.assignments,
    required this.expenses,
    required this.campaignFilter,
  });

  @override
  Widget build(BuildContext context) {
    final campaignsById = {for (final campaign in campaigns) campaign.id: campaign};
    final byCompany = <String, _CompanyAllocationSummary>{};
    for (final assignment in assignments) {
      if (campaignFilter != 'All' && assignment.campaignId != campaignFilter) {
        continue;
      }
      final customer = CustomerRepository.findById(assignment.customerId);
      if (customer == null) continue;
      final company = customer.company.trim().isEmpty
          ? customer.name.trim()
          : customer.company.trim();
      if (company.isEmpty) continue;
      final summary = byCompany.putIfAbsent(
        company,
        () => _CompanyAllocationSummary(company),
      );
      summary.allocated += assignment.allocatedAmount;
      summary.campaignIds.add(assignment.campaignId);
    }

    for (final summary in byCompany.values) {
      summary.spent = expenses
          .where(
            (expense) =>
                summary.campaignIds.contains(expense.campaignId) &&
                expense.company == summary.company &&
                expense.status != AppConstants.expenseRejected,
          )
          .fold(0, (total, expense) => total + expense.amount);
    }

    final brightness = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSecondary = AppTheme.textSecondary(brightness);
    final border = AppTheme.border(brightness);
    final rows = byCompany.values.toList()
      ..sort((a, b) => a.company.compareTo(b.company));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Company allocations',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Allocated, spent, and unallocated amounts across assigned campaigns.',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'No company allocations yet. Assign customers and set an allocation from a campaign.',
              style: TextStyle(color: textSecondary, fontSize: 13),
            )
          else
            ...rows.map((row) {
              final remaining = row.allocated - row.spent;
              final campaignNames = row.campaignIds
                  .map((id) => campaignsById[id]?.name ?? id)
                  .toSet()
                  .join(', ');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.company,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            campaignNames,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _CompanyAmount(
                        label: 'Allocated',
                        amount: row.allocated,
                        color: textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _CompanyAmount(
                        label: 'Spent',
                        amount: row.spent,
                        color: textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _CompanyAmount(
                        label: 'Unallocated',
                        amount: remaining,
                        color: remaining < 0
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CompanyAllocationSummary {
  final String company;
  double allocated = 0;
  double spent = 0;
  final Set<String> campaignIds = {};

  _CompanyAllocationSummary(this.company);
}

class _CompanyAmount extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _CompanyAmount({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        label,
        style: TextStyle(
          color: AppTheme.textSecondary(Theme.of(context).brightness),
          fontSize: 10,
        ),
      ),
      Text(
        'ETB ${amount.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _BudgetHeaderSurface — replaces _BudgetHeaderDelegate + SliverPersistentHeader
// Plain StatelessWidget; no sliver geometry constraints.
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetHeaderSurface extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onAddBudget;
  final VoidCallback onExport;
  final VoidCallback onRequestBudget;
  final List<String> periods;
  final Brightness brightness;

  const _BudgetHeaderSurface({
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onAddBudget,
    required this.onExport,
    required this.onRequestBudget,
    required this.periods,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor(brightness),
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(brightness),
          border: Border(
            bottom: BorderSide(color: AppTheme.border(brightness), width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.pagePadding,
            vertical: 12,
          ),
          child: _BudgetPageHeader(
            selectedPeriod: selectedPeriod,
            onPeriodChanged: onPeriodChanged,
            onAddBudget: onAddBudget,
            onExport: onExport,
            onRequestBudget: onRequestBudget,
            periods: periods,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Header
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetPageHeader extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onAddBudget;
  final VoidCallback onExport;
  final VoidCallback onRequestBudget;
  final List<String> periods;

  const _BudgetPageHeader({
    required this.selectedPeriod, required this.onPeriodChanged,
    required this.onAddBudget, required this.onExport,
    required this.onRequestBudget, required this.periods,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 640;

      final titleBlock = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Budget',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('Monitor marketing spending, allocation, and financial performance.',
                  style: TextStyle(color: textSec, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ],
          ),
        ],
      );

      final actions = Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border(brightness)),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            color: AppTheme.surfaceColor(brightness),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedPeriod,
              dropdownColor: AppTheme.surfaceColor(brightness),
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
              icon: Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.iconColor(brightness)),
              items: periods.map((p) => DropdownMenuItem(value: p,
                  child: Text(p, style: TextStyle(color: AppTheme.textPrimary(brightness))))).toList(),
              onChanged: (v) { if (v != null) onPeriodChanged(v); },
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: onExport,
            icon: const Icon(Icons.download_outlined, size: 16), label: const Text('Export')),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onRequestBudget,
          icon: const Icon(Icons.request_page_outlined, size: 16),
          label: const Text('Request Budget'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning,
              side: const BorderSide(color: AppColors.warning)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(onPressed: onAddBudget,
            icon: const Icon(Icons.add, size: 16), label: const Text('Add Budget'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
      ]);

      if (narrow) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
          ],
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Flexible(child: titleBlock),
        const SizedBox(width: 8),
        actions,
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Cards Row
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCardsRow extends StatelessWidget {
  final double totalAllocated, totalSpent, totalRemaining;
  const _KpiCardsRow({required this.totalAllocated, required this.totalSpent, required this.totalRemaining});

  @override
  Widget build(BuildContext context) {
    final utilPct = totalAllocated > 0 ? (totalSpent / totalAllocated * 100).toStringAsFixed(1) : '0.0';
    final remPct = totalAllocated > 0 ? (totalRemaining / totalAllocated * 100).toStringAsFixed(1) : '0.0';
    final brightness = Theme.of(context).brightness;

    final cards = [
      _KpiCard(label: 'Total Budget', value: _etb(totalAllocated), subtitle: 'FY 2026 allocation',
          icon: Icons.account_balance_wallet_outlined, iconColor: AppColors.primary,
          iconBg: AppTheme.primaryLighter(brightness), badge: null),
      _KpiCard(label: 'Total Spent', value: _etb(totalSpent), subtitle: '$utilPct% of total budget used',
          icon: Icons.trending_up_outlined, iconColor: AppColors.warning,
          iconBg: AppTheme.warningBg(brightness), badge: '$utilPct%',
          badgeColor: double.parse(utilPct) >= 85 ? AppColors.danger : AppColors.warning),
      _KpiCard(label: 'Remaining', value: _etb(totalRemaining), subtitle: '$remPct% remaining',
          icon: Icons.savings_outlined, iconColor: AppColors.success,
          iconBg: AppTheme.successBg(brightness), badge: '$remPct%', badgeColor: AppColors.success),
      _KpiCard(label: 'ROI (Avg)', value: '3.8x', subtitle: '+0.4x vs last period',
          icon: Icons.auto_graph_outlined, iconColor: AppColors.info,
          iconBg: AppTheme.infoBg(brightness), badge: '+0.4x', badgeColor: AppColors.success),
    ];

    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 900 ? 4 : w >= 600 ? 2 : 1;
      final cardWidth = (w - (cols - 1) * AppConstants.itemSpacing) / cols;
      return Wrap(
        spacing: AppConstants.itemSpacing, runSpacing: AppConstants.itemSpacing,
        children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, subtitle;
  final IconData icon;
  final Color iconColor, iconBg;
  final String? badge;
  final Color? badgeColor;

  const _KpiCard({required this.label, required this.value, required this.subtitle,
      required this.icon, required this.iconColor, required this.iconBg,
      this.badge, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
              child: Icon(icon, color: iconColor, size: 18)),
          const Spacer(),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: badgeColor!.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(badge!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor)),
            ),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary(brightness))),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(brightness))),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Charts Section
// ─────────────────────────────────────────────────────────────────────────────

class _ChartsSection extends StatelessWidget {
  final List<Budget> budgets;
  const _ChartsSection({required this.budgets});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      if (w >= 1100) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: _MonthlySpendingChart()),
          const SizedBox(width: AppConstants.itemSpacing),
          Expanded(flex: 4, child: _SpendingTrendChart()),
        ]);
      }
      return Column(children: [
        _MonthlySpendingChart(),
        const SizedBox(height: AppConstants.itemSpacing),
        _SpendingTrendChart(),
      ]);
    });
  }
}

class _MonthlySpendingChart extends StatelessWidget {
  const _MonthlySpendingChart();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const List<double> _allocated = [180000.0, 195000, 210000, 220000, 245000, 250000];
  static const List<double> _spent = [145000.0, 162000, 188000, 205000, 231000, 238000];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primaryLighter(brightness),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
              child: const Icon(Icons.bar_chart_outlined, color: AppColors.primary, size: 18)),
          const SizedBox(width: 10),
          Text('Monthly Spending', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(brightness))),
          const Spacer(),
          _LegendDot(color: AppColors.primary, label: 'Allocated'),
          const SizedBox(width: 12),
          _LegendDot(color: AppColors.warning, label: 'Spent'),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 300000,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.surfaceVariant(brightness),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final month = _months[group.x];
                  final label = rodIndex == 0 ? 'Allocated' : 'Spent';
                  return BarTooltipItem('$month\n$label: ${_etb(rod.toY)}',
                      TextStyle(color: AppTheme.textPrimary(brightness), fontSize: 11));
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= _months.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(_months[i], style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))));
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52, interval: 100000,
                getTitlesWidget: (val, meta) => Text(val == 0 ? '0' : '${(val / 1000).toInt()}K',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary(brightness))),
              )),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 100000,
                getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border(brightness).withValues(alpha: 0.6), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(_months.length, (i) => BarChartGroupData(x: i, barsSpace: 4, barRods: [
              BarChartRodData(toY: _allocated[i], color: AppColors.primary.withValues(alpha: 0.35), width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
              BarChartRodData(toY: _spent[i], color: AppColors.warning, width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ])),
          )),
        ),
      ]),
    );
  }
}

class _SpendingTrendChart extends StatelessWidget {
  const _SpendingTrendChart();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const List<double> _current = [145000.0, 162000, 188000, 205000, 231000, 238000];
  static const List<double> _previous = [120000.0, 135000, 158000, 174000, 198000, 210000];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.infoBg(brightness),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
              child: const Icon(Icons.show_chart_outlined, color: AppColors.info, size: 18)),
          const SizedBox(width: 10),
          Text('Spending Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(brightness))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _LegendDot(color: AppColors.primary, label: 'This Year'),
          const SizedBox(width: 12),
          _LegendDot(color: AppTheme.textSecondary(brightness), label: 'Last Year'),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 50000,
                getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border(brightness).withValues(alpha: 0.6), strokeWidth: 1)),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: 1,
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= _months.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(_months[i], style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))));
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52, interval: 50000,
                getTitlesWidget: (val, meta) => Text(val == 0 ? '0' : '${(val / 1000).toInt()}K',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary(brightness))),
              )),
            ),
            borderData: FlBorderData(show: false),
            minX: 0, maxX: 5, minY: 0, maxY: 280000,
            lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.surfaceVariant(brightness),
              getTooltipItems: (spots) => spots.map((spot) {
                final label = spot.barIndex == 0 ? 'This Year' : 'Last Year';
                return LineTooltipItem('$label\n${_etb(spot.y)}',
                    TextStyle(color: AppTheme.textPrimary(brightness), fontSize: 11));
              }).toList(),
            )),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(_current.length, (i) => FlSpot(i.toDouble(), _current[i])),
                isCurved: true, color: AppColors.primary, barWidth: 2.5,
                dotData: FlDotData(getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 3, color: AppColors.primary, strokeWidth: 2, strokeColor: Colors.white)),
                belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.07)),
              ),
              LineChartBarData(
                spots: List.generate(_previous.length, (i) => FlSpot(i.toDouble(), _previous[i])),
                isCurved: true, color: AppTheme.textSecondary(brightness).withValues(alpha: 0.5),
                barWidth: 2, dashArray: [5, 4],
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          )),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilization Section
// ─────────────────────────────────────────────────────────────────────────────

class _UtilizationSection extends StatelessWidget {
  final List<Budget> budgets;
  const _UtilizationSection({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LayoutBuilder(builder: (_, constraints) {
      final wide = constraints.maxWidth >= 900;
      final utilWidget = Container(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        decoration: BoxDecoration(color: AppTheme.cardColor(brightness),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppTheme.border(brightness))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Budget Utilization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(brightness))),
          const SizedBox(height: 4),
          Text('Spending vs allocation per category',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness))),
          const SizedBox(height: 16),
          ...budgets.map((b) => _UtilizationRow(budget: b)),
        ]),
      );
      final donutWidget = Container(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        decoration: BoxDecoration(color: AppTheme.cardColor(brightness),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppTheme.border(brightness))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Budget Allocation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(brightness))),
          const SizedBox(height: 4),
          Text('Distribution by category',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness))),
          const SizedBox(height: 16),
          _AllocationDonut(budgets: budgets),
        ]),
      );
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: utilWidget),
          const SizedBox(width: AppConstants.itemSpacing),
          Expanded(flex: 4, child: donutWidget),
        ]);
      }
      return Column(children: [utilWidget, const SizedBox(height: AppConstants.itemSpacing), donutWidget]);
    });
  }
}

class _UtilizationRow extends StatelessWidget {
  final Budget budget;
  const _UtilizationRow({required this.budget});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(budget.name,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary(brightness)),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: budget.utilizationColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(budget.utilizationStatus,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: budget.utilizationColor)),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: budget.utilization, minHeight: 6,
                backgroundColor: AppTheme.border(brightness),
                valueColor: AlwaysStoppedAnimation<Color>(budget.utilizationColor))),
        const SizedBox(height: 4),
        Row(children: [
          Text('${_etb(budget.spent)} spent',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))),
          const Spacer(),
          Text('${(budget.utilization * 100).toStringAsFixed(0)}% of ${_etb(budget.allocated)}',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))),
        ]),
      ]),
    );
  }
}

class _AllocationDonut extends StatefulWidget {
  final List<Budget> budgets;
  const _AllocationDonut({required this.budgets});
  @override
  State<_AllocationDonut> createState() => _AllocationDonutState();
}

class _AllocationDonutState extends State<_AllocationDonut> {
  int _touchedIndex = -1;

  static const _catColors = <String, Color>{
    'Advertising': AppColors.primary,
    'Content': AppColors.info,
    'Influencer Marketing': Color(0xFFBB5CF8),
    'Events': AppColors.danger,
    'Email/SMS': AppColors.warning,
    'Other': AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final total = widget.budgets.fold<double>(0, (s, b) => s + b.allocated);
    if (total == 0) return const SizedBox(height: 160);

    final catMap = <String, double>{};
    for (final b in widget.budgets) {
      catMap[b.category] = (catMap[b.category] ?? 0) + b.allocated;
    }
    final cats = catMap.entries.toList();

    return LayoutBuilder(builder: (_, bc) {
      final chartSize = (bc.maxWidth * 0.4).clamp(100.0, 180.0);
      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: chartSize, height: chartSize,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: chartSize * 0.28,
            pieTouchData: PieTouchData(touchCallback: (event, response) {
              if (response?.touchedSection != null) {
                setState(() => _touchedIndex = response!.touchedSection!.touchedSectionIndex);
              } else { setState(() => _touchedIndex = -1); }
            }),
            sections: List.generate(cats.length, (i) {
              final isTouched = i == _touchedIndex;
              final color = _catColors[cats[i].key] ?? AppColors.chartPalette[i % 6];
              final pct = cats[i].value / total * 100;
              return PieChartSectionData(
                color: color, value: cats[i].value,
                radius: isTouched ? chartSize * 0.34 : chartSize * 0.30,
                showTitle: isTouched, title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              );
            }),
          )),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(cats.length, (i) {
              final color = _catColors[cats[i].key] ?? AppColors.chartPalette[i % 6];
              final pct = (cats[i].value / total * 100).toStringAsFixed(0);
              return Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cats[i].key,
                      style: TextStyle(fontSize: 11, color: AppTheme.textPrimary(brightness)),
                      overflow: TextOverflow.ellipsis)),
                  Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary(brightness))),
                ]),
              );
            }),
          ),
        ),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Alerts
// ─────────────────────────────────────────────────────────────────────────────

class _AlertsSection extends StatelessWidget {
  final List<Budget> budgets;
  const _AlertsSection({required this.budgets});

  List<_Alert> _buildAlerts() {
    final alerts = <_Alert>[];
    for (final b in budgets) {
      final pct = b.utilization * 100;
      if (b.spent > b.allocated) {
        alerts.add(_Alert(icon: Icons.warning_amber_rounded, color: AppColors.danger,
            text: '"${b.name}" has exceeded its allocated budget by ${_etb(b.spent - b.allocated)}.'));
      } else if (pct >= 85) {
        alerts.add(_Alert(icon: Icons.info_outline, color: AppColors.warning,
            text: '"${b.name}" is ${pct.toStringAsFixed(0)}% utilized — approaching its limit.'));
      } else if (pct < 20 && b.status == AppConstants.statusActive) {
        alerts.add(_Alert(icon: Icons.lightbulb_outline, color: AppColors.info,
            text: '"${b.name}" is underutilized at ${pct.toStringAsFixed(0)}% — consider reallocation.'));
      }
    }
    return alerts;
  }

  Color _alertBg(Color color, Brightness brightness) {
    if (color == AppColors.danger) return AppTheme.dangerBg(brightness);
    if (color == AppColors.warning) return AppTheme.warningBg(brightness);
    return AppTheme.infoBg(brightness);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final alerts = _buildAlerts();
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(color: AppTheme.cardColor(brightness),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppTheme.border(brightness))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Text('Budget Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(brightness))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.warningBg(brightness), borderRadius: BorderRadius.circular(20)),
            child: Text('${alerts.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
          ),
        ]),
        const SizedBox(height: 12),
        ...alerts.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _alertBg(a.color, brightness),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
            child: Row(children: [
              Icon(a.icon, color: a.color, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(a.text, style: TextStyle(fontSize: 13, color: a.color))),
            ]),
          ),
        )),
      ]),
    );
  }
}

class _Alert {
  final IconData icon;
  final Color color;
  final String text;
  const _Alert({required this.icon, required this.color, required this.text});
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Table Section
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetTableSection extends StatelessWidget {
  final List<Budget> items, allFiltered;
  final String searchQuery, categoryFilter, statusFilter, campaignFilter;
  final List<Campaign> campaigns;
  final int currentPage, pageCount;
  final List<String> categories, statusOptions;
  final ValueChanged<String> onSearchChanged, onCategoryChanged, onStatusChanged, onCampaignChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Budget> onEdit, onDelete, onView, onAddExpense;

  const _BudgetTableSection({
    required this.items, required this.allFiltered,
    required this.searchQuery, required this.categoryFilter, required this.statusFilter, required this.campaignFilter,
    required this.campaigns,
    required this.currentPage, required this.pageCount,
    required this.categories, required this.statusOptions,
    required this.onSearchChanged, required this.onCategoryChanged, required this.onStatusChanged,
    required this.onCampaignChanged,
    required this.onPageChanged, required this.onEdit, required this.onDelete, required this.onView,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(color: AppTheme.cardColor(brightness),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppTheme.border(brightness))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Budget Entries', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(brightness))),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, bc) {
          final narrow = bc.maxWidth < 600;
          final searchField = SizedBox(
            height: 38,
            child: TextField(
              onChanged: onSearchChanged,
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
              decoration: InputDecoration(
                hintText: 'Search budgets…',
                hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness)),
                prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.iconColor(brightness)),
                filled: true, fillColor: AppTheme.inputFill(brightness),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: BorderSide(color: AppTheme.border(brightness))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: BorderSide(color: AppTheme.border(brightness))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          );
          final catDd = _FilterDropdown(value: categoryFilter, items: categories,
              onChanged: onCategoryChanged, hint: 'Category');
          final statDd = _FilterDropdown(value: statusFilter, items: statusOptions,
              onChanged: onStatusChanged, hint: 'Status');
          final campDd = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.inputFill(brightness),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: AppTheme.border(brightness))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: campaignFilter, isDense: true,
                dropdownColor: AppTheme.surfaceColor(brightness),
                icon: Icon(Icons.campaign_outlined, size: 16, color: AppColors.primary),
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(brightness)),
                items: [
                  DropdownMenuItem(value: 'All', child: Text('All Campaigns', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(brightness)))),
                  ...campaigns.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(brightness)), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => onCampaignChanged(v!),
              ),
            ),
          );
          if (narrow) {
            return Column(children: [searchField, const SizedBox(height: 8),
              Row(children: [Expanded(child: catDd), const SizedBox(width: 8), Expanded(child: statDd)]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: campDd)]);
          }
          return Row(children: [Expanded(flex: 3, child: searchField), const SizedBox(width: 8),
            SizedBox(width: 150, child: catDd), const SizedBox(width: 8), SizedBox(width: 130, child: statDd),
            const SizedBox(width: 8), SizedBox(width: 150, child: campDd)]);
        }),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (_, bc) {
          if (bc.maxWidth < 700) {
            if (items.isEmpty) { return _EmptyState(icon: Icons.account_balance_wallet_outlined,
                message: 'No budget entries found', hint: 'Add a budget or clear your filters.'); }
            return Column(children: items.map((b) => _BudgetCard(budget: b,
                onEdit: onEdit, onDelete: onDelete, onView: onView, onAddExpense: onAddExpense)).toList());
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (items.isEmpty)
              _EmptyState(icon: Icons.account_balance_wallet_outlined,
                  message: 'No budget entries found', hint: 'Add a budget or clear your filters.')
            else
              SizedBox(width: double.infinity,
                child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 40, dataRowMinHeight: 52, dataRowMaxHeight: 72, columnSpacing: 16,
                    headingRowColor: WidgetStateProperty.all(AppTheme.tableHeaderColor(brightness)),
                    border: TableBorder(horizontalInside: BorderSide(color: AppTheme.divider(brightness), width: 1)),
                    columns: [
                      DataColumn(label: _ColHeader('Category / Name')),
                      DataColumn(label: _ColHeader('Campaign')),
                      DataColumn(label: _ColHeader('Allocated')),
                      DataColumn(label: _ColHeader('Spent')),
                      DataColumn(label: _ColHeader('Remaining')),
                      DataColumn(label: _ColHeader('Status')),
                      DataColumn(label: _ColHeader('Last Updated')),
                      DataColumn(label: _ColHeader('Actions')),
                    ],
                    rows: items.map((b) => _budgetRow(b, onEdit, onDelete, onView, onAddExpense, brightness)).toList(),
                  ),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 12),
        Row(children: [
          Text('${allFiltered.length} entries',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness))),
          const Spacer(),
          Flexible(child: SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(pageCount, (i) => i + 1).map((p) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                onTap: () => onPageChanged(p),
                child: Container(
                  width: 32, height: 32, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == currentPage ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    border: Border.all(color: p == currentPage ? AppColors.primary : AppTheme.border(brightness)),
                  ),
                  child: Text('$p', style: TextStyle(fontSize: 12,
                      color: p == currentPage ? Colors.white : AppTheme.textPrimary(brightness),
                      fontWeight: FontWeight.w500)),
                ),
              ),
            )).toList()),
          )),
        ]),
      ]),
    );
  }
}

DataRow _budgetRow(Budget b, ValueChanged<Budget> onEdit,
    ValueChanged<Budget> onDelete, ValueChanged<Budget> onView,
    ValueChanged<Budget> onAddExpense, Brightness brightness) {
  final campName = (b.campaignId == null || b.campaignId!.isEmpty)
      ? '— Unassigned —'
      : (CampaignRepository.findById(b.campaignId!)?.name ?? b.campaignId!);
  return DataRow(cells: [
    DataCell(Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(b.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary(brightness)), overflow: TextOverflow.ellipsis),
      Text(b.category, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))),
    ])),
    DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150),
        child: Text(campName, style: TextStyle(fontSize: 12,
            color: campName == '— Unassigned —' ? AppTheme.textSecondary(brightness) : AppTheme.textPrimary(brightness)),
            overflow: TextOverflow.ellipsis, maxLines: 2))),
    DataCell(Text(_etb(b.allocated), style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)))),
    DataCell(Text(_etb(_budgetSpent(b)), style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)))),
    DataCell(Text(_etb(b.allocated - _budgetSpent(b)), style: TextStyle(fontSize: 13,
        color: b.allocated < _budgetSpent(b) ? AppColors.danger : AppTheme.textPrimary(brightness)))),
    DataCell(_StatusBadge(
      status: _budgetUtilizationStatus(b),
      color: _budgetUtilizationColor(b),
    )),
    DataCell(Text('${b.lastUpdated.day}/${b.lastUpdated.month}/${b.lastUpdated.year}',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness)))),
    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
      _TableActionButton(icon: Icons.receipt_long_outlined, tooltip: 'Expenses', onTap: () => onAddExpense(b)),
      const SizedBox(width: 4),
      _TableActionButton(icon: Icons.visibility_outlined, tooltip: 'View', onTap: () => onView(b)),
      const SizedBox(width: 4),
      _TableActionButton(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: () => onEdit(b)),
      const SizedBox(width: 4),
      _TableActionButton(icon: Icons.delete_outline, tooltip: 'Delete',
          onTap: () => onDelete(b), color: AppColors.danger),
    ])),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Card (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final ValueChanged<Budget> onEdit, onDelete, onView, onAddExpense;
  const _BudgetCard({required this.budget, required this.onEdit,
      required this.onDelete, required this.onView, required this.onAddExpense});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final b = budget;
    final campName = (b.campaignId == null || b.campaignId!.isEmpty)
        ? 'Unassigned'
        : (CampaignRepository.findById(b.campaignId!)?.name ?? b.campaignId);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundFill(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(brightness)))),
          _StatusBadge(
            status: _budgetUtilizationStatus(b),
            color: _budgetUtilizationColor(b),
          ),
        ]),
        const SizedBox(height: 4),
        Text('${b.category}  ·  $campName', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))),
        const SizedBox(height: 10),
        Row(children: [
          _MiniStat('Allocated', _etb(b.allocated)),
          const SizedBox(width: 16),
          _MiniStat('Spent', _etb(_budgetSpent(b))),
          const SizedBox(width: 16),
          _MiniStat('Remaining', _etb(b.allocated - _budgetSpent(b))),
        ]),
        Row(children: [
          Text(
            _budgetUtilizationStatus(b),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _budgetUtilizationColor(b),
            ),
          ),
          const Spacer(),
          _TableActionButton(icon: Icons.receipt_long_outlined, tooltip: 'Expenses', onTap: () => onAddExpense(b)),
          const SizedBox(width: 4),
          _TableActionButton(icon: Icons.visibility_outlined, tooltip: 'View', onTap: () => onView(b)),
          const SizedBox(width: 4),
          _TableActionButton(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: () => onEdit(b)),
          const SizedBox(width: 4),
          _TableActionButton(icon: Icons.delete_outline, tooltip: 'Delete',
          onTap: () => onDelete(b), color: AppColors.danger),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary(brightness))),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary(brightness))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary(Theme.of(context).brightness)));
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

class _TableActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _TableActionButton({required this.icon, required this.tooltip,
      required this.onTap, this.color = AppColors.textSecondary});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 17, color: color)),
    ),
  );
}

Widget _formLabel(String text, Brightness brightness) => Text(text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary(brightness)));

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message, hint;
  const _EmptyState({required this.icon, required this.message, required this.hint});
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Icon(icon, size: 40, color: AppTheme.textSecondary(brightness).withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary(brightness))),
        const SizedBox(height: 4),
        Text(hint, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(brightness))),
      ]),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value, hint;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _FilterDropdown({required this.value, required this.items,
      required this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: 38,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: AppTheme.surfaceColor(brightness),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: BorderSide(color: AppTheme.border(brightness))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: BorderSide(color: AppTheme.border(brightness))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          filled: true, fillColor: AppTheme.inputFill(brightness),
        ),
        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
        icon: Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.iconColor(brightness)),
        items: items.map((i) => DropdownMenuItem(value: i,
            child: Text(i, style: TextStyle(color: AppTheme.textPrimary(brightness))))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _DropdownInput({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: AppTheme.surfaceColor(brightness),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: AppTheme.border(brightness))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: AppTheme.border(brightness))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        filled: true, fillColor: AppTheme.inputFill(brightness),
      ),
      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
      icon: Icon(Icons.keyboard_arrow_down, size: 18, color: AppTheme.iconColor(brightness)),
      items: items.map((i) => DropdownMenuItem(value: i,
          child: Text(i, style: TextStyle(color: AppTheme.textPrimary(brightness))))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickerButton({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: Container(
        height: 46, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border(brightness)),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          color: AppTheme.inputFill(brightness),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('${date.day}/${date.month}/${date.year}',
              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness))),
        ]),
      ),
    );
  }
}

TextStyle _inputStyle(Brightness brightness) =>
    TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness));

InputDecoration _inputDec(String hint, Brightness brightness) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      borderSide: BorderSide(color: AppTheme.border(brightness))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      borderSide: BorderSide(color: AppTheme.border(brightness))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  filled: true, fillColor: AppTheme.inputFill(brightness),
);

String _etb(double value) {
  if (value >= 1000000) return 'ETB ${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) {
    final formatted = value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'ETB $formatted';
  }
  return 'ETB ${value.toStringAsFixed(0)}';
}

double _budgetSpent(Budget budget) => budget.spent +
    ExpenseRepository.getByBudget(budget.id)
        .where((expense) => expense.status != AppConstants.expenseRejected)
        .fold(0, (total, expense) => total + expense.amount);

double _budgetUtilization(Budget budget) =>
    budget.allocated > 0 ? _budgetSpent(budget) / budget.allocated : 0;

String _budgetUtilizationStatus(Budget budget) {
  final utilization = _budgetUtilization(budget);
  if (utilization >= 1) return 'Over Budget';
  if (utilization >= .85) return 'Near Limit';
  return 'Healthy';
}

Color _budgetUtilizationColor(Budget budget) {
  final utilization = _budgetUtilization(budget);
  if (utilization >= 1) return AppColors.danger;
  if (utilization >= .85) return AppColors.warning;
  return AppColors.success;
}

// ─────────────────────────────────────────────────────────────────────────────
// _BudgetRequestTile — used inside ApprovalPanel for budget requests
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetRequestTile extends StatelessWidget {
  final BudgetRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BudgetRequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final br      = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.request_page_outlined,
                color: AppColors.warning, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ETB ${request.requestedAmount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri)),
            Text('Requested by ${request.requestedBy}',
                style: TextStyle(fontSize: 12, color: textSec)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Pending',
                style: TextStyle(color: AppColors.warning, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        if (request.description.isNotEmpty)
          Text(request.description,
              style: TextStyle(fontSize: 13, color: textSec, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.calendar_today_outlined, size: 12, color: textSec),
          const SizedBox(width: 4),
          Text(
            '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
            style: TextStyle(fontSize: 11, color: textSec),
          ),
          if (request.category.isNotEmpty) ...[
            const SizedBox(width: 12),
            Icon(Icons.label_outline, size: 12, color: textSec),
            const SizedBox(width: 4),
            Text(request.category, style: TextStyle(fontSize: 11, color: textSec)),
          ],
        ]),
        const SizedBox(height: 12),
        ApprovalActionRow(onApprove: onApprove, onReject: onReject),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExpenseDropdown — compact labelled dropdown used in the expense dialog.
// ─────────────────────────────────────────────────────────────────────────────
class _ExpenseDropdown extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final Color fillColor, borderColor, textColor, secColor;
  final ValueChanged<String> onChanged;
  const _ExpenseDropdown({
    required this.label, required this.value, required this.items,
    required this.fillColor, required this.borderColor,
    required this.textColor, required this.secColor, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: fillColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, isExpanded: true, isDense: true,
            dropdownColor: fillColor,
            icon: Icon(Icons.keyboard_arrow_down, size: 16, color: secColor),
            style: TextStyle(fontSize: 13, color: textColor),
            items: items.map((i) => DropdownMenuItem(
                value: i, child: Text(i, style: TextStyle(fontSize: 13, color: textColor), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    ]);
  }
}
