import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';
import '../../models/campaign_customer.dart';
import '../../models/customer.dart';
import '../../widgets/common/custom_textfield.dart';
import '../../utils/input_validators.dart';
import '../../widgets/charts/customer_growth_chart.dart';
import '../../widgets/charts/customer_segments_chart.dart';
import '../../widgets/badges/status_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomersScreen
// Uses CustomScrollView + SliverPersistentHeader for a sticky page header.
// Route must pass selfScrolling: true in AppLayoutPage.
// ─────────────────────────────────────────────────────────────────────────────

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  // ── filter / pagination state ─────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _filterSegment = 'All';
  String _filterStatus = 'All';
  String _filterCampaign = 'All';
  int _currentPage = 1;

  // ── inline form state ─────────────────────────────────────────────────────
  bool _showNewForm = false;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _formSegment = 'Retail';
  String _formStatus = AppConstants.statusActive;
  String _formCampaign =
      ''; // required campaign id for the new-customer workflow
  bool _formSaving = false;
  final GlobalKey _formPanelKey = GlobalKey();

  /// Campaign id → name (built from the live repository on demand).
  static String _campaignName(String id) =>
      CampaignRepository.findById(id)?.name ?? id;

  /// Comma-joined campaign names a customer is assigned to (via the junction).
  static String _campaignsForCustomer(int customerId) {
    final names = CampaignCustomerRepository.getByCustomer(customerId)
        .map((a) => _campaignName(a.campaignId))
        .where((n) => n.isNotEmpty)
        .toList();
    return names.isEmpty ? '—' : names.join(', ');
  }

  // ── derived list ──────────────────────────────────────────────────────────
  List<Customer> get _filtered {
    var list = CustomerRepository.getAll().toList();
    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.email.toLowerCase().contains(q) ||
                c.phone.contains(q),
          )
          .toList();
    }
    if (_filterSegment != 'All')
      list = list.where((c) => c.segment == _filterSegment).toList();
    if (_filterStatus != 'All')
      list = list.where((c) => c.status == _filterStatus).toList();
    if (_filterCampaign != 'All') {
      final ids = CampaignCustomerRepository.getByCampaign(
        _filterCampaign,
      ).map((a) => a.customerId).toSet();
      list = list.where((c) => ids.contains(c.id)).toList();
    }
    return list;
  }

  int get _totalPages =>
      (_filtered.length / AppConstants.defaultPageSize).ceil().clamp(1, 999);
  List<Customer> get _pageItems {
    final start = (_currentPage - 1) * AppConstants.defaultPageSize;
    final end = (start + AppConstants.defaultPageSize).clamp(
      0,
      _filtered.length,
    );
    if (start >= _filtered.length) return [];
    return _filtered.sublist(start, end);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── actions ───────────────────────────────────────────────────────────────
  void _focusNewForm() {
    setState(() => _showNewForm = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _formPanelKey.currentContext;
      if (ctx != null)
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
    });
  }

  void _cancelForm() {
    setState(() {
      _showNewForm = false;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _companyCtrl.clear();
      _notesCtrl.clear();
      _formSegment = 'Retail';
      _formStatus = AppConstants.statusActive;
      _formCampaign = '';
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_formCampaign.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a campaign for this customer'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!AccessService.requireCreate(context, 'Customers')) return;
    setState(() => _formSaving = true);
    final campaignId = _formCampaign;
    final campaignName = _campaignName(campaignId);
    final existing = CustomerRepository.getAll().firstWhere(
      (c) => c.email.toLowerCase() == _emailCtrl.text.trim().toLowerCase(),
      orElse: () => Customer(
        id: -1,
        name: '',
        email: '',
        phone: '',
        segment: '',
        status: '',
        lastActivity: DateTime.now(),
        joinedAt: DateTime.now(),
      ),
    );
    final reused = existing.id != -1;
    final customer = reused
        ? existing
        : Customer(
            id: CustomerRepository.nextId(),
            name: _nameCtrl.text.trim(),
            company: _companyCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            segment: _formSegment,
            status: _formStatus,
            lastActivity: DateTime.now(),
            joinedAt: DateTime.now(),
            campaignId: campaignId,
          );

    if (!reused && !await CustomerRepository.add(customer)) {
      if (mounted) {
        setState(() => _formSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Customer could not be saved. Check the database connection and try again.',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!CampaignCustomerRepository.isAssigned(campaignId, customer.id) &&
        !await CampaignCustomerRepository.assign(
          CampaignCustomer(
            campaignId: campaignId,
            customerId: customer.id,
            assignedDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        )) {
      if (mounted) {
        setState(() => _formSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Customer was saved, but campaign assignment failed. Please retry the assignment.',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _formSaving = false;
        _showNewForm = false;
      });
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _companyCtrl.clear();
      _notesCtrl.clear();
      _formSegment = 'Retail';
      _formStatus = AppConstants.statusActive;
      _formCampaign = '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reused
                ? '${customer.name} was assigned to $campaignName.'
                : 'Customer created and assigned to $campaignName.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Assign an existing customer to a campaign ─────────────────────────────
  void _showAssignDialog() {
    final allCampaigns = CampaignRepository.getAll();
    if (allCampaigns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No campaigns available. Create a campaign first.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final allCustomers = CustomerRepository.getAll();
    int? customerId;
    String? campaignId;
    final searchCtrl = TextEditingController();
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final brightness = Theme.of(ctx).brightness;
          final textPri = AppTheme.textPrimary(brightness);
          final textSec = AppTheme.textSecondary(brightness);
          final inputFill = AppTheme.inputFill(brightness);
          final borderCol = AppTheme.border(brightness);
          final dropBg = AppTheme.surfaceColor(brightness);

          List<Customer> getMatches() {
            final q = searchCtrl.text.toLowerCase();
            if (q.isEmpty) return allCustomers;
            return allCustomers
                .where(
                  (c) =>
                      c.name.toLowerCase().contains(q) ||
                      c.email.toLowerCase().contains(q),
                )
                .toList();
          }

          return Dialog(
            backgroundColor: AppTheme.surfaceColor(brightness),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              side: BorderSide(color: AppTheme.border(brightness)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Form(
                key: fk,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: brightness == Brightness.dark
                            ? const Color(0xFF2A2650)
                            : AppColors.primaryLight,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppConstants.radiusLarge),
                          topRight: Radius.circular(AppConstants.radiusLarge),
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
                              Icons.group_add_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Assign Existing Customer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
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
                            Text(
                              'Search customer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 42,
                              child: TextField(
                                controller: searchCtrl,
                                onChanged: (_) => setLocal(() {}),
                                style: TextStyle(fontSize: 13, color: textPri),
                                decoration: InputDecoration(
                                  hintText: 'Type a name or email…',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: textSec,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    size: 18,
                                    color: textSec,
                                  ),
                                  filled: true,
                                  fillColor: inputFill,
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusMedium,
                                    ),
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusMedium,
                                    ),
                                    borderSide: BorderSide(color: borderCol),
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
                            Text(
                              'Select customer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMedium,
                                ),
                                border: Border.all(color: borderCol),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: customerId,
                                  isExpanded: true,
                                  isDense: true,
                                  dropdownColor: dropBg,
                                  hint: Text(
                                    'Choose a customer',
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textPri,
                                  ),
                                  items: getMatches()
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
                                      setLocal(() => customerId = v),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Select campaign *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMedium,
                                ),
                                border: Border.all(color: borderCol),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: campaignId,
                                  isExpanded: true,
                                  isDense: true,
                                  dropdownColor: dropBg,
                                  hint: Text(
                                    'Choose a campaign',
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textPri,
                                  ),
                                  items: allCampaigns
                                      .map(
                                        (c) => DropdownMenuItem<String?>(
                                          value: c.id,
                                          child: Text(
                                            '${c.name} (${c.status})',
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
                                      setLocal(() => campaignId = v),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (customerId != null &&
                                campaignId != null &&
                                CampaignCustomerRepository.isAssigned(
                                  campaignId!,
                                  customerId!,
                                ))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'This customer is already assigned to that campaign.',
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
                        color: AppTheme.cardColor(brightness),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(AppConstants.radiusLarge),
                          bottomRight: Radius.circular(
                            AppConstants.radiusLarge,
                          ),
                        ),
                        border: Border(
                          top: BorderSide(color: AppTheme.divider(brightness)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.link_rounded, size: 16),
                            label: const Text('Confirm Assignment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (customerId == null || campaignId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Select both a customer and a campaign',
                                    ),
                                    backgroundColor: AppColors.warning,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              if (CampaignCustomerRepository.isAssigned(
                                campaignId!,
                                customerId!,
                              )) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${CustomerRepository.findById(customerId!)?.name ?? "Customer"} is already assigned to ${_campaignName(campaignId!)}.',
                                    ),
                                    backgroundColor: AppColors.info,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              final assigned =
                                  await CampaignCustomerRepository.assign(
                                    CampaignCustomer(
                                      campaignId: campaignId!,
                                      customerId: customerId!,
                                      assignedDate: DateTime.now(),
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    ),
                                  );
                              if (!mounted || !ctx.mounted) return;
                              if (!assigned) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Customer could not be assigned. Check the database connection and try again.',
                                    ),
                                    backgroundColor: AppColors.danger,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setState(() {}); // refresh campaign columns
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Customer assigned to ${_campaignName(campaignId!)}',
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog({Customer? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final companyCtrl = TextEditingController(text: existing?.company ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String segment = existing?.segment ?? 'Retail';
    String status = existing?.status ?? AppConstants.statusActive;
    String? campaignId;
    final allCampaigns = CampaignRepository.getAll();
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final brightness = Theme.of(ctx).brightness;
          final dialogBg = AppTheme.surfaceColor(brightness);
          final headerBg = brightness == Brightness.dark
              ? const Color(0xFF2A2650)
              : AppColors.primaryLight;
          final textPri = AppTheme.textPrimary(brightness);
          final textSec = AppTheme.textSecondary(brightness);
          final inputFill = AppTheme.inputFill(brightness);
          final borderCol = AppTheme.border(brightness);
          final dropBg = AppTheme.surfaceColor(brightness);

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              side: BorderSide(color: AppTheme.border(brightness)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: headerBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppConstants.radiusLarge),
                        topRight: Radius.circular(AppConstants.radiusLarge),
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
                          child: Icon(
                            isEdit
                                ? Icons.edit_rounded
                                : Icons.person_add_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEdit ? 'Edit Customer' : 'New Customer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close, color: textSec, size: 20),
                        ),
                      ],
                    ),
                  ),
                  // body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: fk,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              controller: nameCtrl,
                              label: 'Full Name',
                              hint: 'e.g. Abebe Kebede',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: emailCtrl,
                              label: 'Email Address',
                              hint: 'name@company.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: InputValidators.email,
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: phoneCtrl,
                              label: 'Phone Number',
                              hint: '09XX XXX XXXX or 07XX XXX XXXX',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: InputValidators.ethiopianPhone,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _DialogDropdown(
                                    label: 'Status',
                                    value: status,
                                    items: const [
                                      'Active',
                                      'Draft',
                                      'Paused',
                                      'Completed',
                                      'Cancelled',
                                      'Pending',
                                    ],
                                    fillColor: inputFill,
                                    borderColor: borderCol,
                                    dropColor: dropBg,
                                    textColor: textPri,
                                    secColor: textSec,
                                    onChanged: (v) =>
                                        setLocal(() => status = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DialogDropdown(
                                    label: 'Segment',
                                    value: segment,
                                    items: const ['Retail', 'Corporate', 'VIP'],
                                    fillColor: inputFill,
                                    borderColor: borderCol,
                                    dropColor: dropBg,
                                    textColor: textPri,
                                    secColor: textSec,
                                    onChanged: (v) =>
                                        setLocal(() => segment = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Existing campaign associations (edit only)
                            if (isEdit) ...[
                              Text(
                                'Assigned Campaigns',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textPri,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...CampaignCustomerRepository.getByCustomer(
                                existing.id,
                              ).map((a) {
                                final name = _campaignName(a.campaignId);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.campaign_outlined,
                                        size: 15,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textPri,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        a.participationStatus,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textSec,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: AppColors.danger,
                                        ),
                                        tooltip: 'Remove from campaign',
                                        onPressed: () async {
                                          final removed =
                                              await CampaignCustomerRepository.remove(
                                            a.campaignId,
                                            existing.id,
                                          );
                                          if (!mounted) return;
                                          if (!removed) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Could not remove the campaign assignment. Try again when online.',
                                                ),
                                                backgroundColor:
                                                    AppColors.danger,
                                              ),
                                            );
                                            return;
                                          }
                                          setLocal(() {});
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Removed from $name',
                                              ),
                                              backgroundColor:
                                                  AppColors.warning,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (CampaignCustomerRepository.getByCustomer(
                                existing.id,
                              ).isEmpty)
                                Text(
                                  'Not assigned to any campaign.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSec,
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                            // Assign to campaign (adds an association on save)
                            Text(
                              isEdit ? 'Assign to Campaign' : 'Campaign *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPri,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMedium,
                                ),
                                border: Border.all(color: borderCol),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: campaignId,
                                  isExpanded: true,
                                  isDense: true,
                                  dropdownColor: dropBg,
                                  hint: Text(
                                    isEdit
                                        ? 'Select a campaign to assign (optional)'
                                        : 'Select a campaign',
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textPri,
                                  ),
                                  items: [
                                    if (isEdit)
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          '— None —',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textSec,
                                          ),
                                        ),
                                      ),
                                    ...allCampaigns.map(
                                      (c) => DropdownMenuItem<String?>(
                                        value: c.id,
                                        child: Text(
                                          '${c.name} (${c.status})',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textPri,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setLocal(() => campaignId = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(brightness),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppConstants.radiusLarge),
                        bottomRight: Radius.circular(AppConstants.radiusLarge),
                      ),
                      border: Border(
                        top: BorderSide(color: AppTheme.divider(brightness)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (!fk.currentState!.validate()) return;
                            if (!isEdit && campaignId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a campaign'),
                                  backgroundColor: AppColors.warning,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            final updated = Customer(
                              id: isEdit
                                  ? existing.id
                                  : CustomerRepository.nextId(),
                              name: nameCtrl.text.trim(),
                              company: companyCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              segment: segment,
                              status: status,
                              lastActivity: DateTime.now(),
                              joinedAt: isEdit
                                  ? existing.joinedAt
                                  : DateTime.now(),
                              campaignId: isEdit
                                  ? existing.campaignId
                                  : campaignId,
                            );
                            if (!AccessService.requireSave(
                              context,
                              isEdit,
                              'Customers',
                            ))
                              return;
                            final persisted = isEdit
                                ? await CustomerRepository.update(updated)
                                : await CustomerRepository.add(updated);
                            if (!mounted || !ctx.mounted) return;
                            if (!persisted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Customer could not be saved. Check the database connection and try again.',
                                  ),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            if (campaignId != null) {
                              final cid = updated.id;
                              if (!CampaignCustomerRepository.isAssigned(
                                campaignId!,
                                cid,
                              )) {
                                final assigned =
                                    await CampaignCustomerRepository.assign(
                                      CampaignCustomer(
                                        campaignId: campaignId!,
                                        customerId: cid,
                                        assignedDate: DateTime.now(),
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      ),
                                    );
                                if (!mounted || !ctx.mounted) return;
                                if (!assigned) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Customer was saved, but campaign assignment failed. Please retry the assignment.',
                                      ),
                                      backgroundColor: AppColors.danger,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                              }
                            }
                            if (!mounted || !ctx.mounted) return;
                            setState(() {});
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Customer updated'
                                      : 'Customer added and assigned to campaign',
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isEdit ? 'Save Changes' : 'Add Customer'),
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
    );
  }

  void _confirmDelete(Customer c) {
    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(brightness),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(color: AppTheme.border(brightness)),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete Customer?',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Text(
            'Remove "${c.name}"? This cannot be undone.',
            style: TextStyle(
              color: AppTheme.textSecondary(brightness),
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!AccessService.requireDelete(context, 'Customers')) return;
                setState(() => CustomerRepository.remove(c.id));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Customer removed'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _viewDetail(Customer c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(customer: c),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return CustomScrollView(
      slivers: [
        // ── Sticky page header ──────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            brightness: brightness,
            bgColor: AppTheme.backgroundFill(brightness),
            child: _PageHeaderBar(
              onNewTap: _focusNewForm,
              onAssignTap: _showAssignDialog,
            ),
          ),
        ),

        // ── Scrollable body ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inline New Customer form
                if (_showNewForm) ...[
                  _NewCustomerFormPanel(
                    key: _formPanelKey,
                    formKey: _formKey,
                    nameCtrl: _nameCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    companyCtrl: _companyCtrl,
                    notesCtrl: _notesCtrl,
                    segment: _formSegment,
                    status: _formStatus,
                    campaign: _formCampaign,
                    campaigns: CampaignRepository.getAll(),
                    saving: _formSaving,
                    onSegmentChanged: (v) => setState(() => _formSegment = v),
                    onStatusChanged: (v) => setState(() => _formStatus = v),
                    onCampaignChanged: (v) => setState(() => _formCampaign = v),
                    onCancel: _cancelForm,
                    onSubmit: _submitForm,
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),
                ],

                // Table section
                _TableSection(
                  searchController: _searchController,
                  filterSegment: _filterSegment,
                  filterStatus: _filterStatus,
                  filterCampaign: _filterCampaign,
                  campaigns: CampaignRepository.getAll(),
                  onSearchChanged: (v) => setState(() => _currentPage = 1),
                  onSegmentChanged: (v) => setState(() {
                    _filterSegment = v;
                    _currentPage = 1;
                  }),
                  onStatusChanged: (v) => setState(() {
                    _filterStatus = v;
                    _currentPage = 1;
                  }),
                  onCampaignChanged: (v) => setState(() {
                    _filterCampaign = v;
                    _currentPage = 1;
                  }),
                  pageItems: _pageItems,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  onView: _viewDetail,
                  onEdit: (c) => _showEditDialog(existing: c),
                  onDelete: _confirmDelete,
                ),
                const SizedBox(height: AppConstants.sectionSpacing),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StickyHeaderDelegate
// ─────────────────────────────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Brightness brightness;
  final Color bgColor;

  static const double _height = 80.0;

  const _StickyHeaderDelegate({
    required this.child,
    required this.brightness,
    required this.bgColor,
  });

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: bgColor,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: bgColor,
          border: overlapsContent
              ? Border(bottom: BorderSide(color: AppTheme.border(brightness)))
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: 12,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      old.brightness != brightness ||
      old.bgColor != bgColor ||
      old.child != child;
}

// ─────────────────────────────────────────────────────────────────────────────
// _PageHeaderBar
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeaderBar extends StatelessWidget {
  final VoidCallback onNewTap;
  final VoidCallback onAssignTap;
  const _PageHeaderBar({required this.onNewTap, required this.onAssignTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec = AppTheme.textSecondary(brightness);

    return LayoutBuilder(
      builder: (context, cst) {
        final narrow = cst.maxWidth < 600;

        final titleBlock = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: const Icon(
                Icons.people_outline,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customers',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Manage and understand your customer relationships.',
                  style: TextStyle(color: textSec, fontSize: 12),
                ),
              ],
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExportMenuButton(),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onAssignTap,
              icon: const Icon(Icons.group_add_rounded, size: 16),
              label: const Text('Assign to Campaign'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onNewTap,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('New Customer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleBlock,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: actions,
              ),
            ],
          );
        }
        return Row(children: [titleBlock, const Spacer(), actions]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExportMenuButton
// ─────────────────────────────────────────────────────────────────────────────

class _ExportMenuButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      color: AppTheme.surfaceColor(brightness),
      elevation: 4,
      offset: const Offset(0, 40),
      onSelected: (_) {},
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'csv',
          child: Text(
            'Export CSV',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary(brightness),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Text(
            'Export PDF',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary(brightness),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Text(
            'Export Excel',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary(brightness),
            ),
          ),
        ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export'),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCardsRow + _StatCard
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardsRow extends StatelessWidget {
  final int total, active, newCount, retention;
  const _StatCardsRow({
    required this.total,
    required this.active,
    required this.newCount,
    required this.retention,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cst) {
        final w = (cst.maxWidth - 3 * AppConstants.itemSpacing) / 4;
        return Wrap(
          spacing: AppConstants.itemSpacing,
          runSpacing: AppConstants.itemSpacing,
          children: [
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'Total Customers',
                value: '$total',
                icon: Icons.people_outline,
                color: AppColors.primary,
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'Active Customers',
                value: '$active',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'New Customers',
                value: '$newCount',
                icon: Icons.person_add_alt_1_outlined,
                color: AppColors.info,
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'Retention Rate',
                value: '$retention%',
                icon: Icons.trending_up_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg = AppTheme.cardColor(brightness);
    final borderCol = AppTheme.border(brightness);
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textSec,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textPri,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChartsRow + _ChartCard
// ─────────────────────────────────────────────────────────────────────────────

class _ChartsRow extends StatelessWidget {
  final List<Customer> customers;
  const _ChartsRow({required this.customers});

  static const _growthData = [
    CustomerGrowthData(month: 'Jan', customers: 120, newCustomers: 8),
    CustomerGrowthData(month: 'Feb', customers: 135, newCustomers: 15),
    CustomerGrowthData(month: 'Mar', customers: 148, newCustomers: 13),
    CustomerGrowthData(month: 'Apr', customers: 162, newCustomers: 14),
    CustomerGrowthData(month: 'May', customers: 178, newCustomers: 16),
    CustomerGrowthData(month: 'Jun', customers: 190, newCustomers: 12),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cst) {
        final growthCard = _ChartCard(
          title: 'Customer Growth',
          subtitle: 'Monthly customer acquisition trends',
          icon: Icons.show_chart_outlined,
          iconColor: AppColors.primary,
          child: CustomerGrowthChart(data: _growthData),
        );
        final segmentCard = _ChartCard(
          title: 'Customer Segments',
          subtitle: 'Distribution by segment',
          icon: Icons.pie_chart_outline,
          iconColor: AppColors.info,
          child: CustomerSegmentsChart(customers: customers),
        );
        if (cst.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: cst.maxWidth >= 900 ? 3 : 1, child: growthCard),
              const SizedBox(width: AppConstants.itemSpacing),
              Expanded(flex: cst.maxWidth >= 900 ? 2 : 1, child: segmentCard),
            ],
          );
        }
        return Column(
          children: [
            growthCard,
            const SizedBox(height: AppConstants.itemSpacing),
            segmentCard,
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg = AppTheme.cardColor(brightness);
    final borderCol = AppTheme.border(brightness);
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSec, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NewCustomerFormPanel — inline collapsible form
// ─────────────────────────────────────────────────────────────────────────────

class _NewCustomerFormPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl,
      emailCtrl,
      phoneCtrl,
      companyCtrl,
      notesCtrl;
  final String segment, status, campaign;
  final List<Campaign> campaigns;
  final bool saving;
  final ValueChanged<String> onSegmentChanged,
      onStatusChanged,
      onCampaignChanged;
  final VoidCallback onCancel, onSubmit;

  const _NewCustomerFormPanel({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.companyCtrl,
    required this.notesCtrl,
    required this.segment,
    required this.status,
    required this.campaign,
    required this.campaigns,
    required this.saving,
    required this.onSegmentChanged,
    required this.onStatusChanged,
    required this.onCampaignChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg = AppTheme.cardColor(brightness);
    final borderCol = AppTheme.border(brightness);
    final divCol = AppTheme.divider(brightness);
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);
    final inputFill = AppTheme.inputFill(brightness);
    final dropBg = AppTheme.surfaceColor(brightness);
    final headerBg = brightness == Brightness.dark
        ? const Color(0xFF2A2650)
        : AppColors.primaryLight;
    final footerBg = AppTheme.surfaceVariant(brightness);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // panel header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusLarge),
                topRight: Radius.circular(AppConstants.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Customer',
                      style: TextStyle(
                        color: textPri,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Fill in the details to add a new customer.',
                      style: TextStyle(color: textSec, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(Icons.close, color: textSec, size: 20),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // form fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // row 1: name + email
                  LayoutBuilder(
                    builder: (ctx, cst) {
                      final two = cst.maxWidth > 600;
                      return Flex(
                        direction: two ? Axis.horizontal : Axis.vertical,
                        children: [
                          Flexible(
                            flex: two ? 1 : 0,
                            child: CustomTextField(
                              controller: nameCtrl,
                              label: 'Full Name *',
                              hint: 'e.g. Abebe Kebede',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          SizedBox(width: two ? 16 : 0, height: two ? 0 : 12),
                          Flexible(
                            flex: two ? 1 : 0,
                            child: CustomTextField(
                              controller: emailCtrl,
                              label: 'Email Address *',
                              hint: 'name@company.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                if (!v.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  // row 2: phone + company
                  LayoutBuilder(
                    builder: (ctx, cst) {
                      final two = cst.maxWidth > 600;
                      return Flex(
                        direction: two ? Axis.horizontal : Axis.vertical,
                        children: [
                          Flexible(
                            flex: two ? 1 : 0,
                            child: CustomTextField(
                              controller: phoneCtrl,
                              label: 'Phone Number *',
                              hint: '+251 9XX XXX XXX',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          SizedBox(width: two ? 16 : 0, height: two ? 0 : 12),
                          Flexible(
                            flex: two ? 1 : 0,
                            child: CustomTextField(
                              controller: companyCtrl,
                              label: 'Company',
                              hint: 'Company name',
                              prefixIcon: Icons.business_outlined,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  // row 3: segment + status dropdowns
                  LayoutBuilder(
                    builder: (ctx, cst) {
                      final two = cst.maxWidth > 600;
                      return Flex(
                        direction: two ? Axis.horizontal : Axis.vertical,
                        children: [
                          Flexible(
                            flex: two ? 1 : 0,
                            child: _FormDropdownField(
                              label: 'Segment',
                              value: segment,
                              items: const ['Retail', 'Corporate', 'VIP'],
                              fillColor: inputFill,
                              borderColor: borderCol,
                              dropColor: dropBg,
                              textColor: textPri,
                              secColor: textSec,
                              onChanged: onSegmentChanged,
                            ),
                          ),
                          SizedBox(width: two ? 16 : 0, height: two ? 0 : 12),
                          Flexible(
                            flex: two ? 1 : 0,
                            child: _FormDropdownField(
                              label: 'Status',
                              value: status,
                              items: const [
                                'Active',
                                'Draft',
                                'Paused',
                                'Pending',
                              ],
                              fillColor: inputFill,
                              borderColor: borderCol,
                              dropColor: dropBg,
                              textColor: textPri,
                              secColor: textSec,
                              onChanged: onStatusChanged,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  // campaign assignment (required)
                  _FormDropdownField(
                    label: 'Campaign *',
                    value: campaign.isEmpty ? null : campaign,
                    items: campaigns.map((c) => c.id).toList(),
                    itemLabels: campaigns
                        .map((c) => '${c.name} (${c.status})')
                        .toList(),
                    fillColor: inputFill,
                    borderColor: borderCol,
                    dropColor: dropBg,
                    textColor: textPri,
                    secColor: textSec,
                    onChanged: onCampaignChanged,
                  ),
                  const SizedBox(height: 14),
                  // notes
                  CustomTextField(
                    controller: notesCtrl,
                    label: 'Notes',
                    hint: 'Any additional notes…',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),

          // footer actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: footerBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppConstants.radiusLarge),
                bottomRight: Radius.circular(AppConstants.radiusLarge),
              ),
              border: Border(top: BorderSide(color: divCol)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: saving ? null : onSubmit,
                  icon: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_rounded, size: 16),
                  label: Text(saving ? 'Creating…' : 'Create Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Label + dropdown helper used in inline form
class _FormDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final List<String>? itemLabels;
  final Color fillColor, borderColor, dropColor, textColor, secColor;
  final ValueChanged<String> onChanged;

  const _FormDropdownField({
    required this.label,
    required this.value,
    required this.items,
    this.itemLabels,
    required this.fillColor,
    required this.borderColor,
    required this.dropColor,
    required this.textColor,
    required this.secColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              isExpanded: true,
              dropdownColor: dropColor,
              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: secColor),
              style: TextStyle(fontSize: 13, color: textColor),
              hint: Text(
                'Select…',
                style: TextStyle(fontSize: 13, color: secColor),
              ),
              items: List.generate(items.length, (i) {
                final display = itemLabels == null ? items[i] : itemLabels![i];
                return DropdownMenuItem(
                  value: items[i],
                  child: Text(
                    display,
                    style: TextStyle(fontSize: 13, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      ],
    );
  }
}

// Dialog-only inline dropdown (no separate label wrapper)
class _DialogDropdown extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final Color fillColor, borderColor, dropColor, textColor, secColor;
  final ValueChanged<String> onChanged;

  const _DialogDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.fillColor,
    required this.borderColor,
    required this.dropColor,
    required this.textColor,
    required this.secColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              isExpanded: true,
              dropdownColor: dropColor,
              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: secColor),
              style: TextStyle(fontSize: 13, color: textColor),
              items: items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        i,
                        style: TextStyle(fontSize: 13, color: textColor),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TableSection
// ─────────────────────────────────────────────────────────────────────────────

class _TableSection extends StatelessWidget {
  final TextEditingController searchController;
  final String filterSegment, filterStatus, filterCampaign;
  final List<Campaign> campaigns;
  final ValueChanged<String> onSearchChanged,
      onSegmentChanged,
      onStatusChanged,
      onCampaignChanged;
  final List<Customer> pageItems;
  final int currentPage, totalPages;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Customer> onView, onEdit, onDelete;

  const _TableSection({
    required this.searchController,
    required this.filterSegment,
    required this.filterStatus,
    required this.filterCampaign,
    required this.campaigns,
    required this.onSearchChanged,
    required this.onSegmentChanged,
    required this.onStatusChanged,
    required this.onCampaignChanged,
    required this.pageItems,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);
    final inputFill = AppTheme.inputFill(brightness);
    final borderCol = AppTheme.border(brightness);
    final dropBg = AppTheme.surfaceColor(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // search + filters
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: TextStyle(fontSize: 13, color: textPri),
                  decoration: InputDecoration(
                    hintText: 'Search customers…',
                    hintStyle: TextStyle(fontSize: 13, color: textSec),
                    prefixIcon: Icon(Icons.search, size: 18, color: textSec),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, size: 16, color: textSec),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      borderSide: BorderSide(color: borderCol),
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
            ),
            const SizedBox(width: 8),
            _FilterDrop(
              value: filterSegment,
              items: const ['All', 'Retail', 'Corporate', 'VIP'],
              icon: Icons.label_outline,
              fillColor: inputFill,
              borderColor: borderCol,
              dropColor: dropBg,
              textColor: textPri,
              secColor: textSec,
              onChanged: onSegmentChanged,
            ),
            const SizedBox(width: 8),
            _FilterDrop(
              value: filterStatus,
              items: const [
                'All',
                'Active',
                'Draft',
                'Paused',
                'Completed',
                'Cancelled',
                'Pending',
              ],
              icon: Icons.toggle_on_outlined,
              fillColor: inputFill,
              borderColor: borderCol,
              dropColor: dropBg,
              textColor: textPri,
              secColor: textSec,
              onChanged: onStatusChanged,
            ),
            const SizedBox(width: 8),
            // Campaign filter (shows names, filters by id)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filterCampaign,
                  isDense: true,
                  dropdownColor: dropBg,
                  icon: Icon(
                    Icons.campaign_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  style: TextStyle(fontSize: 12, color: textPri),
                  items: [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text(
                        'All Campaigns',
                        style: TextStyle(fontSize: 12, color: textPri),
                      ),
                    ),
                    ...campaigns.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.name,
                          style: TextStyle(fontSize: 12, color: textPri),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => onCampaignChanged(v!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // table or empty
        if (pageItems.isEmpty)
          _EmptyState()
        else
          LayoutBuilder(
            builder: (context, cst) {
              if (cst.maxWidth < 700) {
                return Column(
                  children: pageItems
                      .map(
                        (c) => _MobileCard(
                          customer: c,
                          onView: onView,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                      )
                      .toList(),
                );
              }
              return _DesktopTable(
                customers: pageItems,
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete,
              );
            },
          ),

        // pagination
        if (pageItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Pagination(
            currentPage: currentPage,
            totalPages: totalPages,
            onPageChanged: onPageChanged,
          ),
        ],
      ],
    );
  }
}

// Small filter dropdown for the table toolbar
class _FilterDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final Color fillColor, borderColor, dropColor, textColor, secColor;
  final ValueChanged<String> onChanged;

  const _FilterDrop({
    required this.value,
    required this.items,
    required this.icon,
    required this.fillColor,
    required this.borderColor,
    required this.dropColor,
    required this.textColor,
    required this.secColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: dropColor,
          icon: Icon(icon, size: 16, color: AppColors.primary),
          style: TextStyle(fontSize: 12, color: textColor),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    i,
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DesktopTable
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List<Customer> customers;
  final ValueChanged<Customer> onView, onEdit, onDelete;

  const _DesktopTable({
    required this.customers,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final headerBg = AppTheme.tableHeaderColor(brightness);
    final rowBg = AppTheme.cardColor(brightness);
    final hoverBg = AppTheme.tableRowHover(brightness);
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);
    final borderCol = AppTheme.border(brightness);
    final segChipBg = AppTheme.primaryLighter(brightness);

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1040),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(headerBg),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) return hoverBg;
                return rowBg;
              }),
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSec,
              ),
              dataTextStyle: TextStyle(fontSize: 13, color: textPri),
              dividerThickness: 1,
              columns: [
                DataColumn(
                  label: Text(
                    'Customer',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Email',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Phone',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Segment',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Campaigns',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Last Activity',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(
                      color: textSec,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              rows: customers.map((c) {
                final dateStr =
                    '${c.lastActivity.month}/${c.lastActivity.day}/${c.lastActivity.year}';
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              c.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textPri,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        c.email,
                        style: TextStyle(fontSize: 13, color: textPri),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        c.phone,
                        style: TextStyle(fontSize: 13, color: textPri),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: segChipBg,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSmall,
                          ),
                        ),
                        child: Text(
                          c.segment,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          _CustomersScreenState._campaignsForCustomer(c.id),
                          style: TextStyle(fontSize: 12, color: textPri),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    DataCell(StatusBadge(status: c.status)),
                    DataCell(
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 12, color: textSec),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            tooltip: 'View',
                            onPressed: () => onView(c),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.info,
                            ),
                            tooltip: 'Edit',
                            onPressed: () => onEdit(c),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            tooltip: 'Delete',
                            onPressed: () => onDelete(c),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MobileCard
// ─────────────────────────────────────────────────────────────────────────────

class _MobileCard extends StatelessWidget {
  final Customer customer;
  final ValueChanged<Customer> onView, onEdit, onDelete;

  const _MobileCard({
    required this.customer,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg = AppTheme.cardColor(brightness);
    final borderCol = AppTheme.border(brightness);
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);
    final chipBg = AppTheme.surfaceVariant(brightness);
    final chipBdr = AppTheme.border(brightness);
    final dateStr =
        '${customer.lastActivity.month}/${customer.lastActivity.day}/${customer.lastActivity.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  customer.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
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
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: textPri,
                      ),
                    ),
                    Text(
                      customer.email,
                      style: TextStyle(fontSize: 12, color: textSec),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: textSec, size: 20),
                color: AppTheme.surfaceColor(brightness),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  side: BorderSide(color: borderCol),
                ),
                onSelected: (v) {
                  if (v == 'view') onView(customer);
                  if (v == 'edit') onEdit(customer);
                  if (v == 'delete') onDelete(customer);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text('View', style: TextStyle(color: textPri)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        Text('Edit', style: TextStyle(color: textPri)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                icon: Icons.phone_outlined,
                label: customer.phone,
                chipBg: chipBg,
                chipBdr: chipBdr,
                textColor: textPri,
                iconColor: textSec,
              ),
              _Chip(
                icon: Icons.label_outline,
                label: customer.segment,
                chipBg: chipBg,
                chipBdr: chipBdr,
                textColor: textPri,
                iconColor: textSec,
              ),
              StatusBadge(status: customer.status),
              _Chip(
                icon: Icons.calendar_today_outlined,
                label: dateStr,
                chipBg: chipBg,
                chipBdr: chipBdr,
                textColor: textPri,
                iconColor: textSec,
              ),
              _Chip(
                icon: Icons.campaign_outlined,
                label: _CustomersScreenState._campaignsForCustomer(customer.id),
                chipBg: chipBg,
                chipBdr: chipBdr,
                textColor: textPri,
                iconColor: textSec,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color chipBg, chipBdr, textColor, iconColor;

  const _Chip({
    required this.icon,
    required this.label,
    required this.chipBg,
    required this.chipBdr,
    required this.textColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        border: Border.all(color: chipBdr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: textColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: AppTheme.textSecondary(brightness).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No customers found',
              style: TextStyle(
                color: AppTheme.textSecondary(brightness),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Pagination
// ─────────────────────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int currentPage, totalPages;
  final ValueChanged<int> onPageChanged;

  const _Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec = AppTheme.textSecondary(brightness);
    final pageBg = AppTheme.surfaceVariant(brightness);
    final borderCol = AppTheme.border(brightness);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          onPressed: currentPage > 1
              ? () => onPageChanged(currentPage - 1)
              : null,
          color: textSec,
        ),
        ...List.generate(totalPages, (i) {
          final page = i + 1;
          final isActive = page == currentPage;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onPageChanged(page),
              child: AnimatedContainer(
                duration: AppConstants.animFast,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : pageBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? AppColors.primary : borderCol,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$page',
                    style: TextStyle(
                      color: isActive ? Colors.white : textSec,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          onPressed: currentPage < totalPages
              ? () => onPageChanged(currentPage + 1)
              : null,
          color: textSec,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DetailSheet — bottom sheet view
// ─────────────────────────────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  final Customer customer;
  const _DetailSheet({required this.customer});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final sheetBg = AppTheme.surfaceColor(brightness);
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);
    final divCol = AppTheme.divider(brightness);

    final joinedStr =
        '${customer.joinedAt.day}/${customer.joinedAt.month}/${customer.joinedAt.year}';
    final actStr =
        '${customer.lastActivity.day}/${customer.lastActivity.month}/${customer.lastActivity.year}';

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border(brightness),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    customer.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textPri,
                        ),
                      ),
                      Text(
                        customer.segment,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: customer.status),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: divCol),
            const SizedBox(height: 12),
            _detailRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: customer.email,
              textPri: textPri,
              textSec: textSec,
            ),
            _detailRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: customer.phone,
              textPri: textPri,
              textSec: textSec,
            ),
            _detailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Joined',
              value: joinedStr,
              textPri: textPri,
              textSec: textSec,
            ),
            _detailRow(
              icon: Icons.update_outlined,
              label: 'Last Activity',
              value: actStr,
              textPri: textPri,
              textSec: textSec,
            ),
            const SizedBox(height: 8),
            // ── Assigned campaigns ──
            Divider(color: divCol),
            const SizedBox(height: 12),
            Text(
              'Assigned Campaigns',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPri,
              ),
            ),
            const SizedBox(height: 10),
            ..._buildCampaignRows(customer.id, textPri, textSec),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCampaignRows(
    int customerId,
    Color textPri,
    Color textSec,
  ) {
    final assocs = CampaignCustomerRepository.getByCustomer(customerId);
    if (assocs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Not assigned to any campaign.',
            style: TextStyle(fontSize: 12, color: textSec),
          ),
        ),
      ];
    }
    return assocs.map((a) {
      final name =
          CampaignRepository.findById(a.campaignId)?.name ?? a.campaignId;
      final dateStr =
          '${a.assignedDate.day}/${a.assignedDate.month}/${a.assignedDate.year}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(Icons.campaign_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      color: textPri,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Assigned $dateStr  ·  ${a.participationStatus}',
                    style: TextStyle(fontSize: 11, color: textSec),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textPri,
    required Color textSec,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textSec,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: textPri,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
