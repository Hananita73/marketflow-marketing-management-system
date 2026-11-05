import '../core/constants.dart';
import '../config/supabase_config.dart';
import '../services/entity_remote_stores.dart';

class Customer {
  final int id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String segment;
  final String status;
  final DateTime lastActivity;
  final DateTime joinedAt;
  final String? leadId;
  final String? opportunityId;
  final String? campaignId;

  const Customer({
    required this.id,
    required this.name,
    this.company = '',
    required this.email,
    required this.phone,
    required this.segment,
    required this.status,
    required this.lastActivity,
    required this.joinedAt,
    this.leadId,
    this.opportunityId,
    this.campaignId,
  });

  String get initials => name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join();
}

class CustomerRepository {
  CustomerRepository._();

  static final List<Customer> _customers = [
    Customer(
      id: 1,
      name: 'Abebe Kebede',
      email: 'abebe.kebede@techwave.com',
      phone: '+251 911 234 567',
      segment: 'VIP',
      status: AppConstants.statusActive,
      lastActivity: DateTime(2026, 5, 12),
      joinedAt: DateTime(2023, 1, 10),
    ),
    Customer(
      id: 2,
      name: 'Sara Ahmed',
      email: 'sara@greenleaf.co',
      phone: '+251 922 345 678',
      segment: 'Retail',
      status: AppConstants.statusActive,
      lastActivity: DateTime(2026, 5, 8),
      joinedAt: DateTime(2023, 2, 14),
    ),
    Customer(
      id: 3,
      name: 'John Smith',
      email: 'john@globalretail.com',
      phone: '+251 933 456 789',
      segment: 'Retail',
      status: AppConstants.statusActive,
      lastActivity: DateTime(2026, 5, 10),
      joinedAt: DateTime(2023, 3, 20),
    ),
    Customer(
      id: 4,
      name: 'Meron Tadesse',
      email: 'meron@innovate.et',
      phone: '+251 944 567 890',
      segment: 'SME',
      status: AppConstants.statusActive,
      lastActivity: DateTime(2026, 5, 15),
      joinedAt: DateTime(2023, 4, 1),
    ),
    Customer(
      id: 5,
      name: 'Daniel Girma',
      email: 'daniel@nexustech.com',
      phone: '+251 955 678 901',
      segment: 'Technology',
      status: AppConstants.statusActive,
      lastActivity: DateTime(2026, 5, 11),
      joinedAt: DateTime(2023, 5, 20),
    ),
  ];

  static bool _initialized = false;

  static Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _initialized = true;
    final remote = await CustomerRemoteStore.fetchAll();
    if (remote == null) return;
    if (remote.isEmpty) {
      await CustomerRemoteStore.seed(_customers);
    } else {
      _customers ..clear() ..addAll(remote);
    }
  }

  static List<Customer> getAll() => List<Customer>.from(_customers);

  static Customer? findById(int id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> add(Customer customer) async {
    if (SupabaseConfig.isConfigured &&
        !await CustomerRemoteStore.upsert(customer)) {
      return false;
    }
    _customers.add(customer);
    return true;
  }

  static Future<bool> update(Customer updated) async {
    final idx = _customers.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      if (SupabaseConfig.isConfigured &&
          !await CustomerRemoteStore.upsert(updated)) {
        return false;
      }
      _customers[idx] = updated;
      return true;
    }
    return false;
  }

  // NOTE: id is an int (Customer.id is int) — comparing it against a String
  // silently matched nothing, so deletes used to be a no-op.
  static void remove(int id) {
    _customers.removeWhere((c) => c.id == id);
    CustomerRemoteStore.delete(id); // fire-and-forget sync
  }

  static int nextId() {
    if (_customers.isEmpty) return 1;
    return _customers.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
  }
}
