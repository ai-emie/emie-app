// ==============================================
// Emie • Home Screen
// Theme-aware + Language-aware
// Pfad: lib/features/home/presentation/screens/home_screen.dart
// ==============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/widgets/emie_app_bar.dart';
import '../../../../state/session_store.dart';
import '../../../chat/controller/chat_controller.dart';
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

  Future<String>? _dailyWelcomeFuture;
  String? _dailyWelcomeLanguage;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 850,
      ),
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
  void didChangeDependencies() {
    super.didChangeDependencies();

    final session =
        context.read<SessionStore>();

    final language =
        session.language;

    // Daily Welcome nur einmal pro Sprache laden.
    //
    // Dadurch wird bei normalen Rebuilds nicht
    // ständig erneut der API-Endpunkt aufgerufen.
    if (_dailyWelcomeFuture == null ||
        _dailyWelcomeLanguage != language) {
      _dailyWelcomeLanguage = language;

      _dailyWelcomeFuture =
          context
              .read<ChatController>()
              .getDailyWelcome();
    }
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  String _getGreeting(
    _HomeText t,
    String displayName,
  ) {
    final hour =
        DateTime.now().hour;

    if (hour >= 5 && hour < 11) {
      return t.morning(
        displayName,
      );
    }

    if (hour >= 11 && hour < 17) {
      return t.midday(
        displayName,
      );
    }

    if (hour >= 17 && hour < 23) {
      return t.evening(
        displayName,
      );
    }

    return t.night(
      displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session =
        context.watch<SessionStore>();

    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final c =
        _HomeColors(
      isDark: isDark,
    );

    final t =
        _HomeText(
      session.language,
    );

    final displayName =
        session.displayName;

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
            _LuxuryBackground(
              colors: c,
            ),
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
                          icon:
                              Icons.workspace_premium_rounded,
                          badgeText: 'Plus',
                          onIconTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const EmiePlusScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(
                          height: 32,
                        ),

                        _GreetingBlock(
                          title: _getGreeting(
                            t,
                            displayName,
                          ),
                          subtitle:
                              t.overviewToday,
                          colors: c,
                        ),

                        const SizedBox(
                          height: 34,
                        ),

                        Text(
                          t.yourOverview,
                          style: TextStyle(
                            color: c.goldText
                                .withOpacity(0.78),
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w600,
                            letterSpacing: 1.8,
                            fontFamily: 'Inter',
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        // ==================================
                        // DAILY WELCOME
                        // ==================================

                        _GradientBorderCard(
                          colors: c,
                          large: true,
                          icon:
                              Icons.wb_sunny_outlined,
                          title:
                              t.dailyWelcomeTitle,
                          child:
                              _DailyWelcomeContent(
                            future:
                                _dailyWelcomeFuture,
                            colors: c,
                            text: t,
                          ),
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        // ==================================
                        // TOP PROJECT
                        // ==================================
                        //
                        // Aktuell ist im HomeScreen noch
                        // keine echte Project-Datenquelle
                        // angebunden.
                        //
                        // Deshalb bewusst Empty State statt
                        // erfundener Projekt-/Fortschrittsdaten.

                        _GradientBorderCard(
                          colors: c,
                          icon:
                              Icons.business_center_outlined,
                          title:
                              t.topProjectTitle,
                          child: _EmptyState(
                            icon:
                                Icons.folder_open_outlined,
                            title:
                                t.noProjectTitle,
                            subtitle:
                                t.noProjectSubtitle,
                            colors: c,
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
// DAILY WELCOME CONTENT
// ==============================================

class _DailyWelcomeContent
    extends StatelessWidget {
  const _DailyWelcomeContent({
    required this.future,
    required this.colors,
    required this.text,
  });

  final Future<String>? future;
  final _HomeColors colors;
  final _HomeText text;

  @override
  Widget build(BuildContext context) {
    final request = future;

    if (request == null) {
      return _DailyWelcomeLoading(
        colors: colors,
      );
    }

    return FutureBuilder<String>(
      future: request,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return _DailyWelcomeLoading(
            colors: colors,
          );
        }

        final value =
            snapshot.data?.trim() ?? '';

        if (value.isEmpty) {
          return _EmptyState(
            icon:
                Icons.wb_cloudy_outlined,
            title:
                text.dailyWelcomeEmptyTitle,
            subtitle:
                text.dailyWelcomeEmptySubtitle,
            colors: colors,
          );
        }

        return Text(
          value,
          style: TextStyle(
            color: colors.text,
            fontSize: 16,
            height: 1.52,
            fontWeight:
                FontWeight.w400,
            fontFamily: 'Inter',
          ),
        );
      },
    );
  }
}

// ==============================================
// DAILY WELCOME LOADING
// ==============================================

class _DailyWelcomeLoading
    extends StatelessWidget {
  const _DailyWelcomeLoading({
    required this.colors,
  });

  final _HomeColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: colors.goldText,
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        Expanded(
          child: Text(
            '…',
            style: TextStyle(
              color: colors.muted,
              fontSize: 15,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}

// ==============================================
// EMPTY STATE
// ==============================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _HomeColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.goldText
                .withOpacity(0.07),
          ),
          child: Icon(
            icon,
            size: 19,
            color: colors.goldText
                .withOpacity(0.72),
          ),
        ),
        const SizedBox(
          width: 13,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w500,
                  height: 1.3,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 13.5,
                  height: 1.4,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==============================================
// COLORS
// ==============================================

class _HomeColors {
  const _HomeColors({
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

  List<Color> get gradient => [
        bg,
        bg2,
        bg,
      ];
}

// ==============================================
// TEXT
// ==============================================

class _HomeText {
  _HomeText(
    String code,
  ) : isDe = code == 'de';

  final bool isDe;

  String get section =>
      isDe
          ? 'übersicht'
          : 'overview';

  String morning(
    String name,
  ) =>
      isDe
          ? 'Guten Morgen, $name.'
          : 'Good morning, $name.';

  String midday(
    String name,
  ) =>
      isDe
          ? 'Schönen Mittag, $name.'
          : 'Good afternoon, $name.';

  String evening(
    String name,
  ) =>
      isDe
          ? 'Guten Abend, $name.'
          : 'Good evening, $name.';

  String night(
    String name,
  ) =>
      isDe
          ? 'Noch wach, $name?'
          : 'Still awake, $name?';

  String get overviewToday =>
      isDe
          ? 'Dein Überblick für heute.'
          : 'Your overview for today.';

  String get yourOverview =>
      isDe
          ? 'DEIN ÜBERBLICK'
          : 'YOUR OVERVIEW';

  String get dailyWelcomeTitle =>
      '1. DAILY WELCOME';

  String get dailyWelcomeEmptyTitle =>
      isDe
          ? 'Noch kein Tagesimpuls verfügbar'
          : 'No daily insight available yet';

  String get dailyWelcomeEmptySubtitle =>
      isDe
          ? 'Sobald Emie einen Tagesimpuls geladen hat, erscheint er hier.'
          : 'Your daily insight will appear here once Emie has loaded it.';

  String get topProjectTitle =>
      isDe
          ? '2. TOP-PROJEKT'
          : '2. TOP PROJECT';

  String get noProjectTitle =>
      isDe
          ? 'Noch kein Projekt vorhanden'
          : 'No project yet';

  String get noProjectSubtitle =>
      isDe
          ? 'Dein wichtigstes Projekt erscheint hier, sobald Projektdaten verfügbar sind.'
          : 'Your most important project will appear here once project data is available.';
}

// ==============================================
// GREETING BLOCK
// ==============================================

class _GreetingBlock
    extends StatelessWidget {
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
            fontWeight:
                FontWeight.w400,
            letterSpacing: -0.2,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(
          height: 10,
        ),
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

class _LuxuryBackground
    extends StatelessWidget {
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
                    colors.isDark
                        ? 0.12
                        : 0.16,
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

class _GradientBorderCard
    extends StatelessWidget {
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
        minHeight:
            large
                ? 190
                : 150,
      ),
      padding:
          const EdgeInsets.all(0.7),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colors.goldSoft.withOpacity(
              colors.isDark
                  ? 0.34
                  : 0.26,
            ),
            colors.gold.withOpacity(
              colors.isDark
                  ? 0.42
                  : 0.30,
            ),
            colors.goldSoft.withOpacity(
              colors.isDark
                  ? 0.18
                  : 0.14,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                colors.amber.withOpacity(
              colors.isDark
                  ? 0.08
                  : 0.10,
            ),
            blurRadius: 26,
            spreadRadius: -8,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          large
              ? 20
              : 18,
          18,
          large
              ? 20
              : 18,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(21),
          color: colors.card,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color:
                  colors.goldText.withOpacity(
                0.82,
              ),
              size:
                  large
                      ? 24
                      : 22,
            ),
            const SizedBox(
              width: 16,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                          colors.goldText
                              .withOpacity(
                        0.78,
                      ),
                      fontSize: 12,
                      letterSpacing:
                          1.15,
                      fontWeight:
                          FontWeight.w600,
                      fontFamily:
                          'Inter',
                    ),
                  ),
                  SizedBox(
                    height:
                        large
                            ? 16
                            : 14,
                  ),
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