import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import 'package:flutter/services.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/notification_model.dart';
import '../../models/promotion.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/badges/status_badge.dart';
import '../../widgets/common/approval_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data source: PromotionRepository (Supabase-backed).
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// PromotionsScreen
// ─────────────────────────────────────────────────────────────────────────────
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _typeFilter = 'All';

  /// Working copy of the repository data, refreshed after every mutation so
  /// setState picks up changes made through [PromotionRepository].
  List<Promotion> _promos = List.from(PromotionRepository.getAll());

  void _reload() => _promos = List.from(PromotionRepository.getAll());

  static const _statuses = ['All', 'Active', 'Draft', 'Paused', 'Completed'];
  static const _types = [
    'All',
    'Percentage',
    'Fixed Amount',
    'Free Shipping',
    'BOGO',
  ];

  List<Promotion> get _filtered => _promos.where((p) {
    final q = _searchQuery.toLowerCase();
    final matchQ =
        q.isEmpty ||
        p.name.toLowerCase().contains(q) ||
        p.campaignName.toLowerCase().contains(q) ||
        p.couponCodes.any((c) => c.toLowerCase().contains(q));
    final matchS = _statusFilter == 'All' || p.status == _statusFilter;
    final matchT = _typeFilter == 'All' || p.type == _typeFilter;
    return matchQ && matchS && matchT;
  }).toList();

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showForm({Promotion? existing, bool isDuplicate = false}) {
    final isEdit = existing != null && !isDuplicate;
    final nameCtrl = TextEditingController(
      text: isDuplicate ? '${existing!.name} (Copy)' : existing?.name ?? '',
    );
    final discountCtrl = TextEditingController(
      text: existing != null ? existing.discountValue.toStringAsFixed(0) : '',
    );
    final usageLimitCtrl = TextEditingController(
      text: existing != null ? '${existing.usageLimit}' : '',
    );
    final campaignCtrl = TextEditingController(
      text: existing?.campaignName ?? '',
    );
    final codeCtrl = TextEditingController(
      text: existing?.couponCodes.join(', ') ?? '',
    );
    String type = existing?.type ?? 'Percentage';
    String status = isDuplicate
        ? AppConstants.statusDraft
        : (existing?.status ?? AppConstants.statusDraft);
    DateTime startDate = isDuplicate
        ? DateTime.now()
        : (existing?.startDate ?? DateTime.now());
    DateTime endDate = isDuplicate
        ? DateTime.now().add(const Duration(days: 30))
        : (existing?.endDate ?? DateTime.now().add(const Duration(days: 30)));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final brightness = Theme.of(ctx).brightness;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
            ),
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
                      _DialogHeader(
                        icon: isEdit
                            ? Icons.edit_rounded
                            : isDuplicate
                            ? Icons.copy_rounded
                            : Icons.local_offer_outlined,
                        title: isEdit
                            ? 'Edit Promotion'
                            : isDuplicate
                            ? 'Duplicate Promotion'
                            : 'Create Promotion',
                      ),
                      const Divider(height: 28),

                      _FormField(
                        label: 'Promotion Name *',
                        child: TextFormField(
                          controller: nameCtrl,
                          decoration: _inputDec(
                            'e.g. Summer Flash Sale',
                            brightness,
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                          style: _inputStyle(brightness),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _TwoCol(
                        left: _FormField(
                          label: 'Promotion Type',
                          child: _DropdownField(
                            value: type,
                            items: const [
                              'Percentage',
                              'Fixed Amount',
                              'Free Shipping',
                              'BOGO',
                            ],
                            onChanged: (v) => setLocal(() => type = v),
                          ),
                        ),
                        right: _FormField(
                          label: 'Status',
                          child: _DropdownField(
                            value: status,
                            items: const [
                              'Active',
                              'Draft',
                              'Paused',
                              'Completed',
                            ],
                            onChanged: (v) => setLocal(() => status = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _TwoCol(
                        left: _FormField(
                          label: type == 'Percentage'
                              ? 'Discount (%)'
                              : 'Discount Amount',
                          child: TextFormField(
                            controller: discountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: _inputDec(
                              type == 'Percentage' ? '25' : '500',
                              brightness,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                            style: _inputStyle(brightness),
                          ),
                        ),
                        right: _FormField(
                          label: 'Usage Limit',
                          child: TextFormField(
                            controller: usageLimitCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _inputDec('500', brightness),
                            style: _inputStyle(brightness),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _TwoCol(
                        left: _FormField(
                          label: 'Start Date',
                          child: _DateTap(
                            value: startDate,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: startDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                                builder: (c, child) => Theme(
                                  data: Theme.of(c).copyWith(
                                    colorScheme: Theme.of(c).colorScheme
                                        .copyWith(primary: AppColors.primary),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (d != null) setLocal(() => startDate = d);
                            },
                          ),
                        ),
                        right: _FormField(
                          label: 'End Date',
                          child: _DateTap(
                            value: endDate,
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: endDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                                builder: (c, child) => Theme(
                                  data: Theme.of(c).copyWith(
                                    colorScheme: Theme.of(c).colorScheme
                                        .copyWith(primary: AppColors.primary),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (d != null) setLocal(() => endDate = d);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _TwoCol(
                        left: _FormField(
                          label: 'Campaign',
                          child: TextFormField(
                            controller: campaignCtrl,
                            decoration: _inputDec('Campaign name', brightness),
                            style: _inputStyle(brightness),
                          ),
                        ),
                        right: _FormField(
                          label: 'Coupon Codes (comma-separated)',
                          child: TextFormField(
                            controller: codeCtrl,
                            decoration: _inputDec('CODE1, CODE2', brightness),
                            style: _inputStyle(brightness),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              if (!formKey.currentState!.validate()) return;
                              final discVal =
                                  double.tryParse(discountCtrl.text.trim()) ??
                                  0;
                              final limit =
                                  int.tryParse(usageLimitCtrl.text.trim()) ?? 0;
                              final codes = codeCtrl.text
                                  .split(',')
                                  .map((c) => c.trim())
                                  .where((c) => c.isNotEmpty)
                                  .toList();
                              final discLabel = type == 'Percentage'
                                  ? '${discVal.toStringAsFixed(0)}% off'
                                  : type == 'Fixed Amount'
                                  ? 'ETB ${discVal.toStringAsFixed(0)} off'
                                  : type;

                              final promo = Promotion(
                                id: isEdit
                                    ? existing.id
                                    : PromotionRepository.nextId(),
                                name: nameCtrl.text.trim(),
                                type: type,
                                discount: discLabel,
                                discountValue: discVal,
                                startDate: startDate,
                                endDate: endDate,
                                usageLimit: limit,
                                usedCount: isEdit ? existing.usedCount : 0,
                                status: status,
                                campaignName: campaignCtrl.text.trim().isEmpty
                                    ? '—'
                                    : campaignCtrl.text.trim(),
                                couponCodes: codes.isEmpty ? ['PROMO'] : codes,
                              );
                              if (!AccessService.requireSave(
                                context,
                                isEdit,
                                'Promotions',
                              ))
                                return;
                              setState(() {
                                if (isEdit) {
                                  PromotionRepository.update(promo);
                                } else {
                                  PromotionRepository.add(promo);
                                }
                                _reload();
                              });
                              Navigator.pop(ctx);
                              _showSnack(
                                isEdit
                                    ? 'Promotion updated'
                                    : isDuplicate
                                    ? 'Promotion duplicated'
                                    : 'Promotion created',
                              );
                            },
                            child: Text(
                              isEdit
                                  ? 'Save Changes'
                                  : isDuplicate
                                  ? 'Duplicate'
                                  : 'Create Promotion',
                            ),
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

  void _confirmDelete(Promotion p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: const Text(
          'Delete Promotion',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (!AccessService.requireDelete(context, 'Promotions')) return;
              setState(() {
                PromotionRepository.remove(p.id);
                _reload();
              });
              Navigator.pop(ctx);
              _showSnack('Promotion deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {Color color = AppColors.success}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );

  // ── Promotion approval workflow ───────────────────────────────────────────

  static const _statusPendingApproval = 'Pending Approval';

  bool get _canApprovePromotions {
    return AuthService().isAdmin || AccessService.canApprove('Promotions');
  }

  List<Promotion> get _pendingApproval =>
      _promos.where((p) => p.status == _statusPendingApproval).toList();

  void _submitForApproval(Promotion p) {
    final updated = Promotion(
      id: p.id,
      name: p.name,
      type: p.type,
      discount: p.discount,
      discountValue: p.discountValue,
      startDate: p.startDate,
      endDate: p.endDate,
      usageLimit: p.usageLimit,
      usedCount: p.usedCount,
      status: _statusPendingApproval,
      campaignName: p.campaignName,
      couponCodes: p.couponCodes,
    );
    PromotionRepository.update(updated);
    AuditLogService.logSubmit('Promotions', p.id, p.name);
    NotificationRepository.add(
      title: 'Promotion Submitted for Approval',
      message: '"${p.name}" is pending manager approval.',
      category: NotificationCategory.promotion,
    );
    setState(_reload);
    _showSnack('"${p.name}" submitted for approval.');
  }

  void _approvePromotion(Promotion p) {
    final updated = Promotion(
      id: p.id,
      name: p.name,
      type: p.type,
      discount: p.discount,
      discountValue: p.discountValue,
      startDate: p.startDate,
      endDate: p.endDate,
      usageLimit: p.usageLimit,
      usedCount: p.usedCount,
      status: AppConstants.statusActive,
      campaignName: p.campaignName,
      couponCodes: p.couponCodes,
    );
    PromotionRepository.update(updated);
    AuditLogService.logApprove('Promotions', p.id, p.name);
    NotificationRepository.add(
      title: 'Promotion Approved',
      message: '"${p.name}" has been approved and is now Active.',
      category: NotificationCategory.promotion,
    );
    setState(_reload);
    _showSnack('"${p.name}" approved and activated.');
  }

  Future<void> _rejectPromotion(Promotion p) async {
    final reason = await showRejectDialog(context, title: 'Reject Promotion');
    if (reason == null) return;
    final updated = Promotion(
      id: p.id,
      name: p.name,
      type: p.type,
      discount: p.discount,
      discountValue: p.discountValue,
      startDate: p.startDate,
      endDate: p.endDate,
      usageLimit: p.usageLimit,
      usedCount: p.usedCount,
      status: AppConstants.statusDraft,
      campaignName: p.campaignName,
      couponCodes: p.couponCodes,
    );
    PromotionRepository.update(updated);
    AuditLogService.logReject(
      'Promotions',
      p.id,
      p.name,
      details: {'reason': reason},
    );
    NotificationRepository.add(
      title: 'Promotion Rejected',
      message: '"${p.name}" was rejected: $reason',
      category: NotificationCategory.promotion,
    );
    setState(_reload);
    _showSnack(
      '"${p.name}" rejected and returned to Draft.',
      color: AppColors.warning,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered = _filtered;

    return CustomScrollView(
      slivers: [
        // ── Sticky header ─────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _ScreenHeaderDelegate(
            onAction: () => _showForm(),
            brightness: brightness,
          ),
        ),

        // ── Scrollable content ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.sectionSpacing,
              AppConstants.pagePadding,
              AppConstants.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Approval panel (managers/admins only)
                if (_canApprovePromotions && _pendingApproval.isNotEmpty) ...[
                  ApprovalPanel<Promotion>(
                    title: 'Pending Promotion Approvals',
                    subtitle: 'Review and approve submitted promotions',
                    icon: Icons.local_offer_outlined,
                    items: _pendingApproval,
                    itemBuilder: (ctx, promo) => _PromotionApprovalTile(
                      promo: promo,
                      onApprove: () => _approvePromotion(promo),
                      onReject: () => _rejectPromotion(promo),
                    ),
                  ),
                  const SizedBox(height: AppConstants.sectionSpacing),
                ],

                _FilterBar(
                  searchQuery: _searchQuery,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  statusFilter: _statusFilter,
                  statuses: _statuses,
                  onStatusChanged: (v) => setState(() => _statusFilter = v),
                  typeFilter: _typeFilter,
                  types: _types,
                  onTypeChanged: (v) => setState(() => _typeFilter = v),
                ),
                const SizedBox(height: 20),

                filtered.isEmpty
                    ? _EmptyState(
                        icon: Icons.local_offer_outlined,
                        message: 'No promotions found',
                        hint: 'Try adjusting your search or filter',
                      )
                    : _PromotionGrid(
                        promotions: filtered,
                        onEdit: (p) => _showForm(existing: p),
                        onDuplicate: (p) =>
                            _showForm(existing: p, isDuplicate: true),
                        onDelete: _confirmDelete,
                        onSubmitForApproval: (p) {
                          if (p.status == AppConstants.statusDraft) {
                            _submitForApproval(p);
                          }
                        },
                      ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Promotion Grid
// ─────────────────────────────────────────────────────────────────────────────
class _PromotionGrid extends StatelessWidget {
  final List<Promotion> promotions;
  final void Function(Promotion) onEdit;
  final void Function(Promotion) onDuplicate;
  final void Function(Promotion) onDelete;
  final void Function(Promotion) onSubmitForApproval;

  const _PromotionGrid({
    required this.promotions,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onSubmitForApproval,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1100
            ? 3
            : w >= 680
            ? 2
            : 1;
        final spacing = AppConstants.itemSpacing;
        final cardW = (w - (cols - 1) * spacing) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: promotions
              .map(
                (p) => SizedBox(
                  width: cardW,
                  child: _PromotionCard(
                    promo: p,
                    onEdit: onEdit,
                    onDuplicate: onDuplicate,
                    onDelete: onDelete,
                    onSubmitForApproval: onSubmitForApproval,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Promotion Card
// ─────────────────────────────────────────────────────────────────────────────
class _PromotionCard extends StatefulWidget {
  final Promotion promo;
  final void Function(Promotion) onEdit;
  final void Function(Promotion) onDuplicate;
  final void Function(Promotion) onDelete;
  final void Function(Promotion) onSubmitForApproval;

  const _PromotionCard({
    required this.promo,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onSubmitForApproval,
  });

  @override
  State<_PromotionCard> createState() => _PromotionCardState();
}

class _PromotionCardState extends State<_PromotionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final p = widget.promo;
    final accentColor = _statusAccent(p.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        decoration: BoxDecoration(
          color: AppTheme.cardColor(brightness),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: _hovered
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppTheme.border(brightness),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coloured top bar
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusLarge),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row + menu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.textPrimary(brightness),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSmall,
                                ),
                              ),
                              child: Text(
                                p.discount,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: AppTheme.iconColor(brightness),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                        ),
                        onSelected: (v) {
                          if (v == 'edit') widget.onEdit(p);
                          if (v == 'duplicate') widget.onDuplicate(p);
                          if (v == 'submit') widget.onSubmitForApproval(p);
                          if (v == 'delete') widget.onDelete(p);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: AppColors.info,
                                ),
                                SizedBox(width: 8),
                                Text('Edit', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.copy_outlined,
                                  size: 15,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Duplicate',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          if (p.status == AppConstants.statusDraft)
                            const PopupMenuItem(
                              value: 'submit',
                              height: 38,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.send_outlined,
                                    size: 15,
                                    color: AppColors.warning,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Submit for Approval',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 15,
                                  color: AppColors.danger,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: AppTheme.divider(brightness)),
                  const SizedBox(height: 14),

                  // Date range
                  Row(
                    children: [
                      Icon(
                        Icons.date_range_outlined,
                        size: 13,
                        color: AppTheme.iconColor(brightness),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_fmtDate(p.startDate)} → ${_fmtDate(p.endDate)}',
                          style: TextStyle(
                            color: AppTheme.textSecondary(brightness),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Campaign
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 13,
                        color: AppTheme.iconColor(brightness),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.campaignName,
                          style: TextStyle(
                            color: AppTheme.textSecondary(brightness),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Usage progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Usage: ${p.usedCount} / ${p.usageLimit}',
                            style: TextStyle(
                              color: AppTheme.textSecondary(brightness),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${(p.usagePercent * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: p.usagePercent,
                          minHeight: 6,
                          backgroundColor: accentColor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Coupon codes
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: p.couponCodes
                        .take(3)
                        .map(
                          (code) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant(brightness),
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusSmall,
                              ),
                              border: Border.all(
                                color: AppTheme.border(brightness),
                              ),
                            ),
                            child: Text(
                              code,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary(brightness),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),

                  // Status + type row
                  Row(
                    children: [
                      StatusBadge(status: p.status),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant(brightness),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSmall,
                          ),
                        ),
                        child: Text(
                          p.type,
                          style: TextStyle(
                            color: AppTheme.textSecondary(brightness),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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

Color _statusAccent(String status) {
  switch (status) {
    case AppConstants.statusActive:
      return AppColors.success;
    case AppConstants.statusDraft:
      return AppColors.primary;
    case AppConstants.statusPaused:
      return AppColors.warning;
    case AppConstants.statusCompleted:
      return AppColors.textSecondary;
    default:
      return AppColors.info;
  }
}

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month]} ${d.year}';

const _months = [
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
];

// ─────────────────────────────────────────────────────────────────────────────
// Filter Bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String statusFilter;
  final List<String> statuses;
  final ValueChanged<String> onStatusChanged;
  final String typeFilter;
  final List<String> types;
  final ValueChanged<String> onTypeChanged;

  const _FilterBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.statuses,
    required this.onStatusChanged,
    required this.typeFilter,
    required this.types,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final search = SizedBox(
          height: 40,
          child: TextField(
            onChanged: onSearchChanged,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary(brightness),
            ),
            decoration: InputDecoration(
              hintText: 'Search promotions…',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary(brightness),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: AppTheme.iconColor(brightness),
              ),
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
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        );
        final filters = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterChip(
              label: statusFilter,
              items: statuses,
              onChanged: onStatusChanged,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: typeFilter,
              items: types,
              onChanged: onTypeChanged,
            ),
          ],
        );
        if (wide) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              filters,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [search, const SizedBox(height: 10), filters],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _FilterChip({
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.inputFill(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: label,
          isDense: true,
          dropdownColor: AppTheme.surfaceColor(brightness),
          icon: Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: AppTheme.iconColor(brightness),
          ),
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary(brightness),
          ),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    i,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary(brightness),
                    ),
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
// Sticky header delegate — wraps _ScreenHeader in a SliverPersistentHeader
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onAction;
  final Brightness brightness;

  const _ScreenHeaderDelegate({
    required this.onAction,
    required this.brightness,
  });

  static const double _height = 72.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_ScreenHeaderDelegate old) =>
      old.onAction != onAction || old.brightness != brightness;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppTheme.surfaceColor(brightness),
      elevation: overlapsContent ? 2 : 0,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: 12,
        ),
        child: _ScreenHeader(
          title: 'Promotions',
          subtitle: 'Create and monitor marketing offers and promotions.',
          actionLabel: 'Create Promotion',
          actionIcon: Icons.add,
          onAction: onAction,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen header — title, icon, subtitle, and primary action
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec = AppTheme.textSecondary(brightness);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 580;

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
              child: Icon(actionIcon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(subtitle, style: TextStyle(color: textSec, fontSize: 12)),
              ],
            ),
          ],
        );

        final btn = ElevatedButton.icon(
          onPressed: onAction,
          icon: Icon(actionIcon, size: 16),
          label: Text(actionLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), btn],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [titleBlock, const Spacer(), btn],
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 800 ? 4 : 2;
        final spacing = AppConstants.itemSpacing;
        final cardW = (w - (cols - 1) * spacing) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (s) => SizedBox(
                  width: cardW,
                  child: _StatCard(item: s),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.title, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(item.icon, size: 20, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    color: AppTheme.textSecondary(brightness),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppTheme.textSecondary(brightness).withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.textSecondary(brightness),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              color: AppTheme.textSecondary(brightness),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _DialogHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryLighter(brightness),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(brightness),
            ),
          ),
        ),
      ],
    );
  }
}

class _TwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TwoCol({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 380) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 12),
              Expanded(child: right),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [left, const SizedBox(height: 14), right],
        );
      },
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(brightness),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.inputFill(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceColor(brightness),
          icon: Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: AppTheme.iconColor(brightness),
          ),
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary(brightness),
          ),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    i,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary(brightness),
                    ),
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

class _DateTap extends StatelessWidget {
  final DateTime value;
  final VoidCallback onTap;
  const _DateTap({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.inputFill(brightness),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppTheme.border(brightness)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppTheme.iconColor(brightness),
            ),
            const SizedBox(width: 8),
            Text(
              _fmtDate(value),
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _inputStyle(Brightness brightness) =>
    TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness));

InputDecoration _inputDec(String hint, Brightness brightness) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        color: AppTheme.textSecondary(brightness),
      ),
      filled: true,
      fillColor: AppTheme.inputFill(brightness),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );

// ─────────────────────────────────────────────────────────────────────────────
// _PromotionApprovalTile — used inside ApprovalPanel for promotions
// ─────────────────────────────────────────────────────────────────────────────

class _PromotionApprovalTile extends StatelessWidget {
  final Promotion promo;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PromotionApprovalTile({
    required this.promo,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPri,
                      ),
                    ),
                    Text(
                      '${promo.type}  ·  ${promo.discount}  ·  ${promo.campaignName}',
                      style: TextStyle(fontSize: 12, color: textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _PromoChip(
                label: 'Discount: ${promo.discount}',
                color: AppColors.success,
              ),
              _PromoChip(
                label: 'Limit: ${promo.usageLimit}',
                color: AppColors.info,
              ),
              _PromoChip(
                label:
                    'Expires: ${promo.endDate.day}/${promo.endDate.month}/${promo.endDate.year}',
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ApprovalActionRow(onApprove: onApprove, onReject: onReject),
        ],
      ),
    );
  }
}

class _PromoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PromoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
    ),
  );
}
