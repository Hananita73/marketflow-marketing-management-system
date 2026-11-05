import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'admin_alert_service.dart';
import '../models/budget.dart';
import '../models/content_item.dart';
import '../models/customer.dart';
import '../models/influencer.dart';
import '../models/lead.dart';
import '../models/opportunity.dart';
import '../models/promotion.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entity remote stores
//
// Supabase data access for the Customers, Leads and Opportunities modules —
// same architecture as CampaignRemoteService:
//
//   Repository (sync, in-memory)  ← screens keep working unchanged
//            │  fire-and-forget writes / awaited initial load
//            ▼
//   Remote store (async, this file)
//            ▼
//   Supabase table
//
// Every call fails soft: when Supabase is not configured or unreachable the
// methods return null/false instead of throwing, so the app degrades to
// local-only mode automatically.
// ─────────────────────────────────────────────────────────────────────────────

// ═════════════════════════════════════════════════════════════════════════════
// Customers
// ═════════════════════════════════════════════════════════════════════════════

class CustomerRemoteStore {
  CustomerRemoteStore._();

  static const String _table = 'customers';

  static Future<List<Customer>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<Customer>(_fromRow).toList();
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<bool> upsert(Customer c) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(c))
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

  static Future<bool> delete(int id) async {
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

  static Future<bool> seed(List<Customer> list) async {
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

  static Map<String, dynamic> _toRow(Customer c) => {
    'id': c.id,
    'name': c.name,
    'company': c.company,
    'email': c.email,
    'phone': c.phone,
    'segment': c.segment,
    'status': c.status,
    'last_activity': _dateToDb(c.lastActivity),
    'joined_at': _dateToDb(c.joinedAt),
    'lead_id': c.leadId,
    'opportunity_id': c.opportunityId,
    'campaign_id': c.campaignId,
  };

  static Customer _fromRow(Map<String, dynamic> r) => Customer(
    id: _toInt(r['id']),
    name: r['name']?.toString() ?? '',
    company: r['company']?.toString() ?? '',
    email: r['email']?.toString() ?? '',
    phone: r['phone']?.toString() ?? '',
    segment: r['segment']?.toString() ?? 'Retail',
    status: r['status']?.toString() ?? 'Active',
    lastActivity: _dateFromDb(r['last_activity']) ?? DateTime.now(),
    joinedAt: _dateFromDb(r['joined_at']) ?? DateTime.now(),
    leadId: r['lead_id']?.toString() ?? '',
    opportunityId: r['opportunity_id']?.toString() ?? '',
    campaignId: r['campaign_id']?.toString() ?? '',
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Leads
// ═════════════════════════════════════════════════════════════════════════════

class LeadRemoteStore {
  LeadRemoteStore._();

  static const String _table = 'leads';

  static Future<List<Lead>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<Lead>(_fromRow).toList();
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<bool> upsert(Lead l) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(l))
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

  static Future<bool> delete(int id) async {
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

  static Future<bool> seed(List<Lead> list) async {
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

  static Map<String, dynamic> _toRow(Lead l) => {
    'id': l.id,
    'name': l.name,
    'company': l.company,
    'email': l.email,
    'phone': l.phone,
    'source': l.source,
    'score': l.score,
    'assigned_to': l.assignedTo,
    'assigned_campaign_id': l.assignedCampaignId,
    'status': l.status,
    'priority': l.priority,
    'created_at': _dateToDb(l.createdAt),
  };

  static Lead _fromRow(Map<String, dynamic> r) => Lead(
    id: _toInt(r['id']),
    name: r['name']?.toString() ?? '',
    company: r['company']?.toString() ?? '',
    email: r['email']?.toString() ?? '',
    phone: r['phone']?.toString() ?? '',
    source: r['source']?.toString() ?? 'Website',
    score: _toInt(r['score']),
    assignedTo: r['assigned_to']?.toString() ?? '',
    assignedCampaignId: r['assigned_campaign_id']?.toString() ?? '',
    status: r['status']?.toString() ?? 'New',
    priority: r['priority']?.toString() ?? 'Medium',
    createdAt: _dateFromDb(r['created_at']) ?? DateTime.now(),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Opportunities
// ═════════════════════════════════════════════════════════════════════════════

class OpportunityRemoteStore {
  OpportunityRemoteStore._();

  static const String _table = 'opportunities';

  static Future<List<Opportunity>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      final opportunities = rows.map<Opportunity>(_fromRow).toList();
      try {
        final followerRows = await Supabase.instance.client
            .from('opportunity_followers')
            .select('opportunity_id, user_id, user_name')
            .timeout(const Duration(seconds: 6));
        final followers = <int, List<Map<String, String>>>{};
        for (final row in followerRows as List) {
          final item = Map<String, dynamic>.from(row as Map);
          final id = _toInt(item['opportunity_id']);
          followers.putIfAbsent(id, () => []).add({
            'id': item['user_id']?.toString() ?? '',
            'name': item['user_name']?.toString() ?? '',
          });
        }
        return opportunities.map((opportunity) {
          final items =
              followers[opportunity.id] ?? const <Map<String, String>>[];
          return opportunity.copyWith(
            followerIds: items
                .map((item) => item['id'] ?? '')
                .where((id) => id.isNotEmpty)
                .toList(),
            followerNames: items
                .map((item) => item['name'] ?? '')
                .where((name) => name.isNotEmpty)
                .toList(),
          );
        }).toList();
      } catch (_) {
        // The additive follower migration may not be applied yet. The base
        // opportunities remain readable while the app is upgraded.
        return opportunities;
      }
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAssignableUsers() async {
    if (!SupabaseConfig.isConfigured) return const [];
    try {
      final rows = await Supabase.instance.client
          .rpc('list_opportunity_users')
          .timeout(const Duration(seconds: 6));
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (e) {
      AdminAlertService.reportStoreFailure(
        table: 'users',
        operation: 'read',
        error: e,
      );
      return const [];
    }
  }

  static Future<bool> upsert(Opportunity o) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(o))
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

  static Future<bool> save(
    Opportunity opportunity, {
    String? progressNote,
    List<Map<String, String>> followers = const [],
  }) async {
    if (!await upsert(opportunity)) return false;
    if (!await syncFollowers(opportunity.id, followers)) return false;
    if (progressNote != null && progressNote.trim().isNotEmpty) {
      if (!await addProgress(opportunity, progressNote.trim())) return false;
    }
    return true;
  }

  static Future<bool> syncFollowers(
    int opportunityId,
    List<Map<String, String>> followers,
  ) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from('opportunity_followers')
          .delete()
          .eq('opportunity_id', opportunityId);
      if (followers.isEmpty) return true;
      await Supabase.instance.client
          .from('opportunity_followers')
          .insert(
            followers
                .map(
                  (follower) => {
                    'opportunity_id': opportunityId,
                    'user_id': follower['id'],
                    'user_name': follower['name'] ?? '',
                  },
                )
                .toList(),
          );
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
        table: 'opportunity_followers',
        operation: 'write',
        error: e,
      );
      return false;
    }
  }

  static Future<bool> addProgress(Opportunity opportunity, String note) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.from('opportunity_progress').insert({
        'opportunity_id': opportunity.id,
        'note': note,
        'stage': opportunity.stage,
        'value': opportunity.value,
        'probability': opportunity.probability,
        'changed_by_name': opportunity.lastProgressBy,
      });
      return true;
    } catch (e) {
      AdminAlertService.reportStoreFailure(
        table: 'opportunity_progress',
        operation: 'write',
        error: e,
      );
      return false;
    }
  }

  static Future<List<OpportunityProgress>> fetchProgress(
    int opportunityId,
  ) async {
    if (!SupabaseConfig.isConfigured) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('opportunity_progress')
          .select()
          .eq('opportunity_id', opportunityId)
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 6));
      return (rows as List).map((row) {
        final item = Map<String, dynamic>.from(row as Map);
        return OpportunityProgress(
          id: _toInt(item['id']),
          opportunityId: _toInt(item['opportunity_id']),
          note: item['note']?.toString() ?? '',
          stage: item['stage']?.toString() ?? 'New',
          value: _toDouble(item['value']),
          probability: _toInt(item['probability']),
          changedByName: item['changed_by_name']?.toString() ?? '',
          createdAt: _dateFromDb(item['created_at']) ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      AdminAlertService.reportStoreFailure(
        table: 'opportunity_progress',
        operation: 'read',
        error: e,
      );
      rethrow;
    }
  }

  static Future<bool> delete(int id) async {
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

  static Future<bool> seed(List<Opportunity> list) async {
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

  static Map<String, dynamic> _toRow(Opportunity o) => {
    'id': o.id,
    'name': o.name,
    'company': o.company,
    'value': o.value,
    'owner': o.owner,
    'probability': o.probability,
    'stage': o.stage,
    'created_at': _dateToDb(o.createdAt),
    'lead_id': o.leadId,
    'customer_id': o.customerId,
    'created_by': o.createdBy ?? Supabase.instance.client.auth.currentUser?.id,
    'last_progress': o.lastProgress,
    'last_progress_at': o.lastProgressAt?.toIso8601String(),
    'last_progress_by': o.lastProgressBy,
  };

  static Opportunity _fromRow(Map<String, dynamic> r) => Opportunity(
    id: _toInt(r['id']),
    name: r['name']?.toString() ?? '',
    company: r['company']?.toString() ?? '',
    value: _toDouble(r['value']),
    owner: r['owner']?.toString() ?? '',
    probability: _toInt(r['probability']),
    stage: r['stage']?.toString() ?? 'New',
    leadId: r['lead_id']?.toString() ?? '',
    customerId: r['customer_id']?.toString() ?? '',
    createdAt: _dateFromDb(r['created_at']) ?? DateTime.now(),
    createdBy: r['created_by']?.toString(),
    lastProgress: r['last_progress']?.toString() ?? '',
    lastProgressAt: _dateFromDb(r['last_progress_at']),
    lastProgressBy: r['last_progress_by']?.toString() ?? '',
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Budgets
// ═════════════════════════════════════════════════════════════════════════════

class BudgetRemoteStore {
  BudgetRemoteStore._();

  static const String _table = 'budgets';

  static Future<List<Budget>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<Budget>(_fromRow).toList();
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<bool> upsert(Budget b) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(b))
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

  static Future<bool> seed(List<Budget> list) async {
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

  static Map<String, dynamic> _toRow(Budget b) => {
    'id': b.id,
    'name': b.name,
    'category': b.category,
    'allocated': b.allocated,
    'spent': b.spent,
    'start_date': _dateToDb(b.startDate),
    'end_date': _dateToDb(b.endDate),
    'description': b.description,
    'status': b.status,
    'last_updated': _dateToDb(b.lastUpdated),
    'campaign_id': b.campaignId,
  };

  static Budget _fromRow(Map<String, dynamic> r) => Budget(
    id: r['id']?.toString() ?? '',
    name: r['name']?.toString() ?? '',
    category: r['category']?.toString() ?? 'Other',
    allocated: _toDouble(r['allocated']),
    spent: _toDouble(r['spent']),
    startDate: _dateFromDb(r['start_date']) ?? DateTime.now(),
    endDate: _dateFromDb(r['end_date']) ?? DateTime.now(),
    description: r['description']?.toString() ?? '',
    status: r['status']?.toString() ?? 'Active',
    lastUpdated: _dateFromDb(r['last_updated']) ?? DateTime.now(),
    campaignId: r['campaign_id'] == null
        ? null
        : (r['campaign_id'].toString().isEmpty
              ? null
              : r['campaign_id'].toString()),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Promotions
// ═════════════════════════════════════════════════════════════════════════════

class PromotionRemoteStore {
  PromotionRemoteStore._();

  static const String _table = 'promotions';

  static Future<List<Promotion>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<Promotion>(_fromRow).toList();
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<bool> upsert(Promotion p) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(p))
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

  static Future<bool> seed(List<Promotion> list) async {
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

  static Map<String, dynamic> _toRow(Promotion p) => {
    'id': p.id,
    'name': p.name,
    'type': p.type,
    'discount': p.discount,
    'discount_value': p.discountValue,
    'start_date': _dateToDb(p.startDate),
    'end_date': _dateToDb(p.endDate),
    'usage_limit': p.usageLimit,
    'used_count': p.usedCount,
    'status': p.status,
    'campaign_name': p.campaignName,
    'coupon_codes': p.couponCodes,
  };

  static Promotion _fromRow(Map<String, dynamic> r) => Promotion(
    id: r['id']?.toString() ?? '',
    name: r['name']?.toString() ?? '',
    type: r['type']?.toString() ?? 'Percentage',
    discount: r['discount']?.toString() ?? '',
    discountValue: _toDouble(r['discount_value']),
    startDate: _dateFromDb(r['start_date']) ?? DateTime.now(),
    endDate: _dateFromDb(r['end_date']) ?? DateTime.now(),
    usageLimit: _toInt(r['usage_limit']),
    usedCount: _toInt(r['used_count']),
    status: r['status']?.toString() ?? 'Active',
    campaignName: r['campaign_name']?.toString() ?? '',
    couponCodes: ((r['coupon_codes'] as List?) ?? const [])
        .map((c) => c.toString())
        .toList(),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Influencers
// ═════════════════════════════════════════════════════════════════════════════

class InfluencerRemoteStore {
  InfluencerRemoteStore._();

  static const String _table = 'influencers';

  static Future<List<Influencer>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<Influencer>(_fromRow).toList();
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<bool> upsert(Influencer i) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(i))
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

  static Future<bool> seed(List<Influencer> list) async {
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

  static Map<String, dynamic> _toRow(Influencer i) => {
    'id': i.id,
    'name': i.name,
    'handle': i.handle,
    'platform': i.platform,
    'followers': i.followers,
    'engagement_rate': i.engagementRate,
    'category': i.category,
    'status': i.status,
    'cost_per_post': i.costPerPost,
    'campaign_name': i.campaignName,
    'avatar_initials': i.avatarInitials,
  };

  static Influencer _fromRow(Map<String, dynamic> r) => Influencer(
    id: r['id']?.toString() ?? '',
    name: r['name']?.toString() ?? '',
    handle: r['handle']?.toString() ?? '',
    platform: r['platform']?.toString() ?? 'Instagram',
    followers: _toInt(r['followers']),
    engagementRate: _toDouble(r['engagement_rate']),
    category: r['category']?.toString() ?? 'General',
    status: r['status']?.toString() ?? 'Active',
    costPerPost: _toDouble(r['cost_per_post']),
    campaignName: r['campaign_name']?.toString() ?? '',
    avatarInitials: r['avatar_initials']?.toString() ?? '',
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Content items
// ═════════════════════════════════════════════════════════════════════════════

class ContentRemoteStore {
  ContentRemoteStore._();

  static const String _table = 'content_items';

  static Future<List<ContentItem>?> fetchAll() async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));
      return rows.map<ContentItem>(_fromRow).toList();
    } catch (e) {
      // Supabase is configured but unreachable/broken — tell the admin.
      AdminAlertService.reportStoreFailure(
        table: _table,
        operation: 'read',
        error: e,
      );
      return null;
    }
  }

  static Future<bool> upsert(ContentItem c) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client
          .from(_table)
          .upsert(_toRow(c))
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

  static Future<bool> seed(List<ContentItem> list) async {
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

  static Map<String, dynamic> _toRow(ContentItem c) => {
    'id': c.id,
    'title': c.title,
    'type': c.type,
    'channel': c.channel,
    'creator': c.creator,
    'status': c.status,
    'scheduled_date': _dateToDb(c.scheduledDate),
    'campaign_name': c.campaignName,
    'description': c.description,
    'views': c.views,
    'clicks': c.clicks,
  };

  static ContentItem _fromRow(Map<String, dynamic> r) => ContentItem(
    id: r['id']?.toString() ?? '',
    title: r['title']?.toString() ?? '',
    type: r['type']?.toString() ?? 'Blog Post',
    channel: r['channel']?.toString() ?? 'Website',
    creator: r['creator']?.toString() ?? '',
    status: r['status']?.toString() ?? 'Draft',
    scheduledDate: _dateFromDb(r['scheduled_date']) ?? DateTime.now(),
    campaignName: r['campaign_name']?.toString() ?? '',
    description: r['description']?.toString() ?? '',
    views: _toInt(r['views']),
    clicks: _toInt(r['clicks']),
  );
}

// ── Shared primitive coercion helpers ────────────────────────────────────────
// PostgREST may deliver numeric/date columns as int, double, String or null
// depending on column type.

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

DateTime? _dateFromDb(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return DateTime.tryParse(s.isEmpty ? '' : s);
}

String? _dateToDb(DateTime? d) => d == null
    ? null
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
