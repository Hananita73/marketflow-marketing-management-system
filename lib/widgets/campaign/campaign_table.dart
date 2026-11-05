import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/campaign.dart';
import '../../models/campaign_customer.dart';
import 'campaign_status_badge.dart';

class CampaignTable extends StatelessWidget {
  final List<Campaign> campaigns;
  final void Function(Campaign) onView;
  final void Function(Campaign) onEdit;
  final void Function(Campaign) onDelete;
  final VoidCallback onCreate;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int>? onPageChanged;

  const CampaignTable({
    super.key,
    required this.campaigns,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onCreate,
    this.pageSize = 6,
    this.currentPage = 1,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width      = MediaQuery.of(context).size.width;
    final isDesktop  = width >= AppConstants.tabletBreakpoint;
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);

    if (campaigns.isEmpty) {
      return _EmptyState(onCreate: onCreate);
    }

    final start      = (currentPage - 1) * pageSize;
    final end        = (start + pageSize).clamp(0, campaigns.length);
    final pageItems  = campaigns.sublist(start, end);
    final totalPages = (campaigns.length / pageSize).ceil();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: borderCol),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            child: Column(
              children: [
                if (isDesktop)
                  _DesktopTable(campaigns: pageItems, onView: onView, onEdit: onEdit, onDelete: onDelete)
                else
                  _MobileCardList(campaigns: pageItems, onView: onView, onEdit: onEdit, onDelete: onDelete),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Pagination(
          total: campaigns.length,
          pageSize: pageSize,
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

// ─── Desktop table ────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List<Campaign> campaigns;
  final void Function(Campaign) onView;
  final void Function(Campaign) onEdit;
  final void Function(Campaign) onDelete;

  const _DesktopTable({
    required this.campaigns,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        _TableHeader(),
        Divider(height: 1, color: AppTheme.divider(brightness)),
        ...campaigns.asMap().entries.map((entry) {
          final isLast = entry.key == campaigns.length - 1;
          return Column(
            children: [
              _TableRow(
                campaign: entry.value,
                onView: () => onView(entry.value),
                onEdit: () => onEdit(entry.value),
                onDelete: () => onDelete(entry.value),
              ),
              if (!isLast) Divider(height: 1, color: AppTheme.divider(brightness)),
            ],
          );
        }),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final headerBg   = AppTheme.tableHeaderColor(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return Container(
      color: headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(flex: 3, child: _hdr('Campaign', textSec)),
          Expanded(flex: 2, child: _hdr('Objective', textSec)),
          Expanded(flex: 2, child: _hdr('Status', textSec)),
          Expanded(flex: 2, child: _hdr('Channel', textSec)),
          Expanded(flex: 2, child: _hdr('Start Date', textSec)),
          Expanded(flex: 2, child: _hdr('End Date', textSec)),
          Expanded(flex: 2, child: _hdr('Budget', textSec)),
          Expanded(flex: 2, child: _hdr('Spent', textSec)),
          Expanded(flex: 1, child: _hdr('ROI', textSec)),
          const SizedBox(width: 148),
        ],
      ),
    );
  }

  Widget _hdr(String label, Color color) => Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      );
}

class _TableRow extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableRow({
    required this.campaign,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c          = widget.campaign;
    final brightness = Theme.of(context).brightness;
    final rowBg      = AppTheme.cardColor(brightness);
    final hoverBg    = AppTheme.tableRowHover(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        color: _hovered ? hoverBg : rowBg,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: false,
                onChanged: (_) {},
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.primary,
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: TextStyle(
                      color: textPri,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.objective.label,
                    style: TextStyle(color: textSec, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${CampaignCustomerRepository.getByCampaign(c.id).length} customers',
                    style: TextStyle(color: textSec, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(c.objective.label, style: TextStyle(color: textPri, fontSize: 12))),
            Expanded(flex: 2, child: CampaignStatusBadge(status: c.status)),
            Expanded(
              flex: 2,
              child: Text(
                c.channels.map((ch) => ch.label).join(', '),
                style: TextStyle(color: textPri, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 2, child: Text(_fmtDate(c.startDate), style: TextStyle(color: textSec, fontSize: 12))),
            Expanded(flex: 2, child: Text(_fmtDate(c.endDate),   style: TextStyle(color: textSec, fontSize: 12))),
            Expanded(flex: 2, child: Text('ETB ${_num(c.budget)}', style: TextStyle(color: textPri, fontSize: 12))),
            Expanded(flex: 2, child: Text('ETB ${_num(c.spent)}',  style: TextStyle(color: textPri, fontSize: 12))),
            Expanded(
              flex: 1,
              child: Text(
                c.roi > 0 ? '${c.roi}x' : '-',
                style: TextStyle(
                  color: c.roi > 0 ? AppColors.success : textSec,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 148,
              child: Row(
                children: [
                  _ActionButton(icon: Icons.visibility_outlined, tooltip: 'View',   onTap: widget.onView),
                  const SizedBox(width: 4),
                  _ActionButton(icon: Icons.edit_outlined,       tooltip: 'Edit',   onTap: widget.onEdit),
                  const SizedBox(width: 4),
                  _ActionButton(icon: Icons.delete_outline,      tooltip: 'Delete', onTap: widget.onDelete),
                  const SizedBox(width: 4),
                  _MoreMenu(campaign: c, onView: widget.onView, onEdit: widget.onEdit, onDelete: widget.onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.month}/${d.day}/${d.year}';
  }

  String _num(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─── Mobile card list ─────────────────────────────────────────────────────────

class _MobileCardList extends StatelessWidget {
  final List<Campaign> campaigns;
  final void Function(Campaign) onView;
  final void Function(Campaign) onEdit;
  final void Function(Campaign) onDelete;

  const _MobileCardList({
    required this.campaigns,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textPri    = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final divCol     = AppTheme.divider(brightness);

    return Column(
      children: campaigns.asMap().entries.map((entry) {
        final c      = entry.value;
        final isLast = entry.key == campaigns.length - 1;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name,            style: TextStyle(color: textPri, fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(c.objective.label, style: TextStyle(color: textSec, fontSize: 12)),
                            Text(
                              '${CampaignCustomerRepository.getByCampaign(c.id).length} customers',
                              style: TextStyle(color: textSec, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      CampaignStatusBadge(status: c.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _MobileStat(label: 'Budget', value: 'ETB ${_num(c.budget)}')),
                      Expanded(child: _MobileStat(label: 'Spent',  value: 'ETB ${_num(c.spent)}')),
                      Expanded(child: _MobileStat(label: 'ROI',    value: c.roi > 0 ? '${c.roi}x' : '-')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionButton(icon: Icons.visibility_outlined, tooltip: 'View',   onTap: () => onView(c)),
                      const SizedBox(width: 4),
                      _ActionButton(icon: Icons.edit_outlined,       tooltip: 'Edit',   onTap: () => onEdit(c)),
                      const SizedBox(width: 4),
                      _ActionButton(icon: Icons.delete_outline,      tooltip: 'Delete', onTap: () => onDelete(c)),
                      const SizedBox(width: 4),
                      _MoreMenu(
                        campaign: c,
                        onView:   () => onView(c),
                        onEdit:   () => onEdit(c),
                        onDelete: () => onDelete(c),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isLast) Divider(height: 1, color: divCol),
          ],
        );
      }).toList(),
    );
  }

  String _num(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _MobileStat extends StatelessWidget {
  final String label;
  final String value;

  const _MobileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: AppTheme.textPrimary(brightness),   fontSize: 13, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(color: AppTheme.textSecondary(brightness), fontSize: 10)),
      ],
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = _hovered
        ? AppTheme.primaryLighter(brightness)
        : AppTheme.surfaceVariant(brightness);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            ),
            child: Icon(widget.icon, size: 14, color: AppTheme.textPrimary(brightness)),
          ),
        ),
      ),
    );
  }
}

// ─── More menu ────────────────────────────────────────────────────────────────

class _MoreMenu extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MoreMenu({
    required this.campaign,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final menuBg     = AppTheme.surfaceColor(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final iconCol    = AppTheme.textPrimary(brightness);
    final btnBg      = AppTheme.surfaceVariant(brightness);

    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      color: menuBg,
      elevation: 4,
      onSelected: (value) {
        switch (value) {
          case 'view':      onView();  break;
          case 'edit':      onEdit();  break;
          case 'duplicate': _duplicate(context, campaign); break;
          case 'toggle':    _toggleStatus(context, campaign); break;
          case 'delete':    onDelete(); break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'view', child: Text('View Details',   style: TextStyle(fontSize: 13, color: textPri))),
        PopupMenuItem(value: 'edit', child: Text('Edit Campaign',  style: TextStyle(fontSize: 13, color: textPri))),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(children: [
            Icon(Icons.copy_outlined, size: 16, color: iconCol),
            const SizedBox(width: 8),
            Text('Duplicate', style: TextStyle(fontSize: 13, color: textPri)),
          ]),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(children: [
            Icon(
              campaign.status == AppConstants.statusActive
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              size: 16,
              color: iconCol,
            ),
            const SizedBox(width: 8),
            Text(
              campaign.status == AppConstants.statusActive ? 'Pause Campaign' : 'Activate Campaign',
              style: TextStyle(fontSize: 13, color: textPri),
            ),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
            const SizedBox(width: 8),
            Text('Delete', style: TextStyle(fontSize: 13, color: AppColors.danger)),
          ]),
        ),
      ],
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
        child: Icon(Icons.more_vert, size: 16, color: AppColors.primary),
      ),
    );
  }

  void _duplicate(BuildContext context, Campaign campaign) {
    final duplicate = Campaign(
      id: CampaignRepository.nextId(),
      name: '${campaign.name} (Copy)',
      description: campaign.description,
      targetAudience: campaign.targetAudience,
      notes: campaign.notes,
      objective: campaign.objective,
      channels: campaign.channels,
      status: AppConstants.statusDraft,
      startDate: campaign.startDate,
      endDate: campaign.endDate,
      budget: campaign.budget,
      spent: 0,
      leads: 0,
      conversions: 0,
      impressions: 0,
      roi: 0,
      activities: const [],
      coupons: const [],
      expenses: const [],
    );
    CampaignRepository.add(duplicate);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Campaign duplicated successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushReplacementNamed(AppRoutes.campaigns);
  }

  void _toggleStatus(BuildContext context, Campaign campaign) {
    final newStatus = campaign.status == AppConstants.statusActive
        ? AppConstants.statusPaused
        : AppConstants.statusActive;
    final updated = campaign.copyWith(status: newStatus);
    CampaignRepository.update(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Campaign ${newStatus == AppConstants.statusActive ? "activated" : "paused"}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pushReplacementNamed(AppRoutes.campaigns);
  }
}

// ─── Pagination ───────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int total;
  final int pageSize;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onPageChanged;

  const _Pagination({
    required this.total,
    required this.pageSize,
    required this.currentPage,
    required this.totalPages,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final textSec    = AppTheme.textSecondary(brightness);
    final textPri    = AppTheme.textPrimary(brightness);
    final pageBg     = AppTheme.surfaceVariant(brightness);

    final start = total == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final end   = (currentPage * pageSize).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Text(
            'Showing $start to $end of $total campaigns',
            style: TextStyle(color: textSec, fontSize: 12),
          ),
          const Spacer(),
          Row(
            children: List.generate(totalPages, (index) {
              final page     = index + 1;
              final isActive = page == currentPage;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () {
                    if (onPageChanged != null && !isActive) onPageChanged!(page);
                  },
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : pageBg,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      border: Border.all(color: isActive ? AppColors.primary : borderCol),
                    ),
                    child: Center(
                      child: Text(
                        '$page',
                        style: TextStyle(
                          color: isActive ? Colors.white : textPri,
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: pageBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Text('$pageSize', style: TextStyle(color: textPri, fontSize: 12)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 16, color: textSec),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg     = AppTheme.cardColor(brightness);
    final borderCol  = AppTheme.border(brightness);
    final iconCol    = AppTheme.border(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, size: 48, color: iconCol),
          const SizedBox(height: 12),
          Text(
            'No campaigns found',
            style: TextStyle(
              color: AppTheme.textSecondary(brightness),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search or filters',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Campaign'),
          ),
        ],
      ),
    );
  }
}
