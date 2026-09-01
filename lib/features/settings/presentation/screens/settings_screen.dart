// ===============================================
// Emie • Settings Screen
// Konto • Erscheinungsbild • Sprache • Emie
// Pfad: lib/features/settings/presentation/screens/settings_screen.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../state/session_store.dart';
import '../../../auth/controller/auth_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Color _gold = Color(0xFF8A6117);
  static const Color _goldSoft = Color(0xFF9A6F1C);
  static const Color _danger = Color(0xFFFF7A7A);

  static const String _privacyUrl = 'https://emiso.ai/privacy.html';
  static const String _termsUrl = 'https://emiso.ai/terms.html';

  Future<void> _openLegalPage(
    BuildContext context,
    String url,
  ) async {
    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showLegalLinkError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showLegalLinkError(context);
      }
    }
  }

  void _showLegalLinkError(BuildContext context) {
    final isDe =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'de';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isDe
              ? 'Die Seite konnte nicht geöffnet werden.'
              : 'The page could not be opened.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final auth = context.watch<AuthController>();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final c = _SettingsColors(
      isDark: isDark,
    );

    final t = _SettingsText(
      session.language,
    );

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
            padding: const EdgeInsets.fromLTRB(
              22,
              18,
              22,
              36,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              _Header(
                title: t.settings,
                colors: c,
              ),

              const SizedBox(height: 30),

              _ProfileCard(
                name: name,
                email: email,
                initial: initial,
                colors: c,
              ),

              const SizedBox(height: 26),

              // ==========================================
              // KONTO
              // ==========================================

              _SectionTitle(
                t.account,
                colors: c,
              ),

              _SettingsCard(
                colors: c,
                children: [
                  _InfoTile(
                    icon: Icons.mail_outline_rounded,
                    title: t.email,
                    subtitle: email,
                    colors: c,
                  ),

                  _Divider(
                    colors: c,
                  ),

                  // ======================================
                  // ACCOUNT LÖSCHEN
                  // ======================================

                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: t.deleteAccount,
                    subtitle:
                        auth.isLoading ? t.deletingAccount : t.requestDeletion,
                    danger: true,
                    loading: auth.isLoading,
                    colors: c,
                    onTap: auth.isLoading
                        ? null
                        : () async {
                            await _handleDeleteAccount(
                              context,
                              t,
                              c,
                            );
                          },
                  ),

                  _Divider(
                    colors: c,
                  ),

                  // ======================================
                  // LOGOUT
                  // ======================================

                  _ActionTile(
                    icon: Icons.logout_rounded,
                    title: t.logout,
                    subtitle: t.backToLogin,
                    danger: true,
                    colors: c,
                    onTap: auth.isLoading
                        ? null
                        : () async {
                            // Keine Navigation hier.
                            //
                            // logout() löscht die Session.
                            // app.dart reagiert auf
                            // SessionStore und wechselt
                            // den Root automatisch vom
                            // MainShell zum AuthScreen.
                            await context.read<AuthController>().logout();
                          },
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // ==========================================
              // ERSCHEINUNGSBILD
              // ==========================================

              _SectionTitle(
                t.appearance,
                colors: c,
              ),

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
                  _Divider(
                    colors: c,
                  ),
                  _ThemeTile(
                    title: 'Light Gold',
                    subtitle: t.lightSub,
                    value: EmieThemeMode.light,
                    selected: session.themeMode == EmieThemeMode.light,
                    colors: c,
                  ),
                  _Divider(
                    colors: c,
                  ),
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

              // ==========================================
              // SPRACHE
              // ==========================================

              _SectionTitle(
                t.language,
                colors: c,
              ),

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
                  _Divider(
                    colors: c,
                  ),
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

              // ==========================================
              // EMIE
              // ==========================================

              _SectionTitle(
                'Emie',
                colors: c,
              ),

              _SettingsCard(
                colors: c,
                children: [
                  _InfoTile(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Emie Plus',
                    subtitle: t.plusSub,
                    colors: c,
                  ),

                  _Divider(
                    colors: c,
                  ),

                  // ======================================
                  // DYNAMISCHE APP-VERSION
                  // ======================================

                  _VersionTile(
                    title: t.version,
                    colors: c,
                  ),

                  _Divider(
                    colors: c,
                  ),

                  _ActionTile(
                    icon: Icons.privacy_tip_outlined,
                    title: t.privacy,
                    subtitle: 'emiso.ai',
                    colors: c,
                    onTap: () => _openLegalPage(
                      context,
                      _privacyUrl,
                    ),
                  ),

                  _Divider(
                    colors: c,
                  ),

                  _ActionTile(
                    icon: Icons.description_outlined,
                    title: t.terms,
                    subtitle: 'emiso.ai',
                    colors: c,
                    onTap: () => _openLegalPage(
                      context,
                      _termsUrl,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================
  // ACCOUNT DELETE FLOW
  // ==============================================

  Future<void> _handleDeleteAccount(
    BuildContext context,
    _SettingsText t,
    _SettingsColors colors,
  ) async {
    // -------------------------------------------
    // 1. Bestätigung
    // -------------------------------------------

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: SettingsScreen._danger.withOpacity(0.24),
              width: 0.8,
            ),
          ),
          title: Text(
            t.deleteConfirmTitle,
            style: TextStyle(
              color: colors.text,
              fontFamily: 'Inter',
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            t.deleteConfirmBody,
            style: TextStyle(
              color: colors.muted,
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            14,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: Text(
                t.cancel,
                style: TextStyle(
                  color: colors.muted,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: Text(
                t.deleteAccount,
                style: const TextStyle(
                  color: SettingsScreen._danger,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    // User hat abgebrochen.
    if (confirmed != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    // -------------------------------------------
    // 2. Backend + lokale Session löschen
    // -------------------------------------------

    final auth = context.read<AuthController>();

    final deleted = await auth.deleteAccount();

    // Bei Erfolg löscht AuthRepository:
    //
    // - Secure Storage Tokens
    // - SessionStore
    //
    // app.dart reagiert darauf und zeigt
    // automatisch wieder den Login-Screen.
    if (deleted) {
      return;
    }

    // -------------------------------------------
    // 3. Fehler anzeigen
    // -------------------------------------------

    if (!context.mounted) {
      return;
    }

    final message = auth.errorMessage ?? t.deleteFailed;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }
}

// ==============================================
// COLORS
// ==============================================

class _SettingsColors {
  _SettingsColors({
    required this.isDark,
  });

  final bool isDark;

  Color get bg => isDark ? const Color(0xFF050307) : const Color(0xFFF4F1EA);

  Color get bg2 => isDark ? const Color(0xFF0A0712) : const Color(0xFFFFFBF3);

  Color get card => isDark ? const Color(0xFF141312) : const Color(0xFFFCF8F1);

  Color get text => isDark ? Colors.white : const Color(0xFF17130C);

  Color get muted => isDark ? const Color(0xFF8E8B85) : const Color(0xFF736B5F);

  Color get border => SettingsScreen._gold.withOpacity(
        isDark ? 0.12 : 0.24,
      );

  List<Color> get gradient => [
        bg,
        bg2,
        bg,
      ];
}

// ==============================================
// TEXT
// ==============================================

class _SettingsText {
  _SettingsText(
    String code,
  ) : isDe = code == 'de';

  final bool isDe;

  String get settings => isDe ? 'Einstellungen' : 'Settings';

  String get account => isDe ? 'Konto' : 'Account';

  String get appearance => isDe ? 'Erscheinungsbild' : 'Appearance';

  String get language => isDe ? 'Sprache' : 'Language';

  String get email => isDe ? 'E-Mail' : 'Email';

  String get changePassword => isDe ? 'Passwort ändern' : 'Change password';

  String get comingSoon => isDe ? 'Kommt bald' : 'Coming soon';

  String get deleteAccount => isDe ? 'Konto löschen' : 'Delete account';

  String get requestDeletion => isDe
      ? 'Konto und Daten dauerhaft löschen'
      : 'Permanently delete account and data';

  String get deletingAccount =>
      isDe ? 'Konto wird gelöscht …' : 'Deleting account …';

  String get deleteConfirmTitle =>
      isDe ? 'Konto wirklich löschen?' : 'Delete account?';

  String get deleteConfirmBody => isDe
      ? 'Dein Emie-Konto und die damit verbundenen '
          'Daten werden dauerhaft gelöscht. '
          'Dieser Vorgang kann nicht rückgängig '
          'gemacht werden.'
      : 'Your Emie account and its associated data '
          'will be permanently deleted. '
          'This action cannot be undone.';

  String get cancel => isDe ? 'Abbrechen' : 'Cancel';

  String get deleteFailed => isDe
      ? 'Das Konto konnte nicht gelöscht werden.'
      : 'The account could not be deleted.';

  String get logout => isDe ? 'Abmelden' : 'Log out';

  String get backToLogin => isDe ? 'Zurück zum Login' : 'Back to login';

  String get notLoaded => isDe ? 'Noch nicht geladen' : 'Not loaded yet';

  String get system => 'System';

  String get systemSub =>
      isDe ? 'Emie folgt deinem Gerät' : 'Emie follows your device';

  String get lightSub =>
      isDe ? 'Helles Design mit Gold-Akzent' : 'Light design with gold accent';

  String get darkSub => isDe ? 'Dunkles Premium-Design' : 'Dark premium design';

  String get plusSub => isDe
      ? 'Mehr Tokens & früherer Feature-Zugang'
      : 'More tokens & early feature access';

  String get version => 'Version';

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
              color: colors.text.withOpacity(
                0.025,
              ),
              border: Border.all(
                color: SettingsScreen._gold.withOpacity(
                  0.20,
                ),
                width: 0.7,
              ),
            ),
            child: Icon(
              Icons.close_rounded,
              color: SettingsScreen._gold.withOpacity(
                0.82,
              ),
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
        const SizedBox(
          width: 38,
        ),
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
      padding: const EdgeInsets.all(
        0.7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          24,
        ),
        gradient: LinearGradient(
          colors: [
            SettingsScreen._goldSoft.withOpacity(
              0.24,
            ),
            SettingsScreen._gold.withOpacity(
              0.32,
            ),
            SettingsScreen._goldSoft.withOpacity(
              0.10,
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(
          18,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(
            23,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SettingsScreen._goldSoft.withOpacity(
                  0.10,
                ),
                border: Border.all(
                  color: SettingsScreen._gold.withOpacity(
                    0.30,
                  ),
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
            const SizedBox(
              width: 14,
            ),
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
                  const SizedBox(
                    height: 5,
                  ),
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
  const _SectionTitle(
    this.title, {
    required this.colors,
  });

  final String title;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 2,
        bottom: 9,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: SettingsScreen._gold.withOpacity(
            0.70,
          ),
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
      padding: const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        6,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: colors.border,
          width: 0.7,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ==============================================
// TILES
// ==============================================

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    required this.title,
    required this.colors,
  });

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  final String title;
  final _SettingsColors colors;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (
        context,
        snapshot,
      ) {
        final info = snapshot.data;

        final subtitle = info == null
            ? 'Emie · —'
            : 'Emie · ${info.version} (${info.buildNumber})';

        return _InfoTile(
          icon: Icons.info_outline_rounded,
          title: title,
          subtitle: subtitle,
          colors: colors,
        );
      },
    );
  }
}

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
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final _SettingsColors colors;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      danger: danger,
      loading: loading,
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
        context.read<SessionStore>().setThemeMode(
              value,
            );
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
        context.read<SessionStore>().setLanguage(
              code,
            );
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
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _SettingsColors colors;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool selected;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final mainColor = danger
        ? SettingsScreen._danger
        : selected
            ? SettingsScreen._gold
            : colors.text;

    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(
        14,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
        ),
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
            const SizedBox(
              width: 14,
            ),
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
                  const SizedBox(
                    height: 4,
                  ),
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
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: danger ? SettingsScreen._danger : SettingsScreen._gold,
                ),
              )
            else if (trailing != null)
              Icon(
                trailing,
                color: SettingsScreen._gold.withOpacity(
                  0.50,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// DIVIDER
// ==============================================

class _Divider extends StatelessWidget {
  const _Divider({
    required this.colors,
  });

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
