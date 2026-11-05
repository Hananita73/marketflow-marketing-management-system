import 'package:flutter/material.dart';
import '../widgets/layout/app_layout.dart';
import '../core/constants.dart';
import '../screens/auth/login_screen.dart';
import '../screens/campaigns/campaign_list_screen.dart';
import '../screens/campaigns/campaign_details_screen.dart';
import '../screens/campaigns/create_campaign_screen.dart';
import '../screens/campaigns/edit_campaign_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/leads/leads_screen.dart';
import '../screens/opportunities/opportunities_screen.dart';
import '../screens/influencers/influencers_screen.dart';
import '../screens/content/content_screen.dart';
import '../screens/promotions/promotions_screen.dart';
import '../screens/budget/budget_screen.dart';
import '../screens/communications/communications_screen.dart';
import '../screens/automation/automation_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/users/admin_console_screen.dart';
import '../screens/profile/profile_screen.dart';

/// Named route identifiers for the entire application.
class AppRoutes {
  AppRoutes._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String login = '/login';

  // ── Main modules ──────────────────────────────────────────────────────────
  static const String dashboard = '/dashboard';

  // Campaigns
  static const String campaigns = '/campaigns';
  static const String campaignCreate = '/campaigns/create';
  static const String campaignDetail = '/campaigns/detail';
  static const String campaignEdit = '/campaigns/edit';

  // Customers
  static const String customers = '/customers';
  static const String customerDetail = '/customers/detail';

  // Leads
  static const String leads = '/leads';
  static const String leadDetail = '/leads/detail';

  // Opportunities
  static const String opportunities = '/opportunities';
  static const String opportunityDetail = '/opportunities/detail';

  // Influencers
  static const String influencers = '/influencers';
  static const String influencerDetail = '/influencers/detail';

  // Content
  static const String content = '/content';
  static const String contentDetail = '/content/detail';

  // Promotions
  static const String promotions = '/promotions';

  // Budget
  static const String budget = '/budget';

  // Communications
  static const String communications = '/communications';

  // Automation
  static const String automation = '/automation';
  static const String automationDetail = '/automation/detail';

  // Reports
  static const String reports = '/reports';

  // Notifications
  static const String notifications = '/notifications';

  // Users
  static const String users = '/users';
  static const String userDetail = '/users/detail';

  // Profile / Settings
  static const String profile = '/profile';
  static const String settings = '/settings';

  // ── Route table ───────────────────────────────────────────────────────────
  // NOTE: '/' (splash) is NOT in this map because MaterialApp.home is set
  // to AuthGate. Flutter forbids having both `home` and a '/' route entry.
  static Map<String, WidgetBuilder> get routes {
    return {
      login: (_) => const LoginScreen(),

      // Dashboard — real dashboard inside AppLayout
      dashboard: (_) => AppLayoutPage(
            route: dashboard,
            title: AppConstants.navDashboard,
            isDashboard: true,
            child: const DashboardScreen(),
          ),

      // ── Campaigns (Phase 4 — fully implemented) ───────────────────────────
      campaigns: (_) => AppLayoutPage(
            route: campaigns,
            title: AppConstants.navCampaigns,
            selfScrolling: true,
            child: const CampaignListScreen(),
          ),
      campaignCreate: (_) => AppLayoutPage(
            route: campaigns,
            title: 'Create Campaign',
            child: const CreateCampaignScreen(),
          ),
      campaignDetail: (ctx) {
        final id = ModalRoute.of(ctx)!.settings.arguments as String? ?? '';
        return AppLayoutPage(
          route: campaigns,
          title: 'Campaign Details',
          child: CampaignDetailsScreen(campaignId: id),
        );
      },
      campaignEdit: (ctx) {
        final id = ModalRoute.of(ctx)!.settings.arguments as String? ?? '';
        return AppLayoutPage(
          route: campaigns,
          title: 'Edit Campaign',
          child: EditCampaignScreen(campaignId: id),
        );
      },

      // ── Customers (Phase 1 — fully implemented) ─────────────────────────────
      customers: (_) => AppLayoutPage(
            route: customers,
            title: AppConstants.navCustomers,
            selfScrolling: true,
            child: const CustomersScreen(),
          ),
      customerDetail: (_) => AppLayoutPage(
            route: customers,
            title: 'Customer Detail',
            child: const _PlaceholderBody(title: 'Customer Detail'),
          ),

      // ── Leads (Phase 1 — fully implemented) ──────────────────────────────────
      leads: (_) => AppLayoutPage(
            route: leads,
            title: AppConstants.navLeads,
            selfScrolling: true,
            child: const LeadsScreen(),
          ),
      leadDetail: (_) => AppLayoutPage(
            route: leads,
            title: 'Lead Detail',
            child: const _PlaceholderBody(title: 'Lead Detail'),
          ),

      // ── Opportunities (Phase 1 — fully implemented) ──────────────────────────
      opportunities: (_) => AppLayoutPage(
            route: opportunities,
            title: AppConstants.navOpportunities,
            selfScrolling: true,
            child: const OpportunitiesScreen(),
          ),
      opportunityDetail: (_) => AppLayoutPage(
            route: opportunities,
            title: 'Opportunity Detail',
            child: const _PlaceholderBody(title: 'Opportunity Detail'),
          ),
      influencers: (_) => AppLayoutPage(
            route: influencers,
            title: AppConstants.navInfluencers,
            selfScrolling: true,
            child: const InfluencersScreen(),
          ),
      influencerDetail: (_) => AppLayoutPage(
            route: influencers,
            title: 'Influencer Detail',
            child: const _PlaceholderBody(title: 'Influencer Detail'),
          ),
      content: (_) => AppLayoutPage(
            route: content,
            title: AppConstants.navContent,
            selfScrolling: true,
            child: const ContentScreen(),
          ),
      contentDetail: (_) => AppLayoutPage(
            route: content,
            title: 'Content Detail',
            child: const _PlaceholderBody(title: 'Content Detail'),
          ),
      promotions: (_) => AppLayoutPage(
            route: promotions,
            title: AppConstants.navPromotions,
            selfScrolling: true,
            child: const PromotionsScreen(),
          ),
      budget: (_) => AppLayoutPage(
            route: budget,
            title: AppConstants.navBudget,
            selfScrolling: true,
            child: const BudgetScreen(),
          ),
      communications: (_) => AppLayoutPage(
            route: communications,
            title: AppConstants.navCommunications,
            selfScrolling: true,
            child: const CommunicationsScreen(),
          ),
      automation: (_) => AppLayoutPage(
            route: automation,
            title: AppConstants.navAutomation,
            selfScrolling: true,
            child: const AutomationScreen(),
          ),
      automationDetail: (_) => AppLayoutPage(
            route: automation,
            title: 'Automation Detail',
            child: const _PlaceholderBody(title: 'Automation Detail'),
          ),
      reports: (_) => AppLayoutPage(
            route: reports,
            title: AppConstants.navReports,
            selfScrolling: true,
            child: const ReportsScreen(),
          ),
      notifications: (_) => AppLayoutPage(
            route: notifications,
            title: AppConstants.navNotifications,
            selfScrolling: true,
            child: const NotificationsScreen(),
          ),
      users: (_) => AppLayoutPage(
            route: users,
            title: AppConstants.navUsers,
            selfScrolling: true,
            child: const AdminConsoleScreen(),
          ),
      userDetail: (_) => AppLayoutPage(
            route: users,
            title: 'User Detail',
            selfScrolling: true,
            child: const AdminConsoleScreen(),
          ),
      profile: (_) => AppLayoutPage(
            route: profile,
            title: AppConstants.navProfile,
            selfScrolling: true,
            child: const ProfileScreen(),
          ),
      settings: (_) => AppLayoutPage(
            route: settings,
            title: AppConstants.navSettings,
            selfScrolling: true,
            child: const SettingsScreen(),
          ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholders
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderBody extends StatelessWidget {
  final String title;
  const _PlaceholderBody({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_outlined,
              size: 48, color: Color(0xFF6C4CE8)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('This module will be built in a later phase.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
