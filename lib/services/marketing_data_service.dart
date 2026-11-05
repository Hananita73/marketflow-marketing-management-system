import '../models/campaign.dart';
import '../models/customer.dart';
import '../models/lead.dart';
import '../models/opportunity.dart';
import '../models/budget.dart';
import '../core/constants.dart';
// ─────────────────────────────────────────────────────────────────────────────
// MarketingDataService
//
// A thin read-only façade over the existing in-memory repositories.
// The AI service calls ONLY these methods — it never imports a repository
// directly, keeping AI logic decoupled from data storage.
//
// All values returned here come directly from the existing data models,
// so the AI will never invent numbers.
// ─────────────────────────────────────────────────────────────────────────────

class MarketingDataService {
  MarketingDataService._();

  // ── Campaigns ─────────────────────────────────────────────────────────────

  static List<Campaign> allCampaigns() => CampaignRepository.getAll();

  static List<Campaign> activeCampaigns() =>
      CampaignRepository.getAll()
          .where((c) => c.status == AppConstants.statusActive)
          .toList();

  static Campaign? topRoiCampaign() {
    final active = allCampaigns().where((c) => c.roi > 0).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.roi.compareTo(a.roi));
    return active.first;
  }

  static CampaignBudgetSummary budgetSummary() {
    final campaigns = allCampaigns();
    final totalAllocated = campaigns.fold<double>(0, (s, c) => s + c.budget);
    final totalSpent     = campaigns.fold<double>(0, (s, c) => s + c.spent);
    return CampaignBudgetSummary(
      totalAllocated: totalAllocated,
      totalSpent: totalSpent,
      remaining: totalAllocated - totalSpent,
      utilization: totalAllocated > 0 ? totalSpent / totalAllocated : 0,
    );
  }

  static double averageRoi() {
    final withRoi = allCampaigns().where((c) => c.roi > 0).toList();
    if (withRoi.isEmpty) return 0;
    return withRoi.fold<double>(0, (s, c) => s + c.roi) / withRoi.length;
  }

  static int totalLeadsFromCampaigns() =>
      allCampaigns().fold<int>(0, (s, c) => s + c.leads);

  static int totalConversions() =>
      allCampaigns().fold<int>(0, (s, c) => s + c.conversions);

  static int totalImpressions() =>
      allCampaigns().fold<int>(0, (s, c) => s + c.impressions);

  // ── Leads ──────────────────────────────────────────────────────────────────

  static List<Lead> allLeads() => LeadRepository.getAll();

  static LeadSummary leadSummary() {
    final leads = allLeads();
    return LeadSummary(
      total: leads.length,
      newCount: leads.where((l) => l.status == AppConstants.leadNew).length,
      contacted: leads.where((l) => l.status == AppConstants.leadContacted).length,
      qualified: leads.where((l) => l.status == AppConstants.leadQualified).length,
      unqualified: leads.where((l) => l.status == AppConstants.leadUnqualified).length,
      converted: leads.where((l) => l.status == AppConstants.leadConverted).length,
      highPriority: leads.where((l) => l.priority == 'High').length,
      avgScore: leads.isEmpty
          ? 0
          : leads.fold<int>(0, (s, l) => s + l.score) / leads.length,
    );
  }

  /// Returns leads that likely need attention: New or Contacted with high score.
  static List<Lead> leadsNeedingAttention() {
    return allLeads()
        .where((l) =>
            (l.status == AppConstants.leadNew ||
                l.status == AppConstants.leadContacted) &&
            l.score >= 70)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  static List<Customer> allCustomers() => CustomerRepository.getAll();

  static CustomerSummary customerSummary() {
    final customers = allCustomers();
    return CustomerSummary(
      total: customers.length,
      active: customers.where((c) => c.status == AppConstants.statusActive).length,
      vip: customers.where((c) => c.segment == 'VIP').length,
      corporate: customers.where((c) => c.segment == 'Corporate').length,
      retail: customers.where((c) => c.segment == 'Retail').length,
    );
  }

  // ── Opportunities ─────────────────────────────────────────────────────────

  static List<Opportunity> allOpportunities() =>
      OpportunityRepository.getAll();

  static OpportunitySummary opportunitySummary() {
    final opps = allOpportunities();
    final totalValue = opps.fold<double>(0, (s, o) => s + o.value);
    final wonValue   = opps
        .where((o) => o.stage == 'Won')
        .fold<double>(0, (s, o) => s + o.value);
    final weightedValue = opps.fold<double>(
        0, (s, o) => s + o.value * o.probability / 100);

    return OpportunitySummary(
      total: opps.length,
      totalValue: totalValue,
      wonValue: wonValue,
      weightedPipelineValue: weightedValue,
      byStage: {
        for (final stage in ['New', 'Qualified', 'Proposal', 'Negotiation', 'Won'])
          stage: opps.where((o) => o.stage == stage).length,
      },
    );
  }

  // ── Dashboard KPI snapshot ─────────────────────────────────────────────────

  static DashboardSnapshot dashboardSnapshot() {
    // Use live repository data — not hardcoded mock values.
    final leads     = allLeads();
    final budgets   = BudgetRepository.getAll();
    final campaigns = allCampaigns();

    final totalLeadsCount  = leads.length;
    final totalBudget      = budgets.fold<double>(0, (s, b) => s + b.allocated);
    final totalSpent       = budgets.fold<double>(0, (s, b) => s + b.spent);
    final totalRemaining   = totalBudget - totalSpent;
    final avgRoi           = averageRoi();
    final totalConv        = totalConversions();
    final totalLeadsFromC  = totalLeadsFromCampaigns();
    final convRate         = totalLeadsFromC > 0
        ? (totalConv / totalLeadsFromC * 100)
        : 0.0;

    String fmt(double v) {
      if (v >= 1000000) return 'ETB ${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000)    return 'ETB ${(v / 1000).toStringAsFixed(0)}K';
      return 'ETB ${v.toStringAsFixed(0)}';
    }

    return DashboardSnapshot(
      totalCampaigns:  campaigns.length,
      activeCampaigns: activeCampaigns().length,
      totalLeads:      totalLeadsCount > 0 ? '$totalLeadsCount' : '0',
      budgetTotal:     fmt(totalBudget),
      budgetSpent:     fmt(totalSpent),
      budgetRemaining: fmt(totalRemaining),
      overallRoi:      avgRoi > 0 ? '${avgRoi.toStringAsFixed(1)}x' : '0x',
      conversionRate:  '${convRate.toStringAsFixed(1)}%',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Value objects returned by the service
// ─────────────────────────────────────────────────────────────────────────────

class CampaignBudgetSummary {
  final double totalAllocated;
  final double totalSpent;
  final double remaining;
  final double utilization; // 0.0–1.0

  const CampaignBudgetSummary({
    required this.totalAllocated,
    required this.totalSpent,
    required this.remaining,
    required this.utilization,
  });
}

class LeadSummary {
  final int total;
  final int newCount;
  final int contacted;
  final int qualified;
  final int unqualified;
  final int converted;
  final int highPriority;
  final double avgScore;

  const LeadSummary({
    required this.total,
    required this.newCount,
    required this.contacted,
    required this.qualified,
    required this.unqualified,
    required this.converted,
    required this.highPriority,
    required this.avgScore,
  });
}

class CustomerSummary {
  final int total;
  final int active;
  final int vip;
  final int corporate;
  final int retail;

  const CustomerSummary({
    required this.total,
    required this.active,
    required this.vip,
    required this.corporate,
    required this.retail,
  });
}

class OpportunitySummary {
  final int total;
  final double totalValue;
  final double wonValue;
  final double weightedPipelineValue;
  final Map<String, int> byStage;

  const OpportunitySummary({
    required this.total,
    required this.totalValue,
    required this.wonValue,
    required this.weightedPipelineValue,
    required this.byStage,
  });
}

class DashboardSnapshot {
  final int totalCampaigns;
  final int activeCampaigns;
  final String totalLeads;
  final String budgetTotal;
  final String budgetSpent;
  final String budgetRemaining;
  final String overallRoi;
  final String conversionRate;

  const DashboardSnapshot({
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.totalLeads,
    required this.budgetTotal,
    required this.budgetSpent,
    required this.budgetRemaining,
    required this.overallRoi,
    required this.conversionRate,
  });
}
