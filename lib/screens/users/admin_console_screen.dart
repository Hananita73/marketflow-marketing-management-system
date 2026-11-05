import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../core/theme.dart';
import '../../models/user_role_models.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../utils/input_validators.dart';

/// The administration surface for Users & Roles.
///
/// This is intentionally a single remote-backed screen: the visual language
/// follows the supplied admin-console reference, while the data comes from
/// app_roles, role_permissions, users, and audit_logs in Supabase.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  final _permissionSearchController = TextEditingController();

  List<DynamicRole> _roles = const [];
  List<Map<String, dynamic>> _users = const [];
  List<AuditLogEntry> _audit = const [];
  DynamicRole? _selectedRole;
  Set<String> _draftPermissions = <String>{};
  bool _loading = true;
  bool _saving = false;
  String _userSearch = '';
  String _roleFilter = 'All roles';
  String _statusFilter = 'All statuses';
  String _auditSearch = '';
  String _permissionSearch = '';
  Timer? _auditSearchTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _permissionSearchController.dispose();
    _auditSearchTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        PermissionService.listRoles(),
        AuthService().listUsers(),
        AuditLogService.search(limit: 200, query: _auditSearch),
      ]);
      final roles = results[0] as List<DynamicRole>;
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _users = List<Map<String, dynamic>>.from(results[1] as List);
        _audit = results[2] as List<AuditLogEntry>;
        _selectedRole = _findSelectedRole(roles);
        _draftPermissions = _selectedRole?.permissions.toSet() ?? <String>{};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not load administration data: $e', error: true);
    }
  }

  DynamicRole? _findSelectedRole(List<DynamicRole> roles) {
    if (_selectedRole == null) {
      return roles.isEmpty ? null : roles.first;
    }
    for (final role in roles) {
      if (role.key == _selectedRole!.key) return role;
    }
    return roles.isEmpty ? null : roles.first;
  }

  void _selectRole(DynamicRole role) {
    setState(() {
      _selectedRole = role;
      _draftPermissions = role.permissions.toSet();
    });
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _savePermissions() async {
    final role = _selectedRole;
    if (role == null || role.isSystem) return;
    setState(() => _saving = true);
    try {
      await PermissionService.saveRole(
        roleKey: role.key,
        name: role.name,
        permissions: _draftPermissions.toList(),
      );
      await _load();
      _message('Permissions saved to Supabase.');
    } catch (e) {
      _message('Permission save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRole() async {
    final name = await _roleNameDialog();
    if (name == null || name.trim().isEmpty) return;
    try {
      await PermissionService.saveRole(
        name: name.trim(),
        permissions: const [],
      );
      await _load();
      _message('Role created in Supabase.');
    } catch (e) {
      _message('Role creation failed: $e', error: true);
    }
  }

  Future<String?> _roleNameDialog() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create role'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Role name',
            hintText: 'e.g. Campaign Manager',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _deleteRole(DynamicRole role) async {
    if (role.isSystem) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete role?'),
        content: Text('Delete ${role.name}? Reassign all users first.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PermissionService.deleteRole(role.key);
      await _load();
      _message('Role deleted from Supabase.');
    } catch (e) {
      _message('Role deletion failed: $e', error: true);
    }
  }

  Future<void> _editRole(DynamicRole role) async {
    if (role.isSystem) return;
    final controller = TextEditingController(text: role.name);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit role'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Role name',
            hintText: 'e.g. Campaign Manager',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || value.trim() == role.name) {
      return;
    }
    try {
      await PermissionService.saveRole(
        roleKey: role.key,
        name: value.trim(),
        permissions: role.permissions,
      );
      await _load();
      _message('Role updated in Supabase.');
    } catch (e) {
      _message('Role update failed: $e', error: true);
    }
  }

  Future<void> _editUser([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(
      text: existing?['full_name']?.toString(),
    );
    final email = TextEditingController(text: existing?['email']?.toString());
    final phone = TextEditingController(text: existing?['phone']?.toString());
    final department = TextEditingController(
      text: existing?['department']?.toString(),
    );
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var role =
        existing?['role']?.toString() ?? (_roles.firstOrNull?.key ?? 'admin');
    var status = existing?['status']?.toString() ?? 'pending_assignment';
    final isNew = existing == null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isNew ? 'Invite central user' : 'Edit user access'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      enabled: isNew,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                      validator: InputValidators.email,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isNew
                            ? 'Temporary password'
                            : 'New password (optional)',
                        helperText: isNew
                            ? 'At least 8 characters. Share it securely with the user.'
                            : 'Leave blank to keep the current password.',
                      ),
                      validator: (value) =>
                          (isNew || (value?.isNotEmpty ?? false)) &&
                              (value?.length ?? 0) < 8
                          ? 'Use at least 8 characters'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      validator: (value) => InputValidators.ethiopianPhone(
                        value,
                        required: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: department,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _roles.any((r) => r.key == role) ? role : null,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: _roles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.key,
                              child: Text(r.name),
                            ),
                          )
                          .toList(),
                      onChanged: isNew
                          ? (value) =>
                                setDialogState(() => role = value ?? role)
                          : (value) =>
                                setDialogState(() => role = value ?? role),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Account status',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending_assignment',
                          child: Text('Pending approval'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'deactivated',
                          child: Text('Deactivated'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(isNew ? 'Create user' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      name.dispose();
      email.dispose();
      phone.dispose();
      department.dispose();
      password.dispose();
      return;
    }
    try {
      if (isNew) {
        await AuthService().adminCreateUser(
          email: email.text.trim(),
          fullName: name.text.trim(),
          password: password.text,
          phone: phone.text.trim(),
          department: department.text.trim().isEmpty
              ? 'General'
              : department.text.trim(),
          role: role,
          status: status,
        );
      } else {
        await AuthService().updateUserProfile(
          userId: existing['id'].toString(),
          role: role,
          status: status,
          department: department.text.trim(),
        );
        if (password.text.isNotEmpty) {
          try {
            await AuthService().adminUpdateUserPassword(
              userId: existing['id'].toString(),
              password: password.text,
            );
          } catch (e) {
            await _load();
            _message('Profile saved, but password update failed: $e', error: true);
            return;
          }
        }
      }
      await _load();
      _message(
        isNew ? 'User created remotely.' : 'User access saved remotely.',
      );
    } catch (e) {
      _message('User operation failed: $e', error: true);
    } finally {
      name.dispose();
      email.dispose();
      phone.dispose();
      department.dispose();
      password.dispose();
    }
  }

  Future<void> _deactivateUser(Map<String, dynamic> user) async {
    if (user['id']?.toString() == AuthService().currentUser?.id) {
      _message('You cannot deactivate your own account.', error: true);
      return;
    }
    try {
      await AuthService().updateUserProfile(
        userId: user['id'].toString(),
        status: 'deactivated',
      );
      await _load();
      _message('User deactivated remotely.');
    } catch (e) {
      _message('Could not deactivate user: $e', error: true);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId == AuthService().currentUser?.id) {
      _message('You cannot delete your own account.', error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete user permanently?'),
        content: Text(
          'Delete ${user['full_name'] ?? user['email'] ?? 'this user'}? '
          'They will no longer be able to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthService().adminDeleteUser(userId: userId);
      await _load();
      _message('User deleted.');
    } catch (e) {
      _message('Could not delete user: $e', error: true);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _userSearch.trim().toLowerCase();
    return _users.where((user) {
      final matchesSearch =
          q.isEmpty ||
          [
            user['full_name'],
            user['email'],
            user['phone'],
            user['department'],
          ].any((value) => value?.toString().toLowerCase().contains(q) == true);
      final matchesRole =
          _roleFilter == 'All roles' || user['role'] == _roleFilter;
      final matchesStatus =
          _statusFilter == 'All statuses' || user['status'] == _statusFilter;
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  void _queueAuditSearch(String value) {
    _auditSearch = value;
    _auditSearchTimer?.cancel();
    _auditSearchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final entries = await AuditLogService.search(
          limit: 200,
          query: _auditSearch,
        );
        if (mounted) setState(() => _audit = entries);
      } catch (e) {
        if (mounted) _message('Could not search activity: $e', error: true);
      }
    });
  }

  Map<String, List<PermissionDefinition>> get _permissionGroups {
    final grouped = <String, List<PermissionDefinition>>{};
    for (final permission in PermissionService.catalog) {
      grouped.putIfAbsent(permission.module, () => []).add(permission);
    }
    return grouped;
  }

  Map<String, List<PermissionDefinition>> get _filteredPermissionGroups {
    final query = _permissionSearch.trim().toLowerCase();
    if (query.isEmpty) return _permissionGroups;
    final filtered = <String, List<PermissionDefinition>>{};
    for (final entry in _permissionGroups.entries) {
      final permissions = entry.value
          .where(
            (permission) =>
                permission.key.toLowerCase().contains(query) ||
                permission.label.toLowerCase().contains(query) ||
                permission.module.toLowerCase().contains(query),
          )
          .toList();
      if (permissions.isNotEmpty) filtered[entry.key] = permissions;
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(br);
    final textSecondary = AppTheme.textSecondary(br);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
      children: [
        _topHeader(textPrimary, textSecondary),
        const SizedBox(height: 20),
        _summaryCards(br),
        const SizedBox(height: 20),
        _tabBar(br),
        const SizedBox(height: 18),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(80),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          AnimatedBuilder(
            animation: _tabs,
            builder: (_, __) => switch (_tabs.index) {
              0 => _rolesView(br),
              1 => _usersView(br),
              2 => _auditView(br),
              _ => _recentActivityView(br),
            },
          ),
      ],
    );
  }

  Widget _topHeader(Color primary, Color secondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Central administration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Manage MarketFlow access, users, and security activity from one place.',
                style: TextStyle(color: secondary),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _summaryCards(Brightness br) {
    final active = _users.where((u) => u['status'] == 'active').length;
    final pending = _users
        .where((u) => u['status'] == 'pending_assignment')
        .length;
    final selected = _selectedRole?.permissions.length ?? 0;
    final cards = [
      (
        'System roles',
        '${_roles.length}',
        Icons.shield_outlined,
        AppColors.primary,
      ),
      (
        'Total permissions',
        '${PermissionService.catalog.length}',
        Icons.key_outlined,
        AppColors.info,
      ),
      (
        'Central users',
        '${_users.length}',
        Icons.people_outline,
        AppColors.success,
      ),
      (
        'Selected permissions',
        '$selected/${PermissionService.catalog.length}',
        Icons.check_circle_outline,
        AppColors.warning,
      ),
      (
        'Active / pending',
        '$active / $pending',
        Icons.verified_user_outlined,
        AppColors.success,
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = constraints.maxWidth >= 1150
            ? 5
            : constraints.maxWidth >= 650
            ? 3
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(width: width, child: _summaryCard(card, br)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard((String, String, IconData, Color) card, Brightness br) {
    return _panel(
      br,
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: card.$4.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(card.$3, size: 18, color: card.$4),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.$1.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary(br),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.$2,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary(br),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar(Brightness br) {
    final isDark = br == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1C1A27)
        : AppColors.primaryLighter;
    final borderColor = isDark
        ? const Color(0xFF312E47)
        : AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return TabBar(
            controller: _tabs,
            isScrollable: isNarrow,
            tabAlignment:
                isNarrow ? TabAlignment.start : TabAlignment.fill,
            labelColor: Colors.white,
            unselectedLabelColor: isDark
                ? const Color(0xFF9E9BB5)
                : AppColors.primary.withValues(alpha: 0.55),
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorPadding: EdgeInsets.zero,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(
                icon: Icon(Icons.shield_outlined, size: 16),
                text: 'Roles & permissions',
              ),
              Tab(
                icon: Icon(Icons.people_outline, size: 16),
                text: 'Central users',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined, size: 16),
                text: 'Audit logs',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 16),
                text: 'Recent activity',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rolesView(Brightness br) {
    final selected = _selectedRole;
    return LayoutBuilder(
      builder: (_, constraints) {
        final narrow = constraints.maxWidth < 900;
        final list = _roleList(br);
        final matrix = selected == null
            ? _emptyPanel(br, 'No roles found.')
            : _permissionMatrix(br, selected);
        return narrow
            ? Column(children: [list, const SizedBox(height: 16), matrix])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 265, child: list),
                  const SizedBox(width: 16),
                  Expanded(child: matrix),
                ],
              );
      },
    );
  }

  Widget _roleList(Brightness br) {
    return _panel(
      br,
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'SYSTEM ROLES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary(br),
                    letterSpacing: .6,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Add role',
                  onPressed: _createRole,
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search roles',
                prefixIcon: Icon(Icons.search, size: 17),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            ..._roles
                .where(
                  (role) => role.name.toLowerCase().contains(
                    _searchController.text.toLowerCase(),
                  ),
                )
                .map((role) {
                  final active = _selectedRole?.key == role.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () => _selectRole(role),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : AppTheme.surfaceVariant(br),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              role.isSystem
                                  ? Icons.shield_outlined
                                  : Icons.verified_user_outlined,
                              size: 16,
                              color: active ? Colors.white : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                role.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors.white
                                      : AppTheme.textPrimary(br),
                                ),
                              ),
                            ),
                            if (role.isSystem)
                              Icon(
                                Icons.lock_outline,
                                size: 13,
                                color: active
                                    ? Colors.white70
                                    : AppTheme.textSecondary(br),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit role',
                                    onPressed: () => _editRole(role),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 26,
                                      height: 26,
                                    ),
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 15,
                                      color: active
                                          ? Colors.white
                                          : AppTheme.textSecondary(br),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete role',
                                    onPressed: () => _deleteRole(role),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 26,
                                      height: 26,
                                    ),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 15,
                                      color: active
                                          ? Colors.white70
                                          : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }

  Widget _permissionMatrix(Brightness br, DynamicRole role) {
    final grouped = _filteredPermissionGroups;
    final locked = role.isSystem;
    return _panel(
      br,
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PERMISSIONS MATRIX  /  ${role.name.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary(br),
                      letterSpacing: .4,
                    ),
                  ),
                ),
                if (locked)
                  _tinyTag('Protected system role', AppColors.warning),
                if (!locked) ...[
                  TextButton(
                    onPressed: () => setState(
                      () =>
                          _draftPermissions = PermissionService.allKeys.toSet(),
                    ),
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _draftPermissions.clear()),
                    child: const Text('Clear all'),
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _savePermissions,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: Text(_saving ? 'Saving…' : 'Save permissions'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Every checkbox maps to a named backend permission and is enforced by Supabase RLS.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(br)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _permissionSearchController,
              onChanged: (value) => setState(() => _permissionSearch = value),
              decoration: InputDecoration(
                hintText: 'Search permissions by name or module',
                prefixIcon: const Icon(Icons.search, size: 17),
                isDense: true,
                suffixIcon: _permissionSearch.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _permissionSearchController.clear();
                          setState(() => _permissionSearch = '');
                        },
                        icon: const Icon(Icons.close, size: 17),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            if (grouped.isEmpty)
              _emptyPanel(br, 'No permissions match your search.')
            else
              ...grouped.entries.map(
                (entry) => _permissionGroup(br, entry.key, entry.value, locked),
              ),
          ],
        ),
      ),
    );
  }

  Widget _permissionGroup(
    Brightness br,
    String module,
    List<PermissionDefinition> permissions,
    bool locked,
  ) {
    final selectedCount = permissions
        .where((p) => _draftPermissions.contains(p.key))
        .length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border(br)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Text(
                  module.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary(br),
                    letterSpacing: .5,
                  ),
                ),
                const Spacer(),
                Text(
                  '$selectedCount/${permissions.length}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary(br),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: permissions.map((permission) {
                final checked = _draftPermissions.contains(permission.key);
                return SizedBox(
                  width: 190,
                  child: InkWell(
                    onTap: locked
                        ? null
                        : () => setState(
                            () => checked
                                ? _draftPermissions.remove(permission.key)
                                : _draftPermissions.add(permission.key),
                          ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: checked
                            ? AppColors.primaryLight
                            : AppTheme.surfaceVariant(br),
                        border: Border.all(
                          color: checked
                              ? AppColors.primary.withValues(alpha: .35)
                              : AppTheme.border(br),
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            checked
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 16,
                            color: checked
                                ? AppColors.primary
                                : AppTheme.textSecondary(br),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              permission.key,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textPrimary(br),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _usersView(Brightness br) {
    final users = _filteredUsers;
    final roles = ['All roles', ..._roles.map((r) => r.key)];
    const statuses = [
      'All statuses',
      'active',
      'pending_assignment',
      'deactivated',
    ];
    return _panel(
      br,
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CENTRAL USERS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary(br),
                      letterSpacing: .6,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _editUser(),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Create user'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (_, constraints) {
                final stacked = constraints.maxWidth < 700;
                final search = TextField(
                  onChanged: (v) => setState(() => _userSearch = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, email, phone…',
                    prefixIcon: Icon(Icons.search, size: 17),
                    isDense: true,
                  ),
                );
                final roleDrop = _filterDropdown(
                  br,
                  _roleFilter,
                  roles,
                  (v) => setState(() => _roleFilter = v),
                );
                final statusDrop = _filterDropdown(
                  br,
                  _statusFilter,
                  statuses,
                  (v) => setState(() => _statusFilter = v),
                );
                return stacked
                    ? Column(
                        children: [
                          search,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: roleDrop),
                              const SizedBox(width: 8),
                              Expanded(child: statusDrop),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 2, child: search),
                          const SizedBox(width: 8),
                          Expanded(child: roleDrop),
                          const SizedBox(width: 8),
                          Expanded(child: statusDrop),
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            if (users.isEmpty)
              _emptyPanel(br, 'No central users match the filters.')
            else
              _usersTable(br, users),
          ],
        ),
      ),
    );
  }

  Widget _usersTable(Brightness br, List<Map<String, dynamic>> users) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.surfaceVariant(br)),
        columns: const [
          DataColumn(label: Text('USER / EMAIL')),
          DataColumn(label: Text('ROLE')),
          DataColumn(label: Text('DEPARTMENT')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ACTIONS')),
        ],
        rows: users
            .map(
              (user) => DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 250,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primaryLight,
                            child: Text(
                              _initials(user['full_name']?.toString() ?? ''),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['full_name']?.toString() ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  user['email']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary(br),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    _tinyTag(
                      UserRoleRepository.roleDisplayName(
                        user['role']?.toString() ?? '',
                      ),
                      AppColors.primary,
                    ),
                  ),
                  DataCell(Text(user['department']?.toString() ?? 'General')),
                  DataCell(_statusTag(br, user['status']?.toString() ?? '')),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _editUser(user),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                        ),
                        if (user['id']?.toString() !=
                            AuthService().currentUser?.id)
                          IconButton(
                            tooltip: 'Deactivate',
                            onPressed: () => _deactivateUser(user),
                            icon: const Icon(
                              Icons.person_off_outlined,
                              size: 17,
                              color: AppColors.danger,
                            ),
                          ),
                        if (user['id']?.toString() !=
                            AuthService().currentUser?.id)
                          IconButton(
                            tooltip: 'Delete user permanently',
                            onPressed: () => _deleteUser(user),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 17,
                              color: AppColors.danger,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _auditView(Brightness br) {
    return _panel(
      br,
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CENTRAL AUDIT LOGS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary(br),
                      letterSpacing: .6,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Tamper-aware activity history for security events and administrator operations.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(br)),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: _queueAuditSearch,
              decoration: const InputDecoration(
                hintText: 'Search description, user, action...',
                prefixIcon: Icon(Icons.search, size: 17),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            if (_audit.isEmpty)
              _emptyPanel(br, 'No audit records found.')
            else
              ..._audit.map((entry) => _auditRow(br, entry)),
          ],
        ),
      ),
    );
  }

  Widget _recentActivityView(Brightness br) {
    final entries = _audit.take(12).toList();
    return _panel(
      br,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECENT ACTIVITY',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary(br),
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'The latest administrator and security events from Supabase.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(br),
                        ),
                      ),
                    ],
                  ),
                ),
                _tinyTag('${entries.length} latest events', AppColors.primary),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (entries.isEmpty)
              _emptyPanel(br, 'No recent activity found.')
            else
              ...entries.asMap().entries.map(
                (item) => _activityTimelineRow(
                  br,
                  item.value,
                  item.key == entries.length - 1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activityTimelineRow(Brightness br, AuditLogEntry entry, bool last) {
    final color = _activityColor(entry.action);
    final subject = entry.recordName.isEmpty ? entry.module : entry.recordName;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _activityIcon(entry.action),
                    size: 15,
                    color: color,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1, color: AppTheme.border(br)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(br),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border(br)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _tinyTag(entry.action.toUpperCase(), color),
                            const SizedBox(width: 8),
                            _tinyTag(entry.module, AppColors.info),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$subject  •  ${entry.userName.isEmpty ? 'System' : entry.userName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(br),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(entry.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary(br),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _activityColor(String action) {
    final normalized = action.toLowerCase();
    if (normalized.contains('delete') ||
        normalized.contains('deactivate') ||
        normalized.contains('reject'))
      return AppColors.danger;
    if (normalized.contains('create') ||
        normalized.contains('activate') ||
        normalized.contains('approve'))
      return AppColors.success;
    return AppColors.primary;
  }

  IconData _activityIcon(String action) {
    final normalized = action.toLowerCase();
    if (normalized.contains('delete')) return Icons.delete_outline;
    if (normalized.contains('login')) return Icons.login_rounded;
    if (normalized.contains('logout')) return Icons.logout_rounded;
    if (normalized.contains('create')) return Icons.add_circle_outline;
    if (normalized.contains('update') || normalized.contains('edit'))
      return Icons.edit_outlined;
    if (normalized.contains('activate')) return Icons.check_circle_outline;
    return Icons.security_outlined;
  }

  Widget _auditRow(Brightness br, AuditLogEntry entry) {
    final color =
        entry.action.contains('delete') || entry.action.contains('deactivate')
        ? AppColors.danger
        : entry.action.contains('create') || entry.action.contains('activate')
        ? AppColors.success
        : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider(br))),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _tinyTag(entry.action.toUpperCase(), color),
                    const SizedBox(width: 7),
                    _tinyTag(entry.module, AppColors.info),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  entry.recordName.isEmpty
                      ? entry.userName
                      : '${entry.userName} · ${entry.recordName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(entry.createdAt),
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(br)),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown(
    Brightness br,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      decoration: const InputDecoration(isDense: true),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item == 'All roles' || item == 'All statuses'
                    ? item
                    : UserRoleRepository.roleDisplayName(item),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _panel(Brightness br, Widget child) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surfaceColor(br),
      border: Border.all(color: AppTheme.border(br)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );

  Widget _emptyPanel(Brightness br, String text) => _panel(
    br,
    Padding(
      padding: const EdgeInsets.all(42),
      child: Center(
        child: Text(text, style: TextStyle(color: AppTheme.textSecondary(br))),
      ),
    ),
  );

  Widget _tinyTag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
    ),
  );

  Widget _statusTag(Brightness br, String status) {
    final active = status == 'active';
    final pending = status == 'pending_assignment';
    final color = active
        ? AppColors.success
        : pending
        ? AppColors.warning
        : AppColors.danger;
    return _tinyTag(
      active
          ? 'ACTIVE'
          : pending
          ? 'PENDING'
          : 'DEACTIVATED',
      color,
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length > 1)
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    return parts.isEmpty ? '?' : parts.first[0].toUpperCase();
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
