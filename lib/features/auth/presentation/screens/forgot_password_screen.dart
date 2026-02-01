// ===============================================
// Emie • Forgot Password Screen (Final Cut)
// Pfad: lib/features/auth/presentation/screens/forgot_password_screen.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controller/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _hint;

  // Match Auth UI tokens
  static const _bg = Color(0xFF050307);
  static const _surface = Color(0xFF151119);
  static const _surface2 = Color(0xFF0C0913);
  static const _border = Color(0xFFFFD37F);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    FocusScope.of(context).unfocus();
    auth.clearError();
    setState(() => _hint = null);

    if (!_formKey.currentState!.validate()) return;

    final email = _email.text.trim();

    final ok = await auth.requestPasswordReset(email);

    if (!mounted) return;

    if (ok) {
      setState(() {
        _hint =
            'Wenn ein Account existiert, wurde eine E-Mail zum Zurücksetzen gesendet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Passwort zurücksetzen',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Reset-Link anfordern',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Gib deine E-Mail ein. Wir senden dir einen Link zum Zurücksetzen.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12.8,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'E-Mail',
                          labelStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.mail_outline_rounded,
                              color: Colors.white38, size: 20),
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
                            borderSide: const BorderSide(
                                color: Colors.redAccent, width: 1.1),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Colors.redAccent, width: 1.2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Bitte E-Mail eingeben.';
                          if (!text.contains('@') || !text.contains('.')) {
                            return 'Bitte eine gültige E-Mail-Adresse eingeben.';
                          }
                          return null;
                        },
                      ),

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

                      if (_hint != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _hint!,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              auth.isLoading ? null : () => _submit(auth),
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
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.black),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text('Bitte warten'),
                                    ],
                                  )
                                : const Text(
                                    'Link senden',
                                    key: ValueKey('btn_text'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.8,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
