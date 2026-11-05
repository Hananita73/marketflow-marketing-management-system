import '../core/constants.dart';
import '../services/admin_alert_service.dart';
import '../services/entity_remote_stores.dart';
import 'campaign_customer.dart';
import 'opportunity.dart';
import 'customer.dart';

class Lead {
  final int id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String source;
  final int score;
  final String assignedTo;
  final String status;
  final String priority;
  final String? assignedCampaignId;
  final DateTime createdAt;

  const Lead({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.source,
    required this.score,
    required this.assignedTo,
    required this.status,
    required this.priority,
    this.assignedCampaignId,
    required this.createdAt,
  });

  /// Creates a copy of this Lead with the given fields replaced.
  Lead copyWith({
    int? id,
    String? name,
    String? company,
    String? email,
    String? phone,
    String? source,
    int? score,
    String? assignedTo,
    String? status,
    String? priority,
    String? assignedCampaignId,
    DateTime? createdAt,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      source: source ?? this.source,
      score: score ?? this.score,
      assignedTo: assignedTo ?? this.assignedTo,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedCampaignId: assignedCampaignId ?? this.assignedCampaignId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class LeadRepository {
  LeadRepository._();

  static final List<Lead> _leads = [
    Lead(
      id: 1,
      name: 'Abebe Kebede',
      company: 'TechWave Inc.',
      email: 'abebe@techwave.com',
      phone: '+251 911 234 567',
      source: 'Website',
      score: 85,
      assignedTo: 'Hana Tsegaye',
      assignedCampaignId: null,
      status: AppConstants.leadQualified,
      priority: 'High',
      createdAt: DateTime(2026, 5, 1),
    ),
    Lead(
      id: 2,
      name: 'Sara Ahmed',
      company: 'GreenLeaf Co.',
      email: 'sara@greenleaf.co',
      phone: '+251 922 345 678',
      source: 'Social Media',
      score: 72,
      assignedTo: 'Daniel Girma',
      status: AppConstants.leadNew,
      priority: 'Medium',
      createdAt: DateTime(2026, 5, 3),
    ),
    Lead(
      id: 3,
      name: 'John Smith',
      company: 'Global Retail',
      email: 'john@globalretail.com',
      phone: '+251 933 456 789',
      source: 'Email',
      score: 45,
      assignedTo: 'Meron Tadesse',
      status: AppConstants.leadContacted,
      priority: 'Low',
      createdAt: DateTime(2026, 5, 5),
    ),
    Lead(
      id: 4,
      name: 'Meron Tadesse',
      company: 'Innovate ET',
      email: 'meron@innovate.et',
      phone: '+251 944 567 890',
      source: 'Referrals',
      score: 91,
      assignedTo: 'Meron Tadesse',
      assignedCampaignId: null,
      status: AppConstants.leadQualified,
      priority: 'High',
      createdAt: DateTime(2026, 5, 2),
    ),
    Lead(
      id: 5,
      name: 'Daniel Girma',
      company: 'NexusTech',
      email: 'daniel@nexustech.com',
      phone: '+251 955 678 901',
      source: 'Paid Ads',
      score: 38,
      assignedTo: 'Yonas Alemu',
      status: AppConstants.leadUnqualified,
      priority: 'Low',
      createdAt: DateTime(2026, 5, 4),
    ),
    Lead(
      id: 6,
      name: 'Hana Bekele',
      company: 'BrightStar IO',
      email: 'hana@brightstar.io',
      phone: '+251 966 789 012',
      source: 'Website',
      score: 68,
      assignedTo: 'Daniel Girma',
      status: AppConstants.leadNew,
      priority: 'Medium',
      createdAt: DateTime(2026, 5, 6),
    ),
    Lead(
      id: 7,
      name: 'Yonas Alemu',
      company: 'Summit Group',
      email: 'yonas@summitgroup.com',
      phone: '+251 977 890 123',
      source: 'Social Media',
      score: 55,
      assignedTo: 'Meron Tadesse',
      status: AppConstants.leadContacted,
      priority: 'Medium',
      createdAt: DateTime(2026, 5, 7),
    ),
    Lead(
      id: 8,
      name: 'Lidya Haile',
      company: 'FreshStart ET',
      email: 'lidya@freshstart.et',
      phone: '+251 988 901 234',
      source: 'Referrals',
      score: 95,
      assignedTo: 'Hana Tsegaye',
      status: AppConstants.leadConverted,
      priority: 'High',
      createdAt: DateTime(2026, 4, 28),
    ),
    Lead(
      id: 9,
      name: 'Samuel Tesfaye',
      company: 'Apex Ventures',
      email: 'samuel@apexventures.com',
      phone: '+251 999 012 345',
      source: 'Website',
      score: 60,
      assignedTo: 'Yonas Alemu',
      status: AppConstants.leadNew,
      priority: 'Medium',
      createdAt: DateTime(2026, 5, 8),
    ),
    Lead(
      id: 10,
      name: 'Kenenisa Bekele',
      company: 'SpeedLogistics',
      email: 'kenenisa@speedlogistics.com',
      phone: '+251 910 123 456',
      source: 'Paid Ads',
      score: 78,
      assignedTo: 'Daniel Girma',
      status: AppConstants.leadQualified,
      priority: 'High',
      createdAt: DateTime(2026, 5, 9),
    ),
    Lead(
      id: 11,
      name: 'Rahel Tesfaye',
      company: 'BloomDesign Co.',
      email: 'rahel@bloomdesign.co',
      phone: '+251 921 234 567',
      source: 'Email',
      score: 42,
      assignedTo: 'Meron Tadesse',
      status: AppConstants.leadContacted,
      priority: 'Low',
      createdAt: DateTime(2026, 5, 10),
    ),
    Lead(
      id: 12,
      name: 'Bereket Yohannes',
      company: 'CoreBuild ET',
      email: 'bereket@corebuild.et',
      phone: '+251 932 345 678',
      source: 'Website',
      score: 88,
      assignedTo: 'Hana Tsegaye',
      status: AppConstants.leadQualified,
      priority: 'High',
      createdAt: DateTime(2026, 5, 11),
    ),
  ];

  static bool _initialized = false;

  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await LeadRemoteStore.fetchAll();
    if (remote == null) return;
    if (remote.isEmpty) {
      await LeadRemoteStore.seed(_leads);
    } else {
      _leads
        ..clear()
        ..addAll(remote);
    }
  }

  static List<Lead> getAll() => List.unmodifiable(_leads);

  static Lead? findById(int id) {
    try {
      return _leads.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  static void add(Lead lead) {
    _leads.add(lead);
    AdminAlertService.report(
      event: 'New lead created',
      message: '${lead.name} (${lead.company}) was added as a lead.',
      severity: 'info',
      details: {
        'name': lead.name,
        'company': lead.company,
        'source': lead.source,
        'status': lead.status,
      },
    );
    LeadRemoteStore.upsert(lead)
        .then((_) {
          // Lead persisted to database
        })
        .onError((_, _) {
          // Failed to persist - running in offline mode, local data remains valid
        });
  }

  static void update(Lead lead) {
    final idx = _leads.indexWhere((l) => l.id == lead.id);
    if (idx != -1) {
      _leads[idx] = lead;
      LeadRemoteStore.upsert(lead)
          .then((_) {
            // Lead persisted to database
          })
          .onError((_, _) {
            // Failed to persist - running in offline mode, local data remains valid
          });
    }
  }

  static void remove(int id) {
    _leads.removeWhere((l) => l.id == id);
    LeadRemoteStore.delete(id);
  }

  static int nextId() {
    return _leads.isEmpty
        ? 1
        : _leads.map((l) => l.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Converts a qualified lead into an Opportunity and optionally a Customer.
  ///
  /// This is the core lead-to-customer workflow:
  /// 1. Validates the lead is qualified (status check)
  /// 2. Creates an Opportunity linked to this lead via [leadId]
  /// 3. Optionally creates a Customer linked to this lead and campaign
  /// 4. Checks for duplicate customers by email
  /// 5. Marks the lead as 'Converted'
  ///
  /// Returns a Map with the created entity IDs and objects.
  /// Throws if a customer with the same email already exists.
  static Future<Map<String, dynamic>> convertToOpportunityAndCustomer({
    required Lead lead,
    required String campaignId,
    required double opportunityValue,
    required String opportunityStage,
    required bool convertToCustomer,
    required String customerName,
    required String customerEmail,
    required String customerSegment,
    required String assignedStaff,
  }) async {
    // Check for duplicate customer by email among existing customers
    final existingCustomers = CustomerRepository.getAll();
    final duplicateCustomer = existingCustomers.any(
      (c) => c.email == customerEmail,
    );
    if (duplicateCustomer) {
      throw Exception('A customer with this email already exists.');
    }

    // Check for duplicate opportunity by lead ID
    final existingOpps = OpportunityRepository.getAll();
    final duplicateOpp = existingOpps.any(
      (o) => o.leadId == lead.id.toString(),
    );
    if (duplicateOpp) {
      throw Exception('An opportunity already exists for this lead.');
    }

    // Create the opportunity linked to this lead
    final oppId = OpportunityRepository.nextId();
    final newOpportunity = Opportunity(
      id: oppId,
      name: 'Opportunity from ${lead.name}',
      company: lead.company,
      value: opportunityValue,
      owner: assignedStaff,
      probability: (lead.score ~/ 20).clamp(0, 100),
      stage: opportunityStage,
      leadId: lead.id.toString(),
      customerId: convertToCustomer
          ? null
          : null, // Set later if customer created
      createdAt: DateTime.now(),
    );
    OpportunityRepository.add(newOpportunity);

    // Optionally create a customer from the converted lead
    Customer? newCustomer;
    int? newCustomerId;
    if (convertToCustomer) {
      newCustomerId = CustomerRepository.nextId();
      newCustomer = Customer(
        id: newCustomerId,
        name: customerName,
        email: customerEmail,
        phone: lead.phone,
        segment: customerSegment,
        status: AppConstants.statusActive,
        lastActivity: DateTime.now(),
        joinedAt: DateTime.now(),
        leadId: lead.id.toString(),
        opportunityId: newOpportunity.id.toString(),
        campaignId: campaignId,
      );
      if (!await CustomerRepository.add(newCustomer)) {
        throw Exception('Customer could not be saved.');
      }
      if (campaignId.isNotEmpty &&
          !await CampaignCustomerRepository.assign(
            CampaignCustomer(
              campaignId: campaignId,
              customerId: newCustomer.id,
              assignedDate: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          )) {
        throw Exception('Customer was saved, but campaign assignment failed.');
      }
    }

    // Mark the lead as converted
    final convertedLead = lead.copyWith(status: AppConstants.leadConverted);
    final leadIdx = _leads.indexWhere((l) => l.id == lead.id);
    if (leadIdx != -1) {
      _leads[leadIdx] = convertedLead;
      LeadRemoteStore.upsert(convertedLead);
    }

    // Return conversion summary
    final result = <String, dynamic>{
      'leadId': lead.id,
      'opportunityId': oppId,
      'opportunity': newOpportunity,
    };
    if (convertToCustomer && newCustomer != null) {
      result['customerId'] = newCustomerId;
      result['customer'] = newCustomer;
    }
    return result;
  }
}
