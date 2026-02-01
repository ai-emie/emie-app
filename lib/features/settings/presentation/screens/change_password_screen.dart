// ===============================================
// Emie • Change Password Screen (Beta v1 Base)
// Pfad: lib/features/settings/presentation/screens/change_password_screen.dart
// ===============================================

import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _next2 = TextEditingController();

  String? _hint;
  bool _isSaving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _next2.dispose();
    super.dispose();
  }

  void _save() async {
    setState(() => _hint = null);

    final cur = _current.text.trim();
    final n1 = _next.text.trim();
    final n2 = _next2.text.trim();

    if (cur.isEmpty || n1.isEmpty || n2.isEmpty) {
      setState(() => _hint = 'Bitte alle Felder ausfüllen.');
      return;
    }
    if (n1.length < 8) {
      setState(() => _hint = 'Neues Passwort muss mindestens 8 Zeichen haben.');
      return;
    }
    if (n1 != n2) {
      setState(() => _hint = 'Neue Passwörter stimmen nicht überein.');
      return;
    }

    setState(() {
      _isSaving = true;
      _hint = null;
    });

    // Beta v1: UI steht, Backend-Call kommt als nächster Schritt.
    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _hint = 'Beta v1: Passwort-Änderung wird als nächstes mit dem Backend verbunden.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF050307) : const Color(0xFFFFFFFF);
    final surface = isDark ? const Color(0xFF131319) : const Color(0xFFF4F4F4);
    final border = isDark ? Colors.white12 : Colors.black12;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0E0E0E);
    final textSecondary = isDark ? Colors.white54 : Colors.black54;

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textSecondary),
          filled: true,
          fillColor: surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFFD37F)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Passwort ändern',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Sicherheit',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _current,
              obscureText: true,
              style: TextStyle(color: textPrimary),
              decoration: deco('Aktuelles Passwort'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _next,
              obscureText: true,
              style: TextStyle(color: textPrimary),
              decoration: deco('Neues Passwort (mind. 8 Zeichen)'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _next2,
              obscureText: true,
              style: TextStyle(color: textPrimary),
              decoration: deco('Neues Passwort wiederholen'),
            ),

            if (_hint != null) ...[
              const SizedBox(height: 10),
              Text(
                _hint!,
                style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.35),
              ),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSaving ? null : _save,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(color: border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(_isSaving ? 'Speichern…' : 'Speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
