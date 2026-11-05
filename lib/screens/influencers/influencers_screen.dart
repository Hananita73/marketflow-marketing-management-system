import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/influencer.dart';
import '../../widgets/badges/status_badge.dart';

class InfluencersScreen extends StatefulWidget {
  const InfluencersScreen({super.key});
  @override
  State<InfluencersScreen> createState() => _InfluencersScreenState();
}

class _InfluencersScreenState extends State<InfluencersScreen> {
  // Data source: InfluencerRepository (Supabase-backed). The local copy below
  // is rebuilt via [_reload] after every mutation so setState picks up changes
  // made through [InfluencerRepository].
  List<Influencer> _influencers = List.from(InfluencerRepository.getAll());

  void _reload() => _influencers = List.from(InfluencerRepository.getAll());

  String _searchQuery = '';
  String _platformFilter = 'All';
  String _statusFilter = 'All';

  static const List<String> _platforms = [
    'All', 'Instagram', 'TikTok', 'YouTube', 'Twitter', 'Facebook', 'Other',
  ];
  static const List<String> _statuses = [
    'All', 'Active', 'Paused', 'Completed',
  ];

  List<Influencer> get _filtered {
    return _influencers.where((inf) {
      final q = _searchQuery.toLowerCase();
      final matchQ = q.isEmpty ||
          inf.name.toLowerCase().contains(q) ||
          inf.handle.toLowerCase().contains(q) ||
          inf.category.toLowerCase().contains(q) ||
          inf.campaignName.toLowerCase().contains(q);
      final matchP = _platformFilter == 'All' || inf.platform == _platformFilter;
      final matchS = _statusFilter == 'All' || inf.status == _statusFilter;
      return matchQ && matchP && matchS;
    }).toList();
  }

  // ── Stats ────────────────────────────────────────────────────────────────
  int get _activeCount =>
      _influencers.where((i) => i.status == AppConstants.statusActive).length;
  String get _totalReach {
    final total = _influencers.fold<int>(0, (s, i) => s + i.followers);
    if (total >= 1000000) return '${(total / 1000000).toStringAsFixed(1)}M';
    if (total >= 1000) return '${(total / 1000).toStringAsFixed(0)}K';
    return '$total';
  }
  String get _avgEngagement {
    if (_influencers.isEmpty) return '0.0%';
    final avg = _influencers.fold(0.0, (s, i) => s + i.engagementRate) /
        _influencers.length;
    return '${avg.toStringAsFixed(1)}%';
  }
  String get _avgRoi => '4.2x';

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showForm({Influencer? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final handleCtrl = TextEditingController(text: existing?.handle ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    final campaignCtrl =
        TextEditingController(text: existing?.campaignName ?? '');
    final followersCtrl = TextEditingController(
        text: existing != null ? '${existing.followers}' : '');
    final engCtrl = TextEditingController(
        text: existing != null
            ? existing.engagementRate.toStringAsFixed(1)
            : '');
    String platform = existing?.platform ?? 'Instagram';
    String status = existing?.status ?? AppConstants.statusActive;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final brightness = Theme.of(ctx).brightness;
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusXL)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
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
                            : Icons.person_add_outlined,
                        title: isEdit ? 'Edit Influencer' : 'Add Influencer',
                      ),
                      const Divider(height: 28),
                      _TwoCol(
                        left: _FormField(
                          label: 'Full Name *',
                          child: TextFormField(
                            controller: nameCtrl,
                            decoration: _inputDec('e.g. Abel Tafesse', brightness),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                            style: _inputStyle(brightness),
                          ),
                        ),
                        right: _FormField(
                          label: 'Handle',
                          child: TextFormField(
                            controller: handleCtrl,
                            decoration: _inputDec('@username', brightness),
                            style: _inputStyle(brightness),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TwoCol(
                        left: _FormField(
                          label: 'Platform',
                          child: _DropdownField(
                            value: platform,
                            items: const [
                              'Instagram', 'TikTok', 'YouTube',
                              'Twitter', 'Facebook', 'Other'
                            ],
                            onChanged: (v) => setLocal(() => platform = v),
                          ),
                        ),
                        right: _FormField(
                          label: 'Category',
                          child: TextFormField(
                            controller: categoryCtrl,
                            decoration: _inputDec('e.g. Lifestyle', brightness),
                            style: _inputStyle(brightness),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TwoCol(
                        left: _FormField(
                          label: 'Followers *',
                          child: TextFormField(
                            controller: followersCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDec('245000', brightness),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                            style: _inputStyle(brightness),
                          ),
                        ),
                        right: _FormField(
                          label: 'Engagement %',
                          child: TextFormField(
                            controller: engCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: _inputDec('5.8', brightness),
                            style: _inputStyle(brightness),
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
                          label: 'Status',
                          child: _DropdownField(
                            value: status,
                            items: const ['Active', 'Paused', 'Completed'],
                            onChanged: (v) => setLocal(() => status = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white),
                            onPressed: () {
                              if (!formKey.currentState!.validate()) return;
                              final inf = Influencer(
                                id: isEdit
                                    ? existing.id
                                    : InfluencerRepository.nextId(),
                                name: nameCtrl.text.trim(),
                                handle: handleCtrl.text.trim().isEmpty
                                    ? '@${nameCtrl.text.trim().toLowerCase().replaceAll(' ', '')}'
                                    : handleCtrl.text.trim(),
                                platform: platform,
                                followers: int.tryParse(followersCtrl.text.trim()) ?? 0,
                                engagementRate:
                                    double.tryParse(engCtrl.text.trim()) ?? 0.0,
                                category: categoryCtrl.text.trim().isEmpty
                                    ? 'General'
                                    : categoryCtrl.text.trim(),
                                status: status,
                                costPerPost: isEdit ? existing.costPerPost : 0,
                                campaignName: campaignCtrl.text.trim().isEmpty
                                    ? '—'
                                    : campaignCtrl.text.trim(),
                                avatarInitials: nameCtrl.text.trim().length >= 2
                                    ? nameCtrl.text
                                        .trim()
                                        .split(' ')
                                        .take(2)
                                        .map((w) => w[0].toUpperCase())
                                        .join()
                                    : nameCtrl.text.trim()[0].toUpperCase(),
                              );
                              if (!AccessService.requireSave(context, isEdit, 'Influencers')) return;
                              setState(() {
                                if (isEdit) {
                                  InfluencerRepository.update(inf);
                                } else {
                                  InfluencerRepository.add(inf);
                                }
                                _reload();
                              });
                              Navigator.pop(ctx);
                              _showSnack(isEdit
                                  ? 'Influencer updated'
                                  : 'Influencer added');
                            },
                            child: Text(isEdit ? 'Save Changes' : 'Add Influencer'),
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

  void _confirmDelete(Influencer inf) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge)),
        title: const Text('Remove Influencer',
            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
        content: Text('Remove "${inf.name}" from your roster?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              if (!AccessService.requireDelete(context, 'Influencers')) return;
              InfluencerRepository.remove(inf.id);
              setState(_reload);
              Navigator.pop(ctx);
              _showSnack('Influencer removed');
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
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
                _StatsRow(items: [
                  _StatItem('Active Influencers', '$_activeCount',
                      Icons.people_outline, AppColors.primary),
                  _StatItem('Total Reach', _totalReach,
                      Icons.bar_chart_rounded, AppColors.info),
                  _StatItem('Avg Engagement', _avgEngagement,
                      Icons.favorite_border_rounded, AppColors.success),
                  _StatItem('Campaign ROI', _avgRoi,
                      Icons.trending_up_rounded, AppColors.warning),
                ]),
                const SizedBox(height: AppConstants.sectionSpacing),

                _SearchAndFilters(
                  searchQuery: _searchQuery,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  platformFilter: _platformFilter,
                  platforms: _platforms,
                  onPlatformChanged: (v) =>
                      setState(() => _platformFilter = v),
                  statusFilter: _statusFilter,
                  statuses: _statuses,
                  onStatusChanged: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(height: 20),

                filtered.isEmpty
                    ? _EmptyState(
                        icon: Icons.people_outline,
                        message: 'No influencers found',
                        hint: 'Try adjusting your search or filter',
                      )
                    : _InfluencerGrid(
                        influencers: filtered,
                        onEdit: (inf) => _showForm(existing: inf),
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
// Influencer Grid
// ─────────────────────────────────────────────────────────────────────────────
class _InfluencerGrid extends StatelessWidget {
  final List<Influencer> influencers;
  final void Function(Influencer) onEdit;
  final void Function(Influencer) onDelete;

  const _InfluencerGrid({
    required this.influencers,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 1100 ? 3 : w >= 700 ? 2 : 1;
      final spacing = AppConstants.itemSpacing;
      final cardW = (w - (cols - 1) * spacing) / cols;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: influencers
            .map((inf) => SizedBox(
                width: cardW,
                child: _InfluencerCard(
                    influencer: inf, onEdit: onEdit, onDelete: onDelete)))
            .toList(),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Influencer Card
// ─────────────────────────────────────────────────────────────────────────────
class _InfluencerCard extends StatefulWidget {
  final Influencer influencer;
  final void Function(Influencer) onEdit;
  final void Function(Influencer) onDelete;

  const _InfluencerCard({
    required this.influencer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_InfluencerCard> createState() => _InfluencerCardState();
}

class _InfluencerCardState extends State<_InfluencerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final inf = widget.influencer;
    final platformColor = _platformColor(inf.platform);
    final platformIcon = _platformIcon(inf.platform);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(brightness),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
              color: _hovered
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppTheme.border(brightness)),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + name + badge + menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: inf.avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    inf.avatarInitials,
                    style: TextStyle(
                        color: inf.avatarColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inf.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary(brightness)),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(inf.handle,
                          style: TextStyle(
                              color: AppTheme.textSecondary(brightness), fontSize: 12)),
                    ],
                  ),
                ),
                StatusBadge(status: inf.status),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      size: 18, color: AppTheme.iconColor(brightness)),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMedium)),
                  onSelected: (v) {
                    if (v == 'edit') widget.onEdit(inf);
                    if (v == 'delete') widget.onDelete(inf);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined,
                              size: 15, color: AppColors.info),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(fontSize: 13)),
                        ])),
                    PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.person_remove_outlined,
                              size: 15, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text('Remove',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.danger)),
                        ])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Platform pill
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: platformColor.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(platformIcon, size: 13, color: platformColor),
                    const SizedBox(width: 5),
                    Text(inf.platform,
                        style: TextStyle(
                            color: platformColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant(brightness),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Text(inf.category,
                    style: TextStyle(
                        color: AppTheme.textSecondary(brightness),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppTheme.divider(brightness)),
            const SizedBox(height: 14),

            // Stats row
            Row(children: [
              Expanded(
                  child: _CardStat(
                      label: 'Followers', value: inf.followersLabel)),
              Expanded(
                  child: _CardStat(
                      label: 'Engagement',
                      value: '${inf.engagementRate.toStringAsFixed(1)}%')),
            ]),
            const SizedBox(height: 10),

            // Campaign chip
            Row(children: [
              Icon(Icons.campaign_outlined,
                  size: 13, color: AppTheme.iconColor(brightness)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(inf.campaignName,
                    style: TextStyle(
                        color: AppTheme.textSecondary(brightness), fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 12),

            // Engagement bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (inf.engagementRate / 10).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppTheme.border(brightness),
                valueColor: AlwaysStoppedAnimation<Color>(
                    inf.engagementRate >= 7
                        ? AppColors.success
                        : inf.engagementRate >= 4
                            ? AppColors.warning
                            : AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String label;
  final String value;
  const _CardStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              color: AppTheme.textPrimary(brightness),
              fontWeight: FontWeight.w700,
              fontSize: 15)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(color: AppTheme.textSecondary(brightness), fontSize: 11)),
    ]);
  }
}

Color _platformColor(String p) {
  switch (p) {
    case 'Instagram': return const Color(0xFFE1306C);
    case 'TikTok':    return const Color(0xFF010101);
    case 'YouTube':   return const Color(0xFFFF0000);
    case 'Twitter':   return const Color(0xFF1DA1F2);
    case 'Facebook':  return const Color(0xFF1877F2);
    default:          return AppColors.primary;
  }
}

IconData _platformIcon(String p) {
  switch (p) {
    case 'Instagram': return Icons.camera_alt_outlined;
    case 'TikTok':    return Icons.music_note_outlined;
    case 'YouTube':   return Icons.play_circle_outline;
    case 'Twitter':   return Icons.alternate_email;
    case 'Facebook':  return Icons.thumb_up_outlined;
    default:          return Icons.public_outlined;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + Filter Bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchAndFilters extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String platformFilter;
  final List<String> platforms;
  final ValueChanged<String> onPlatformChanged;
  final String statusFilter;
  final List<String> statuses;
  final ValueChanged<String> onStatusChanged;

  const _SearchAndFilters({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.platformFilter,
    required this.platforms,
    required this.onPlatformChanged,
    required this.statusFilter,
    required this.statuses,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      final searchField = SizedBox(
        height: 40,
        child: TextField(
          onChanged: onSearchChanged,
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
          decoration: InputDecoration(
            hintText: 'Search influencers…',
            hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness)),
            prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.iconColor(brightness)),
            filled: true,
            fillColor: AppTheme.inputFill(brightness),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: BorderSide(color: AppTheme.border(brightness))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: BorderSide(color: AppTheme.border(brightness))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      );
      final filters = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterChip(
            label: platformFilter,
            icon: Icons.public_outlined,
            items: platforms,
            onChanged: onPlatformChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: statusFilter,
            icon: Icons.tune_rounded,
            items: statuses,
            onChanged: onStatusChanged,
          ),
        ],
      );

      if (wide) {
        return Row(children: [
          Expanded(child: searchField),
          const SizedBox(width: 12),
          filters,
        ]);
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [searchField, const SizedBox(height: 10), filters]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _FilterChip({
    required this.label,
    required this.icon,
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
          icon: Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.iconColor(brightness)),
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
          dropdownColor: AppTheme.surfaceColor(brightness),
          items: items
              .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)))))
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
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
          title: 'Influencers',
          subtitle: 'Manage influencer partnerships and campaign performance.',
          actionLabel: 'Add Influencer',
          actionIcon: Icons.person_add_outlined,
          onAction: onAction,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page header bar
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
    final textSec    = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (_, cst) {
      final narrow = cst.maxWidth < 580;

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
            child: Icon(actionIcon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: TextStyle(color: textSec, fontSize: 12)),
            ],
          ),
        ],
      );

      final btn = ElevatedButton.icon(
        onPressed: onAction,
        icon: Icon(actionIcon, size: 16),
        label: Text(actionLabel),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      );

      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [titleBlock, const SizedBox(height: 8), btn],
        );
      }
      return Row(children: [titleBlock, const Spacer(), btn]);
    });
  }
}

class _StatsRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 800 ? 4 : w >= 500 ? 2 : 2;
      final spacing = AppConstants.itemSpacing;
      final cardW = (w - (cols - 1) * spacing) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: items
            .map((s) => SizedBox(width: cardW, child: _StatCard(item: s)))
            .toList(),
      );
    });
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
      child: Row(children: [
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
              Text(item.value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(brightness))),
              const SizedBox(height: 2),
              Text(item.title,
                  style: TextStyle(color: AppTheme.textSecondary(brightness), fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  const _EmptyState(
      {required this.icon, required this.message, required this.hint});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
          color: AppTheme.cardColor(brightness),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppTheme.border(brightness))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: AppTheme.textSecondary(brightness).withValues(alpha: 0.25)),
        const SizedBox(height: 12),
        Text(message,
            style: TextStyle(
                color: AppTheme.textSecondary(brightness),
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(hint,
            style: TextStyle(color: AppTheme.textSecondary(brightness), fontSize: 12)),
      ]),
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
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppTheme.primaryLighter(brightness),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(brightness))),
      ),
    ]);
  }
}

class _TwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TwoCol({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 400) {
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
          children: [left, const SizedBox(height: 14), right]);
    });
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(brightness))),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _DropdownField(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: AppTheme.inputFill(brightness),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: AppTheme.border(brightness))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceColor(brightness),
          icon: Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.iconColor(brightness)),
          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)),
          items: items
              .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness)))))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

TextStyle _inputStyle(Brightness brightness) =>
    TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness));

InputDecoration _inputDec(String hint, Brightness brightness) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: AppTheme.textSecondary(brightness)),
      filled: true,
      fillColor: AppTheme.inputFill(brightness),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: AppTheme.border(brightness))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: AppTheme.border(brightness))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
