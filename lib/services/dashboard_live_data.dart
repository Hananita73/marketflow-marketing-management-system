import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../models/budget.dart';
import '../models/campaign.dart';
import '../models/customer.dart';
import '../models/dashboard_models.dart';
import '../models/lead.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardLiveData
//
// Repository-backed data for the Dashboard. Every number, chart and table on
// the dashboard is computed from the same repositories the CRUD screens write
// to, which are synced with Supabase (campaigns, leads, customers, budgets…).
//
//   DashboardMockData  — static sample content (kept for reference/tests)
//   DashboardLiveData  — what the app actually renders
//
// All getters are cheap enough to call from build() (in-memory lists) and
// degrade to the bundled seed data when the app runs offline.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardLiveData {
  DashboardLiveData._();

  static List<Campaign> get _campaigns => CampaignRepository.getAll();
  static List<Lead> get _leads => LeadRepository.getAll();
  static List<Customer> get _customers => CustomerRepository.getAll();
  static List<Budget> get _budgets => BudgetRepository.getAll();

  static const List<Color> _palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.success,
    AppColors.warning,
    Color(0xFFBB5CF8),
    AppColors.textSecondary,
  ];

  // ── Formatting helpers ────────────────────────────────────────────────────

  static String _compact(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v >= 100 || v == v.roundToDouble()
        ? v.round().toString()
        : v.toStringAsFixed(1);
  }

  static String _grouped(num v) {
    final digits = v.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return v < 0 ? '-$buffer' : buffer.toString();
  }

  static String _etb(num v) => 'ETB ${_grouped(v)}';

  static String _percent(double fraction) =>
      '${(fraction * 100).toStringAsFixed(0)}%';

  static String _short(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max - 1)}…';

  static int _since(Iterable<DateTime?> dates, Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return dates.whereType<DateTime>().where((d) => d.isAfter(cutoff)).length;
  }

  // ── 1. KPI cards ──────────────────────────────────────────────────────────

  static List<KpiStat> get kpiStats {
    final campaigns = _campaigns;
    final leads = _leads;
    final customers = _customers;
    final budgets = _budgets;

    final allocated = budgets.fold<double>(0, (sum, b) => sum + b.allocated);
    final spent = budgets.fold<double>(0, (sum, b) => sum + b.spent);
    final utilisation = allocated > 0 ? spent / allocated : 0.0;

    final active =
        campaigns.where((c) => c.status == AppConstants.statusActive).length;
    final avgRoi = campaigns.isEmpty
        ? 0.0
        : campaigns.fold<double>(0, (sum, c) => sum + c.roi) / campaigns.length;

    final converted =
        leads.where((l) => l.status == AppConstants.leadConverted).length;
    final qualified =
        leads.where((l) => l.status == AppConstants.leadQualified).length;
    final conversionRate =
        leads.isEmpty ? 0.0 : converted / leads.length * 100;
    final avgScore = leads.isEmpty
        ? 0.0
        : leads.fold<double>(0, (sum, l) => sum + l.score) / leads.length;

    const month = Duration(days: 30);

    return [
      KpiStat(
        label: 'Total Campaigns',
        value: '${campaigns.length}',
        change: '+${_since(campaigns.map((c) => c.startDate).toList(), month)}',
        isPositive: campaigns.isNotEmpty,
        icon: Icons.campaign_outlined,
        iconColor: AppColors.primary,
        subtitle: 'started in 30 days',
      ),
      KpiStat(
        label: 'Total Leads',
        value: _grouped(leads.length),
        change: '+${_since(leads.map((l) => l.createdAt).toList(), month)}',
        isPositive: leads.isNotEmpty,
        icon: Icons.person_search_outlined,
        iconColor: AppColors.success,
        subtitle: 'new in 30 days',
      ),
      KpiStat(
        label: 'Budget Spend',
        value: _etb(spent),
        change: _percent(utilisation),
        isPositive: utilisation < 0.8,
        icon: Icons.account_balance_wallet_outlined,
        iconColor: AppColors.warning,
        subtitle: 'of allocation',
        module: 'Budget',
      ),
      KpiStat(
        label: 'ROI',
        value: '${avgRoi.toStringAsFixed(2)}×',
        change: avgRoi >= 2 ? 'on target' : 'below 2×',
        isPositive: avgRoi >= 2,
        icon: Icons.trending_up_outlined,
        iconColor: AppColors.info,
        subtitle: 'campaign average',
      ),
      KpiStat(
        label: 'Active Campaigns',
        value: '$active',
        change: '${campaigns.length - active} other',
        isPositive: active > 0,
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        subtitle: 'currently running',
      ),
      KpiStat(
        label: 'Conversion Rate',
        value: '${conversionRate.toStringAsFixed(1)}%',
        change: '$converted/${leads.length}',
        isPositive: converted > 0,
        icon: Icons.swap_horiz_outlined,
        iconColor: const Color(0xFFBB5CF8),
        subtitle: 'leads converted',
      ),
      KpiStat(
        label: 'New Customers',
        value: '${customers.length}',
        change:
            '+${_since(customers.map((c) => c.joinedAt).toList(), month)}',
        isPositive: customers.isNotEmpty,
        icon: Icons.person_add_alt_1_outlined,
        iconColor: AppColors.info,
        subtitle: 'joined in 30 days',
      ),
      KpiStat(
        label: 'Avg Lead Score',
        value: avgScore.toStringAsFixed(0),
        change: '$qualified qualified',
        isPositive: qualified > 0,
        icon: Icons.insights_outlined,
        iconColor: AppColors.warning,
        subtitle: 'across all leads',
      ),
    ];
  }

  // ── 2. Campaign performance chart ─────────────────────────────────────────

  static List<CampaignPerformanceData> get campaignPerformance {
    final top = [..._campaigns]
      ..sort((a, b) => b.impressions.compareTo(a.impressions));
    return top.take(5).map((c) {
      return CampaignPerformanceData(
        label: _short(c.name, 14),
        impressions: c.impressions / 1000,
        leads: c.leads.toDouble(),
        conversions: c.conversions.toDouble(),
      );
    }).toList();
  }

  // ── 3. Leads by source (donut) ────────────────────────────────────────────

  static List<ChannelSlice> get leadsBySource {
    final leads = _leads;
    if (leads.isEmpty) return const [];

    final counts = <String, int>{};
    for (final lead in leads) {
      final key = lead.source.trim().isEmpty ? 'Others' : lead.source;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const colorSlots = 5;
    final top = sorted.take(colorSlots).toList();
    final rest =
        sorted.skip(colorSlots).fold<int>(0, (sum, e) => sum + e.value);
    final total = leads.length;

    final slices = <ChannelSlice>[
      for (var i = 0; i < top.length; i++)
        ChannelSlice(
          name: top[i].key,
          percentage: top[i].value / total * 100,
          color: _palette[i],
        ),
    ];
    if (rest > 0) {
      slices.add(ChannelSlice(
        name: 'Others',
        percentage: rest / total * 100,
        color: _palette[colorSlots],
      ));
    }
    return slices;
  }

  static String get totalLeads => _grouped(_leads.length);

  // ── 4. Recent activity (from live campaign activity logs) ─────────────────

  static List<RecentActivity> get recentActivities {
    final entries = <_ActivityEntry>[];
    for (final campaign in _campaigns) {
      for (final activity in campaign.activities) {
        entries.add(_ActivityEntry(
          activity: activity,
          campaignName: campaign.name,
          sortDate: _parseDisplayDate(activity.date),
        ));
      }
    }

    if (entries.isNotEmpty) {
      entries.sort((a, b) => b.sortDate.compareTo(a.sortDate));
      return entries.take(5).map((e) {
        return RecentActivity(
          title: '${e.campaignName}: ${e.activity.description}',
          timestamp: e.activity.date,
          icon: e.activity.icon,
          iconColor: e.activity.iconColor,
        );
      }).toList();
    }

    // Fallback when no campaign has logged activity yet.
    DateTime startOf(Campaign c) => c.startDate ?? DateTime(2000);

    final campaigns = [..._campaigns]
      ..sort((a, b) => startOf(b).compareTo(startOf(a)));
    return campaigns.take(5).map((c) {
      final start = startOf(c);
      final stamp =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      return RecentActivity(
        title: 'Campaign "${c.name}" — ${c.status.toLowerCase()}',
        timestamp: stamp,
        icon: Icons.campaign_outlined,
        iconColor: AppColors.primary,
      );
    }).toList();
  }

  // ── 5. Top campaigns table ────────────────────────────────────────────────

  static List<TopCampaign> get topCampaigns {
    final top = [..._campaigns]
      ..sort((a, b) => b.impressions.compareTo(a.impressions));
    return top.take(5).map((c) {
      return TopCampaign(
        name: c.name,
        status: c.status,
        impressions: _compact(c.impressions),
        leads: _compact(c.leads),
        conversions: _grouped(c.conversions),
        roi: '${c.roi.toStringAsFixed(1)}×',
      );
    }).toList();
  }

  // ── 6. Budget overview ────────────────────────────────────────────────────

  static double get _allocated =>
      _budgets.fold<double>(0, (sum, b) => sum + b.allocated);

  static double get _spent =>
      _budgets.fold<double>(0, (sum, b) => sum + b.spent);

  static String get budgetTotal => _etb(_allocated);

  static String get budgetSpent => _etb(_spent);

  static String get budgetRemaining => _etb(_allocated - _spent);

  static double get budgetUtilization =>
      _allocated > 0 ? _spent / _allocated : 0;

  // ── 7. Channel performance ────────────────────────────────────────────────

  static List<ChannelPerformance> get channelPerformance {
    final campaigns = _campaigns;
    if (campaigns.isEmpty) return const [];

    final counts = <CampaignChannel, int>{};
    for (final c in campaigns) {
      for (final ch in c.channels) {
        counts[ch] = (counts[ch] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const [];

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (var i = 0; i < sorted.length && i < 5; i++)
        ChannelPerformance(
          name: sorted[i].key.label,
          percentage: sorted[i].value / campaigns.length,
          color: _palette[i % _palette.length],
        ),
    ];
  }

  // ── Date parsing ──────────────────────────────────────────────────────────

  /// Parses the display dates used in campaign activity logs
  /// ('May 10, 2026'), falling back to epoch so unparsed entries sort last.
  static DateTime _parseDisplayDate(String raw) {
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    const months = <String, int>{
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6, 'jul': 7,
      'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    final parts = raw
        .split(RegExp(r'[ ,]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 3) {
      final month = months[parts[0].toLowerCase()];
      final day = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (month != null && day != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _ActivityEntry {
  final CampaignActivity activity;
  final String campaignName;
  final DateTime sortDate;

  const _ActivityEntry({
    required this.activity,
    required this.campaignName,
    required this.sortDate,
  });
}
