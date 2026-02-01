// ===============================================
// Emie • Chat Screen (ChatGPT-like, Theme-aware, i18n)
// Pfad: lib/features/chat/presentation/screens/chat_screen.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../controller/chat_controller.dart';
import '../../../../data/chat/chat_models.dart';

import '../../../settings/presentation/screens/settings_screen.dart';

import '../widgets/user_message_bubble.dart';
import '../widgets/emie_response_card.dart';
import '../widgets/emie_typing_line.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/main_menu.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  int _lastMessageCount = 0;
  String? _uiHint;

  // ==========================================
  //  STEP 5: Bootstrapping (load sessions once)
  // ==========================================
  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;
      final chat = context.read<ChatController>();

      // optional: only load if empty
      if (chat.sessions.isEmpty) {
        await chat.loadSessions();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(BuildContext context) async {
    final chat = context.read<ChatController>();
    final text = _textController.text.trim();
    if (text.isEmpty || chat.isSending) return;

    setState(() => _uiHint = null);

    _textController.clear();
    await chat.send(text);

    if (!mounted) return;

    final err = chat.error;
    if (err != null) {
      setState(
        () => _uiHint = _t(
          context,
          de: 'Verbindung nicht stabil. Bitte erneut senden.',
          en: 'Connection unstable. Please try again.',
        ),
      );
    }
  }

  void _autoScrollIfNeeded(int currentCount) {
    if (currentCount != _lastMessageCount) {
      _lastMessageCount = currentCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          max + 160,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  // ✅ FIX: kein async/await, weil chat.newChat() void ist
  void _handleNewChat(BuildContext context) {
    final chat = context.read<ChatController>();
    if (chat.isSending) {
      setState(() => _uiHint = _t(context, de: 'Bitte kurz warten…', en: 'Please wait…'));
      return;
    }

    chat.newChat();

    if (!mounted) return;
    setState(() => _uiHint = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chat = context.watch<ChatController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);
    final surface = isDark ? const Color(0xFF161616) : const Color(0xFFF4F4F4);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0E0E0E);
    final textSecondary = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF5A5A5A);

    _autoScrollIfNeeded(chat.messages.length);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: textPrimary),
          onPressed: () => _showMainMenu(context, isDark),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/emiso.logo.transparent.png',
              height: 22,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.poweredBy,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.newChat,
            onPressed: () => _handleNewChat(context),
            icon: Icon(Icons.add_comment_rounded, color: textPrimary),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: TextButton.icon(
              onPressed: () => _showEmiePlusSheet(context),
              style: TextButton.styleFrom(
                foregroundColor: textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: border, width: 1),
                ),
              ),
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: Text(
                l10n.plus,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
                itemCount: chat.messages.length,
                itemBuilder: (context, index) {
                  final ChatMessage msg = chat.messages[index];
                  final text = msg.text;
                  final isUser = msg.role == 'user';

                  if (!isUser && text.trim() == '…') {
                    return EmieTypingLine(
                      surface: surface,
                      border: border,
                      textSecondary: textSecondary,
                    );
                  }

                  if (isUser) {
                    return UserMessageBubble(
                      text: text,
                      surface: surface,
                      border: border,
                      textPrimary: textPrimary,
                    );
                  }

                  return EmieResponseCard(
                    markdown: text,
                    bg: bg,
                    surface: surface,
                    border: border,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                },
              ),
            ),
            if (_uiHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _uiHint!,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ),
              ),
            ChatInputBar(
              controller: _textController,
              onSend: () => _send(context),
              onSnack: (_) {},
              surface: surface,
              border: border,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              bg: bg,
              hintText: l10n.askEmie,
              attachHintText: _t(
                context,
                de: 'Anhänge sind aktuell nicht verfügbar.',
                en: 'Attachments are not available yet.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMainMenu(BuildContext context, bool isDark) {
    final width = MediaQuery.of(context).size.width * 0.80;
    final menuBg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Main Menu',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width,
              height: double.infinity,
              decoration: BoxDecoration(
                color: menuBg,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: MainMenu(
                onClose: () => Navigator.of(ctx).pop(),
                onOpenSettings: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          ),
        );

        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  void _showEmiePlusSheet(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0E0E0E);
    final textSecondary = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF5A5A5A);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      l10n.emiePlusTitle,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(l10n.emiePlusLine1, style: TextStyle(color: textSecondary, fontSize: 13, height: 1.35)),
                const SizedBox(height: 8),
                Text(l10n.emiePlusLine2, style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35)),
                const SizedBox(height: 12),
                Text(l10n.emiePlusLine3, style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: border),
                      foregroundColor: textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text(l10n.ok, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _t(BuildContext context, {required String de, required String en}) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'de' ? de : en;
  }
}
