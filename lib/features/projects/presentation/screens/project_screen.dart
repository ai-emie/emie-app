import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/b2_text.dart';
import '../../../../data/projects/project_api.dart';
import '../../../../state/paged_list.dart';
import '../../../../state/session_store.dart';
import 'project_editor.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key, this.api, this.isActive = true});
  final ProjectApi? api;
  final bool isActive;
  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late final ProjectApi api = widget.api ?? ProjectApi();
  late final PagedList<Project> list =
      PagedList(fetch: api.list, id: (p) => p.id);
  @override
  void initState() {
    super.initState();
    list.refresh();
  }

  @override
  void didUpdateWidget(covariant ProjectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      list.refresh(through: list.items.length);
    }
  }

  @override
  void dispose() {
    list.dispose();
    super.dispose();
  }

  Future<void> open([Project? project]) async {
    final generation = context.read<SessionStore>().generation;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProjectEditor(projectId: project?.id, api: api)));
    if (mounted && SessionStore.instance.isCurrent(generation)) {
      await list.refresh(through: list.items.length);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: list,
      builder: (context, _) => Scaffold(
            appBar: AppBar(
                title: Text(b2(context, 'Projekte', 'Projects')),
                actions: [
                  IconButton(
                      tooltip: b2(context, 'Aktualisieren', 'Refresh'),
                      onPressed: () => list.refresh(),
                      icon: const Icon(Icons.refresh)),
                ]),
            body: RefreshIndicator(
                onRefresh: () => list.refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 130),
                  children: [
                    Text(b2(context, 'Dein privater Arbeitsraum für Notizen.',
                        'Your private workspace for notes.')),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        key: const ValueKey('create-project'),
                        onPressed: () => open(),
                        icon: const Icon(Icons.add),
                        label: Text(
                            b2(context, 'Projekt anlegen', 'Create project'))),
                    if (list.loading) const LinearProgressIndicator(),
                    if (list.failed)
                      Text(b2(
                          context,
                          'Projekte konnten nicht geladen werden. Angezeigte Daten können veraltet sein.',
                          'Could not load projects. Displayed data may be out of date.')),
                    if (list.loaded &&
                        list.items.isEmpty &&
                        !list.loading &&
                        !list.failed)
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(b2(
                              context,
                              'Noch keine Projekte. Lege dein erstes an.',
                              'No projects yet. Create your first.'))),
                    for (final project in list.items)
                      Card(
                          child: ListTile(
                              key: ValueKey('project-${project.id}'),
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(project.name),
                              subtitle: project.description.isEmpty
                                  ? null
                                  : Text(project.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                              onTap: () => open(project))),
                    if (list.hasMore || list.failed)
                      TextButton(
                          onPressed: list.loading
                              ? null
                              : () => list.failed ? list.retry() : list.more(),
                          child: Text(list.failed
                              ? b2(context, 'Erneut versuchen', 'Retry')
                              : b2(context, 'Weitere laden', 'Load more'))),
                    if (list.loaded && !list.hasMore && list.items.isNotEmpty)
                      Text(b2(context, 'Alle Projekte geladen.',
                          'All projects loaded.')),
                  ],
                )),
          ));
}
