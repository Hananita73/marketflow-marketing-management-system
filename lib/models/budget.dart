import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../services/admin_alert_service.dart';
import '../services/entity_remote_stores.dart';

// ══════════════════════════════════════════════════════════════════════════
// BUDGET EXPENSE — model for tracking individual budget expenses.
// ══════════════════════════════════════════════════════════════════════════

class BudgetExpense {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String approvedBy;
  final String status; // 'pending', 'approved', 'rejected'
  final String campaignId; // optional campaign linkage

  const BudgetExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.approvedBy,
    required this.status,
    this.campaignId = '',
  });

  Color get statusColor {
    if (status == 'approved') return AppColors.success;
    if (status == 'pending') return AppColors.warning;
    return AppColors.danger;
  }
}

// ══════════════════════════════════════════════════════════════════════════
// BUDGET — canonical model for the Budget module.
// ══════════════════════════════════════════════════════════════════════════

class Budget {
  final String id;
  final String name;
  final String category;
  final double allocated;
  final double spent;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final String status;
  final DateTime lastUpdated;
  final String? campaignId;
  final List<BudgetExpense> expenses;

  const Budget({
    required this.id,
    required this.name,
    required this.category,
    required this.allocated,
    required this.spent,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.status,
    required this.lastUpdated,
    this.campaignId,
    this.expenses = const [],
  });

  Budget copyWith({
    String? name,
    String? category,
    double? allocated,
    double? spent,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    String? status,
    DateTime? lastUpdated,
    String? campaignId,
    List<BudgetExpense>? expenses,
  }) =>
      Budget(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        allocated: allocated ?? this.allocated,
        spent: spent ?? this.spent,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        description: description ?? this.description,
        status: status ?? this.status,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        campaignId: campaignId ?? this.campaignId,
        expenses: expenses ?? this.expenses,
      );

  double get remaining =>
      (allocated - spent - expenses.fold(0, (s, e) => s + e.amount)).clamp(0, double.infinity);

  double get utilization => allocated > 0 ? (spent / allocated).clamp(0, 1) : 0;

  String get utilizationStatus {
    if (utilization >= 1.0) return 'Over Budget';
    if (utilization >= 0.85) return 'Near Limit';
    return 'Healthy';
  }

  Color get utilizationColor {
    if (utilization >= 1.0) return AppColors.danger;
    if (utilization >= 0.85) return AppColors.warning;
    return AppColors.success;
  }

  double get approvedExpenses =>
      expenses.where((e) => e.status == 'approved').fold(0, (s, e) => s + e.amount);
}

// ══════════════════════════════════════════════════════════════════════════
// BUDGET REPOSITORY — local seed data + Supabase sync wrapper.
// ══════════════════════════════════════════════════════════════════════════

class BudgetRepository {
  BudgetRepository._();

  static final List<Budget> _budgets = [
    Budget(
      id: 'B001',
      name: 'Digital Advertising',
      category: 'Advertising',
      allocated: 320000,
      spent: 272000,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      description: 'Google Ads, Facebook Ads, and display campaigns.',
      status: AppConstants.statusActive,
      lastUpdated: DateTime(2026, 8, 10),
    ),
    Budget(
      id: 'B002',
      name: 'Blog & Video Content',
      category: 'Content',
      allocated: 150000,
      spent: 68000,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      description: 'Blog posts, videos, and infographic production.',
      status: AppConstants.statusActive,
      lastUpdated: DateTime(2026, 8, 8),
    ),
    Budget(
      id: 'B003',
      name: 'Influencer Partnerships',
      category: 'Influencer Marketing',
      allocated: 180000,
      spent: 178500,
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 9, 30),
      description: 'Sponsored posts and collaboration fees.',
      status: AppConstants.statusActive,
      lastUpdated: DateTime(2026, 8, 12),
    ),
    Budget(
      id: 'B004',
      name: 'Annual Conference',
      category: 'Events',
      allocated: 220000,
      spent: 238000,
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 8, 31),
      description: 'Addis Ababa marketing summit — venue, catering, AV.',
      status: AppConstants.statusActive,
      lastUpdated: DateTime(2026, 8, 14),
    ),
    Budget(
      id: 'B005',
      name: 'Email & SMS Campaigns',
      category: 'Email/SMS',
      allocated: 80000,
      spent: 42000,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      description: 'Bulk email platform, SMS gateway, automation tools.',
      status: AppConstants.statusActive,
      lastUpdated: DateTime(2026, 8, 7),
    ),
    Budget(
      id: 'B006',
      name: 'Market Research',
      category: 'Other',
      allocated: 50000,
      spent: 12500,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30),
      description: 'Consumer surveys, competitor analysis, reports.',
      status: AppConstants.statusPaused,
      lastUpdated: DateTime(2026, 7, 15),
    ),
  ];

  static bool _initialized = false;

  /// Loads budgets from Supabase once at startup (called from main.dart).
  /// Falls back to bundled seed data when the backend is unreachable; seeds
  /// the remote table from local data on first run when it is empty.
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await BudgetRemoteStore.fetchAll();
    if (remote == null) return;
    if (remote.isEmpty) {
      await BudgetRemoteStore.seed(_budgets);
    } else {
      _budgets ..clear() ..addAll(remote);
    }
  }

  static List<Budget> getAll() => List.unmodifiable(_budgets);

  static Budget? findById(String id) {
    try {
      return _budgets.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Budgets allocated to a specific campaign.
  static List<Budget> getByCampaign(String campaignId) =>
      _budgets.where((b) => b.campaignId == campaignId).toList();

  /// Total allocated budget for a campaign (sum of non-Draft allocations).
  /// Draft allocations are treated as pending requests, not approved funds.
  static double allocatedForCampaign(String campaignId) => _budgets
      .where((b) => b.campaignId == campaignId && b.status != AppConstants.statusDraft)
      .fold(0, (s, b) => s + b.allocated);

  /// Pending budget allocations for a campaign (Draft status).
  static double pendingAllocationForCampaign(String campaignId) => _budgets
      .where((b) => b.campaignId == campaignId && b.status == AppConstants.statusDraft)
      .fold(0, (s, b) => s + b.allocated);

  static void add(Budget budget) {
    _budgets.add(budget);
    _alertIfThresholdCrossed(null, budget);
    // Persist to database (fire-and-forget, fails silently in offline mode)
    BudgetRemoteStore.upsert(budget)
      .then((_) {
        // Budget persisted to database
      })
      .onError((_, _) {
        // Failed to persist - running in offline mode, local data remains valid
      });
  }

  static void update(Budget budget) {
    final idx = _budgets.indexWhere((b) => b.id == budget.id);
    if (idx != -1) {
      final previous = _budgets[idx];
      _budgets[idx] = budget;
      _alertIfThresholdCrossed(previous, budget);
      // Persist to database (fire-and-forget, fails silently in offline mode)
      BudgetRemoteStore.upsert(budget)
        .then((_) {
          // Budget persisted to database
        })
        .onError((_, _) {
          // Failed to persist - running in offline mode, local data remains valid
        });
    }
  }

  static void remove(String id) {
    _budgets.removeWhere((b) => b.id == id);
    BudgetRemoteStore.delete(id); // fire-and-forget sync
  }

  /// Fraction of an allocated budget already spent (0 when nothing allocated).
  static double _utilisation(Budget b) =>
      b.allocated > 0 ? b.spent / b.allocated : 0;

  /// Emails the admin the first time a budget's spend crosses 80%.
  /// [before] is null when the budget is brand new.
  static void _alertIfThresholdCrossed(Budget? before, Budget after) {
    const threshold = 0.8;

    final used = _utilisation(after);
    if (used < threshold) return;
    // Only alert on the crossing itself, not on every later save.
    if (before != null && _utilisation(before) >= threshold) return;

    final percent = (used * 100).round();
    AdminAlertService.report(
      event: 'Budget threshold reached',
      message: '"${after.name}" has used $percent% of its allocated budget '
          '(${after.spent.toStringAsFixed(0)} of ${after.allocated.toStringAsFixed(0)}).',
      severity: 'warning',
      details: {
        'budget': after.name,
        'category': after.category,
        'spent': after.spent,
        'allocated': after.allocated,
        'utilisation': '$percent%',
      },
    );
  }

  static String nextId() {
    if (_budgets.isEmpty) return 'B001';
    final maxNum = _budgets
        .map((b) => int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'B${(maxNum + 1).toString().padLeft(3, '0')}';
  }
}
