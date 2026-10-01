import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/b2_text.dart';
import '../../../../data/memory/api/memory_api.dart';
import '../../../../data/memory/models/memory_item.dart';
import '../../../../state/paged_list.dart';
import '../../../../state/session_store.dart';
import 'memory_editor.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, this.api, this.isActive = true});
  final MemoryApi? api;
  final bool isActive;
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late final api = widget.api ?? MemoryApi();
  String category = 'all', search = '';
  final query = TextEditingController();
  late final PagedList<MemoryItem> list = PagedList(
      id: (m) => m.id,
      fetch: (offset, generation) => api.fetchPage(
          offset: offset,
          category: category,
          search: search,
          generation: generation));
  @override
  void initState() {
    super.initState();
    list.refresh();
  }

  @override
  void didUpdateWidget(covariant MemoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      list.refresh(through: list.items.length);
    }
  }

  @override
  void dispose() {
    list.dispose();
    query.dispose();
    super.dispose();
  }

  Future<void> open(MemoryItem item) async {
    final generation = context.read<SessionStore>().generation;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => MemoryEditor(item: item, api: api)));
    if (mounted && SessionStore.instance.isCurrent(generation)) {
      await list.refresh(through: list.items.length);
    }
  }

  void applySearch() {
    search = query.text;
    list.refresh(clear: true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: list,
      builder: (context, _) => Scaffold(
            appBar: AppBar(
                title: Text(b2(context, 'Erinnerungen', 'Memories')),
                actions: [
                  IconButton(
                      tooltip: b2(context, 'Aktualisieren', 'Refresh'),
                      onPressed: () => list.refresh(),
                      icon: const Icon(Icons.refresh)),
                ]),
            body: Column(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(children: [
                    TextField(
                        key: const ValueKey('memory-search'),
                        controller: query,
                        onSubmitted: (_) => applySearch(),
                        decoration: InputDecoration(
                            labelText: b2(
                                context,
                                'Gesamten Bestand durchsuchen',
                                'Search all memories'),
                            suffixIcon: IconButton(
                                tooltip: b2(context, 'Suchen', 'Search'),
                                onPressed: applySearch,
                                icon: const Icon(Icons.search)))),
                    DropdownButton<String>(
                        value: category,
                        isExpanded: true,
                        items: [
                          for (final entry in {
                            'all': b2(
                                context, 'Alle Kategorien', 'All categories'),
                            'facts': b2(context, 'Fakten', 'Facts'),
                            'profile': b2(context, 'Profil', 'Profile'),
                            'favorites': b2(context, 'Favoriten', 'Favorites'),
                            'habit': b2(context, 'Gewohnheiten', 'Habits'),
                            'custom': b2(context, 'Notizen', 'Notes'),
                          }.entries)
                            DropdownMenuItem(
                                value: entry.key, child: Text(entry.value)),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => category = value);
                          list.refresh(clear: true);
                        }),
                    Text(b2(
                        context,
                        'Sortiert nach Fixierung, Wichtigkeit und Datum.',
                        'Sorted by pinned status, importance and date.')),
                    if (list.loaded)
                      Text(b2(
                          context,
                          '${list.items.length} von ${list.total} geladen',
                          '${list.items.length} of ${list.total} loaded')),
                    if (list.loading) const LinearProgressIndicator(),
                  ])),
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: () => list.refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 130),
                        children: [
                          if (list.failed)
                            Text(b2(
                                context,
                                'Laden fehlgeschlagen. Angezeigte Daten können veraltet sein.',
                                'Loading failed. Displayed data may be out of date.')),
                          if (list.loaded &&
                              !list.loading &&
                              !list.failed &&
                              list.items.isEmpty)
                            Text(b2(
                                context,
                                'Keine passenden Erinnerungen vorhanden.',
                                'No matching memories.')),
                          for (final item in list.items)
                            Card(
                                child: ListTile(
                                    key: ValueKey('memory-${item.id}'),
                                    title: Text(item.content,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(b2(
                                        context,
                                        'Wichtigkeit: ${item.importance}',
                                        'Importance: ${item.importance}')),
                                    trailing: const Icon(Icons.edit_outlined),
                                    onTap: () => open(item))),
                          if (list.hasMore || list.failed)
                            TextButton(
                                onPressed: list.loading
                                    ? null
                                    : () => list.failed
                                        ? list.retry()
                                        : list.more(),
                                child: Text(list.failed
                                    ? b2(context, 'Erneut versuchen', 'Retry')
                                    : b2(context, 'Weitere laden',
                                        'Load more'))),
                          if (list.loaded &&
                              !list.hasMore &&
                              list.items.isNotEmpty)
                            Text(b2(context, 'Alle Treffer geladen.',
                                'All results loaded.')),
                        ],
                      ))),
            ]),
          ));
}
