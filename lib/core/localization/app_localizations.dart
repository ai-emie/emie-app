// ===============================================
// Emie • App Localizations (DE/EN)
// Pfad: lib/core/localization/app_localizations.dart
// ===============================================

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Minimal, robuste i18n-Lösung ohne Code-Gen.
/// Unterstützt Deutsch (de) und Englisch (en).
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(loc != null, 'AppLocalizations not found in context');
    return loc!;
  }

  static const supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  static const Map<String, Map<String, String>> _strings = {
    'de': {
      'app_name': 'Emie',
      'powered_by': 'powered by Emiso',

      'new_chat': 'Neuer Chat',
      'my_chats': 'Meine Chats',
      'search_chats': 'Chats suchen',
      'library': 'Bibliothek',
      'projects': 'Projekte',
      'profile_settings': 'Profil & Einstellungen',

      'settings': 'Einstellungen',
      'account': 'Konto',
      'appearance': 'Erscheinungsbild',
      'language': 'Sprache',
      'about': 'Über Emie',

      // Settings: Account
      'email': 'E-Mail-Adresse',
      'change_password': 'Passwort ändern',
      'logout': 'Abmelden',

      // Settings: Theme
      'design': 'Design',
      'system_default': 'Systemstandard',
      'light_theme': 'Hell – Emie Light Gold',
      'dark_theme': 'Dunkel – Emie Black Gold',
      'system_desc': 'Nutze das Theme deines Geräts.',
      'light_desc': 'Helle Oberfläche mit Gold-Akzenten.',
      'dark_desc': 'Dunkle Oberfläche mit Gold-Akzenten.',

      // Settings: Language
      'app_language': 'App-Sprache',
      'german': 'Deutsch',
      'english': 'Englisch',

      // About
      'version': 'Version',
      'built_by': 'Gemeinsam gebaut von Mensch & KI.',

      // Beta help: only this blank template and installed version leave the app.
      'feedback_title': 'Hilfe & Feedback',
      'feedback_entry': 'Fragen oder Fehler in der Beta melden',
      'feedback_contact': 'Vorläufiger Beta-Kontakt',
      'feedback_intro': 'Brauchst du Hilfe oder möchtest du einen Fehler melden? '
          'Die installierte Version und Schritte zum Nachstellen helfen uns.',
      'feedback_privacy': 'Bitte keine Passwörter, API-Schlüssel, '
          'Bestätigungs-/Resetlinks oder vertraulichen Inhalte mitschicken.',
      'feedback_draft_hint': 'Es wird nur ein Mailentwurf mit der Vorlage '
          'vorbereitet. Du ergänzt und prüfst ihn und sendest selbst. '
          'Kontodaten, App-Inhalte und Anhänge werden nicht automatisch ergänzt.',
      'feedback_prepare': 'E-Mail vorbereiten',
      'feedback_copy_address': 'Kontaktadresse kopieren',
      'feedback_copy_template': 'Vorlage kopieren',
      'feedback_template_title': 'Fehlervorlage',
      'feedback_subject': 'Emie Beta – Hilfe & Feedback',
      'feedback_version': 'Appversion / Buildnummer',
      'feedback_version_manual': '[bitte selbst ergänzen]',
      'feedback_questions': 'Was wollte ich tun?\n\nWas ist passiert?\n\n'
          'Was hätte passieren sollen?\n\nWelche Schritte führen zum Problem?',
      'feedback_mail_opened': 'Mailprogramm aufgerufen. Bitte prüfe den Entwurf '
          'und sende ihn selbst.',
      'feedback_mail_unavailable': 'Es konnte kein Mailprogramm geöffnet werden. '
          'Kopiere die Kontaktadresse und die Vorlage und füge sie in dein Postfach ein.',
      'feedback_address_copied': 'Kontaktadresse kopiert.',
      'feedback_template_copied': 'Vorlage kopiert.',
      'feedback_copy_failed': 'Kopieren nicht möglich. Du kannst den Text '
          'direkt markieren und manuell übernehmen.',

      // Chat
      'ask_emie': 'Frag Emie etwas…',
      'plus': 'Plus',

      // Plus Sheet
      'emie_plus_title': 'Emie Plus',
      'emie_plus_line1': 'Emie Plus ist ein freiwilliges Support-Abo.',
      'emie_plus_line2': 'Core bleibt kostenlos und unverändert. Plus schaltet keine „besseren Antworten“ frei.',
      'emie_plus_line3': 'Plus-Vorteile: mehr Tokens und frühere Updates.',
      'ok': 'Okay',
    },
    'en': {
      'app_name': 'Emie',
      'powered_by': 'powered by Emiso',

      'new_chat': 'New chat',
      'my_chats': 'My chats',
      'search_chats': 'Search chats',
      'library': 'Library',
      'projects': 'Projects',
      'profile_settings': 'Profile & settings',

      'settings': 'Settings',
      'account': 'Account',
      'appearance': 'Appearance',
      'language': 'Language',
      'about': 'About Emie',

      // Settings: Account
      'email': 'Email address',
      'change_password': 'Change password',
      'logout': 'Log out',

      // Settings: Theme
      'design': 'Theme',
      'system_default': 'System default',
      'light_theme': 'Light – Emie Light Gold',
      'dark_theme': 'Dark – Emie Black Gold',
      'system_desc': 'Use your device theme.',
      'light_desc': 'Light UI with gold accents.',
      'dark_desc': 'Dark UI with gold accents.',

      // Settings: Language
      'app_language': 'App language',
      'german': 'German',
      'english': 'English',

      // About
      'version': 'Version',
      'built_by': 'Built together by human & AI.',

      'feedback_title': 'Help & feedback',
      'feedback_entry': 'Ask a question or report a beta issue',
      'feedback_contact': 'Temporary beta contact',
      'feedback_intro': 'Need help or want to report a problem? '
          'Your installed version and steps to reproduce the issue help us.',
      'feedback_privacy': 'Please do not include passwords, API keys, '
          'verification/reset links or confidential content.',
      'feedback_draft_hint': 'Only an email draft with the template is prepared. '
          'You fill it in, review it and send it yourself. Account details, '
          'app content and attachments are not added automatically.',
      'feedback_prepare': 'Prepare email',
      'feedback_copy_address': 'Copy contact address',
      'feedback_copy_template': 'Copy template',
      'feedback_template_title': 'Issue template',
      'feedback_subject': 'Emie Beta – Help & feedback',
      'feedback_version': 'App version / build number',
      'feedback_version_manual': '[please fill in]',
      'feedback_questions': 'What was I trying to do?\n\nWhat happened?\n\n'
          'What should have happened?\n\nWhat steps reproduce the problem?',
      'feedback_mail_opened': 'Mail app opened. Please review the draft '
          'and send it yourself.',
      'feedback_mail_unavailable': 'No mail app could be opened. Copy the '
          'contact address and template and paste them into your mailbox.',
      'feedback_address_copied': 'Contact address copied.',
      'feedback_template_copied': 'Template copied.',
      'feedback_copy_failed': 'Could not copy. You can select the text '
          'and copy it manually.',

      // Chat
      'ask_emie': 'Ask Emie…',
      'plus': 'Plus',

      // Plus Sheet
      'emie_plus_title': 'Emie Plus',
      'emie_plus_line1': 'Emie Plus is a voluntary support subscription.',
      'emie_plus_line2': 'Core remains free and unchanged. Plus does not unlock “better answers”.',
      'emie_plus_line3': 'Plus perks: more tokens and earlier updates.',
      'ok': 'OK',
    },
  };

  String _t(String key) {
    final lang = _strings[locale.languageCode] ?? _strings['en']!;
    return lang[key] ?? _strings['en']![key] ?? key;
  }

  // General
  String get appName => _t('app_name');
  String get poweredBy => _t('powered_by');

  // Menu
  String get newChat => _t('new_chat');
  String get myChats => _t('my_chats');
  String get searchChats => _t('search_chats');
  String get library => _t('library');
  String get projects => _t('projects');
  String get profileSettings => _t('profile_settings');

  // Settings Sections
  String get settings => _t('settings');
  String get account => _t('account');
  String get appearance => _t('appearance');
  String get language => _t('language');
  String get about => _t('about');

  // Settings: Account
  String get email => _t('email');
  String get changePassword => _t('change_password');
  String get logout => _t('logout');

  // Settings: Theme
  String get design => _t('design');
  String get systemDefault => _t('system_default');
  String get lightTheme => _t('light_theme');
  String get darkTheme => _t('dark_theme');
  String get systemDesc => _t('system_desc');
  String get lightDesc => _t('light_desc');
  String get darkDesc => _t('dark_desc');

  // Settings: Language
  String get appLanguage => _t('app_language');
  String get german => _t('german');
  String get english => _t('english');

  // About
  String get version => _t('version');
  String get builtBy => _t('built_by');

  // Beta help / feedback
  String get feedbackTitle => _t('feedback_title');
  String get feedbackEntry => _t('feedback_entry');
  String get feedbackContact => _t('feedback_contact');
  String get feedbackIntro => _t('feedback_intro');
  String get feedbackPrivacy => _t('feedback_privacy');
  String get feedbackDraftHint => _t('feedback_draft_hint');
  String get feedbackPrepare => _t('feedback_prepare');
  String get feedbackCopyAddress => _t('feedback_copy_address');
  String get feedbackCopyTemplate => _t('feedback_copy_template');
  String get feedbackTemplateTitle => _t('feedback_template_title');
  String get feedbackSubject => _t('feedback_subject');
  String get feedbackMailOpened => _t('feedback_mail_opened');
  String get feedbackMailUnavailable => _t('feedback_mail_unavailable');
  String get feedbackAddressCopied => _t('feedback_address_copied');
  String get feedbackTemplateCopied => _t('feedback_template_copied');
  String get feedbackCopyFailed => _t('feedback_copy_failed');

  String feedbackTemplate(String? installedVersion) =>
      '${_t('feedback_version')}: '
      '${installedVersion ?? _t('feedback_version_manual')}\n\n'
      '${_t('feedback_questions')}';

  // Chat
  String get askEmie => _t('ask_emie');
  String get plus => _t('plus');

  // Plus Sheet
  String get emiePlusTitle => _t('emie_plus_title');
  String get emiePlusLine1 => _t('emie_plus_line1');
  String get emiePlusLine2 => _t('emie_plus_line2');
  String get emiePlusLine3 => _t('emie_plus_line3');
  String get ok => _t('ok');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final normalized = AppLocalizations.supportedLocales.firstWhere(
      (l) => l.languageCode == locale.languageCode,
      orElse: () => const Locale('en'),
    );
    return SynchronousFuture<AppLocalizations>(AppLocalizations(normalized));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
