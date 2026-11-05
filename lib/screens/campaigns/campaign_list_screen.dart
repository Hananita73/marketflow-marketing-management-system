import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import 'package:flutter/services.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';
import '../../models/notification_model.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../widgets/campaign/campaign_table.dart';
import '../../widgets/campaign/campaign_stat_card.dart';
import '../../widgets/campaign/campaign_dialogs.dart';
import '../../widgets/campaign/campaign_filter_dialog.dart';
import '../../widgets/campaign/campaign_form_widgets.dart';
import '../../widgets/common/approval_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CampaignListScreen
//
// Rendered inside AppLayout with selfScrolling: true, meaning the outer
// SingleChildScrollView is bypassed and this widget fills available height.
//
// Scroll architecture:
//   CustomScrollView
//     ├─ SliverPersistentHeader (pinned) → sticky _PageHeaderBar
//     └─ SliverList → all page content (KPI cards, charts, table, form)
// ─────────────────────────────────────────────────────────────────────────────

class CampaignListScreen extends StatefulWidget {
  const CampaignListScreen({super.key});

  @override
  State<CampaignListScreen> createState() => _CampaignListScreenState();
}

class _CampaignListScreenState extends State<CampaignListScreen> {
  // ── Form scroll key ───────────────────────────────────────────────────────
  final GlobalKey _newCampaignFormKey = GlobalKey();

  // ── Table / filter state ──────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _tabFilter    = 'All Campaigns';
  String _searchQuery  = '';
  int    _currentPage  = 1;
  String _filterStatus = '';
  CampaignObjective? _filterObjective;
  CampaignChannel?   _filterChannel;

  // ── Inline new-campaign form state ────────────────────────────────────────
  bool _showNewForm = false;

  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _typeCtrl   = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  // ─── Derived list ─────────────────────────────────────────────────────────
  List<Campaign> get _filtered {
    final all   = CampaignRepository.getAll();
    final query = _searchQuery.toLowerCase();
    return all.where((c) {
      final matchSearch = query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.objective.label.toLowerCase().contains(query) ||
          c.status.toLowerCase().contains(query) ||
          c.channels.any((ch) => ch.label.toLowerCase().contains(query));
      final matchTab  = _tabFilter == 'All Campaigns' || c.status == _tabFilter;
      final matchSt   = _filterStatus.isEmpty    || c.status    == _filterStatus;
      final matchObj  = _filterObjective == null || c.objective == _filterObjective;
      final matchCh   = _filterChannel   == null || c.channels.contains(_filterChannel);
      return matchSearch && matchTab && matchSt && matchObj && matchCh;
    }).toList();
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _searchController.dispose();
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _budgetCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Approval workflow helpers ─────────────────────────────────────────────

  bool get _canApprove {
    return AuthService().isAdmin || AccessService.canApprove('Campaigns');
  }

  List<Campaign> get _pendingApproval => CampaignRepository.getPendingApproval();

  void _approveCampaign(Campaign c) {
    CampaignRepository.approveCampaign(c.id, AuthService().currentName,
        comments: 'Approved via approval queue');
    AuditLogService.logApprove('Campaigns', c.id, c.name);
    NotificationRepository.add(
      title: 'Campaign Approved',
      message: '"${c.name}" has been approved and is ready to execute.',
      category: NotificationCategory.campaign,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${c.name}" approved successfully.'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _rejectCampaign(Campaign c) async {
    final reason = await showRejectDialog(context, title: 'Reject Campaign');
    if (reason == null || !mounted) return;
    CampaignRepository.rejectCampaign(c.id, AuthService().currentName, reason);
    AuditLogService.logReject('Campaigns', c.id, c.name, details: {'reason': reason});
    NotificationRepository.add(
      title: 'Campaign Rejected',
      message: '"${c.name}" was rejected: $reason',
      category: NotificationCategory.campaign,
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${c.name}" rejected.'),
      backgroundColor: AppColors.warning,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── Dialogs / actions ───────────────────────────────────────────────────
  void _goToDetail(Campaign c) {
    showDialog(context: context, builder: (_) => CampaignDetailsDialog(campaign: c))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  void _goToEdit(Campaign c) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CampaignFormDialog(campaign: c),
    ).then((updated) { if (updated != null && mounted) setState(() {}); });
  }

  void _openFilters() {
    showDialog(
      context: context,
      builder: (_) => CampaignFilterDialog(
        currentStatus:    _filterStatus,
        currentObjective: _filterObjective,
        currentChannel:   _filterChannel,
      ),
    ).then((result) {
      if (result != null && mounted) {
        setState(() {
          _filterStatus    = result['status']    ?? '';
          _filterObjective = result['objective'];
          _filterChannel   = result['channel'];
          _currentPage     = 1;
        });
      }
    });
  }

  void _confirmDelete(Campaign c) {
    showDialog(
      context: context,
      builder: (_) => DeleteCampaignDialog(
        campaignName: c.name,
        onConfirm: () {
          if (!AccessService.requireDelete(context, 'Campaigns')) return;
          CampaignRepository.remove(c.id);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Campaign deleted successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ));
        },
      ),
    );
  }

  void _focusNewCampaignForm() {
    setState(() => _showNewForm = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _newCampaignFormKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.05);
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? (_startDate?.add(const Duration(days: 30)) ?? now)),
      firstDate: DateTime(2024),
      lastDate:  DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
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

  void _submitNewCampaign() {
    if (!_formKey.currentState!.validate()) return;
    if (!AccessService.requireCreate(context, 'Campaigns')) return;
    setState(() => _saving = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      final campaign = Campaign(
        id: CampaignRepository.nextId(),
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        objective: CampaignObjective.brandAwareness,
        channels: const [CampaignChannel.socialMedia],
        status: AppConstants.statusDraft,
        startDate: _startDate,
        endDate:   _endDate,
        budget: double.tryParse(_budgetCtrl.text.replaceAll(',', '')) ?? 0,
        spent: 0, leads: 0, conversions: 0, impressions: 0, roi: 0,
        activities: const [], coupons: const [], expenses: const [],
      );
      CampaignRepository.add(campaign);
      if (mounted) {
        setState(() {
          _saving = false;
          _showNewForm = false;
          _nameCtrl.clear(); _typeCtrl.clear();
          _budgetCtrl.clear(); _descCtrl.clear();
          _startDate = null; _endDate = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Campaign created successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  void _cancelNewForm() {
    setState(() {
      _showNewForm = false;
      _nameCtrl.clear(); _typeCtrl.clear();
      _budgetCtrl.clear(); _descCtrl.clear();
      _startDate = null; _endDate = null;
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final campaigns  = _filtered;
    final brightness = Theme.of(context).brightness;
    final bgColor    = AppTheme.backgroundFill(brightness);

    // ── Layout: fixed header + scrollable body ───────────────────────────
    // We use a plain Column instead of CustomScrollView + SliverPersistentHeader
    // because SliverPersistentHeader requires paintExtent >= minExtent at all
    // times. On a small window the viewport gives paintExtent < any reasonable
    // minExtent, causing "SliverGeometry is not valid" assertion crashes.
    //
    // The Column approach is simpler and crash-proof:
    //   • _PageHeaderBar is always visible at the top (intrinsic height).
    //   • SingleChildScrollView below it handles all scrollable content.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Sticky page header (no sliver) ──────────────────────────────
        _PageHeaderSurface(
          brightness: brightness,
          bgColor: bgColor,
          child: _PageHeaderBar(
            onCreateTap:  () {
              if (!AccessService.requireCreate(context, 'Campaigns')) {
                return;
              }
              _focusNewCampaignForm();
            },
            onFiltersTap: _openFilters,
          ),
        ),

        // ── Scrollable page body ─────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inline New Campaign form
                if (_showNewForm) ...[
                  _NewCampaignFormPanel(
                    key: _newCampaignFormKey,
                    formKey: _formKey,
                    nameCtrl:   _nameCtrl,
                    typeCtrl:   _typeCtrl,
                    budgetCtrl: _budgetCtrl,
                    descCtrl:   _descCtrl,
                    startDate: _startDate,
                    endDate:   _endDate,
                    saving: _saving,
                    onPickStartDate: () => _pickDate(isStart: true),
                    onPickEndDate:   () => _pickDate(isStart: false),
                    onCancel:  _cancelNewForm,
                    onSubmit:  _submitNewCampaign,
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),
                ],

                // ── Approval panel (managers/admins only, when there are pending campaigns)
                if (_canApprove && _pendingApproval.isNotEmpty) ...[
                  ApprovalPanel<Campaign>(
                    title: 'Pending Campaign Approvals',
                    subtitle: 'Review and approve submitted campaigns',
                    icon: Icons.campaign_outlined,
                    items: _pendingApproval,
                    itemBuilder: (ctx, campaign) => _CampaignApprovalTile(
                      campaign: campaign,
                      onApprove: () => _approveCampaign(campaign),
                      onReject:  () => _rejectCampaign(campaign),
                      onView:    () => _goToDetail(campaign),
                    ),
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),
                ],

                // Table header (tabs + search)
                _TableSectionHeader(
                  searchController: _searchController,
                  tabFilter: _tabFilter,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onTabChanged:    (v) => setState(() { _tabFilter = v; _currentPage = 1; }),
                ),
                const SizedBox(height: AppConstants.itemSpacing),

                // Campaign table
                CampaignTable(
                  campaigns: campaigns,
                  onView:   _goToDetail,
                  onEdit:   _goToEdit,
                  onDelete: _confirmDelete,
                  onCreate: _focusNewCampaignForm,
                  pageSize: 6,
                  currentPage: _currentPage,
                  onPageChanged: (page) => setState(() => _currentPage = page),
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
// _PageHeaderSurface
//
// A plain non-sliver sticky header. Replaces SliverPersistentHeader which
// requires paintExtent >= minExtent at all times. On small windows the sliver
// engine cannot satisfy that constraint, causing:
//   "SliverGeometry is not valid: layoutExtent exceeds paintExtent"
//
// This widget renders as a simple Material surface above the scrollable body.
// It is always visible regardless of viewport size because it sits outside the
// scroll view entirely — the Column parent gives it intrinsic height and the
// Expanded below it takes all remaining space.
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeaderSurface extends StatelessWidget {
  final Widget child;
  final Brightness brightness;
  final Color bgColor;

  const _PageHeaderSurface({
    required this.child,
    required this.brightness,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: bgColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: AppTheme.border(brightness), width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.pagePadding,
            vertical: 10,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PageHeaderBar
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeaderBar extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onFiltersTap;

  const _PageHeaderBar({required this.onCreateTap, required this.onFiltersTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (context, cst) {
      // Use the real available content width (accounts for sidebar + AI panel).
      // 560px threshold fits comfortably: below it the two-row layout is used.
      final narrow = cst.maxWidth < 560;

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
            child: const Icon(Icons.campaign_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campaigns',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Create, manage and track your marketing campaigns.',
                  style: TextStyle(color: textSec, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      );

      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: onFiltersTap,
            icon: const Icon(Icons.filter_list_outlined, size: 16),
            label: const Text('Filters'),
          ),
          const SizedBox(width: 8),
          _ExportMenuButton(),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Campaign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );

      if (narrow) {
        // Two-row layout: title on top, buttons below.
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
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

      // Wide layout: title left, buttons right, vertically centered.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: titleBlock),
          const SizedBox(width: 8),
          actions,
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ExportMenuButton
// ─────────────────────────────────────────────────────────────────────────────

class _ExportMenuButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const ExportMenuButton(module: 'Campaigns');
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCardsRow
//
// Truly responsive KPI card row that adapts when the AI panel opens and
// narrows the available content area.
//
// Strategy:
//   • Minimum card width = 160px (cards never get squeezed below this).
//   • Column count = max number of cards that fit at or above 160px.
//   • Card width = (availableWidth - (cols-1)*spacing) / cols — always fills
//     full width with no leftover gap regardless of how many columns are used.
//   • Wrap handles line-breaking automatically when cols changes.
//
// This prevents the layout overflow that caused Campaigns to go blank when the
// AI panel (340px) opened and reduced the content width.
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardsRow extends StatelessWidget {
  /// Minimum card width before wrapping to fewer columns.
  static const double _minCardWidth = 160.0;

  @override
  Widget build(BuildContext context) {
    final all        = CampaignRepository.getAll();
    final active     = all.where((c) => c.status == AppConstants.statusActive).length;
    final totalSpent = all.fold(0.0, (s, c) => s + c.spent);
    final totalRev   = all.fold(0.0, (s, c) => s + (c.roi * c.spent));
    final avgRoi     = all.isEmpty ? 0.0 : all.fold(0.0, (s, c) => s + c.roi) / all.length;

    const cards = 5; // total KPI cards
    final cardData = <Map<String, dynamic>>[
      {'title': 'Total Campaigns',  'value': '${all.length}',                                 'change': '12%',   'pos': true,  'icon': Icons.campaign_outlined,              'color': AppColors.primary},
      {'title': 'Active Campaigns', 'value': '$active',                                        'change': '8.2%',  'pos': true,  'icon': Icons.check_circle_outline,           'color': AppColors.success},
      {'title': 'Total Spent',      'value': 'ETB ${(totalSpent / 1000).toStringAsFixed(0)}K', 'change': '4.3%',  'pos': false, 'icon': Icons.account_balance_wallet_outlined, 'color': AppColors.warning},
      {'title': 'Total Revenue',    'value': 'ETB ${(totalRev   / 1000).toStringAsFixed(0)}K', 'change': '15.3%', 'pos': true,  'icon': Icons.monetization_on_outlined,       'color': AppColors.info},
      {'title': 'Avg. ROI',         'value': '${avgRoi.toStringAsFixed(2)}x',                  'change': '18%',   'pos': true,  'icon': Icons.trending_up_outlined,           'color': AppColors.primary},
    ];

    return LayoutBuilder(builder: (context, cst) {
      final spacing   = AppConstants.itemSpacing;
      final available = cst.maxWidth;

      // How many columns can fit?  Start from 5 and drop down until each
      // column is at least _minCardWidth wide.  Floor at 1 so we never
      // divide by zero.
      int cols = cards;
      while (cols > 1) {
        final w = (available - (cols - 1) * spacing) / cols;
        if (w >= _minCardWidth) break;
        cols--;
      }

      final cardWidth = (available - (cols - 1) * spacing) / cols;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cardData.map((d) => SizedBox(
          width: cardWidth,
          child: CampaignStatCard(
            title:      d['title']  as String,
            value:      d['value']  as String,
            change:     d['change'] as String,
            isPositive: d['pos']    as bool,
            icon:       d['icon']   as IconData,
            iconColor:  d['color']  as Color,
          ),
        )).toList(),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NewCampaignFormPanel — inline collapsible form
// ─────────────────────────────────────────────────────────────────────────────

class _NewCampaignFormPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController typeCtrl;
  final TextEditingController budgetCtrl;
  final TextEditingController descCtrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool saving;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _NewCampaignFormPanel({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.typeCtrl,
    required this.budgetCtrl,
    required this.descCtrl,
    required this.startDate,
    required this.endDate,
    required this.saving,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final divCol     = AppTheme.divider(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final headerBg   = brightness == Brightness.dark
        ? const Color(0xFF2A2650)
        : AppColors.primaryLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  child: const Icon(Icons.add_circle_outline, size: 17, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Campaign', style: TextStyle(color: textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Fill in the details to create a new campaign.', style: TextStyle(color: textSec, fontSize: 12)),
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

          // Form body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name + Type
                  LayoutBuilder(builder: (ctx, cst) {
                    final twoCol = cst.maxWidth > 600;
                    return Flex(
                      direction: twoCol ? Axis.horizontal : Axis.vertical,
                      children: [
                        Flexible(
                          flex: twoCol ? 1 : 0,
                          child: _Field(
                            label: 'Campaign Name *',
                            child: TextFormField(
                              controller: nameCtrl,
                              style: TextStyle(fontSize: 13, color: textPri),
                              decoration: InputDecoration(
                                hintText: 'e.g. Summer Sale 2026',
                                hintStyle: TextStyle(fontSize: 13, color: textSec),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campaign name is required' : null,
                            ),
                          ),
                        ),
                        SizedBox(width: twoCol ? 16 : 0, height: twoCol ? 0 : 12),
                        Flexible(
                          flex: twoCol ? 1 : 0,
                          child: _Field(
                            label: 'Campaign Type',
                            child: TextFormField(
                              controller: typeCtrl,
                              style: TextStyle(fontSize: 13, color: textPri),
                              decoration: InputDecoration(
                                hintText: 'e.g. Product Launch, Brand Awareness',
                                hintStyle: TextStyle(fontSize: 13, color: textSec),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),

                  // Row 2: Start Date + End Date
                  LayoutBuilder(builder: (ctx, cst) {
                    final twoCol = cst.maxWidth > 600;
                    return Flex(
                      direction: twoCol ? Axis.horizontal : Axis.vertical,
                      children: [
                        Flexible(
                          flex: twoCol ? 1 : 0,
                          child: _Field(
                            label: 'Start Date',
                            child: CampaignDateField(value: startDate, hint: 'Select start date', onTap: onPickStartDate),
                          ),
                        ),
                        SizedBox(width: twoCol ? 16 : 0, height: twoCol ? 0 : 12),
                        Flexible(
                          flex: twoCol ? 1 : 0,
                          child: _Field(
                            label: 'End Date',
                            child: CampaignDateField(value: endDate, hint: 'Select end date', onTap: onPickEndDate),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),

                  // Budget
                  _Field(
                    label: 'Budget (ETB) *',
                    child: TextFormField(
                      controller: budgetCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(fontSize: 13, color: textPri),
                      decoration: InputDecoration(
                        hintText: 'e.g. 50000',
                        hintStyle: TextStyle(fontSize: 13, color: textSec),
                        prefixText: 'ETB  ',
                        prefixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Budget is required';
                        final p = double.tryParse(v);
                        if (p == null || p <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _Field(
                    label: 'Description',
                    child: TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: TextStyle(fontSize: 13, color: textPri),
                      decoration: InputDecoration(
                        hintText: 'Brief description of the campaign goal…',
                        hintStyle: TextStyle(fontSize: 13, color: textSec),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant(brightness),
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
                  onPressed: saving ? null : onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: saving ? null : onSubmit,
                  icon: saving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.rocket_launch_outlined, size: 16),
                  label: Text(saving ? 'Creating…' : 'Create Campaign'),
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

// Label + field helper
class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textPrimary(brightness), fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TableSectionHeader — status tabs + search bar
// ─────────────────────────────────────────────────────────────────────────────

class _TableSectionHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String tabFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTabChanged;

  const _TableSectionHeader({
    required this.searchController,
    required this.tabFilter,
    required this.onSearchChanged,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tabs = ['All Campaigns', 'Active', 'Paused', 'Completed', 'Draft'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.map((tab) {
              final isActive = tab == tabFilter;
              return GestureDetector(
                onTap: () => onTabChanged(tab),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isActive ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tab,
                    style: TextStyle(
                      color: isActive ? AppColors.primary : AppTheme.textSecondary(brightness),
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
                  decoration: InputDecoration(
                    hintText: 'Search campaigns…',
                    hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness)),
                    prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.iconColor(brightness)),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close, size: 16, color: AppTheme.iconColor(brightness)),
                            onPressed: () { searchController.clear(); onSearchChanged(''); },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.inputFill(brightness),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      borderSide: BorderSide(color: AppTheme.border(brightness)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      borderSide: BorderSide(color: AppTheme.border(brightness)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.grid_view_outlined,  tooltip: 'Grid view', onTap: () {}),
            const SizedBox(width: 4),
            _IconBtn(icon: Icons.filter_list_outlined, tooltip: 'Filter',    onTap: () {}),
          ],
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(brightness),
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
          child: Icon(icon, size: 18, color: AppTheme.iconColor(brightness)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CampaignApprovalTile — used inside ApprovalPanel for campaigns
// ─────────────────────────────────────────────────────────────────────────────

class _CampaignApprovalTile extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onView;

  const _CampaignApprovalTile({
    required this.campaign,
    required this.onApprove,
    required this.onReject,
    required this.onView,
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
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.campaign_outlined, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(campaign.name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPri)),
            Text(campaign.objective.label,
                style: TextStyle(fontSize: 12, color: textSec)),
          ])),
          TextButton(
            onPressed: onView,
            child: const Text('View Details', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _ApprovalChip(label: 'Budget: ETB ${campaign.budget.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_outlined, color: AppColors.info),
          if (campaign.startDate != null)
            _ApprovalChip(
              label: '${campaign.startDate!.day}/${campaign.startDate!.month}/${campaign.startDate!.year}'
                  ' → ${campaign.endDate != null ? "${campaign.endDate!.day}/${campaign.endDate!.month}/${campaign.endDate!.year}" : "…"}',
              icon: Icons.date_range_outlined, color: AppColors.primary),
          ...campaign.channels.take(3).map((ch) =>
              _ApprovalChip(label: ch.label, icon: ch.icon, color: ch.color)),
        ]),
        const SizedBox(height: 10),
        if (campaign.description.isNotEmpty)
          Text(campaign.description,
              style: TextStyle(fontSize: 12, color: textSec, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        ApprovalActionRow(onApprove: onApprove, onReject: onReject),
      ]),
    );
  }
}

class _ApprovalChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _ApprovalChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ]),
      );
}
