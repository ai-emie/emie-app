// ==============================================
// Emie • Modular Profile Screen
// Theme-aware + Language-aware + Dashboard Modules
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool showSleep = true;
  bool showGarmin = true;
  bool showHeartRate = true;
  bool showGlucose = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final c = _ProfileColors(isDark: isDark);
    final t = _ProfileText(session.language);

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
            _ProfileBackground(colors: c),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmieAppBar(
                      section: t.section,
                      icon: Icons.settings_rounded,
                      onIconTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
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
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 10),
                        children: [
                          if (showSleep) ...[
                            _HealthCard(
                              colors: c,
                              icon: Icons.bedtime_outlined,
                              title: t.sleep,
                              value: '7h 12min',
                              subtitle: t.sleepSubtitle,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (showGarmin) ...[
                            _HealthCard(
                              colors: c,
                              icon: Icons.watch_rounded,
                              title: t.garmin,
                              value: '8.420',
                              subtitle: t.garminSubtitle,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (showHeartRate) ...[
                            _HealthCard(
                              colors: c,
                              icon: Icons.favorite_border_rounded,
                              title: t.heart,
                              value: '68 bpm',
                              subtitle: t.heartSubtitle,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (showGlucose) ...[
                            _HealthCard(
                              colors: c,
                              icon: Icons.bloodtype_outlined,
                              title: t.glucose,
                              value: t.notConnected,
                              subtitle: t.glucoseSubtitle,
                            ),
                            const SizedBox(height: 14),
                          ],
                          const SizedBox(height: 8),
                          _CustomizeDashboardButton(
                            colors: c,
                            text: t.customizeDashboard,
                            onTap: () => _openCustomizeSheet(context, c, t),
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

  void _openCustomizeSheet(
    BuildContext context,
    _ProfileColors colors,
    _ProfileText text,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void update(VoidCallback change) {
              setModalState(change);
              setState(() {});
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
              decoration: BoxDecoration(
                color: colors.sheet,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(
                  color: colors.gold.withOpacity(0.18),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      colors.isDark ? 0.45 : 0.16,
                    ),
                    blurRadius: 34,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.gold.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      text.sheetTitle,
                      style: TextStyle(
                        color: colors.gold,
                        fontSize: 24,
                        height: 1.12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      text.sheetInfo,
                      style: TextStyle(
                        color: colors.sheetMuted,
                        fontSize: 13.4,
                        height: 1.45,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ModuleSwitch(
                      colors: colors,
                      title: text.sleepModule,
                      subtitle: text.sleepModuleSubtitle,
                      value: showSleep,
                      onChanged: (value) {
                        update(() => showSleep = value);
                      },
                    ),
                    _ModuleSwitch(
                      colors: colors,
                      title: text.garminModule,
                      subtitle: text.garminModuleSubtitle,
                      value: showGarmin,
                      onChanged: (value) {
                        update(() => showGarmin = value);
                      },
                    ),
                    _ModuleSwitch(
                      colors: colors,
                      title: text.heartModule,
                      subtitle: text.heartModuleSubtitle,
                      value: showHeartRate,
                      onChanged: (value) {
                        update(() => showHeartRate = value);
                      },
                    ),
                    _ModuleSwitch(
                      colors: colors,
                      title: text.glucoseModule,
                      subtitle: text.glucoseModuleSubtitle,
                      value: showGlucose,
                      onChanged: (value) {
                        update(() => showGlucose = value);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Color get bg =>
      isDark ? const Color(0xFF050307) : const Color(0xFFF4F1EA);

  Color get bg2 =>
      isDark ? const Color(0xFF0A0712) : const Color(0xFFFFFBF3);

  Color get card =>
      isDark ? const Color(0xFF141312) : const Color(0xFFFCF8F1);

  Color get sheet =>
      isDark ? const Color(0xFF141312) : const Color(0xFFFCF8F1);

  Color get text => isDark ? Colors.white : const Color(0xFF17130C);

  Color get muted =>
      isDark ? const Color(0xFF8E8B85) : const Color(0xFF736B5F);

  Color get sheetMuted =>
      isDark ? const Color(0xFFB7B0A5) : const Color(0xFF736B5F);

  Color get gold =>
      isDark ? const Color(0xFFFCF6BA) : const Color(0xFF8A6117);

  Color get deepGold => const Color(0xFF8A6117);

  Color get goldSoft =>
      isDark ? const Color(0xFFBF953F) : const Color(0xFFB88922);

  Color get amber =>
      isDark ? const Color(0xFFFFC96B) : const Color(0xFFB88922);

  List<Color> get gradient => [bg, bg2, bg];
}

// ==============================================
// TEXT
// ==============================================

class _ProfileText {
  _ProfileText(String code) : isDe = code == 'de';

  final bool isDe;

  String get section => isDe ? 'profil' : 'profile';

  String get title => isDe ? 'Profil' : 'Profile';

  String get subtitle => isDe
      ? 'Dein Körper, deine Energie und deine Routinen. Du entscheidest, welche Module Emie begleiten dürfen.'
      : 'Your body, your energy and your routines. You decide which modules Emie may use.';

  String get sleep => isDe ? 'SCHLAF' : 'SLEEP';

  String get sleepSubtitle =>
      isDe ? 'Letzte Nacht · ruhig' : 'Last night · calm';

  String get garmin => isDe ? 'GARMIN' : 'GARMIN';

  String get garminSubtitle => isDe
      ? 'Heute · gutes Aktivitätsniveau'
      : 'Today · good activity level';

  String get heart => isDe ? 'HERZRHYTHMUS' : 'HEART RATE';

  String get heartSubtitle =>
      isDe ? 'Ruhepuls · stabil' : 'Resting pulse · stable';

  String get glucose => isDe ? 'BLUTZUCKER' : 'GLUCOSE';

  String get glucoseSubtitle => isDe
      ? 'Optionales Gesundheitsmodul · jederzeit deaktivierbar'
      : 'Optional health module · can be disabled anytime';

  String get notConnected => isDe ? 'Nicht verbunden' : 'Not connected';

  String get customizeDashboard =>
      isDe ? '+ Dashboard anpassen' : '+ Customize dashboard';

  String get sheetTitle =>
      isDe ? 'Dashboard anpassen' : 'Customize dashboard';

  String get sheetInfo => isDe
      ? 'Deine Daten, deine Kontrolle. Alle aktivierten Module spiegeln ihre Daten direkt in deine private Cloud. Du kannst sie jederzeit löschen.'
      : 'Your data, your control. All activated modules mirror their data directly into your private cloud. You can delete them at any time.';

  String get sleepModule => isDe ? 'Schlaf' : 'Sleep';

  String get sleepModuleSubtitle => isDe
      ? 'Schlafdauer, Qualität und Erholung'
      : 'Sleep duration, quality and recovery';

  String get garminModule => isDe ? 'Garmin' : 'Garmin';

  String get garminModuleSubtitle => isDe
      ? 'Schritte, Aktivität und Tagesbewegung'
      : 'Steps, activity and daily movement';

  String get heartModule => isDe ? 'Herzrhythmus' : 'Heart rate';

  String get heartModuleSubtitle => isDe
      ? 'Ruhepuls und Belastungsdaten'
      : 'Resting pulse and activity load';

  String get glucoseModule => isDe ? 'Blutzucker' : 'Glucose';

  String get glucoseModuleSubtitle => isDe
      ? 'Optionales Gesundheitsmodul'
      : 'Optional health module';
}

// ==============================================
// HEALTH CARD
// ==============================================

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final _ProfileColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0.7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colors.goldSoft.withOpacity(colors.isDark ? 0.22 : 0.18),
            colors.gold.withOpacity(colors.isDark ? 0.30 : 0.22),
            colors.goldSoft.withOpacity(colors.isDark ? 0.12 : 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: colors.gold.withOpacity(0.82),
              size: 25,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.gold.withOpacity(0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.3,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 5),
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
              color: colors.gold.withOpacity(0.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// CUSTOMIZE BUTTON
// ==============================================

class _CustomizeDashboardButton extends StatelessWidget {
  const _CustomizeDashboardButton({
    required this.colors,
    required this.text,
    required this.onTap,
  });

  final _ProfileColors colors;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.gold,
        side: BorderSide(
          color: colors.gold.withOpacity(0.34),
          width: 0.9,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ==============================================
// MODULE SWITCH
// ==============================================

class _ModuleSwitch extends StatelessWidget {
  const _ModuleSwitch({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final _ProfileColors colors;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: colors.deepGold,
      activeTrackColor: colors.deepGold.withOpacity(0.32),
      inactiveThumbColor: colors.isDark
          ? const Color(0xFF8E8B85)
          : const Color(0xFFB8AEA0),
      inactiveTrackColor: colors.isDark
          ? Colors.white.withOpacity(0.10)
          : Colors.black.withOpacity(0.08),
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: colors.gold,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: colors.sheetMuted,
          fontSize: 12.8,
          height: 1.35,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ==============================================
// BACKGROUND
// ==============================================

class _ProfileBackground extends StatelessWidget {
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
                  colors.amber.withOpacity(colors.isDark ? 0.10 : 0.14),
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