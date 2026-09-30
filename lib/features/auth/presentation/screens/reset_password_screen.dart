import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../state/session_store.dart';
import '../../controller/auth_controller.dart';
import 'forgot_password_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen(
      {super.key, required this.token, required this.onDone});
  final String? token;
  final VoidCallback onDone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (auth.isLoading || _success || widget.token == null) return;
    auth.clearError();
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final origin = SessionStore.instance.generation;
    final ok = await auth.finishPasswordReset(widget.token!, _password.text);
    if (!mounted || !SessionStore.instance.isCurrent(origin)) return;
    if (ok) {
      _password.clear();
      _confirmation.clear();
      setState(() => _success = true);
    } else {
      setState(() => _error = auth.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final authenticated = context.watch<SessionStore>().isAuthenticated;
    final invalid = widget.token == null;
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Passwort setzen')),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_success)
                    const Text(
                        'Dein Passwort wurde geändert. Melde dich mit dem neuen Passwort an.',
                        key: ValueKey('reset-success'))
                  else if (invalid)
                    const Text(
                        'Dieser Reset-Link ist ungültig. Fordere bitte einen neuen Link an.',
                        key: ValueKey('reset-invalid-link'))
                  else ...[
                    const Text(
                        'Lege ein neues Passwort für das Konto aus deiner Reset-Mail fest.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('reset-password'),
                      controller: _password,
                      enabled: !auth.isLoading,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration:
                          const InputDecoration(labelText: 'Neues Passwort'),
                      validator: (value) => (value ?? '').runes.length < 6
                          ? 'Mindestens 6 Zeichen.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('reset-confirmation'),
                      controller: _confirmation,
                      enabled: !auth.isLoading,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                          labelText: 'Passwort bestätigen'),
                      validator: (value) => value != _password.text
                          ? 'Passwörter stimmen nicht überein.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          key: const ValueKey('reset-error'),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const ValueKey('reset-submit'),
                      onPressed: auth.isLoading ? null : () => _submit(auth),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Passwort speichern'),
                    ),
                  ],
                  if (!_success)
                    TextButton(
                      key: const ValueKey('reset-request-again'),
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              auth.clearError();
                              Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ForgotPasswordScreen()));
                            },
                      child: const Text('Neuen Reset-Link anfordern'),
                    ),
                  TextButton(
                    key: const ValueKey('recovery-return'),
                    onPressed: auth.isLoading ? null : widget.onDone,
                    child: Text(
                        authenticated ? 'Zurück zur App' : 'Zurück zum Login'),
                  ),
                ],
              )),
        ),
      ))),
    );
  }
}
