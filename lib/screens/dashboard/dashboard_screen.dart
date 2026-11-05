import 'package:flutter/material.dart';
import '../../core/ai_notifier.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/dashboard_models.dart';
import '../../services/access_service.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_live_data.dart';
import '../../widgets/auth/user_profile_provider.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/charts/campaign_performance_chart.dart';
import '../../widgets/charts/leads_source_chart.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';

/// Professional SaaS marketing dashboard.
/// Rendered inside AppLayout (sidebar + simplified 5-action top bar).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'This Week';

  // Date range state � starts on the current default range
  DateTime _startDate = DateTime(2026, 5, 12);
  DateTime _endDate   = DateTime(2026, 5, 18);

  void _navigateTo(String route) {
    Navigator.of(context).pushNamed(route);
  }

  // -- Date range picker ------------------------------------------------------

  Future<void> _openDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      currentDate: now,
      helpText: 'SELECT DATE RANGE',
      saveText: 'APPLY',
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final isDark = brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1C1A27),
                    onSurface: Color(0xFFECEAF4),
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppColors.textDark,
                  ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate   = picked.end;
      });
    }
  }

  // Apply a quick preset range
  void _applyQuickRange(_QuickRange preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (preset) {
      case _QuickRange.today:
        start = DateTime(now.year, now.month, now.day);
        end   = start;
        break;
      case _QuickRange.thisWeek:
        final weekday = now.weekday; // 1=Mon�7=Sun
        start = now.subtract(Duration(days: weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end   = DateTime(now.year, now.month, now.day);
        break;
      case _QuickRange.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end   = DateTime(now.year, now.month, now.day);
        break;
      case _QuickRange.last7Days:
        end   = DateTime(now.year, now.month, now.day);
        start = end.subtract(const Duration(days: 6));
        break;
      case _QuickRange.last30Days:
        end   = DateTime(now.year, now.month, now.day);
        start = end.subtract(const Duration(days: 29));
        break;
    }

    setState(() {
      _startDate = start;
      _endDate   = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width    = constraints.maxWidth;
        final isWide   = width >= 1100;
        final isMedium = width >= 700;

        // -- Role-based visibility -------------------------------------
        // The dashboard renders a different set of cards per role: budget
        // figures need Budget view access, quick actions need create access
        // on at least one of the modules they open.
        final showBudgetOverview = AccessService.canView('Budget');
        final showQuickActions =
            AccessService.canCreate('Campaigns') ||
                AccessService.canCreate('Leads') ||
                AccessService.canCreate('Content') ||
                AccessService.canCreate('Reports');
        final role = AuthService().currentRole;
        final channelPerf = DashboardLiveData.channelPerformance;
        final visibleKpis = _kpisForRole(role)
            .where((s) => s.module == null || AccessService.canView(s.module!))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // -- 1. Welcome + date range --------------------------------
            _WelcomeHeader(
              startDate:          _startDate,
              endDate:            _endDate,
              onDateTap:          _openDateRangePicker,
              onQuickRange:       _applyQuickRange,
            ),
            const SizedBox(height: AppConstants.sectionSpacing),

            // Each role gets a different working surface. The cards below are
            // deliberately role-focused so the dashboard answers the user's
            // daily question instead of showing the same generic snapshot to
            // every account.
            _RoleWorkspace(
              role: role,
              onNavigate: _navigateTo,
            ),
            const SizedBox(height: AppConstants.sectionSpacing),

            // -- 2. KPI cards -------------------------------------------
            _KpiSummaryGrid(
              stats:    visibleKpis,
              isWide:   isWide,
              isMedium: isMedium,
            ),
            const SizedBox(height: AppConstants.sectionSpacing),

            // -- 3. Charts row ------------------------------------------
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _CampaignPerformanceCard(
                      selectedPeriod:  _selectedPeriod,
                      onPeriodChanged: (v) =>
                          setState(() => _selectedPeriod = v),
                    ),
                  ),
                  const SizedBox(width: AppConstants.itemSpacing),
                  Expanded(
                    flex: 2,
                    child: _LeadsSourceCard(
                      onViewReport: () => _navigateTo(AppRoutes.reports),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _CampaignPerformanceCard(
                    selectedPeriod:  _selectedPeriod,
                    onPeriodChanged: (v) =>
                        setState(() => _selectedPeriod = v),
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),
                  _LeadsSourceCard(
                    onViewReport: () => _navigateTo(AppRoutes.reports),
                  ),
                ],
              ),
            const SizedBox(height: AppConstants.sectionSpacing),

            // -- 4. Recent Activity + Quick Actions + ROI ---------------
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: RecentActivityCard(
                      activities: DashboardLiveData.recentActivities,
                      onViewAll: () => _navigateTo(AppRoutes.notifications),
                    ),
                  ),
                  const SizedBox(width: AppConstants.itemSpacing),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        if (showQuickActions)
                    QuickActionsCard(
                      onNewCampaign:  () =>
                          _navigateTo(AppRoutes.campaignCreate),
                          onAddLead:      () => _navigateTo(AppRoutes.leads),
                          onCreateContent:() => _navigateTo(AppRoutes.content),
                          onCreateReport: () => _navigateTo(AppRoutes.reports),
                        ),
                        const SizedBox(height: AppConstants.itemSpacing),
                        RoiInsightCard(
                          onExplore: () => _navigateTo(AppRoutes.reports),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  RecentActivityCard(
                    activities: DashboardLiveData.recentActivities,
                    onViewAll: () => _navigateTo(AppRoutes.notifications),
                  ),
                  const SizedBox(height: AppConstants.itemSpacing),
                  if (showQuickActions)
                    QuickActionsCard(
                      onNewCampaign:  () => _navigateTo(AppRoutes.campaignCreate),
                      onAddLead:      () => _navigateTo(AppRoutes.leads),
                      onCreateContent:() => _navigateTo(AppRoutes.content),
                      onCreateReport: () => _navigateTo(AppRoutes.reports),
                    ),
                  const SizedBox(height: AppConstants.itemSpacing),
                  RoiInsightCard(
                    onExplore: () => _navigateTo(AppRoutes.reports),
                  ),
                ],
              ),
            const SizedBox(height: AppConstants.sectionSpacing),

            // -- 6. Top Campaigns table ---------------------------------
            TopCampaignsTable(
              campaigns: DashboardLiveData.topCampaigns,
              onViewAll: () => _navigateTo(AppRoutes.campaigns),
            ),
            const SizedBox(height: AppConstants.sectionSpacing),

            // -- AI Assistant shortcut ----------------------------------
            _AiShortcutCard(),
            const SizedBox(height: AppConstants.sectionSpacing),

            // -- 7. Budget Overview + Channel Performance ----------------
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBudgetOverview) ...[
                    Expanded(
                      child: BudgetOverviewCard(
                        total:        DashboardLiveData.budgetTotal,
                        spent:        DashboardLiveData.budgetSpent,
                        remaining:    DashboardLiveData.budgetRemaining,
                        utilization:  DashboardLiveData.budgetUtilization,
                        onViewDetails:() => _navigateTo(AppRoutes.budget),
                      ),
                    ),
                    const SizedBox(width: AppConstants.itemSpacing),
                  ],
                  if (channelPerf.isNotEmpty)
                    Expanded(
                      child: ChannelPerformanceCard(
                        channels:       channelPerf,
                        onViewAnalytics:() => _navigateTo(AppRoutes.reports),
                      ),
                    ),
                ],
              )
            else
              Column(
                children: [
                  if (showBudgetOverview) ...[
                    BudgetOverviewCard(
                      total:        DashboardLiveData.budgetTotal,
                      spent:        DashboardLiveData.budgetSpent,
                      remaining:    DashboardLiveData.budgetRemaining,
                      utilization:  DashboardLiveData.budgetUtilization,
                      onViewDetails:() => _navigateTo(AppRoutes.budget),
                    ),
                    const SizedBox(height: AppConstants.itemSpacing),
                  ],
                  if (channelPerf.isNotEmpty)
                    ChannelPerformanceCard(
                      channels:       channelPerf,
                      onViewAnalytics:() => _navigateTo(AppRoutes.reports),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  List<KpiStat> _kpisForRole(String role) {
    final all = DashboardLiveData.kpiStats;
    final labelsByRole = <String, Set<String>>{
      'admin': all.map((k) => k.label).toSet(),
      'marketing_manager': {
        'Total Campaigns',
        'Total Leads',
        'Budget Spend',
        'ROI',
        'Active Campaigns',
        'Conversion Rate',
      },
      'marketing_clerk': {
        'Total Campaigns',
        'Total Leads',
        'Active Campaigns',
        'New Customers',
      },
      'content_creator': {
        'Active Campaigns',
        'Total Campaigns',
      },
      'viewer': {'Total Campaigns', 'Active Campaigns', 'New Customers'},
    };
    final visible = labelsByRole[role] ?? labelsByRole['viewer']!;
    return all.where((kpi) => visible.contains(kpi.label)).toList();
  }
}

/// Role-specific dashboard workspaces. This is intentionally separate from
/// the shared charts so adding a new role does not accidentally expose the
/// manager or administrator workflow to a read-only account.
class _RoleWorkspace extends StatelessWidget {
  final String role;
  final void Function(String route) onNavigate;

  const _RoleWorkspace({required this.role, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final name = AuthService().currentName;
    final config = _configForRole(role);
    bool canOpen(String module) => AccessService.canView(module);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(brightness),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppTheme.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(config.icon, color: config.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${config.title}, $name',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                    const SizedBox(height: 3),
                    Text(config.subtitle,
                        style: TextStyle(
                          color: AppTheme.textSecondary(brightness),
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final metric in config.metrics)
                _RoleMetric(label: metric.label, value: metric.value, color: metric.iconColor),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in config.actions)
                if (canOpen(action.module))
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(action.route),
                    icon: Icon(action.icon, size: 16),
                    label: Text(action.label),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  _RoleDashboardConfig _configForRole(String role) {
    final all = DashboardLiveData.kpiStats;
    KpiStat metric(String label) => all.firstWhere(
          (k) => k.label == label,
          orElse: () => KpiStat(
            label: label,
            value: '0',
            change: '',
            isPositive: true,
            icon: Icons.insights_outlined,
            iconColor: AppColors.primary,
            subtitle: '',
          ),
        );
    switch (role) {
      case 'admin':
        return _RoleDashboardConfig(
          title: 'System control center',
          subtitle: 'Monitor every workspace and manage access, data, and configuration.',
          icon: Icons.admin_panel_settings_outlined,
          color: AppColors.primary,
          metrics: [metric('Total Campaigns'), metric('Total Leads'), metric('New Customers'), metric('Budget Spend')],
          actions: const [
            _RoleAction('Users & Roles', AppRoutes.users, Icons.manage_accounts_outlined),
            _RoleAction('Settings', AppRoutes.settings, Icons.settings_outlined),
            _RoleAction('Reports', AppRoutes.reports, Icons.assessment_outlined),
          ],
        );
      case 'marketing_manager':
        return _RoleDashboardConfig(
          title: 'Growth command center',
          subtitle: 'Prioritise campaigns, pipeline movement, and spend against targets.',
          icon: Icons.insights_outlined,
          color: AppColors.info,
          metrics: [metric('Active Campaigns'), metric('Total Leads'), metric('Conversion Rate'), metric('ROI')],
          actions: const [
            _RoleAction('Campaigns', AppRoutes.campaigns, Icons.campaign_outlined),
            _RoleAction('Leads', AppRoutes.leads, Icons.person_search_outlined),
            _RoleAction('Budget', AppRoutes.budget, Icons.account_balance_wallet_outlined),
          ],
        );
      case 'marketing_clerk':
        return _RoleDashboardConfig(
          title: 'Execution workspace',
          subtitle: 'Work the queue: publish content, follow up leads, and keep campaigns moving.',
          icon: Icons.task_alt_outlined,
          color: AppColors.success,
          metrics: [metric('Active Campaigns'), metric('Total Leads'), metric('New Customers')],
          actions: const [
            _RoleAction('Content', AppRoutes.content, Icons.article_outlined),
            _RoleAction('Leads', AppRoutes.leads, Icons.person_search_outlined),
            _RoleAction('Campaigns', AppRoutes.campaigns, Icons.campaign_outlined),
          ],
        );
      case 'content_creator':
        return _RoleDashboardConfig(
          title: 'Content workspace',
          subtitle: 'Create, schedule, and manage content and influencer collaborations.',
          icon: Icons.article_outlined,
          color: const Color(0xFFEC4899),
          metrics: [metric('Active Campaigns'), metric('Total Campaigns')],
          actions: const [
            _RoleAction('Content',    AppRoutes.content,    Icons.article_outlined),
            _RoleAction('Influencers',AppRoutes.influencers, Icons.star_outline),
            _RoleAction('Campaigns',  AppRoutes.campaigns,  Icons.campaign_outlined),
          ],
        );
      default:
        return _RoleDashboardConfig(
          title: 'Read only overview',
          subtitle: 'Review approved campaign and customer progress without changing records.',
          icon: Icons.visibility_outlined,
          color: AppColors.textSecondary,
          metrics: [metric('Active Campaigns'), metric('Total Campaigns'), metric('New Customers')],
          actions: const [
            _RoleAction('Campaigns', AppRoutes.campaigns, Icons.campaign_outlined),
            _RoleAction('Reports', AppRoutes.reports, Icons.assessment_outlined),
          ],
        );
    }
  }
}

class _RoleMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RoleMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(brightness))),
        ],
      ),
    );
  }
}

class _RoleDashboardConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<KpiStat> metrics;
  final List<_RoleAction> actions;

  const _RoleDashboardConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.metrics,
    required this.actions,
  });
}

class _RoleAction {
  final String label;
  final String route;
  final IconData icon;

  const _RoleAction(this.label, this.route, this.icon);

  String get module {
    if (route == AppRoutes.campaigns || route == AppRoutes.campaignCreate) {
      return 'Campaigns';
    }
    if (route == AppRoutes.leads) return 'Leads';
    if (route == AppRoutes.content) return 'Content';
    if (route == AppRoutes.budget) return 'Budget';
    if (route == AppRoutes.reports) return 'Reports';
    if (route == AppRoutes.users) return 'Users & Roles';
    if (route == AppRoutes.settings) return 'Settings';
    return 'Dashboard';
  }
}

// -----------------------------------------------------------------------------
// Quick range enum
// -----------------------------------------------------------------------------

enum _QuickRange { today, thisWeek, thisMonth, last7Days, last30Days }

// -----------------------------------------------------------------------------
// AI Shortcut Card
//
// A single-row call-to-action card that opens the global AI assistant panel.
// It reads AiNotifier from context � the SAME panel used everywhere else.
// Placed on the Dashboard between the Campaigns table and Budget section.
// -----------------------------------------------------------------------------

class _AiShortcutCard extends StatefulWidget {
  @override
  State<_AiShortcutCard> createState() => _AiShortcutCardState();
}

class _AiShortcutCardState extends State<_AiShortcutCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;
    final aiNotifier = AiNotifier.of(context);

    final bg = isDark
        ? const Color(0xFF1C1A27)
        : AppColors.surface;
    final borderColor = _hovered
        ? AppColors.primary.withValues(alpha: 0.5)
        : (isDark
            ? AppColors.primary.withValues(alpha: 0.25)
            : AppColors.primary.withValues(alpha: 0.2));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: aiNotifier.open,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: borderColor, width: 1.5),
            gradient: _hovered
                ? LinearGradient(
                    colors: [
                      isDark
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.primaryLighter,
                      isDark
                          ? const Color(0xFF252235)
                          : AppColors.surface,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Gradient badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFBB5CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: const Center(
                  child: Text('?', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '? Ask Marketing AI',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Analyze your marketing performance with AI.',
                      style: TextStyle(
                        color: AppTheme.textSecondary(brightness),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _hovered
                    ? AppColors.primary
                    : AppTheme.iconColor(brightness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. Dashboard page header
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 2. Welcome header � compact banner with functional date range picker
// -----------------------------------------------------------------------------

class _WelcomeHeader extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onDateTap;
  final ValueChanged<_QuickRange> onQuickRange;

  const _WelcomeHeader({
    required this.startDate,
    required this.endDate,
    required this.onDateTap,
    required this.onQuickRange,
  });

  String _fmt(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month]} ${d.day}';
  }

  String get _rangeLabel {
    final s = _fmt(startDate);
    final e = _fmt(endDate);
    final sameYear = startDate.year == endDate.year;
    if (s == e) return '$s, ${startDate.year}';
    return sameYear
        ? '$s � $e, ${startDate.year}'
        : '$s ${startDate.year} � $e ${endDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;
    final isNarrow   = MediaQuery.of(context).size.width < 560;

    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final userName    = UserProfileProvider.of(context).currentName;

    final bannerBg = isDark
        ? const Color(0xFF1C1A27)
        : AppColors.primaryLighter;
    final bannerBorder = isDark
        ? AppColors.primary.withValues(alpha: 0.25)
        : AppColors.primary.withValues(alpha: 0.12);

    // -- Date range chip with quick-presets popup -------------------------
    final dateChip = PopupMenuButton<_QuickRange>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      color: isDark ? const Color(0xFF252235) : AppColors.surface,
      elevation: 4,
      tooltip: '',
      onSelected: (preset) {
        if (preset == _QuickRange.today ||
            preset == _QuickRange.thisWeek ||
            preset == _QuickRange.thisMonth ||
            preset == _QuickRange.last7Days ||
            preset == _QuickRange.last30Days) {
          onQuickRange(preset);
        }
      },
      itemBuilder: (_) => [
        _buildPresetItem('Today',       _QuickRange.today,     isDark),
        _buildPresetItem('This Week',   _QuickRange.thisWeek,  isDark),
        _buildPresetItem('This Month',  _QuickRange.thisMonth, isDark),
        _buildPresetItem('Last 7 Days', _QuickRange.last7Days, isDark),
        _buildPresetItem('Last 30 Days',_QuickRange.last30Days,isDark),
        PopupMenuItem<_QuickRange>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Divider(
            height: 1,
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.border,
          ),
        ),
        PopupMenuItem<_QuickRange>(
          // value is null so onSelected won't fire � we call onDateTap manually
          onTap: onDateTap,
          child: _buildCustomRangeRow(context, isDark),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252235) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(
              _rangeLabel,
              style: TextStyle(
                color: isDark
                    ? textPrimary
                    : AppColors.textDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 15, color: AppTheme.textSecondary(brightness)),
          ],
        ),
      ),
    );

    // -- Text block ---------------------------------------------------------
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Welcome back, ',
              style: TextStyle(
                color: textPrimary,
                fontSize: isNarrow ? 18 : 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            Text(
              userName,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: isNarrow ? 18 : 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            Text(
              '! ??',
              style: TextStyle(
                color: textPrimary,
                fontSize: isNarrow ? 18 : 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Great things happen when strategy meets action.',
          style: TextStyle(
            color: textSec,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Plan smart. Execute better. Grow bigger! ??',
          style: TextStyle(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.85)
                : AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        if (isNarrow) ...[
          const SizedBox(height: 12),
          dateChip,
        ],
      ],
    );

    // -- Decorative visual --------------------------------------------------
    final decorative = isNarrow
        ? const SizedBox.shrink()
        : SizedBox(
            width: 120,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.trending_up_rounded,
                      color: AppColors.primary, size: 22),
                ),
                // ROI badge
                Positioned(
                  top: 2,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_upward,
                            size: 8, color: AppColors.success),
                        const SizedBox(width: 2),
                        Text('ROI',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                // Campaign count badge
                Positioned(
                  bottom: 2,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 8, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text('24',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : 22,
        vertical:   isNarrow ? 16 : 18,
      ),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        border: Border.all(color: bannerBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary
                .withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: isNarrow
          ? textBlock
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: textBlock),
                const SizedBox(width: 12),
                decorative,
                const SizedBox(width: 16),
                dateChip,
              ],
            ),
    );
  }

  PopupMenuItem<_QuickRange> _buildPresetItem(
      String label, _QuickRange value, bool isDark) {
    final color = isDark ? const Color(0xFFECEAF4) : AppColors.textDark;
    return PopupMenuItem<_QuickRange>(
      value: value,
      height: 36,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCustomRangeRow(BuildContext context, bool isDark) {
    return Row(
      children: [
        Icon(Icons.date_range_outlined,
            size: 14,
            color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          'Custom Range�',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 3. KPI summary grid � up to 6 columns on wide, 4 on medium, 2 on mobile
// -----------------------------------------------------------------------------

class _KpiSummaryGrid extends StatelessWidget {
  final List<KpiStat> stats;
  final bool isWide;
  final bool isMedium;

  const _KpiSummaryGrid({
    required this.stats,
    required this.isWide,
    required this.isMedium,
  });

  @override
  Widget build(BuildContext context) {
    // Wide: 4 cols first row, remaining fill (up to 4 more = 4+4 or 4+3+1 etc)
    // Use 4 cols on wide, 2 on medium/mobile for clean wrapping.
    // On very wide (=1400) we try 6 per row.
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      int cols;
      if (width >= 1400) {
        cols = 6;
      } else if (width >= 1100) {
        cols = 4;
      } else if (width >= 700) {
        cols = 3;
      } else if (width >= 480) {
        cols = 2;
      } else {
        cols = 1;
      }

      final spacing  = AppConstants.itemSpacing;
      final itemWidth = (width - (cols - 1) * spacing) / cols;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: stats
            .map((stat) => SizedBox(
                  width: itemWidth,
                  child: StatCard(stat: stat),
                ))
            .toList(),
      );
    });
  }
}

// -----------------------------------------------------------------------------
// 4. Campaign Performance card
// -----------------------------------------------------------------------------

class _CampaignPerformanceCard extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const _CampaignPerformanceCard({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: 'Campaign Performance',
            subtitle: 'Impressions, leads & conversions by campaign',
            icon: Icons.bar_chart_outlined,
            iconColor: AppColors.primary,
            trailing: _PeriodSelector(
              selected: selectedPeriod,
              onChanged: onPeriodChanged,
            ),
          ),
          const SizedBox(height: 16),
          CampaignPerformanceChart(
            data: DashboardLiveData.campaignPerformance,
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const periods = ['This Week', 'This Month', 'This Year'];
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF252235) : AppColors.background;
    final selectedBg = isDark ? const Color(0xFF312E47) : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periods.map((p) {
          final isSelected = p == selected;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : AppTheme.textSecondary(brightness),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. Leads by Source card
// -----------------------------------------------------------------------------

class _LeadsSourceCard extends StatelessWidget {
  final VoidCallback onViewReport;

  const _LeadsSourceCard({required this.onViewReport});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: 'Leads by Source',
            icon: Icons.pie_chart_outline,
            iconColor: AppColors.success,
          ),
          const SizedBox(height: 16),
          LeadsSourceChart(
            slices:      DashboardLiveData.leadsBySource,
            centerValue: DashboardLiveData.totalLeads,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewReport,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('View Full Report',
                  style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

