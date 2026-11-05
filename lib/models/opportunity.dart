import '../services/entity_remote_stores.dart';

class Opportunity {
  final int id;
  final String name;
  final String company;
  final double value;
  final String owner;
  final int probability;
  final String stage;
  final String? leadId;
  final String? customerId;
  final DateTime createdAt;

  const Opportunity({
    required this.id,
    required this.name,
    required this.company,
    required this.value,
    required this.owner,
    required this.probability,
    required this.stage,
    this.leadId,
    this.customerId,
    required this.createdAt,
  });

  /// Creates a copy of this Opportunity with the given fields replaced.
  /// Preserves leadId and customerId unless explicitly overridden.
  Opportunity copyWith({
    int? id,
    String? name,
    String? company,
    double? value,
    String? owner,
    int? probability,
    String? stage,
    String? leadId,
    String? customerId,
    DateTime? createdAt,
  }) {
    return Opportunity(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      value: value ?? this.value,
      owner: owner ?? this.owner,
      probability: probability ?? this.probability,
      stage: stage ?? this.stage,
      leadId: leadId ?? this.leadId,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class OpportunityRepository {
  OpportunityRepository._();

  static final List<Opportunity> _opportunities = [
    Opportunity(
      id: 1,
      name: 'Summer Campaign Package',
      company: 'TechWave Inc.',
      value: 45000,
      owner: 'Hana Tsegaye',
      probability: 80,
      stage: 'Proposal',
      createdAt: DateTime(2026, 5, 1),
    ),
    Opportunity(
      id: 2,
      name: 'Winter Retention Deal',
      company: 'GreenLeaf Co.',
      value: 28000,
      owner: 'Daniel Girma',
      probability: 65,
      stage: 'Negotiation',
      createdAt: DateTime(2026, 4, 15),
    ),
    Opportunity(
      id: 3,
      name: 'Q3 Expansion Opportunity',
      company: 'Global Retail',
      value: 75000,
      owner: 'Meron Tadesse',
      probability: 70,
      stage: 'Proposal',
      createdAt: DateTime(2026, 5, 10),
    ),
  ];

  static bool _initialized = false;

  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await OpportunityRemoteStore.fetchAll();
    if (remote == null) return;
    if (remote.isEmpty) {
      await OpportunityRemoteStore.seed(_opportunities);
    } else {
      _opportunities ..clear() ..addAll(remote);
    }
  }

  static List<Opportunity> getAll() => List<Opportunity>.from(_opportunities);

  static Opportunity? findById(int id) {
    try {
      return _opportunities.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  static void add(Opportunity opportunity) {
    _opportunities.add(opportunity);
    OpportunityRemoteStore.upsert(opportunity)
      .then((_) {
        // Opportunity persisted to database
      })
      .onError((_, _) {
        // Failed to persist - running in offline mode, local data remains valid
      });
  }

  static void update(Opportunity updated) {
    final idx = _opportunities.indexWhere((o) => o.id == updated.id);
    if (idx != -1) {
      _opportunities[idx] = updated;
      OpportunityRemoteStore.upsert(updated)
        .then((_) {
          // Opportunity persisted to database
        })
        .onError((_, _) {
          // Failed to persist - running in offline mode, local data remains valid
        });
    }
  }

  /// Updates only the stage of an opportunity, preserving all other fields
  /// including leadId and customerId (fixes data-loss bug where updateStage
  /// previously dropped relationship FKs).
  static void updateStage(int id, String newStage) {
    final opp = findById(id);
    if (opp == null) return;
    final updated = opp.copyWith(stage: newStage);
    update(updated);
  }

  static void remove(int id) {
    _opportunities.removeWhere((o) => o.id == id);
    OpportunityRemoteStore.delete(id); // fire-and-forget sync
  }

  static int nextId() {
    if (_opportunities.isEmpty) return 1;
    return _opportunities.map((o) => o.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}
