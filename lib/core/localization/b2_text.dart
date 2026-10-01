import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/session_store.dart';

String b2(BuildContext context, String de, String en) =>
    context.watch<SessionStore>().language == 'de' ? de : en;

String b2Read(BuildContext context, String de, String en) =>
    context.read<SessionStore>().language == 'de' ? de : en;

void b2Notice(BuildContext context, String de, String en) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(b2Read(context, de, en))));
}

Future<bool> b2Confirm(BuildContext context, String de, String en) async =>
    await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              content: Text(b2(dialog, de, en)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(b2(dialog, 'Abbrechen', 'Cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(b2(dialog, 'Bestätigen', 'Confirm'))),
              ],
            )) ??
    false;
