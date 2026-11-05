import 'package:flutter/material.dart';
import '../../services/access_service.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/notification_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsScreen
//
// Full-featured notification centre with:
//   • Filter pills (All · Unread · per-category)
//   • In-memory search
//   • Mark as read / unread / mark all read
//   • Delete with snackbar confirmation
//   • Navigation to related module where a route exists
//   • Empty state for zero results
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'All';

  static const List<String> _filterLabels = [
    'All',
    'Unread',
    'Campaigns',
    'Leads',
    'Customers',
    'Budget',
    'Automation',
    'Reports',
    'System',
  ];

  // ── Derived state ──────────────────────────────────────────────────────────

  List<NotificationModel> get _allNotifications =>
      NotificationRepository.getAll();

  int get _totalUnread => NotificationRepository.unreadCount;

  List<NotificationModel> get _filtered {
    final all = _allNotifications;
    final q = _searchQuery.toLowerCase();

    return all.where((n) {
      // Category / read filter
      bool matchesFilter;
      switch (_activeFilter) {
        case 'Unread':
          matchesFilter = !n.isRead;
          break;
        case 'Campaigns':
          matchesFilter = n.category == NotificationCategory.campaign;
          break;
        case 'Leads':
          matchesFilter = n.category == NotificationCategory.lead;
          break;
        case 'Customers':
          matchesFilter = n.category == NotificationCategory.customer;
          break;
        case 'Budget':
          matchesFilter = n.category == NotificationCategory.budget;
          break;
        case 'Automation':
          matchesFilter = n.category == NotificationCategory.automation;
          break;
        case 'Reports':
          matchesFilter = n.category == NotificationCategory.report;
          break;
        case 'System':
          matchesFilter = n.category == NotificationCategory.system;
          break;
        default: // 'All'
          matchesFilter = true;
      }

      // Search filter
      final matchesSearch = q.isEmpty ||
          n.title.toLowerCase().contains(q) ||
          n.message.toLowerCase().contains(q) ||
          n.category.label.toLowerCase().contains(q);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _toggleRead(NotificationModel n) {
    setState(() {
      if (n.isRead) {
        NotificationRepository.markAsUnread(n.id);
      } else {
        NotificationRepository.markAsRead(n.id);
      }
    });
    _showSnack(n.isRead ? 'Marked as unread' : 'Marked as read');
  }

  void _delete(NotificationModel n) {
    if (!AccessService.requireDelete(context, 'Notifications')) return;
    setState(() => NotificationRepository.delete(n.id));
    _showSnack('Notification deleted');
  }

  void _markAllRead() {
    setState(() => NotificationRepository.markAllAsRead());
    _showSnack('All notifications marked as read');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
    );
  }

  void _navigateTo(NotificationModel n) {
    final route = n.category.route;
    if (route == null) return;
    // Mark read on tap
    setState(() => NotificationRepository.markAsRead(n.id));
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Plain sticky header (no SliverPersistentHeader) ───────────────
        _NotificationsHeaderSurface(
          brightness: brightness,
          unreadCount: _totalUnread,
          searchController: _searchController,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          onMarkAllRead: _markAllRead,
          onOpenSettings: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.settings),
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
                // ── Filter pills ───────────────────────────────────────────
                _FilterPillBar(
                  labels: _filterLabels,
                  active: _activeFilter,
                  onSelect: (f) => setState(() => _activeFilter = f),
                ),

                const SizedBox(height: AppConstants.itemSpacing),

                // ── List card ──────────────────────────────────────────────
                _NotificationListCard(
                  notifications: filtered,
                  onToggleRead: _toggleRead,
                  onDelete: _delete,
                  onNavigate: _navigateTo,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationsHeaderSurface — replaces the SliverPersistentHeaderDelegate.
// Plain StatelessWidget; no sliver geometry constraints.
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsHeaderSurface extends StatelessWidget {
  final int unreadCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMarkAllRead;
  final VoidCallback onOpenSettings;
  final Brightness brightness;

  const _NotificationsHeaderSurface({
    required this.unreadCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onMarkAllRead,
    required this.onOpenSettings,
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
          child: _NotificationsHeader(
            unreadCount: unreadCount,
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            onMarkAllRead: onMarkAllRead,
            onOpenSettings: onOpenSettings,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationsHeader
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsHeader extends StatelessWidget {
  final int unreadCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMarkAllRead;
  final VoidCallback onOpenSettings;

  const _NotificationsHeader({
    required this.unreadCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onMarkAllRead,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

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
          child: const Icon(Icons.notifications_outlined,
              size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(
                          AppConstants.radiusSmall),
                    ),
                    child: Text(
                      '$unreadCount unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              'Stay informed about important marketing activities.',
              style: TextStyle(color: textSec, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ],
    );

    // Search field — fixed width on wide, fills row on narrow.
    Widget searchField = SizedBox(
      height: 38,
      child: TextField(
        controller: searchController,
        style: TextStyle(
            fontSize: 13, color: AppTheme.textPrimary(brightness)),
        decoration: InputDecoration(
          hintText: 'Search notifications…',
          hintStyle: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary(brightness)),
          prefixIcon: Icon(Icons.search,
              size: 18, color: AppTheme.iconColor(brightness)),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close,
                      size: 16,
                      color: AppTheme.iconColor(brightness)),
                  onPressed: () {
                    searchController.clear();
                    onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.inputFill(brightness),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: AppTheme.border(brightness)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: AppTheme.border(brightness)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMedium),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        onChanged: onSearchChanged,
      ),
    );

    final actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onMarkAllRead,
          icon: const Icon(Icons.done_all, size: 16),
          label: const Text('Mark All as Read'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined, size: 16),
          label: const Text('Settings'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );

    // LayoutBuilder reads the real available content width — not MediaQuery
    // full-screen width — so the layout switch is correct whether the
    // AI panel is open or closed.
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 680;

      if (narrow) {
        // Narrow: title on top row, controls (search + buttons) in second row.
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                actionButtons,
              ],
            ),
          ],
        );
      }

      // Wide: everything on one row.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: titleBlock),
          const SizedBox(width: 12),
          SizedBox(width: 200, child: searchField),
          const SizedBox(width: 8),
          // Wrap in Flexible so action buttons shrink/clip rather than overflow
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: actionButtons,
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterPillBar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPillBar extends StatelessWidget {
  final List<String> labels;
  final String active;
  final ValueChanged<String> onSelect;

  const _FilterPillBar({
    required this.labels,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.map((label) {
          final isActive = label == active;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterPill(
              label: label,
              isActive: isActive,
              onTap: () => onSelect(label),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterPill extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Semantics(
      button: true,
      selected: widget.isActive,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.primary
                  : _hovered
                      ? AppTheme.primaryLighter(brightness)
                      : AppTheme.surfaceColor(brightness),
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: widget.isActive
                    ? AppColors.primary
                    : AppTheme.border(brightness),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isActive
                    ? Colors.white
                    : AppTheme.textPrimary(brightness),
                fontSize: 13,
                fontWeight: widget.isActive
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationListCard
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationListCard extends StatelessWidget {
  final List<NotificationModel> notifications;
  final ValueChanged<NotificationModel> onToggleRead;
  final ValueChanged<NotificationModel> onDelete;
  final ValueChanged<NotificationModel> onNavigate;

  const _NotificationListCard({
    required this.notifications,
    required this.onToggleRead,
    required this.onDelete,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: notifications.isEmpty
          ? _EmptyState()
          : Column(
              children: List.generate(notifications.length, (i) {
                final n = notifications[i];
                final isLast = i == notifications.length - 1;
                return Column(
                  children: [
                    _NotificationRow(
                      notification: n,
                      onToggleRead: () => onToggleRead(n),
                      onDelete: () => onDelete(n),
                      onNavigate: n.category.route != null
                          ? () => onNavigate(n)
                          : null,
                    ),
                    if (!isLast)
                      Divider(
                          height: 1,
                          thickness: 1,
                          color: AppTheme.divider(brightness)),
                  ],
                );
              }),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationRow
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationRow extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;
  final VoidCallback? onNavigate;

  const _NotificationRow({
    required this.notification,
    required this.onToggleRead,
    required this.onDelete,
    this.onNavigate,
  });

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> {
  bool _hovered = false;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final n = widget.notification;
    final cat = n.category;
    final isUnread = !n.isRead;
    final canNavigate = widget.onNavigate != null;

    return Semantics(
      label:
          '${isUnread ? "Unread notification" : "Notification"}: ${n.title}. ${n.message}',
      button: canNavigate,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor:
            canNavigate ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          color: isUnread
              ? (_hovered
                  ? AppTheme.primaryLighter(brightness)
                  : AppColors.primaryLight.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.35))
              : (_hovered ? AppTheme.surfaceVariant(brightness) : Colors.transparent),
          child: InkWell(
            onTap: canNavigate ? widget.onNavigate : null,
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.cardPadding,
                  vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Unread dot indicator ──────────────────────────────
                  SizedBox(
                    width: 10,
                    child: isUnread
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // ── Category icon ─────────────────────────────────────
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                          AppConstants.radiusMedium),
                    ),
                    child: Icon(cat.icon, size: 20, color: cat.color),
                  ),
                  const SizedBox(width: 12),

                  // ── Text content ──────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppTheme.textPrimary(brightness),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Category chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSmall),
                              ),
                              child: Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cat.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Message
                        Text(
                          n.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(brightness),
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Time + navigate hint
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined,
                                size: 12,
                                color: AppTheme.textSecondary(brightness)),
                            const SizedBox(width: 4),
                            Text(
                              _relativeTime(n.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary(brightness),
                              ),
                            ),
                            if (canNavigate) ...[
                              const SizedBox(width: 8),
                              Text(
                                '· Tap to view',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Action menu ───────────────────────────────────────
                  _RowActionMenu(
                    isRead: n.isRead,
                    onToggleRead: widget.onToggleRead,
                    onDelete: widget.onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RowActionMenu  — the three-dot popup per row
// ─────────────────────────────────────────────────────────────────────────────

class _RowActionMenu extends StatelessWidget {
  final bool isRead;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  const _RowActionMenu({
    required this.isRead,
    required this.onToggleRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          size: 18, color: AppTheme.iconColor(brightness)),
      tooltip: 'More options',
      offset: const Offset(0, 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      color: AppTheme.surfaceColor(brightness),
      elevation: 4,
      onSelected: (v) {
        if (v == 'toggle') onToggleRead();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'toggle',
          child: Row(children: [
            Icon(
              isRead
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
              size: 16,
              color: AppTheme.textPrimary(brightness),
            ),
            const SizedBox(width: 10),
            Text(
              isRead ? 'Mark as Unread' : 'Mark as Read',
              style: const TextStyle(fontSize: 13),
            ),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline,
                size: 16, color: AppColors.danger),
            const SizedBox(width: 10),
            const Text('Delete',
                style: TextStyle(fontSize: 13, color: AppColors.danger)),
          ]),
        ),
      ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryLighter(brightness),
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusXL),
              ),
              child: const Icon(Icons.notifications_none_outlined,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(brightness)),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up.\nTry a different filter or search term.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary(brightness),
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
