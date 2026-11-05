// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user_role_models.dart';
import '../../services/access_service.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_textfield.dart';
import '../../utils/input_validators.dart';

// -----------------------------------------------------------------------------
// UsersScreen � Users & Roles
// selfScrolling: true in routes.dart � owns its own CustomScrollView.
// Scroll architecture:
//   CustomScrollView
//     +- SliverPersistentHeader (pinned) ? sticky _UsersPageHeaderBar
//     +- SliverToBoxAdapter             ? KPI row, tabs, tab content
// -----------------------------------------------------------------------------

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final TextEditingController _searchCtrl = TextEditingController();
  String _roleFilter = 'All';
  String _deptFilter = 'All';
  String _statusFilter = 'All';
  String _sortBy = 'Name';
  String _userSection = 'All Users';
  List<AppUser> _users = [];
  List<DynamicRole> _roles = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
    _loadUsers();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await PermissionService.listRoles();
      if (mounted) setState(() => _roles = roles);
    } catch (_) {
      if (mounted) {
        setState(
          () => _roles = const [
            DynamicRole(
              key: 'admin',
              name: 'Administrator',
              isSystem: true,
              permissions: [],
            ),
          ],
        );
      }
    }
  }

  List<String> get _roleDisplayNames {
    final names = _roles
        .map((role) => role.name)
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? const ['Administrator'] : names;
  }

  /// Loads users from Supabase; falls back to mock data if the query fails.
  Future<void> _loadUsers() async {
    try {
      final rows = await AuthService().listUsers();
      if (!mounted) return;
      setState(() {
        _users = rows
            .map(
              (r) => AppUser(
                id: r['id'] as String,
                fullName: r['full_name'] as String? ?? 'Unknown',
                email: r['email'] as String? ?? '',
                phone: r['phone'] as String? ?? '',
                role: r['role'] as String? ?? 'viewer', // DB string
                department: r['department'] as String? ?? 'General',
                status: _statusFromString(r['status'] as String? ?? 'pending'),
                lastActive: 'N/A',
                accountCreated: r['created_at'] as String? ?? '',
              ),
            )
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = UserRoleRepository.getAll();
        });
      }
    }
  }

  UserStatus _statusFromString(String s) {
    switch (s) {
      case 'active':
        return UserStatus.active;
      case 'deactivated':
      case 'inactive':
        return UserStatus.inactive;
      default:
        return UserStatus.pending;
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -- computed --------------------------------------------------------------
  List<AppUser> get _filtered {
    var list = List<AppUser>.from(_users);
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (u) =>
                u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.phone.toLowerCase().contains(q) ||
                u.department.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_roleFilter != 'All') {
      final dbRole = UserRoleRepository.dbRoleFromDisplay(_roleFilter);
      list = list.where((u) => u.role == dbRole).toList();
    }
    if (_deptFilter != 'All')
      list = list.where((u) => u.department == _deptFilter).toList();
    if (_statusFilter != 'All') {
      final s = _statusStringToEnum(_statusFilter);
      list = list.where((u) => u.status == s).toList();
    }
    if (_userSection == 'Pending Users') {
      list = list.where((u) => u.status == UserStatus.pending).toList();
    } else if (_userSection == 'Deactivated Users') {
      list = list.where((u) => u.status == UserStatus.inactive).toList();
    }
    switch (_sortBy) {
      case 'Name':
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'Role':
        list.sort((a, b) => a.role.compareTo(b.role));
        break;
      case 'Department':
        list.sort((a, b) => a.department.compareTo(b.department));
        break;
      case 'Status':
        list.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }
    return list;
  }

  UserStatus _statusStringToEnum(String s) {
    switch (s) {
      case 'Active':
        return UserStatus.active;
      case 'Deactivated':
      case 'Inactive':
        return UserStatus.inactive;
      default:
        return UserStatus.pending;
    }
  }

  int get _totalUsers => _users.length;
  int get _activeUsers =>
      _users.where((u) => u.status == UserStatus.active).length;
  int get _admins => _users.where((u) => u.role == 'admin').length;
  int get _pending =>
      _users.where((u) => u.status == UserStatus.pending).length;

  List<String> get _allDepts {
    final d = _users.map((u) => u.department).toSet().toList()..sort();
    return ['All', ...d];
  }

  // -- helper: map display role name to database role string ------------------
  String _dbNameFromDisplay(String display) => _roles
      .firstWhere(
        (role) => role.name == display,
        orElse: () => DynamicRole(
          key: UserRoleRepository.dbRoleFromDisplay(display),
          name: display,
          isSystem: false,
          permissions: const [],
        ),
      )
      .key;

  // -- snackbar --------------------------------------------------------------
  void _snack(
    String msg, {
    IconData icon = Icons.check_circle_rounded,
    Color color = AppColors.success,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -- invite dialog ---------------------------------------------------------
  void _showInviteDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    String role = 'Marketing Staff';
    String status = 'Pending';
    final formKey = GlobalKey<FormState>();
    final roles = _roleDisplayNames;
    final statuses = ['Active', 'Pending'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final br = Theme.of(ctx).brightness;
          return Dialog(
            backgroundColor: AppTheme.surfaceColor(br),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogHeader(
                          ctx,
                          Icons.person_add_rounded,
                          'Invite User',
                          AppColors.primary,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: nameCtrl,
                          label: 'Full Name *',
                          hint: 'e.g. Abebe Kebede',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: emailCtrl,
                          label: 'Email Address *',
                          hint: 'user@marketflow.et',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: InputValidators.email,
                        ),
                        const SizedBox(height: 14),
                        _dropdownField(
                          ctx,
                          'Role *',
                          role,
                          roles,
                          (v) => setLocal(() => role = v!),
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: deptCtrl,
                          label: 'Department',
                          hint: 'e.g. Marketing',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 14),
                        _dropdownField(
                          ctx,
                          'Status',
                          status,
                          statuses,
                          (v) => setLocal(() => status = v!),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            CustomButton(
                              text: 'Send Invitation',
                              fullWidth: false,
                              size: ButtonSize.small,
                              prefixIcon: Icons.send_rounded,
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final dbName = _dbNameFromDisplay(role);
                                final dbStatus = status == 'Active'
                                    ? 'active'
                                    : 'pending_assignment';
                                try {
                                  await AuthService().adminCreateUser(
                                    email: emailCtrl.text.trim(),
                                    fullName: nameCtrl.text.trim(),
                                    department: deptCtrl.text.trim().isEmpty
                                        ? 'General'
                                        : deptCtrl.text.trim(),
                                    role: dbName,
                                    status: dbStatus,
                                  );
                                  Navigator.pop(ctx);
                                  _snack(
                                    'Invitation sent to ${nameCtrl.text.trim()}',
                                  );
                                  _loadUsers(); // refresh list from Supabase
                                } on AppAuthException catch (e) {
                                  // Edge Function not deployed � add locally as fallback
                                  final newUser = AppUser(
                                    id: 'u${DateTime.now().millisecondsSinceEpoch}',
                                    fullName: nameCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    role: role,
                                    department: deptCtrl.text.trim().isEmpty
                                        ? 'General'
                                        : deptCtrl.text.trim(),
                                    status: status == 'Active'
                                        ? UserStatus.active
                                        : UserStatus.pending,
                                    lastActive: 'Never',
                                    accountCreated: 'Aug 24, 2026',
                                  );
                                  setState(() {
                                    _users.add(newUser);
                                    UserRoleRepository.addUser(newUser);
                                  });
                                  Navigator.pop(ctx);
                                  _snack(
                                    '${newUser.fullName} added locally � ${e.message}',
                                  );
                                } catch (e) {
                                  Navigator.pop(ctx);
                                  _snack(
                                    'Failed to create user: $e',
                                    icon: Icons.error_outline_rounded,
                                    color: AppColors.danger,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -- view user dialog ------------------------------------------------------
  void _showViewDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) {
        final br = Theme.of(ctx).brightness;
        final textPrimary = AppTheme.textPrimary(br);
        final textSec = AppTheme.textSecondary(br);
        final borderColor = AppTheme.border(br);
        final surfColor = AppTheme.surfaceColor(br);
        return Dialog(
          backgroundColor: surfColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogHeader(
                      ctx,
                      Icons.person_outlined,
                      'User Details',
                      AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _avatar(user, radius: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.roleDisplayName,
                                style: TextStyle(fontSize: 13, color: textSec),
                              ),
                            ],
                          ),
                        ),
                        _statusBadge(user.status, br),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor),
                    const SizedBox(height: 16),
                    _detailRow(ctx, Icons.email_outlined, 'Email', user.email),
                    _detailRow(
                      ctx,
                      Icons.phone_outlined,
                      'Phone',
                      user.phone.isEmpty ? 'Not provided' : user.phone,
                    ),
                    _detailRow(
                      ctx,
                      Icons.business_outlined,
                      'Department',
                      user.department,
                    ),
                    _detailRow(
                      ctx,
                      Icons.access_time_rounded,
                      'Last Active',
                      user.lastActive,
                    ),
                    _detailRow(
                      ctx,
                      Icons.calendar_today_outlined,
                      'Account Created',
                      user.accountCreated,
                    ),
                    if (user.recentActivity.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...user.recentActivity.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 6,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  a,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSec,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -- edit user dialog ------------------------------------------------------
  void _showEditDialog(AppUser user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final deptCtrl = TextEditingController(text: user.department);
    String role = user.roleDisplayName;
    final formKey = GlobalKey<FormState>();
    final roles = _roleDisplayNames;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final br = Theme.of(ctx).brightness;
          return Dialog(
            backgroundColor: AppTheme.surfaceColor(br),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogHeader(
                          ctx,
                          Icons.edit_rounded,
                          'Edit User',
                          AppColors.primary,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: nameCtrl,
                          label: 'Full Name *',
                          hint: 'Full name',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: emailCtrl,
                          label: 'Email Address *',
                          hint: 'email@marketflow.et',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: InputValidators.email,
                        ),
                        const SizedBox(height: 14),
                        _dropdownField(
                          ctx,
                          'Role *',
                          role,
                          roles,
                          (v) => setLocal(() => role = v!),
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: deptCtrl,
                          label: 'Department',
                          hint: 'e.g. Marketing',
                          prefixIcon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            CustomButton(
                              text: 'Save Changes',
                              fullWidth: false,
                              size: ButtonSize.small,
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final newDbRole = _dbNameFromDisplay(role);
                                final roleChanged = newDbRole != user.role;
                                final updated = user.copyWith(
                                  fullName: nameCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  role: newDbRole,
                                  department: deptCtrl.text.trim().isEmpty
                                      ? user.department
                                      : deptCtrl.text.trim(),
                                );
                                // Persist to Supabase.
                                try {
                                  await AuthService().updateUserProfile(
                                    userId: user.id,
                                    role: newDbRole,
                                    status: user.status == UserStatus.pending
                                        ? 'active'
                                        : null,
                                    department: deptCtrl.text.trim().isNotEmpty
                                        ? deptCtrl.text.trim()
                                        : user.department,
                                  );
                                  if (roleChanged) {
                                    AuditLogService.log(
                                      action: 'role_change',
                                      module: 'Users & Roles',
                                      recordId: user.id,
                                      recordName: updated.fullName,
                                      details: {
                                        'old_role': user.role,
                                        'new_role': newDbRole,
                                        'changed_by': AuthService().currentName,
                                      },
                                    );
                                  }
                                } catch (e) {
                                  _snack(
                                    'Failed to save: $e',
                                    icon: Icons.error_outline_rounded,
                                    color: AppColors.danger,
                                  );
                                  return;
                                }
                                setState(() {
                                  final idx = _users.indexWhere(
                                    (u) => u.id == user.id,
                                  );
                                  if (idx != -1) _users[idx] = updated;
                                });
                                Navigator.pop(ctx);
                                _snack(
                                  '${updated.fullName} updated successfully',
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -- toggle active / inactive ----------------------------------------------
  void _toggleStatus(AppUser user) async {
    final newStatus = user.status == UserStatus.active
        ? UserStatus.inactive
        : UserStatus.active;
    final label = newStatus == UserStatus.active ? 'activated' : 'deactivated';
    final dbStatus = newStatus == UserStatus.active ? 'active' : 'deactivated';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${newStatus == UserStatus.active ? 'Activate' : 'Deactivate'} account?',
        ),
        content: Text(
          newStatus == UserStatus.active
              ? 'Activate ${user.fullName} and allow login with the assigned role?'
              : 'Deactivate ${user.fullName}? Their protected access will be revoked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              newStatus == UserStatus.active ? 'Activate' : 'Deactivate',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Update local state immediately for responsive UI.
    setState(() {
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) _users[idx] = user.copyWith(status: newStatus);
    });

    // Persist to Supabase.
    try {
      await AuthService().updateUserProfile(userId: user.id, status: dbStatus);
      AuditLogService.log(
        action: newStatus == UserStatus.active ? 'activate' : 'deactivate',
        module: 'Users & Roles',
        recordId: user.id,
        recordName: user.fullName,
        details: {
          'new_status': dbStatus,
          'changed_by': AuthService().currentName,
        },
      );
    } catch (e) {
      _snack(
        'Failed to update ${user.fullName}: $e',
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
      // Revert local state on failure.
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx != -1) _users[idx] = user;
      });
      return;
    }

    _snack(
      '${user.fullName} has been $label',
      icon: newStatus == UserStatus.active
          ? Icons.check_circle_rounded
          : Icons.cancel_rounded,
      color: newStatus == UserStatus.active
          ? AppColors.success
          : AppColors.warning,
    );
  }

  // -- delete user -----------------------------------------------------------
  void _confirmDelete(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) {
        final br = Theme.of(ctx).brightness;
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(br),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBg(br),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete User',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete ${user.fullName}? '
            'This action cannot be undone.',
            style: TextStyle(color: AppTheme.textPrimary(br)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Soft-delete: deactivate in Supabase, remove from local list.
                try {
                  await AuthService().updateUserProfile(
                    userId: user.id,
                    status: 'deactivated',
                  );
                } catch (_) {
                  // Continue with local removal even if Supabase update fails.
                }
                setState(() => _users.removeWhere((u) => u.id == user.id));
                Navigator.pop(ctx);
                _snack(
                  '${user.fullName} deleted',
                  icon: Icons.delete_rounded,
                  color: AppColors.danger,
                );
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // -- roles & permissions dialog --------------------------------------------
  void _showRolePermissionsDialog(AppRole role) {
    final dynamicRole = _roles.firstWhere(
      (item) => item.key == role.dbKey,
      orElse: () => DynamicRole(
        key: role.dbKey,
        name: role.name,
        isSystem: role.dbKey == 'admin',
        permissions: const [],
      ),
    );
    _showDynamicRoleEditor(dynamicRole);
    return;
    // Legacy matrix dialog retained below for source compatibility.
    // ignore: dead_code
    final perms = UserRoleRepository.getPermissionsForRole(role.dbKey);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final br = Theme.of(ctx).brightness;
          final textSec = AppTheme.textSecondary(br);
          return Dialog(
            backgroundColor: AppTheme.surfaceColor(br),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogHeader(
                      ctx,
                      Icons.security_rounded,
                      '${role.name} � Permissions',
                      role.color,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role.description,
                      style: TextStyle(fontSize: 13, color: textSec),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: _PermissionMatrix(
                          permissions: perms,
                          onChanged: (p) => setLocal(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CustomButton(
                        text: 'Save Changes',
                        fullWidth: false,
                        size: ButtonSize.small,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _snack('Permissions for ${role.name} updated');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteDynamicRole(DynamicRole role) async {
    if (role.isSystem) {
      _snack(
        'The Administrator starter role cannot be deleted.',
        icon: Icons.lock_outline,
        color: AppColors.warning,
      );
      return;
    }

    final assignedUsers = _users.where((user) => user.role == role.key).length;
    if (assignedUsers > 0) {
      _snack(
        'Reassign users before deleting this role.',
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete role?'),
        content: Text('Delete "${role.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await PermissionService.deleteRole(role.key);
      if (!mounted) return;
      setState(() => _roles.removeWhere((item) => item.key == role.key));
      _snack('Role deleted');
    } catch (e) {
      if (!mounted) return;
      _snack(
        'Could not delete role: $e',
        icon: Icons.error_outline,
        color: AppColors.danger,
      );
    }
  }

  Future<void> _showCreateDynamicRole() async {
    final nameCtrl = TextEditingController();
    final selected = <String>{};
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create role'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Role name'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PermissionService.catalog
                        .map(
                          (permission) => FilterChip(
                            label: Text(permission.key),
                            selected: selected.contains(permission.key),
                            onSelected: (value) => setLocal(
                              () => value
                                  ? selected.add(permission.key)
                                  : selected.remove(permission.key),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (save != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await PermissionService.saveRole(
        name: nameCtrl.text,
        permissions: selected.toList(),
      );
      await _loadRoles();
      _snack('Role created');
    } catch (e) {
      _snack(
        'Could not create role: $e',
        icon: Icons.error_outline,
        color: AppColors.danger,
      );
    }
  }

  Future<void> _showDynamicRoleEditor(DynamicRole role) async {
    if (role.isSystem) {
      _snack(
        'The Administrator starter role cannot be edited.',
        icon: Icons.lock_outline,
        color: AppColors.warning,
      );
      return;
    }
    final nameCtrl = TextEditingController(text: role.name);
    final selected = role.permissions.toSet();
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Edit ${role.name} permissions'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PermissionService.catalog
                    .map(
                      (permission) => FilterChip(
                        label: Text(permission.key),
                        selected: selected.contains(permission.key),
                        onSelected: (value) => setLocal(
                          () => value
                              ? selected.add(permission.key)
                              : selected.remove(permission.key),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await PermissionService.saveRole(
        roleKey: role.key,
        name: nameCtrl.text,
        permissions: selected.toList(),
      );
      await _loadRoles();
      _snack('Permissions updated');
    } catch (e) {
      _snack(
        'Could not update permissions: $e',
        icon: Icons.error_outline,
        color: AppColors.danger,
      );
    }
  }

  // -- build -----------------------------------------------------------------
  // CustomScrollView so the page header is pinned via SliverPersistentHeader
  // while the body content scrolls underneath it.
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = AppTheme.backgroundFill(brightness);

    return CustomScrollView(
      slivers: [
        // -- Pinned page header ------------------------------------------
        SliverPersistentHeader(
          pinned: true,
          delegate: _UsersStickyHeaderDelegate(
            brightness: brightness,
            bgColor: bgColor,
            onInvite: AccessService.isAdmin
                ? _showInviteDialog
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Only Administrators can invite users.'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
          ),
        ),

        // -- Scrollable body ---------------------------------------------
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiRow(),
                const SizedBox(height: AppConstants.sectionSpacing),
                _buildTabBar(),
                const SizedBox(height: 16),
                _buildTabContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -- KPI row ---------------------------------------------------------------
  Widget _buildKpiRow() {
    final kpis = [
      _KpiData(
        'Total Users',
        '$_totalUsers',
        Icons.group_outlined,
        AppColors.primary,
      ),
      _KpiData(
        'Active Users',
        '$_activeUsers',
        Icons.check_circle_outline,
        AppColors.success,
      ),
      _KpiData(
        'Administrators',
        '$_admins',
        Icons.admin_panel_settings_outlined,
        AppColors.info,
      ),
      _KpiData(
        'Pending Invitations',
        '$_pending',
        Icons.schedule_outlined,
        AppColors.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final cols = c.maxWidth >= 800 ? 4 : (c.maxWidth >= 500 ? 2 : 1);
        final w = (c.maxWidth - (cols - 1) * AppConstants.itemSpacing) / cols;
        return Wrap(
          spacing: AppConstants.itemSpacing,
          runSpacing: AppConstants.itemSpacing,
          children: kpis
              .map(
                (k) => SizedBox(
                  width: w,
                  child: _KpiCard(data: k),
                ),
              )
              .toList(),
        );
      },
    );
  }

  // -- tab bar ---------------------------------------------------------------
  Widget _buildTabBar() {
    final br = Theme.of(context).brightness;
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: TabBar(
        controller: _tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppTheme.textSecondary(br),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primaryLight.withValues(
            alpha: br == Brightness.dark ? 0.18 : 1.0,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'User Management'),
          Tab(text: 'Roles & Permissions'),
          Tab(text: 'Recent Activity'),
          Tab(text: 'Audit Log'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return [
      _buildUserManagement(),
      _buildRolesAndPermissions(),
      _buildRecentActivity(),
      _AuditLogTab(),
    ][_tab.index];
  }

  // -- user management tab ---------------------------------------------------
  Widget _buildUserManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserSections(),
        const SizedBox(height: 14),
        _buildToolbar(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (ctx, c) {
            if (c.maxWidth >= AppConstants.tabletBreakpoint - 240) {
              return _buildDesktopTable();
            }
            return _buildMobileCardList();
          },
        ),
      ],
    );
  }

  Widget _buildUserSections() {
    final br = Theme.of(context).brightness;
    const sections = ['All Users', 'Pending Users', 'Deactivated Users'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sections.map((section) {
        final selected = _userSection == section;
        final count = section == 'All Users'
            ? _users.length
            : section == 'Pending Users'
            ? _pending
            : _users.where((u) => u.status == UserStatus.inactive).length;
        return ChoiceChip(
          label: Text('$section ($count)'),
          selected: selected,
          onSelected: (_) => setState(() => _userSection = section),
          selectedColor: AppColors.primaryLight,
          labelStyle: TextStyle(
            color: selected ? AppColors.primary : AppTheme.textSecondary(br),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToolbar() {
    // Role filter items: 'All' + DB strings displayed as display names
    final roleFilterItems = ['All', ..._roleDisplayNames];
    final statuses = ['All', 'Active', 'Deactivated', 'Pending'];
    final sorts = ['Name', 'Role', 'Department', 'Status'];

    final filters = [
      _FilterChip(
        label: 'Role',
        value: _roleFilter,
        items: roleFilterItems,
        onChanged: (v) => setState(() {
          _roleFilter = v;
        }),
      ),
      _FilterChip(
        label: 'Dept',
        value: _deptFilter,
        items: _allDepts,
        onChanged: (v) => setState(() {
          _deptFilter = v;
        }),
      ),
      _FilterChip(
        label: 'Status',
        value: _statusFilter,
        items: statuses,
        onChanged: (v) => setState(() {
          _statusFilter = v;
        }),
      ),
      _FilterChip(
        label: 'Sort',
        value: _sortBy,
        items: sorts,
        onChanged: (v) => setState(() {
          _sortBy = v;
        }),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _searchCtrl,
          hint: 'Search users by name, email, or department...',
          prefixIcon: Icons.search_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: filters),
      ],
    );
  }

  // -- desktop table ---------------------------------------------------------
  Widget _buildDesktopTable() {
    final br = Theme.of(context).brightness;
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    final tableHeader = AppTheme.tableHeaderColor(br);
    final textSec = AppTheme.textSecondary(br);
    final users = _filtered;

    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tableHeader,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _ColHeader('User', textSec)),
                Expanded(flex: 3, child: _ColHeader('Email', textSec)),
                Expanded(flex: 2, child: _ColHeader('Phone', textSec)),
                Expanded(flex: 2, child: _ColHeader('Role', textSec)),
                Expanded(flex: 2, child: _ColHeader('Department', textSec)),
                Expanded(flex: 2, child: _ColHeader('Status', textSec)),
                Expanded(flex: 2, child: _ColHeader('Registered', textSec)),
                SizedBox(width: 120, child: _ColHeader('Actions', textSec)),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No users match the current filters.',
                  style: TextStyle(color: textSec),
                ),
              ),
            )
          else
            ...users.asMap().entries.map((e) {
              final u = e.value;
              return _DesktopUserRow(
                user: u,
                isLast: e.key == users.length - 1,
                onView: () => _showViewDialog(u),
                onEdit: () => _showEditDialog(u),
                onToggle: () => _toggleStatus(u),
                onDelete: () => _confirmDelete(u),
              );
            }),
        ],
      ),
    );
  }

  // -- mobile card list ------------------------------------------------------
  Widget _buildMobileCardList() {
    final br = Theme.of(context).brightness;
    final users = _filtered;
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No users match the current filters.',
            style: TextStyle(color: AppTheme.textSecondary(br)),
          ),
        ),
      );
    }
    return Column(
      children: users
          .map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MobileUserCard(
                user: u,
                onView: () => _showViewDialog(u),
                onEdit: () => _showEditDialog(u),
                onToggle: () => _toggleStatus(u),
                onDelete: () => _confirmDelete(u),
              ),
            ),
          )
          .toList(),
    );
  }

  // -- roles & permissions tab -----------------------------------------------
  Widget _buildRolesAndPermissions() {
    final br = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    final roles = _roles
        .map(
          (role) => AppRole(
            name: role.name,
            dbKey: role.key,
            userCount: _users.where((user) => user.role == role.key).length,
            color: role.isSystem ? AppColors.primary : AppColors.info,
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (AccessService.isAdmin)
          Align(
            alignment: Alignment.centerRight,
            child: CustomButton(
              text: 'Add role',
              fullWidth: false,
              size: ButtonSize.small,
              prefixIcon: Icons.add_rounded,
              onPressed: _showCreateDynamicRole,
            ),
          ),
        Text(
          'Roles',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, c) {
            final cols = c.maxWidth >= 800 ? 2 : 1;
            final w =
                (c.maxWidth - (cols - 1) * AppConstants.itemSpacing) / cols;
            return Wrap(
              spacing: AppConstants.itemSpacing,
              runSpacing: AppConstants.itemSpacing,
              children: roles
                  .map(
                    (r) => SizedBox(
                      width: w,
                      child: _RoleCard(
                        role: r,
                        userCount: _users
                            .where((u) => u.role == r.dbKey)
                            .length,
                        onView: () => _showRolePermissionsDialog(r),
                        onEdit: () => _showRolePermissionsDialog(r),
                        permissionKeys: _roles
                            .firstWhere(
                              (role) => role.key == r.dbKey,
                              orElse: () => const DynamicRole(
                                key: 'admin',
                                name: 'Administrator',
                                isSystem: true,
                                permissions: [],
                              ),
                            )
                            .permissions,
                        onDelete: r.dbKey == 'admin'
                            ? null
                            : () => _deleteDynamicRole(
                                _roles.firstWhere(
                                  (role) => role.key == r.dbKey,
                                ),
                              ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Permission Matrix � Administrator (demo)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select a role above to view and edit its permissions.',
          style: TextStyle(fontSize: 13, color: textSec),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: surfColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: _PermissionMatrix(
            permissions: UserRoleRepository.getAdminPermissions(),
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }

  // -- recent activity tab ---------------------------------------------------
  Widget _buildRecentActivity() {
    final br = Theme.of(context).brightness;
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    final divColor = AppTheme.divider(br);
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final entries = UserRoleRepository.recentActivity;

    return Container(
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: entries.asMap().entries.map((e) {
          final entry = e.value;
          final isLast = e.key == entries.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: entry.iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(entry.icon, color: entry.iconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.description,
                            style: TextStyle(fontSize: 14, color: textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.timestamp,
                            style: TextStyle(fontSize: 12, color: textSec),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1, color: divColor),
            ],
          );
        }).toList(),
      ),
    );
  }

  // -- shared dialog helpers -------------------------------------------------
  Widget _dialogHeader(
    BuildContext ctx,
    IconData icon,
    String title,
    Color color,
  ) {
    final textPrimary = AppTheme.textPrimary(Theme.of(ctx).brightness);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _dropdownField(
    BuildContext ctx,
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final br = Theme.of(ctx).brightness;
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final inputFill = AppTheme.inputFill(br);
    final borderColor = AppTheme.border(br);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          dropdownColor: AppTheme.surfaceColor(br),
          style: TextStyle(fontSize: 14, color: textPrimary),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: TextStyle(color: textPrimary)),
                ),
              )
              .toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.8,
              ),
            ),
            hintStyle: TextStyle(color: textSec),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    final br = Theme.of(ctx).brightness;
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSec),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontSize: 13, color: textSec)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(AppUser u, {double radius = 20}) {
    final color = _roleColor(u.role);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        u.initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.6,
        ),
      ),
    );
  }

  Widget _statusBadge(UserStatus s, Brightness br) {
    switch (s) {
      case UserStatus.active:
        return _badge('Active', AppColors.success, AppTheme.successBg(br));
      case UserStatus.inactive:
        return _badge(
          'Deactivated',
          AppTheme.textSecondary(br),
          AppTheme.surfaceVariant(br),
        );
      case UserStatus.pending:
        return _badge(
          'Pending Assignment',
          AppColors.warning,
          AppTheme.warningBg(br),
        );
    }
  }

  Widget _badge(String label, Color text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
      case 'marketing_manager':
      case 'marketing_clerk':
      default:
        return AppColors.textSecondary;
    }
  }
}

// -----------------------------------------------------------------------------
// _UsersStickyHeaderDelegate � pinned page header (matches CampaignListScreen)
// -----------------------------------------------------------------------------

class _UsersStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Brightness brightness;
  final Color bgColor;
  final VoidCallback onInvite;

  static const double _height = 80.0;

  const _UsersStickyHeaderDelegate({
    required this.brightness,
    required this.bgColor,
    required this.onInvite,
  });

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_UsersStickyHeaderDelegate old) =>
      old.brightness != brightness ||
      old.bgColor != bgColor ||
      old.onInvite != onInvite;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: bgColor,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: bgColor,
          border: overlapsContent
              ? Border(
                  bottom: BorderSide(
                    color: AppTheme.border(brightness),
                    width: 1,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: 12,
        ),
        child: _UsersPageHeaderBar(onInvite: onInvite),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _UsersPageHeaderBar � icon badge + title + subtitle + Invite User button
// -----------------------------------------------------------------------------

class _UsersPageHeaderBar extends StatelessWidget {
  final VoidCallback onInvite;
  const _UsersPageHeaderBar({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec = AppTheme.textSecondary(brightness);

    return LayoutBuilder(
      builder: (context, cst) {
        final narrow = cst.maxWidth < 500;

        final titleBlock = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: const Icon(
                Icons.manage_accounts_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Users & Roles',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage team members, roles, and access permissions.',
                    style: TextStyle(fontSize: 12, color: textSec),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        );

        final inviteButton = ElevatedButton.icon(
          onPressed: onInvite,
          icon: const Icon(Icons.person_add_outlined, size: 15),
          label: narrow ? const Text('Invite') : const Text('Invite User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            inviteButton,
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// _KpiData + _KpiCard
// -----------------------------------------------------------------------------

class _KpiData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: Icon(data.icon, size: 22, color: data.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  style: TextStyle(fontSize: 12, color: textSec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _ColHeader
// -----------------------------------------------------------------------------

class _ColHeader extends StatelessWidget {
  final String text;
  final Color color;
  const _ColHeader(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }
}

// -----------------------------------------------------------------------------
// _FilterChip � inline dropdown filter label
// -----------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _FilterChip({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final isActive = value != 'All';

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: AppTheme.surfaceColor(br),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: BorderSide(color: borderColor),
      ),
      itemBuilder: (_) => items
          .map(
            (i) => PopupMenuItem(
              value: i,
              child: Text(
                i,
                style: TextStyle(fontSize: 13, color: textPrimary),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryLight.withValues(
                  alpha: br == Brightness.dark ? 0.18 : 1.0,
                )
              : surfColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.4)
                : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.primary : textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive ? AppColors.primary : textSec,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _DesktopUserRow
// -----------------------------------------------------------------------------

class _DesktopUserRow extends StatefulWidget {
  final AppUser user;
  final bool isLast;
  final VoidCallback onView, onEdit, onToggle, onDelete;
  const _DesktopUserRow({
    required this.user,
    required this.isLast,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  @override
  State<_DesktopUserRow> createState() => _DesktopUserRowState();
}

class _DesktopUserRowState extends State<_DesktopUserRow> {
  bool _hovered = false;

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
      case 'marketing_manager':
      case 'marketing_clerk':
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _statusBadge(UserStatus s, Brightness br) {
    switch (s) {
      case UserStatus.active:
        return _badge(
          'Active',
          AppColors.success,
          AppTheme.successBg(br),
          Icons.check_circle_outline,
        );
      case UserStatus.inactive:
        return _badge(
          'Deactivated',
          AppTheme.textSecondary(br),
          AppTheme.surfaceVariant(br),
          Icons.remove_circle_outline,
        );
      case UserStatus.pending:
        return _badge(
          'Pending Assignment',
          AppColors.warning,
          AppTheme.warningBg(br),
          Icons.schedule_outlined,
        );
    }
  }

  Widget _badge(String label, Color text, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final divColor = AppTheme.divider(br);
    final hoverColor = AppTheme.tableRowHover(br);
    final u = widget.user;
    final rc = _roleColor(u.role);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        color: _hovered ? hoverColor : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: rc.withValues(alpha: 0.15),
                          child: Text(
                            u.initials,
                            style: TextStyle(
                              color: rc,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            u.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      u.email,
                      style: TextStyle(fontSize: 13, color: textSec),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      u.phone.isEmpty ? '—' : u.phone,
                      style: TextStyle(fontSize: 12, color: textSec),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: rc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        u.roleDisplayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: rc,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      u.department,
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(flex: 2, child: _statusBadge(u.status, br)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      u.accountCreated,
                      style: TextStyle(fontSize: 12, color: textSec),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconBtn(
                          Icons.visibility_outlined,
                          'View',
                          AppColors.primary,
                          widget.onView,
                        ),
                        _iconBtn(
                          Icons.edit_outlined,
                          'Edit',
                          AppColors.info,
                          widget.onEdit,
                        ),
                        _iconBtn(
                          u.status == UserStatus.active
                              ? Icons.block_outlined
                              : Icons.check_circle_outline,
                          u.status == UserStatus.active
                              ? 'Deactivate'
                              : 'Activate',
                          u.status == UserStatus.active
                              ? AppColors.warning
                              : AppColors.success,
                          widget.onToggle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.isLast) Divider(height: 1, color: divColor),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _MobileUserCard
// -----------------------------------------------------------------------------

class _MobileUserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onView, onEdit, onToggle, onDelete;
  const _MobileUserCard({
    required this.user,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  Color _rc(String role) {
    switch (role) {
      case 'admin':
      case 'marketing_manager':
      case 'marketing_clerk':
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    final divColor = AppTheme.divider(br);
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final u = user;
    final rc = _rc(u.role);

    Widget statusBadge(UserStatus s) {
      switch (s) {
        case UserStatus.active:
          return _badge('Active', AppColors.success, AppTheme.successBg(br));
        case UserStatus.inactive:
          return _badge(
            'Deactivated',
            AppTheme.textSecondary(br),
            AppTheme.surfaceVariant(br),
          );
        case UserStatus.pending:
          return _badge(
            'Pending Assignment',
            AppColors.warning,
            AppTheme.warningBg(br),
          );
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: rc.withValues(alpha: 0.15),
                child: Text(
                  u.initials,
                  style: TextStyle(
                    color: rc,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      u.email,
                      style: TextStyle(fontSize: 12, color: textSec),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              statusBadge(u.status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: divColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoChip(
                  Icons.work_outline_rounded,
                  u.roleDisplayName,
                  rc,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoChip(
                  Icons.business_outlined,
                  u.department,
                  textSec,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoChip(
            Icons.access_time_rounded,
            'Last active: ${u.lastActive}',
            textSec,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: BorderSide(
                      color: AppColors.info.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    u.status == UserStatus.active
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    size: 14,
                  ),
                  label: Text(
                    u.status == UserStatus.active ? 'Deactivate' : 'Activate',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: u.status == UserStatus.active
                        ? AppColors.warning
                        : AppColors.success,
                    side: BorderSide(
                      color:
                          (u.status == UserStatus.active
                                  ? AppColors.warning
                                  : AppColors.success)
                              .withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// _RoleCard
// -----------------------------------------------------------------------------

class _RoleCard extends StatelessWidget {
  final AppRole role;
  final int userCount;
  final VoidCallback onView, onEdit;
  final VoidCallback? onDelete;
  final List<String> permissionKeys;
  const _RoleCard({
    required this.role,
    required this.userCount,
    required this.onView,
    required this.onEdit,
    this.permissionKeys = const [],
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final surfColor = AppTheme.surfaceColor(br);
    final borderColor = AppTheme.border(br);
    final textPrimary = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: role.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield_outlined, color: role.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '$userCount user${userCount != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: textSec),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (role.description.isNotEmpty)
            Text(
              role.description,
              style: TextStyle(fontSize: 13, color: textSec),
            ),
          if (role.permissionSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: role.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role.permissionSummary,
                style: TextStyle(
                  fontSize: 12,
                  color: role.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (permissionKeys.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: permissionKeys
                  .map(
                    (key) => Chip(
                      label: Text(key, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Permissions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: BorderSide(
                      color: AppColors.info.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete role',
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.danger,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// _PermissionMatrix � responsive, never overflows
// -----------------------------------------------------------------------------

class _PermissionMatrix extends StatefulWidget {
  final List<ModulePermission> permissions;
  final ValueChanged<ModulePermission> onChanged;
  const _PermissionMatrix({required this.permissions, required this.onChanged});
  @override
  State<_PermissionMatrix> createState() => _PermissionMatrixState();
}

class _PermissionMatrixState extends State<_PermissionMatrix> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final narrow = c.maxWidth < 500;
        return narrow ? _buildCards(ctx) : _buildTable(ctx);
      },
    );
  }

  Widget _buildTable(BuildContext context) {
    final br = Theme.of(context).brightness;
    final surfVar = AppTheme.surfaceVariant(br);
    final textSec = AppTheme.textSecondary(br);
    final textPrimary = AppTheme.textPrimary(br);

    return Column(
      children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: surfVar,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Module',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSec,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'View',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSec,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Create',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSec,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSec,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSec,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Approve',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSec,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Submit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSec,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...widget.permissions.asMap().entries.map((e) {
          final p = e.value;
          final even = e.key.isEven;
          return Container(
            color: even ? Colors.transparent : surfVar.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    p.module,
                    style: TextStyle(fontSize: 13, color: textPrimary),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _perm(
                      p.view,
                      (v) => setState(() {
                        p.view = v;
                        widget.onChanged(p);
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _perm(
                      p.create,
                      (v) => setState(() {
                        p.create = v;
                        widget.onChanged(p);
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _perm(
                      p.edit,
                      (v) => setState(() {
                        p.edit = v;
                        widget.onChanged(p);
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _perm(
                      p.delete,
                      (v) => setState(() {
                        p.delete = v;
                        widget.onChanged(p);
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _perm(
                      p.approve,
                      (v) => setState(() {
                        p.approve = v;
                        widget.onChanged(p);
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _perm(
                      p.submit,
                      (v) => setState(() {
                        p.submit = v;
                        widget.onChanged(p);
                      }),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCards(BuildContext context) {
    final br = Theme.of(context).brightness;
    final surfVar = AppTheme.surfaceVariant(br);
    final textPrimary = AppTheme.textPrimary(br);
    final textDark = AppTheme.textPrimary(br);

    return Column(
      children: widget.permissions
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfVar,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.module,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        _permLabel(
                          'View',
                          p.view,
                          (v) => setState(() {
                            p.view = v;
                            widget.onChanged(p);
                          }),
                          textDark,
                        ),
                        _permLabel(
                          'Create',
                          p.create,
                          (v) => setState(() {
                            p.create = v;
                            widget.onChanged(p);
                          }),
                          textDark,
                        ),
                        _permLabel(
                          'Edit',
                          p.edit,
                          (v) => setState(() {
                            p.edit = v;
                            widget.onChanged(p);
                          }),
                          textDark,
                        ),
                        _permLabel(
                          'Delete',
                          p.delete,
                          (v) => setState(() {
                            p.delete = v;
                            widget.onChanged(p);
                          }),
                          textDark,
                        ),
                        _permLabel(
                          'Approve',
                          p.approve,
                          (v) => setState(() {
                            p.approve = v;
                            widget.onChanged(p);
                          }),
                          textDark,
                        ),
                        _permLabel(
                          'Submit',
                          p.submit,
                          (v) => setState(() {
                            p.submit = v;
                            widget.onChanged(p);
                          }),
                          textDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _perm(bool val, ValueChanged<bool> onChanged) {
    return Checkbox(
      value: val,
      onChanged: (v) => onChanged(v ?? false),
      activeColor: AppColors.primary,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  Widget _permLabel(
    String label,
    bool val,
    ValueChanged<bool> onChanged,
    Color textColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: val,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.primary,
        ),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AuditLogTab — shows real audit entries from Supabase with filters
// ─────────────────────────────────────────────────────────────────────────────

class _AuditLogTab extends StatefulWidget {
  const _AuditLogTab();
  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  List<AuditLogEntry> _entries = [];
  bool _loading = true;
  String _searchQuery = '';
  String _actionFilter = '';
  String _moduleFilter = '';

  static const List<String> _actions = [
    '',
    'create',
    'update',
    'delete',
    'approve',
    'reject',
    'submit',
    'login',
    'logout',
    'activate',
    'deactivate',
    'role_change',
    'changes_requested',
  ];

  static const List<String> _modules = [
    '',
    'Campaigns',
    'Customers',
    'Leads',
    'Opportunities',
    'Budget',
    'Promotions',
    'Content',
    'Influencers',
    'Users & Roles',
    'Auth',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await AuditLogService.search(
      query: _searchQuery,
      actionFilter: _actionFilter.isEmpty ? null : _actionFilter,
      moduleFilter: _moduleFilter.isEmpty ? null : _moduleFilter,
      limit: 200,
    );
    if (mounted)
      setState(() {
        _entries = entries;
        _loading = false;
      });
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'create':
        return AppColors.success;
      case 'approve':
        return AppColors.success;
      case 'activate':
        return AppColors.success;
      case 'login':
        return AppColors.info;
      case 'delete':
        return AppColors.danger;
      case 'reject':
        return AppColors.danger;
      case 'deactivate':
        return AppColors.danger;
      case 'submit':
        return AppColors.info;
      case 'update':
        return AppColors.warning;
      case 'role_change':
        return AppColors.primary;
      case 'changes_requested':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'approve':
        return Icons.check_circle_outline;
      case 'reject':
        return Icons.cancel_outlined;
      case 'submit':
        return Icons.send_outlined;
      case 'login':
        return Icons.login_outlined;
      case 'logout':
        return Icons.logout_outlined;
      case 'activate':
        return Icons.person_outlined;
      case 'deactivate':
        return Icons.person_off_outlined;
      case 'role_change':
        return Icons.manage_accounts_outlined;
      case 'changes_requested':
        return Icons.edit_note_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final br = Theme.of(context).brightness;
    final textPri = AppTheme.textPrimary(br);
    final textSec = AppTheme.textSecondary(br);
    final cardColor = AppTheme.cardColor(br);
    final borderColor = AppTheme.border(br);
    final inputFill = AppTheme.inputFill(br);

    return Container(
      padding: const EdgeInsets.all(AppConstants.cardPadding),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit Log',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                  Text(
                    'Activity history for all users',
                    style: TextStyle(fontSize: 12, color: textSec),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Filters ──
          LayoutBuilder(
            builder: (_, bc) {
              final narrow = bc.maxWidth < 600;
              final searchBox = SizedBox(
                height: 38,
                child: TextField(
                  onChanged: (v) {
                    _searchQuery = v;
                    _load();
                  },
                  style: TextStyle(fontSize: 13, color: textPri),
                  decoration: InputDecoration(
                    hintText: 'Search user, action, record…',
                    hintStyle: TextStyle(color: textSec, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: textSec),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              );
              final actionDd = _buildFilterDrop(
                'Action',
                _actionFilter,
                _actions,
                (v) {
                  setState(() => _actionFilter = v ?? '');
                  _load();
                },
                inputFill,
                borderColor,
                textPri,
                textSec,
              );
              final moduleDd = _buildFilterDrop(
                'Module',
                _moduleFilter,
                _modules,
                (v) {
                  setState(() => _moduleFilter = v ?? '');
                  _load();
                },
                inputFill,
                borderColor,
                textPri,
                textSec,
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    searchBox,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: actionDd),
                        const SizedBox(width: 8),
                        Expanded(child: moduleDd),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: searchBox),
                  const SizedBox(width: 8),
                  SizedBox(width: 140, child: actionDd),
                  const SizedBox(width: 8),
                  SizedBox(width: 140, child: moduleDd),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 4),

          // ── Entries ──
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_outlined,
                      size: 40,
                      color: textSec.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No audit entries found.',
                      style: TextStyle(color: textSec, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _entries.map((e) {
                final color = _actionColor(e.action);
                final icon = _actionIcon(e.action);
                final timeStr =
                    '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}  ${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant(br),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 15, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    e.action.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    e.module,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              e.recordName.isNotEmpty
                                  ? '${e.userName}  ·  ${e.recordName}'
                                  : e.userName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textPri,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 11, color: textSec),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterDrop(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    Color fill,
    Color border,
    Color textPri,
    Color textSec,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textSec,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: fill,
              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textSec),
              style: TextStyle(fontSize: 13, color: textPri),
              items: items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        i.isEmpty ? 'All' : i,
                        style: TextStyle(fontSize: 13, color: textPri),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
