import 'package:flutter/material.dart';
import '../../core/ai_notifier.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/theme_notifier.dart';
import '../../models/user_role_models.dart';
import '../../widgets/auth/auth_gate.dart';
import '../auth/user_profile_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppTopBar
//
// Sticky bar rendered at the top of the content column in AppLayout.
//
// Layout (left → right):
//   [☰ Menu] [Search — flexible, max 280px] [↻] [⚙] [🌙] [🔔]
//   non-dashboard only → [⋯ More: Print/Edit/Download]
//   [✨ Ask AI — pill on wide, icon on narrow] [User avatar ▾]
//
// The search bar uses a flexible widget with a max-width constraint so it
// never pushes fixed-width icons off-screen. All icon buttons are 38×38px.
// ─────────────────────────────────────────────────────────────────────────────

class AppTopBar extends StatefulWidget implements PreferredSizeWidget {
  final String pageTitle;
  final VoidCallback? onMenuTap;
  final ValueChanged<String> onNavigate;
  final bool isDashboard;

  const AppTopBar({
    super.key,
    required this.pageTitle,
    required this.onNavigate,
    this.onMenuTap,
    this.isDashboard = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppConstants.topBarHeight);

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isRefreshing = false);
      _showSnack('Refreshed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width      = MediaQuery.of(context).size.width;
    // Breakpoints for topbar behaviour:
    //   compact  < 768  → no search, icon-only AI button
    //   medium   < 960  → search visible, icon-only AI button
    //   wide    ≥ 960  → search visible, pill AI button
    final isCompact  = width < AppConstants.mobileBreakpoint;   // 768
    final isWide     = width >= AppConstants.sidebarBreakpoint;  // 960
    final brightness = Theme.of(context).brightness;

    return Container(
      height: AppConstants.topBarHeight,
      decoration: BoxDecoration(
        color: AppTheme.topBarBg(brightness),
        border: Border(
          bottom: BorderSide(color: AppTheme.border(brightness), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Hamburger ─────────────────────────────────────────────────────
          _TopBarIconButton(
            icon: Icons.menu,
            tooltip: 'Toggle menu',
            onTap: widget.onMenuTap ?? () {},
          ),
          const SizedBox(width: 6),

          // ── Search bar — flexible with max width cap ──────────────────────
          if (!isCompact) ...[
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: _SearchBar(
                  controller: _searchController,
                  brightness: brightness,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // ── Spacer pushes right-side actions to the far right ─────────────
          const Spacer(),

          // ── Always-present icons ──────────────────────────────────────────
          _RefreshButton(isRefreshing: _isRefreshing, onTap: _handleRefresh),
          const SizedBox(width: 2),
          _TopBarIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => widget.onNavigate(AppRoutes.settings),
          ),
          const SizedBox(width: 2),
          _ThemeToggleButton(),
          const SizedBox(width: 2),
          _NotificationBell(
            badgeCount: 3,
            onTap: () => widget.onNavigate(AppRoutes.notifications),
          ),

          // ── Non-dashboard extra actions: Print | Edit | Download ────────
          // Below 1100px these collapse into a single ⋯ menu to prevent
          // the topbar Row from overflowing when the AI panel is also open.
          if (!widget.isDashboard) ...[
            const SizedBox(width: 2),
            if (isWide && MediaQuery.of(context).size.width >= 1100) ...[
              _TopBarIconButton(
                icon: Icons.print_outlined,
                tooltip: 'Print',
                onTap: () => _showSnack('Print'),
              ),
              const SizedBox(width: 2),
              _TopBarIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: () => _showSnack('Edit'),
              ),
              const SizedBox(width: 2),
              _TopBarIconButton(
                icon: Icons.download_outlined,
                tooltip: 'Download',
                onTap: () => _showSnack('Download'),
              ),
            ] else
              PopupMenuButton<String>(
                tooltip: 'More actions',
                offset: const Offset(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  side: BorderSide(color: AppTheme.border(brightness)),
                ),
                color: AppTheme.surfaceColor(brightness),
                elevation: 4,
                onSelected: (v) => _showSnack(v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'Print',    child: _menuRow(Icons.print_outlined,    'Print',    brightness)),
                  PopupMenuItem(value: 'Edit',     child: _menuRow(Icons.edit_outlined,     'Edit',     brightness)),
                  PopupMenuItem(value: 'Download', child: _menuRow(Icons.download_outlined, 'Download', brightness)),
                ],
                child: _TopBarIconButton(
                  icon: Icons.more_horiz,
                  tooltip: 'More',
                  onTap: () {},
                ),
              ),
          ],

          // ── ✨ Ask Marketing AI ───────────────────────────────────────────
          const SizedBox(width: 6),
          _AskAiButton(showLabel: isWide),
          const SizedBox(width: 6),

          // ── Profile / user dropdown ───────────────────────────────────────
          _UserAvatarMenu(onNavigate: widget.onNavigate),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Refresh button with animated rotation
// ─────────────────────────────────────────────────────────────────────────────

class _RefreshButton extends StatefulWidget {
  final bool isRefreshing;
  final VoidCallback onTap;
  const _RefreshButton({required this.isRefreshing, required this.onTap});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(_RefreshButton old) {
    super.didUpdateWidget(old);
    if (widget.isRefreshing && !old.isRefreshing) {
      _ctrl.repeat();
    } else if (!widget.isRefreshing && old.isRefreshing) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Tooltip(
      message: widget.isRefreshing ? 'Refreshing…' : 'Refresh',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: widget.isRefreshing
            ? SystemMouseCursors.wait
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.isRefreshing ? null : widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered && !widget.isRefreshing
                  ? AppTheme.hoverFill(brightness)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: RotationTransition(
              turns: _ctrl,
              child: Icon(
                Icons.refresh,
                size: 20,
                color: widget.isRefreshing
                    ? AppColors.primary
                    : AppTheme.iconColor(brightness),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Brightness brightness;
  const _SearchBar({required this.controller, required this.brightness});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    final br        = widget.brightness;
    final fillColor = AppTheme.inputFill(br);
    final borderCol = AppTheme.border(br);
    final textCol   = AppTheme.textPrimary(br);
    final hintCol   = AppTheme.textSecondary(br);

    return SizedBox(
      height: 38,
      child: TextField(
        controller: widget.controller,
        style: TextStyle(fontSize: 13, color: textCol),
        decoration: InputDecoration(
          hintText: 'Search…',
          hintStyle: TextStyle(fontSize: 13, color: hintCol),
          prefixIcon: Icon(Icons.search, size: 18, color: hintCol),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 16, color: hintCol),
                  onPressed: () => setState(() => widget.controller.clear()),
                )
              : null,
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: borderCol),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide: BorderSide(color: borderCol),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification bell with badge
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBell extends StatefulWidget {
  final int badgeCount;
  final VoidCallback onTap;
  const _NotificationBell({required this.badgeCount, required this.onTap});

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _hovered
                ? AppTheme.hoverFill(brightness)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.notifications_outlined,
                  size: 20, color: AppTheme.iconColor(brightness)),
              if (widget.badgeCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        widget.badgeCount > 9
                            ? '9+'
                            : '${widget.badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
// User avatar with dropdown menu
// ─────────────────────────────────────────────────────────────────────────────

class _UserAvatarMenu extends StatelessWidget {
  final ValueChanged<String> onNavigate;
  const _UserAvatarMenu({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final auth = UserProfileProvider.of(context);
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(color: AppTheme.border(brightness)),
      ),
      color: AppTheme.surfaceColor(brightness),
      elevation: 4,
      tooltip: '',
      onSelected: (value) async {
        if (value == 'signout') {
          await auth.signOut();
          // Clear the entire Navigator stack and push a fresh AuthGate.
          // This prevents back-navigation into authenticated screens.
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGate()),
              (_) => false,
            );
          }
        } else {
          onNavigate(value);
        }
      },
      itemBuilder: (_) => [
        _menuItem(Icons.person_outline,          'Profile',       AppRoutes.profile),
        if (auth.hasPermission('Users & Roles', PermissionType.view))
          _menuItem(Icons.manage_accounts_outlined, 'Users & Roles', AppRoutes.users),
        if (auth.hasPermission('Settings', PermissionType.view))
          _menuItem(Icons.settings_outlined,        'Settings',      AppRoutes.settings),
        const PopupMenuDivider(),
        _menuItem(Icons.logout, 'Sign out', 'signout',
            color: AppColors.danger),
      ],
      child: _AvatarChip(),
    );
  }

  PopupMenuItem<String> _menuItem(
    IconData icon,
    String label,
    String route, {
    Color? color,
  }) {
    return PopupMenuItem<String>(
      value: route,
      child: Builder(builder: (context) {
        final textCol =
            color ?? AppTheme.textPrimary(Theme.of(context).brightness);
        return Row(
          children: [
            Icon(icon, size: 16, color: textCol),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13, color: textCol)),
          ],
        );
      }),
    );
  }
}

class _AvatarChip extends StatefulWidget {
  @override
  State<_AvatarChip> createState() => _AvatarChipState();
}

class _AvatarChipState extends State<_AvatarChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final hoverBg     = AppTheme.primaryLighter(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final isCompact   = MediaQuery.of(context).size.width < AppConstants.mobileBreakpoint;

    final auth       = UserProfileProvider.of(context);
    final userName   = auth.currentName;
    final userRole   = UserRoleRepository.roleDisplayName(auth.currentRole);
    final userInitials = auth.currentInitials;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _hovered ? hoverBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                userInitials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Hide name/role on compact screens to save space
            if (!isCompact) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    userRole,
                    style: TextStyle(color: textSec, fontSize: 10),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable icon button (38 × 38, hover fill, tooltip)
// Helper for PopupMenuButton rows in the collapsed overflow menu
Widget _menuRow(IconData icon, String label, Brightness brightness) => Row(
  children: [
    Icon(icon, size: 16, color: AppTheme.textPrimary(brightness)),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(brightness))),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────

class _TopBarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.hoverFill(brightness)
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(widget.icon,
                size: 20, color: AppTheme.iconColor(brightness)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme toggle button — sun / moon
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeToggleButton extends StatefulWidget {
  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final notifier   = ThemeNotifier.of(context);
    final isDark     = notifier.isDark(context);
    final brightness = Theme.of(context).brightness;
    final icon = isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    final tip  = isDark ? 'Switch to Light mode' : 'Switch to Dark mode';

    return Tooltip(
      message: tip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: notifier.toggle,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.hoverFill(brightness)
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(icon,
                size: 20, color: AppTheme.iconColor(brightness)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✨ Ask Marketing AI button
//
// showLabel = true  → pill with "Ask Marketing AI" text  (wide screens)
// showLabel = false → 38×38 icon-only button             (narrow/tablet/mobile)
//
// Calls AiNotifier.of(context).toggle() — no routing, no new page.
// Turns filled-purple when the panel is open.
// ─────────────────────────────────────────────────────────────────────────────

class _AskAiButton extends StatefulWidget {
  /// Show the text label alongside the sparkle icon.
  final bool showLabel;
  const _AskAiButton({required this.showLabel});

  @override
  State<_AskAiButton> createState() => _AskAiButtonState();
}

class _AskAiButtonState extends State<_AskAiButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;
    final ai         = AiNotifier.of(context);
    final isOpen     = ai.isOpen;

    final bg = isOpen
        ? AppColors.primary
        : (_hovered
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.primaryLighter)
            : (isDark
                ? const Color(0xFF252235)
                : AppColors.primaryLighter));

    final textColor   = isOpen ? Colors.white : AppColors.primary;
    final borderColor = isOpen
        ? Colors.transparent
        : AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.35);

    final tip = isOpen ? 'Close Marketing AI' : 'Ask Marketing AI';

    if (!widget.showLabel) {
      // Icon-only variant
      return Tooltip(
        message: tip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit:  (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: ai.toggle,
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: borderColor),
              ),
              child: const Center(child: Text('✨', style: TextStyle(fontSize: 15))),
            ),
          ),
        ),
      );
    }

    // Pill variant (wide screens)
    return Tooltip(
      message: tip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: ai.toggle,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  'Ask Marketing AI',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
