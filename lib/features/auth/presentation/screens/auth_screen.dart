// ===============================================
// Emie • Professional Auth Screen (Login & Register)
// Pfad: lib/features/auth/presentation/screens/auth_screen.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'forgot_password_screen.dart';

import '../../../chat/presentation/screens/chat_screen.dart';
import '../../controller/auth_controller.dart';
import '../../../../state/session_store.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // -----------------------------------------------
  //  Form-Key & Text-Controller
  // -----------------------------------------------
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoginMode = true;
  bool _passwordVisible = false;
  bool _passwordConfirmVisible = false;

  // -----------------------------------------------
  //  Calm inline hint (no snackbars)
  // -----------------------------------------------
  String? _uiHint;

  // -----------------------------------------------
  //  Theme Tokens (match Chat UI)
  // -----------------------------------------------
  static const _bg = Color(0xFF050307);
  static const _surface = Color(0xFF151119);
  static const _surface2 = Color(0xFF0C0913);
  static const _border = Color(0xFFFFD37F);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  // ===============================================
  //  SUBMIT-LOGIK
  // ===============================================
  Future<void> _submit(AuthController auth) async {
    FocusScope.of(context).unfocus();
    auth.clearError();
    setState(() => _uiHint = null);

    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLoginMode) {
      final success = await auth.loginWithEmail(email, password);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    } else {
      final success = await auth.registerWithEmail(name, email, password);

      if (!mounted) return;

      if (success) {
        // Final Cut: no snackbars
        setState(() {
          _uiHint =
              'Registrierung erfolgreich. Bitte E-Mail bestätigen und danach einloggen.';
          _isLoginMode = true;
        });
      }
    }
  }

  // ===============================================
  //  BUILD
  // ===============================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final session = context.watch<SessionStore>();

    if (session.isAuthenticated) {
      return const ChatScreen();
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildFormCard(context, auth),
                      const SizedBox(height: 14),
                      _buildFooterNote(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================
  //  HEADER (Emiso Logo + clean copy)
  // ===============================================
  Widget _buildHeader() {
    return Column(
      children: [
        Opacity(
          opacity: 0.95,
          child: Image.asset(
            'assets/images/emiso.logo.transparent.png',
            height: 88,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Emie',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _isLoginMode
                ? 'Melde dich an, um fortzufahren.'
                : 'Erstelle deinen Account in wenigen Sekunden.',
            key: ValueKey(_isLoginMode),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Professional Personal AI',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 1,
          width: double.infinity,
          color: _border.withOpacity(0.20),
        ),
      ],
    );
  }

  // ===============================================
  //  FORM CARD
  // ===============================================
  Widget _buildFormCard(BuildContext context, AuthController auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.80),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isLoginMode ? 'Einloggen' : 'Registrieren',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isLoginMode
                    ? 'E-Mail und Passwort eingeben.'
                    : 'Name, E-Mail und Passwort festlegen.',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12.8,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name (Register only)
            if (!_isLoginMode) ...[
              _buildTextField(
                controller: _nameController,
                label: 'Name',
                icon: Icons.person_outline_rounded,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Bitte deinen Namen eingeben.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Email
            _buildTextField(
              controller: _emailController,
              label: 'E-Mail',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Bitte E-Mail eingeben.';
                if (!text.contains('@') || !text.contains('.')) {
                  return 'Bitte eine gültige E-Mail-Adresse eingeben.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: 'Passwort',
              icon: Icons.lock_outline_rounded,
              obscureText: !_passwordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                  color: Colors.white38,
                ),
                onPressed: () {
                  setState(() => _passwordVisible = !_passwordVisible);
                },
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return 'Bitte Passwort eingeben.';
                if (text.length < 6) return 'Mindestens 6 Zeichen.';
                return null;
              },
            ),

            // Forgot password (Login only)
            if (_isLoginMode) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                  child: const Text(
                    'Passwort vergessen?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.8,
                    ),
                  ),
                ),
              ),
            ],

            // Confirm password (Register only)
            if (!_isLoginMode) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _passwordConfirmController,
                label: 'Passwort bestätigen',
                icon: Icons.lock_outline_rounded,
                obscureText: !_passwordConfirmVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordConfirmVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: Colors.white38,
                  ),
                  onPressed: () {
                    setState(() => _passwordConfirmVisible =
                        !_passwordConfirmVisible);
                  },
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) return 'Bitte Passwort bestätigen.';
                  if (text != _passwordController.text) {
                    return 'Passwörter stimmen nicht überein.';
                  }
                  return null;
                },
              ),
            ],

            // Error (backend)
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  auth.errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
            ],

            // Calm hint (UI, no snackbars)
            if (_uiHint != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _uiHint!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Primary Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : () => _submit(auth),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  backgroundColor: _border,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  disabledBackgroundColor:
                      Colors.grey.shade600.withOpacity(0.55),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: auth.isLoading
                      ? Row(
                          key: const ValueKey('loading'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Bitte warten'),
                          ],
                        )
                      : Text(
                          _isLoginMode ? 'Einloggen' : 'Registrieren',
                          key: const ValueKey('btn_text'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.8,
                            letterSpacing: 0.1,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Social
            _buildSocialSection(auth),

            const SizedBox(height: 8),

            // Toggle
            TextButton(
              onPressed: auth.isLoading
                  ? null
                  : () {
                      setState(() => _isLoginMode = !_isLoginMode);
                      auth.clearError();
                      setState(() => _uiHint = null);
                    },
              child: Text(
                _isLoginMode
                    ? 'Noch kein Account? Registrieren'
                    : 'Schon einen Account? Einloggen',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================
  //  GENERISCHE TEXTFELDER
  // ===============================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surface2.withOpacity(0.92),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.14),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: _border.withOpacity(0.85),
            width: 1.35,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: validator,
    );
  }

  // ===============================================
  //  SOCIAL SECTION (Apple / Google)
  // ===============================================
  Widget _buildSocialSection(AuthController auth) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.16))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'oder',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12.5,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.16))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    auth.isLoading ? null : () async => auth.loginWithApple(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(color: Colors.white.withOpacity(0.18), width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/apple_logo.png', height: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Apple',
                      style: TextStyle(
                          fontSize: 13.2, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed:
                    auth.isLoading ? null : () async => auth.loginWithGoogle(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(color: Colors.white.withOpacity(0.18), width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/google_logo.png', height: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Google',
                      style: TextStyle(
                          fontSize: 13.2, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===============================================
  //  FOOTER NOTE
  // ===============================================
  Widget _buildFooterNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        'powered by Emiso',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 11.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ===========================================================
//  Background: subtle glow only (no logo watermark)
// ===========================================================
class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF050307),
            Color(0xFF07040D),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.75),
        child: Container(
          width: 520,
          height: 520,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFFFD37F).withOpacity(0.08),
                Colors.transparent,
              ],
              radius: 0.75,
            ),
          ),
        ),
      ),
    );
  }
}
