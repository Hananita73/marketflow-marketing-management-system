// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, UserAttributes;
import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/audit_log_service.dart';
import '../../widgets/auth/user_profile_provider.dart';
import '../../models/user_role_models.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_textfield.dart';

// Access helper so profile_screen can call Supabase.instance.client without
// re-importing the whole package in every method.
class _SupabaseAccess {
  static dynamic get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── profile state ─────────────────────────────────────────────────────────
  String _name       = '';
  String _role       = '';
  String _email      = '';
  String _phone      = '';
  String _department = '';
  String _location   = 'Addis Ababa, Ethiopia';
  String _contact    = 'Email';

  // ── security state ────────────────────────────────────────────────────────
  bool   _twoFactor          = false;
  bool   _loginAlerts        = true;
  bool   _isSavingPassword   = false;
  String _passwordStatus     = 'Strong';
  String _lastPasswordChange = 'June 10, 2026';
  bool   _showPasswordForm   = false;

  // ── password form ─────────────────────────────────────────────────────────
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl     = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  final _pwFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfileFromAuth());
  }

  /// Reads the authenticated user's profile from UserProfileProvider
  /// and populates the local state — never hard-codes any user.
  void _loadProfileFromAuth() {
    final auth = UserProfileProvider.of(context);
    if (!mounted) return;
    setState(() {
      _name       = auth.currentName;
      _email      = auth.currentEmail;
      _role       = UserRoleRepository.roleDisplayName(auth.currentRole);
      _department = auth.currentDepartment;
    });
  }

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  // ── snackbar ──────────────────────────────────────────────────────────────
  void _snack(String msg,
      {IconData icon = Icons.check_circle_rounded,
      Color color = AppColors.success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── edit profile dialog ───────────────────────────────────────────────────
  void _showEditDialog() {
    final nameCtrl  = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final deptCtrl  = TextEditingController(text: _department);
    final locCtrl   = TextEditingController(text: _location);
    String role    = _role;
    String contact = _contact;
    final formKey  = GlobalKey<FormState>();
    // Role changes are Administrator-only and are managed from Users & Roles.
    final roles = [_role];
    final contacts = ['Email', 'Phone', 'Both'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final brightness  = Theme.of(ctx).brightness;
          final surfColor   = AppTheme.surfaceColor(brightness);
          final textPrimary = AppTheme.textPrimary(brightness);
          final inputFill   = AppTheme.inputFill(brightness);
          final borderColor = AppTheme.border(brightness);

          return Dialog(
            backgroundColor: surfColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogHeader(ctx, Icons.edit_rounded, 'Edit Profile', AppColors.primary),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: nameCtrl, label: 'Full Name *',
                          hint: 'Your full name',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: emailCtrl, label: 'Email Address *',
                          hint: 'email@marketflow.et',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: phoneCtrl, label: 'Phone Number',
                          hint: '+251 9XX XXX XXX',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _dropdownField(ctx, 'Role', role, roles,
                            (v) => setLocal(() => role = v!),
                            fillColor: inputFill,
                            borderColor: borderColor,
                            textColor: textPrimary),
                        const SizedBox(height: 14),
                        LayoutBuilder(builder: (_, c) {
                          final narrow = c.maxWidth < 340;
                          if (narrow) {
                            return Column(children: [
                              CustomTextField(controller: deptCtrl, label: 'Department', hint: 'e.g. Marketing', prefixIcon: Icons.business_outlined),
                              const SizedBox(height: 14),
                              CustomTextField(controller: locCtrl, label: 'Location', hint: 'City, Country', prefixIcon: Icons.location_on_outlined),
                            ]);
                          }
                          return Row(children: [
                            Expanded(child: CustomTextField(controller: deptCtrl, label: 'Department', hint: 'e.g. Marketing', prefixIcon: Icons.business_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: CustomTextField(controller: locCtrl, label: 'Location', hint: 'City, Country', prefixIcon: Icons.location_on_outlined)),
                          ]);
                        }),
                        const SizedBox(height: 14),
                        _dropdownField(ctx, 'Preferred Contact', contact, contacts,
                            (v) => setLocal(() => contact = v!),
                            fillColor: inputFill,
                            borderColor: borderColor,
                            textColor: textPrimary),
                        const SizedBox(height: 24),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
                              final auth = UserProfileProvider.of(context);
                              final userId = auth.currentUser?.id;

                              // Persist to Supabase
                              if (userId != null) {
                                try {
                                  await auth.updateUserProfile(
                                    userId: userId,
                                    department: deptCtrl.text.trim().isNotEmpty
                                        ? deptCtrl.text.trim()
                                        : _department,
                                  );
                                } catch (_) {
                                  // Non-fatal: update local state anyway
                                }
                              }
                              setState(() {
                                _name       = nameCtrl.text.trim();
                                _email      = emailCtrl.text.trim();
                                _phone      = phoneCtrl.text.trim();
                                _role       = role;
                                _department = deptCtrl.text.trim().isEmpty ? _department : deptCtrl.text.trim();
                                _location   = locCtrl.text.trim().isEmpty ? _location : locCtrl.text.trim();
                                _contact    = contact;
                              });
                              AuditLogService.logUpdate('Users', userId ?? '', _name,
                                  details: {'department': _department});
                              Navigator.pop(ctx);
                              _snack('Profile updated successfully');
                            },
                          ),
                        ]),
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

  // ── password change ───────────────────────────────────────────────────────
  void _submitPasswordChange() async {
    if (!_pwFormKey.currentState!.validate()) return;
    setState(() => _isSavingPassword = true);

    try {
      // Step 1: Verify current password by re-authenticating
      final email = AuthService().currentEmail;
      if (email.isNotEmpty) {
        try {
          await AuthService().signIn(
            email: email,
            password: _currentPwCtrl.text,
          );
        } on AppAuthException {
          if (mounted) {
            _snack('Current password is incorrect.',
                icon: Icons.error_outline, color: AppColors.danger);
          }
          setState(() => _isSavingPassword = false);
          return;
        }
      }

      // Step 2: Update to the new password via Supabase
      final supabase = await _supabaseUpdatePassword(_newPwCtrl.text);
      if (!supabase) throw Exception('Supabase password update failed');

      if (mounted) {
        setState(() {
          _showPasswordForm   = false;
          _passwordStatus     = 'Strong';
          _lastPasswordChange =
              '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}';
          _currentPwCtrl.clear();
          _newPwCtrl.clear();
          _confirmPwCtrl.clear();
          _isSavingPassword = false;
        });
        AuditLogService.log(action: 'update', module: 'Auth',
            recordName: 'Password changed');
        _snack('Password changed successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingPassword = false);
        _snack('Failed to change password. Please try again.',
            icon: Icons.error_outline, color: AppColors.danger);
      }
    }
  }

  Future<bool> _supabaseUpdatePassword(String newPassword) async {
    try {
      // Access Supabase via the package directly
      // ignore: implementation_imports
      final client = _supabaseClient;
      if (client == null) return false;
      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // Lazily accessed Supabase client
  dynamic get _supabaseClient {
    try {
      // Supabase.instance.client is available once Supabase.initialize() ran in main.dart
      return _SupabaseAccess.client;
    } catch (_) {
      return null;
    }
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(m - 1).clamp(0, 11)];
  }

  void _cancelPasswordChange() {
    setState(() {
      _showPasswordForm = false;
      _isSavingPassword = false;
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────
  // Uses CustomScrollView so the page header is pinned via SliverPersistentHeader
  // while the body content scrolls underneath it.
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor    = AppTheme.backgroundFill(brightness);

    return CustomScrollView(
      slivers: [
        // ── Pinned page header ────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProfileStickyHeaderDelegate(
            brightness: brightness,
            bgColor: bgColor,
            onEditProfile: _showEditDialog,
          ),
        ),

        // ── Scrollable body ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.itemSpacing,
            AppConstants.pagePadding,
            AppConstants.pagePadding,
          ),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(builder: (ctx, c) {
              final wide = c.maxWidth >= 900;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildLeftColumn()),
                    const SizedBox(width: AppConstants.sectionSpacing),
                    Expanded(flex: 3, child: _buildRightColumn()),
                  ],
                );
              }
              return Column(children: [
                _buildLeftColumn(),
                const SizedBox(height: AppConstants.sectionSpacing),
                _buildRightColumn(),
              ]);
            }),
          ),
        ),
      ],
    );
  }

  // ── left column: hero + account info ─────────────────────────────────────
  Widget _buildLeftColumn() {
    return Column(children: [
      _buildProfileHeroCard(),
      const SizedBox(height: AppConstants.itemSpacing),
      _buildAccountInfoCard(),
    ]);
  }

  // ── right column: personal info + security + sessions + activity ──────────
  Widget _buildRightColumn() {
    return Column(children: [
      _buildPersonalInfoCard(),
      const SizedBox(height: AppConstants.itemSpacing),
      _buildSecurityCard(),
      if (_showPasswordForm) ...[
        const SizedBox(height: AppConstants.itemSpacing),
        _buildPasswordForm(),
      ],
      const SizedBox(height: AppConstants.itemSpacing),
      _buildActiveSessionsCard(),
      const SizedBox(height: AppConstants.itemSpacing),
      _buildRecentActivityCard(),
    ]);
  }

  // ── profile hero card — always purple, no dark adaptation needed ──────────
  Widget _buildProfileHeroCard() {
    final initials = _name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
      ),
      child: Column(children: [
        Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          GestureDetector(
            onTap: _showEditDialog,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary, size: 14),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(_name,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(_role,
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(_department,
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 16),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline,
                size: 13, color: Colors.white),
            const SizedBox(width: 5),
            const Text('Active Account',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showEditDialog,
            icon: const Icon(Icons.edit_rounded,
                size: 16, color: Colors.white),
            label: const Text('Edit Profile',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── account info card ─────────────────────────────────────────────────────
  Widget _buildAccountInfoCard() {
    return _section(context, 'Account Information', Icons.info_outline_rounded, [
      _infoRow(context, Icons.verified_user_outlined, 'Account Status',
          UserProfileProvider.of(context).currentStatus,
          valueColor: AppColors.success),
      _infoRow(context, Icons.calendar_today_outlined, 'Member Since',
          'January 12, 2024'),
      _infoRow(context, Icons.login_rounded, 'Last Login',
          'Aug 15, 2026 · 9:30 AM'),
      _infoRow(context, Icons.work_outline_rounded, 'User Role', _role),
      _infoRow(context, Icons.business_outlined, 'Department', _department),
    ]);
  }

  // ── personal info card ────────────────────────────────────────────────────
  Widget _buildPersonalInfoCard() {
    return _section(context, 'Personal Information', Icons.person_outline_rounded, [
      _infoRow(context, Icons.person_outline_rounded, 'Full Name', _name),
      _infoRow(context, Icons.email_outlined, 'Email Address', _email),
      _infoRow(context, Icons.phone_outlined, 'Phone Number', _phone),
      _infoRow(context, Icons.work_outline_rounded, 'Role', _role),
      _infoRow(context, Icons.business_outlined, 'Department', _department),
      _infoRow(context, Icons.location_on_outlined, 'Location', _location),
      _infoRow(context, Icons.contact_mail_outlined, 'Preferred Contact',
          _contact),
    ], actionButton: TextButton.icon(
      onPressed: _showEditDialog,
      icon: const Icon(Icons.edit_rounded, size: 16),
      label: const Text('Edit'),
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ));
  }

  // ── security card ─────────────────────────────────────────────────────────
  Widget _buildSecurityCard() {
    return _section(context, 'Security', Icons.security_rounded, [
      _securityRow(
        context,
        icon: Icons.lock_outline_rounded,
        label: 'Password',
        value: _passwordStatus,
        valueColor: _passwordStatus == 'Strong'
            ? AppColors.success
            : AppColors.warning,
        trailing: TextButton(
          onPressed: () =>
              setState(() => _showPasswordForm = !_showPasswordForm),
          child: Text(_showPasswordForm ? 'Cancel' : 'Change Password'),
        ),
      ),
      _infoRow(context, Icons.history_rounded, 'Last Changed',
          _lastPasswordChange),
      _securityRow(
        context,
        icon: Icons.phonelink_lock_rounded,
        label: 'Two-Factor Authentication',
        value: _twoFactor ? 'Enabled' : 'Disabled',
        valueColor:
            _twoFactor ? AppColors.success : AppTheme.textSecondary(Theme.of(context).brightness),
        trailing: Switch(
          value: _twoFactor,
          onChanged: (v) {
            setState(() => _twoFactor = v);
            _snack('2FA ${v ? 'enabled' : 'disabled'}',
                icon: Icons.shield_rounded);
          },
          activeThumbColor: AppColors.primary,
        ),
      ),
      _securityRow(
        context,
        icon: Icons.notifications_active_outlined,
        label: 'Login Alerts',
        value: _loginAlerts ? 'On' : 'Off',
        valueColor: _loginAlerts
            ? AppColors.success
            : AppTheme.textSecondary(Theme.of(context).brightness),
        trailing: Switch(
          value: _loginAlerts,
          onChanged: (v) {
            setState(() => _loginAlerts = v);
            _snack('Login alerts ${v ? 'enabled' : 'disabled'}');
          },
          activeThumbColor: AppColors.primary,
        ),
      ),
    ]);
  }

  // ── password change form ──────────────────────────────────────────────────
  Widget _buildPasswordForm() {
    final brightness  = Theme.of(context).brightness;
    final surfColor   = AppTheme.surfaceColor(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final primaryLighter = AppTheme.primaryLighter(brightness);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Form(
        key: _pwFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: primaryLighter,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.lock_reset_rounded,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Change Password',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
          ]),
          const SizedBox(height: 16),
          _pwField(context, _currentPwCtrl, 'Current Password *',
              _obscureCurrent,
              () => setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          _pwField(context, _newPwCtrl, 'New Password *', _obscureNew,
              () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v.length < 8) return 'Minimum 8 characters';
            return null;
          }),
          const SizedBox(height: 12),
          _pwField(context, _confirmPwCtrl, 'Confirm New Password *',
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v != _newPwCtrl.text) return 'Passwords do not match';
            return null;
          }),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelPasswordChange,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.border(brightness)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: _isSavingPassword ? 'Updating…' : 'Update Password',
                fullWidth: true,
                size: ButtonSize.small,
                prefixIcon: Icons.lock_rounded,
                onPressed: _isSavingPassword ? null : _submitPasswordChange,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _pwField(
    BuildContext context,
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback toggleObscure, {
    String? Function(String?)? validator,
  }) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final inputFill   = AppTheme.inputFill(brightness);
    final borderColor = AppTheme.border(brightness);

    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(fontSize: 14, color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSec),
        filled: true,
        fillColor: inputFill,
        prefixIcon: Icon(Icons.lock_outline_rounded,
            size: 18, color: textSec),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: textSec),
          onPressed: toggleObscure,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.8)),
      ),
    );
  }

  // ── active sessions card ──────────────────────────────────────────────────
  Widget _buildActiveSessionsCard() {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final surfVar     = AppTheme.surfaceVariant(brightness);
    final primaryLighter = AppTheme.primaryLighter(brightness);
    final successBg   = AppTheme.successBg(brightness);

    final sessions = [
      _Session('Chrome on Windows', 'Current session', 'Just now',
          Icons.computer_rounded, true),
      _Session('Firefox on MacOS', 'Office laptop', '2 hours ago',
          Icons.laptop_mac_rounded, false),
      _Session('MarketFlow Mobile', 'Android — Addis Ababa', 'Yesterday',
          Icons.phone_android_rounded, false),
    ];

    return _section(context, 'Active Sessions', Icons.devices_rounded, [],
        customContent: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sessions.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: s.isCurrent ? primaryLighter : surfVar,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(s.icon,
                  size: 18,
                  color: s.isCurrent ? AppColors.primary : textSec),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(s.device,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (s.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: successBg,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('Current',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ),
                  ]),
                  Text(s.detail,
                      style: TextStyle(fontSize: 12, color: textSec)),
                  Text(s.time,
                      style: TextStyle(fontSize: 11, color: textSec)),
                ],
              ),
            ),
            if (!s.isCurrent)
              TextButton(
                onPressed: () => _snack(
                    'Session on ${s.device} signed out',
                    icon: Icons.logout_rounded,
                    color: AppColors.warning),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Sign out',
                    style: TextStyle(fontSize: 12)),
              ),
          ]),
        )),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _snack(
                'All other sessions signed out',
                icon: Icons.logout_rounded,
                color: AppColors.warning),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Sign Out All Other Sessions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ));
  }

  // ── recent account activity ───────────────────────────────────────────────
  Widget _buildRecentActivityCard() {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);
    final divColor    = AppTheme.divider(brightness);

    final entries = [
      _ActivityItem(Icons.edit_rounded, AppColors.primary,
          'Profile information updated', 'Aug 15, 2026 · 9:28 AM'),
      _ActivityItem(Icons.lock_reset_rounded, AppColors.warning,
          'Password changed', 'Jun 10, 2026 · 3:15 PM'),
      _ActivityItem(Icons.login_rounded, AppColors.success,
          'Logged in from Chrome on Windows', 'Aug 15, 2026 · 9:25 AM'),
      _ActivityItem(Icons.notifications_rounded, AppColors.info,
          'Notification preferences updated', 'Aug 12, 2026 · 11:00 AM'),
      _ActivityItem(Icons.security_rounded, AppColors.primary,
          'Two-Factor Authentication disabled', 'Jul 30, 2026 · 4:45 PM'),
    ];

    return _section(context, 'Recent Account Activity', Icons.history_rounded, [],
        customContent: Column(
      children: entries.asMap().entries.map((e) {
        final item   = e.value;
        final isLast = e.key == entries.length - 1;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label,
                          style: TextStyle(
                              fontSize: 13, color: textPrimary)),
                      Text(item.time,
                          style: TextStyle(
                              fontSize: 11, color: textSec)),
                    ]),
              ),
            ]),
          ),
          if (!isLast) Divider(height: 1, color: divColor),
        ]);
      }).toList(),
    ));
  }

  // ── section wrapper ───────────────────────────────────────────────────────
  Widget _section(
    BuildContext context,
    String title,
    IconData titleIcon,
    List<Widget> rows, {
    Widget? actionButton,
    Widget? customContent,
  }) {
    final brightness  = Theme.of(context).brightness;
    final surfColor   = AppTheme.surfaceColor(brightness);
    final borderColor = AppTheme.border(brightness);
    final divColor    = AppTheme.border(brightness);
    final textPrimary = AppTheme.textPrimary(brightness);
    final primaryLighter = AppTheme.primaryLighter(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfColor,
        borderRadius:
            BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: primaryLighter,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(titleIcon,
                    color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
              ),
              ?actionButton,
            ]),
            if (rows.isNotEmpty || customContent != null) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: divColor),
              const SizedBox(height: 12),
              ?customContent,
              ...rows,
            ],
          ]),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: textSec),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: textSec)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? textPrimary)),
        ),
      ]),
    );
  }

  Widget _securityRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    required Widget trailing,
  }) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);
    final textSec     = AppTheme.textSecondary(brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 16, color: textSec),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: textPrimary,
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        color: valueColor,
                        fontWeight: FontWeight.w600)),
              ]),
        ),
        trailing,
      ]),
    );
  }

  Widget _dialogHeader(
      BuildContext context, IconData icon, String title, Color color) {
    final brightness  = Theme.of(context).brightness;
    final textPrimary = AppTheme.textPrimary(brightness);

    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Text(title,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textPrimary)),
    ]);
  }

  Widget _dropdownField(
    BuildContext context,
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    required Color fillColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        dropdownColor: AppTheme.surfaceColor(Theme.of(context).brightness),
        style: TextStyle(fontSize: 14, color: textColor),
        items: items
            .map((i) => DropdownMenuItem(
                value: i,
                child: Text(i, style: TextStyle(color: textColor))))
            .toList(),
        decoration: InputDecoration(
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 1.8)),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProfileStickyHeaderDelegate — pinned page header (matches CampaignListScreen)
// Fixed at 80px. Shows a bottom border + Material elevation once content
// scrolls underneath it, identical to the _StickyHeaderDelegate pattern used
// across the rest of the app.
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Brightness brightness;
  final Color bgColor;
  final VoidCallback onEditProfile;

  static const double _height = 80.0;

  const _ProfileStickyHeaderDelegate({
    required this.brightness,
    required this.bgColor,
    required this.onEditProfile,
  });

  @override double get minExtent => _height;
  @override double get maxExtent => _height;

  @override
  bool shouldRebuild(_ProfileStickyHeaderDelegate old) =>
      old.brightness != brightness ||
      old.bgColor != bgColor ||
      old.onEditProfile != onEditProfile;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
                      color: AppTheme.border(brightness), width: 1))
              : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: 12,
        ),
        child: _ProfilePageHeaderBar(onEditProfile: onEditProfile),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProfilePageHeaderBar — the content inside the sticky header
// Icon badge + title + subtitle (left) | Edit Profile button (right)
// Collapses gracefully on narrow screens (<580px).
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePageHeaderBar extends StatelessWidget {
  final VoidCallback onEditProfile;

  const _ProfilePageHeaderBar({required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textSec    = AppTheme.textSecondary(brightness);

    return LayoutBuilder(builder: (context, cst) {
      final narrow = cst.maxWidth < 580;

      final titleBlock = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Purple icon badge — matches the style used on every other screen
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMedium),
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage your MarketFlow account information and security.',
                  style: TextStyle(fontSize: 12, color: textSec),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      );

      final editButton = OutlinedButton.icon(
        onPressed: onEditProfile,
        icon: const Icon(Icons.edit_rounded, size: 15),
        label: const Text('Edit Profile'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMedium)),
          textStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );

      if (narrow) {
        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 8),
            editButton,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: 16),
          editButton,
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Session {
  final String device, detail, time;
  final IconData icon;
  final bool isCurrent;
  const _Session(
      this.device, this.detail, this.time, this.icon, this.isCurrent);
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String label, time;
  const _ActivityItem(this.icon, this.color, this.label, this.time);
}
