import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/dashboard_models.dart';
import '../badges/status_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Card wrapper — consistent card styling
// ─────────────────────────────────────────────────────────────────────────────

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cardBg   = AppTheme.cardColor(brightness);
    final borderCol = AppTheme.border(brightness);

    return Container(
      width: double.infinity,
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      padding: padding ?? const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card header with title + optional action
// ─────────────────────────────────────────────────────────────────────────────

class DashboardCardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final Color? iconColor;

  const DashboardCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: textSec,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Activity card
// ─────────────────────────────────────────────────────────────────────────────

class RecentActivityCard extends StatelessWidget {
  final List<RecentActivity> activities;
  final VoidCallback? onViewAll;

  const RecentActivityCard({
    super.key,
    required this.activities,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: 'Recent Activity',
            icon: Icons.notifications_active_outlined,
            iconColor: AppColors.primary,
            trailing: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('View All', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),
          ...activities.map((a) => _ActivityRow(activity: a)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final RecentActivity activity;
  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: activity.iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(activity.icon, size: 18, color: activity.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.timestamp,
                  style: TextStyle(
                    color: textSec,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Campaigns table
// ─────────────────────────────────────────────────────────────────────────────

class TopCampaignsTable extends StatelessWidget {
  final List<TopCampaign> campaigns;
  final VoidCallback? onViewAll;

  const TopCampaignsTable({
    super.key,
    required this.campaigns,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: DashboardCardHeader(
              title: 'Top Campaigns',
              icon: Icons.emoji_events_outlined,
              iconColor: AppColors.warning,
              trailing: TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('View All Campaigns', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.border(Theme.of(context).brightness)),
          // Table header
          _TableHeader(),
          Divider(height: 1, color: AppTheme.divider(Theme.of(context).brightness)),
          // Table rows
          ...campaigns.map((c) => _CampaignRow(campaign: c)),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final headerBg   = AppTheme.tableHeaderColor(brightness);
    final textSec    = AppTheme.textSecondary(brightness);

    return Container(
      color: headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Campaign', style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Status', style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Impressions', textAlign: TextAlign.right, style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Leads', textAlign: TextAlign.right, style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Conv.', textAlign: TextAlign.right, style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('ROI', textAlign: TextAlign.right, style: TextStyle(color: textSec, fontSize: 11, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _CampaignRow extends StatelessWidget {
  final TopCampaign campaign;
  const _CampaignRow({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final dividerCol  = AppTheme.divider(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerCol, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              campaign.name,
              style: TextStyle(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(status: campaign.status),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              campaign.impressions,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              campaign.leads,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              campaign.conversions,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              campaign.roi,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Overview card
// ─────────────────────────────────────────────────────────────────────────────

class BudgetOverviewCard extends StatelessWidget {
  final String total;
  final String spent;
  final String remaining;
  final double utilization;
  final VoidCallback? onViewDetails;

  const BudgetOverviewCard({
    super.key,
    required this.total,
    required this.spent,
    required this.remaining,
    required this.utilization,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: 'Budget Overview',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _BudgetRow(label: 'Total Budget', value: total, color: textPrimary),
          const SizedBox(height: 10),
          _BudgetRow(label: 'Spent', value: spent, color: AppColors.warning),
          const SizedBox(height: 10),
          _BudgetRow(label: 'Remaining', value: remaining, color: AppColors.success),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Utilization',
                style: TextStyle(color: textSec, fontSize: 12),
              ),
              Text(
                '${(utilization * 100).toStringAsFixed(1)}% spent',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: utilization,
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewDetails,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('View Budget Details', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BudgetRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textSec,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel Performance card
// ─────────────────────────────────────────────────────────────────────────────

class ChannelPerformanceCard extends StatelessWidget {
  final List<ChannelPerformance> channels;
  final VoidCallback? onViewAnalytics;

  const ChannelPerformanceCard({
    super.key,
    required this.channels,
    this.onViewAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: 'Channel Performance',
            icon: Icons.donut_large_outlined,
            iconColor: AppColors.info,
          ),
          const SizedBox(height: 16),
          ...channels.map((c) => _ChannelRow(channel: c)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewAnalytics,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('View Full Analytics', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final ChannelPerformance channel;
  const _ChannelRow({required this.channel});

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                channel.name,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(channel.percentage * 100).round()}%',
                style: TextStyle(
                  color: channel.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: channel.percentage,
              minHeight: 6,
              backgroundColor: channel.color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(channel.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions card
// ─────────────────────────────────────────────────────────────────────────────

class QuickActionsCard extends StatelessWidget {
  final VoidCallback? onNewCampaign;
  final VoidCallback? onAddLead;
  final VoidCallback? onCreateContent;
  final VoidCallback? onCreateReport;

  const QuickActionsCard({
    super.key,
    this.onNewCampaign,
    this.onAddLead,
    this.onCreateContent,
    this.onCreateReport,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardCardHeader(
            title: 'Quick Actions',
            icon: Icons.bolt_outlined,
            iconColor: AppColors.warning,
          ),
          const SizedBox(height: 16),
          if (onNewCampaign != null)
            _QuickActionTile(
              icon: Icons.add_circle_outline,
              color: AppColors.primary,
              label: 'New Campaign',
              onTap: onNewCampaign,
            ),
          if (onAddLead != null) ...[
            const SizedBox(height: 8),
            _QuickActionTile(
              icon: Icons.person_add_alt_1_outlined,
              color: AppColors.success,
              label: 'Add Lead',
              onTap: onAddLead,
            ),
          ],
          if (onCreateContent != null) ...[
            const SizedBox(height: 8),
            _QuickActionTile(
              icon: Icons.article_outlined,
              color: AppColors.info,
              label: 'Create Content',
              onTap: onCreateContent,
            ),
          ],
          if (onCreateReport != null) ...[
            const SizedBox(height: 8),
            _QuickActionTile(
              icon: Icons.bar_chart_outlined,
              color: AppColors.warning,
              label: 'Create Report',
              onTap: onCreateReport,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: textSec),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boost Your ROI card
// ─────────────────────────────────────────────────────────────────────────────

class RoiInsightCard extends StatelessWidget {
  final VoidCallback? onExplore;

  const RoiInsightCard({super.key, this.onExplore});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark     = brightness == Brightness.dark;

    final cardBg = isDark
        ? const Color(0xFF252235)
        : AppColors.primaryLighter;
    final cardBorder = isDark
        ? AppColors.primary.withValues(alpha: 0.2)
        : AppColors.primary.withValues(alpha: 0.15);
    final titleColor  = AppTheme.textPrimary(brightness);
    final bodyColor   = AppTheme.textSecondary(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Boost Your ROI',
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Discover strategies to improve your campaign performance.',
            style: TextStyle(
              color: bodyColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onExplore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Explore Insights', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}