import '../config/supabase_config.dart';
import '../core/constants.dart';
import 'customer.dart';
import '../services/campaign_customer_remote_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CampaignCustomer — junction record linking a Customer to a Campaign.
//
// Implements the many-to-many relationship: one campaign can have many
// customers and one customer can participate in multiple campaigns. The
// composite key (campaignId, customerId) guarantees no duplicate assignments.
// Each association carries its own participation metadata, so the same
// customer is tracked independently in every campaign they join.
// ─────────────────────────────────────────────────────────────────────────────

class CampaignCustomer {
  final String campaignId;
  final int customerId;
  final DateTime assignedDate;
  final String participationStatus;
  final String engagementStatus;
  final String conversionStatus;
  final String notes;
  final double allocatedAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CampaignCustomer({
    required this.campaignId,
    required this.customerId,
    required this.assignedDate,
    this.participationStatus = AppConstants.participationAssigned,
    this.engagementStatus = AppConstants.engagementPending,
    this.conversionStatus = AppConstants.conversionNotConverted,
    this.notes = '',
    this.allocatedAmount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  CampaignCustomer copyWith({
    DateTime? assignedDate,
    String? participationStatus,
    String? engagementStatus,
    String? conversionStatus,
    String? notes,
    double? allocatedAmount,
    DateTime? updatedAt,
  }) => CampaignCustomer(
    campaignId: campaignId,
    customerId: customerId,
    assignedDate: assignedDate ?? this.assignedDate,
    participationStatus: participationStatus ?? this.participationStatus,
    engagementStatus: engagementStatus ?? this.engagementStatus,
    conversionStatus: conversionStatus ?? this.conversionStatus,
    notes: notes ?? this.notes,
    allocatedAmount: allocatedAmount ?? this.allocatedAmount,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CampaignCustomerRepository — in-memory store + Supabase sync.
// Same architecture as CustomerRepository / BudgetRepository: screens call the
// sync methods; writes are fire-and-forget to the remote store.
// ─────────────────────────────────────────────────────────────────────────────

class CampaignCustomerRepository {
  CampaignCustomerRepository._();

  static final List<CampaignCustomer> _items = [];
  static bool _initialized = false;

  /// Loads associations from Supabase once at startup (called from main.dart).
  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await CampaignCustomerRemoteStore.fetchAll();
    if (remote == null) return; // offline — keep empty list
    _items
      ..clear()
      ..addAll(remote);
  }

  static List<CampaignCustomer> getAll() => List<CampaignCustomer>.from(_items);

  /// All associations for a campaign (the customers assigned to it).
  static List<CampaignCustomer> getByCampaign(String campaignId) =>
      _items.where((a) => a.campaignId == campaignId).toList();

  /// All associations for a customer (the campaigns a customer belongs to).
  static List<CampaignCustomer> getByCustomer(int customerId) =>
      _items.where((a) => a.customerId == customerId).toList();

  /// True when the customer is already assigned to the campaign.
  static bool isAssigned(String campaignId, int customerId) => _items.any(
    (a) => a.campaignId == campaignId && a.customerId == customerId,
  );

  static double allocatedForCompany(String campaignId, String company) =>
      _items
          .where((assignment) => assignment.campaignId == campaignId)
          .where((assignment) {
            final customer = CustomerRepository.findById(assignment.customerId);
            if (customer == null) return false;
            final companyName = customer.company.trim().isEmpty
                ? customer.name.trim()
                : customer.company.trim();
            return companyName == company;
          })
          .fold(0, (total, assignment) => total + assignment.allocatedAmount);

  /// Creates the customer ↔ campaign association. Returns false (without
  /// duplicating) when the assignment already exists.
  static Future<bool> assign(CampaignCustomer assoc) async {
    if (isAssigned(assoc.campaignId, assoc.customerId)) return false;
    if (SupabaseConfig.isConfigured &&
        !await CampaignCustomerRemoteStore.upsert(assoc)) {
      return false;
    }
    if (isAssigned(assoc.campaignId, assoc.customerId)) return false;
    _items.add(assoc);
    return true;
  }

  /// Updates an existing association (e.g. change participation status).
  static Future<bool> update(CampaignCustomer assoc) async {
    final idx = _items.indexWhere(
      (a) =>
          a.campaignId == assoc.campaignId && a.customerId == assoc.customerId,
    );
    if (idx == -1) return false;
    if (SupabaseConfig.isConfigured &&
        !await CampaignCustomerRemoteStore.upsert(assoc)) {
      return false;
    }
    _items[idx] = assoc;
    return true;
  }

  /// Removes ONLY the association (the customer record itself is preserved).
  static Future<bool> remove(String campaignId, int customerId) async {
    final exists = isAssigned(campaignId, customerId);
    if (!exists) return false;
    if (SupabaseConfig.isConfigured &&
        !await CampaignCustomerRemoteStore.delete(campaignId, customerId)) {
      return false;
    }
    _items.removeWhere(
      (a) => a.campaignId == campaignId && a.customerId == customerId,
    );
    return true;
  }
}

class CampaignBudgetMath {
  const CampaignBudgetMath._();

  static double remaining(double allocated, double spent) =>
      (allocated - spent).clamp(0, double.infinity);

  static bool canRecordExpense({
    required double allocated,
    required double alreadySpent,
    required double expenseAmount,
  }) =>
      expenseAmount > 0 &&
      allocated >= 0 &&
      alreadySpent >= 0 &&
      alreadySpent + expenseAmount <= allocated;
}
