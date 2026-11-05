import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/admin_alert_service.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationCategory enum
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationCategory {
  campaign,
  lead,
  customer,
  budget,
  automation,
  report,
  system,
  promotion,
}

extension NotificationCategoryX on NotificationCategory {
  String get label {
    switch (this) {
      case NotificationCategory.campaign:   return 'Campaigns';
      case NotificationCategory.lead:       return 'Leads';
      case NotificationCategory.customer:   return 'Customers';
      case NotificationCategory.budget:     return 'Budget';
      case NotificationCategory.automation: return 'Automation';
      case NotificationCategory.report:     return 'Reports';
      case NotificationCategory.system:     return 'System';
      case NotificationCategory.promotion:  return 'Promotions';
    }
  }

  String get dbValue {
    switch (this) {
      case NotificationCategory.campaign:   return 'campaign';
      case NotificationCategory.lead:       return 'lead';
      case NotificationCategory.customer:   return 'customer';
      case NotificationCategory.budget:     return 'budget';
      case NotificationCategory.automation: return 'automation';
      case NotificationCategory.report:     return 'report';
      case NotificationCategory.system:     return 'system';
      case NotificationCategory.promotion:  return 'promotion';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationCategory.campaign:   return Icons.campaign_outlined;
      case NotificationCategory.lead:       return Icons.person_search_outlined;
      case NotificationCategory.customer:   return Icons.people_outline;
      case NotificationCategory.budget:     return Icons.account_balance_wallet_outlined;
      case NotificationCategory.automation: return Icons.settings_suggest_outlined;
      case NotificationCategory.report:     return Icons.bar_chart_outlined;
      case NotificationCategory.system:     return Icons.info_outline;
      case NotificationCategory.promotion:  return Icons.local_offer_outlined;
    }
  }

  Color get color {
    switch (this) {
      case NotificationCategory.campaign:   return const Color(0xFF6C4CE8);
      case NotificationCategory.lead:       return const Color(0xFF0EA5E9);
      case NotificationCategory.customer:   return const Color(0xFF22A06B);
      case NotificationCategory.budget:     return const Color(0xFFF59E0B);
      case NotificationCategory.automation: return const Color(0xFFE5484D);
      case NotificationCategory.report:     return const Color(0xFF22A06B);
      case NotificationCategory.system:     return const Color(0xFF777784);
      case NotificationCategory.promotion:  return const Color(0xFFBB5CF8);
    }
  }

  String? get route {
    switch (this) {
      case NotificationCategory.campaign:   return '/campaigns';
      case NotificationCategory.lead:       return '/leads';
      case NotificationCategory.customer:   return '/customers';
      case NotificationCategory.budget:     return '/budget';
      case NotificationCategory.automation: return '/automation';
      case NotificationCategory.report:     return '/reports';
      case NotificationCategory.promotion:  return '/promotions';
      case NotificationCategory.system:     return null;
    }
  }

  static NotificationCategory fromDb(String value) {
    switch (value.toLowerCase()) {
      case 'campaign':   return NotificationCategory.campaign;
      case 'lead':       return NotificationCategory.lead;
      case 'customer':   return NotificationCategory.customer;
      case 'budget':     return NotificationCategory.budget;
      case 'automation': return NotificationCategory.automation;
      case 'report':     return NotificationCategory.report;
      case 'promotion':  return NotificationCategory.promotion;
      default:           return NotificationCategory.system;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationModel
// ─────────────────────────────────────────────────────────────────────────────

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final DateTime createdAt;
  bool isRead;

  // Legacy alias kept for backward compatibility.
  String get date => createdAt.toIso8601String();

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        message: message,
        category: category,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toRow({String? userId}) => {
        'id': id,
        'user_id': userId,
        'title': title,
        'message': message,
        'category': category.dbValue,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  static NotificationModel fromRow(Map<String, dynamic> r) => NotificationModel(
        id: r['id']?.toString() ?? '',
        title: r['title']?.toString() ?? '',
        message: r['message']?.toString() ?? '',
        category: NotificationCategoryX.fromDb(r['category']?.toString() ?? 'system'),
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        isRead: r['is_read'] == true,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationRepository — Supabase-backed with in-memory fallback
// ─────────────────────────────────────────────────────────────────────────────

class NotificationRepository {
  NotificationRepository._();

  static const _table = 'notifications';
  static final List<NotificationModel> _items = [];
  static bool _initialized = false;
  static RealtimeChannel? _channel;

  // ── Initialise ─────────────────────────────────────────────────────────────

  /// Load notifications for the current user from Supabase.
  /// Falls back to seed data when offline.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;

    if (!SupabaseConfig.isConfigured) {
      _loadSeedData();
      return;
    }

    try {
      final userId = AuthService().currentUser?.id;
      // Filter by user when authenticated, otherwise fetch all (dev mode).
      final rows = userId != null
          ? await Supabase.instance.client
              .from(_table)
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(100)
              .timeout(const Duration(seconds: 6))
          : await Supabase.instance.client
              .from(_table)
              .select()
              .order('created_at', ascending: false)
              .limit(100)
              .timeout(const Duration(seconds: 6));

      _items
        ..clear()
        ..addAll(rows.map<NotificationModel>(NotificationModel.fromRow));

      // If the table is empty for this user seed sample notifications.
      if (_items.isEmpty) {
        _loadSeedData();
        await _pushSeedToDb(userId);
      }

      _subscribeRealtime(userId);
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'read', error: e);
      _loadSeedData();
    }
  }

  /// Subscribe to real-time INSERT events on the notifications table.
  static void _subscribeRealtime(String? userId) {
    _channel?.unsubscribe();
    if (!SupabaseConfig.isConfigured) return;
    _channel = Supabase.instance.client
        .channel('notifications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _table,
          callback: (payload) {
            final row = payload.newRecord;
            // Only add if it belongs to this user (or no user filter).
            if (userId == null || row['user_id'] == userId) {
              final n = NotificationModel.fromRow(row);
              _items.insert(0, n); // newest first
            }
          },
        )
        .subscribe();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  static List<NotificationModel> getAll() =>
      List<NotificationModel>.from(_items);

  static int get unreadCount => _items.where((n) => !n.isRead).length;

  static void markAsRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _items[idx].isRead = true;
      _updateDb(id, {'is_read': true});
    }
  }

  static void markAsUnread(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _items[idx].isRead = false;
      _updateDb(id, {'is_read': false});
    }
  }

  static void markAllAsRead() {
    for (final n in _items) {
      n.isRead = true;
    }
    _markAllReadDb();
  }

  static void delete(String id) {
    _items.removeWhere((n) => n.id == id);
    _deleteDb(id);
  }

  /// Adds a new notification for the current user and persists it.
  static Future<void> add({
    required String title,
    required String message,
    required NotificationCategory category,
    String? targetUserId,
  }) async {
    final id = 'n_${DateTime.now().millisecondsSinceEpoch}';
    final n = NotificationModel(
      id: id,
      title: title,
      message: message,
      category: category,
      createdAt: DateTime.now(),
      isRead: false,
    );
    _items.insert(0, n);

    if (!SupabaseConfig.isConfigured) return;
    try {
      final userId = targetUserId ?? AuthService().currentUser?.id;
      await Supabase.instance.client
          .from(_table)
          .insert(n.toRow(userId: userId))
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
    }
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  static Future<void> _updateDb(String id, Map<String, dynamic> data) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .update(data)
          .eq('id', id)
          .select('id')
          .timeout(const Duration(seconds: 6));
      if (rows.isEmpty) {
        AdminAlertService.reportStoreFailure(
          table: _table,
          operation: 'update',
          error: StateError('No matching row was updated.'),
        );
      }
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'update', error: e);
    }
  }

  static Future<void> _markAllReadDb() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final userId = AuthService().currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from(_table)
            .update({'is_read': true})
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 6));
      } else {
        await Supabase.instance.client
            .from(_table)
            .update({'is_read': true})
            .timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'update', error: e);
    }
  }

  static Future<void> _deleteDb(String id) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .delete()
          .eq('id', id)
          .select('id')
          .timeout(const Duration(seconds: 6));
      if (rows.isEmpty) {
        AdminAlertService.reportStoreFailure(
          table: _table,
          operation: 'delete',
          error: StateError('No matching row was deleted.'),
        );
      }
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'delete', error: e);
    }
  }

  static Future<void> _pushSeedToDb(String? userId) async {
    if (!SupabaseConfig.isConfigured || _items.isEmpty) return;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_items.map((n) => n.toRow(userId: userId)).toList())
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
    }
  }

  /// Loads sample notifications so the app is never empty on first run.
  static void _loadSeedData() {
    _items
      ..clear()
      ..addAll([
        NotificationModel(
          id: 'n01',
          title: 'Campaign Completed',
          message: 'Your "Q3 Brand Awareness" campaign finished. Final reach: 42,800 impressions.',
          category: NotificationCategory.campaign,
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
          isRead: false,
        ),
        NotificationModel(
          id: 'n02',
          title: 'New Lead Assigned',
          message: 'Tigist Bekele from Addis Tech Solutions has been assigned as a qualified lead.',
          category: NotificationCategory.lead,
          createdAt: DateTime.now().subtract(const Duration(minutes: 38)),
          isRead: false,
        ),
        NotificationModel(
          id: 'n03',
          title: 'Budget Threshold Reached',
          message: '"Digital Channels" budget hit 85% of monthly limit (ETB 127,500 of 150,000).',
          category: NotificationCategory.budget,
          createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
          isRead: false,
        ),
        NotificationModel(
          id: 'n04',
          title: 'Automation Workflow Failed',
          message: '"Welcome Email Sequence" failed at step 3: SMTP timed out. 14 contacts not reached.',
          category: NotificationCategory.automation,
          createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
          isRead: false,
        ),
        NotificationModel(
          id: 'n05',
          title: 'New Customer Added',
          message: 'Selam Trading PLC added as new customer. Managed by Hana Tsegaye.',
          category: NotificationCategory.customer,
          createdAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 44)),
          isRead: true,
        ),
        NotificationModel(
          id: 'n06',
          title: 'Monthly Report Generated',
          message: 'July 2026 marketing performance report is ready. View it in Reports.',
          category: NotificationCategory.report,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          isRead: true,
        ),
        NotificationModel(
          id: 'n07',
          title: 'Promotion Created',
          message: '"Mid-Year Flash Sale" promotion created and scheduled for August 20.',
          category: NotificationCategory.promotion,
          createdAt: DateTime.now().subtract(const Duration(hours: 7, minutes: 20)),
          isRead: true,
        ),
        NotificationModel(
          id: 'n08',
          title: 'User Invitation Accepted',
          message: 'Bereket Haile accepted your invitation and joined as Marketing Clerk.',
          category: NotificationCategory.system,
          createdAt: DateTime.now().subtract(const Duration(hours: 10)),
          isRead: true,
        ),
        NotificationModel(
          id: 'n09',
          title: 'Campaign Paused',
          message: '"Summer Influencer Push" paused after exceeding daily spend cap.',
          category: NotificationCategory.campaign,
          createdAt: DateTime.now().subtract(const Duration(hours: 22)),
          isRead: true,
        ),
        NotificationModel(
          id: 'n10',
          title: 'Lead Status Updated',
          message: 'Dawit Mekonnen progressed from "Contacted" to "Qualified".',
          category: NotificationCategory.lead,
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          isRead: true,
        ),
        NotificationModel(
          id: 'n11',
          title: 'System Maintenance Scheduled',
          message: 'Planned maintenance on Aug 17 from 02:00–04:00 EAT. Expect brief downtime.',
          category: NotificationCategory.system,
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
          isRead: false,
        ),
        NotificationModel(
          id: 'n12',
          title: 'Budget Approved',
          message: 'Q4 marketing budget of ETB 600,000 approved and available for allocation.',
          category: NotificationCategory.budget,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
        ),
      ]);
  }

  /// Dispose the realtime channel on app shutdown.
  static void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
