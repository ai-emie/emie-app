// ===============================================
// Emie • Settings Screen (ChatGPT-like, Theme-aware, i18n)
// Pfad: lib/features/settings/presentation/screens/settings_screen.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../state/session_store.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late EmieThemeMode _themeMode;
  late String _language;

  @override
  void initState() {
    super.initState();
    final session = SessionStore.instance;
    _themeMode = session.themeMode;
    _language = session.language;
  }

  void _exitSettings(BuildContext context) {
    // ✅ Always leave settings:
    // 1) normal pop if possible
    // 2) otherwise fallback to ChatScreen (prevents "trapped" states)
    final nav = Navigator.of(context);

    if (nav.canPop()) {
      nav.pop();
      return;
    }

    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final l10n = context.l10n;

    // Sync bei externen Änderungen
    _themeMode = session.themeMode;
    _language = session.language;

    final displayName = session.displayName;
    final displayInitial = session.displayInitial;
    final email = session.user?.email ?? '—';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = theme.scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF0D0D11) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    final titleColor = isDark ? Colors.white : const Color(0xFF0E0E0E);
    final subColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.55);

    final gold = const Color(0xFFFFD37F);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,

        // ✅ FIX: Du kommst IMMER raus
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded, // ChatGPT-like close
            size: 22,
            color: titleColor,
          ),
          onPressed: () => _exitSettings(context),
          tooltip: _t(context, de: 'Schließen', en: 'Close'),
        ),

        title: Text(
          l10n.settings,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ===========================================
            //  PROFIL
            // ===========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: gold.withValues(alpha: 0.90),
                        width: 1.6,
                      ),
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    child: Center(
                      child: Text(
                        displayInitial,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            color: subColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ===========================================
            //  KONTO
            // ===========================================
            _sectionHeader(l10n.account, subColor),
            _settingsCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.email, style: TextStyle(color: titleColor)),
                  subtitle: Text(email, style: TextStyle(color: subColor)),
                ),
                Divider(height: 1, color: cardBorder),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.changePassword, style: TextStyle(color: titleColor)),
                  trailing: Icon(Icons.chevron_right_rounded, color: subColor),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _logoutButton(context, l10n.logout),

            const SizedBox(height: 24),

            // ===========================================
            //  ERSCHEINUNGSBILD
            // ===========================================
            _sectionHeader(l10n.appearance, subColor),
            _settingsCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.design,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _themeRadio(
                  context: context,
                  label: l10n.systemDefault,
                  description: l10n.systemDesc,
                  value: EmieThemeMode.system,
                  isSelected: _themeMode == EmieThemeMode.system,
                  titleColor: titleColor,
                  subColor: subColor,
                  gold: gold,
                ),
                _themeRadio(
                  context: context,
                  label: l10n.lightTheme,
                  description: l10n.lightDesc,
                  value: EmieThemeMode.light,
                  isSelected: _themeMode == EmieThemeMode.light,
                  titleColor: titleColor,
                  subColor: subColor,
                  gold: gold,
                ),
                _themeRadio(
                  context: context,
                  label: l10n.darkTheme,
                  description: l10n.darkDesc,
                  value: EmieThemeMode.dark,
                  isSelected: _themeMode == EmieThemeMode.dark,
                  titleColor: titleColor,
                  subColor: subColor,
                  gold: gold,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===========================================
            //  SPRACHE
            // ===========================================
            _sectionHeader(l10n.language, subColor),
            _settingsCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.appLanguage, style: TextStyle(color: titleColor)),
                  subtitle: Text(
                    _language == 'de' ? l10n.german : l10n.english,
                    style: TextStyle(color: subColor),
                  ),
                  trailing: Icon(Icons.swap_horiz_rounded, color: subColor),
                  onTap: () {
                    final newLang = _language == 'de' ? 'en' : 'de';
                    setState(() => _language = newLang);
                    context.read<SessionStore>().setLanguage(newLang);
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===========================================
            //  ÜBER EMIE
            // ===========================================
            _sectionHeader(l10n.about, subColor),
            _settingsCard(
              cardBg: cardBg,
              cardBorder: cardBorder,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.version, style: TextStyle(color: titleColor)),
                  subtitle: Text('Emie · 0.1', style: TextStyle(color: subColor)),
                ),
                Divider(height: 1, color: cardBorder),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.poweredBy, style: TextStyle(color: titleColor)),
                  subtitle: Text(l10n.builtBy, style: TextStyle(color: subColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  //  HELFER
  // =========================================================
  Widget _sectionHeader(String title, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(
          color: subColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _settingsCard({
    required Color cardBg,
    required Color cardBorder,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _themeRadio({
    required BuildContext context,
    required String label,
    required String description,
    required EmieThemeMode value,
    required bool isSelected,
    required Color titleColor,
    required Color subColor,
    required Color gold,
  }) {
    return InkWell(
      onTap: () {
        setState(() => _themeMode = value);
        context.read<SessionStore>().setThemeMode(value);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: isSelected ? gold : subColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(color: subColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton(BuildContext context, String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () {
          final session = context.read<SessionStore>();
          session.clear();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFF8080),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }

  String _t(BuildContext context, {required String de, required String en}) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'de' ? de : en;
  }
}
