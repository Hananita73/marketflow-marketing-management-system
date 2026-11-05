import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../services/auth_service.dart';
import '../../utils/input_validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_textfield.dart';
import 'signup_screen.dart';

/// MarketFlow login screen.
///
/// Desktop  : two-column layout — purple/lavender branding panel (left)
///           + login form card (right).
/// Tablet   : branding panel shrinks and simplifies.
/// Mobile   : only the login form is shown (no horizontal overflow).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    return InputValidators.email(v);
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    return null;
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  void _showForgotPassword(BuildContext context) {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final fk   = GlobalKey<FormState>();
    bool sending  = false;
    bool sent     = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Text('Reset Password',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 360,
            child: sent
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF22A06B), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Password reset email sent to ${ctrl.text.trim()}. '
                            'Check your inbox and follow the link.',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF065F46)),
                          ),
                        ),
                      ]),
                    ),
                  ])
                : Form(
                    key: fk,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                        'Enter your account email address. '
                        'We will send you a link to reset your password.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: ctrl,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: const Icon(Icons.email_outlined, size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12)),
                      ],
                    ]),
                  ),
          ),
          actions: sent
              ? [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                    child: const Text('Close'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: sending
                        ? null
                        : () async {
                            if (!fk.currentState!.validate()) return;
                            setLocal(() { sending = true; error = null; });
                            try {
                              await Supabase.instance.client.auth
                                  .resetPasswordForEmail(
                                ctrl.text.trim(),
                                redirectTo: 'io.supabase.marketflow://reset-callback/',
                              );
                              setLocal(() { sending = false; sent = true; });
                            } catch (e) {
                              setLocal(() {
                                sending = false;
                                error = 'Failed to send reset email. '
                                    'Please check the address and try again.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                    child: sending
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Send Reset Link'),
                  ),
                ],
        );
      }),
    );
  }

  Future<void> _onLogin() async {    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService().signIn(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      // Profile loaded successfully — role and status are valid.
      // AuthGate listens to onAuthStateChange and will automatically
      // rebuild to show the authenticated shell. No manual navigation needed.
      setState(() => _isLoading = false);
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
        _errorMessage = 'Unable to connect to the server. Please check your internet connection.';
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
          ? _DesktopLoginLayout(
              form: _buildForm(),
            )
          : _buildMobileForm(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared form (used by both desktop and mobile layouts)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
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
            'Welcome back',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in to continue to your Marketing Management System.',
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
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
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

          // ── Password ────────────────────────────────────
          CustomTextField(
            controller: _passwordCtrl,
            label: 'Password',
            hint: 'Enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            onSuffixTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            obscureText: _obscurePassword,
            validator: _validatePassword,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),

          // ── Remember me + forgot password ────────────────
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Remember me',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showForgotPassword(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Sign in ──────────────────────────────────────
          CustomButton(
            text: 'Sign In',
            onPressed: _isLoading ? null : _onLogin,
            isLoading: _isLoading,
            size: ButtonSize.large,
          ),
          const SizedBox(height: 20),

          // ── Sign-up prompt ───────────────────────────────
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Don\'t have an account?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SignupScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Create one',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mobile / tablet form layout (form only)
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
// Desktop two-column layout
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopLoginLayout extends StatelessWidget {
  final Widget form;

  const _DesktopLoginLayout({required this.form});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left: branding / illustration panel ─────────────
        Expanded(
          flex: 5,
          child: _BrandingPanel(),
        ),

        // ── Right: login card ────────────────────────────────
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
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
// Left branding panel — purple/lavender visual area
// ─────────────────────────────────────────────────────────────────────────────

class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Decorative circles
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
                  // Brand
                  const Row(
                    children: [
                      _BrandMark(size: 44, borderRadius: 12, iconSize: 24),
                      SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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

                  // Marketing statement + illustration
                  const Text(
                    'Plan. Execute. Measure. Grow.',
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
                    'Everything you need to run high-impact marketing campaigns, '
                    'manage budgets, and track performance — all in one place.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Marketing illustration (abstract chart/growth visual)
                  SizedBox(
                    width: double.infinity,
                    child: _GrowthIllustration(),
                  ),

                  const Spacer(),

                  // Footer mini-stat
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
                          color: Colors.white.withValues(alpha: 0.8),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract marketing illustration — growth bars + line, built with pure widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GrowthIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Growth bars
          for (final entry in const [40.0, 64.0, 52.0, 88.0, 70.0, 110.0]
              .asMap()
              .entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: entry.value,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 
                          0.35 + (entry.key * 0.1) > 0.9
                              ? 0.9
                              : 0.35 + (entry.key * 0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),
          // Trend line icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand mark + header used in the form card (right side / mobile)
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
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Reusable purple gradient square brand mark.
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
      child: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: iconSize),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decorative circle for the branding panel
// ─────────────────────────────────────────────────────────────────────────────

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