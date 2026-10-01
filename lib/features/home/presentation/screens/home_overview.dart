import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/localization/b2_text.dart';
import '../../../../data/home/api/home_api.dart';
import '../../../../data/home/models/home_summary_model.dart';
import '../../../../state/session_store.dart';
import '../../../memory/presentation/screens/memory_editor.dart';
import '../../../memory/presentation/screens/memory_screen.dart';
import '../../../projects/presentation/screens/project_editor.dart';
import '../../../projects/presentation/screens/project_screen.dart';

class HomeOverview extends StatefulWidget {
  const HomeOverview({super.key, this.api, this.isActive = true});
  final HomeApi? api;
  final bool isActive;
  @override
  State<HomeOverview> createState() => _HomeOverviewState();
}

class _HomeOverviewState extends State<HomeOverview> {
  late final api = widget.api ?? HomeApi();
  final session = SessionStore.instance;
  late int generation = session.generation;
  HomeSummaryModel? summary;
  bool loading = false, failed = false;
  int request = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    session.addListener(identityChanged);
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    load();
  }

  void identityChanged() {
    if (generation == session.generation) return;
    generation = session.generation;
    request++;
    setState(() {
      summary = null;
      loading = failed = false;
    });
  }

  @override
  void didUpdateWidget(covariant HomeOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) load();
  }

  @override
  void dispose() {
    timer?.cancel();
    session.removeListener(identityChanged);
    request++;
    super.dispose();
  }

  Future<void> load() async {
    final stamp = ++request, origin = generation;
    setState(() {
      loading = true;
      failed = false;
    });
    bool current() => mounted && stamp == request && session.isCurrent(origin);
    try {
      final result = await api.fetchSummary(generation: origin);
      if (current()) setState(() => summary = result);
    } catch (_) {
      if (current()) setState(() => failed = true);
    } finally {
      if (current()) setState(() => loading = false);
    }
  }

  Future<void> open(Widget screen) async {
    final origin = generation;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted && session.isCurrent(origin)) await load();
  }

  @override
  Widget build(BuildContext context) {
    final data = summary;
    final stale = data != null &&
        (failed || DateTime.now().difference(data.generatedAt).inMinutes >= 5);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(b2(context, 'Dein gespeicherter Bestand',
                          'Your saved workspace'))),
                  IconButton(
                      tooltip: b2(context, 'Aktualisieren', 'Refresh'),
                      onPressed: load,
                      icon: const Icon(Icons.refresh))
                ]),
                if (loading) const LinearProgressIndicator(),
                if (failed)
                  Text(b2(context, 'Übersicht konnte nicht geladen werden.',
                      'Could not load overview.')),
                if (stale)
                  Text(b2(
                      context,
                      'Stand möglicherweise veraltet. Bitte aktualisieren.',
                      'Data may be out of date. Please refresh.')),
                if (data != null) ...[
                  Text(b2(
                      context,
                      '${data.totalProjects} Projekte · ${data.totalMemories} Erinnerungen',
                      '${data.totalProjects} projects · ${data.totalMemories} memories')),
                  Text(b2(
                      context,
                      '${data.memoriesToday} Erinnerungen heute (UTC)',
                      '${data.memoriesToday} memories today (UTC)')),
                  Text(b2(context, 'Stand: ${data.generatedAt.toLocal()}',
                      'Updated: ${data.generatedAt.toLocal()}')),
                  if (data.recentProject != null)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(data.recentProject!.name),
                        subtitle: Text(b2(
                            context,
                            'Zuletzt bearbeitetes Projekt',
                            'Last edited project')),
                        leading: const Icon(Icons.folder_outlined),
                        onTap: () => open(
                            ProjectEditor(projectId: data.recentProject!.id)))
                  else
                    Text(b2(context, 'Noch keine Projekte gespeichert.',
                        'No saved projects yet.')),
                  if (data.recentMemory != null)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(data.recentMemory!.content,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            b2(context, 'Neueste Erinnerung', 'Latest memory')),
                        leading: const Icon(Icons.psychology_outlined),
                        onTap: () =>
                            open(MemoryEditor(item: data.recentMemory!)))
                  else
                    Text(b2(context, 'Noch keine Erinnerungen gespeichert.',
                        'No saved memories yet.')),
                  Wrap(spacing: 12, children: [
                    TextButton(
                        onPressed: () => open(const ProjectScreen()),
                        child:
                            Text(b2(context, 'Alle Projekte', 'All projects'))),
                    TextButton(
                        onPressed: () => open(const MemoryScreen()),
                        child: Text(
                            b2(context, 'Alle Erinnerungen', 'All memories'))),
                  ]),
                ],
              ],
            )));
  }
}
