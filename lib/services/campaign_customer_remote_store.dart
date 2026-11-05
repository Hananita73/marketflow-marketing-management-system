import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../core/constants.dart';
import '../models/campaign_customer.dart';
import 'admin_alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CampaignCustomerRemoteStore — Supabase data access for the campaign_customers
// junction table. Same fail-soft pattern as the other remote stores.
// ─────────────────────────────────────────────────────────────────────────────

class CampaignCustomerRemoteStore {
  CampaignCustomerRemoteStore._();

  static const String _table = 'campaign_customers';

  static Future<List<CampaignCustomer>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('added_at', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<CampaignCustomer>(_fromRow).toList();
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'read', error: e);
      return null;
    }
  }

  static Future<bool> upsert(CampaignCustomer a) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(a))
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'write', error: e);
      return false;
    }
  }

  static Future<bool> delete(String campaignId, int customerId) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .delete()
          .eq('campaign_id', campaignId)
          .eq('customer_id', customerId)
          .timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
          table: _table, operation: 'delete', error: e);
      return false;
    }
  }

  static Map<String, dynamic> _toRow(CampaignCustomer a) => {
        'campaign_id': a.campaignId,
        'customer_id': a.customerId,
        'added_at': a.assignedDate.toIso8601String(),
        'participation_status': a.participationStatus,
        'engagement_status': a.engagementStatus,
        'conversion_status': a.conversionStatus,
        'notes': a.notes,
      };

  static CampaignCustomer _fromRow(Map<String, dynamic> r) {
    DateTime parseTs(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    // 'added_at' is the assigned date; fall back to created_at.
    final assigned = r['added_at'] != null
        ? parseTs(r['added_at'])
        : (r['created_at'] != null ? parseTs(r['created_at']) : DateTime.now());
    return CampaignCustomer(
      campaignId: r['campaign_id']?.toString() ?? '',
      customerId: r['customer_id'] is int
          ? r['customer_id'] as int
          : int.tryParse(r['customer_id']?.toString() ?? '') ?? 0,
      assignedDate: assigned,
      participationStatus:
          r['participation_status']?.toString() ?? AppConstants.participationAssigned,
      engagementStatus:
          r['engagement_status']?.toString() ?? AppConstants.engagementPending,
      conversionStatus:
          r['conversion_status']?.toString() ?? AppConstants.conversionNotConverted,
      notes: r['notes']?.toString() ?? '',
      createdAt: parseTs(r['created_at']),
      updatedAt: parseTs(r['updated_at']),
    );
  }
}
