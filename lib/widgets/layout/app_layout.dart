import 'package:flutter/material.dart';
import '../../core/ai_notifier.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/access_service.dart';
import '../ai/ai_assistant_panel.dart';
import '../common/access_denied_panel.dart';
import 'app_sidebar.dart';
import 'app_topbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppLayout
//
// The master shell for every authenticated page.
//
// Desktop  (≥ 960px): permanent sidebar on the left + top bar + scrollable body
// Tablet   (600-959px): collapsible drawer + top bar + scrollable body
// Mobile   (< 600px): collapsible drawer + top bar (no inline search) + body
//
// Usage:
//   AppLayout(
//     currentRoute: AppRoutes.dashboard,
//     pageTitle: 'Dashboard',
//     child: DashboardScreen(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class AppLayout extends StatefulWidget {
  /// The route that is currently active — used to highlight the sidebar item.
  final String currentRoute;

  /// Title shown in the top bar.
  final String pageTitle;

  /// The page content widget.
  final Widget child;

  /// When true the top bar renders the simplified Dashboard-only 5-action set.
  final bool isDashboard;

  /// When true the child manages its own scrolling (e.g. CustomScrollView).
  /// The outer SingleChildScrollView wrapper is skipped so the child fills
  /// all available height and controls its own scroll physics.
  final bool selfScrolling;

  const AppLayout({
    super.key,
    required this.currentRoute,
    required this.pageTitle,
    required this.child,
    this.isDashboard = false,
    this.selfScrolling = false,
  });

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Desktop-only collapse state. Tablet/mobile always use the drawer.
  bool _sidebarCollapsed = false;

  // Navigates to a named route, closing the drawer first if open.
  void _navigate(String route) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop(); // close drawer
    }
    // Replace the current route so the back button doesn't stack shell pages
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _toggleSidebar() {
    final width     = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.sidebarBreakpoint;
    if (isDesktop) {
      // Desktop: collapse / expand the inline sidebar
      setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    } else {
      // Tablet / mobile: open the drawer
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width      = MediaQuery.of(context).size.width;
    final isDesktop  = width >= AppConstants.sidebarBreakpoint;
    final isMobile   = width < AppConstants.mobileBreakpoint;
    final brightness = Theme.of(context).brightness;

    // ── IMPORTANT: Do NOT call AiNotifier.of(context) here. ─────────────
    //
    // If AiNotifier is read in this build() method, the entire AppLayout
    // widget tree (including the content column and CampaignListScreen) is
    // rebuilt every time the AI panel opens or closes. That rebuild causes
    // layout thrashing on the CustomScrollView and makes the Campaigns
    // screen go blank.
    //
    // Instead, AI state is read inside _AiPanelSlot (tablet/desktop) and
    // _AiMobileOverlay (mobile) — two small dedicated widgets that are the
    // only things that rebuild when isOpen changes. The content column and
    // CampaignListScreen are completely unaffected.

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ── Drawer (tablet + mobile only) ──────────────────────────────────
      drawer: isDesktop
          ? null
          : Drawer(
              width: AppConstants.sidebarWidth,
              backgroundColor: AppTheme.sidebarBg(brightness),
              shape: const RoundedRectangleBorder(),
              child: AppSidebar(
                currentRoute: widget.currentRoute,
                onNavigate: _navigate,
                isDrawer: true,
              ),
            ),

      // ── Body: sidebar + content column + AI panel ───────────────────────
      body: Stack(
        children: [
          // ── Main layout row ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Permanent sidebar — desktop only.
              if (isDesktop)
                AnimatedContainer(
                  duration: AppConstants.animNormal,
                  curve: Curves.easeInOut,
                  width: _sidebarCollapsed
                      ? AppSidebar.railWidth
                      : AppConstants.sidebarWidth,
                  child: ClipRect(
                    child: AppSidebar(
                      currentRoute: widget.currentRoute,
                      onNavigate: _navigate,
                      collapsed: _sidebarCollapsed,
                    ),
                  ),
                ),

              // ── Content column ──────────────────────────────────────────
              // Wrapped in Expanded so it fills all remaining horizontal space
              // after the sidebar and AI panel claim their widths.
              //
              // This column NEVER reads AiNotifier — it is completely isolated
              // from AI state changes. Campaigns (and every other screen) stays
              // alive and rendered regardless of whether the AI panel is open.
              Expanded(
                child: Column(
                  children: [
                    // Sticky top bar
                    AppTopBar(
                      pageTitle: widget.pageTitle,
                      onNavigate: _navigate,
                      isDashboard: widget.isDashboard,
                      onMenuTap: _toggleSidebar,
                    ),

                    // Page content — fills remaining height
                    Expanded(
                      child: _PageContentArea(
                        selfScrolling: widget.selfScrolling,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),

              // ── AI panel slot — tablet & desktop only ───────────────────
              // _AiPanelSlot is the ONLY widget that reads AiNotifier.
              // It rebuilds independently; the content column above does not.
              if (!isMobile)
                _AiPanelSlot(currentRoute: widget.currentRoute),
            ],
          ),

          // ── Mobile AI overlay ───────────────────────────────────────────
          // Full-screen drawer-style overlay on small screens.
          // Also isolated in its own widget so the content column is safe.
          if (isMobile)
            _AiMobileOverlay(
              currentRoute: widget.currentRoute,
              screenWidth: width,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AiPanelSlot
//
// The ONLY widget in the layout that subscribes to AiNotifier.
// When isOpen changes, only this widget rebuilds — the content column
// (Campaigns, Dashboard, etc.) is completely untouched.
//
// Renders as an AnimatedContainer that slides from 0 → panelWidth.
// On mobile this widget is not added to the Row at all (_AiMobileOverlay
// handles mobile separately via the Stack).
// ─────────────────────────────────────────────────────────────────────────────

class _AiPanelSlot extends StatelessWidget {
  final String currentRoute;
  const _AiPanelSlot({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final ai         = AiNotifier.of(context);   // ← only subscriber
    final isOpen     = ai.isOpen;
    final width      = MediaQuery.of(context).size.width;
    final isDesktop  = width >= AppConstants.sidebarBreakpoint;
    final panelWidth = isDesktop ? 340.0 : 300.0;

    return AnimatedContainer(
      duration: AppConstants.animNormal,
      curve: Curves.easeInOut,
      width: isOpen ? panelWidth : 0.0,
      child: ClipRect(
        child: isOpen
            ? AiAssistantPanel(
                currentRoute: currentRoute,
                onClose: ai.close,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AiMobileOverlay
//
// Full-screen overlay for mobile (< 768px). Sits in the Stack on top of all
// content. Also isolated so only this widget rebuilds on AI state changes.
// ─────────────────────────────────────────────────────────────────────────────

class _AiMobileOverlay extends StatelessWidget {
  final String currentRoute;
  final double screenWidth;
  const _AiMobileOverlay({required this.currentRoute, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final ai     = AiNotifier.of(context);   // ← only subscriber
    final isOpen = ai.isOpen;

    if (!isOpen) return const SizedBox.shrink();

    return Stack(
      children: [
        // Scrim — tap anywhere outside the panel to close
        GestureDetector(
          onTap: ai.close,
          child: Container(color: Colors.black.withValues(alpha: 0.4)),
        ),
        // Panel — slides in from the right edge
        Positioned(
          top:    0,
          right:  0,
          bottom: 0,
          width:  screenWidth * 0.92,
          child: AiAssistantPanel(
            currentRoute: currentRoute,
            onClose: ai.close,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page content area — scrollable, with consistent padding
// ─────────────────────────────────────────────────────────────────────────────

class _PageContentArea extends StatelessWidget {
  final Widget child;
  /// When true the child is a self-scrolling widget (e.g. CustomScrollView).
  /// We skip the outer SingleChildScrollView so it fills all available height.
  final bool selfScrolling;

  const _PageContentArea({required this.child, this.selfScrolling = false});

  @override
  Widget build(BuildContext context) {
    if (selfScrolling) {
      return ClipRect(child: child);
    }
    return ClipRect(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppLayoutPage — convenience wrapper for route builder lambdas.
//
// Instead of manually wrapping every screen, use this:
//
//   dashboard: (_) => AppLayoutPage(
//     route: AppRoutes.dashboard,
//     title: AppConstants.navDashboard,
//     child: const DashboardScreen(),
//   ),
// ─────────────────────────────────────────────────────────────────────────────

class AppLayoutPage extends StatelessWidget {
  final String route;
  final String title;
  final Widget child;
  final bool isDashboard;
  final bool selfScrolling;

  const AppLayoutPage({
    super.key,
    required this.route,
    required this.title,
    required this.child,
    this.isDashboard = false,
    this.selfScrolling = false,
  });

  @override
  Widget build(BuildContext context) {
    // ── Role guard ───────────────────────────────────────────────────────
    // One check for every route in the table: if the signed-in role has no
    // view permission for the module, the screen is replaced by an access
    // panel. This also covers deep links from notifications and the AI panel.
    final module = AccessService.moduleForRoute(route);
    final Widget body;
    if (module != null && !AccessService.canView(module)) {
      body = AccessDeniedPanel(module: module);
    } else {
      body = child;
    }

    return AppLayout(
      currentRoute: route,
      pageTitle: title,
      isDashboard: isDashboard,
      selfScrolling: selfScrolling,
      child: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardShellPreview
//
// A self-contained demo screen wired to the '/dashboard' route so the layout
// can be tested immediately — no real DashboardScreen needed yet.
// This is replaced in Phase 5 when the real dashboard is built.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardShellPreview extends StatelessWidget {
  const DashboardShellPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayoutPage(
      route: AppRoutes.dashboard,
      title: AppConstants.navDashboard,
      child: const _ShellPreviewBody(),
    );
  }
}

class _ShellPreviewBody extends StatelessWidget {
  const _ShellPreviewBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                ),
                child: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, Hana Tsegaye 👋',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Here\'s what\'s happening with your marketing today.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.sectionSpacing),

        // Shell phase info card
        Container(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: AppTheme.border(Theme.of(context).brightness)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phase 2 — App Shell', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'The sidebar, top bar, and responsive layout are working.\n'
                'Dashboard content will be added in Phase 5.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.itemSpacing),

        // Sample placeholder KPI row
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 800 ? 4 : (constraints.maxWidth >= 500 ? 2 : 1);
            final itemWidth = (constraints.maxWidth - (cols - 1) * AppConstants.itemSpacing) / cols;

            return Wrap(
              spacing: AppConstants.itemSpacing,
              runSpacing: AppConstants.itemSpacing,
              children: const [
                _PreviewKpiCard(label: 'Total Campaigns', value: '24', icon: Icons.campaign_outlined, color: AppColors.primary),
                _PreviewKpiCard(label: 'Total Leads',     value: '3,248', icon: Icons.person_search_outlined, color: AppColors.success),
                _PreviewKpiCard(label: 'Budget Spend',    value: '\$750K', icon: Icons.account_balance_wallet_outlined, color: AppColors.warning),
                _PreviewKpiCard(label: 'ROI',             value: '4.35×', icon: Icons.trending_up_outlined, color: AppColors.info),
              ].map((card) => SizedBox(width: itemWidth, child: card)).toList(),
            );
          },
        ),
      ],
    );
  }
}

// Small preview KPI card — replaced by the real StatCard in Phase 3
class _PreviewKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PreviewKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(Theme.of(context).brightness)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
