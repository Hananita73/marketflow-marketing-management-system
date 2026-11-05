import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/opportunity.dart';
import '../../widgets/common/custom_textfield.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OpportunitiesScreen
// selfScrolling: true in routes.dart — owns its own CustomScrollView.
// ─────────────────────────────────────────────────────────────────────────────

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStage = 'All';

  List<Opportunity> get _filtered {
    var list = List<Opportunity>.from(OpportunityRepository.getAll());
    final q = _searchController.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((o) =>
          o.name.toLowerCase().contains(q) ||
          o.company.toLowerCase().contains(q) ||
          o.owner.toLowerCase().contains(q)).toList();
    }
    if (_filterStage != 'All') {
      list = list.where((o) => o.stage == _filterStage).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showAddEditDialog({Opportunity? existing}) {
    final isEdit      = existing != null;
    final snap        = existing;
    final nameCtrl    = TextEditingController(text: snap?.name    ?? '');
    final companyCtrl = TextEditingController(text: snap?.company ?? '');
    final valueCtrl   = TextEditingController(
        text: snap != null ? snap.value.toStringAsFixed(0) : '');
    final ownerCtrl   = TextEditingController(
        text: snap?.owner ?? 'Hana Tsegaye');
    String stage = snap?.stage ?? 'New';
    int probability = snap?.probability ?? 50;
    final fk = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final brightness = Theme.of(ctx).brightness;
          final dialogBg   = AppTheme.surfaceColor(brightness);
          final headerBg   = brightness == Brightness.dark
              ? const Color(0xFF2A2650)
              : AppColors.primaryLight;
          final textPri    = AppTheme.textPrimary(brightness);
          final textSec    = AppTheme.textSecondary(brightness);
          final inputFill  = AppTheme.inputFill(brightness);
          final borderCol  = AppTheme.border(brightness);
          final dropBg     = AppTheme.surfaceColor(brightness);

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              side: BorderSide(color: AppTheme.border(brightness)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
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
                        topLeft: Radius.circular(AppConstants.radiusXL),
                        topRight: Radius.circular(AppConstants.radiusXL),
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
                                : Icons.add_circle_outline_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEdit ? 'Edit Opportunity' : 'New Opportunity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close,
                            color: textSec,
                            size: 20,
                          ),
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
                              label: 'Opportunity Name',
                              hint: 'e.g. Summer Campaign Package',
                              prefixIcon: Icons.work_outline_rounded,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            CustomTextField(
                              controller: companyCtrl,
                              label: 'Company',
                              hint: 'e.g. TechWave Inc.',
                              prefixIcon: Icons.business_outlined,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (_, cst) {
                                final two = cst.maxWidth > 400;
                                return Flex(
                                  direction:
                                      two ? Axis.horizontal : Axis.vertical,
                                  children: [
                                    Flexible(
                                      flex: two ? 1 : 0,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Value (ETB)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textPri,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          CustomTextField(
                                            controller: valueCtrl,
                                            hint: '45000',
                                            prefixIcon:
                                                Icons.attach_money_rounded,
                                            keyboardType:
                                                TextInputType.number,
                                            validator: (v) =>
                                                v == null ||
                                                        v.trim().isEmpty
                                                    ? 'Required'
                                                    : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: two ? 12 : 0,
                                      height: two ? 0 : 12,
                                    ),
                                    Flexible(
                                      flex: two ? 1 : 0,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Probability (%)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textPri,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _ProbabilityField(
                                            initial: probability,
                                            onChanged: (v) =>
                                                setLocal(() => probability = v),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (_, cst) {
                                final two = cst.maxWidth > 400;
                                return Flex(
                                  direction:
                                      two ? Axis.horizontal : Axis.vertical,
                                  children: [
                                    Flexible(
                                      flex: two ? 1 : 0,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Stage',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textPri,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          _StageDropdown(
                                            value: stage,
                                            stages: const [
                                              'New',
                                              'Qualified',
                                              'Proposal',
                                              'Negotiation',
                                              'Won',
                                              'Lost'
                                            ],
                                            onChanged: (v) =>
                                                setLocal(() => stage = v),
                                            fillColor: inputFill,
                                            borderColor: borderCol,
                                            dropColor: dropBg,
                                            textColor: textPri,
                                            secColor: textSec,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: two ? 12 : 0,
                                      height: two ? 0 : 12,
                                    ),
                                    Flexible(
                                      flex: two ? 1 : 0,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Owner',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textPri,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          CustomTextField(
                                            controller: ownerCtrl,
                                            hint: 'Hana Tsegaye',
                                            prefixIcon:
                                                Icons.person_outline_rounded,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
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
                        bottomLeft: Radius.circular(AppConstants.radiusXL),
                        bottomRight: Radius.circular(AppConstants.radiusXL),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.divider(brightness),
                        ),
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (!fk.currentState!.validate()) return;

                            final opp = Opportunity(
                              id: isEdit
                                  ? snap!.id
                                  : OpportunityRepository.nextId(),
                              name: nameCtrl.text.trim(),
                              company: companyCtrl.text.trim(),
                              value: double.tryParse(
                                      valueCtrl.text.trim()) ??
                                  0,
                              owner: ownerCtrl.text.trim().isEmpty
                                  ? 'Hana Tsegaye'
                                  : ownerCtrl.text.trim(),
                              probability: probability,
                              stage: stage,
                              createdAt: isEdit
                                  ? snap!.createdAt
                                  : DateTime.now(),
                            );

                            if (!AccessService.requireSave(context, isEdit, 'Opportunities')) {
                              return;
                            }
                            setState(() {
                              isEdit
                                  ? OpportunityRepository.update(opp)
                                  : OpportunityRepository.add(opp);
                            });

                            Navigator.pop(ctx);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Opportunity updated'
                                      : 'Opportunity added',
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(
                            isEdit ? 'Save Changes' : 'Add Opportunity',
                          ),
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

  void _showViewDialog(Opportunity o) {
    final color = _stageColor(o.stage);

    // ONLY CHANGE: $ → ETB
    final valueStr = o.value >= 1000
        ? 'ETB ${(o.value / 1000).toStringAsFixed(1)}K'
        : 'ETB ${o.value.toInt()}';

    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;
        final dialogBg = AppTheme.surfaceColor(brightness);
        final textPri = AppTheme.textPrimary(brightness);
        final textSec = AppTheme.textSecondary(brightness);

        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusXL),
            side: BorderSide(
              color: AppTheme.border(brightness),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                        ),
                        child: Icon(
                          Icons.work_outline_rounded,
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: textPri,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              o.company,
                              style: TextStyle(
                                color: textSec,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StagePill(
                        stage: o.stage,
                        color: color,
                      ),
                    ],
                  ),
                  Divider(
                    height: 28,
                    color: AppTheme.divider(brightness),
                  ),
                  _DetailRow(
                    icon: Icons.attach_money_rounded,
                    label: 'Value',
                    value: valueStr,
                    color: color,
                    textSec: textSec,
                    textPri: textPri,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Owner',
                    value: o.owner,
                    textSec: textSec,
                    textPri: textPri,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.percent_rounded,
                    label: 'Probability',
                    value: '${o.probability}%',
                    textSec: textSec,
                    textPri: textPri,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Created',
                    value:
                        '${o.createdAt.month}/${o.createdAt.day}/${o.createdAt.year}',
                    textSec: textSec,
                    textPri: textPri,
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: o.probability / 100,
                      minHeight: 8,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                        ),
                        label: const Text('Edit'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddEditDialog(existing: o);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(Opportunity o) {
    showDialog(
      context: context,
      builder: (ctx) {
        final brightness = Theme.of(ctx).brightness;

        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(brightness),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(
              color: AppTheme.border(brightness),
            ),
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
                'Delete Opportunity?',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Text(
            'Remove "${o.name}"? This cannot be undone.',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (!AccessService.requireDelete(context, 'Opportunities')) {
                  return;
                }
                setState(
                  () => OpportunityRepository.remove(o.id),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opportunity deleted'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final all = OpportunityRepository.getAll();
    final openOps = all
        .where((o) => o.stage != 'Won' && o.stage != 'Lost')
        .length;
    final pipelineVal = all
        .where((o) => o.stage != 'Won' && o.stage != 'Lost')
        .fold(0.0, (s, o) => s + o.value);
    final won = all.where((o) => o.stage == 'Won').length;
    final lost = all.where((o) => o.stage == 'Lost').length;
    final filtered = _filtered;

    return CustomScrollView(
      slivers: [
        // ── Sticky header ─────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _PageHeaderDelegate(
            onAdd: () => _showAddEditDialog(),
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
                _StatsRow(
                  open: openOps,
                  pipelineValue: pipelineVal,
                  won: won,
                  lost: lost,
                ),
                const SizedBox(
                  height: AppConstants.sectionSpacing,
                ),
                _Toolbar(
                  searchController: _searchController,
                  filterStage: _filterStage,
                  stages: const [
                    'All',
                    'New',
                    'Qualified',
                    'Proposal',
                    'Negotiation',
                    'Won'
                  ],
                  onSearchChanged: (_) => setState(() {}),
                  onStageChanged: (v) =>
                      setState(() => _filterStage = v),
                  onAdd: () => _showAddEditDialog(),
                ),
                const SizedBox(height: 16),
                filtered.isEmpty
                    ? _EmptyState()
                    : _KanbanBoard(
                        opportunities: filtered,
                        onView: _showViewDialog,
                        onEdit: (o) =>
                            _showAddEditDialog(existing: o),
                        onDelete: _confirmDelete,
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
// Stage color helper
// ─────────────────────────────────────────────────────────────────────────────

Color _stageColor(String stage) {
  switch (stage) {
    case 'New':
      return AppColors.info;
    case 'Qualified':
      return AppColors.primary;
    case 'Proposal':
      return AppColors.warning;
    case 'Negotiation':
      return const Color(0xFFBB5CF8);
    case 'Won':
      return AppColors.success;
    case 'Lost':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int open, won, lost;
  final double pipelineValue;

  const _StatsRow({
    required this.open,
    required this.pipelineValue,
    required this.won,
    required this.lost,
  });

  @override
  Widget build(BuildContext context) {
    // ONLY CHANGE: $ → ETB
    final pipeline = pipelineValue >= 1000
        ? 'ETB ${(pipelineValue / 1000).toStringAsFixed(1)}K'
        : 'ETB ${pipelineValue.toInt()}';

    return LayoutBuilder(
      builder: (_, cst) {
        final cols = cst.maxWidth < 600 ? 2 : 4;
        final w = (cst.maxWidth -
                (cols - 1) * AppConstants.itemSpacing) /
            cols;

        return Wrap(
          spacing: AppConstants.itemSpacing,
          runSpacing: AppConstants.itemSpacing,
          children: [
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'Open Opportunities',
                value: '$open',
                icon: Icons.trending_up_rounded,
                color: AppColors.primary,
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'Pipeline Value',
                value: pipeline,
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.info,
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'Won',
                value: '$won',
                icon: Icons.emoji_events_outlined,
                color: AppColors.success,
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                title: 'Lost',
                value: '$lost',
                icon: Icons.cancel_outlined,
                color: AppColors.danger,
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

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius:
            BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppTheme.border(brightness),
        ),
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
                    color: AppTheme.textSecondary(brightness),
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
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary(brightness),
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
// Toolbar — search + stage filter + add button
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String filterStage;
  final List<String> stages;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStageChanged;
  final VoidCallback onAdd;

  const _Toolbar({
    required this.searchController,
    required this.filterStage,
    required this.stages,
    required this.onSearchChanged,
    required this.onStageChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);
    final inputFill = AppTheme.inputFill(brightness);
    final borderCol = AppTheme.border(brightness);
    final dropBg = AppTheme.surfaceColor(brightness);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: TextStyle(
                fontSize: 13,
                color: textPri,
              ),
              decoration: InputDecoration(
                hintText: 'Search opportunities…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: textSec,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: textSec,
                ),
                suffixIcon:
                    searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: textSec,
                            ),
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
                  borderSide: BorderSide(
                    color: borderCol,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  borderSide: BorderSide(
                    color: borderCol,
                  ),
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
        const SizedBox(width: 10),
        _StageDropdown(
          value: filterStage,
          stages: stages,
          onChanged: onStageChanged,
          icon: Icons.tune_rounded,
          fillColor: inputFill,
          borderColor: borderCol,
          dropColor: dropBg,
          textColor: textPri,
          secColor: textSec,
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Opportunity'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanban board
// ─────────────────────────────────────────────────────────────────────────────

class _KanbanBoard extends StatelessWidget {
  final List<Opportunity> opportunities;
  final ValueChanged<Opportunity> onView;
  final ValueChanged<Opportunity> onEdit;
  final ValueChanged<Opportunity> onDelete;

  const _KanbanBoard({
    required this.opportunities,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  static const _stageOrder = [
    'New',
    'Qualified',
    'Proposal',
    'Negotiation',
    'Won'
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, cst) {
        final w = cst.maxWidth;

        if (w < 600) {
          return Column(
            children: _stageOrder.map((stage) {
              final items = opportunities
                  .where((o) => o.stage == stage)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _KanbanColumn(
                  stage: stage,
                  items: items,
                  color: _stageColor(stage),
                  onView: onView,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              );
            }).toList(),
          );
        }

        if (w < 900) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _stageOrder.map((stage) {
                final items = opportunities
                    .where((o) => o.stage == stage)
                    .toList();

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 220,
                    child: _KanbanColumn(
                      stage: stage,
                      items: items,
                      color: _stageColor(stage),
                      onView: onView,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _stageOrder.map((stage) {
            final items = opportunities
                .where((o) => o.stage == stage)
                .toList();
            final isLast = stage == _stageOrder.last;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: isLast ? 0 : 12,
                ),
                child: _KanbanColumn(
                  stage: stage,
                  items: items,
                  color: _stageColor(stage),
                  onView: onView,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanban column — uses Column (not ListView) for intrinsic height
// ─────────────────────────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  final String stage;
  final List<Opportunity> items;
  final Color color;
  final ValueChanged<Opportunity> onView, onEdit, onDelete;

  const _KanbanColumn({
    required this.stage,
    required this.items,
    required this.color,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg = AppTheme.cardColor(brightness);
    final borderCol = AppTheme.border(brightness);
    final textSec = AppTheme.textSecondary(brightness);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius:
            BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: borderCol,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // column header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: borderCol,
          ),

          // cards
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No opportunities',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSec.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const SizedBox(height: 8),
                    _OpportunityCard(
                      opportunity: items[i],
                      color: color,
                      onView: onView,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Opportunity card
// ─────────────────────────────────────────────────────────────────────────────

class _OpportunityCard extends StatefulWidget {
  final Opportunity opportunity;
  final Color color;
  final ValueChanged<Opportunity> onView, onEdit, onDelete;

  const _OpportunityCard({
    required this.opportunity,
    required this.color,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_OpportunityCard> createState() =>
      _OpportunityCardState();
}

class _OpportunityCardState extends State<_OpportunityCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.opportunity;
    final color = widget.color;
    final brightness = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(brightness);
    final textSec = AppTheme.textSecondary(brightness);
    final normalBg = AppTheme.surfaceVariant(brightness);
    final hoverBg = AppTheme.tableRowHover(brightness);
    final borderCol = AppTheme.border(brightness);
    final hoverBdr =
        AppColors.primary.withValues(alpha: 0.35);

    // ONLY CHANGE: $ → ETB
    final valueStr = o.value >= 1000
        ? 'ETB ${(o.value / 1000).toStringAsFixed(1)}K'
        : 'ETB ${o.value.toInt()}';

    final menuBg = AppTheme.surfaceColor(brightness);

    return MouseRegion(
      onEnter: (_) =>
          setState(() => _hovered = true),
      onExit: (_) =>
          setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered ? hoverBg : normalBg,
          borderRadius:
              BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: _hovered ? hoverBdr : borderCol,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    o.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPri,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    color: menuBg,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10),
                      side: BorderSide(
                        color: borderCol,
                      ),
                    ),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 16,
                      color: textSec,
                    ),
                    onSelected: (v) {
                      if (v == 'view') {
                        widget.onView(o);
                      }
                      if (v == 'edit') {
                        widget.onEdit(o);
                      }
                      if (v == 'delete') {
                        widget.onDelete(o);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'view',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'View',
                              style: TextStyle(
                                fontSize: 13,
                                color: textPri,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 13,
                                color: textPri,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              size: 15,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            const Text(
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
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              o.company,
              style: TextStyle(
                fontSize: 11,
                color: textSec,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.attach_money_rounded,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 3),
                Text(
                  valueStr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.person_outline_rounded,
                  size: 12,
                  color: textSec,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    o.owner,
                    style: TextStyle(
                      fontSize: 11,
                      color: textSec,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: o.probability / 100,
                      minHeight: 5,
                      backgroundColor:
                          color.withValues(alpha: 0.1),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(
                              color),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${o.probability}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StagePill extends StatelessWidget {
  final String stage;
  final Color color;

  const _StagePill({
    required this.stage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Text(
        stage,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;
  final Color textSec, textPri;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textSec,
    required this.textPri,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: textSec,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: textSec,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? textPri,
          ),
        ),
      ],
    );
  }
}

class _ProbabilityField extends StatefulWidget {
  final int initial;
  final ValueChanged<int> onChanged;

  const _ProbabilityField({
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_ProbabilityField> createState() =>
      _ProbabilityFieldState();
}

class _ProbabilityFieldState
    extends State<_ProbabilityField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: '${widget.initial}',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: _ctrl,
      hint: '50',
      prefixIcon: Icons.percent_rounded,
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final p = int.tryParse(v);
        if (p != null) {
          widget.onChanged(p.clamp(0, 100));
        }
      },
    );
  }
}

class _StageDropdown extends StatelessWidget {
  final String value;
  final List<String> stages;
  final ValueChanged<String> onChanged;
  final IconData? icon;
  final Color fillColor, borderColor, dropColor, textColor, secColor;

  const _StageDropdown({
    required this.value,
    required this.stages,
    required this.onChanged,
    required this.fillColor,
    required this.borderColor,
    required this.dropColor,
    required this.textColor,
    required this.secColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius:
            BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: dropColor,
          icon: Icon(
            icon ?? Icons.arrow_drop_down,
            size: 16,
            color: AppColors.primary,
          ),
          style: TextStyle(
            fontSize: 13,
            color: textColor,
          ),
          items: stages
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(brightness),
        borderRadius:
            BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: AppTheme.border(brightness),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up_outlined,
            size: 52,
            color: AppTheme.textSecondary(brightness)
                .withValues(alpha: 0.25),
          ),
          const SizedBox(height: 14),
          Text(
            'No opportunities found',
            style: TextStyle(
              color: AppTheme.textSecondary(brightness),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filter',
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

// ─────────────────────────────────────────────────────────────────────────────
// Sticky header delegate — wraps _PageHeaderBar in a SliverPersistentHeader
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final VoidCallback onAdd;
  final Brightness brightness;

  const _PageHeaderDelegate({
    required this.onAdd,
    required this.brightness,
  });

  // Narrow layout: icon row + button stacked → ~110 px; wide layout → ~72 px.
  // We use a fixed extent (maxExtent == minExtent) so the header never shrinks.
  static const double _height = 72.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(
      _PageHeaderDelegate old) =>
      old.onAdd != onAdd ||
      old.brightness != brightness;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bg = AppTheme.surfaceColor(brightness);

    return Material(
      color: bg,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: 12,
        ),
        child: _PageHeaderBar(
          title: 'Opportunities',
          subtitle:
              'Track potential deals and expected revenue.',
          icon: Icons.trending_up_rounded,
          onAdd: onAdd,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header bar — title, icon, subtitle, and primary action
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onAdd;

  const _PageHeaderBar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec = AppTheme.textSecondary(brightness);

    return LayoutBuilder(
      builder: (_, cst) {
        final narrow = cst.maxWidth < 600;

        final titleBlock = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(
                        AppConstants.radiusMedium),
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSec,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        );

        final actions = ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(
            Icons.add,
            size: 16,
          ),
          label: const Text(
            'Add Opportunity',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleBlock,
              const SizedBox(height: 8),
              actions,
            ],
          );
        }

        return Row(
          children: [
            titleBlock,
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }
}