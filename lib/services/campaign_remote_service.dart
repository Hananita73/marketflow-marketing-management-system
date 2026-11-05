import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'admin_alert_service.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../models/campaign.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CampaignRemoteService
//
// Thin data-access layer between CampaignRepository and Supabase.
//
//   CampaignRepository (sync, in-memory)  ← UI keeps working unchanged
//            │  fire-and-forget writes / awaited initial load
//            ▼
//   CampaignRemoteService (async)  ← this file
//            ▼
//   Supabase table `campaigns`
//
// Every method fails soft: when Supabase is not configured or unreachable
// the calls return null/false instead of throwing, so the app degrades to
// local-only mode automatically.
// ─────────────────────────────────────────────────────────────────────────────

class CampaignRemoteService {
  CampaignRemoteService._();

  static const String _table = 'campaigns';

  /// Returns null when the backend is unavailable (not configured / offline /
  /// error). Returns an empty list when the table exists but has no rows.
  static Future<List<Campaign>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<Campaign>(_fromRow).toList();
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'read', error: e);
      return null;
    }
  }

  static Future<bool> upsert(Campaign c) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(c))
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
      return false;
    }
  }

  static Future<bool> delete(String id) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .delete()
          .eq('id', id)
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
      return false;
    }
  }

  /// Inserts the given campaigns in one batch. Used on first run when the
  /// remote table is empty so the database starts out with sample content.
  static Future<bool> seed(List<Campaign> campaigns) async {
    if (!SupabaseConfig.isConfigured || campaigns.isEmpty) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(campaigns.map(_toRow).toList())
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
      return false;
    }
  }

  // ── Row mapping ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _toRow(Campaign c) => {
        'id': c.id,
        'name': c.name,
        'description': c.description,
        'target_audience': c.targetAudience,
        'notes': c.notes,
        'objective': c.objective.name,
        'channels': c.channels.map((ch) => ch.name).toList(),
        'status': c.status,
        'start_date': _dateToDb(c.startDate),
        'end_date': _dateToDb(c.endDate),
        'budget': c.budget,
        'spent': c.spent,
        'leads': c.leads,
        'conversions': c.conversions,
        'impressions': c.impressions,
        'roi': c.roi,
        'activities': c.activities.map(_activityToJson).toList(),
        'coupons': c.coupons.map(_couponToJson).toList(),
        'approval_comments': c.approvalComments,
        'approved_by': c.approvedBy,
        'submitted_by': c.submittedBy,
      };

  static Campaign _fromRow(Map<String, dynamic> row) {
    return Campaign(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      targetAudience: row['target_audience']?.toString() ?? '',
      notes: row['notes']?.toString() ?? '',
      objective: _objectiveFromDb(row['objective']),
      channels: ((row['channels'] as List?) ?? const [])
          .map((ch) => _channelFromDb(ch.toString()))
          .toList(),
      status: row['status']?.toString() ?? AppConstants.statusDraft,
      startDate: _dateFromDb(row['start_date']),
      endDate: _dateFromDb(row['end_date']),
      budget: _toDouble(row['budget']),
      spent: _toDouble(row['spent']),
      leads: _toInt(row['leads']),
      conversions: _toInt(row['conversions']),
      impressions: _toInt(row['impressions']),
      roi: _toDouble(row['roi']),
      activities: ((row['activities'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_activityFromJson)
          .toList(),
      coupons: ((row['coupons'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_couponFromJson)
          .toList(),
      expenses: ((row['expenses'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_expenseFromJson)
          .toList(),
      approvalComments: row['approval_comments']?.toString() ?? '',
      approvedBy: row['approved_by']?.toString() ?? '',
      submittedBy: row['submitted_by']?.toString() ?? '',
    );
  }

  // ── Expense JSON helpers ─────────────────────────────────────────────────

  static CampaignExpense _expenseFromJson(Map<String, dynamic> json) => CampaignExpense(
    id: json['id']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    amount: _toDouble(json['amount']),
    date: _dateFromDb(json['date']),
    approvedBy: json['approved_by']?.toString() ?? '',
    status: json['status']?.toString() ?? 'pending',
  );

  // ── Enum helpers ──────────────────────────────────────────────────────────

  static CampaignChannel _channelFromDb(String value) {
    for (final ch in CampaignChannel.values) {
      if (ch.name == value) return ch;
    }
    // Tolerate human-readable labels ('Social Media') written by hand in SQL.
    for (final ch in CampaignChannel.values) {
      if (ch.label.toLowerCase() == value.toLowerCase()) return ch;
    }
    return CampaignChannel.email;
  }

  static CampaignObjective _objectiveFromDb(dynamic value) {
    final v = value?.toString() ?? '';
    for (final o in CampaignObjective.values) {
      if (o.name == v) return o;
    }
    for (final o in CampaignObjective.values) {
      if (o.label.toLowerCase() == v.toLowerCase()) return o;
    }
    return CampaignObjective.brandAwareness;
  }

  // ── Activities ────────────────────────────────────────────────────────────

  // Map of icon names to const IconData for deserialization
  static const Map<String, IconData> _iconLookup = {
    'rocket_launch_outlined': Icons.rocket_launch_outlined,
    'share_outlined': Icons.share_outlined,
    'check_circle_outline': Icons.check_circle_outline,
    'email_outlined': Icons.email_outlined,
    'pause_circle_outline': Icons.pause_circle_outline,
    'flag_outlined': Icons.flag_outlined,
    'campaign_outlined': Icons.campaign_outlined,
    'trending_up': Icons.trending_up,
    'visibility': Icons.visibility,
    'edit': Icons.edit,
    'delete': Icons.delete,
    'add': Icons.add,
    'star': Icons.star,
    'star_outline': Icons.star_outline,
    'bolt': Icons.bolt,
    'group': Icons.group,
    'group_add': Icons.group_add,
    'analytics': Icons.analytics,
    'insights': Icons.insights,
    'storefront': Icons.storefront,
    'shopping_cart': Icons.shopping_cart,
    'payments': Icons.payments,
    'local_offer': Icons.local_offer,
    'bookmark': Icons.bookmark,
    'bookmark_border': Icons.bookmark_border,
    'notifications': Icons.notifications,
    'notifications_none': Icons.notifications_none,
    'settings': Icons.settings,
    'refresh': Icons.refresh,
    'filter_list': Icons.filter_list,
    'sort': Icons.sort,
    'calendar_today': Icons.calendar_today,
    'date_range': Icons.date_range,
    'location_on': Icons.location_on,
    'language': Icons.language,
    'public': Icons.public,
    'link': Icons.link,
    'share': Icons.share,
    'cloud_upload': Icons.cloud_upload,
    'cloud_download': Icons.cloud_download,
    'download': Icons.download,
    'upload': Icons.upload,
    'info': Icons.info,
    'info_outline': Icons.info_outline,
    'help_outline': Icons.help_outline,
    'warning': Icons.warning,
    'error': Icons.error,
    'check': Icons.check,
    'close': Icons.close,
    'arrow_back': Icons.arrow_back,
    'arrow_forward': Icons.arrow_forward,
    'chevron_left': Icons.chevron_left,
    'chevron_right': Icons.chevron_right,
    'expand_more': Icons.expand_more,
    'expand_less': Icons.expand_less,
    'menu': Icons.menu,
    'more_vert': Icons.more_vert,
    'search': Icons.search,
    'clear': Icons.clear,
    'home': Icons.home,
    'dashboard': Icons.dashboard,
    'bar_chart': Icons.bar_chart,
    'pie_chart': Icons.pie_chart,
    'show_chart': Icons.show_chart,
    'multiline_chart': Icons.multiline_chart,
    'stacked_line_chart': Icons.stacked_line_chart,
  };

  static String _iconToName(IconData icon) {
    // Match by codePoint against known const IconData values
    if (icon.codePoint == Icons.rocket_launch_outlined.codePoint) return 'rocket_launch_outlined';
    if (icon.codePoint == Icons.share_outlined.codePoint) return 'share_outlined';
    if (icon.codePoint == Icons.check_circle_outline.codePoint) return 'check_circle_outline';
    if (icon.codePoint == Icons.email_outlined.codePoint) return 'email_outlined';
    if (icon.codePoint == Icons.pause_circle_outline.codePoint) return 'pause_circle_outline';
    if (icon.codePoint == Icons.flag_outlined.codePoint) return 'flag_outlined';
    if (icon.codePoint == Icons.campaign_outlined.codePoint) return 'campaign_outlined';
    if (icon.codePoint == Icons.trending_up.codePoint) return 'trending_up';
    if (icon.codePoint == Icons.visibility.codePoint) return 'visibility';
    if (icon.codePoint == Icons.edit.codePoint) return 'edit';
    if (icon.codePoint == Icons.delete.codePoint) return 'delete';
    if (icon.codePoint == Icons.add.codePoint) return 'add';
    if (icon.codePoint == Icons.star.codePoint) return 'star';
    if (icon.codePoint == Icons.star_outline.codePoint) return 'star_outline';
    if (icon.codePoint == Icons.bolt.codePoint) return 'bolt';
    if (icon.codePoint == Icons.group.codePoint) return 'group';
    if (icon.codePoint == Icons.group_add.codePoint) return 'group_add';
    if (icon.codePoint == Icons.analytics.codePoint) return 'analytics';
    if (icon.codePoint == Icons.insights.codePoint) return 'insights';
    if (icon.codePoint == Icons.storefront.codePoint) return 'storefront';
    if (icon.codePoint == Icons.shopping_cart.codePoint) return 'shopping_cart';
    if (icon.codePoint == Icons.payments.codePoint) return 'payments';
    if (icon.codePoint == Icons.local_offer.codePoint) return 'local_offer';
    if (icon.codePoint == Icons.info.codePoint) return 'info';
    if (icon.codePoint == Icons.info_outline.codePoint) return 'info_outline';
    if (icon.codePoint == Icons.warning.codePoint) return 'warning';
    if (icon.codePoint == Icons.check.codePoint) return 'check';
    if (icon.codePoint == Icons.close.codePoint) return 'close';
    if (icon.codePoint == Icons.search.codePoint) return 'search';
    if (icon.codePoint == Icons.home.codePoint) return 'home';
    if (icon.codePoint == Icons.dashboard.codePoint) return 'dashboard';
    if (icon.codePoint == Icons.bar_chart.codePoint) return 'bar_chart';
    if (icon.codePoint == Icons.pie_chart.codePoint) return 'pie_chart';
    if (icon.codePoint == Icons.show_chart.codePoint) return 'show_chart';
    if (icon.codePoint == Icons.multiline_chart.codePoint) return 'multiline_chart';
    if (icon.codePoint == Icons.stacked_line_chart.codePoint) return 'stacked_line_chart';
    if (icon.codePoint == Icons.calendar_today.codePoint) return 'calendar_today';
    if (icon.codePoint == Icons.date_range.codePoint) return 'date_range';
    return 'flag_outlined';
  }

  static Map<String, dynamic> _activityToJson(CampaignActivity a) => {
        'description': a.description,
        'date': a.date,
        'iconName': _iconToName(a.icon),
        'iconColorValue': a.iconColor.toARGB32(),
      };

  static CampaignActivity _activityFromJson(Map<String, dynamic> json) {
    // Support both new 'iconName' and legacy 'iconCode' formats
    String? iconName = json['iconName']?.toString();
    final colorValue = _toInt(json['iconColorValue']);
    final icon = (iconName != null && _iconLookup.containsKey(iconName))
        ? _iconLookup[iconName]!
        : Icons.flag_outlined;
    return CampaignActivity(
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      icon: icon,
      iconColor: colorValue != 0 ? Color(colorValue) : AppColors.primary,
    );
  }

  // ── Coupons ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _couponToJson(CampaignCoupon cpn) => {
        'code': cpn.code,
        'discount': cpn.discount,
        'usageLimit': cpn.usageLimit,
        'usedCount': cpn.usedCount,
        'expiryDate': cpn.expiryDate,
      };

  static CampaignCoupon _couponFromJson(Map<String, dynamic> json) {
    return CampaignCoupon(
      code: json['code']?.toString() ?? '',
      discount: json['discount']?.toString() ?? '',
      usageLimit: _toInt(json['usageLimit']),
      usedCount: _toInt(json['usedCount']),
      expiryDate: json['expiryDate']?.toString() ?? '',
    );
  }

  // ── Primitive coercion helpers (PostgREST may deliver numeric/date types
  //    as int, double, String or null depending on column type) ─────────────

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime _dateFromDb(dynamic v) {
    if (v == null) return DateTime(2020, 1, 1);
    final s = v.toString();
    final parsed = DateTime.tryParse(s.isEmpty ? '' : s);
    return parsed ?? DateTime(2020, 1, 1);
  }

  static String? _dateToDb(DateTime? d) =>
      d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
