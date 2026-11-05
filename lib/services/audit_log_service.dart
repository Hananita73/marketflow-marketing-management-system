import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuditLogService
//
// Records important user activity to the `audit_logs` Supabase table.
// Every call is fire-and-forget: the app never waits on audit writes and
// never surfaces errors to the user if audit logging fails.
//
// Usage:
//   AuditLogService.log(
//     action: 'create',
//     module: 'Campaigns',
//     recordId: 'C007',
//     recordName: 'Holiday Promo 2026',
//   );
// ─────────────────────────────────────────────────────────────────────────────

class AuditLogEntry {
  final int id;
  final String userId;
  final String userName;
  final String action;
  final String module;
  final String recordId;
  final String recordName;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.module,
    required this.recordId,
    required this.recordName,
    required this.details,
    required this.createdAt,
  });

  static AuditLogEntry fromRow(Map<String, dynamic> r) => AuditLogEntry(
        id: (r['id'] as num?)?.toInt() ?? 0,
        userId: r['user_id']?.toString() ?? '',
        userName: r['user_name']?.toString() ?? '',
        action: r['action']?.toString() ?? '',
        module: r['module']?.toString() ?? '',
        recordId: r['record_id']?.toString() ?? '',
        recordName: r['record_name']?.toString() ?? '',
        details: Map<String, dynamic>.from(r['details'] as Map? ?? {}),
        createdAt:
            DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class AuditLogService {
  AuditLogService._();

  static const _table = 'audit_logs';

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Logs an action. Fire-and-forget — never throws or blocks the caller.
  ///
  /// [action]     : 'create' | 'update' | 'delete' | 'approve' | 'reject' |
  ///                'login' | 'logout' | 'submit' | 'activate' | 'convert'
  /// [module]     : 'Campaigns' | 'Leads' | 'Customers' | 'Budget' |
  ///                'Promotions' | 'Opportunities' | 'Content' | 'Influencers' |
  ///                'Automation' | 'Users' | 'SMS' | 'Auth'
  /// [recordId]   : primary key of the affected record (e.g. 'C001', '42')
  /// [recordName] : human-readable label (e.g. 'Summer Sale 2026')
  /// [details]    : optional extra data to store as JSONB
  static void log({
    required String action,
    required String module,
    String recordId = '',
    String recordName = '',
    Map<String, dynamic>? details,
  }) {
    if (!SupabaseConfig.isConfigured) return;

    final auth = AuthService();
    final userId = auth.currentUser?.id;
    final userName = auth.currentName;

    // Run async in background without awaiting.
    Future.microtask(() async {
      try {
        await Supabase.instance.client.from(_table).insert({
          'user_id': userId,
          'user_name': userName,
          'action': action,
          'module': module,
          'record_id': recordId,
          'record_name': recordName,
          'details': details ?? {},
          'created_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 8));
      } catch (e) {
        // Audit failure is non-critical — log locally only.
        developer.log('AuditLog write failed: $e', name: 'AuditLogService');
      }
    });
  }

  // ── Convenience wrappers ───────────────────────────────────────────────────

  static void logCreate(String module, String recordId, String recordName,
          {Map<String, dynamic>? details}) =>
      log(action: 'create', module: module, recordId: recordId, recordName: recordName, details: details);

  static void logUpdate(String module, String recordId, String recordName,
          {Map<String, dynamic>? details}) =>
      log(action: 'update', module: module, recordId: recordId, recordName: recordName, details: details);

  static void logDelete(String module, String recordId, String recordName,
          {Map<String, dynamic>? details}) =>
      log(action: 'delete', module: module, recordId: recordId, recordName: recordName, details: details);

  static void logApprove(String module, String recordId, String recordName,
          {Map<String, dynamic>? details}) =>
      log(action: 'approve', module: module, recordId: recordId, recordName: recordName, details: details);

  static void logReject(String module, String recordId, String recordName,
          {Map<String, dynamic>? details}) =>
      log(action: 'reject', module: module, recordId: recordId, recordName: recordName, details: details);

  static void logLogin(String userEmail) =>
      log(action: 'login', module: 'Auth', recordName: userEmail);

  static void logLogout(String userEmail) =>
      log(action: 'logout', module: 'Auth', recordName: userEmail);

  static void logSubmit(String module, String recordId, String recordName,
          {Map<String, dynamic>? details}) =>
      log(action: 'submit', module: module, recordId: recordId, recordName: recordName, details: details);

  static void logConvert(String module, String recordId, String recordName,
          {Map<String, dynamic>? details}) =>
      log(action: 'convert', module: module, recordId: recordId, recordName: recordName, details: details);

  // ── Read (admin/manager use) ───────────────────────────────────────────────

  /// Fetches recent audit log entries for the Users/Audit screen.
  /// Returns an empty list when offline or on error.
  static Future<List<AuditLogEntry>> fetchRecent({
    int limit = 100,
    String? actionFilter,
    String? moduleFilter,
  }) async {
    if (!SupabaseConfig.isConfigured) return [];
    try {
      // Build query with filters applied BEFORE limit (transform builder limitation).
      var q = Supabase.instance.client
          .from(_table)
          .select()
          .order('created_at', ascending: false);

      // Apply eq filters before calling limit (must stay on FilterBuilder)
      dynamic filtered = q;
      if (actionFilter != null && actionFilter.isNotEmpty) {
        filtered = (filtered as dynamic).eq('action', actionFilter);
      }
      if (moduleFilter != null && moduleFilter.isNotEmpty) {
        filtered = (filtered as dynamic).eq('module', moduleFilter);
      }

      final rows = await (filtered as dynamic)
          .limit(limit)
          .timeout(const Duration(seconds: 8));

      return (rows as List)
          .map<AuditLogEntry>((r) => AuditLogEntry.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('AuditLog fetch failed: $e', name: 'AuditLogService');
      return [];
    }
  }

  /// Fetches audit entries with an optional text search across user_name,
  /// record_name, and action fields (client-side filter over recent entries).
  static Future<List<AuditLogEntry>> search({
    String query = '',
    String? actionFilter,
    String? moduleFilter,
    int limit = 200,
  }) async {
    final all = await fetchRecent(
      limit: limit,
      actionFilter: actionFilter,
      moduleFilter: moduleFilter,
    );
    if (query.isEmpty) return all;
    final q = query.toLowerCase();
    return all
        .where((e) =>
            e.userName.toLowerCase().contains(q) ||
            e.recordName.toLowerCase().contains(q) ||
            e.action.toLowerCase().contains(q) ||
            e.module.toLowerCase().contains(q))
        .toList();
  }
}
