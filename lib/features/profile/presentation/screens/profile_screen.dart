// ==============================================
// Emie • Profile Screen
// Theme-aware + Language-aware
// Pfad: lib/features/profile/presentation/screens/profile_screen.dart
// ==============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/emie_app_bar.dart';
import '../../../../state/session_store.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

// ==============================================
// PROFILE SCREEN
// ==============================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session =
        context.watch<SessionStore>();

    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final c = _ProfileColors(
      isDark: isDark,
    );

    final t = _ProfileText(
      session.language,
    );

    final displayName =
        session.displayName;

    final displayInitial =
        session.displayInitial;

    final email =
        session.user?.email.trim() ?? '';

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
            _ProfileBackground(
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

                    EmieAppBar(
                      section: t.section,
                      icon:
                          Icons.settings_rounded,
                      onIconTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const SettingsScreen(),
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
                    // CONTENT
                    // ==================================

                    Expanded(
                      child: ListView(
                        physics:
                            const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        children: [
                          _AccountCard(
                            colors: c,
                            title: t.account,
                            name: displayName,
                            initial: displayInitial,
                            email: email,
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
// ACCOUNT CARD
// ==============================================

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.colors,
    required this.title,
    required this.name,
    required this.initial,
    required this.email,
  });

  final _ProfileColors colors;
  final String title;
  final String name;
  final String initial;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(0.7),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colors.goldSoft.withOpacity(
              colors.isDark
                  ? 0.22
                  : 0.18,
            ),
            colors.gold.withOpacity(
              colors.isDark
                  ? 0.30
                  : 0.22,
            ),
            colors.goldSoft.withOpacity(
              colors.isDark
                  ? 0.12
                  : 0.08,
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
          18,
          18,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              BorderRadius.circular(21),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            // ==================================
            // INITIAL
            // ==================================

            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    colors.gold.withOpacity(
                  0.08,
                ),
                border: Border.all(
                  color:
                      colors.gold.withOpacity(
                    0.18,
                  ),
                  width: 0.7,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: colors.gold,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 15,
            ),

            // ==================================
            // REAL USER DATA
            // ==================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                          colors.gold.withOpacity(
                        0.68,
                      ),
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                      letterSpacing: 1.2,
                      fontFamily: 'Inter',
                    ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Text(
                    name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),

                  if (email.isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      email,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ],
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

class _ProfileColors {
  const _ProfileColors({
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

  List<Color> get gradient => [
        bg,
        bg2,
        bg,
      ];
}

// ==============================================
// TEXT
// ==============================================

class _ProfileText {
  _ProfileText(
    String code,
  ) : isDe = code == 'de';

  final bool isDe;

  String get section =>
      isDe
          ? 'profil'
          : 'profile';

  String get title =>
      isDe
          ? 'Profil'
          : 'Profile';

  String get subtitle => isDe
      ? 'Dein Konto und deine Einstellungen.'
      : 'Your account and settings.';

  String get account =>
      isDe
          ? 'KONTO'
          : 'ACCOUNT';
}

// ==============================================
// BACKGROUND
// ==============================================

class _ProfileBackground
    extends StatelessWidget {
  const _ProfileBackground({
    required this.colors,
  });

  final _ProfileColors colors;

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