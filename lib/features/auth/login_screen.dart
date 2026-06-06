import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../company_admin/admin_shell.dart';

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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────────────────────
  Future<void> _handleSignIn() async {
    setState(() {
      _emailError = _emailCtrl.text.trim().isEmpty ? 'Email address is required' : null;
      _passwordError = _passwordCtrl.text.isEmpty ? 'Password is required' : null;
    });

    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminShell()),
    );
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

                    // ── Sign In button ────────────────────────
                    _buildSignInButton(),
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
    return _HoverButton(
      onTap: _isLoading ? null : _handleSignIn,
      isLoading: _isLoading,
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
// Sign In button with hover effect
// ─────────────────────────────────────────────────────────────────────────────

class _HoverButton extends StatefulWidget {
  const _HoverButton({required this.onTap, required this.isLoading});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  static const _primary = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: _hovered && !widget.isLoading ? _primaryDark : _primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered && !widget.isLoading
                ? [
                    BoxShadow(
                      color: _primary.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Text(
                    'Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
