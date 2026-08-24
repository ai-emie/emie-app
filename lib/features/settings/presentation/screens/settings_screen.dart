// ===============================================
// Emie • Settings Screen
// Konto • Erscheinungsbild • Sprache • Emie
// Pfad: lib/features/settings/presentation/screens/settings_screen.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../state/session_store.dart';
import '../../../auth/controller/auth_controller.dart';
import '../../../auth/presentation/screens/auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _gold = Color(0xFF8A6117);
  static const Color _goldSoft = Color(0xFF9A6F1C);
  static const Color _danger = Color(0xFFFF7A7A);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = _SettingsColors(isDark: isDark);
    final t = _SettingsText(session.language);

    final email = session.user?.email ?? t.notLoaded;
    final name = session.displayName;
    final initial = session.displayInitial;

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
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
            physics: const BouncingScrollPhysics(),
            children: [
              _Header(title: t.settings, colors: c),
              const SizedBox(height: 30),

              _ProfileCard(
                name: name,
                email: email,
                initial: initial,
                colors: c,
              ),

              const SizedBox(height: 26),

              _SectionTitle(t.account, colors: c),
              _SettingsCard(
                colors: c,
                children: [
                  _InfoTile(
                    icon: Icons.mail_outline_rounded,
                    title: t.email,
                    subtitle: email,
                    colors: c,
                  ),
                  _Divider(colors: c),
                  _ActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: t.changePassword,
                    subtitle: t.comingSoon,
                    colors: c,
                    onTap: () {},
                  ),
                  _Divider(colors: c),
                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: t.deleteAccount,
                    subtitle: t.requestDeletion,
                    danger: true,
                    colors: c,
                    onTap: () async {
                      final uri = Uri.parse(
                        'https://emiso.ai/konto-loeschen.html',
                      );

                      final opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );

                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t.couldNotOpenDeletionPage),
                          ),
                        );
                      }
                    },
                  ),
                  _Divider(colors: c),
                  _ActionTile(
                    icon: Icons.logout_rounded,
                    title: t.logout,
                    subtitle: t.backToLogin,
                    danger: true,
                    colors: c,
                    onTap: () async {
                      await context.read<AuthController>().logout();

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const AuthScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 26),

              _SectionTitle(t.appearance, colors: c),
              _SettingsCard(
                colors: c,
                children: [
                  _ThemeTile(
                    title: t.system,
                    subtitle: t.systemSub,
                    value: EmieThemeMode.system,
                    selected: session.themeMode == EmieThemeMode.system,
                    colors: c,
                  ),
                  _Divider(colors: c),
                  _ThemeTile(
                    title: 'Light Gold',
                    subtitle: t.lightSub,
                    value: EmieThemeMode.light,
                    selected: session.themeMode == EmieThemeMode.light,
                    colors: c,
                  ),
                  _Divider(colors: c),
                  _ThemeTile(
                    title: 'Black Gold',
                    subtitle: t.darkSub,
                    value: EmieThemeMode.dark,
                    selected: session.themeMode == EmieThemeMode.dark,
                    colors: c,
                  ),
                ],
              ),

              const SizedBox(height: 26),

              _SectionTitle(t.language, colors: c),
              _SettingsCard(
                colors: c,
                children: [
                  _LanguageTile(
                    title: 'Deutsch',
                    subtitle: 'App-Sprache Deutsch',
                    code: 'de',
                    selected: session.language == 'de',
                    colors: c,
                  ),
                  _Divider(colors: c),
                  _LanguageTile(
                    title: 'English',
                    subtitle: 'App language English',
                    code: 'en',
                    selected: session.language == 'en',
                    colors: c,
                  ),
                ],
              ),

              const SizedBox(height: 26),

              _SectionTitle('Emie', colors: c),
              _SettingsCard(
                colors: c,
                children: [
                  _InfoTile(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Emie Plus',
                    subtitle: t.plusSub,
                    colors: c,
                  ),
                  _Divider(colors: c),
                  _InfoTile(
                    icon: Icons.info_outline_rounded,
                    title: t.version,
                    subtitle: 'Emie Alpha · 0.1',
                    colors: c,
                  ),
                  _Divider(colors: c),
                  _InfoTile(
                    icon: Icons.privacy_tip_outlined,
                    title: t.privacy,
                    subtitle: t.comingSoon,
                    colors: c,
                  ),
                  _Divider(colors: c),
                  _InfoTile(
                    icon: Icons.description_outlined,
                    title: t.terms,
                    subtitle: t.comingSoon,
                    colors: c,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================
// COLORS
// ==============================================

class _SettingsColors {
  _SettingsColors({required this.isDark});

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

  Color get border => SettingsScreen._gold.withOpacity(
        isDark ? 0.12 : 0.24,
      );

  List<Color> get gradient => [bg, bg2, bg];
}

// ==============================================
// TEXT
// ==============================================

class _SettingsText {
  _SettingsText(String code) : isDe = code == 'de';

  final bool isDe;

  String get settings => isDe ? 'Einstellungen' : 'Settings';
  String get account => isDe ? 'Konto' : 'Account';
  String get appearance => isDe ? 'Erscheinungsbild' : 'Appearance';
  String get language => isDe ? 'Sprache' : 'Language';
  String get email => isDe ? 'E-Mail' : 'Email';
  String get changePassword => isDe ? 'Passwort ändern' : 'Change password';
  String get comingSoon => isDe ? 'Kommt bald' : 'Coming soon';
  String get deleteAccount => isDe ? 'Konto löschen' : 'Delete account';
  String get requestDeletion =>
      isDe ? 'Kontolöschung anfordern' : 'Request account deletion';
  String get couldNotOpenDeletionPage => isDe
      ? 'Die Seite zur Kontolöschung konnte nicht geöffnet werden.'
      : 'The account deletion page could not be opened.';
  String get logout => isDe ? 'Abmelden' : 'Log out';
  String get backToLogin => isDe ? 'Zurück zum Login' : 'Back to login';
  String get notLoaded => isDe ? 'Noch nicht geladen' : 'Not loaded yet';

  String get system => isDe ? 'System' : 'System';
  String get systemSub =>
      isDe ? 'Emie folgt deinem Gerät' : 'Emie follows your device';
  String get lightSub => isDe
      ? 'Helles Design mit Gold-Akzent'
      : 'Light design with gold accent';
  String get darkSub =>
      isDe ? 'Dunkles Premium-Design' : 'Dark premium design';

  String get plusSub => isDe
      ? 'Mehr Tokens & früherer Feature-Zugang'
      : 'More tokens & early feature access';

  String get version => isDe ? 'Version' : 'Version';
  String get privacy => isDe ? 'Datenschutz' : 'Privacy';
  String get terms => isDe ? 'Nutzungsbedingungen' : 'Terms of use';
}

// ==============================================
// HEADER
// ==============================================

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.colors,
  });

  final String title;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.text.withOpacity(0.025),
              border: Border.all(
                color: SettingsScreen._gold.withOpacity(0.20),
                width: 0.7,
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              color: SettingsScreen._gold.withOpacity(0.82),
              size: 20,
            ),
          ),
        ),
        const Spacer(),
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 38),
      ],
    );
  }
}

// ==============================================
// PROFILE CARD
// ==============================================

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.initial,
    required this.colors,
  });

  final String name;
  final String email;
  final String initial;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(0.7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            SettingsScreen._goldSoft.withOpacity(0.24),
            SettingsScreen._gold.withOpacity(0.32),
            SettingsScreen._goldSoft.withOpacity(0.10),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SettingsScreen._goldSoft.withOpacity(0.10),
                border: Border.all(
                  color: SettingsScreen._gold.withOpacity(0.30),
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: SettingsScreen._gold,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                  ),
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
// SECTION TITLE
// ==============================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.colors});

  final String title;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: SettingsScreen._gold.withOpacity(0.70),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ==============================================
// SETTINGS CARD
// ==============================================

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
    required this.colors,
  });

  final List<Widget> children;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.border,
          width: 0.7,
        ),
      ),
      child: Column(children: children),
    );
  }
}

// ==============================================
// TILES
// ==============================================

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      colors: colors,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.colors,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final _SettingsColors colors;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      danger: danger,
      trailing: Icons.chevron_right_rounded,
      colors: colors,
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final EmieThemeMode value;
  final bool selected;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      icon: selected
          ? Icons.radio_button_checked_rounded
          : Icons.radio_button_off_rounded,
      title: title,
      subtitle: subtitle,
      selected: selected,
      colors: colors,
      onTap: () {
        context.read<SessionStore>().setThemeMode(value);
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.selected,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final String code;
  final bool selected;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      icon: selected
          ? Icons.radio_button_checked_rounded
          : Icons.radio_button_off_rounded,
      title: title,
      subtitle: subtitle,
      selected: selected,
      colors: colors,
      onTap: () {
        context.read<SessionStore>().setLanguage(code);
      },
    );
  }
}

class _BaseTile extends StatelessWidget {
  const _BaseTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.onTap,
    this.trailing,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _SettingsColors colors;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final mainColor = danger
        ? SettingsScreen._danger
        : selected
            ? SettingsScreen._gold
            : colors.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              color: danger
                  ? SettingsScreen._danger
                  : SettingsScreen._gold.withOpacity(
                      selected ? 0.92 : 0.72,
                    ),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: mainColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13,
                      height: 1.3,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Icon(
                trailing,
                color: SettingsScreen._gold.withOpacity(0.50),
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.colors});

  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      color: colors.border,
    );
  }
}