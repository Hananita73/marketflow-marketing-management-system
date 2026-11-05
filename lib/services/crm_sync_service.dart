import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/customer.dart';
import '../models/lead.dart';
import '../services/audit_log_service.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CrmSyncService
//
// Skeleton CRM integration for MarketFlow.
//
// Architecture:
//   • Reads from an external CRM API (configured via CrmConfig).
//   • Imports/updates Customer and Lead records into local repositories
//     and Supabase.
//   • Records every sync run in the `crm_sync_log` table.
//   • Handles duplicates via email uniqueness check.
//   • All calls are safe — failures are caught and logged, never thrown.
//
// To connect a real CRM:
//   1. Set CrmConfig.apiUrl and CrmConfig.apiKey in Settings → Integrations.
//   2. Map the CRM's customer/contact JSON to CrmCustomer/CrmLead below.
//   3. Call CrmSyncService.syncCustomers() and CrmSyncService.syncLeads().
// ─────────────────────────────────────────────────────────────────────────────

// ── Configuration ─────────────────────────────────────────────────────────────

class CrmConfig {
  static String apiUrl = ''; // e.g. https://api.yourcrm.com/v1
  static String apiKey = '';
  static bool get isConfigured => apiUrl.isNotEmpty && apiKey.isNotEmpty;
}

// ── Value objects from CRM ─────────────────────────────────────────────────────

class CrmCustomer {
  final String externalId;
  final String name;
  final String email;
  final String phone;
  final String segment;

  const CrmCustomer({
    required this.externalId,
    required this.name,
    required this.email,
    required this.phone,
    required this.segment,
  });

  /// Map a raw CRM API response row to this model.
  /// Adjust field names to match your CRM's actual response shape.
  static CrmCustomer fromJson(Map<String, dynamic> j) => CrmCustomer(
        externalId: j['id']?.toString() ?? '',
        name:       j['name']?.toString() ?? j['full_name']?.toString() ?? '',
        email:      j['email']?.toString() ?? '',
        phone:      j['phone']?.toString() ?? j['mobile']?.toString() ?? '',
        segment:    j['segment']?.toString() ?? j['tier']?.toString() ?? 'Retail',
      );
}

class CrmLead {
  final String externalId;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String source;
  final int score;

  const CrmLead({
    required this.externalId,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.source,
    required this.score,
  });

  static CrmLead fromJson(Map<String, dynamic> j) => CrmLead(
        externalId: j['id']?.toString() ?? '',
        name:       j['name']?.toString() ?? '',
        company:    j['company']?.toString() ?? j['organization']?.toString() ?? '',
        email:      j['email']?.toString() ?? '',
        phone:      j['phone']?.toString() ?? '',
        source:     j['source']?.toString() ?? 'CRM Import',
        score:      (j['score'] as num?)?.toInt() ?? 50,
      );
}

// ── Sync result ────────────────────────────────────────────────────────────────

class CrmSyncResult {
  final String syncType;
  final String status;       // 'success' | 'failed' | 'partial' | 'skipped'
  final int imported;
  final int updated;
  final int skipped;
  final String errorMessage;
  final DateTime runAt;

  const CrmSyncResult({
    required this.syncType,
    required this.status,
    required this.imported,
    required this.updated,
    required this.skipped,
    required this.errorMessage,
    required this.runAt,
  });

  @override
  String toString() =>
      '$syncType: $imported imported, $updated updated, $skipped skipped — $status';
}

// ── Service ────────────────────────────────────────────────────────────────────

class CrmSyncService {
  CrmSyncService._();

  // ── Customers ────────────────────────────────────────────────────────────────

  /// Imports or updates customers from the configured CRM.
  /// Returns a result summary. Never throws.
  static Future<CrmSyncResult> syncCustomers({
    List<Map<String, dynamic>>? mockData,
  }) async {
    if (!CrmConfig.isConfigured && mockData == null) {
      return CrmSyncResult(
        syncType: 'customers', status: 'skipped',
        imported: 0, updated: 0, skipped: 0,
        errorMessage: 'CRM not configured. Set API URL and key in Settings → Integrations.',
        runAt: DateTime.now(),
      );
    }

    int imported = 0, updated = 0, skipped = 0;
    String status = 'success';
    String errorMsg = '';

    try {
      // Fetch from CRM (or use provided mock data)
      final rawList = mockData ?? await _fetchFromCrm('/customers');
      final crmCustomers = rawList.map(CrmCustomer.fromJson).toList();

      final existing = CustomerRepository.getAll();
      final existingEmails = {for (final c in existing) c.email: c};

      for (final crm in crmCustomers) {
        if (crm.email.isEmpty) { skipped++; continue; }

        if (existingEmails.containsKey(crm.email)) {
          // Update existing customer
          final c = existingEmails[crm.email]!;
          final updated_ = Customer(
            id: c.id,
            name: crm.name.isNotEmpty ? crm.name : c.name,
            email: c.email,
            phone: crm.phone.isNotEmpty ? crm.phone : c.phone,
            segment: crm.segment.isNotEmpty ? crm.segment : c.segment,
            status: c.status,
            lastActivity: DateTime.now(),
            joinedAt: c.joinedAt,
            leadId: c.leadId,
            opportunityId: c.opportunityId,
            campaignId: c.campaignId,
          );
          CustomerRepository.update(updated_);
          updated++;
        } else {
          // Create new customer
          final newId  = CustomerRepository.nextId();
          final newCust = Customer(
            id: newId,
            name: crm.name,
            email: crm.email,
            phone: crm.phone,
            segment: crm.segment,
            status: 'Active',
            lastActivity: DateTime.now(),
            joinedAt: DateTime.now(),
          );
          CustomerRepository.add(newCust);
          imported++;
        }
      }
    } catch (e) {
      status = 'failed';
      errorMsg = e.toString();
      developer.log('CRM customer sync failed: $e', name: 'CrmSyncService');
    }

    final result = CrmSyncResult(
      syncType: 'customers', status: status,
      imported: imported, updated: updated, skipped: skipped,
      errorMessage: errorMsg, runAt: DateTime.now(),
    );

    await _logSync(result);
    AuditLogService.log(
      action: 'create', module: 'Customers',
      recordName: 'CRM Sync — $imported imported, $updated updated',
    );

    return result;
  }

  // ── Leads ─────────────────────────────────────────────────────────────────────

  static Future<CrmSyncResult> syncLeads({
    List<Map<String, dynamic>>? mockData,
  }) async {
    if (!CrmConfig.isConfigured && mockData == null) {
      return CrmSyncResult(
        syncType: 'leads', status: 'skipped',
        imported: 0, updated: 0, skipped: 0,
        errorMessage: 'CRM not configured.',
        runAt: DateTime.now(),
      );
    }

    int imported = 0, updated = 0, skipped = 0;
    String status = 'success';
    String errorMsg = '';

    try {
      final rawList  = mockData ?? await _fetchFromCrm('/leads');
      final crmLeads = rawList.map(CrmLead.fromJson).toList();

      final existing = LeadRepository.getAll();
      final existingEmails = {for (final l in existing) l.email: l};

      for (final crm in crmLeads) {
        if (crm.email.isEmpty) { skipped++; continue; }

        if (existingEmails.containsKey(crm.email)) {
          // Update score/source if changed
          final l = existingEmails[crm.email]!;
          LeadRepository.update(l.copyWith(
            score: crm.score > 0 ? crm.score : l.score,
            company: crm.company.isNotEmpty ? crm.company : l.company,
          ));
          updated++;
        } else {
          // Create new lead
          final newLead = Lead(
            id: LeadRepository.nextId(),
            name: crm.name,
            company: crm.company,
            email: crm.email,
            phone: crm.phone,
            source: crm.source,
            score: crm.score,
            assignedTo: AuthService().currentName,
            status: 'New',
            priority: crm.score >= 80 ? 'High' : crm.score >= 50 ? 'Medium' : 'Low',
            createdAt: DateTime.now(),
          );
          LeadRepository.add(newLead);
          imported++;
        }
      }
    } catch (e) {
      status = 'failed';
      errorMsg = e.toString();
      developer.log('CRM lead sync failed: $e', name: 'CrmSyncService');
    }

    final result = CrmSyncResult(
      syncType: 'leads', status: status,
      imported: imported, updated: updated, skipped: skipped,
      errorMessage: errorMsg, runAt: DateTime.now(),
    );

    await _logSync(result);
    return result;
  }

  // ── Sync history ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSyncHistory({int limit = 20}) async {
    if (!SupabaseConfig.isConfigured) return [];
    try {
      final rows = await Supabase.instance.client
          .from('crm_sync_log')
          .select()
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(const Duration(seconds: 8));
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      developer.log('CrmSyncService.getSyncHistory failed: $e', name: 'CrmSyncService');
      return [];
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────────

  /// Calls the configured CRM API endpoint. Override in tests with mockData.
  static Future<List<Map<String, dynamic>>> _fetchFromCrm(String path) async {
    // HTTP call to CRM API.
    // Replace with actual http.get() when CrmConfig is configured.
    // Example:
    //   final response = await http.get(
    //     Uri.parse('${CrmConfig.apiUrl}$path'),
    //     headers: {'Authorization': 'Bearer ${CrmConfig.apiKey}'},
    //   ).timeout(const Duration(seconds: 15));
    //   if (response.statusCode == 200) {
    //     return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    //   }
    //   throw Exception('CRM API error ${response.statusCode}');
    return []; // No real CRM configured — return empty list safely
  }

  static Future<void> _logSync(CrmSyncResult r) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await Supabase.instance.client.from('crm_sync_log').insert({
        'sync_type':        r.syncType,
        'status':           r.status,
        'records_imported': r.imported,
        'records_updated':  r.updated,
        'records_skipped':  r.skipped,
        'error_message':    r.errorMessage,
        'triggered_by':     AuthService().currentName,
        'created_at':       r.runAt.toIso8601String(),
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      developer.log('CrmSyncService._logSync failed: $e', name: 'CrmSyncService');
    }
  }
}
