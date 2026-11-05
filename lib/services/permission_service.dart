import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role_models.dart';

/// Canonical permission names used by the UI, routing, and Supabase RLS.
/// Every actionable control should use one of these keys.
class PermissionDefinition {
  final String key;
  final String label;
  final String module;
  const PermissionDefinition(this.key, this.label, this.module);
}

class DynamicRole {
  final String key;
  final String name;
  final bool isSystem;
  final List<String> permissions;

  const DynamicRole({
    required this.key,
    required this.name,
    required this.isSystem,
    required this.permissions,
  });

  factory DynamicRole.fromRow(Map<String, dynamic> row) {
    final links = row['role_permissions'] as List? ?? const [];
    return DynamicRole(
      key: row['role_key']?.toString() ?? row['key']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      isSystem: row['is_system'] == true,
      permissions: links
          .map((item) => item is Map
              ? item['permission_key']?.toString() ?? ''
              : item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

class PermissionService {
  PermissionService._();
  static final _client = Supabase.instance.client;

  static const List<PermissionDefinition> catalog = [
    PermissionDefinition('dashboard.view', 'dashboard.view', 'Dashboard'),
    PermissionDefinition('campaign.view', 'campaign.view', 'Campaigns'),
    PermissionDefinition('campaign.add', 'campaign.add', 'Campaigns'),
    PermissionDefinition('campaign.edit', 'campaign.edit', 'Campaigns'),
    PermissionDefinition('campaign.delete', 'campaign.delete', 'Campaigns'),
    PermissionDefinition('campaign.submit', 'campaign.submit', 'Campaigns'),
    PermissionDefinition('campaign.approve', 'campaign.approve', 'Campaigns'),
    PermissionDefinition('customer.view', 'customer.view', 'Customers'),
    PermissionDefinition('customer.add', 'customer.add', 'Customers'),
    PermissionDefinition('customer.edit', 'customer.edit', 'Customers'),
    PermissionDefinition('customer.delete', 'customer.delete', 'Customers'),
    PermissionDefinition('lead.view', 'lead.view', 'Leads'),
    PermissionDefinition('lead.add', 'lead.add', 'Leads'),
    PermissionDefinition('lead.edit', 'lead.edit', 'Leads'),
    PermissionDefinition('lead.delete', 'lead.delete', 'Leads'),
    PermissionDefinition('opportunity.view', 'opportunity.view', 'Opportunities'),
    PermissionDefinition('opportunity.view_all', 'opportunity.view_all', 'Opportunities'),
    PermissionDefinition('opportunity.add', 'opportunity.add', 'Opportunities'),
    PermissionDefinition('opportunity.edit', 'opportunity.edit', 'Opportunities'),
    PermissionDefinition('opportunity.delete', 'opportunity.delete', 'Opportunities'),
    PermissionDefinition('influencer.view', 'influencer.view', 'Influencers'),
    PermissionDefinition('influencer.add', 'influencer.add', 'Influencers'),
    PermissionDefinition('influencer.edit', 'influencer.edit', 'Influencers'),
    PermissionDefinition('influencer.delete', 'influencer.delete', 'Influencers'),
    PermissionDefinition('content.view', 'content.view', 'Content'),
    PermissionDefinition('content.add', 'content.add', 'Content'),
    PermissionDefinition('content.edit', 'content.edit', 'Content'),
    PermissionDefinition('content.delete', 'content.delete', 'Content'),
    PermissionDefinition('promotion.view', 'promotion.view', 'Promotions'),
    PermissionDefinition('promotion.add', 'promotion.add', 'Promotions'),
    PermissionDefinition('promotion.edit', 'promotion.edit', 'Promotions'),
    PermissionDefinition('promotion.delete', 'promotion.delete', 'Promotions'),
    PermissionDefinition('promotion.approve', 'promotion.approve', 'Promotions'),
    PermissionDefinition('budget.view', 'budget.view', 'Budget'),
    PermissionDefinition('budget.add', 'budget.add', 'Budget'),
    PermissionDefinition('budget.edit', 'budget.edit', 'Budget'),
    PermissionDefinition('budget.delete', 'budget.delete', 'Budget'),
    PermissionDefinition('budget.approve', 'budget.approve', 'Budget'),
    PermissionDefinition('communication.view', 'communication.view', 'Communications'),
    PermissionDefinition('communication.add', 'communication.add', 'Communications'),
    PermissionDefinition('communication.edit', 'communication.edit', 'Communications'),
    PermissionDefinition('communication.delete', 'communication.delete', 'Communications'),
    PermissionDefinition('automation.view', 'automation.view', 'Automation'),
    PermissionDefinition('automation.add', 'automation.add', 'Automation'),
    PermissionDefinition('automation.edit', 'automation.edit', 'Automation'),
    PermissionDefinition('automation.delete', 'automation.delete', 'Automation'),
    PermissionDefinition('report.view', 'report.view', 'Reports'),
    PermissionDefinition('report.generate', 'report.generate', 'Reports'),
    PermissionDefinition('notification.view', 'notification.view', 'Notifications'),
    PermissionDefinition('user.view', 'user.view', 'Users & Roles'),
    PermissionDefinition('user.invite', 'user.invite', 'Users & Roles'),
    PermissionDefinition('user.assign_role', 'user.assign_role', 'Users & Roles'),
    PermissionDefinition('user.activate', 'user.activate', 'Users & Roles'),
    PermissionDefinition('user.deactivate', 'user.deactivate', 'Users & Roles'),
    PermissionDefinition('settings.view', 'settings.view', 'Settings'),
    PermissionDefinition('settings.manage', 'settings.manage', 'Settings'),
    PermissionDefinition('audit.view', 'audit.view', 'Audit Log'),
  ];

  static List<String> get allKeys => catalog.map((item) => item.key).toList();

  static String keyFor(String module, PermissionType type) {
    final base = module.toLowerCase().trim();
    final action = switch (type) {
      PermissionType.view => 'view',
      PermissionType.create => 'add',
      PermissionType.edit => 'edit',
      PermissionType.delete => 'delete',
      PermissionType.approve => 'approve',
      PermissionType.submit => 'submit',
    };
    final prefix = switch (base) {
      'campaigns' => 'campaign', 'customers' => 'customer', 'leads' => 'lead',
      'opportunities' => 'opportunity', 'influencers' => 'influencer',
      'content' => 'content', 'promotions' => 'promotion', 'budget' => 'budget',
      'communications' => 'communication', 'automation' => 'automation',
      'reports' => 'report', 'notifications' => 'notification',
      'users & roles' => 'user', 'settings' => 'settings',
      'audit log' => 'audit', 'dashboard' => 'dashboard', _ => base,
    };
    final normalizedAction = prefix == 'report' && action == 'create'
        ? 'generate'
        : action;
    return '$prefix.$normalizedAction';
  }

  static Future<List<DynamicRole>> listRoles() async {
    final rows = await _client
        .from('app_roles')
        .select('role_key, name, is_system, role_permissions(permission_key)')
        .order('name');
    return (rows as List)
        .map((row) => DynamicRole.fromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  static Future<Set<String>> loadKeysForRole(String roleKey) async {
    final rows = await _client
        .from('role_permissions')
        .select('permission_key')
        .eq('role_key', roleKey);
    return (rows as List)
        .map((row) => (row as Map)['permission_key']?.toString() ?? '')
        .where((key) => key.isNotEmpty)
        .toSet();
  }

  static Future<void> saveRole({
    String? roleKey,
    required String name,
    required List<String> permissions,
  }) async {
    await _client.rpc(
      roleKey == null ? 'admin_create_role' : 'admin_update_role',
      params: {
        if (roleKey != null) 'p_role_key': roleKey,
        'p_name': name.trim(),
        'p_permissions': permissions,
      },
    );
  }

  static Future<void> deleteRole(String roleKey) async {
    await _client.rpc('admin_delete_role', params: {'p_role_key': roleKey});
  }

  static Set<String> modulePermissionKeys(Iterable<String> keys) => keys.toSet();

  static List<ModulePermission> toModulePermissions(Iterable<String> keys) {
    final granted = keys.toSet();
    final modules = <String, String>{
      'Dashboard': 'dashboard', 'Campaigns': 'campaign', 'Customers': 'customer',
      'Leads': 'lead', 'Opportunities': 'opportunity', 'Influencers': 'influencer',
      'Content': 'content', 'Promotions': 'promotion', 'Budget': 'budget',
      'Communications': 'communication', 'Automation': 'automation',
      'Reports': 'report', 'Notifications': 'notification', 'Users & Roles': 'user',
      'Settings': 'settings', 'Audit Log': 'audit',
    };
    return modules.entries.map((entry) => ModulePermission(
      module: entry.key,
      view: granted.contains('${entry.value}.view'),
      create: granted.contains(entry.value == 'report'
          ? 'report.generate'
          : entry.value == 'user'
              ? 'user.invite'
              : '${entry.value}.add'),
      edit: granted.contains('${entry.value}.edit'),
      delete: granted.contains('${entry.value}.delete'),
      approve: granted.contains('${entry.value}.approve'),
      submit: granted.contains('${entry.value}.submit'),
    )).toList();
  }

  static void reportFailure(Object error) =>
      developer.log('Permission service failed: $error', name: 'PermissionService');
}
