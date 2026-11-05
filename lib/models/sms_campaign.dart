import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/admin_alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmsCampaign — model for SMS marketing campaigns
// ─────────────────────────────────────────────────────────────────────────────

class SmsRecipient {
  final int customerId;
  final String name;
  final String phone;
  final String? deliveryStatus; // 'pending' | 'sent' | 'delivered' | 'failed'

  const SmsRecipient({
    required this.customerId,
    required this.name,
    required this.phone,
    this.deliveryStatus,
  });

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'name': name,
        'phone': phone,
        'delivery_status': deliveryStatus ?? 'pending',
      };

  static SmsRecipient fromJson(Map<String, dynamic> j) => SmsRecipient(
        customerId: (j['customer_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        deliveryStatus: j['delivery_status']?.toString(),
      );
}

class SmsCampaign {
  final String id;
  final String name;
  final String? campaignId; // linked marketing campaign
  final String message;
  final String status; // Draft | Scheduled | Sent | Failed | Cancelled
  final int recipientCount;
  final int sentCount;
  final int failedCount;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final String createdBy;
  final String providerRef;
  final List<SmsRecipient> recipients;
  final DateTime createdAt;

  const SmsCampaign({
    required this.id,
    required this.name,
    this.campaignId,
    required this.message,
    required this.status,
    required this.recipientCount,
    required this.sentCount,
    required this.failedCount,
    this.scheduledAt,
    this.sentAt,
    required this.createdBy,
    required this.providerRef,
    required this.recipients,
    required this.createdAt,
  });

  SmsCampaign copyWith({
    String? name,
    String? campaignId,
    String? message,
    String? status,
    int? recipientCount,
    int? sentCount,
    int? failedCount,
    DateTime? scheduledAt,
    DateTime? sentAt,
    String? createdBy,
    String? providerRef,
    List<SmsRecipient>? recipients,
  }) =>
      SmsCampaign(
        id: id,
        name: name ?? this.name,
        campaignId: campaignId ?? this.campaignId,
        message: message ?? this.message,
        status: status ?? this.status,
        recipientCount: recipientCount ?? this.recipientCount,
        sentCount: sentCount ?? this.sentCount,
        failedCount: failedCount ?? this.failedCount,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        sentAt: sentAt ?? this.sentAt,
        createdBy: createdBy ?? this.createdBy,
        providerRef: providerRef ?? this.providerRef,
        recipients: recipients ?? this.recipients,
        createdAt: createdAt,
      );

  double get deliveryRate =>
      recipientCount > 0 ? sentCount / recipientCount : 0.0;

  Map<String, dynamic> toRow() => {
        'id': id,
        'name': name,
        'campaign_id': campaignId,
        'message': message,
        'status': status,
        'recipient_count': recipientCount,
        'sent_count': sentCount,
        'failed_count': failedCount,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'sent_at': sentAt?.toIso8601String(),
        'created_by': createdBy,
        'provider_ref': providerRef,
        'recipients': recipients.map((r) => r.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  static SmsCampaign fromRow(Map<String, dynamic> r) => SmsCampaign(
        id: r['id']?.toString() ?? '',
        name: r['name']?.toString() ?? '',
        campaignId: r['campaign_id']?.toString(),
        message: r['message']?.toString() ?? '',
        status: r['status']?.toString() ?? 'Draft',
        recipientCount: (r['recipient_count'] as num?)?.toInt() ?? 0,
        sentCount: (r['sent_count'] as num?)?.toInt() ?? 0,
        failedCount: (r['failed_count'] as num?)?.toInt() ?? 0,
        scheduledAt: r['scheduled_at'] != null
            ? DateTime.tryParse(r['scheduled_at'].toString())
            : null,
        sentAt: r['sent_at'] != null
            ? DateTime.tryParse(r['sent_at'].toString())
            : null,
        createdBy: r['created_by']?.toString() ?? '',
        providerRef: r['provider_ref']?.toString() ?? '',
        recipients: ((r['recipients'] as List?) ?? [])
            .map((e) => SmsRecipient.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SmsCampaignRepository — Supabase-backed
// ─────────────────────────────────────────────────────────────────────────────

class SmsCampaignRepository {
  SmsCampaignRepository._();

  static const _table = 'sms_campaigns';
  static final List<SmsCampaign> _items = [];
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
        ..addAll(rows.map<SmsCampaign>(SmsCampaign.fromRow));
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'read', error: e);
    }
  }

  static List<SmsCampaign> getAll() => List.unmodifiable(_items);

  static SmsCampaign? findById(String id) {
    try {
      return _items.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static void add(SmsCampaign s) {
    _items.insert(0, s);
    _upsert(s);
  }

  static void update(SmsCampaign s) {
    final idx = _items.indexWhere((x) => x.id == s.id);
    if (idx != -1) _items[idx] = s;
    _upsert(s);
  }

  static void remove(String id) {
    _items.removeWhere((s) => s.id == id);
    _delete(id);
  }

  static String nextId() {
    if (_items.isEmpty) return 'SMS001';
    final maxNum = _items
        .map((s) => int.tryParse(s.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return 'SMS${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  static Future<void> _upsert(SmsCampaign s) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(s.toRow())
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
    }
  }

  static Future<void> _delete(String id) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.instance.client
          .from(_table)
          .delete()
          .eq('id', id)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'delete', error: e);
    }
  }
}
