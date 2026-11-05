import 'package:flutter/material.dart';

enum UserStatus { active, inactive, pending }

/// Compatibility enum for existing widgets. Authorization uses named keys
/// loaded from Supabase app_permissions.
enum PermissionType { view, create, edit, delete, approve, submit }

class AppUser {
  final String id;
  String fullName;
  String email;
  String phone;
  String role;
  String department;
  UserStatus status;
  String lastActive;
  String accountCreated;
  List<String> recentActivity;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    required this.role,
    required this.department,
    required this.status,
    required this.lastActive,
    required this.accountCreated,
    this.recentActivity = const [],
  });

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? department,
    UserStatus? status,
    String? lastActive,
    String? accountCreated,
    List<String>? recentActivity,
  }) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    department: department ?? this.department,
    status: status ?? this.status,
    lastActive: lastActive ?? this.lastActive,
    accountCreated: accountCreated ?? this.accountCreated,
    recentActivity: recentActivity ?? this.recentActivity,
  );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : '?';
  }

  String get roleDisplayName => UserRoleRepository.roleDisplayName(role);
}

class AppRole {
  final String name;
  final String dbKey;
  final String description;
  final String permissionSummary;
  final int userCount;
  final Color color;

  const AppRole({
    required this.name,
    required this.dbKey,
    this.description = '',
    this.permissionSummary = '',
    this.userCount = 0,
    this.color = const Color(0xFF6C4CE8),
  });
}

class ModulePermission {
  final String module;
  bool view;
  bool create;
  bool edit;
  bool delete;
  bool approve;
  bool submit;

  ModulePermission({
    required this.module,
    this.view = false,
    this.create = false,
    this.edit = false,
    this.delete = false,
    this.approve = false,
    this.submit = false,
  });
}

class ActivityEntry {
  final String id;
  final String description;
  final String timestamp;
  final IconData icon;
  final Color iconColor;

  const ActivityEntry({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
  });
}

/// Compatibility facade for older widgets. User accounts, roles, and
/// permissions are no longer seeded here; Supabase is the source of truth.
class UserRoleRepository {
  UserRoleRepository._();
  static final List<AppUser> _offlineUsers = <AppUser>[];

  static List<AppUser> getAll() => List<AppUser>.from(_offlineUsers);
  static void addUser(AppUser user) => _offlineUsers.add(user);
  static void updateUser(AppUser user) {
    final index = _offlineUsers.indexWhere((item) => item.id == user.id);
    if (index >= 0) _offlineUsers[index] = user;
  }

  static void removeUser(String id) =>
      _offlineUsers.removeWhere((item) => item.id == id);

  static String roleDisplayName(String role) {
    if (role == 'admin') return 'Administrator';
    if (role == 'marketing_clerk') return 'Marketing Staff';
    if (role.isEmpty) return 'Unassigned';
    return role
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String dbRoleFromDisplay(String display) {
    if (display == 'Administrator') return 'admin';
    if (display == 'Marketing Staff') return 'marketing_clerk';
    return display.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  static const List<String> roleDisplayNames = ['Administrator'];
  static const List<AppRole> roles = <AppRole>[];
  static const List<ActivityEntry> recentActivity = <ActivityEntry>[];

  static List<ModulePermission> getPermissionsForRole(String role) =>
      <ModulePermission>[];
  static List<ModulePermission> getAdminPermissions() => <ModulePermission>[];
  static bool canView(String role, String module) => false;
  static bool canCreate(String role, String module) => false;
  static bool canEdit(String role, String module) => false;
  static bool canDelete(String role, String module) => false;
  static bool canApprove(String role, String module) => false;
  static bool canSubmit(String role, String module) => false;
}
