import '../core/constants.dart';
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
    required this.createdAt,
    required this.updatedAt,
  });

  CampaignCustomer copyWith({
    DateTime? assignedDate,
    String? participationStatus,
    String? engagementStatus,
    String? conversionStatus,
    String? notes,
    DateTime? updatedAt,
  }) =>
      CampaignCustomer(
        campaignId: campaignId,
        customerId: customerId,
        assignedDate: assignedDate ?? this.assignedDate,
        participationStatus: participationStatus ?? this.participationStatus,
        engagementStatus: engagementStatus ?? this.engagementStatus,
        conversionStatus: conversionStatus ?? this.conversionStatus,
        notes: notes ?? this.notes,
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
  static bool isAssigned(String campaignId, int customerId) =>
      _items.any((a) => a.campaignId == campaignId && a.customerId == customerId);

  /// Creates the customer ↔ campaign association. Returns false (without
  /// duplicating) when the assignment already exists.
  static bool assign(CampaignCustomer assoc) {
    if (isAssigned(assoc.campaignId, assoc.customerId)) return false;
    _items.add(assoc);
    CampaignCustomerRemoteStore.upsert(assoc).then((_) {}).onError((_, _) {});
    return true;
  }

  /// Updates an existing association (e.g. change participation status).
  static void update(CampaignCustomer assoc) {
    final idx = _items.indexWhere(
        (a) => a.campaignId == assoc.campaignId && a.customerId == assoc.customerId);
    if (idx != -1) {
      _items[idx] = assoc;
      CampaignCustomerRemoteStore.upsert(assoc).then((_) {}).onError((_, _) {});
    }
  }

  /// Removes ONLY the association (the customer record itself is preserved).
  static void remove(String campaignId, int customerId) {
    _items.removeWhere(
        (a) => a.campaignId == campaignId && a.customerId == customerId);
    CampaignCustomerRemoteStore.delete(campaignId, customerId)
        .then((_) {})
        .onError((_, _) {});
  }
}
