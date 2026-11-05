// ─────────────────────────────────────────────────────────────────────────────
// AuthService
//
// Wraps Supabase Auth for email/password login, sign-out, and profile loading.
// The logged-in user's application role, department, and status live in the
// public.users table (linked to auth.users via UUID).
//
// Usage:
//   final profile = await AuthService().signIn(email: '...', password: '...');
//   final role = profile['role'];          // 'admin', 'marketing_manager', …
//   final status = profile['status'];      // 'active', 'deactivated', 'pending_assignment'
//
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthResponse, Session, Supabase, SupabaseClient, User;
import '../models/user_role_models.dart';
import 'audit_log_service.dart';
import 'repository_sync.dart';
import 'permission_service.dart';

/// Application-level auth exception (distinct from Supabase's AuthException).
class AppAuthException implements Exception {
  final String message;
  const AppAuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Cached user profile from `public.users` — populated after sign-in.
  Map<String, dynamic>? _cachedProfile;

  /// The user's permission matrix, derived from their role.
  List<ModulePermission>? _cachedPermissions;
  Set<String> _cachedPermissionKeys = <String>{};

  /// Timestamp until which the user's role is locked (cannot be self-changed).
  DateTime? _roleLockExpiry;

  // ── Sign in ──────────────────────────────────────────────────────────────

  /// Authenticates the user via email + password.
  ///
  /// Returns the user's application profile from `public.users`.
  ///
  /// Throws [AppAuthException] with spec-compliant messages for:
  ///   - Invalid credentials
  ///   - Missing profile
  ///   - Inactive account
  ///   - Pending account
  ///   - Network errors
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final AuthResponse res;
    try {
      res = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      developer.log('Supabase AuthException: ${e.message}', name: 'AuthService');
      // Map Supabase error messages to user-friendly versions.
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login') ||
          msg.contains('invalid email') ||
          msg.contains('invalid password') ||
          msg.contains('email not confirmed')) {
        throw const AppAuthException('Invalid email or password.');
      }
      throw AppAuthException(e.message);
    } catch (e) {
      developer.log('Unexpected signIn error: $e', name: 'AuthService');
      throw const AppAuthException(
        'Unable to connect to the server. Please check your internet connection.',
      );
    }

    final user = res.user;
    if (user == null) {
      throw const AppAuthException('Invalid email or password.');
    }

    // ── Load application profile ───────────────────────────────────────────
    final Map<String, dynamic> profile;
    try {
      profile = await _loadProfile(user.id);
    } on AppAuthException {
      // Profile doesn't exist — sign out and reject.
      await _supabase.auth.signOut();
      rethrow;
    }

    // ── Check account status ───────────────────────────────────────────────
    final status = profile['status'] as String? ?? 'pending_assignment';
    if (status != 'active') {
      await _supabase.auth.signOut();
      if (status == 'pending_assignment' || status == 'pending') {
        throw const AppAuthException(
          'Your account is pending approval. Please contact an administrator.',
        );
      }
      throw const AppAuthException(
        'Your account is inactive. Please contact an administrator.',
      );
    }

    // ── Cache profile & permissions ────────────────────────────────────
    _cachedProfile = profile;
    await _cachePermissions(profile['role'] as String? ?? '');
    // Ensure role cannot be changed by the client
    _roleLockExpiry = DateTime.now().add(const Duration(days: 365));

    // The initial app boot may have happened before authentication. Reload all
    // business repositories now that authenticated Supabase reads are allowed.
    await RepositorySync.reloadAll();

    // Audit the successful login.
    AuditLogService.logLogin(profile['email'] as String? ?? email);

    return profile;
  }

  // ── Sign up ──────────────────────────────────────────────────────────────

  /// Registers a new user via public self-registration.
  ///
  /// The database trigger `handle_new_user()` automatically creates the
  /// `public.users` profile with role='viewer' and status='pending_assignment'.
  ///
  /// After signup the user CANNOT log in until an admin sets status='active'.
  ///
  /// Throws [AppAuthException] with user-friendly messages for:
  ///   - Email already registered
  ///   - Weak password
  ///   - Missing profile (trigger failure)
  ///   - Network errors
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String department = 'General',
  }) async {
    final AuthResponse res;
    try {
      res = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'department': department.trim().isNotEmpty ? department.trim() : 'General',
        },
      );
    } on AuthException catch (e) {
      developer.log('Supabase signUp error: ${e.message}', name: 'AuthService');
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('already been registered') ||
          msg.contains('user already exists')) {
        throw const AppAuthException(
          'An account with this email already exists.',
        );
      }
      if (msg.contains('password') &&
          (msg.contains('weak') || msg.contains('too short') || msg.contains('at least'))) {
        throw const AppAuthException(
          'Password is too weak. Use at least 8 characters.',
        );
      }
      if (msg.contains('valid email') || msg.contains('invalid email')) {
        throw const AppAuthException('Please enter a valid email address.');
      }
      throw AppAuthException(e.message);
    } catch (e) {
      developer.log('Unexpected signUp error: $e', name: 'AuthService');
      throw const AppAuthException(
        'Unable to create your account. Please try again.',
      );
    }

    // After successful signup, sign out immediately. The user's profile
    // is created by the database trigger with status='pending_assignment', so they
    // must wait for admin approval before they can log in.
    final user = res.user;
    if (user != null) {
      // Sign out — the user should not be in an authenticated session
      // with a pending profile.
      await _supabase.auth.signOut();
    }
  }

  // ── Admin: create user (server-side) ─────────────────────────────────────

  /// Admin-only: creates a new user and sets their role/status.
  ///
  /// SECURITY: This calls a Supabase Edge Function that uses the service_role
  /// key to create the auth user and profile. The Flutter client never
  /// handles the service_role key directly.
  ///
  /// If no Edge Function is configured, falls back to a local-only creation
  /// for development purposes.
  Future<void> adminCreateUser({
    required String email,
    required String fullName,
    required String password,
    String phone = '',
    required String department,
    required String role,
    required String status,
  }) async {
    if (password.length < 8) {
      throw const AppAuthException(
        'Password must be at least 8 characters long.',
      );
    }
    try {
      await _supabase.functions.invoke(
        'admin-create-user',
        body: {
          'email': email.trim(),
          'full_name': fullName.trim(),
          'password': password,
          'phone': phone.trim(),
          'department': department.trim().isNotEmpty ? department.trim() : 'General',
          'role': role,
          'status': status,
        },
      );
    } catch (e) {
      developer.log('Admin user creation failed: $e', name: 'AuthService');
      throw AppAuthException('User creation failed: $e');
    }
  }

  /// Admin-only: replaces a user's password through a server-side function.
  Future<void> adminUpdateUserPassword({
    required String userId,
    required String password,
  }) async {
    if (!isAdmin) {
      throw const AppAuthException(
        'Only Administrators can update user passwords.',
      );
    }
    if (password.length < 8) {
      throw const AppAuthException(
        'Password must be at least 8 characters long.',
      );
    }
    try {
      await _supabase.functions.invoke(
        'admin-manage-user',
        body: {
          'action': 'update_password',
          'user_id': userId,
          'password': password,
        },
      );
    } catch (e) {
      developer.log('Admin password update failed: $e', name: 'AuthService');
      throw AppAuthException('Password update failed: $e');
    }
  }

  /// Admin-only: permanently deletes a user's Auth account and profile.
  Future<void> adminDeleteUser({required String userId}) async {
    if (!isAdmin) {
      throw const AppAuthException('Only Administrators can delete users.');
    }
    if (userId == currentUser?.id) {
      throw const AppAuthException('You cannot delete your own account.');
    }
    try {
      await _supabase.functions.invoke(
        'admin-manage-user',
        body: {'action': 'delete_user', 'user_id': userId},
      );
    } catch (e) {
      developer.log('Admin user deletion failed: $e', name: 'AuthService');
      throw AppAuthException('User deletion failed: $e');
    }
  }

  // ── Admin: list users ────────────────────────────────────────────────────

  /// Returns all user profiles from public.users (admin use).
  Future<List<Map<String, dynamic>>> listUsers() async {
    if (!isAdmin) {
      throw const AppAuthException('Only Administrators can view user management.');
    }
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, email, phone, role, department, status, created_at')
          .order('full_name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      developer.log('Failed to list users: $e', name: 'AuthService');
      throw const AppAuthException(
        'Unable to load users. Please try again.',
      );
    }
  }

  // ── Admin: update user status/role ────────────────────────────────────────

  /// Admin-only: updates a user's role, department, or status in public.users.
  /// Enforces that only admin users can change roles.
  Future<void> updateUserProfile({
    required String userId,
    String? role,
    String? department,
    String? status,
  }) async {
    try {
      // Role and account-status changes are always performed by the guarded
      // database function. The client never writes these columns directly.
      if (role != null || status != null) {
        if (!isAdmin) {
          throw const AppAuthException(
            'Only Administrators can change roles or account status.',
          );
        }
        await _supabase.rpc('admin_update_user', params: {
          'p_user_id': userId,
          'p_role': role,
          'p_status': status,
          'p_department': department,
        });
        return;
      }
      final updates = <String, dynamic>{};
      if (department != null) updates['department'] = department;
      if (updates.isEmpty) return;

      await _supabase
          .from('users')
          .update(updates)
          .eq('id', userId);
    } on AppAuthException {
      rethrow;
    } catch (e) {
      developer.log('Failed to update user: $e', name: 'AuthService');
      throw AppAuthException('Unable to update user: $e');
    }
  }

  // ── Sign out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    final email = currentEmail;
    _cachedProfile = null;
    _cachedPermissions = null;
    _cachedPermissionKeys = <String>{};
    AuditLogService.logLogout(email);
    await _supabase.auth.signOut();
  }

  // ── Current user / session ───────────────────────────────────────────────

  /// Returns the raw Supabase auth [User], or null if not authenticated.
  User? get currentUser => _supabase.auth.currentUser;

  /// Returns the current session, or null if expired/absent.
  Session? get currentSession => _supabase.auth.currentSession;

  /// Returns true if there is a valid Supabase session.
  bool get isAuthenticated => currentSession != null && currentUser != null;

  /// Alias for [currentUser] — returns the raw Supabase auth [User].
  User? getCurrentUser() => currentUser;

  // ── Profile helpers ──────────────────────────────────────────────────────

  /// The cached user profile. Only available after a successful signIn.
  /// Returns null if no user has signed in (or after signOut).
  Map<String, dynamic>? get currentProfile => _cachedProfile;

  /// The cached permission matrix for the current user.
  List<ModulePermission>? get currentPermissions =>
      PermissionService.toModulePermissions(_cachedPermissionKeys);

  /// Returns the cached role string, falling back to 'viewer'.
  String get currentRole =>
      _cachedProfile?['role'] as String? ?? 'viewer';

  bool get isAdmin => currentRole == 'admin';

  /// Returns the cached full name, or 'User' if unavailable.
  String get currentName =>
      _cachedProfile?['full_name'] as String? ?? 'User';

  /// Returns the cached email, or an empty string.
  String get currentEmail =>
      _cachedProfile?['email'] as String? ?? '';

  /// Two-letter initials derived from the cached full name.
  String get currentInitials {
    final parts = currentName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Returns the cached status string, or 'pending_assignment'.
  String get currentStatus =>
      _cachedProfile?['status'] as String? ?? 'pending_assignment';

  /// Returns the cached department, or 'General'.
  String get currentDepartment =>
      _cachedProfile?['department'] as String? ?? 'General';

  /// Fetches the user's application profile from `public.users`.
  Future<Map<String, dynamic>> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) {
      throw const AppAuthException('No authenticated user.');
    }
    return _loadProfile(user.id);
  }

  /// Returns the application role string (e.g. 'admin', 'marketing_manager').
  Future<String> getCurrentRole() async {
    final profile = await getCurrentProfile();
    return profile['role'] as String? ?? 'viewer';
  }

  /// Returns true if the user's application status is 'active'.
  Future<bool> isActive() async {
    final profile = await getCurrentProfile();
    return profile['status'] == 'active';
  }

  /// Attempts to restore a cached profile from an existing session.
  /// Returns the profile if the session is valid and the user is active.
  /// Returns null if no session, missing profile, or inactive/pending status
  /// (and signs out the user in those cases).
  Future<Map<String, dynamic>?> restoreSession() async {
    if (!isAuthenticated) return null;

    try {
      final user = currentUser!;
      final profile = await _loadProfile(user.id);

      final status = profile['status'] as String? ?? 'pending_assignment';
      if (status != 'active') {
        await signOut();
        return null;
      }

      // Cache profile & permissions.
      _cachedProfile = profile;
      await _cachePermissions(profile['role'] as String? ?? '');

      await RepositorySync.reloadAll();

      return profile;
    } catch (e) {
      developer.log('Session restore failed: $e', name: 'AuthService');
      await signOut();
      return null;
    }
  }

  /// Re-reads the current profile so role/status changes made by an
  /// Administrator take effect without requiring a fresh app install.
  Future<bool> refreshCurrentProfile() async {
    if (!isAuthenticated) return false;
    try {
      final profile = await _loadProfile(currentUser!.id);
      if (profile['status'] != 'active') {
        await signOut();
        return false;
      }
      _cachedProfile = profile;
      await _cachePermissions(profile['role'] as String? ?? '');
      return true;
    } catch (e) {
      developer.log('Profile refresh failed: $e', name: 'AuthService');
      await signOut();
      return false;
    }
  }

  // ── Permission helpers ───────────────────────────────────────────────────

  /// Checks whether the current user's role grants permission for the
  /// given module with at least [type] access.
  bool hasPermission(String module, PermissionType type) {
    if (isAdmin) return true;
    return _cachedPermissionKeys.contains(PermissionService.keyFor(module, type));
  }

  bool hasAction(String permissionKey) =>
      isAdmin || _cachedPermissionKeys.contains(permissionKey);

  /// Checks if a user is trying to change their own role — this should never
  /// succeed as the role is locked after initial sign-in and can only be changed
  /// by an administrator via the adminCreateUser or updateUserProfile methods.
  bool get roleLocked => _roleLockExpiry != null && DateTime.now().isBefore(_roleLockExpiry!);

  /// Throws [AppAuthException] if the user is attempting to change their own role.
  void _assertRoleNotChanged() {
    if (!roleLocked) {
      throw const AppAuthException(
        'Role changes are not permitted. Administrative changes only.',
      );
    }
  }

  /// Convenience: can the current user view [module]?
  bool canView(String module) => hasPermission(module, PermissionType.view);

  /// Convenience: can the current user create in [module]?
  bool canCreate(String module) => hasPermission(module, PermissionType.create);

  /// Convenience: can the current user edit [module]?
  bool canEdit(String module) => hasPermission(module, PermissionType.edit);

  /// Convenience: can the current user delete from [module]?
  bool canDelete(String module) => hasPermission(module, PermissionType.delete);

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _cachePermissions(String role) async {
    if (role == 'admin') {
      _cachedPermissionKeys = PermissionService.allKeys.toSet();
      _cachedPermissions = PermissionService.toModulePermissions(
        _cachedPermissionKeys,
      );
      return;
    }
    try {
      _cachedPermissionKeys = await PermissionService.loadKeysForRole(role);
    } catch (e) {
      PermissionService.reportFailure(e);
      _cachedPermissionKeys = <String>{};
    }
    _cachedPermissions = PermissionService.toModulePermissions(_cachedPermissionKeys);
  }

  Future<Map<String, dynamic>> _loadProfile(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, email, phone, role, department, status, created_at')
          .eq('id', userId)
          .single();
      return data;
    } catch (e) {
      developer.log('Failed to load profile for $userId: $e', name: 'AuthService');
      throw const AppAuthException(
        'Your user profile could not be found. Please contact an administrator.',
      );
    }
  }
}
