import '../services/entity_remote_stores.dart';
import '../config/supabase_config.dart';

class OpportunityProgress {
  final int id;
  final int opportunityId;
  final String note;
  final String stage;
  final double value;
  final int probability;
  final String changedByName;
  final DateTime createdAt;

  const OpportunityProgress({
    required this.id,
    required this.opportunityId,
    required this.note,
    required this.stage,
    required this.value,
    required this.probability,
    required this.changedByName,
    required this.createdAt,
  });
}

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
  final String? createdBy;
  final String lastProgress;
  final DateTime? lastProgressAt;
  final String lastProgressBy;
  final List<String> followerIds;
  final List<String> followerNames;

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
    this.createdBy,
    this.lastProgress = '',
    this.lastProgressAt,
    this.lastProgressBy = '',
    this.followerIds = const [],
    this.followerNames = const [],
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
    String? createdBy,
    String? lastProgress,
    DateTime? lastProgressAt,
    String? lastProgressBy,
    List<String>? followerIds,
    List<String>? followerNames,
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
      createdBy: createdBy ?? this.createdBy,
      lastProgress: lastProgress ?? this.lastProgress,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      lastProgressBy: lastProgressBy ?? this.lastProgressBy,
      followerIds: followerIds ?? this.followerIds,
      followerNames: followerNames ?? this.followerNames,
    );
  }

  String get followersLabel =>
      followerNames.isNotEmpty ? followerNames.join(', ') : owner;
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
  static final Map<int, List<OpportunityProgress>> _localProgress = {};

  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await OpportunityRemoteStore.fetchAll();
    if (remote == null) return;
    // RLS can legitimately return no visible rows for users who are not
    // opportunity creators, followers, or view-all administrators. Never
    // mistake that scoped result for an empty table and try to insert demo
    // records through the authenticated client.
    _opportunities
      ..clear()
      ..addAll(remote);
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

  static Future<bool> save(
    Opportunity opportunity, {
    String? progressNote,
    List<Map<String, String>> followers = const [],
  }) async {
    if (SupabaseConfig.isConfigured &&
        !await OpportunityRemoteStore.save(
          opportunity,
          progressNote: progressNote,
          followers: followers,
        )) {
      return false;
    }
    final idx = _opportunities.indexWhere((o) => o.id == opportunity.id);
    if (idx == -1) {
      _opportunities.add(opportunity);
    } else {
      _opportunities[idx] = opportunity;
    }
    if (progressNote != null && progressNote.trim().isNotEmpty) {
      final progress = OpportunityProgress(
        id: DateTime.now().microsecondsSinceEpoch,
        opportunityId: opportunity.id,
        note: progressNote.trim(),
        stage: opportunity.stage,
        value: opportunity.value,
        probability: opportunity.probability,
        changedByName: opportunity.lastProgressBy,
        createdAt: DateTime.now(),
      );
      _localProgress.putIfAbsent(opportunity.id, () => []).insert(0, progress);
    }
    return true;
  }

  static Future<List<OpportunityProgress>> fetchProgress(int opportunityId) =>
      SupabaseConfig.isConfigured
      ? OpportunityRemoteStore.fetchProgress(opportunityId)
      : Future.value(
          List<OpportunityProgress>.from(
            _localProgress[opportunityId] ?? const [],
          ),
        );

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
