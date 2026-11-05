// LEGACY — Kiro-era standalone dashboard. Not wired to routes.
// Preserved for later migration. Use DashboardScreen inside AppLayout instead.

import 'package:flutter/material.dart';
import '../customers/customer_screen.dart';
import '../budget/budget_screen.dart';
import '../promotions/promotions_screen.dart';
import '../reports/reports_screen.dart';
import '../profile/profile_screen.dart';

/// Stub replacing the removed campaign_screen.dart reference.
class CampaignScreen extends StatelessWidget {
  const CampaignScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Legacy campaign screen — not active')),
    );
  }
}

// ─── DESIGN TOKENS ───────────────────────────────────────────
class _P {
  // Brand — deep teal/slate professional palette
  static const primary      = Color(0xFF0F4C75);
  static const primaryLight = Color(0xFF1B6CA8);
  static const accent       = Color(0xFF00B4D8);

  // Backgrounds
  static const bg           = Color(0xFFF0F4F8);
  static const surface      = Color(0xFFFFFFFF);
  static const surfaceAlt   = Color(0xFFF8FAFC);

  // Text
  static const textHigh     = Color(0xFF0D1B2A);
  static const textMid      = Color(0xFF4A5568);
  static const textLow      = Color(0xFF8A99AA);

  // Status
  static const success      = Color(0xFF00897B);
  static const successBg    = Color(0xFFE0F2F1);
  static const warning      = Color(0xFFF57C00);
  static const warningBg    = Color(0xFFFFF3E0);
  static const info         = Color(0xFF1565C0);
  static const infoBg       = Color(0xFFE3F2FD);
  static const danger       = Color(0xFFC62828);
  static const dangerBg     = Color(0xFFFFEBEE);
}

Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'active':    return _P.success;
    case 'completed': return _P.info;
    case 'pending':   return _P.warning;
    case 'cancelled': return _P.danger;
    default:          return _P.textLow;
  }
}

Color _statusBg(String s) {
  switch (s.toLowerCase()) {
    case 'active':    return _P.successBg;
    case 'completed': return _P.infoBg;
    case 'pending':   return _P.warningBg;
    case 'cancelled': return _P.dangerBg;
    default:          return _P.surfaceAlt;
  }
}

// ─── DASHBOARD ───────────────────────────────────────────────
@Deprecated('Use DashboardScreen inside AppLayout')
class LegacyDashboardScreen extends StatelessWidget {
  const LegacyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      drawer: _Drawer(),
      body: CustomScrollView(
        slivers: [
          _AppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _WelcomeBanner(),
                const SizedBox(height: 28),
                const _SectionLabel(text: 'Overview'),
                const SizedBox(height: 12),
                const _StatsRow(),
                const SizedBox(height: 28),
                const _SectionLabel(text: 'Marketing Performance'),
                const SizedBox(height: 12),
                const _PerformanceCard(),
                const SizedBox(height: 28),
                _SectionLabel(
                  text: 'Recent Campaigns',
                  trailing: TextButton(
                    onPressed: () => _push(context, const CampaignScreen()),
                    style: TextButton.styleFrom(foregroundColor: _P.primaryLight),
                    child: const Text('See all →'),
                  ),
                ),
                const SizedBox(height: 12),
                const _CampaignTile(
                  title: 'Summer Marketing Campaign',
                  status: 'Active',
                  subtitle: 'Ends Aug 31 · 12 assets',
                ),
                const _CampaignTile(
                  title: 'New Product Promotion',
                  status: 'Pending',
                  subtitle: 'Starts Sep 1 · 5 assets',
                ),
                const _CampaignTile(
                  title: 'Customer Awareness Drive',
                  status: 'Completed',
                  subtitle: 'Ended Jul 15 · 20 assets',
                ),
                const SizedBox(height: 28),
                const _SectionLabel(text: 'Quick Actions'),
                const SizedBox(height: 12),
                const _QuickActionsGrid(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

void _push(BuildContext ctx, Widget page) =>
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => page));

// ─── APP BAR ─────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: _P.primary,
      expandedHeight: 0,
      titleSpacing: 20,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      title: const Text(
        'Marketing Dashboard',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 19,
          letterSpacing: 0.3,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Stack(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            Positioned(
              right: 10, top: 10,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: _P.accent, shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─── DRAWER ──────────────────────────────────────────────────
class _Drawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _P.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // header
          Container(
            padding: const EdgeInsets.only(top: 56, bottom: 28, left: 24, right: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_P.primary, _P.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _P.accent, width: 2.5),
                  ),
                  child: const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_rounded, size: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Hana Tsegaye',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _P.accent.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Administrator',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _drawerItem(context, 'Campaigns',  Icons.campaign_rounded,                const CampaignScreen()),
          _drawerItem(context, 'Customers',  Icons.people_alt_rounded,              const CustomerScreen()),
          _drawerItem(context, 'Budget',     Icons.account_balance_wallet_rounded,  const BudgetScreen()),
          _drawerItem(context, 'Promotions', Icons.local_offer_rounded,             const PromotionsScreen()),
          _drawerItem(context, 'Reports',    Icons.analytics_rounded,               const ReportsScreen()),

          Divider(height: 24, indent: 20, endIndent: 20, color: Colors.grey.shade200),
          _drawerItem(context, 'Profile',    Icons.person_rounded,                  const ProfileScreen()),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('v1.0.0',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext ctx, String title, IconData icon, Widget page) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _P.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _P.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: _P.textHigh, fontSize: 14)),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
      onTap: () {
        Navigator.pop(ctx);
        _push(ctx, page);
      },
    );
  }
}

// ─── WELCOME BANNER ──────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_P.primary, _P.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _P.primary.withValues(alpha: .3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // decorative circles
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .06),
              ),
            ),
          ),
          Positioned(
            right: 30, bottom: -30,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _P.accent.withValues(alpha: .15),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _P.accent.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _greeting(),
                            style: const TextStyle(
                                color: _P.accent, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Welcome back, Admin 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your campaigns are performing well.\nHere\'s today\'s snapshot.',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '☀️  Good Morning';
    if (h < 17) return '🌤  Good Afternoon';
    return '🌙  Good Evening';
  }
}

// ─── SECTION LABEL ───────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SectionLabel({required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: _P.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _P.textHigh,
                  letterSpacing: .2,
                )),
          ],
        ),
        ?trailing,
      ],
    );
  }
}

// ─── STATS ROW ───────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // featured
        const _FeaturedStat(
          label: 'Active Campaigns',
          value: '12',
          trend: '+3 this month',
          trendUp: true,
          icon: Icons.rocket_launch_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: _MiniStat(label: 'Customers',  value: '250', icon: Icons.people_alt_rounded,              color: _P.info)),
            SizedBox(width: 10),
            Expanded(child: _MiniStat(label: 'Budget',     value: 'ETB15K', icon: Icons.account_balance_wallet_rounded, color: _P.success)),
            SizedBox(width: 10),
            Expanded(child: _MiniStat(label: 'Promotions', value: '8',   icon: Icons.local_offer_rounded,              color: _P.warning)),
          ],
        ),
      ],
    );
  }
}

class _FeaturedStat extends StatelessWidget {
  final String label, value, trend;
  final bool trendUp;
  final IconData icon;
  const _FeaturedStat({
    required this.label, required this.value,
    required this.trend, required this.trendUp, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .05),
              blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_P.primary, _P.primaryLight],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: _P.textMid, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w800, color: _P.textHigh,
                        height: 1)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: trendUp ? _P.successBg : _P.dangerBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 14,
                  color: trendUp ? _P.success : _P.danger,
                ),
                const SizedBox(width: 4),
                Text(trend,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trendUp ? _P.success : _P.danger)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .04),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _P.textHigh)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: _P.textLow),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── PERFORMANCE CARD ────────────────────────────────────────
class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .04),
              blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: const Column(
        children: [
          _ProgressRow(label: 'Campaign Success', value: 0.85, color: _P.success),
          SizedBox(height: 18),
          _ProgressRow(label: 'Customer Growth',  value: 0.70, color: _P.info),
          SizedBox(height: 18),
          _ProgressRow(label: 'Budget Usage',     value: 0.60, color: _P.warning),
          SizedBox(height: 18),
          _ProgressRow(label: 'Lead Conversion',  value: 0.45, color: _P.accent),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _P.textHigh)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            color: color,
            backgroundColor: color.withValues(alpha: .1),
          ),
        ),
      ],
    );
  }
}

// ─── CAMPAIGN TILE ───────────────────────────────────────────
class _CampaignTile extends StatelessWidget {
  final String title, status, subtitle;
  const _CampaignTile({
    required this.title,
    required this.status,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final bg    = _statusBg(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .03),
              blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _P.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded, color: _P.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: _P.textHigh, fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: _P.textLow)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: .25)),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

// ─── QUICK ACTIONS ───────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action('New Campaign', Icons.add_circle_rounded,   _P.primary,  const CampaignScreen()),
      _Action('Reports',      Icons.bar_chart_rounded,    _P.info,     const ReportsScreen()),
      _Action('Budget',       Icons.wallet_rounded,       _P.success,  const BudgetScreen()),
      _Action('Promotions',   Icons.local_offer_rounded,  _P.warning,  const PromotionsScreen()),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: actions
          .map((a) => _ActionTile(action: a))
          .toList(),
    );
  }
}

class _Action {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;
  const _Action(this.title, this.icon, this.color, this.page);
}

class _ActionTile extends StatelessWidget {
  final _Action action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _P.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _push(context, action.page),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: action.color.withValues(alpha: .2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .03),
                  blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _P.textHigh,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
