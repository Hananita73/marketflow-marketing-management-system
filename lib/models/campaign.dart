import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/colors.dart';
import '../services/admin_alert_service.dart';
import '../services/campaign_remote_service.dart';

enum CampaignChannel {
  email,
  socialMedia,
  webPush,
  sms,
  influencer,
  search,
  display;

  String get label {
    switch (this) {
      case CampaignChannel.email:       return 'Email';
      case CampaignChannel.socialMedia: return 'Social Media';
      case CampaignChannel.webPush:     return 'Web Push';
      case CampaignChannel.sms:         return 'SMS';
      case CampaignChannel.influencer:  return 'Influencer';
      case CampaignChannel.search:      return 'Search';
      case CampaignChannel.display:     return 'Display';
    }
  }

  IconData get icon {
    switch (this) {
      case CampaignChannel.email:       return Icons.email_outlined;
      case CampaignChannel.socialMedia: return Icons.share_outlined;
      case CampaignChannel.webPush:     return Icons.notifications_outlined;
      case CampaignChannel.sms:         return Icons.sms_outlined;
      case CampaignChannel.influencer:  return Icons.star_outline;
      case CampaignChannel.search:      return Icons.search;
      case CampaignChannel.display:     return Icons.display_settings_outlined;
    }
  }

  Color get color {
    switch (this) {
      case CampaignChannel.email:       return AppColors.primary;
      case CampaignChannel.socialMedia: return AppColors.info;
      case CampaignChannel.webPush:     return const Color(0xFFBB5CF8);
      case CampaignChannel.sms:         return AppColors.warning;
      case CampaignChannel.influencer:  return AppColors.success;
      case CampaignChannel.search:      return AppColors.danger;
      case CampaignChannel.display:     return AppColors.textSecondary;
    }
  }
}

enum CampaignObjective {
  brandAwareness,
  leadGeneration,
  salesConversion,
  customerRetention,
  productLaunch,
  eventPromotion;

  String get label {
    switch (this) {
      case CampaignObjective.brandAwareness:    return 'Brand Awareness';
      case CampaignObjective.leadGeneration:    return 'Lead Generation';
      case CampaignObjective.salesConversion:   return 'Sales Conversion';
      case CampaignObjective.customerRetention: return 'Customer Retention';
      case CampaignObjective.productLaunch:     return 'Product Launch';
      case CampaignObjective.eventPromotion:    return 'Event Promotion';
    }
  }
}

class CampaignActivity {
  final String description;
  final String date;
  final IconData icon;
  final Color iconColor;

  const CampaignActivity({
    required this.description,
    required this.date,
    required this.icon,
    required this.iconColor,
  });
}

class CampaignCoupon {
  final String code;
  final String discount;
  final int usageLimit;
  final int usedCount;
  final String expiryDate;

  const CampaignCoupon({
    required this.code,
    required this.discount,
    required this.usageLimit,
    required this.usedCount,
    required this.expiryDate,
  });
}

class CampaignExpense {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String approvedBy;
  final String status; // 'pending', 'approved', 'rejected'

  const CampaignExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.approvedBy,
    required this.status,
  });

  Color get statusColor {
    if (status == 'approved') return AppColors.success;
    if (status == 'pending') return AppColors.warning;
    return AppColors.danger;
  }
}

class Campaign {
  final String id;
  final String name;
  final String description;
  final String targetAudience;
  final String notes;
  final CampaignObjective objective;
  final List<CampaignChannel> channels;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double budget;
  final double spent;
  final int leads;
  final int conversions;
  final int impressions;
  final double roi;
  final List<CampaignActivity> activities;
  final List<CampaignCoupon> coupons;
  final List<CampaignExpense> expenses;
  final String approvalComments;
  final String approvedBy;
  final String submittedBy;  // who submitted for approval (self-approval prevention)

  const Campaign({
    required this.id,
    required this.name,
    required this.description,
    this.targetAudience = '',
    this.notes = '',
    required this.objective,
    required this.channels,
    required this.status,
    this.startDate,
    this.endDate,
    required this.budget,
    required this.spent,
    required this.leads,
    required this.conversions,
    required this.impressions,
    required this.roi,
    required this.activities,
    required this.coupons,
    required this.expenses,
    this.approvalComments = '',
    this.approvedBy = '',
    this.submittedBy = '',
  });

  double get budgetUtilization => budget > 0 ? ((spent + expenses.fold(0, (s, e) => s + e.amount)) / budget).clamp(0.0, 1.0) : 0.0;
  double get remaining => budget - spent - expenses.fold(0, (s, e) => s + e.amount);

  double get approvedExpenses => expenses.where((e) => e.status == 'approved').fold(0, (s, e) => s + e.amount);

  /// Returns true if the campaign is in the approval workflow.
  bool get isPendingApproval => status == AppConstants.statusPendingApproval;

  /// Returns true if the campaign has been approved.
  bool get isApproved => status == AppConstants.statusApproved;

  /// Returns true if the campaign was rejected.
  bool get isRejected => status == AppConstants.statusRejected;

  /// Returns true if changes have been requested.
  bool get isChangesRequested => status == AppConstants.statusChangesRequested;

  /// Total pending (unapproved) expenses.
  double get pendingExpenses => expenses.where((e) => e.status == 'pending').fold(0, (s, e) => s + e.amount);

  Campaign copyWith({
    String? name,
    String? description,
    String? targetAudience,
    String? notes,
    CampaignObjective? objective,
    List<CampaignChannel>? channels,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    double? spent,
    int? leads,
    int? conversions,
    int? impressions,
    double? roi,
    List<CampaignActivity>? activities,
    List<CampaignCoupon>? coupons,
    List<CampaignExpense>? expenses,
    String? approvalComments,
    String? approvedBy,
    String? submittedBy,
  }) {
    return Campaign(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAudience: targetAudience ?? this.targetAudience,
      notes: notes ?? this.notes,
      objective: objective ?? this.objective,
      channels: channels ?? this.channels,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
      leads: leads ?? this.leads,
      conversions: conversions ?? this.conversions,
      impressions: impressions ?? this.impressions,
      roi: roi ?? this.roi,
      activities: activities ?? this.activities,
      coupons: coupons ?? this.coupons,
      expenses: expenses ?? this.expenses,
      approvalComments: approvalComments ?? this.approvalComments,
      approvedBy: approvedBy ?? this.approvedBy,
      submittedBy: submittedBy ?? this.submittedBy,
    );
  }
}

class CampaignRepository {
  CampaignRepository._();

  static final List<Campaign> _campaigns = [    Campaign(
      id: 'C001',
      name: 'Summer Sale 2026',
      description: 'Boost summer product sales with targeted promotions across digital channels.',
      targetAudience: 'Online shoppers, 18-45',
      objective: CampaignObjective.salesConversion,
      channels: [CampaignChannel.socialMedia, CampaignChannel.email, CampaignChannel.search],
      status: AppConstants.statusActive,
      startDate: DateTime(2026, 5, 10),
      endDate: DateTime(2026, 6, 10),
      budget: 50000,
      spent: 32450,
      leads: 320,
      conversions: 85,
      impressions: 45000,
      roi: 5.2,
      activities: [
        CampaignActivity(description: 'Campaign launched', date: 'May 10, 2026', icon: Icons.rocket_launch_outlined, iconColor: AppColors.primary),
        CampaignActivity(description: 'Social ads went live', date: 'May 11, 2026', icon: Icons.share_outlined, iconColor: AppColors.success),
      ],
      coupons: [
        CampaignCoupon(code: 'SUMMER20', discount: '20% off', usageLimit: 500, usedCount: 234, expiryDate: 'Jun 10, 2026'),
      ],
      expenses: [
        CampaignExpense(
          id: 'EXP001',
          description: 'Google Ads placement',
          amount: 12000,
          date: DateTime(2026, 5, 15),
          approvedBy: 'Hana Tsegaye',
          status: 'approved',
        ),
        CampaignExpense(
          id: 'EXP002',
          description: 'Facebook Ads boost',
          amount: 8500,
          date: DateTime(2026, 5, 20),
          approvedBy: 'Hana Tsegaye',
          status: 'approved',
        ),
        CampaignExpense(
          id: 'EXP003',
          description: 'SMS gateway fees',
          amount: 2450,
          date: DateTime(2026, 5, 25),
          approvedBy: 'Hana Tsegaye',
          status: 'pending',
        ),
      ],
    ),
    Campaign(
      id: 'C002',
      name: 'Brand Awareness Q2',
      description: 'Increase brand visibility across social platforms.',
      targetAudience: 'General consumers, 18-35',
      objective: CampaignObjective.brandAwareness,
      channels: [CampaignChannel.socialMedia, CampaignChannel.email],
      status: AppConstants.statusActive,
      startDate: DateTime(2026, 4, 20),
      endDate: DateTime(2026, 5, 20),
      budget: 40000,
      spent: 28300,
      leads: 210,
      conversions: 45,
      impressions: 38000,
      roi: 3.8,
      activities: [
        CampaignActivity(description: 'Campaign brief approved', date: 'Apr 20, 2026', icon: Icons.check_circle_outline, iconColor: AppColors.success),
      ],
      coupons: [],
      expenses: [],
    ),
    Campaign(
      id: 'C003',
      name: 'Email Nurture May',
      description: 'Nurture leads via email sequences and drip campaigns.',
      targetAudience: 'Existing leads, 25-50',
      objective: CampaignObjective.leadGeneration,
      channels: [CampaignChannel.email],
      status: AppConstants.statusCompleted,
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 15),
      budget: 10000,
      spent: 7650,
      leads: 180,
      conversions: 62,
      impressions: 12000,
      roi: 6.1,
      activities: [
        CampaignActivity(description: 'Email sequence deployed', date: 'May 1, 2026', icon: Icons.email_outlined, iconColor: AppColors.info),
      ],
      coupons: [],
      expenses: [],
    ),
    Campaign(
      id: 'C004',
      name: 'Product Launch X',
      description: 'Launch of product X with multi-channel advertising.',
      targetAudience: 'Tech enthusiasts, 22-40',
      objective: CampaignObjective.salesConversion,
      channels: [CampaignChannel.search, CampaignChannel.socialMedia],
      status: AppConstants.statusPaused,
      startDate: DateTime(2026, 5, 5),
      endDate: DateTime(2026, 6, 5),
      budget: 60000,
      spent: 21200,
      leads: 150,
      conversions: 28,
      impressions: 25000,
      roi: 2.9,
      activities: [
        CampaignActivity(description: 'Campaign paused for review', date: 'May 12, 2026', icon: Icons.pause_circle_outline, iconColor: AppColors.warning),
      ],
      coupons: [
        CampaignCoupon(code: 'LAUNCHX10', discount: '10% off', usageLimit: 300, usedCount: 89, expiryDate: 'Jun 5, 2026'),
      ],
      expenses: [],
    ),
    Campaign(
      id: 'C005',
      name: 'Re-engagement May',
      description: 'Win back inactive users with personalized offers.',
      targetAudience: 'Inactive users, 25-55',
      objective: CampaignObjective.customerRetention,
      channels: [CampaignChannel.email, CampaignChannel.sms],
      status: AppConstants.statusActive,
      startDate: DateTime(2026, 5, 8),
      endDate: DateTime(2026, 5, 29),
      budget: 15000,
      spent: 8900,
      leads: 95,
      conversions: 38,
      impressions: 8000,
      roi: 4.7,
      activities: [
        CampaignActivity(description: 'Re-engagement emails sent', date: 'May 8, 2026', icon: Icons.email_outlined, iconColor: AppColors.info),
      ],
      coupons: [
        CampaignCoupon(code: 'COMEBACK15', discount: '15% off', usageLimit: 200, usedCount: 67, expiryDate: 'May 29, 2026'),
      ],
      expenses: [],
    ),
    Campaign(
      id: 'C006',
      name: 'Holiday Promo',
      description: 'Holiday season promotion across social and search.',
      targetAudience: 'All segments',
      objective: CampaignObjective.salesConversion,
      channels: [CampaignChannel.socialMedia, CampaignChannel.search, CampaignChannel.display],
      status: AppConstants.statusDraft,
      startDate: null,
      endDate: null,
      budget: 30000,
      spent: 0,
      leads: 0,
      conversions: 0,
      impressions: 0,
      roi: 0,
      activities: [],
      coupons: [],
      expenses: [],
    ),
  ];

  static bool _initialized = false;

  /// Loads campaigns from Supabase once at startup (called from main.dart).
  ///
  /// Behaviour:
  ///   • Remote fetch succeeds with rows → local cache is replaced by them.
  ///   • Remote table is empty           → bundled seed data is pushed to
  ///                                       Supabase (first-run bootstrap).
  ///   • Backend unreachable/not set up  → seed data stays in memory and the
  ///                                       app keeps working offline.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await CampaignRemoteService.fetchAll();
    if (remote == null) return; // offline mode — keep seed data
    if (remote.isEmpty) {
      await CampaignRemoteService.seed(_campaigns);
    } else {
      _campaigns
        ..clear()
        ..addAll(remote);
    }
  }

  static List<Campaign> getAll() => List.unmodifiable(_campaigns);

  static Campaign? findById(String id) {
    try {
      return _campaigns.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static void update(Campaign updated) {
    final index = _campaigns.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _campaigns[index] = updated;
      CampaignRemoteService.upsert(updated); // fire-and-forget sync
    }
  }

  static void add(Campaign campaign) {
    _campaigns.add(campaign);
    AdminAlertService.report(
      event: 'Campaign created',
      message: 'Campaign "${campaign.name}" (${campaign.id}) was created.',
      severity: 'info',
      details: {
        'id': campaign.id,
        'status': campaign.status,
        'budget': campaign.budget,
      },
    );
    // Persist to database (fire-and-forget, fails silently in offline mode)
    CampaignRemoteService.upsert(campaign).then((_) {
      // Campaign persisted to database
    }).onError((_, _) {
      // Failed to persist - running in offline mode, local data remains valid
    });
  }

  // FIX: new method — mutates the real backing list directly.
  // getAll() returns List.unmodifiable(_campaigns), so calling
  // .removeWhere() on its result throws "Unsupported operation: remove".
  static void remove(String id) {
    final removed = findById(id);
    _campaigns.removeWhere((c) => c.id == id);
    AdminAlertService.report(
      event: 'Campaign deleted',
      message: removed == null
          ? 'Campaign $id was deleted.'
          : 'Campaign "${removed.name}" ($id) was deleted.',
      severity: 'warning',
      details: {'id': id, 'name': removed?.name},
    );
    CampaignRemoteService.delete(id); // fire-and-forget sync
  }

  static String nextId() {
    // Guard against empty list: reduce() throws StateError on an empty
    // iterable.  If all campaigns have been deleted, start from C001.
    if (_campaigns.isEmpty) return 'C001';
    final maxNum = _campaigns
        .map((c) => int.tryParse(c.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'C${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  // ── Campaign approval workflow ─────────────────────────────────────────────

  /// Submits a draft campaign for manager approval.
  /// Changes status from 'Draft' to 'Pending Approval'.
  static void submitForApproval(String id) {
    final campaign = findById(id);
    if (campaign == null) return;
    if (campaign.status != AppConstants.statusDraft) return;
    final updated = campaign.copyWith(status: AppConstants.statusPendingApproval);
    update(updated);
  }

  /// Approves a pending campaign. Sets status to 'Approved' and records
  /// the approver and optional comments. Only managers/admins should call this.
  static void approveCampaign(String id, String approverName, {String comments = ''}) {
    final campaign = findById(id);
    if (campaign == null) return;
    if (campaign.status != AppConstants.statusPendingApproval) return;
    final updated = campaign.copyWith(
      status: AppConstants.statusApproved,
      approvedBy: approverName,
      approvalComments: comments,
    );
    update(updated);
  }

  /// Rejects a pending campaign. Sets status to 'Rejected' and records
  /// the approver and rejection comments. Only managers/admins should call this.
  static void rejectCampaign(String id, String approverName, String comments) {
    final campaign = findById(id);
    if (campaign == null) return;
    if (campaign.status != AppConstants.statusPendingApproval) return;
    final updated = campaign.copyWith(
      status: AppConstants.statusRejected,
      approvedBy: approverName,
      approvalComments: comments,
    );
    update(updated);
  }

  /// Activates an approved campaign.
  static void activateCampaign(String id) {
    final campaign = findById(id);
    if (campaign == null) return;
    if (campaign.status != AppConstants.statusApproved) return;
    final updated = campaign.copyWith(status: AppConstants.statusActive);
    update(updated);
  }

  // ── Expense management ──────────────────────────────────────────────────────

  /// Adds a new expense record to a campaign.
  /// Expenses start in 'pending' status and must be approved by a manager.
  static void addExpense(String campaignId, CampaignExpense expense) {
    final campaign = findById(campaignId);
    if (campaign == null) return;
    final updatedExpenses = [...campaign.expenses, expense];
    final updated = campaign.copyWith(expenses: updatedExpenses);
    update(updated);
  }

  /// Approves a pending expense on a campaign.
  /// Only managers/admins should call this.
  static void approveExpense(String campaignId, String expenseId, String approverName) {
    final campaign = findById(campaignId);
    if (campaign == null) return;
    final updatedExpenses = campaign.expenses.map((e) {
      if (e.id == expenseId) {
        return CampaignExpense(
          id: e.id,
          description: e.description,
          amount: e.amount,
          date: e.date,
          approvedBy: approverName,
          status: AppConstants.expenseApproved,
        );
      }
      return e;
    }).toList();
    final updated = campaign.copyWith(expenses: updatedExpenses);
    update(updated);
  }

  /// Rejects a pending expense on a campaign.
  /// Only managers/admins should call this.
  static void rejectExpense(String campaignId, String expenseId, String approverName) {
    final campaign = findById(campaignId);
    if (campaign == null) return;
    final updatedExpenses = campaign.expenses.map((e) {
      if (e.id == expenseId) {
        return CampaignExpense(
          id: e.id,
          description: e.description,
          amount: e.amount,
          date: e.date,
          approvedBy: approverName,
          status: AppConstants.expenseRejected,
        );
      }
      return e;
    }).toList();
    final updated = campaign.copyWith(expenses: updatedExpenses);
    update(updated);
  }

  /// Returns all campaigns pending approval (for manager dashboard).
  static List<Campaign> getPendingApproval() {
    return _campaigns.where((c) => c.status == AppConstants.statusPendingApproval).toList();
  }

  /// Returns all campaigns with pending expenses (for manager dashboard).
  static List<Campaign> getWithPendingExpenses() {
    return _campaigns.where((c) => c.expenses.any((e) => e.status == 'pending')).toList();
  }

  /// Generates the next expense ID for a campaign.
  static String nextExpenseId(String campaignId) {
    final campaign = findById(campaignId);
    if (campaign == null || campaign.expenses.isEmpty) return '${campaignId}_EXP001';
    final maxNum = campaign.expenses
        .map((e) => int.tryParse(e.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return '${campaignId}_EXP${(maxNum + 1).toString().padLeft(3, '0')}';
  }
}
