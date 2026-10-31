import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../state/session_store.dart';
import '../../controller/auth_controller.dart';
import 'verification_recovery_screen.dart';

/// Opening a link never consumes its proof; only the explicit button posts it.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen(
      {super.key, required this.token, required this.onDone});
  final String? token;
  final VoidCallback onDone;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _success = false;
  String? _error;

  Future<void> _confirm(AuthController auth) async {
    if (auth.isLoading || _success || widget.token == null) return;
    final origin = SessionStore.instance.generation;
    setState(() => _error = null);
    final ok = await auth.verifyEmail(widget.token!);
    if (!mounted || !SessionStore.instance.isCurrent(origin)) return;
    setState(() {
      _success = ok;
      _error = ok ? null : auth.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final authenticated = context.watch<SessionStore>().isAuthenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      _success
                          ? 'Deine E-Mail ist bestätigt. Melde dich jetzt mit deinem Passwort an.'
                          : widget.token == null
                              ? 'Dieser Bestätigungslink ist ungültig. Fordere eine neue E-Mail an.'
                              : 'Bestätige die E-Mail-Adresse aus diesem Link. Du wirst dadurch nicht automatisch angemeldet.',
                      key: ValueKey(
                          _success ? 'verify-success' : 'verify-instructions')),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            key: const ValueKey('verify-error'),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 20),
                  if (!_success && widget.token != null)
                    FilledButton(
                        key: const ValueKey('verify-confirm'),
                        onPressed: auth.isLoading ? null : () => _confirm(auth),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('E-Mail bestätigen')),
                  if (!_success)
                    TextButton(
                        key: const ValueKey('verify-resend'),
                        onPressed: auth.isLoading
                            ? null
                            : () {
                                auth.clearError();
                                Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            VerificationRecoveryScreen(
                                                onDone: widget.onDone)));
                              },
                        child: const Text('Neue Bestätigungs-Mail anfordern')),
                  TextButton(
                      key: const ValueKey('verify-return'),
                      onPressed: auth.isLoading ? null : widget.onDone,
                      child: Text(authenticated
                          ? 'Zurück zur App'
                          : 'Zurück zum Login')),
                ])),
      ))),
    );
  }
}
