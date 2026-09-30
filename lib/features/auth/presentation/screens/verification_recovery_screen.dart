import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../state/session_store.dart';
import '../../controller/auth_controller.dart';

class VerificationRecoveryScreen extends StatefulWidget {
  const VerificationRecoveryScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<VerificationRecoveryScreen> createState() =>
      _VerificationRecoveryScreenState();
}

class _VerificationRecoveryScreenState
    extends State<VerificationRecoveryScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _form = GlobalKey<FormState>();
  bool _requested = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (auth.isLoading) return;
    auth.clearError();
    setState(() {
      _requested = false;
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final origin = SessionStore.instance.generation;
    final ok = await auth.requestVerificationResend(_email.text.trim());
    if (!mounted || !SessionStore.instance.isCurrent(origin)) return;
    setState(() {
      _requested = ok;
      _error = ok ? null : auth.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
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
                  const Text(
                      'Keine Mail erhalten oder Link abgelaufen? Fordere eine neue Bestätigungs-Mail an. '
                      'Öffne anschließend den neuesten Link und kehre zum Login zurück.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('verification-email'),
                    controller: _email,
                    enabled: !auth.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'E-Mail'),
                    validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch((value ?? '').trim())
                        ? null
                        : 'Bitte eine gültige E-Mail-Adresse eingeben.',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        key: const ValueKey('verification-error'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_requested) ...[
                    const SizedBox(height: 12),
                    const Text(
                        'Falls für diese Adresse eine Bestätigung nötig ist, wurde eine neue Mail angefordert. '
                        'Prüfe auch den Spamordner. Bereits bestätigt? Melde dich direkt an.',
                        key: ValueKey('verification-requested')),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('verification-submit'),
                    onPressed: auth.isLoading ? null : () => _submit(auth),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('E-Mail erneut senden'),
                  ),
                  TextButton(
                    key: const ValueKey('verification-return'),
                    onPressed: auth.isLoading
                        ? null
                        : () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                    child: const Text('Zurück zum Login'),
                  ),
                ],
              )),
        ),
      ))),
    );
  }
}
