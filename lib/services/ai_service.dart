import 'dart:math' as math;
import '../core/routes.dart';
import 'marketing_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiMessage — a single chat turn
// ─────────────────────────────────────────────────────────────────────────────

enum AiMessageRole { user, assistant }

class AiMessage {
  final AiMessageRole role;
  final String text;
  final DateTime timestamp;

  AiMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// AiResponse — result envelope returned by AiService.query()
// ─────────────────────────────────────────────────────────────────────────────

enum AiResponseStatus { ok, error }

class AiResponse {
  final AiResponseStatus status;
  final String text;

  const AiResponse.ok(this.text) : status = AiResponseStatus.ok;
  const AiResponse.error(this.text) : status = AiResponseStatus.error;
}

// ─────────────────────────────────────────────────────────────────────────────
// AiService
//
// Processes user questions and returns answers grounded exclusively in the
// data exposed by MarketingDataService.  No data is invented here.
//
// Architecture:
//   AiAssistantPanel  ──→  AiService.query(question, currentRoute)
//                              ──→  MarketingDataService  (real repo data)
//                              ──→  AiResponse (text)
//
// When a real AI backend is added later, only this class needs to change.
// The UI and data layers remain untouched.
// ─────────────────────────────────────────────────────────────────────────────

class AiService {
  AiService._();

  // Simulated network latency so the loading indicator is visible.
  static const Duration _delay = Duration(milliseconds: 900);

  /// Process a single user [question] and return an [AiResponse].
  /// [currentRoute] is used to add page-context awareness.
  static Future<AiResponse> query({
    required String question,
    required String currentRoute,
  }) async {
    await Future.delayed(_delay);

    try {
      final q = question.trim().toLowerCase();
      final answer = _route(q, currentRoute);
      return AiResponse.ok(answer);
    } catch (_) {
      return const AiResponse.error(
        'Unable to analyze the data right now. Please try again.',
      );
    }
  }

  // ── Main routing logic ───────────────────────────────────────────────────

  static String _route(String q, String route) {
    // ── ROI questions ──────────────────────────────────────────────────────
    if (_matches(q, ['highest roi', 'best roi', 'top roi', 'most roi',
                     'best performing campaign', 'top performing campaign',
                     'best campaign'])) {
      return _highestRoi();
    }
    if (_matches(q, ['average roi', 'avg roi', 'mean roi', 'overall roi'])) {
      return _averageRoi();
    }
    if (_matches(q, ['roi', 'return on investment']) &&
        !_matches(q, ['campaign'])) {
      return _roiSummary(route);
    }

    // ── Budget questions ───────────────────────────────────────────────────
    if (_matches(q, ['budget', 'spend', 'spending', 'allocated', 'remaining',
                     'how much', 'total spend', 'budget performance',
                     'budget overview'])) {
      return _budgetSummary();
    }

    // ── Campaign questions ─────────────────────────────────────────────────
    if (_matches(q, ['show my top', 'top campaign', 'list campaign',
                     'all campaign', 'campaign list', 'my campaigns'])) {
      return _topCampaigns();
    }
    if (_matches(q, ['active campaign', 'running campaign',
                     'current campaign'])) {
      return _activeCampaigns();
    }
    if (_matches(q, ['campaign status', 'campaign summary',
                     'campaign overview', 'how many campaign'])) {
      return _campaignSummary();
    }
    if (_matches(q, ['campaign']) && route == AppRoutes.campaigns) {
      return _campaignSummary();
    }

    // ── Leads questions ────────────────────────────────────────────────────
    if (_matches(q, ['need attention', 'need follow', 'follow up',
                     'priority lead', 'urgent lead'])) {
      return _leadsNeedingAttention();
    }
    if (_matches(q, ['lead count', 'how many lead', 'total lead',
                     'lead number', 'lead statistic', 'lead summary',
                     'lead overview', 'lead status'])) {
      return _leadSummary();
    }
    if (_matches(q, ['lead conversion', 'convert lead', 'converted lead'])) {
      return _leadConversionInfo();
    }
    if (_matches(q, ['lead']) && route == AppRoutes.leads) {
      return _leadSummary();
    }

    // ── Customer questions ─────────────────────────────────────────────────
    if (_matches(q, ['customer statistic', 'customer summary',
                     'customer overview', 'how many customer',
                     'total customer', 'customer count',
                     'customer segment', 'customer activity'])) {
      return _customerSummary();
    }
    if (_matches(q, ['customer']) && route == AppRoutes.customers) {
      return _customerSummary();
    }

    // ── Opportunity questions ──────────────────────────────────────────────
    if (_matches(q, ['opportunity', 'pipeline', 'deal', 'stage',
                     'opportunity value', 'pipeline value',
                     'opportunity performance'])) {
      return _opportunitySummary();
    }

    // ── Performance / summary questions ───────────────────────────────────
    if (_matches(q, ['this month', 'monthly performance', 'month summary',
                     'summarize', 'performance summary', 'marketing summary',
                     'marketing performance', 'overall performance',
                     'how am i doing', 'how are we doing'])) {
      return _overallSummary();
    }

    // ── Dashboard / general overview ──────────────────────────────────────
    if (_matches(q, ['dashboard', 'overview', 'snapshot', 'kpi',
                     'key metric'])) {
      return _dashboardSnapshot();
    }

    // ── Conversions ───────────────────────────────────────────────────────
    if (_matches(q, ['conversion rate', 'total conversion',
                     'how many conversion'])) {
      return _conversionSummary();
    }

    // ── Contextual fallback — answer based on current screen ──────────────
    return _contextualFallback(q, route);
  }

  // ── Individual answer builders ───────────────────────────────────────────

  static String _highestRoi() {
    final top = MarketingDataService.topRoiCampaign();
    if (top == null) {
      return "I don't have enough campaign data to determine the highest ROI yet.";
    }
    final roiStr = top.roi.toStringAsFixed(2);
    final spentStr = _etb(top.spent);
    final revenueEstimate = top.spent * top.roi;
    final lines = [
      '📈 **${top.name}** currently has the highest ROI at **$roiStr×**.',
      '',
      'Calculation:',
      '  ROI  = Revenue ÷ Spend',
      '  Revenue ≈ ${_etb(revenueEstimate)}',
      '  Spend   = $spentStr',
      '  ROI     = $roiStr×',
      '',
      'Status: ${top.status}  •  Leads: ${top.leads}  •  Conversions: ${top.conversions}',
    ];
    return lines.join('\n');
  }

  static String _averageRoi() {
    final avg = MarketingDataService.averageRoi();
    if (avg == 0) {
      return "No campaign ROI data is available yet.";
    }
    final campaigns = MarketingDataService.allCampaigns()
        .where((c) => c.roi > 0)
        .toList()
      ..sort((a, b) => b.roi.compareTo(a.roi));
    final lines = [
      '📊 Average campaign ROI across ${campaigns.length} campaigns: **${avg.toStringAsFixed(2)}×**.',
      '',
      'Top 3 by ROI:',
      for (int i = 0; i < math.min(3, campaigns.length); i++)
        '  ${i + 1}. ${campaigns[i].name} — ${campaigns[i].roi.toStringAsFixed(2)}×',
    ];
    return lines.join('\n');
  }

  static String _roiSummary(String route) {
    final snap = MarketingDataService.dashboardSnapshot();
    return '📊 Overall portfolio ROI: **${snap.overallRoi}**\n\n'
        'For a breakdown by campaign, ask "Which campaign has the highest ROI?"';
  }

  static String _budgetSummary() {
    final b = MarketingDataService.budgetSummary();
    final pct = (b.utilization * 100).toStringAsFixed(1);
    return '💰 **Budget Summary (Campaign Data)**\n\n'
        '  Allocated : ${_etb(b.totalAllocated)}\n'
        '  Spent     : ${_etb(b.totalSpent)}\n'
        '  Remaining : ${_etb(b.remaining)}\n'
        '  Utilization: $pct%\n\n'
        'Dashboard totals (all channels):\n'
        '  Total : ${MarketingDataService.dashboardSnapshot().budgetTotal}\n'
        '  Spent : ${MarketingDataService.dashboardSnapshot().budgetSpent}\n'
        '  Remaining: ${MarketingDataService.dashboardSnapshot().budgetRemaining}';
  }

  static String _campaignSummary() {
    final campaigns = MarketingDataService.allCampaigns();
    final byStatus = <String, int>{};
    for (final c in campaigns) {
      byStatus[c.status] = (byStatus[c.status] ?? 0) + 1;
    }
    final lines = [
      '🚀 **Campaign Summary** (${campaigns.length} total)',
      '',
      for (final entry in byStatus.entries)
        '  ${entry.key}: ${entry.value}',
      '',
      'Total budget allocated : ${_etb(campaigns.fold(0.0, (s, c) => s + c.budget))}',
      'Total spent            : ${_etb(campaigns.fold(0.0, (s, c) => s + c.spent))}',
      'Total leads generated  : ${campaigns.fold(0, (s, c) => s + c.leads)}',
      'Total conversions      : ${campaigns.fold(0, (s, c) => s + c.conversions)}',
    ];
    return lines.join('\n');
  }

  static String _topCampaigns() {
    final campaigns = MarketingDataService.allCampaigns()
        .where((c) => c.roi > 0)
        .toList()
      ..sort((a, b) => b.roi.compareTo(a.roi));
    if (campaigns.isEmpty) {
      return "No campaign performance data is available yet.";
    }
    final top = campaigns.take(5).toList();
    final lines = [
      '🏆 **Top ${top.length} Campaigns by ROI:**',
      '',
      for (int i = 0; i < top.length; i++)
        '  ${i + 1}. ${top[i].name}\n'
        '      ROI: ${top[i].roi.toStringAsFixed(2)}×  •  Status: ${top[i].status}\n'
        '      Leads: ${top[i].leads}  •  Conversions: ${top[i].conversions}',
    ];
    return lines.join('\n');
  }

  static String _activeCampaigns() {
    final active = MarketingDataService.activeCampaigns();
    if (active.isEmpty) {
      return "There are no active campaigns at the moment.";
    }
    final lines = [
      '✅ **${active.length} Active Campaign${active.length == 1 ? '' : 's'}:**',
      '',
      for (final c in active)
        '  • ${c.name}  —  ${_etb(c.spent)} spent of ${_etb(c.budget)}  (ROI ${c.roi.toStringAsFixed(1)}×)',
    ];
    return lines.join('\n');
  }

  static String _leadSummary() {
    final s = MarketingDataService.leadSummary();
    return '👥 **Lead Summary** (${s.total} total)\n\n'
        '  New         : ${s.newCount}\n'
        '  Contacted   : ${s.contacted}\n'
        '  Qualified   : ${s.qualified}\n'
        '  Unqualified : ${s.unqualified}\n'
        '  Converted   : ${s.converted}\n\n'
        '  High-priority leads : ${s.highPriority}\n'
        '  Average lead score  : ${s.avgScore.toStringAsFixed(0)}/100';
  }

  static String _leadsNeedingAttention() {
    final leads = MarketingDataService.leadsNeedingAttention();
    if (leads.isEmpty) {
      return "No high-priority leads currently need immediate attention.";
    }
    final shown = leads.take(5).toList();
    final lines = [
      '⚠️ **${leads.length} lead${leads.length == 1 ? '' : 's'} needing attention** '
          '(New or Contacted, score ≥ 70):',
      '',
      for (final l in shown)
        '  • ${l.name} (${l.company})  —  Score: ${l.score}  •  Status: ${l.status}',
      if (leads.length > 5)
        '  … and ${leads.length - 5} more.',
    ];
    return lines.join('\n');
  }

  static String _leadConversionInfo() {
    final s = MarketingDataService.leadSummary();
    final convRate = s.total > 0
        ? (s.converted / s.total * 100).toStringAsFixed(1)
        : '0.0';
    return '🔄 **Lead Conversion**\n\n'
        '  Total leads   : ${s.total}\n'
        '  Converted     : ${s.converted}\n'
        '  Conversion rate: $convRate%\n\n'
        'Qualified leads (strong pipeline): ${s.qualified}';
  }

  static String _customerSummary() {
    final s = MarketingDataService.customerSummary();
    return '🏢 **Customer Summary** (${s.total} total)\n\n'
        '  Active    : ${s.active}\n\n'
        '  By segment:\n'
        '    VIP       : ${s.vip}\n'
        '    Corporate : ${s.corporate}\n'
        '    Retail    : ${s.retail}';
  }

  static String _opportunitySummary() {
    final s = MarketingDataService.opportunitySummary();
    final stages = s.byStage.entries
        .where((e) => e.value > 0)
        .map((e) => '    ${e.key}: ${e.value}')
        .join('\n');
    return '💼 **Opportunity Pipeline** (${s.total} total)\n\n'
        '  Total pipeline value   : ${_etb(s.totalValue)}\n'
        '  Weighted pipeline value: ${_etb(s.weightedPipelineValue)}\n'
        '  Won value              : ${_etb(s.wonValue)}\n\n'
        '  By stage:\n$stages';
  }

  static String _conversionSummary() {
    final snap = MarketingDataService.dashboardSnapshot();
    final totalConv = MarketingDataService.totalConversions();
    return '🔄 **Conversions**\n\n'
        '  Overall conversion rate : ${snap.conversionRate}\n'
        '  Total conversions (campaigns) : $totalConv\n\n'
        'For lead-specific conversions, ask "How many leads are converted?"';
  }

  static String _overallSummary() {
    final snap     = MarketingDataService.dashboardSnapshot();
    final budget   = MarketingDataService.budgetSummary();
    final leads    = MarketingDataService.leadSummary();
    final topCamp  = MarketingDataService.topRoiCampaign();
    final pct      = (budget.utilization * 100).toStringAsFixed(1);
    return '📋 **Marketing Performance Summary**\n\n'
        '🚀 Campaigns\n'
        '  Total: ${snap.totalCampaigns}  •  Active: ${snap.activeCampaigns}\n\n'
        '💰 Budget\n'
        '  Total: ${snap.budgetTotal}  •  Spent: ${snap.budgetSpent}\n'
        '  Remaining: ${snap.budgetRemaining}  •  Utilization: $pct%\n\n'
        '👥 Leads\n'
        '  Total: ${leads.total}  •  Qualified: ${leads.qualified}  •  Converted: ${leads.converted}\n\n'
        '📈 ROI\n'
        '  Portfolio: ${snap.overallRoi}  •  Conversion rate: ${snap.conversionRate}\n'
        '  Top campaign: ${topCamp != null ? '${topCamp.name} (${topCamp.roi.toStringAsFixed(2)}×)' : 'N/A'}';
  }

  static String _dashboardSnapshot() {
    final snap = MarketingDataService.dashboardSnapshot();
    return '📊 **Dashboard Snapshot**\n\n'
        '  Campaigns      : ${snap.totalCampaigns} total (${snap.activeCampaigns} active)\n'
        '  Leads          : ${snap.totalLeads}\n'
        '  Budget Total   : ${snap.budgetTotal}\n'
        '  Budget Spent   : ${snap.budgetSpent}\n'
        '  Remaining      : ${snap.budgetRemaining}\n'
        '  Overall ROI    : ${snap.overallRoi}\n'
        '  Conversion Rate: ${snap.conversionRate}';
  }

  static String _contextualFallback(String q, String route) {
    // Provide page-aware hints even for unrecognised queries.
    final pageContext = _pageHint(route);
    // Generic unrecognised response — never invent data.
    return "I don't have enough information to answer that specifically.\n\n"
        "${pageContext.isNotEmpty ? 'On this page I can help with:\n$pageContext\n\n' : ''}"
        "Try asking:\n"
        "  • \"Which campaign has the highest ROI?\"\n"
        "  • \"How is my budget performing?\"\n"
        "  • \"Which leads need attention?\"\n"
        "  • \"Summarize this month's performance.\"";
  }

  static String _pageHint(String route) {
    switch (route) {
      case AppRoutes.campaigns:
      case AppRoutes.campaignCreate:
      case AppRoutes.campaignDetail:
      case AppRoutes.campaignEdit:
        return '  • Campaign performance & ROI\n'
               '  • Campaign status breakdown\n'
               '  • Budget utilization per campaign';
      case AppRoutes.leads:
        return '  • Lead counts & status\n'
               '  • Leads needing attention\n'
               '  • Conversion information';
      case AppRoutes.customers:
        return '  • Customer statistics\n'
               '  • Segment breakdown\n'
               '  • Active vs inactive customers';
      case AppRoutes.opportunities:
        return '  • Opportunity stages\n'
               '  • Pipeline value\n'
               '  • Won vs open opportunities';
      case AppRoutes.budget:
        return '  • Total budget & spend\n'
               '  • Remaining budget\n'
               '  • Budget utilization %';
      case AppRoutes.reports:
        return '  • Marketing performance\n'
               '  • Trends & summaries\n'
               '  • ROI analysis';
      case AppRoutes.dashboard:
        return '  • Full marketing overview\n'
               '  • KPI snapshot\n'
               '  • Top campaigns & budget';
      default:
        return '';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns true when [query] contains ANY of the [keywords].
  static bool _matches(String query, List<String> keywords) =>
      keywords.any((kw) => query.contains(kw));

  /// Format a double as ETB currency string.
  static String _etb(double value) {
    if (value >= 1000000) {
      return 'ETB ${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return 'ETB ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'ETB ${value.toStringAsFixed(0)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggested questions — shown in the empty-state chat panel.
// Each suggestion maps to a question the AI can answer from real data.
// ─────────────────────────────────────────────────────────────────────────────

class AiSuggestions {
  AiSuggestions._();

  /// Default suggestions shown before the user sends any message.
  static const List<String> defaults = [
    'Which campaign has the highest ROI?',
    'How is my budget performing?',
    'Show my top-performing campaigns.',
    'Which leads need attention?',
    'What is my total marketing spend?',
    "Summarize this month's performance.",
  ];

  /// Context-aware suggestions based on the current screen.
  static List<String> forRoute(String route) {
    switch (route) {
      case AppRoutes.campaigns:
      case AppRoutes.campaignDetail:
        return [
          'Which campaign has the highest ROI?',
          'Show all active campaigns.',
          'What is the total campaign spend?',
          'Show my top-performing campaigns.',
        ];
      case AppRoutes.leads:
        return [
          'Which leads need attention?',
          'How many leads are qualified?',
          'What is the lead conversion rate?',
          'Give me a lead summary.',
        ];
      case AppRoutes.customers:
        return [
          'How many active customers do I have?',
          'Show customer segment breakdown.',
          'How many VIP customers do I have?',
        ];
      case AppRoutes.opportunities:
        return [
          'What is the total pipeline value?',
          'How many opportunities are in negotiation?',
          'What is the weighted pipeline value?',
        ];
      case AppRoutes.budget:
        return [
          'What is my total marketing spend?',
          'How much budget is remaining?',
          'What is my budget utilization?',
        ];
      case AppRoutes.reports:
        return [
          "Summarize this month's performance.",
          'What is my overall ROI?',
          'Show marketing performance overview.',
        ];
      default:
        return defaults;
    }
  }
}
