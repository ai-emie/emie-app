import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';

const _betaContact = 'emiso.emie@gmail.com';

enum _Notice {
  mailOpened,
  mailUnavailable,
  addressCopied,
  templateCopied,
  copyFailed
}

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({
    super.key,
    this.packageInfoLoader = PackageInfo.fromPlatform,
  });

  final Future<PackageInfo> Function() packageInfoLoader;

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  String? _installedVersion;
  _Notice? _notice;
  bool _openingMail = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      // The same platform source already used by Settings; no pubspec fallback.
      final info = await widget.packageInfoLoader();
      if (!mounted ||
          info.version.trim().isEmpty ||
          info.buildNumber.trim().isEmpty) {
        return;
      }
      setState(
          () => _installedVersion = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // The template remains usable with a manually completed version field.
    }
  }

  Future<void> _prepareEmail(AppLocalizations t) async {
    if (_openingMail) {
      return;
    }
    setState(() => _openingMail = true);
    try {
      // Explicit allowlist: no session, account, diagnostics or attachments.
      // Encode components ourselves so mail clients receive spaces, not '+'.
      final query = {
        'subject': t.feedbackSubject,
        'body': t.feedbackTemplate(_installedVersion),
      }
          .entries
          .map((entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
          .join('&');
      final opened = await launchUrl(
        Uri(scheme: 'mailto', path: _betaContact, query: query),
        mode: LaunchMode.externalApplication,
      );
      if (mounted) {
        setState(() =>
            _notice = opened ? _Notice.mailOpened : _Notice.mailUnavailable);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = _Notice.mailUnavailable);
      }
    } finally {
      if (mounted) {
        setState(() => _openingMail = false);
      }
    }
  }

  Future<void> _copy(String text, _Notice success) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        setState(() => _notice = success);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = _Notice.copyFailed);
      }
    }
  }

  String _noticeText(AppLocalizations t, _Notice notice) => switch (notice) {
        _Notice.mailOpened => t.feedbackMailOpened,
        _Notice.mailUnavailable => t.feedbackMailUnavailable,
        _Notice.addressCopied => t.feedbackAddressCopied,
        _Notice.templateCopied => t.feedbackTemplateCopied,
        _Notice.copyFailed => t.feedbackCopyFailed,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final template = t.feedbackTemplate(_installedVersion);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const BackButton(),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(t.feedbackTitle,
                              style: theme.textTheme.headlineSmall)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(t.feedbackIntro),
                  const SizedBox(height: 16),
                  _FeedbackCard(
                    children: [
                      Text(t.feedbackContact,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const SelectableText(_betaContact),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            _copy(_betaContact, _Notice.addressCopied),
                        child: Text(t.feedbackCopyAddress,
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(t.feedbackPrivacy,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(t.feedbackDraftHint),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _openingMail ? null : () => _prepareEmail(t),
                    child: Text(t.feedbackPrepare, textAlign: TextAlign.center),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                        liveRegion: true,
                        child: Text(_noticeText(t, _notice!))),
                  ],
                  const SizedBox(height: 16),
                  _FeedbackCard(
                    children: [
                      Text(t.feedbackTemplateTitle,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SelectableText(template),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            _copy(template, _Notice.templateCopied),
                        child: Text(t.feedbackCopyTemplate,
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children),
        ),
      );
}
