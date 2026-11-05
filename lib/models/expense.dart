import '../config/supabase_config.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../models/campaign.dart';
import '../services/expense_remote_store.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Expense — canonical expense record linked to a campaign and (optionally) to
// a budget allocation within that campaign.
//
// status         : pending | approved | rejected  (approval workflow)
// payment_status : Pending | Paid | Partial       (accounting state)
//
// This is the single source of truth for expenses. It replaces the previous
// pattern of storing expenses as a JSON column on campaigns (which was never
// persisted on upsert) and the unused BudgetExpense model.
// ─────────────────────────────────────────────────────────────────────────────

class Expense {
  final String id;
  final String campaignId;
  final String? budgetId;
  final String company;
  final String name;
  final String description;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String vendor;
  final String paymentStatus;
  final String status; // pending | approved | rejected
  final String recordedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.campaignId,
    this.budgetId,
    this.company = '',
    required this.name,
    this.description = '',
    this.category = 'Other',
    required this.amount,
    required this.expenseDate,
    this.vendor = '',
    this.paymentStatus = AppConstants.paymentPending,
    this.status = AppConstants.expensePending,
    this.recordedBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    String? budgetId,
    String? company,
    String? name,
    String? description,
    String? category,
    double? amount,
    DateTime? expenseDate,
    String? vendor,
    String? paymentStatus,
    String? status,
    String? recordedBy,
    DateTime? updatedAt,
  }) =>
      Expense(
        id: id,
        campaignId: campaignId,
        budgetId: budgetId ?? this.budgetId,
        company: company ?? this.company,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        expenseDate: expenseDate ?? this.expenseDate,
        vendor: vendor ?? this.vendor,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        status: status ?? this.status,
        recordedBy: recordedBy ?? this.recordedBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Color get statusColor {
    if (status == AppConstants.expenseApproved) return AppColors.success;
    if (status == AppConstants.expensePending) return AppColors.warning;
    return AppColors.danger;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ExpenseRepository — in-memory store + Supabase sync.
// ─────────────────────────────────────────────────────────────────────────────

class ExpenseRepository {
  ExpenseRepository._();

  static final List<Expense> _items = [];
  static bool _initialized = false;

  /// Loads expenses from Supabase once at startup (called from main.dart).
  ///
  /// On first run (empty remote table) it migrates the legacy expenses that
  /// were stored as JSON arrays on each campaign, attaching them to the
  /// campaign they belong to. This preserves all historical expense data
  /// without guessing any campaign relationships — each expense keeps the
  /// campaign it was already recorded under.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await ExpenseRemoteStore.fetchAll();
    if (remote == null) return; // offline — keep empty list
    if (remote.isEmpty) {
      await _seedFromCampaigns();
    } else {
      _items
        ..clear()
        ..addAll(remote);
    }
  }

  /// Migrates the legacy campaign.expenses JSON into the new expenses table.
  static Future<void> _seedFromCampaigns() async {
    // Take a snapshot so a concurrent remote campaign load cannot mutate the
    // list while we iterate it.
    final campaigns = List<Campaign>.from(CampaignRepository.getAll());
    int seq = 1;
    final migrated = <Expense>[];
    for (final c in campaigns) {
      for (final e in c.expenses) {
        final expense = Expense(
          id: 'EXP${seq.toString().padLeft(4, '0')}',
          campaignId: c.id,
          budgetId: null,
          name: e.description,
          description: e.description,
          category: 'Other',
          amount: e.amount,
          expenseDate: e.date,
          status: e.status,
          recordedBy: e.approvedBy,
          createdAt: e.date,
          updatedAt: e.date,
        );
        migrated.add(expense);
        seq++;
      }
    }
    _items.addAll(migrated);
    if (migrated.isNotEmpty) {
      await ExpenseRemoteStore.seed(migrated);
    }
  }

  static List<Expense> getAll() => List<Expense>.from(_items);

  /// All expenses for a campaign (any status).
  static List<Expense> getByCampaign(String campaignId) =>
      _items.where((e) => e.campaignId == campaignId).toList();

  /// All expenses linked to a budget allocation.
  static List<Expense> getByBudget(String? budgetId) =>
      budgetId == null ? [] : _items.where((e) => e.budgetId == budgetId).toList();

  static Expense? findById(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> add(Expense e) async {
    if (SupabaseConfig.isConfigured && !await ExpenseRemoteStore.upsert(e)) {
      return false;
    }
    _items.add(e);
    return true;
  }

  static Future<bool> update(Expense e) async {
    final idx = _items.indexWhere((x) => x.id == e.id);
    if (idx == -1) return false;
    if (SupabaseConfig.isConfigured && !await ExpenseRemoteStore.upsert(e)) {
      return false;
    }
    _items[idx] = e;
    return true;
  }

  static void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    ExpenseRemoteStore.delete(id).then((_) {}).onError((_, _) {});
  }

  /// Sum of valid (non-rejected) expenses for a campaign.
  static double actualExpensesForCampaign(String campaignId) => _items
      .where((e) => e.campaignId == campaignId && e.status != AppConstants.expenseRejected)
      .fold(0, (s, e) => s + e.amount);

  static double spentForCompany(String campaignId, String company) => _items
      .where(
        (expense) =>
            expense.campaignId == campaignId &&
            expense.company == company &&
            expense.status != AppConstants.expenseRejected,
      )
      .fold(0, (total, expense) => total + expense.amount);

  /// Sum of approved expenses only.
  static double approvedExpensesForCampaign(String campaignId) => _items
      .where((e) =>
          e.campaignId == campaignId && e.status == AppConstants.expenseApproved)
      .fold(0, (s, e) => s + e.amount);

  /// Sum of pending expenses only.
  static double pendingExpensesForCampaign(String campaignId) => _items
      .where((e) =>
          e.campaignId == campaignId && e.status == AppConstants.expensePending)
      .fold(0, (s, e) => s + e.amount);

  // ── Approval workflow ──────────────────────────────────────────────────────

  static Future<bool> approve(String id, String approverName) async {
    final e = findById(id);
    if (e == null) return false;
    return update(
      e.copyWith(
        status: AppConstants.expenseApproved,
        recordedBy: approverName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  static Future<bool> reject(String id, String approverName) async {
    final e = findById(id);
    if (e == null) return false;
    return update(
      e.copyWith(
        status: AppConstants.expenseRejected,
        recordedBy: approverName,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Generates the next expense id (e.g. EXP0007).
  static String nextId() {
    if (_items.isEmpty) return 'EXP0001';
    final maxNum = _items
        .map((e) => int.tryParse(e.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'EXP${(maxNum + 1).toString().padLeft(4, '0')}';
  }
}
