// ==============================================
// Emie • Project Screen
// Theme-aware + Language-aware
// Pfad: lib/features/projects/presentation/screens/project_screen.dart
// ==============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/emie_app_bar.dart';
import '../../../../state/session_store.dart';

// ==============================================
// PROJECT SCREEN
// ==============================================

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session =
        context.watch<SessionStore>();

    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final c =
        _ProjectColors(
      isDark: isDark,
    );

    final t =
        _ProjectText(
      session.language,
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: c.gradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            _ProjectBackground(
              colors: c,
            ),

            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  120,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==================================
                    // APP BAR
                    // ==================================
                    //
                    // Projekt-Erstellung ist aktuell
                    // noch nicht mit einer echten
                    // Project-API verbunden.
                    //
                    // Der Button bleibt sichtbar,
                    // reagiert aber ehrlich statt
                    // eine tote Action zu sein.

                    EmieAppBar(
                      section: t.section,
                      icon: Icons.add_rounded,
                      onIconTap: () {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              t.createUnavailable,
                            ),
                          ),
                        );
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
                      height: 30,
                    ),

                    // ==================================
                    // PROJECT CONTENT
                    // ==================================
                    //
                    // Keine echte Project-Datenquelle
                    // ist derzeit an diesen Screen
                    // angebunden.
                    //
                    // Deshalb bewusst keine Demo- oder
                    // Placeholder-Projekte darstellen.

                    Expanded(
                      child: _ProjectEmptyState(
                        colors: c,
                        text: t,
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
}

// ==============================================
// EMPTY STATE
// ==============================================

class _ProjectEmptyState
    extends StatelessWidget {
  const _ProjectEmptyState({
    required this.colors,
    required this.text,
  });

  final _ProjectColors colors;
  final _ProjectText text;

  @override
  Widget build(BuildContext context) {
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
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.gold.withOpacity(
                  colors.isDark
                      ? 0.08
                      : 0.07,
                ),
                border: Border.all(
                  color:
                      colors.gold.withOpacity(
                    colors.isDark
                        ? 0.16
                        : 0.18,
                  ),
                  width: 0.7,
                ),
              ),
              child: Icon(
                Icons.folder_open_outlined,
                color:
                    colors.gold.withOpacity(
                  0.76,
                ),
                size: 25,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              text.emptyTitle,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight:
                    FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              text.emptySubtitle,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: colors.muted,
                fontSize: 14,
                height: 1.45,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// COLORS
// ==============================================

class _ProjectColors {
  const _ProjectColors({
    required this.isDark,
  });

  final bool isDark;

  Color get bg => isDark
      ? const Color(0xFF050307)
      : const Color(0xFFF4F1EA);

  Color get bg2 => isDark
      ? const Color(0xFF0A0712)
      : const Color(0xFFFFFBF3);

  Color get text => isDark
      ? Colors.white
      : const Color(0xFF17130C);

  Color get muted => isDark
      ? const Color(0xFF8E8B85)
      : const Color(0xFF736B5F);

  Color get gold => isDark
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get amber => isDark
      ? const Color(0xFFFFC96B)
      : const Color(0xFFB88922);

  List<Color> get gradient => [
        bg,
        bg2,
        bg,
      ];
}

// ==============================================
// TEXT
// ==============================================

class _ProjectText {
  _ProjectText(
    String code,
  ) : isDe = code == 'de';

  final bool isDe;

  String get section =>
      isDe
          ? 'projekte'
          : 'projects';

  String get title =>
      isDe
          ? 'Projekte'
          : 'Projects';

  String get subtitle => isDe
      ? 'Plane Reisen, Arbeit und große Ziele an einem Ort.'
      : 'Plan trips, work and major goals in one place.';

  String get emptyTitle => isDe
      ? 'Noch keine Projekte verfügbar'
      : 'No projects available yet';

  String get emptySubtitle => isDe
      ? 'Sobald die Projektfunktion verbunden ist, erscheinen deine echten Projekte hier.'
      : 'Once the project feature is connected, your real projects will appear here.';

  String get createUnavailable => isDe
      ? 'Projekt erstellen ist in dieser Beta noch nicht verfügbar.'
      : 'Creating projects is not available in this beta yet.';
}

// ==============================================
// BACKGROUND
// ==============================================

class _ProjectBackground
    extends StatelessWidget {
  const _ProjectBackground({
    required this.colors,
  });

  final _ProjectColors colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -130,
          child: Container(
            width: 330,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.amber.withOpacity(
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