import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/b2_text.dart';
import '../../../../data/memory/api/memory_api.dart';
import '../../../../data/memory/models/memory_item.dart';
import '../../../../state/session_store.dart';

class MemoryEditor extends StatefulWidget {
  const MemoryEditor({super.key, required this.item, this.api});
  final MemoryItem item;
  final MemoryApi? api;
  @override
  State<MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<MemoryEditor> {
  late final api = widget.api ?? MemoryApi();
  late final generation = context.read<SessionStore>().generation;
  late MemoryItem saved = widget.item;
  late final content = TextEditingController(text: saved.content)
    ..addListener(changed);
  bool busy = false, uncertain = false, missing = false;
  bool get current => mounted && SessionStore.instance.isCurrent(generation);
  bool get dirty => content.text != saved.content;
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    if (busy || !current) return;
    if (dirty &&
        !await b2Confirm(context, 'Änderungen verwerfen und neu laden?',
            'Discard changes and reload?')) {
      return;
    }
    if (!mounted || !current) return;
    setState(() => busy = true);
    try {
      final value = await api.getById(saved.id, generation);
      if (!mounted || !current) return;
      setState(() {
        missing = value == null;
        if (value != null) {
          saved = value;
          content.text = value.content;
        }
        uncertain = false;
      });
    } catch (_) {
      if (mounted && current) {
        b2Notice(context, 'Laden fehlgeschlagen.', 'Loading failed.');
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> write({bool delete = false}) async {
    if (busy || uncertain || !current || missing) return;
    if (delete &&
        !await b2Confirm(context, 'Erinnerung endgültig löschen?',
            'Permanently delete memory?')) {
      return;
    }
    if (!mounted || !current) return;
    setState(() => busy = true);
    try {
      if (delete) {
        await api.deleteMemory(saved.id, generation: generation);
        if (!mounted || !current) return;
        b2Notice(context, 'Erinnerung gelöscht.', 'Memory deleted.');
        content.text = saved.content;
        Navigator.pop(context);
      } else {
        final value = await api.updateMemory(
            id: saved.id, content: content.text.trim(), generation: generation);
        if (!mounted || !current) return;
        setState(() {
          saved = value;
          content.text = value.content;
        });
        b2Notice(context, 'Erinnerung gespeichert.', 'Memory saved.');
      }
    } catch (_) {
      if (current) setState(() => uncertain = true);
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !dirty && !busy,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop &&
              !busy &&
              await b2Confirm(context, 'Ungespeicherte Änderungen verwerfen?',
                  'Discard unsaved changes?') &&
              current) {
            content.text = saved.content;
            if (context.mounted) Navigator.pop(context);
          }
        },
        child: Scaffold(
            appBar: AppBar(
                title:
                    Text(b2(context, 'Erinnerung bearbeiten', 'Edit memory')),
                actions: [
                  IconButton(
                      onPressed: busy ? null : reload,
                      tooltip: b2(context, 'Neu laden', 'Reload'),
                      icon: const Icon(Icons.refresh)),
                ]),
            body: ListView(padding: const EdgeInsets.all(22), children: [
              if (busy) const LinearProgressIndicator(),
              if (uncertain)
                Text(b2(
                    context,
                    'Änderung nicht bestätigt. Lade den Stand vor einer weiteren Änderung neu.',
                    'Change unconfirmed. Reload before making another change.')),
              if (missing)
                Text(b2(context, 'Diese Erinnerung ist nicht mehr vorhanden.',
                    'This memory no longer exists.')),
              Text(dirty
                  ? b2(context, 'Ungespeicherte Änderungen', 'Unsaved changes')
                  : b2(context, 'Gespeicherter Inhalt', 'Saved content')),
              TextField(
                  key: const ValueKey('memory-content'),
                  controller: content,
                  enabled: !busy && !missing,
                  minLines: 6,
                  maxLines: null,
                  decoration: InputDecoration(
                      labelText: b2(context, 'Erinnerung', 'Memory'))),
              FilledButton(
                  onPressed: busy ||
                          uncertain ||
                          missing ||
                          !dirty ||
                          content.text.trim().isEmpty
                      ? null
                      : () => write(),
                  child: Text(b2(context, 'Speichern', 'Save'))),
              TextButton(
                  onPressed: busy || uncertain || missing
                      ? null
                      : () => write(delete: true),
                  child: Text(b2(context, 'Löschen', 'Delete'))),
            ])),
      );
}
