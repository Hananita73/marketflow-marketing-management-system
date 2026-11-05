import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/user_role_models.dart';
import '../../services/auth_service.dart';
import '../auth/user_profile_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single sidebar navigation item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Full list of navigation items — order matches the specification
// ─────────────────────────────────────────────────────────────────────────────

const List<_NavItem> _mainNavItems = [
  _NavItem(label: AppConstants.navDashboard,      icon: Icons.dashboard_outlined,        route: AppRoutes.dashboard),
  _NavItem(label: AppConstants.navCampaigns,      icon: Icons.campaign_outlined,         route: AppRoutes.campaigns),
  _NavItem(label: AppConstants.navCustomers,      icon: Icons.people_outline,            route: AppRoutes.customers),
  _NavItem(label: AppConstants.navLeads,          icon: Icons.person_search_outlined,    route: AppRoutes.leads),
  _NavItem(label: AppConstants.navOpportunities,  icon: Icons.trending_up_outlined,      route: AppRoutes.opportunities),
  _NavItem(label: AppConstants.navInfluencers,    icon: Icons.star_outline,              route: AppRoutes.influencers),
  _NavItem(label: AppConstants.navContent,        icon: Icons.article_outlined,          route: AppRoutes.content),
  _NavItem(label: AppConstants.navPromotions,     icon: Icons.local_offer_outlined,      route: AppRoutes.promotions),
  _NavItem(label: AppConstants.navBudget,         icon: Icons.account_balance_wallet_outlined, route: AppRoutes.budget),
  _NavItem(label: AppConstants.navCommunications, icon: Icons.chat_bubble_outline,       route: AppRoutes.communications),
  _NavItem(label: AppConstants.navAutomation,     icon: Icons.settings_suggest_outlined, route: AppRoutes.automation),
  _NavItem(label: AppConstants.navReports,        icon: Icons.bar_chart_outlined,        route: AppRoutes.reports),
];

const List<_NavItem> _bottomNavItems = [
  _NavItem(label: AppConstants.navUsers, icon: Icons.manage_accounts_outlined, route: AppRoutes.users),
];

// ─────────────────────────────────────────────────────────────────────────────
// AppSidebar
// ─────────────────────────────────────────────────────────────────────────────

class AppSidebar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final bool isDrawer;

  /// When true the sidebar renders as a narrow 64 px icon rail.
  /// Only used on desktop (isDrawer is always false in that context).
  final bool collapsed;

  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    this.isDrawer = false,
    this.collapsed = false,
  });

  // ── collapsed rail width ─────────────────────────────────────────────────
  static const double railWidth = 64.0;

  /// Returns the visible nav items filtered by the user's permissions.
  List<_NavItem> _visibleItems(
    List<_NavItem> items,
    AuthService auth,
  ) {
    return items.where((item) {
      // Dashboard is always visible.
      if (item.route == AppRoutes.dashboard) return true;
      return auth.hasPermission(item.label, PermissionType.view);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final bgColor     = AppTheme.sidebarBg(brightness);
    final divColor    = AppTheme.divider(brightness);
    final borderColor = AppTheme.border(brightness);
    final auth        = UserProfileProvider.of(context);
    final mainItems   = _visibleItems(_mainNavItems, auth);
    final bottomItems = _visibleItems(_bottomNavItems, auth);
    final userName    = auth.currentName;
    final userRole    = UserRoleRepository.roleDisplayName(auth.currentRole);
    final userInitials = auth.currentInitials;

    // In collapsed mode render a compact icon-only rail.
    if (collapsed && !isDrawer) {
      return Container(
        width: railWidth,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(right: BorderSide(color: borderColor, width: 1)),
        ),
        child: Column(
          children: [
            // Brand icon — just the purple "M" badge
            SizedBox(
              height: AppConstants.topBarHeight,
              child: Center(
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('M',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                  ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: divColor),

            // Nav icons
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ...mainItems.map((item) => _RailIcon(
                        item: item,
                        isActive: currentRoute == item.route,
                        onTap: () => onNavigate(item.route),
                      )),
                  if (bottomItems.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Divider(thickness: 1, color: divColor, indent: 12, endIndent: 12),
                    ...bottomItems.map((item) => _RailIcon(
                          item: item,
                          isActive: currentRoute == item.route,
                          onTap: () => onNavigate(item.route),
                        )),
                  ],
                ],
              ),
            ),

            // User avatar only
            Divider(height: 1, thickness: 1, color: divColor),
            _RailUserIcon(
              onTap: () => onNavigate(AppRoutes.profile),
              userName: userName,
              userInitials: userInitials,
            ),
          ],
        ),
      );
    }

    // ── Full expanded sidebar ───────────────────────────────────────────────
    final content = Container(
      width: AppConstants.sidebarWidth,
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarBrand(),
          Divider(height: 1, thickness: 1, color: divColor),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...mainItems.map(
                  (item) => _NavTile(
                    item: item,
                    isActive: currentRoute == item.route,
                    onTap: () => onNavigate(item.route),
                  ),
                ),
                if (bottomItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Divider(thickness: 1, color: divColor),
                  ),
                  ...bottomItems.map(
                    (item) => _NavTile(
                      item: item,
                      isActive: currentRoute == item.route,
                      onTap: () => onNavigate(item.route),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: divColor),
          _SidebarUserCard(
            onTap: () => onNavigate(AppRoutes.profile),
            userName: userName,
            userRole: userRole,
            userInitials: userInitials,
          ),
        ],
      ),
    );

    if (isDrawer) return SafeArea(child: content);

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand / logo header
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return Container(
      height: AppConstants.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Purple "M" badge — always purple
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MarketFlow',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    color: textSec,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
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

// ─────────────────────────────────────────────────────────────────────────────
// Individual nav tile with hover + active states
// ─────────────────────────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active     = widget.isActive;
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;

    // Active bg: purple tint (darker in dark mode for visibility)
    final activeBg  = isDark ? const Color(0xFF2A2650) : AppColors.sidebarActive;
    final hoverBg   = isDark ? const Color(0xFF211F35) : AppColors.sidebarHover;

    Color bgColor = Colors.transparent;
    if (active) {
      bgColor = activeBg;
    } else if (_hovered) {
      bgColor = hoverBg;
    }

    final iconColor = active ? AppColors.sidebarActiveText : AppTheme.textSecondary(brightness);
    final textColor = active ? AppColors.sidebarActiveText : AppTheme.textPrimary(brightness);
    final fontWeight = active ? FontWeight.w600 : FontWeight.w400;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: Row(
            children: [
              // Active indicator bar
              AnimatedContainer(
                duration: AppConstants.animFast,
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(widget.item.icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: fontWeight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User card pinned at the bottom of the sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarUserCard extends StatefulWidget {
  final VoidCallback onTap;
  final String userName;
  final String userRole;
  final String userInitials;
  const _SidebarUserCard({
    required this.onTap,
    required this.userName,
    required this.userRole,
    required this.userInitials,
  });

  @override
  State<_SidebarUserCard> createState() => _SidebarUserCardState();
}

class _SidebarUserCardState extends State<_SidebarUserCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;
    final hoverBg    = isDark ? const Color(0xFF211F35) : AppColors.sidebarHover;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: _hovered ? hoverBg : Colors.transparent,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  widget.userInitials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
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
                      widget.userName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.userRole,
                      style: TextStyle(
                        color: textSec,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, size: 16, color: textSec),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RailIcon — icon-only nav tile used in the collapsed sidebar rail
// ─────────────────────────────────────────────────────────────────────────────

class _RailIcon extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _RailIcon({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_RailIcon> createState() => _RailIconState();
}

class _RailIconState extends State<_RailIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active     = widget.isActive;
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;

    final activeBg = isDark ? const Color(0xFF2A2650) : AppColors.sidebarActive;
    final hoverBg  = isDark ? const Color(0xFF211F35) : AppColors.sidebarHover;

    Color bgColor = Colors.transparent;
    if (active) {
      bgColor = activeBg;
    } else if (_hovered) {
      bgColor = hoverBg;
    }

    final iconColor = active
        ? AppColors.sidebarActiveText
        : AppTheme.textSecondary(brightness);

    return Tooltip(
      message: widget.item.label,
      preferBelow: false,
      verticalOffset: 0,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      textStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary(brightness),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            width: AppSidebar.railWidth - 16,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(widget.item.icon, size: 18, color: iconColor),
                // Active indicator dot at the top-right
                if (active)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RailUserIcon — avatar-only user tile for the collapsed rail
// ─────────────────────────────────────────────────────────────────────────────

class _RailUserIcon extends StatefulWidget {
  final VoidCallback onTap;
  final String userName;
  final String userInitials;
  const _RailUserIcon({
    required this.onTap,
    required this.userName,
    required this.userInitials,
  });

  @override
  State<_RailUserIcon> createState() => _RailUserIconState();
}

class _RailUserIconState extends State<_RailUserIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;
    final hoverBg    = isDark ? const Color(0xFF211F35) : AppColors.sidebarHover;

    return Tooltip(
      message: widget.userName,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            height: 56,
            color: _hovered ? hoverBg : Colors.transparent,
            child: Center(
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  widget.userInitials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
