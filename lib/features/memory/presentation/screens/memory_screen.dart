// ==============================================
// Emie • Memory Screen
// Theme-aware + Language-aware
// Pfad: lib/features/memory/presentation/screens/memory_screen.dart
// ==============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/memory/api/memory_api.dart';
import '../../../../data/memory/models/memory_item.dart';
import '../../../../shared/widgets/emie_app_bar.dart';
import '../../../../state/session_store.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() =>
      _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<MemoryItem> memories = [];

  bool isLoading = true;

  String selectedFilter = 'all';

  String? loadErrorMessage;

  late final MemoryApi api;

  @override
  void initState() {
    super.initState();

    api = MemoryApi();

    loadMemories();
  }

  // ==============================================
  // FILTERED MEMORIES
  // ==============================================

  List<MemoryItem> get filteredMemories {
    final list = [...memories];

    if (selectedFilter != 'all') {
      list.removeWhere(
        (memory) =>
            memory.category != selectedFilter,
      );
    }

    list.sort(
      (a, b) =>
          b.importance.compareTo(a.importance),
    );

    return list;
  }

  // ==============================================
  // LOAD MEMORIES
  // ==============================================

  Future<void> loadMemories() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        loadErrorMessage = null;
      });
    }

    try {
      final data =
          await api.fetchMemories();

      if (!mounted) return;

      setState(() {
        memories = data;
        isLoading = false;
        loadErrorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      final t = _MemoryText(
        context.read<SessionStore>().language,
      );

      setState(() {
        isLoading = false;
        loadErrorMessage = t.loadError;
      });
    }
  }

  // ==============================================
  // DELETE MEMORY
  // ==============================================

  Future<void> deleteMemory(
    String id,
  ) async {
    final backup = [...memories];

    setState(() {
      memories.removeWhere(
        (memory) => memory.id == id,
      );
    });

    try {
      await api.deleteMemory(id);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        memories = backup;
      });

      final t = _MemoryText(
        context.read<SessionStore>().language,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.deleteError,
          ),
        ),
      );
    }
  }

  // ==============================================
  // EDIT MEMORY
  // ==============================================

  Future<void> openEditDialog(
    MemoryItem item,
  ) async {
    final session =
        context.read<SessionStore>();

    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final c =
        _MemoryColors(
      isDark: isDark,
    );

    final t =
        _MemoryText(
      session.language,
    );

    final controller =
        TextEditingController(
      text: item.content,
    );

    final result =
        await showDialog<String>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(24),
            side: BorderSide(
              color: c.border,
              width: 0.7,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              16,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  t.editTitle,
                  style: TextStyle(
                    color: c.goldText,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                TextField(
                  controller: controller,
                  maxLines: 4,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14.5,
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    hintText:
                        t.memoryHint,
                    hintStyle:
                        TextStyle(
                      color:
                          c.muted.withOpacity(
                        0.8,
                      ),
                      fontFamily:
                          'Inter',
                    ),
                    filled: true,
                    fillColor:
                        c.inputFill,
                    border:
                        _inputBorder(c),
                    enabledBorder:
                        _inputBorder(c),
                    focusedBorder:
                        _inputBorder(
                      c,
                      focused: true,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      child: Text(
                        t.cancel,
                        style: TextStyle(
                          color:
                              c.muted.withOpacity(
                            0.95,
                          ),
                          fontFamily:
                              'Inter',
                        ),
                      ),
                    ),

                    const Spacer(),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          controller.text.trim(),
                        );
                      },
                      child: Text(
                        t.save,
                        style: TextStyle(
                          color:
                              c.amber.withOpacity(
                            0.9,
                          ),
                          fontWeight:
                              FontWeight.w500,
                          fontFamily:
                              'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (result == null ||
        result.trim().isEmpty) {
      return;
    }

    try {
      final updated =
          await api.updateMemory(
        id: item.id,
        content: result.trim(),
      );

      if (!mounted) return;

      setState(() {
        final index =
            memories.indexWhere(
          (memory) =>
              memory.id == item.id,
        );

        if (index != -1) {
          memories[index] = updated;
        }
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.editError,
          ),
        ),
      );
    }
  }

  // ==============================================
  // INPUT BORDER
  // ==============================================

  OutlineInputBorder _inputBorder(
    _MemoryColors c, {
    bool focused = false,
  }) {
    return OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(18),
      borderSide: BorderSide(
        color: focused
            ? c.goldText.withOpacity(0.38)
            : c.goldText.withOpacity(0.16),
        width:
            focused ? 0.8 : 0.7,
      ),
    );
  }

  // ==============================================
  // BUILD
  // ==============================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final session =
        context.watch<SessionStore>();

    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final c =
        _MemoryColors(
      isDark: isDark,
    );

    final t =
        _MemoryText(
      session.language,
    );

    final visibleMemories =
        filteredMemories;

    return Scaffold(
      backgroundColor: c.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: c.gradient,
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            _MemoryBackground(
              colors: c,
            ),

            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  0,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==================================
                    // APP BAR
                    // ==================================
                    //
                    // Vorher:
                    // Suchsymbol ohne Funktion.
                    //
                    // Jetzt:
                    // echter Refresh der API-Daten.

                    EmieAppBar(
                      section: t.section,
                      icon:
                          Icons.refresh_rounded,
                      onIconTap: () {
                        if (!isLoading) {
                          loadMemories();
                        }
                      },
                    ),

                    const SizedBox(
                      height: 34,
                    ),

                    // ==================================
                    // TITLE
                    // ==================================

                    Text(
                      t.title,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 34,
                        height: 1.1,
                        fontWeight:
                            FontWeight.w400,
                        letterSpacing: -0.4,
                        fontFamily: 'Inter',
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      t.subtitle,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 14.5,
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    // ==================================
                    // FILTER
                    // ==================================

                    _FilterRow(
                      selectedFilter:
                          selectedFilter,
                      colors: c,
                      text: t,
                      onSelected: (value) {
                        setState(() {
                          selectedFilter =
                              value;
                        });
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==================================
                    // CONTENT
                    // ==================================

                    Expanded(
                      child: _buildContent(
                        colors: c,
                        text: t,
                        visibleMemories:
                            visibleMemories,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // CONTENT STATE
  // ==============================================

  Widget _buildContent({
    required _MemoryColors colors,
    required _MemoryText text,
    required List<MemoryItem> visibleMemories,
  }) {
    // --------------------------------------------
    // LOADING
    // --------------------------------------------

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color:
              colors.goldText.withOpacity(
            0.85,
          ),
          strokeWidth: 2,
        ),
      );
    }

    // --------------------------------------------
    // API ERROR
    // --------------------------------------------
    //
    // Ein Ladefehler darf niemals wie
    // "0 Erinnerungen" aussehen.

    if (loadErrorMessage != null) {
      return _MemoryErrorState(
        colors: colors,
        text: text,
        message: loadErrorMessage!,
        onRetry: () {
          loadMemories();
        },
      );
    }

    // --------------------------------------------
    // REAL EMPTY STATE
    // --------------------------------------------

    if (memories.isEmpty) {
      return _EmptyState(
        colors: colors,
        message: text.empty,
      );
    }

    // --------------------------------------------
    // FILTER EMPTY STATE
    // --------------------------------------------

    if (visibleMemories.isEmpty) {
      return _EmptyState(
        colors: colors,
        message: text.filterEmpty,
      );
    }

    // --------------------------------------------
    // REAL API DATA
    // --------------------------------------------

    return ListView.builder(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.only(
        bottom: 120,
      ),
      itemCount:
          visibleMemories.length,
      itemBuilder: (
        context,
        index,
      ) {
        final memory =
            visibleMemories[index];

        return _MemoryCard(
          memory: memory,
          colors: colors,
          text: text,
          onTap: () =>
              openEditDialog(
            memory,
          ),
          onDelete: () =>
              deleteMemory(
            memory.id,
          ),
        );
      },
    );
  }
}

// ==============================================
// COLORS
// ==============================================

class _MemoryColors {
  const _MemoryColors({
    required this.isDark,
  });

  final bool isDark;

  Color get bg => isDark
      ? const Color(0xFF050307)
      : const Color(0xFFF4F1EA);

  Color get bg2 => isDark
      ? const Color(0xFF0A0712)
      : const Color(0xFFFFFBF3);

  Color get card => isDark
      ? const Color(0xFF141312)
      : const Color(0xFFFCF8F1);

  Color get text => isDark
      ? Colors.white
      : const Color(0xFF17130C);

  Color get muted => isDark
      ? const Color(0xFF8E8B85)
      : const Color(0xFF736B5F);

  Color get gold => isDark
      ? const Color(0xFFBF953F)
      : const Color(0xFFB88922);

  Color get goldText => isDark
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get amber => isDark
      ? const Color(0xFFFFC96B)
      : const Color(0xFFB88922);

  Color get border =>
      goldText.withOpacity(
        isDark ? 0.12 : 0.22,
      );

  Color get inputFill => isDark
      ? Colors.black.withOpacity(0.25)
      : const Color(0xFFF4F1EA);

  List<Color> get gradient => [
        bg,
        bg2,
        bg,
      ];
}

// ==============================================
// TEXT
// ==============================================

class _MemoryText {
  _MemoryText(
    String code,
  ) : isDe = code == 'de';

  final bool isDe;

  String get section =>
      isDe
          ? 'erinnerung'
          : 'memory';

  String get title =>
      isDe
          ? 'Erinnerung'
          : 'Memory';

  String get subtitle => isDe
      ? 'Alles, was wichtig bleibt.'
      : 'Everything that matters stays.';

  String get all =>
      isDe
          ? 'Alle'
          : 'All';

  String get facts =>
      isDe
          ? 'Fakten'
          : 'Facts';

  String get emotions =>
      isDe
          ? 'Emotionen'
          : 'Emotions';

  String get projects =>
      isDe
          ? 'Projekte'
          : 'Projects';

  String get empty => isDe
      ? 'Noch keine Erinnerungen vorhanden.'
      : 'No memories yet.';

  String get filterEmpty => isDe
      ? 'Keine Erinnerungen in diesem Bereich.'
      : 'No memories in this category.';

  String get editTitle => isDe
      ? 'Erinnerung bearbeiten'
      : 'Edit memory';

  String get memoryHint =>
      isDe
          ? 'Erinnerung'
          : 'Memory';

  String get cancel =>
      isDe
          ? 'Abbrechen'
          : 'Cancel';

  String get save =>
      isDe
          ? 'Speichern'
          : 'Save';

  String get loadError => isDe
      ? 'Erinnerungen konnten nicht geladen werden.'
      : 'Could not load memories.';

  String get retry =>
      isDe
          ? 'Erneut versuchen'
          : 'Try again';

  String get deleteError => isDe
      ? 'Erinnerung konnte nicht gelöscht werden.'
      : 'Could not delete memory.';

  String get editError => isDe
      ? 'Erinnerung konnte nicht bearbeitet werden.'
      : 'Could not edit memory.';

  String get importance =>
      isDe
          ? 'Wichtigkeit'
          : 'Importance';

  String categoryLabel(
    String category,
  ) {
    switch (category) {
      case 'fact':
        return isDe
            ? 'FAKT'
            : 'FACT';

      case 'emotion':
        return 'EMOTION';

      case 'project':
        return isDe
            ? 'PROJEKT'
            : 'PROJECT';

      default:
        return isDe
            ? 'ERINNERUNG'
            : 'MEMORY';
    }
  }
}

// ==============================================
// FILTER ROW
// ==============================================

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedFilter,
    required this.onSelected,
    required this.colors,
    required this.text,
  });

  final String selectedFilter;
  final ValueChanged<String> onSelected;
  final _MemoryColors colors;
  final _MemoryText text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      physics:
          const BouncingScrollPhysics(),
      child: Row(
        children: [
          _FilterPill(
            label: text.all,
            selected:
                selectedFilter == 'all',
            colors: colors,
            onTap: () =>
                onSelected('all'),
          ),
          _FilterPill(
            label: text.facts,
            selected:
                selectedFilter == 'fact',
            colors: colors,
            onTap: () =>
                onSelected('fact'),
          ),
          _FilterPill(
            label: text.emotions,
            selected:
                selectedFilter ==
                    'emotion',
            colors: colors,
            onTap: () =>
                onSelected('emotion'),
          ),
          _FilterPill(
            label: text.projects,
            selected:
                selectedFilter ==
                    'project',
            colors: colors,
            onTap: () =>
                onSelected('project'),
          ),
        ],
      ),
    );
  }
}

// ==============================================
// EMPTY STATE
// ==============================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colors,
    required this.message,
  });

  final _MemoryColors colors;
  final String message;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Text(
        message,
        textAlign:
            TextAlign.center,
        style: TextStyle(
          color: colors.muted,
          fontSize: 14.5,
          height: 1.4,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ==============================================
// ERROR STATE
// ==============================================

class _MemoryErrorState
    extends StatelessWidget {
  const _MemoryErrorState({
    required this.colors,
    required this.text,
    required this.message,
    required this.onRetry,
  });

  final _MemoryColors colors;
  final _MemoryText text;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color:
                  colors.goldText.withOpacity(
                0.68,
              ),
              size: 30,
            ),

            const SizedBox(
              height: 14,
            ),

            Text(
              message,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 14.5,
                height: 1.4,
                fontFamily: 'Inter',
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            TextButton(
              onPressed:
                  onRetry,
              child: Text(
                text.retry,
                style: TextStyle(
                  color:
                      colors.goldText,
                  fontWeight:
                      FontWeight.w500,
                  fontFamily:
                      'Inter',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// FILTER PILL
// ==============================================

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final _MemoryColors colors;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        right: 9,
      ),
      child: GestureDetector(
        onTap:
            onTap,
        behavior:
            HitTestBehavior.opaque,
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 9,
          ),
          decoration:
              BoxDecoration(
            color: selected
                ? colors.gold.withOpacity(
                    colors.isDark
                        ? 0.13
                        : 0.10,
                  )
                : colors.card.withOpacity(
                    0.96,
                  ),
            borderRadius:
                BorderRadius.circular(
              999,
            ),
            border:
                Border.all(
              color: selected
                  ? colors.goldText
                      .withOpacity(
                      0.30,
                    )
                  : colors.goldText
                      .withOpacity(
                      0.12,
                    ),
              width: 0.7,
            ),
          ),
          child: Text(
            label,
            style:
                TextStyle(
              color: selected
                  ? colors.goldText
                  : colors.text.withOpacity(
                      0.62,
                    ),
              fontSize: 13,
              fontWeight: selected
                  ? FontWeight.w500
                  : FontWeight.w400,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================
// MEMORY CARD
// ==============================================

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.onTap,
    required this.onDelete,
    required this.colors,
    required this.text,
  });

  final MemoryItem memory;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final _MemoryColors colors;
  final _MemoryText text;

  @override
  Widget build(
    BuildContext context,
  ) {
    final isImportant =
        memory.importance >= 4;

    return Dismissible(
      key:
          Key(memory.id),
      direction:
          DismissDirection.endToStart,
      background:
          Container(
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        alignment:
            Alignment.centerRight,
        decoration:
            BoxDecoration(
          color:
              Colors.red.withOpacity(
            0.35,
          ),
          borderRadius:
              BorderRadius.circular(
            22,
          ),
        ),
        child:
            const Icon(
          Icons.delete_outline_rounded,
          color:
              Colors.white,
        ),
      ),
      onDismissed:
          (_) => onDelete(),
      child:
          GestureDetector(
        onTap:
            onTap,
        child:
            Container(
          width:
              double.infinity,
          margin:
              const EdgeInsets.only(
            bottom: 14,
          ),
          padding:
              const EdgeInsets.all(
            0.7,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            gradient:
                LinearGradient(
              colors: [
                colors.gold.withOpacity(
                  isImportant
                      ? 0.34
                      : 0.20,
                ),
                colors.goldText
                    .withOpacity(
                  isImportant
                      ? 0.42
                      : 0.24,
                ),
                colors.gold.withOpacity(
                  0.12,
                ),
              ],
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
            ),
          ),
          child:
              Container(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18,
            ),
            decoration:
                BoxDecoration(
              color:
                  colors.card,
              borderRadius:
                  BorderRadius.circular(
                21,
              ),
              boxShadow: [
                if (isImportant)
                  BoxShadow(
                    color:
                        colors.amber
                            .withOpacity(
                      0.08,
                    ),
                    blurRadius:
                        24,
                    spreadRadius:
                        -8,
                    offset:
                        const Offset(
                      0,
                      8,
                    ),
                  ),
              ],
            ),
            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  _iconForCategory(
                    memory.category,
                  ),
                  color:
                      colors.goldText
                          .withOpacity(
                    0.76,
                  ),
                  size:
                      22,
                ),

                const SizedBox(
                  width: 16,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.categoryLabel(
                          memory.category,
                        ),
                        style:
                            TextStyle(
                          color:
                              colors.goldText
                                  .withOpacity(
                            0.62,
                          ),
                          fontSize:
                              11.5,
                          letterSpacing:
                              1.15,
                          fontWeight:
                              FontWeight.w600,
                          fontFamily:
                              'Inter',
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Text(
                        memory.content,
                        style:
                            TextStyle(
                          color:
                              colors.text,
                          fontSize:
                              15,
                          height:
                              1.45,
                          fontWeight:
                              FontWeight.w400,
                          fontFamily:
                              'Inter',
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      Row(
                        children: [
                          Text(
                            '${text.importance} '
                            '${memory.importance}',
                            style:
                                TextStyle(
                              color:
                                  colors.muted
                                      .withOpacity(
                                0.88,
                              ),
                              fontSize:
                                  12.5,
                              fontFamily:
                                  'Inter',
                            ),
                          ),

                          const Spacer(),

                          Icon(
                            isImportant
                                ? Icons.star_rounded
                                : Icons.edit_outlined,
                            color: isImportant
                                ? colors.amber
                                    .withOpacity(
                                    0.82,
                                  )
                                : colors.muted
                                    .withOpacity(
                                    0.82,
                                  ),
                            size:
                                18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(
    String category,
  ) {
    switch (category) {
      case 'fact':
        return Icons
            .psychology_alt_outlined;

      case 'emotion':
        return Icons
            .favorite_border_rounded;

      case 'project':
        return Icons.folder_outlined;

      default:
        return Icons.memory_rounded;
    }
  }
}

// ==============================================
// BACKGROUND
// ==============================================

class _MemoryBackground
    extends StatelessWidget {
  const _MemoryBackground({
    required this.colors,
  });

  final _MemoryColors colors;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -130,
          child: Container(
            width: 330,
            height: 330,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              gradient:
                  RadialGradient(
                colors: [
                  colors.amber
                      .withOpacity(
                    colors.isDark
                        ? 0.10
                        : 0.14,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}