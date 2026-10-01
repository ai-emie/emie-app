import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/b2_text.dart';
import '../../../../data/projects/project_api.dart';
import '../../../../state/session_store.dart';

class ProjectEditor extends StatefulWidget {
  const ProjectEditor({super.key, this.projectId, this.api});
  final String? projectId;
  final ProjectApi? api;
  @override
  State<ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<ProjectEditor> {
  late final api = widget.api ?? ProjectApi();
  late final generation = context.read<SessionStore>().generation;
  final name = TextEditingController(),
      description = TextEditingController(),
      content = TextEditingController();
  final form = GlobalKey<FormState>();
  Project? saved;
  String? id;
  bool busy = false,
      failed = false,
      uncertain = false,
      ready = false,
      allowDiscard = false;
  bool get current => mounted && SessionStore.instance.isCurrent(generation);
  bool get dirty =>
      name.text != (saved?.name ?? '') ||
      description.text != (saved?.description ?? '') ||
      content.text != (saved?.content ?? '');
  @override
  void initState() {
    super.initState();
    id = widget.projectId;
    for (final field in [name, description, content]) {
      field.addListener(changed);
    }
    if (id == null) {
      ready = true;
    } else {
      load();
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  String? checkLength(String? value, int limit) =>
      (value?.runes.length ?? 0) > limit
          ? b2Read(context, 'Bitte Text kürzen.', 'Please shorten the text.')
          : null;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    content.dispose();
    super.dispose();
  }

  void accept(Project value) {
    saved = value;
    id = value.id;
    name.text = value.name;
    description.text = value.description;
    content.text = value.content;
    ready = true;
    uncertain = failed = false;
  }

  Future<void> load() async {
    if (busy || id == null) return;
    if (dirty &&
        !await b2Confirm(
            context,
            'Ungespeicherte Änderungen verwerfen und neu laden?',
            'Discard unsaved changes and reload?')) {
      return;
    }
    if (!mounted || !current) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final value = await api.get(id!, generation);
      if (current) setState(() => accept(value));
    } catch (_) {
      if (current) setState(() => failed = true);
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!current || busy || uncertain || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final value = await api.save(
          id: id,
          name: name.text.trim(),
          description: description.text,
          content: content.text,
          generation: generation);
      if (!mounted || !current) return;
      setState(() => accept(value));
      b2Notice(context, 'Projekt gespeichert.', 'Project saved.');
    } catch (error) {
      if (!mounted || !current) return;
      setState(() {
        failed = true;
        uncertain = !(error is DioException &&
            [400, 401, 403, 404, 422].contains(error.response?.statusCode));
      });
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    if (!current || busy || id == null || uncertain) return;
    if (!await b2Confirm(
        context,
        'Dieses Projekt mit seinem gesamten Inhalt löschen?',
        'Delete this project and all its content?')) {
      return;
    }
    if (!mounted || !current) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await api.delete(id!, generation);
      if (!mounted || !current) return;
      b2Notice(context, 'Projekt gelöscht.', 'Project deleted.');
      Navigator.pop(context);
    } catch (_) {
      if (current) {
        setState(() {
          uncertain = failed = true;
        });
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<bool> leave() async =>
      !busy &&
      (!dirty ||
          await b2Confirm(context, 'Ungespeicherte Änderungen verwerfen?',
              'Discard unsaved changes?'));
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: allowDiscard || (!dirty && !busy),
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && await leave() && current) {
            setState(() => allowDiscard = true);
            if (context.mounted) Navigator.pop(context);
          }
        },
        child: Scaffold(
            appBar: AppBar(
                title: Text(b2(context, 'Projekt', 'Project')),
                actions: [
                  if (id != null)
                    IconButton(
                        onPressed: busy ? null : load,
                        tooltip: b2(context, 'Neu laden', 'Reload'),
                        icon: const Icon(Icons.refresh)),
                ]),
            body: Form(
                key: form,
                child: ListView(padding: const EdgeInsets.all(22), children: [
                  if (busy) const LinearProgressIndicator(),
                  if (failed)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(uncertain
                            ? b2(
                                context,
                                'Ausgang nicht bestätigt. Bitte den gespeicherten Stand neu laden bzw. die Projektliste prüfen, bevor du erneut speicherst oder löschst.',
                                'Outcome unconfirmed. Reload the saved version or check the project list before saving or deleting again.')
                            : b2(
                                context,
                                'Vorgang fehlgeschlagen. Prüfe deine Eingaben und versuche es erneut.',
                                'Operation failed. Check your input and try again.'))),
                  if (!ready && !busy)
                    TextButton(
                        onPressed: load,
                        child:
                            Text(b2(context, 'Erneut laden', 'Retry loading'))),
                  if (ready) ...[
                    Text(id == null
                        ? b2(context, 'Noch nicht gespeichert', 'Not saved yet')
                        : dirty
                            ? b2(context, 'Ungespeicherte Änderungen',
                                'Unsaved changes')
                            : b2(
                                context, 'Stand gespeichert', 'Saved version')),
                    TextFormField(
                        key: const ValueKey('project-name'),
                        controller: name,
                        enabled: !busy,
                        maxLength: 120,
                        decoration: InputDecoration(
                            labelText: b2(context, 'Name', 'Name')),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? b2Read(context, 'Name ist erforderlich.',
                                    'Name is required.')
                                : checkLength(value.trim(), 120)),
                    TextFormField(
                        key: const ValueKey('project-description'),
                        controller: description,
                        enabled: !busy,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                            labelText: b2(
                                context,
                                'Kurzbeschreibung (optional)',
                                'Description (optional)')),
                        validator: (value) => checkLength(value, 1000)),
                    TextFormField(
                        key: const ValueKey('project-content'),
                        controller: content,
                        enabled: !busy,
                        maxLength: 100000,
                        minLines: 8,
                        maxLines: null,
                        decoration: InputDecoration(
                            labelText:
                                b2(context, 'Arbeitsnotiz', 'Workspace note'),
                            alignLabelWithHint: true),
                        validator: (value) => checkLength(value, 100000)),
                    FilledButton(
                        key: const ValueKey('save-project'),
                        onPressed: busy || uncertain || (!dirty && id != null)
                            ? null
                            : save,
                        child: Text(b2(context, 'Speichern', 'Save'))),
                    if (id != null)
                      TextButton(
                          onPressed: busy || uncertain ? null : remove,
                          child: Text(b2(
                              context, 'Projekt löschen', 'Delete project'))),
                  ],
                ]))),
      );
}
