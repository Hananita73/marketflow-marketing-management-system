import 'package:flutter/material.dart';
import '../core/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum ReportType {
  campaignPerformance,
  leadAnalytics,
  budgetReport,
  customerGrowth,
  roiAnalysis,
  communicationPerformance,
}

enum ReportStatus {
  ready,
  scheduled,
  generating,
  failed,
}

enum ReportSchedule {
  none,
  daily,
  weekly,
  monthly,
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

extension ReportTypeLabel on ReportType {
  String get label {
    switch (this) {
      case ReportType.campaignPerformance:
        return 'Campaign Performance';
      case ReportType.leadAnalytics:
        return 'Lead Analytics';
      case ReportType.budgetReport:
        return 'Budget Report';
      case ReportType.customerGrowth:
        return 'Customer Growth';
      case ReportType.roiAnalysis:
        return 'ROI Analysis';
      case ReportType.communicationPerformance:
        return 'Communication Performance';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportType.campaignPerformance:
        return Icons.campaign_outlined;
      case ReportType.leadAnalytics:
        return Icons.person_search_outlined;
      case ReportType.budgetReport:
        return Icons.account_balance_wallet_outlined;
      case ReportType.customerGrowth:
        return Icons.group_outlined;
      case ReportType.roiAnalysis:
        return Icons.trending_up_outlined;
      case ReportType.communicationPerformance:
        return Icons.forum_outlined;
    }
  }
}

extension ReportStatusLabel on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.ready:
        return 'Ready';
      case ReportStatus.scheduled:
        return 'Scheduled';
      case ReportStatus.generating:
        return 'Generating';
      case ReportStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case ReportStatus.ready:
        return AppColors.success;
      case ReportStatus.scheduled:
        return AppColors.primary;
      case ReportStatus.generating:
        return AppColors.warning;
      case ReportStatus.failed:
        return AppColors.danger;
    }
  }

  Color get bgColor {
    switch (this) {
      case ReportStatus.ready:
        return AppColors.successBg;
      case ReportStatus.scheduled:
        return AppColors.primaryLight;
      case ReportStatus.generating:
        return AppColors.warningBg;
      case ReportStatus.failed:
        return AppColors.dangerBg;
    }
  }
}

extension ReportScheduleLabel on ReportSchedule {
  String get label {
    switch (this) {
      case ReportSchedule.none:
        return 'None';
      case ReportSchedule.daily:
        return 'Daily';
      case ReportSchedule.weekly:
        return 'Weekly';
      case ReportSchedule.monthly:
        return 'Monthly';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReportRecord
// ─────────────────────────────────────────────────────────────────────────────

class ReportRecord {
  final String id;
  String name;
  String description;
  ReportType type;
  ReportStatus status;
  DateTime? lastGenerated;
  String createdBy;
  String dateRange;
  ReportSchedule schedule;
  List<String> recipients;

  ReportRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    this.lastGenerated,
    required this.createdBy,
    required this.dateRange,
    this.schedule = ReportSchedule.none,
    this.recipients = const [],
  });

  ReportRecord copyWith({
    String? name,
    String? description,
    ReportType? type,
    ReportStatus? status,
    DateTime? lastGenerated,
    String? createdBy,
    String? dateRange,
    ReportSchedule? schedule,
    List<String>? recipients,
  }) {
    return ReportRecord(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      lastGenerated: lastGenerated ?? this.lastGenerated,
      createdBy: createdBy ?? this.createdBy,
      dateRange: dateRange ?? this.dateRange,
      schedule: schedule ?? this.schedule,
      recipients: recipients ?? this.recipients,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReportRepository — in-memory mock
// ─────────────────────────────────────────────────────────────────────────────

class ReportRepository {
  ReportRepository._();

  static int _nextId = 7;

  static final List<ReportRecord> _records = [
    ReportRecord(
      id: '1',
      name: 'Campaign Performance',
      description:
          'Detailed breakdown of all active and completed campaigns, '
          'including impressions, clicks, conversions, and ROI by channel.',
      type: ReportType.campaignPerformance,
      status: ReportStatus.ready,
      lastGenerated: DateTime(2026, 8, 14, 9, 30),
      createdBy: 'Hana Tsegaye',
      dateRange: 'Jul 1 – Aug 14, 2026',
      schedule: ReportSchedule.weekly,
      recipients: ['hana@marketflow.et'],
    ),
    ReportRecord(
      id: '2',
      name: 'Lead Analytics',
      description:
          'Lead pipeline summary showing source distribution, conversion '
          'rates, average time-to-close, and funnel drop-off points.',
      type: ReportType.leadAnalytics,
      status: ReportStatus.scheduled,
      lastGenerated: DateTime(2026, 8, 10, 8, 0),
      createdBy: 'Hana Tsegaye',
      dateRange: 'Aug 1 – Aug 31, 2026',
      schedule: ReportSchedule.monthly,
      recipients: ['hana@marketflow.et', 'team@marketflow.et'],
    ),
    ReportRecord(
      id: '3',
      name: 'Budget Report',
      description:
          'Allocation vs. spend analysis across all marketing channels, '
          'highlighting over- and under-spend categories.',
      type: ReportType.budgetReport,
      status: ReportStatus.ready,
      lastGenerated: DateTime(2026, 8, 13, 14, 15),
      createdBy: 'Hana Tsegaye',
      dateRange: 'Jan 1 – Aug 14, 2026',
      schedule: ReportSchedule.monthly,
      recipients: ['hana@marketflow.et'],
    ),
    ReportRecord(
      id: '4',
      name: 'Customer Growth',
      description:
          'Month-over-month new customer acquisition, churn rate, '
          'retention trends, and lifetime value estimates.',
      type: ReportType.customerGrowth,
      status: ReportStatus.generating,
      lastGenerated: DateTime(2026, 8, 1, 0, 0),
      createdBy: 'Hana Tsegaye',
      dateRange: 'Q2 2026',
      schedule: ReportSchedule.weekly,
      recipients: [],
    ),
    ReportRecord(
      id: '5',
      name: 'ROI Analysis',
      description:
          'Return-on-investment breakdown by campaign type, channel, '
          'and budget tier — with ETB spend-to-revenue mapping.',
      type: ReportType.roiAnalysis,
      status: ReportStatus.ready,
      lastGenerated: DateTime(2026, 8, 12, 11, 45),
      createdBy: 'Hana Tsegaye',
      dateRange: 'Jan 1 – Aug 12, 2026',
      schedule: ReportSchedule.none,
      recipients: ['hana@marketflow.et'],
    ),
    ReportRecord(
      id: '6',
      name: 'Communication Performance',
      description:
          'Email and SMS campaign metrics: delivery rate, open rate, '
          'click-through rate, and unsubscribe rate by segment.',
      type: ReportType.communicationPerformance,
      status: ReportStatus.failed,
      lastGenerated: DateTime(2026, 8, 5, 16, 0),
      createdBy: 'Hana Tsegaye',
      dateRange: 'Jul 1 – Aug 5, 2026',
      schedule: ReportSchedule.none,
      recipients: [],
    ),
  ];

  static List<ReportRecord> getAll() => List.unmodifiable(_records);

  static ReportRecord? findById(String id) {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  static ReportRecord add(ReportRecord record) {
    _records.add(record);
    return record;
  }

  static String nextId() => (_nextId++).toString();

  static void update(ReportRecord updated) {
    final idx = _records.indexWhere((r) => r.id == updated.id);
    if (idx != -1) _records[idx] = updated;
  }

  static void delete(String id) {
    _records.removeWhere((r) => r.id == id);
  }
}
