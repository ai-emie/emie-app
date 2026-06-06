// ===============================================
// Emie • Luxury Auth Screen (Login & Register)
// Pfad: lib/features/auth/presentation/screens/auth_screen.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'forgot_password_screen.dart';

import '../../../home/presentation/screens/home_screen.dart';
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
  //  Luxury Theme Tokens
  // -----------------------------------------------
  static const _bg = Color(0xFF050307);
  static const _surface = Color(0xFF141116);
  static const _surface2 = Color(0xFF0C0913);
  static const _gold = Color(0xFF8A6117);
  static const _champagne = Color(0xFFFCF6BA);
  static const _muted = Color(0xFF8E8B85);

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
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      final success = await auth.registerWithEmail(name, email, password);

      if (!mounted) return;

      if (success) {
        setState(() {
          _uiHint =
              'Registrierung erfolgreich. Bitte bestätige deine E-Mail und logge dich danach ein.';
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
      return const HomeScreen();
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      _buildHeader(),
                      const SizedBox(height: 22),
                      _buildFormCard(context, auth),
                      const SizedBox(height: 16),
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
  //  HEADER
  // ===============================================
  Widget _buildHeader() {
    return Column(
      children: [
        Opacity(
          opacity: 0.96,
          child: Image.asset(
            'assets/images/emiso.logo.transparent.png',
            height: 88,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.auto_awesome_rounded,
              color: _champagne,
              size: 54,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Emie',
          style: TextStyle(
            color: _champagne,
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _isLoginMode
                ? 'Willkommen zurück.'
                : 'Erstelle deinen persönlichen Zugang.',
            key: ValueKey(_isLoginMode),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.64),
              fontSize: 14,
              height: 1.35,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Built around you.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.36),
            fontSize: 12,
            letterSpacing: 0.25,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 1,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                _gold.withOpacity(0.34),
                Colors.transparent,
              ],
            ),
          ),
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
      padding: const EdgeInsets.all(0.8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            _gold.withOpacity(0.10),
            _gold.withOpacity(0.28),
            _champagne.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.88),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: _gold.withOpacity(0.14),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.56),
              blurRadius: 34,
              offset: const Offset(0, 22),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    letterSpacing: -0.1,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isLoginMode
                      ? 'Melde dich an und öffne dein persönliches System.'
                      : 'Starte mit Emie in wenigen Sekunden.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.52),
                    fontSize: 12.9,
                    height: 1.35,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 18),

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
                    color: _champagne.withOpacity(0.42),
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
                    child: Text(
                      'Passwort vergessen?',
                      style: TextStyle(
                        color: _champagne.withOpacity(0.62),
                        fontSize: 12.8,
                        fontFamily: 'Inter',
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
                      color: _champagne.withOpacity(0.42),
                    ),
                    onPressed: () {
                      setState(
                        () => _passwordConfirmVisible =
                            !_passwordConfirmVisible,
                      );
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
                const SizedBox(height: 11),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    auth.errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12.2,
                      height: 1.3,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],

              // Calm hint (UI, no snackbars)
              if (_uiHint != null) ...[
                const SizedBox(height: 11),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _uiHint!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.56),
                      fontSize: 12.2,
                      height: 1.35,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Primary Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : () => _submit(auth),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    backgroundColor: _champagne,
                    foregroundColor: const Color(0xFF17130C),
                    elevation: 0,
                    disabledBackgroundColor: _muted.withOpacity(0.42),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF17130C),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Bitte warten',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isLoginMode ? 'Einloggen' : 'Registrieren',
                            key: const ValueKey('btn_text'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.8,
                              letterSpacing: 0.1,
                              fontFamily: 'Inter',
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Social
              _buildSocialSection(auth),

              const SizedBox(height: 8),

              // Toggle
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () {
                        auth.clearError();
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _uiHint = null;
                        });
                      },
                child: Text(
                  _isLoginMode
                      ? 'Noch kein Account? Registrieren'
                      : 'Schon einen Account? Einloggen',
                  style: TextStyle(
                    color: _champagne.withOpacity(0.72),
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
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
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Inter',
      ),
      cursorColor: _champagne,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.44),
          fontFamily: 'Inter',
        ),
        prefixIcon: Icon(
          icon,
          color: _champagne.withOpacity(0.38),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.035),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: _gold.withOpacity(0.15),
            width: 0.9,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: _champagne.withOpacity(0.70),
            width: 1.25,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
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
            Expanded(
              child: Divider(
                color: _gold.withOpacity(0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'oder',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 12.5,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: _gold.withOpacity(0.15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final success = await auth.loginWithApple();
                        if (!mounted) return;
                        if (success) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        }
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: _gold.withOpacity(0.18),
                    width: 0.9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.025),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/apple_logo.png',
                      height: 18,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.apple_rounded,
                        size: 20,
                        color: Colors.white.withOpacity(0.82),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Apple',
                      style: TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final success = await auth.loginWithGoogle();
                        if (!mounted) return;
                        if (success) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        }
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: _gold.withOpacity(0.18),
                    width: 0.9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.025),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/google_logo.png',
                      height: 18,
                      errorBuilder: (_, __, ___) => Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.86),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Google',
                      style: TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
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
        'Your Second Brain. Under your control.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.34),
          fontSize: 11.8,
          height: 1.3,
          letterSpacing: 0.2,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ===========================================================
//  Background: subtle luxury glow
// ===========================================================
class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  static const _bg = Color(0xFF050307);
  static const _bg2 = Color(0xFF07040D);
  static const _gold = Color(0xFF8A6117);
  static const _champagne = Color(0xFFFCF6BA);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bg, _bg2, _bg],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.76),
            child: Container(
              width: 540,
              height: 540,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _champagne.withOpacity(0.075),
                    _gold.withOpacity(0.030),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.38, 0.78],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withOpacity(0.065),
                    Colors.transparent,
                  ],
                  radius: 0.72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}