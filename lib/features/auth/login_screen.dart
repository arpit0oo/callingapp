import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/rtdb_service.dart';
import '../company_admin/admin_shell.dart';
import '../manager/manager_shell.dart';
import '../cold_caller/caller_shell.dart';
import '../super_admin/super_admin_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Colors ──────────────────────────────────────────────────
  static const _primary = Color(0xFF1A73E8);
  static const _bgPage = Color(0xFFF8F9FA);
  static const _textPrimary = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _borderDefault = Color(0xFFE8EAED);
  static const _textHint = Color(0xFF9AA0A6);
  static const _errorRed = Color(0xFFD93025);

  // ── State ────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _authError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Quick-access navigation (testing) ────────────────────────
  void _goTo(Widget shell) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => shell),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coming Soon',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
        backgroundColor: const Color(0xFF5F6368),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Real Firebase Auth sign-in ────────────────────────────────
  Future<void> _signIn() async {
    // Clear previous errors
    setState(() {
      _emailError = null;
      _passwordError = null;
      _authError = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    // Basic client-side validation
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Firebase Auth
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user!;

      // 2. Direct document fetch at tenants/xperttutor/users/{uid}.
      //    tenantId is hardcoded as "xperttutor" for now; replace with a
      //    real multi-tenant lookup when that feature is implemented.
      const tenantId = 'xperttutor';
      final userDocSnap = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDocSnap.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _isLoading = false;
          _authError = 'User profile not found. Contact your administrator.';
        });
        return;
      }

      final data = userDocSnap.data()!;

      // 3. Hydrate AppSession
      AppSession.tenantId = tenantId;
      AppSession.userId   = user.uid;
      AppSession.name     = data['name'] ?? '';
      AppSession.role     = (data['role'] as String? ?? '').toLowerCase();

      final assignedCampaigns =
          (data['assignedCampaigns'] as List<dynamic>? ?? []);
      AppSession.campaignId =
          assignedCampaigns.isNotEmpty ? assignedCampaigns.first as String : '';

      // Fetch campaign name for display in the workspace badge.
      if (AppSession.campaignId.isNotEmpty) {
        try {
          final campaignSnap = await FirebaseFirestore.instance
              .collection('tenants')
              .doc(tenantId)
              .collection('campaigns')
              .doc(AppSession.campaignId)
              .get();
          AppSession.campaignName =
              campaignSnap.data()?['name'] as String? ?? AppSession.campaignId;
        } catch (_) {
          // Non-fatal: fall back to the raw campaign ID.
          AppSession.campaignName = AppSession.campaignId;
        }
      }

      if (!mounted) return;

      // 4. Role-based navigation
      switch (AppSession.role) {
        case AppRoles.companyAdmin:
          _goTo(AdminShell(key: AdminShell.shellKey));
          break;
        case AppRoles.manager:
          _goTo(ManagerShell(key: ManagerShell.shellKey));
          break;
        case 'cold_caller':
          await RtdbService.updateCallerState(tenantId, user.uid, {
            'shiftStarted': ServerValue.timestamp,
            'status': 'on_shift',
            'lastSeen': ServerValue.timestamp,
          });
          if (!mounted) return;
          _goTo(CallerShell(key: CallerShell.shellKey, role: 'cold_caller'));
          break;
        case 'warm_caller':
          await RtdbService.updateCallerState(tenantId, user.uid, {
            'shiftStarted': ServerValue.timestamp,
            'status': 'on_shift',
            'lastSeen': ServerValue.timestamp,
          });
          if (!mounted) return;
          _goTo(CallerShell(key: CallerShell.shellKey, role: 'warm_caller'));
          break;
        case AppRoles.superAdmin:
          _goTo(SuperAdminShell(key: SuperAdminShell.shellKey));
          break;
        default:
          setState(() {
            _isLoading = false;
            _authError = 'Unknown role "${AppSession.role}". Contact your administrator.';
          });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          message = 'No account found for this email.';
          _emailError = message;
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect password. Please try again.';
          _passwordError = message;
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'Sign-in failed. Please try again.';
      }
      setState(() {
        _isLoading = false;
        _authError = message;
      });
    } catch (e) {
      // Non-auth errors (Firestore, network, etc.) should not produce a
      // user-facing message on the login screen. Reset loading state and
      // re-throw so Flutter's error reporting / crash tools can capture it.
      setState(() => _isLoading = false);
      rethrow;
    }
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo ──────────────────────────────────
                    Center(child: _buildLogo()),
                    const SizedBox(height: 20),

                    // ── App name ──────────────────────────────
                    Center(
                      child: Text(
                        'CallingApp',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ── Subtitle ──────────────────────────────
                    Center(
                      child: Text(
                        'Sign in to your account',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Email field ───────────────────────────
                    _buildLabel('Email address'),
                    const SizedBox(height: 6),
                    _buildEmailField(),
                    if (_emailError != null) _buildError(_emailError!),
                    const SizedBox(height: 16),

                    // ── Password field ────────────────────────
                    _buildLabel('Password'),
                    const SizedBox(height: 6),
                    _buildPasswordField(),
                    if (_passwordError != null) _buildError(_passwordError!),
                    const SizedBox(height: 12),

                    // ── Forgot password ───────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {},
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Real Sign In button ───────────────────
                    _buildSignInButton(),
                    if (_authError != null) _buildAuthError(_authError!),
                    const SizedBox(height: 24),

                    // ── Quick Access (Testing) ────────────────
                    _buildQuickAccessButtons(),
                    const SizedBox(height: 24),

                    // ── Divider with help text ────────────────
                    _buildHelpDivider(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────

  Widget _buildLogo() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'CA',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
      ),
    );
  }

  Widget _buildEmailField() {
    return _StyledTextField(
      controller: _emailCtrl,
      hintText: 'you@example.com',
      keyboardType: TextInputType.emailAddress,
      hasError: _emailError != null,
      onChanged: (_) {
        if (_emailError != null) setState(() => _emailError = null);
      },
    );
  }

  Widget _buildPasswordField() {
    return _StyledTextField(
      controller: _passwordCtrl,
      hintText: '••••••••',
      obscureText: _obscurePassword,
      hasError: _passwordError != null,
      onChanged: (_) {
        if (_passwordError != null) setState(() => _passwordError = null);
      },
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18,
          color: _textSecondary,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        splashRadius: 20,
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 13, color: _errorRed),
          const SizedBox(width: 4),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _errorRed,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton() {
    return _isLoading
        ? const SizedBox(
            height: 48,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        : _RoleButton(
            label: 'Sign In',
            color: _primary,
            textColor: Colors.white,
            onTap: _signIn,
          );
  }

  Widget _buildAuthError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 14, color: _errorRed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _errorRed,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label
        Center(
          child: Text(
            'Quick Access (Testing)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Company Admin
        _RoleButton(
          label: 'Company Admin',
          color: _primary,
          textColor: Colors.white,
          onTap: () => _goTo(AdminShell(key: AdminShell.shellKey)),
        ),
        const SizedBox(height: 8),
        // Manager
        _RoleButton(
          label: 'Manager',
          color: const Color(0xFF34A853),
          textColor: Colors.white,
          onTap: () => _goTo(ManagerShell(key: ManagerShell.shellKey)),
        ),
        const SizedBox(height: 8),
        // Cold Caller
        _RoleButton(
          label: 'Cold Caller',
          color: const Color(0xFFFBBC04),
          textColor: const Color(0xFF202124),
          onTap: () => _goTo(CallerShell(key: CallerShell.shellKey, role: 'cold')),
        ),
        const SizedBox(height: 8),
        // Warm Caller
        _RoleButton(
          label: 'Warm Caller',
          color: const Color(0xFF7B61FF),
          textColor: Colors.white,
          onTap: () => _goTo(CallerShell(key: CallerShell.shellKey, role: 'warm')),
        ),
        const SizedBox(height: 8),
        // Super Admin
        _RoleButton(
          label: 'Super Admin',
          color: const Color(0xFF5F6368),
          textColor: Colors.white,
          onTap: () => _goTo(SuperAdminShell(key: SuperAdminShell.shellKey)),
        ),
      ],
    );
  }

  Widget _buildHelpDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: _borderDefault, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Need help? Contact your administrator',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _textHint,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(child: Divider(color: _borderDefault, thickness: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable outlined text field
// ─────────────────────────────────────────────────────────────────────────────

class _StyledTextField extends StatefulWidget {
  const _StyledTextField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.hasError = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  @override
  State<_StyledTextField> createState() => _StyledTextFieldState();
}

class _StyledTextFieldState extends State<_StyledTextField> {
  static const _primary = Color(0xFF1A73E8);
  static const _borderDefault = Color(0xFFE8EAED);
  static const _errorRed = Color(0xFFD93025);
  static const _textPrimary = Color(0xFF202124);
  static const _textHint = Color(0xFF9AA0A6);

  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError
        ? _errorRed
        : _focused
            ? _primary
            : _borderDefault;

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: _focused ? 1.8 : 1),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: TextField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: _textHint,
            ),
            suffixIcon: widget.suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role button with hover effect
// ─────────────────────────────────────────────────────────────────────────────

class _RoleButton extends StatefulWidget {
  const _RoleButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<_RoleButton> createState() => _RoleButtonState();
}

class _RoleButtonState extends State<_RoleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Darken by ~10% on hover
    final hoverColor = Color.fromARGB(
      widget.color.alpha,
      (widget.color.red * 0.88).round(),
      (widget.color.green * 0.88).round(),
      (widget.color.blue * 0.88).round(),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 44,
          decoration: BoxDecoration(
            color: _hovered ? hoverColor : widget.color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.textColor,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}
