import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/admin_alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BudgetRequest — model for budget allocation requests that require
// manager approval before funds are available.
// ─────────────────────────────────────────────────────────────────────────────

class BudgetRequest {
  final String id;
  final String? budgetId;
  final String? campaignId;
  final String requestedBy;
  final double requestedAmount;
  final String category;
  final String description;
  final String status; // 'Pending' | 'Approved' | 'Rejected'
  final String reviewedBy;
  final String reviewComments;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const BudgetRequest({
    required this.id,
    this.budgetId,
    this.campaignId,
    required this.requestedBy,
    required this.requestedAmount,
    required this.category,
    required this.description,
    required this.status,
    required this.reviewedBy,
    required this.reviewComments,
    this.reviewedAt,
    required this.createdAt,
  });

  BudgetRequest copyWith({
    String? status,
    String? reviewedBy,
    String? reviewComments,
    DateTime? reviewedAt,
  }) =>
      BudgetRequest(
        id: id,
        budgetId: budgetId,
        campaignId: campaignId,
        requestedBy: requestedBy,
        requestedAmount: requestedAmount,
        category: category,
        description: description,
        status: status ?? this.status,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        reviewComments: reviewComments ?? this.reviewComments,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'budget_id': budgetId,
        'campaign_id': campaignId,
        'requested_by': requestedBy,
        'requested_amount': requestedAmount,
        'category': category,
        'description': description,
        'status': status,
        'reviewed_by': reviewedBy,
        'review_comments': reviewComments,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  static BudgetRequest fromRow(Map<String, dynamic> r) => BudgetRequest(
        id: r['id']?.toString() ?? '',
        budgetId: r['budget_id']?.toString(),
        campaignId: r['campaign_id']?.toString(),
        requestedBy: r['requested_by']?.toString() ?? '',
        requestedAmount: (r['requested_amount'] as num?)?.toDouble() ?? 0,
        category: r['category']?.toString() ?? 'Other',
        description: r['description']?.toString() ?? '',
        status: r['status']?.toString() ?? 'Pending',
        reviewedBy: r['reviewed_by']?.toString() ?? '',
        reviewComments: r['review_comments']?.toString() ?? '',
        reviewedAt: r['reviewed_at'] != null
            ? DateTime.tryParse(r['reviewed_at'].toString())
            : null,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BudgetRequestRepository — Supabase-backed
// ─────────────────────────────────────────────────────────────────────────────

class BudgetRequestRepository {
  BudgetRequestRepository._();

  static const _table = 'budget_requests';
  static final List<BudgetRequest> _items = [];
  static bool _initialized = false;

  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    if (!SupabaseConfig.isConfigured) return;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 8));
      _items
        ..clear()
        ..addAll(rows.map<BudgetRequest>(BudgetRequest.fromRow));
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'read', error: e);
    }
  }

  static List<BudgetRequest> getAll() => List.unmodifiable(_items);

  static List<BudgetRequest> getPending() =>
      _items.where((r) => r.status == 'Pending').toList();

  static BudgetRequest? findById(String id) {
    try {
      return _items.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> add(BudgetRequest req) async {
    if (SupabaseConfig.isConfigured && !await _upsert(req)) return false;
    _items.insert(0, req);
    return true;
  }

  static Future<bool> update(BudgetRequest req) async {
    final idx = _items.indexWhere((r) => r.id == req.id);
    if (idx == -1) return false;
    if (SupabaseConfig.isConfigured && !await _upsert(req)) return false;
    _items[idx] = req;
    return true;
  }

  static Future<bool> remove(String id) async {
    if (!_items.any((request) => request.id == id)) return false;
    if (SupabaseConfig.isConfigured && !await _delete(id)) return false;
    _items.removeWhere((r) => r.id == id);
    return true;
  }

  static String nextId() {
    if (_items.isEmpty) return 'BR001';
    final maxNum = _items
        .map((r) => int.tryParse(r.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'BR${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  static Future<bool> _upsert(BudgetRequest req) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(req.toRow())
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
      return false;
    }
  }

  static Future<bool> _delete(String id) async {
    if (!SupabaseConfig.isConfigured) return true;
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
        return false;
      }
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'delete', error: e);
      return false;
    }
  }
}
