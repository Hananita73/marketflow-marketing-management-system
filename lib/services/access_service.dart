import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../models/user_role_models.dart';
import 'permission_service.dart';
import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AccessService
//
// Central RBAC gateway. Every screen, route, and CRUD action asks this class.
//
// ROLES (5):
//   admin              – Full system access
//   marketing_manager  – View + Approve only, NO create/edit
//   marketing_clerk    – Create / Edit / Submit for approval
//   content_creator    – Content + Influencers create/edit/submit
//   viewer             – Broad read-only, no mutations
//
// FAIL-OPEN: while the profile has not loaded yet (cold start / offline) every
// check returns true so the app keeps working. Once the profile is known the
// permission matrix is enforced.
// ─────────────────────────────────────────────────────────────────────────────

class AccessService {
  AccessService._();

  // ── Route → module name map ──────────────────────────────────────────────
  static const Map<String, String> routeModules = {
    '/dashboard':     'Dashboard',
    '/campaigns':     'Campaigns',
    '/customers':     'Customers',
    '/leads':         'Leads',
    '/opportunities': 'Opportunities',
    '/influencers':   'Influencers',
    '/content':       'Content',
    '/promotions':    'Promotions',
    '/budget':        'Budget',
    '/communications':'Communications',
    '/automation':    'Automation',
    '/reports':       'Reports',
    '/notifications': 'Notifications',
    '/users':         'Users & Roles',
    '/profile':       'Profile',
    '/settings':      'Settings',
  };

  static String? moduleForRoute(String route) {
    String? best;
    for (final prefix in routeModules.keys) {
      if (route == prefix || route.startsWith('$prefix/')) {
        if (best == null || prefix.length > best.length) best = prefix;
      }
    }
    return best == null ? null : routeModules[best];
  }

  // ── Guard helpers (show snackbar + return false on denial) ────────────────

  static bool requireCreate(BuildContext context, String module) =>
      _require(context, 'create records in', module, canCreate(module));

  static bool requireEdit(BuildContext context, String module) =>
      _require(context, 'edit records in', module, canEdit(module));

  static bool requireDelete(BuildContext context, String module) =>
      _require(context, 'delete records in', module, canDelete(module));

  static bool requireApprove(BuildContext context, String module) =>
      _require(context, 'approve items in', module, canApprove(module));

  static bool requireSubmit(BuildContext context, String module) =>
      _require(context, 'submit items in', module, canSubmit(module));

  /// Convenience: create-or-edit depending on [isEdit].
  static bool requireSave(BuildContext context, bool isEdit, String module) =>
      isEdit ? requireEdit(context, module) : requireCreate(context, module);

  static bool _require(
      BuildContext context, String action, String module, bool permitted) {
    if (permitted) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Your role does not have permission to $action $module.'),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
    return false;
  }

  // ── Permission checks ─────────────────────────────────────────────────────

  static bool canView(String module)    => _check(module, PermissionType.view);
  static bool canCreate(String module)  => _check(module, PermissionType.create);
  static bool canEdit(String module)    => _check(module, PermissionType.edit);
  static bool canDelete(String module)  => _check(module, PermissionType.delete);
  static bool canApprove(String module) => _check(module, PermissionType.approve);
  static bool canSubmit(String module)  => _check(module, PermissionType.submit);

  /// Fine-grained action check used by buttons and cards, for example
  /// `campaign.add` or `user.assign_role`.
  static bool canAction(String permissionKey) =>
      AuthService().hasAction(permissionKey);

  static String actionKey(String module, PermissionType type) =>
      PermissionService.keyFor(module, type);

  static bool _check(String module, PermissionType type) {
    final auth = AuthService();
    if (auth.currentProfile == null) return false;
    return auth.hasPermission(module, type);
  }

  // ── Role identity helpers ─────────────────────────────────────────────────

  static String get currentRole => AuthService().currentRole;

  static bool get isAdmin          => currentRole == AppConstants.dbRoleAdmin;
  static bool get isManager        => currentRole == AppConstants.dbRoleMarketingManager;
  static bool get isClerk          => currentRole == AppConstants.dbRoleMarketingClerk;
  static bool get isContentCreator => currentRole == AppConstants.dbRoleContentCreator;
  static bool get isViewer         => currentRole == AppConstants.dbRoleViewer;

  /// Approval is permission-driven. The Administrator starter role and any
  /// custom role with an approve permission can approve records.
  static bool get isApprover =>
      canApprove('Campaigns') ||
      canApprove('Budget') ||
      canApprove('Promotions');

  /// True when the current user can submit items for approval.
  static bool get isSubmitter =>
      canSubmit('Campaigns') || canSubmit('Content');
}
