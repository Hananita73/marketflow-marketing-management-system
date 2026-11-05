import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../services/auth_service.dart';
import '../../utils/input_validators.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_textfield.dart';

/// MarketFlow public sign-up screen.
///
/// Allows a new user to request an account. The database trigger creates the
/// profile with no assigned role and status='pending_assignment'. An
/// Administrator must review and activate the account before first login.
///
/// Desktop  : two-column layout matching the Login screen.
/// Mobile   : form only, wrapped in a card.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _signupSuccess = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    return null;
  }

  String? _validateEmail(String? v) {
    return InputValidators.email(v);
  }

  String? _validatePhone(String? v) {
    return InputValidators.ethiopianPhone(v);
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _onSignup() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService().signUp(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text,
        phone: _phoneCtrl.text,
        department: _deptCtrl.text,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _signupSuccess = true;
      });
    } on AppAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to create your account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 960;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isDesktop
          ? _DesktopSignupLayout(form: _buildForm())
          : _buildMobileForm(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared form
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    if (_signupSuccess) {
      return _buildSuccessView();
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo + brand ─────────────────────────────────
          const _BrandHeader(),
          const SizedBox(height: 32),

          // ── Welcome text ────────────────────────────────
          const Text(
            'Create your account',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Request access to the Marketing Management System.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // ── Error banner ────────────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Full Name ───────────────────────────────────
          CustomTextField(
            controller: _nameCtrl,
            label: 'Full Name',
            hint: 'e.g. John Doe',
            prefixIcon: Icons.person_outline_rounded,
            validator: _validateName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // ── Email ───────────────────────────────────────
          CustomTextField(
            controller: _emailCtrl,
            label: 'Email',
            hint: 'you@company.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          CustomTextField(
            controller: _phoneCtrl,
            label: 'Phone Number',
            hint: 'e.g. +251 911 234 567',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // ── Department ──────────────────────────────────
          CustomTextField(
            controller: _deptCtrl,
            label: 'Department',
            hint: 'e.g. Marketing, IT, Sales',
            prefixIcon: Icons.business_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // ── Password ────────────────────────────────────
          CustomTextField(
            controller: _passwordCtrl,
            label: 'Password',
            hint: 'Minimum 8 characters',
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onSuffixTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            obscureText: _obscurePassword,
            validator: _validatePassword,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // ── Confirm Password ────────────────────────────
          CustomTextField(
            controller: _confirmCtrl,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: _obscureConfirm
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onSuffixTap: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            obscureText: _obscureConfirm,
            validator: _validateConfirm,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),

          // ── Sign up ─────────────────────────────────────
          CustomButton(
            text: 'Request Access',
            onPressed: _isLoading ? null : _onSignup,
            isLoading: _isLoading,
            size: ButtonSize.large,
          ),
          const SizedBox(height: 20),

          // ── Sign-in prompt ──────────────────────────────
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Sign in',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Success view after signup
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Account Created!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Your account request has been submitted. An Administrator will review it and activate your account before you can sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Back to Sign In',
            onPressed: () => Navigator.of(context).pop(),
            size: ButtonSize.medium,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mobile form layout
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop two-column layout (reuses the login branding panel concept)
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopSignupLayout extends StatelessWidget {
  final Widget form;
  const _DesktopSignupLayout({required this.form});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: branding panel ──────────────────────────
        Expanded(
          flex: 5,
          child: Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  Color(0xFF8B6CFF),
                  Color(0xFFAB94FF),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -80,
                  child: _DecoCircle(size: 260, opacity: 0.10),
                ),
                Positioned(
                  top: 140,
                  right: -60,
                  child: _DecoCircle(size: 180, opacity: 0.08),
                ),
                Positioned(
                  bottom: -100,
                  left: 60,
                  child: _DecoCircle(size: 240, opacity: 0.07),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            _BrandMark(
                                size: 44,
                                borderRadius: 12,
                                iconSize: 24),
                            SizedBox(width: 14),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MarketFlow',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  'Marketing Management System',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'Join Your\nMarketing Team.',
                          style: TextStyle(
                            fontSize: 34,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create an account to get started. An administrator '
                          'an administrator reviews your request and assigns the right role.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color:
                                Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Trusted by marketing teams everywhere',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Right: signup card ─────────────────────────────
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: form,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared brand widgets (matching login screen)
// ─────────────────────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _BrandMark(size: 52, borderRadius: 14, iconSize: 28),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MarketFlow',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              'Marketing Management System',
              style:
                  TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;
  final double borderRadius;
  final double iconSize;

  const _BrandMark({
    required this.size,
    required this.borderRadius,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF9B7DFF)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(Icons.rocket_launch_rounded,
          color: Colors.white, size: iconSize),
    );
  }
}

class _DecoCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecoCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
