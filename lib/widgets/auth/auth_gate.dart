// ─────────────────────────────────────────────────────────────────────────────
// AuthGate
//
// Listens to Supabase auth state changes and shows:
//   • LoginScreen  — when no session exists OR profile is inactive/pending
//   • The main app — when a valid session AND active profile exist
//
// On startup the gate attempts to restore the session by loading the user's
// profile from public.users. If the profile is missing, inactive, or pending
// the user is signed out and shown the login screen.
//
// Place this at the top of your widget tree (as `home:` in MaterialApp) to
// enforce authentication before any other screen is reachable.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/routes.dart';
import '../../screens/auth/login_screen.dart';
import '../../services/auth_service.dart';
import '../layout/app_layout.dart';
import '../../core/constants.dart';
import '../../screens/dashboard/dashboard_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSub;
  Timer? _profileRefreshTimer;
  bool _initialized = false;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    // Listen for sign-in / sign-out / token-refresh events.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
    // Attempt to restore the session on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreSession();
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    _profileRefreshTimer?.cancel();
    super.dispose();
  }

  /// Tries to restore the user profile from an existing session.
  /// Signs out if the profile is missing, inactive, or pending.
  Future<void> _restoreSession() async {
    final auth = AuthService();
    if (auth.isAuthenticated) {
      final profile = await auth.restoreSession();
      if (profile == null) {
        // Session existed but profile was inactive/missing — already signed out.
        developer.log('Session restore failed — profile inactive or missing.',
            name: 'AuthGate');
      }
    }
    if (mounted) {
      setState(() {
        _initialized = true;
        _restoring = false;
      });
      _profileRefreshTimer ??= Timer.periodic(
        const Duration(seconds: 20),
        (_) async {
          final active = await AuthService().refreshCurrentProfile();
          if (mounted) setState(() {});
          if (!active) developer.log(
            'Current profile is no longer active.',
            name: 'AuthGate',
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final auth = AuthService();
    final hasProfile = auth.currentProfile != null;

    // Before restoration completes, show a loading spinner to avoid a flash
    // of the login screen when a valid session exists.
    if (!_initialized || _restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No session or no cached profile → show login.
    if (session == null || !hasProfile) {
      return const LoginScreen();
    }

    // Authenticated with an active profile — show the main application shell.
    // UserProfileProvider is already above MaterialApp (set up in main.dart),
    // so all routes—including sidebar & topbar—can access the user profile.
    return AppLayoutPage(
      route: AppRoutes.dashboard,
      title: AppConstants.navDashboard,
      isDashboard: true,
      child: const DashboardScreen(),
    );
  }
}


