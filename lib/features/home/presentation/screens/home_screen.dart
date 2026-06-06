// ==============================================
// Emie • Home Screen
// Theme-aware + Language-aware
// Pfad: lib/features/home/presentation/screens/home_screen.dart
// ==============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/emie_app_bar.dart';
import '../../../../state/session_store.dart';
import '../../../plus/presentation/screens/emie_plus_screen.dart';

// ==============================================
// HOME SCREEN
// ==============================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getGreeting(_HomeText t) {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 11) {
      return t.morning;
    }

    if (hour >= 11 && hour < 17) {
      return t.midday;
    }

    if (hour >= 17 && hour < 23) {
      return t.evening;
    }

    return t.night;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final c = _HomeColors(isDark: isDark);
    final t = _HomeText(session.language);

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
            _LuxuryBackground(colors: c),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: SingleChildScrollView(
                    physics:
                        const BouncingScrollPhysics(),
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
                        EmieAppBar(
                          section: t.section,
                          icon: Icons.workspace_premium_rounded,
                          badgeText: 'Plus',
                          onIconTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                              builder: (_) => const EmiePlusScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        _GreetingBlock(
                          title: _getGreeting(t),
                          subtitle: t.overviewToday,
                          colors: c,
                        ),

                        const SizedBox(height: 34),

                        Text(
                          t.yourOverview,
                          style: TextStyle(
                            color: c.goldText
                                .withOpacity(0.78),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                            fontFamily: 'Inter',
                          ),
                        ),

                        const SizedBox(height: 14),

                        _GradientBorderCard(
                          colors: c,
                          large: true,
                          icon: Icons.wb_sunny_outlined,
                          title: t.dailyWelcomeTitle,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.dailyWelcomeText,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 16,
                                  height: 1.52,
                                  fontWeight:
                                      FontWeight.w400,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 18),
                              _GoldActionText(
                                text: t.startNow,
                                colors: c,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        _GradientBorderCard(
                          colors: c,
                          icon: Icons.business_center_outlined,
                          title: t.topProjectTitle,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.projectName,
                                style: TextStyle(
                                  color: c.goldText,
                                  fontSize: 22,
                                  letterSpacing: 1.2,
                                  fontWeight:
                                      FontWeight.w500,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.projectSubtitle,
                                style: TextStyle(
                                  color: c.subText,
                                  fontSize: 14.2,
                                  height: 1.35,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 15),
                              _ProgressBar(
                                value: 0.67,
                                colors: c,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                t.projectProgress,
                                style: TextStyle(
                                  color: c.muted,
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _GoldActionText(
                                text: t.openProject,
                                colors: c,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        _GradientBorderCard(
                          colors: c,
                          icon: Icons.favorite_border_rounded,
                          title: t.healthTitle,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.sleepTitle,
                                style: TextStyle(
                                  color: c.goldText,
                                  fontSize: 20,
                                  letterSpacing: 1,
                                  fontWeight:
                                      FontWeight.w500,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                t.sleepSubtitle,
                                style: TextStyle(
                                  color: c.subText,
                                  fontSize: 14,
                                  height: 1.45,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 14),
                              _GoldActionText(
                                text: t.openHealth,
                                colors: c,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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

class _HomeColors {
  const _HomeColors({required this.isDark});

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

  Color get subText => isDark
      ? Colors.white.withOpacity(0.64)
      : const Color(0xFF51493D);

  Color get muted => isDark
      ? const Color(0xFF8E8B85)
      : const Color(0xFF736B5F);

  Color get gold => isDark
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get goldSoft => isDark
      ? const Color(0xFFBF953F)
      : const Color(0xFFB88922);

  Color get goldText => isDark
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get amber => isDark
      ? const Color(0xFFFFC96B)
      : const Color(0xFFB88922);

  List<Color> get gradient => [bg, bg2, bg];
}

// ==============================================
// TEXT
// ==============================================

class _HomeText {
  _HomeText(String code) : isDe = code == 'de';

  final bool isDe;

  String get section => isDe ? 'übersicht' : 'overview';

  String get morning =>
      isDe ? 'Guten Morgen, Patze.' : 'Good morning, Patze.';
  String get midday =>
      isDe ? 'Schönen Mittag, Patze.' : 'Good afternoon, Patze.';
  String get evening =>
      isDe ? 'Guten Abend, Patze.' : 'Good evening, Patze.';
  String get night =>
      isDe ? 'Noch wach, Patze?' : 'Still awake, Patze?';

  String get overviewToday => isDe
      ? 'Dein Überblick für heute.'
      : 'Your overview for today.';

  String get yourOverview =>
      isDe ? 'DEIN ÜBERBLICK' : 'YOUR OVERVIEW';

  String get dailyWelcomeTitle =>
      isDe ? '1. DAILY WELCOME' : '1. DAILY WELCOME';

  String get dailyWelcomeText => isDe
      ? 'Gestern war intensiv. Heute lieber mit einem klaren ersten Schritt beginnen statt alles gleichzeitig anzugehen.'
      : 'Yesterday was intense. Today, start with one clear first step instead of trying to handle everything at once.';

  String get startNow =>
      isDe ? 'Jetzt starten' : 'Start now';

  String get topProjectTitle =>
      isDe ? '2. TOP-PROJEKT' : '2. TOP PROJECT';

  String get projectName =>
      isDe ? 'JAPAN-REISE' : 'JAPAN TRIP';

  String get projectSubtitle =>
      isDe ? 'In 87 Tagen geht es los.' : 'Starts in 87 days.';

  String get projectProgress =>
      isDe ? '67% geplant' : '67% planned';

  String get openProject =>
      isDe ? 'Projekt öffnen' : 'Open project';

  String get healthTitle =>
      isDe ? '3. HEALTH' : '3. HEALTH';

  String get sleepTitle =>
      isDe ? '7H 12MIN SCHLAF' : '7H 12MIN SLEEP';

  String get sleepSubtitle => isDe
      ? 'Ruhige Nacht. Deine Regeneration wirkt stabil.'
      : 'Calm night. Your recovery looks stable.';

  String get openHealth =>
      isDe ? 'Health öffnen' : 'Open health';
}

// ==============================================
// GREETING BLOCK
// ==============================================

class _GreetingBlock extends StatelessWidget {
  const _GreetingBlock({
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final _HomeColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.muted,
            fontSize: 14.5,
            height: 1.4,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ==============================================
// BACKGROUND
// ==============================================

class _LuxuryBackground extends StatelessWidget {
  const _LuxuryBackground({
    required this.colors,
  });

  final _HomeColors colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -120,
          child: Container(
            width: 330,
            height: 330,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.amber.withOpacity(
                    colors.isDark ? 0.12 : 0.16,
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

// ==============================================
// CARD
// ==============================================

class _GradientBorderCard extends StatelessWidget {
  const _GradientBorderCard({
    required this.icon,
    required this.title,
    required this.child,
    required this.colors,
    this.large = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final _HomeColors colors;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: large ? 190 : 150,
      ),
      padding: const EdgeInsets.all(0.7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colors.goldSoft.withOpacity(
              colors.isDark ? 0.34 : 0.26,
            ),
            colors.gold.withOpacity(
              colors.isDark ? 0.42 : 0.30,
            ),
            colors.goldSoft.withOpacity(
              colors.isDark ? 0.18 : 0.14,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.amber.withOpacity(
              colors.isDark ? 0.08 : 0.10,
            ),
            blurRadius: 26,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          large ? 20 : 18,
          18,
          large ? 20 : 18,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          color: colors.card,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: colors.goldText.withOpacity(0.82),
              size: large ? 24 : 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                          colors.goldText.withOpacity(0.78),
                      fontSize: 12,
                      letterSpacing: 1.15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: large ? 16 : 14),
                  child,
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
// GOLD ACTION TEXT
// ==============================================

class _GoldActionText extends StatelessWidget {
  const _GoldActionText({
    required this.text,
    required this.colors,
  });

  final String text;
  final _HomeColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$text  →',
      style: TextStyle(
        color: colors.amber.withOpacity(0.88),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        fontFamily: 'Inter',
      ),
    );
  }
}

// ==============================================
// PROGRESS BAR
// ==============================================

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.colors,
  });

  final double value;
  final _HomeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.text.withOpacity(
          colors.isDark ? 0.06 : 0.10,
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(999),
              color: colors.goldText.withOpacity(0.76),
            ),
          ),
        ),
      ),
    );
  }
}