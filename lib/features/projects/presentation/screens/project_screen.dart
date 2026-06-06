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
    final session = context.watch<SessionStore>();

    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final c = _ProjectColors(isDark: isDark);
    final t = _ProjectText(session.language);

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
            _ProjectBackground(colors: c),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  120,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    EmieAppBar(
                      section: t.section,
                      icon: Icons.add_rounded,
                      onIconTap: () {},
                    ),

                    const SizedBox(height: 34),

                    Text(
                      t.title,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 34,
                        height: 1.1,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.4,
                        fontFamily: 'Inter',
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      t.subtitle,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 14.5,
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),

                    const SizedBox(height: 30),

                    Expanded(
                      child: ListView(
                        physics:
                            const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        children: [
                          _ProjectCard(
                            colors: c,
                            title: t.projectJapan,
                            subtitle:
                                t.projectJapanSub,
                            icon: Icons
                                .flight_takeoff_rounded,
                          ),

                          const SizedBox(height: 14),

                          _ProjectCard(
                            colors: c,
                            title: 'EMIE BETA UI',
                            subtitle:
                                t.projectEmieSub,
                            icon: Icons
                                .auto_awesome_rounded,
                          ),

                          const SizedBox(height: 14),

                          _ProjectCard(
                            colors: c,
                            title:
                                t.projectTaxes,
                            subtitle:
                                t.projectTaxesSub,
                            icon: Icons
                                .description_outlined,
                          ),
                        ],
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
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get goldSoft => isDark
      ? const Color(0xFFBF953F)
      : const Color(0xFFB88922);

  Color get amber => isDark
      ? const Color(0xFFFFC96B)
      : const Color(0xFFB88922);

  List<Color> get gradient => [bg, bg2, bg];
}

// ==============================================
// TEXT
// ==============================================

class _ProjectText {
  _ProjectText(String code)
      : isDe = code == 'de';

  final bool isDe;

  String get section =>
      isDe ? 'projekte' : 'projects';

  String get title =>
      isDe ? 'Projekte' : 'Projects';

  String get subtitle => isDe
      ? 'Plane Reisen, Arbeit und große Ziele an einem Ort.'
      : 'Plan trips, work and major goals in one place.';

  String get projectJapan =>
      isDe ? 'JAPAN-REISE' : 'JAPAN TRIP';

  String get projectJapanSub => isDe
      ? '67% geplant · In 87 Tagen'
      : '67% planned · In 87 days';

  String get projectEmieSub => isDe
      ? 'HomeScreen & Navigation finalisieren'
      : 'Finalize HomeScreen & navigation';

  String get projectTaxes =>
      isDe ? 'STEUERERKLÄRUNG' : 'TAX RETURN';

  String get projectTaxesSub => isDe
      ? 'Unterlagen sammeln und strukturieren'
      : 'Collect and organize documents';
}

// ==============================================
// PROJECT CARD
// ==============================================

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _ProjectColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0.7),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colors.goldSoft.withOpacity(
              colors.isDark ? 0.22 : 0.18,
            ),
            colors.gold.withOpacity(
              colors.isDark ? 0.30 : 0.22,
            ),
            colors.goldSoft.withOpacity(
              colors.isDark ? 0.12 : 0.08,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          18,
          18,
          16,
          18,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  colors.gold.withOpacity(0.82),
              size: 24,
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.gold,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w500,
                      letterSpacing: 0.8,
                      fontFamily: 'Inter',
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13.5,
                      height: 1.35,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color:
                  colors.gold.withOpacity(0.48),
            ),
          ],
        ),
      ),
    );
  }
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