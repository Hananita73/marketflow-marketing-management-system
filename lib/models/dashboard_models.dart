import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPI Stat
// ─────────────────────────────────────────────────────────────────────────────

class KpiStat {
  final String label;
  final String value;
  final String change;      // e.g. "+19%"
  final bool isPositive;
  final IconData icon;
  final Color iconColor;
  final String subtitle;    // e.g. "vs last week"

  /// Permission-matrix module that owns this KPI (e.g. 'Budget'). When set,
  /// the dashboard hides the card for roles without view access to it.
  final String? module;

  const KpiStat({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.iconColor,
    required this.subtitle,
    this.module,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Campaign Performance data point (for the grouped bar chart)
// ─────────────────────────────────────────────────────────────────────────────

class CampaignPerformanceData {
  final String label;       // x-axis label e.g. "Brand Awareness"
  final double impressions;
  final double leads;       // Campaign.clicks does not exist in the schema
  final double conversions;

  const CampaignPerformanceData({
    required this.label,
    required this.impressions,
    required this.leads,
    required this.conversions,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel Distribution slice (for the donut chart)
// ─────────────────────────────────────────────────────────────────────────────

class ChannelSlice {
  final String name;
  final double percentage;
  final Color color;

  const ChannelSlice({
    required this.name,
    required this.percentage,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Activity item
// ─────────────────────────────────────────────────────────────────────────────

class RecentActivity {
  final String title;
  final String timestamp;
  final IconData icon;
  final Color iconColor;

  const RecentActivity({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Campaign row (for the table)
// ─────────────────────────────────────────────────────────────────────────────

class TopCampaign {
  final String name;
  final String status;
  final String impressions;
  final String leads;
  final String conversions;
  final String roi;

  const TopCampaign({
    required this.name,
    required this.status,
    required this.impressions,
    required this.leads,
    required this.conversions,
    required this.roi,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel Performance item
// ─────────────────────────────────────────────────────────────────────────────

class ChannelPerformance {
  final String name;
  final double percentage;
  final Color color;

  const ChannelPerformance({
    required this.name,
    required this.percentage,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock Data
// ─────────────────────────────────────────────────────────────────────────────

class DashboardMockData {
  DashboardMockData._();

  static const List<KpiStat> kpiStats = [
    KpiStat(
      label: 'Total Campaigns',
      value: '24',
      change: '+12%',
      isPositive: true,
      icon: Icons.campaign_outlined,
      iconColor: AppColors.primary,
      subtitle: 'vs last week',
    ),
    KpiStat(
      label: 'Total Leads',
      value: '3,248',
      change: '+8%',
      isPositive: true,
      icon: Icons.person_search_outlined,
      iconColor: AppColors.success,
      subtitle: 'vs last week',
    ),
    KpiStat(
      label: 'Budget Spend',
      value: 'ETB 750K',
      change: '+5%',
      isPositive: true,
      icon: Icons.account_balance_wallet_outlined,
      iconColor: AppColors.warning,
      subtitle: 'vs last week',
    ),
    KpiStat(
      label: 'ROI',
      value: '4.35×',
      change: '+15%',
      isPositive: true,
      icon: Icons.trending_up_outlined,
      iconColor: AppColors.info,
      subtitle: 'vs last week',
    ),
    KpiStat(
      label: 'Active Campaigns',
      value: '18',
      change: '+6%',
      isPositive: true,
      icon: Icons.check_circle_outline,
      iconColor: AppColors.success,
      subtitle: 'currently running',
    ),
    KpiStat(
      label: 'Conversion Rate',
      value: '6.4%',
      change: '+1.2%',
      isPositive: true,
      icon: Icons.swap_horiz_outlined,
      iconColor: Color(0xFFBB5CF8),
      subtitle: 'vs last week',
    ),
    KpiStat(
      label: 'New Customers',
      value: '412',
      change: '+19%',
      isPositive: true,
      icon: Icons.person_add_alt_1_outlined,
      iconColor: AppColors.info,
      subtitle: 'this week',
    ),
    KpiStat(
      label: 'Engagement Rate',
      value: '34.7%',
      change: '+3.5%',
      isPositive: true,
      icon: Icons.insights_outlined,
      iconColor: AppColors.warning,
      subtitle: 'vs last week',
    ),
  ];

  static const List<CampaignPerformanceData> campaignPerformance = [
    CampaignPerformanceData(
      label: 'Brand Awareness',
      impressions: 45.2,
      leads: 2.1,
      conversions: 210,
    ),
    CampaignPerformanceData(
      label: 'Product Launch',
      impressions: 38.7,
      leads: 1.8,
      conversions: 190,
    ),
    CampaignPerformanceData(
      label: 'Email Campaign',
      impressions: 28.9,
      leads: 1.2,
      conversions: 150,
    ),
    CampaignPerformanceData(
      label: 'Social Media',
      impressions: 22.1,
      leads: 0.98,
      conversions: 120,
    ),
    CampaignPerformanceData(
      label: 'Retargeting',
      impressions: 18.7,
      leads: 0.75,
      conversions: 90,
    ),
  ];

  static const List<ChannelSlice> leadsBySource = [
    ChannelSlice(name: 'Website',     percentage: 28, color: AppColors.primary),
    ChannelSlice(name: 'Social Media', percentage: 24, color: AppColors.info),
    ChannelSlice(name: 'Email',       percentage: 20, color: AppColors.success),
    ChannelSlice(name: 'Referrals',   percentage: 14, color: AppColors.warning),
    ChannelSlice(name: 'Paid Ads',    percentage: 10, color: Color(0xFFBB5CF8)),
    ChannelSlice(name: 'Others',      percentage: 4,  color: AppColors.textSecondary),
  ];

  static const String totalLeads = '3,248';

  static const List<RecentActivity> recentActivities = [
    RecentActivity(
      title: 'New campaign "Summer Sale" created',
      timestamp: '2 min ago',
      icon: Icons.campaign_outlined,
      iconColor: AppColors.primary,
    ),
    RecentActivity(
      title: 'Lead converted to opportunity',
      timestamp: '15 min ago',
      icon: Icons.person_add_alt_1_outlined,
      iconColor: AppColors.success,
    ),
    RecentActivity(
      title: 'Budget updated for Product Launch',
      timestamp: '1 hour ago',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: AppColors.warning,
    ),
    RecentActivity(
      title: 'New content published on blog',
      timestamp: '2 hours ago',
      icon: Icons.article_outlined,
      iconColor: AppColors.info,
    ),
    RecentActivity(
      title: 'ROI improved by 15% this week',
      timestamp: '4 hours ago',
      icon: Icons.trending_up_outlined,
      iconColor: AppColors.success,
    ),
  ];

  static const List<TopCampaign> topCampaigns = [
    TopCampaign(
      name: 'Brand Awareness',
      status: AppConstants.statusActive,
      impressions: '45.2K',
      leads: '2.1K',
      conversions: '210',
      roi: '4.8×',
    ),
    TopCampaign(
      name: 'Product Launch',
      status: AppConstants.statusActive,
      impressions: '38.7K',
      leads: '1.8K',
      conversions: '190',
      roi: '5.2×',
    ),
    TopCampaign(
      name: 'Email Campaign',
      status: AppConstants.statusActive,
      impressions: '28.9K',
      leads: '1.2K',
      conversions: '150',
      roi: '4.1×',
    ),
    TopCampaign(
      name: 'Social Media',
      status: AppConstants.statusPaused,
      impressions: '22.1K',
      leads: '980',
      conversions: '120',
      roi: '3.6×',
    ),
    TopCampaign(
      name: 'Retargeting',
      status: AppConstants.statusActive,
      impressions: '18.7K',
      leads: '750',
      conversions: '90',
      roi: '4.9×',
    ),
  ];

  // Budget summary numbers
  static const String budgetTotal = 'ETB 1,200,000';
  static const String budgetSpent = 'ETB 750,000';
  static const String budgetRemaining = 'ETB 450,000';
  static const double budgetUtilization = 0.625; // 62.5%

  static const List<ChannelPerformance> channelPerformance = [
    ChannelPerformance(name: 'Social Media',       percentage: 0.85, color: AppColors.primary),
    ChannelPerformance(name: 'Email Marketing',    percentage: 0.70, color: AppColors.info),
    ChannelPerformance(name: 'Paid Ads',           percentage: 0.60, color: AppColors.success),
    ChannelPerformance(name: 'Content Marketing',  percentage: 0.45, color: AppColors.warning),
    ChannelPerformance(name: 'Influencer Marketing', percentage: 0.35, color: Color(0xFFBB5CF8)),
  ];
}