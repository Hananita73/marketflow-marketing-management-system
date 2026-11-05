// ─────────────────────────────────────────────────────────────────────────────
// UserProfileProvider
//
// An InheritedWidget that exposes the current AuthService instance (with its
// cached profile) to any descendant widget.
//
// Place it below AuthGate so every authenticated screen can access user data
// synchronously via:
//
//   final profile = UserProfileProvider.of(context);
//   final name = profile.currentName;
//   final role = profile.currentRole;
//   final initials = profile.currentInitials;
//   final permissions = profile.currentPermissions;
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class UserProfileProvider extends InheritedWidget {
  final AuthService authService;

  const UserProfileProvider({
    super.key,
    required this.authService,
    required super.child,
  });

  /// Returns the nearest [AuthService] instance up the tree.
  static AuthService of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<UserProfileProvider>();
    assert(provider != null, 'No UserProfileProvider found in context');
    return provider!.authService;
  }

  @override
  bool updateShouldNotify(UserProfileProvider oldWidget) =>
      authService != oldWidget.authService;
}
