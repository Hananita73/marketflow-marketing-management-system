import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../core/constants.dart';
import '../models/expense.dart';
import 'admin_alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExpenseRemoteStore — Supabase data access for the expenses table.
// Same fail-soft pattern as the other remote stores.
// ─────────────────────────────────────────────────────────────────────────────

class ExpenseRemoteStore {
  ExpenseRemoteStore._();

  static const String _table = 'expenses';

  static Future<List<Expense>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('expense_date', ascending: false)
          .timeout(const Duration(seconds: 6));
      return rows.map<Expense>(_fromRow).toList();
    } catch (e) {
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<bool> upsert(Expense e) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(e))
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'write',
        error: e,
      );
      return false;
    }
  }

  static Future<bool> delete(String id) async {
    if (!SupabaseConfig.isConfigured) return false;
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
        table: _table,
        operation: 'delete',
        error: e,
      );
      return false;
    }
  }

  static Future<bool> seed(List<Expense> list) async {
    if (!SupabaseConfig.isConfigured || list.isEmpty) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(list.map(_toRow).toList())
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'write',
        error: e,
      );
      return false;
    }
  }

  static Map<String, dynamic> _toRow(Expense e) => {
    'id': e.id,
    'campaign_id': e.campaignId,
    'budget_id': e.budgetId,
    'company': e.company,
    'name': e.name,
    'description': e.description,
    'category': e.category,
    'amount': e.amount,
    'expense_date': _dateToDb(e.expenseDate),
    'vendor': e.vendor,
    'payment_status': e.paymentStatus,
    'status': e.status,
    'recorded_by': e.recordedBy,
  };

  static Expense _fromRow(Map<String, dynamic> r) {
    DateTime parseTs(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return Expense(
      id: r['id']?.toString() ?? '',
      campaignId: r['campaign_id']?.toString() ?? '',
      budgetId: r['budget_id']?.toString().isEmpty == true
          ? null
          : r['budget_id']?.toString(),
      company: r['company']?.toString() ?? '',
      name: r['name']?.toString() ?? '',
      description: r['description']?.toString() ?? '',
      category: r['category']?.toString() ?? 'Other',
      amount: _toDouble(r['amount']),
      expenseDate: _dateFromDb(r['expense_date']) ?? DateTime.now(),
      vendor: r['vendor']?.toString() ?? '',
      paymentStatus:
          r['payment_status']?.toString() ?? AppConstants.paymentPending,
      status: r['status']?.toString() ?? AppConstants.expensePending,
      recordedBy: r['recorded_by']?.toString() ?? '',
      createdAt: parseTs(r['created_at']),
      updatedAt: parseTs(r['updated_at']),
    );
  }

  // ── Shared coercion helpers (kept local to avoid cross-file coupling) ───────
  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _dateFromDb(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return DateTime.tryParse(s.isEmpty ? '' : s);
  }

  static String? _dateToDb(DateTime? d) => d == null
      ? null
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
