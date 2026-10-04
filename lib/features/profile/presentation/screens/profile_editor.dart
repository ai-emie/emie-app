import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/local_probe.dart';
import '../../../../core/localization/b2_text.dart';
import '../../../../data/auth/auth_models.dart';
import '../../../../data/profile/profile_api.dart';
import '../../../../state/session_store.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, this.api});
  final ProfileApi? api;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final api = widget.api ?? ProfileApi();
  late final session = context.read<SessionStore>();
  late final generation = session.generation;
  final username = TextEditingController(),
      bio = TextEditingController(),
      goal = TextEditingController();
  final form = GlobalKey<FormState>();
  EditableProfile? saved;
  bool busy = false, failed = false, uncertain = false;
  bool get current => mounted && session.isCurrent(generation);
  bool get dirty =>
      saved != null &&
      (username.text != saved!.username ||
          bio.text != saved!.bio ||
          goal.text != saved!.dailyGoal);
  @override
  void initState() {
    super.initState();
    for (final field in [username, bio, goal]) {
      field.addListener(changed);
    }
    load();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    username.dispose();
    bio.dispose();
    goal.dispose();
    super.dispose();
  }

  void accept(EditableProfile profile) {
    localProbe('profile.accept', current: current, same: profile.id == session.user?.id);
    if (profile.id != session.user?.id) {
      throw const FormatException('Profile identity mismatch');
    }
    saved = profile;
    username.text = profile.username;
    bio.text = profile.bio;
    goal.text = profile.dailyGoal;
    uncertain = failed = false;
    session.updateUser(
        UserProfile(
            id: profile.id, email: profile.email, name: profile.username),
        generation: generation);
  }

  Future<void> load() async {
    if (busy) return;
    if (dirty &&
        !await b2Confirm(context, 'Änderungen verwerfen und neu laden?',
            'Discard changes and reload?')) {
      return;
    }
    if (!mounted || !current) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final profile = await api.get(generation);
      if (current) setState(() => accept(profile));
    } catch (error) {
      localProbe('profile.load_error', current: current, errorClass: error.runtimeType.toString());
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
      final profile = await api.save(
          username: username.text,
          bio: bio.text,
          dailyGoal: goal.text,
          generation: generation);
      if (!mounted || !current) return;
      setState(() => accept(profile));
      b2Notice(context, 'Profil gespeichert.', 'Profile saved.');
    } catch (_) {
      if (current) {
        setState(() {
          failed = uncertain = true;
        });
      }
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
            saved = null;
            if (context.mounted) Navigator.pop(context);
          }
        },
        child: Scaffold(
            appBar: AppBar(
                title: Text(b2(context, 'Profil bearbeiten', 'Edit profile')),
                actions: [
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
                    Text(uncertain
                        ? b2(
                            context,
                            'Speichern nicht bestätigt. Bitte vor einer weiteren Änderung neu laden.',
                            'Save unconfirmed. Please reload before another change.')
                        : b2(context, 'Profil konnte nicht geladen werden.',
                            'Could not load profile.')),
                  if (saved == null && !busy)
                    TextButton(
                        onPressed: load,
                        child: Text(b2(context, 'Erneut versuchen', 'Retry'))),
                  if (saved != null) ...[
                    Text(saved!.email),
                    Text(b2(
                        context,
                        'Änderungen werden auch in deinen vorhandenen Profilerinnerungen berücksichtigt.',
                        'Changes also update your existing profile memories.')),
                    if (dirty)
                      Text(b2(context, 'Ungespeicherte Änderungen',
                          'Unsaved changes')),
                    for (final field in [
                      (
                        username,
                        120,
                        b2(context, 'Anzeigename', 'Display name')
                      ),
                      (bio, 2000, b2(context, 'Über mich', 'About me')),
                      (goal, 1000, b2(context, 'Tagesziel', 'Daily goal'))
                    ])
                      TextFormField(
                          key: ObjectKey(field.$1),
                          controller: field.$1,
                          enabled: !busy,
                          maxLines: field.$1 == username ? 1 : 4,
                          decoration: InputDecoration(
                              labelText: field.$3,
                              helperText: b2(
                                  context,
                                  'Bis zu ${field.$2} Zeichen',
                                  'Up to ${field.$2} characters')),
                          validator: (value) =>
                              (value?.runes.length ?? 0) > field.$2
                                  ? b2Read(context, 'Bitte Text kürzen.',
                                      'Please shorten the text.')
                                  : null),
                    FilledButton(
                        onPressed: busy || uncertain || !dirty ? null : save,
                        child: Text(b2(context, 'Speichern', 'Save'))),
                  ],
                ]))),
      );
}
