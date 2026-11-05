/// App-wide constants for the Marketing Management System.
/// Grouping them here keeps magic numbers out of UI code.
class AppConstants {
  AppConstants._();

  // ── App identity ──────────────────────────────────────────────────────────
  static const String appName = 'Marketing Management System';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Marketing Management';

  // ── Layout ────────────────────────────────────────────────────────────────
  /// Fixed width of the desktop sidebar in pixels (240–260px range).
  static const double sidebarWidth = 250.0;

  /// Height of the top bar.
  static const double topBarHeight = 64.0;

  /// Padding used inside page content areas.
  static const double pagePadding = 24.0;

  /// Smaller padding for tighter sections.
  static const double cardPadding = 16.0;

  /// Default gap between grid / flex children.
  static const double itemSpacing = 16.0;

  /// Larger section gap.
  static const double sectionSpacing = 24.0;

  // ── Breakpoints ───────────────────────────────────────────────────────────
  /// Below this width the sidebar becomes a drawer (mobile).
  static const double mobileBreakpoint = 768.0;

  /// At or above this width the permanent sidebar is shown beside content.
  /// Set to 960px so laptops and mid-size windows always see the sidebar.
  static const double sidebarBreakpoint = 960.0;

  /// At or above this width content switches to a multi-column desktop layout.
  static const double desktopBreakpoint = 1200.0;

  /// Legacy alias — prefer [desktopBreakpoint].
  static const double tabletBreakpoint = desktopBreakpoint;

  // ── Border radius ─────────────────────────────────────────────────────────
  static const double radiusSmall = 6.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXL = 16.0;

  // ── Animation durations ───────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);

  // ── Sidebar navigation labels ─────────────────────────────────────────────
  // These are used in both the sidebar widget and the routes map.
  static const String navDashboard = 'Dashboard';
  static const String navCampaigns = 'Campaigns';
  static const String navCustomers = 'Customers';
  static const String navLeads = 'Leads';
  static const String navOpportunities = 'Opportunities';
  static const String navInfluencers = 'Influencers';
  static const String navContent = 'Content';
  static const String navPromotions = 'Promotions';
  static const String navBudget = 'Budget';
  static const String navCommunications = 'Communications';
  static const String navAutomation = 'Automation';
  static const String navReports = 'Reports';
  static const String navNotifications = 'Notifications';
  static const String navUsers = 'Users & Roles';
  static const String navProfile = 'Profile';
  static const String navSettings = 'Settings';

  // ── Mock / data limits ────────────────────────────────────────────────────
  /// Number of items shown per page in paginated tables.
  static const int defaultPageSize = 10;

  // ── Status labels (shared across modules) ─────────────────────────────────
  static const String statusActive = 'Active';
  static const String statusDraft = 'Draft';
  static const String statusPaused = 'Paused';
  static const String statusCompleted = 'Completed';
  static const String statusCancelled = 'Cancelled';

  // ── Campaign approval workflow statuses ──────────────────────────────────
  static const String statusPendingApproval = 'Pending Approval';
  static const String statusApproved = 'Approved';
  static const String statusRejected = 'Rejected';
  static const String statusChangesRequested = 'Changes Requested';

  // ── Database role strings ─────────────────────────────────────────────────
  // Five roles, one per user. These match the public.users.role column.
  static const String dbRoleAdmin            = 'admin';
  static const String dbRoleMarketingManager = 'marketing_manager';
  static const String dbRoleMarketingClerk   = 'marketing_clerk';   // formerly marketing_staff
  static const String dbRoleContentCreator   = 'content_creator';
  static const String dbRoleViewer           = 'viewer';

  // ── Expense statuses ──────────────────────────────────────────────────────
  static const String expensePending = 'pending';
  static const String expenseApproved = 'approved';
  static const String expenseRejected = 'rejected';

  // ── Expense payment statuses (accounting state) ────────────────────────────
  static const String paymentPending = 'Pending';
  static const String paymentPaid = 'Paid';
  static const String paymentPartial = 'Partial';

  // ── Campaign-customer participation statuses ──────────────────────────────
  static const String participationAssigned = 'Assigned';
  static const String participationActive = 'Active';
  static const String participationCompleted = 'Completed';
  static const String participationWithdrawn = 'Withdrawn';

  // ── Campaign-customer engagement statuses ─────────────────────────────────
  static const String engagementPending = 'Pending';
  static const String engagementEngaged = 'Engaged';
  static const String engagementUnresponsive = 'Unresponsive';

  // ── Campaign-customer conversion statuses ─────────────────────────────────
  static const String conversionNotConverted = 'Not Converted';
  static const String conversionInterested = 'Interested';
  static const String conversionConverted = 'Converted';

  // ── Budget categories (reusable across campaigns) ──────────────────────────
  static const List<String> budgetCategories = [
    'Digital Advertising',
    'Social Media Marketing',
    'Content Production',
    'Influencer Marketing',
    'Events',
    'Promotions',
    'Printing and Distribution',
    'Research',
    'Other Marketing Expenses',
  ];

  // ── Expense categories ────────────────────────────────────────────────────
  static const List<String> expenseCategories = [
    'Digital Advertising',
    'Social Media Marketing',
    'Content Production',
    'Influencer Marketing',
    'Events',
    'Promotions',
    'Printing and Distribution',
    'Research',
    'Other Marketing Expenses',
  ];

  // ── Lead statuses ─────────────────────────────────────────────────────────
  static const String leadNew = 'New';
  static const String leadContacted = 'Contacted';
  static const String leadQualified = 'Qualified';
  static const String leadUnqualified = 'Unqualified';
  static const String leadConverted = 'Converted';

  // ── Opportunity stages ────────────────────────────────────────────────────
  static const String stageQualification = 'Qualification';
  static const String stageNeedsAnalysis = 'Needs Analysis';
  static const String stageProposal = 'Proposal';
  static const String stageNegotiation = 'Negotiation';
  static const String stageClosedWon = 'Closed Won';
  static const String stageClosedLost = 'Closed Lost';

  // ── User roles ────────────────────────────────────────────────────────────
  // Display names (used in UI labels)
  static const String roleMarketingManager = 'Marketing Manager';
  static const String roleMarketingClerk = 'Marketing Staff';
}

