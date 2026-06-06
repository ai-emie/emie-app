// ===============================================
// Emie • Chat Screen
// Theme-aware Chat UI
// Pfad: lib/features/chat/presentation/screens/chat_screen.dart
// ===============================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../data/chat/chat_models.dart';
import '../../../../shared/widgets/emie_app_bar.dart';
import '../../controller/chat_controller.dart';

import '../widgets/chat_input_bar.dart';
import '../widgets/emie_response_card.dart';
import '../widgets/emie_typing_line.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _lastMessageCount = 0;
  String? _uiHint;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;

      final chat = context.read<ChatController>();

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

  void _handleNewChat(BuildContext context) {
    final chat = context.read<ChatController>();

    if (chat.isSending) {
      setState(
        () => _uiHint = _t(
          context,
          de: 'Bitte kurz warten…',
          en: 'Please wait…',
        ),
      );
      return;
    }

    chat.newChat();

    if (!mounted) return;

    setState(() => _uiHint = null);
  }

  void _autoScrollIfNeeded(int currentCount) {
    if (currentCount == _lastMessageCount) return;

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chat = context.watch<ChatController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = _ChatColors(isDark: isDark);

    _autoScrollIfNeeded(chat.messages.length);

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
            _ChatLuxuryBackground(colors: c),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                    child: EmieAppBar(
                      section: 'chat',
                      icon: Icons.history_rounded,
                      onIconTap: () => _showChatListSheet(context, c),
                    ),
                  ),
                  Expanded(
                    child: chat.messages.isEmpty
                        ? _buildEmptyChat(c)
                        : _buildMessageList(
                            chat: chat,
                            colors: c,
                          ),
                  ),
                  if (_uiHint != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _uiHint!,
                          style: TextStyle(
                            color: c.muted,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ChatInputBar(
                    controller: _textController,
                    onSend: () => _send(context),
                    onSnack: (_) {},
                    surface: c.surface,
                    border: c.border,
                    textPrimary: c.text,
                    textSecondary: c.muted,
                    bg: c.bg,
                    hintText: l10n.askEmie,
                    attachHintText: _t(
                      context,
                      de: 'Anhänge sind aktuell nicht verfügbar.',
                      en: 'Attachments are not available yet.',
                    ),
                  ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat(_ChatColors c) {
    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 56, 22, 20),
      children: [
        Text(
          _t(
            context,
            de: 'Neuer Chat.',
            en: 'New chat.',
          ),
          style: TextStyle(
            color: c.text.withOpacity(0.94),
            fontSize: 25,
            height: 1.18,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList({
    required ChatController chat,
    required _ChatColors colors,
  }) {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      itemCount: chat.messages.length,
      itemBuilder: (context, index) {
        final ChatMessage msg = chat.messages[index];
        final text = msg.text;
        final isUser = msg.role == 'user';

        final messageKey = ValueKey(
          '${msg.role}_${msg.text.hashCode}_$index',
        );

        if (!isUser && text.trim() == '…') {
          return KeyedSubtree(
            key: messageKey,
            child: EmieTypingLine(
              surface: colors.surface,
              border: colors.border,
              textSecondary: colors.muted,
            ),
          );
        }

        if (isUser) {
          return KeyedSubtree(
            key: messageKey,
            child: _UserPlainMessage(
              text: text,
              colors: colors,
            ),
          );
        }

        return KeyedSubtree(
          key: messageKey,
          child: EmieResponseCard(
            markdown: text,
            bg: colors.bg,
            surface: colors.surface,
            border: colors.border,
            textPrimary: colors.text,
            textSecondary: colors.muted,
          ),
        );
      },
    );
  }

  void _showChatListSheet(BuildContext context, _ChatColors c) {
    final chat = context.read<ChatController>();
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchController.text.trim().toLowerCase();

            final sessions = chat.sessions.where((session) {
              if (query.isEmpty) return true;
              return session.id.toLowerCase().contains(query);
            }).toList();

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.72,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  decoration: BoxDecoration(
                    color: c.sheet,
                    border: Border(
                      top: BorderSide(
                        color: c.border,
                        width: 0.7,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _t(
                              context,
                              de: 'Chats',
                              en: 'Chats',
                            ),
                            style: TextStyle(
                              color: c.goldText,
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _handleNewChat(context);
                            },
                            icon: Icon(
                              Icons.add_rounded,
                              color: c.goldText.withOpacity(0.82),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: c.border,
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: c.muted,
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                onChanged: (_) => setSheetState(() {}),
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                                decoration: InputDecoration(
                                  hintText: _t(
                                    context,
                                    de: 'Chats suchen...',
                                    en: 'Search chats...',
                                  ),
                                  hintStyle: TextStyle(
                                    color: c.muted,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: sessions.isEmpty
                            ? Center(
                                child: Text(
                                  _t(
                                    context,
                                    de: 'Noch keine gespeicherten Chats.',
                                    en: 'No saved chats yet.',
                                  ),
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: sessions.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final session = sessions[index];

                                  return _ChatHistoryItem(
                                    title: 'Chat ${index + 1}',
                                    subtitle: _t(
                                      context,
                                      de: 'Gespeicherte Unterhaltung',
                                      en: 'Saved conversation',
                                    ),
                                    colors: c,
                                    onTap: () async {
                                      Navigator.of(ctx).pop();
                                      await chat.openChat(session.id);
                                    },
                                    onDelete: () async {
                                      await chat.deleteChat(session.id);

                                      if (context.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      searchController.dispose();
    });
  }

  String _t(
    BuildContext context, {
    required String de,
    required String en,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'de' ? de : en;
  }
}

// ==============================================
// COLORS
// ==============================================

class _ChatColors {
  const _ChatColors({
    required this.isDark,
  });

  final bool isDark;

  Color get bg => isDark
      ? const Color(0xFF050307)
      : const Color(0xFFF4F1EA);

  Color get bg2 => isDark
      ? const Color(0xFF0A0712)
      : const Color(0xFFFFFBF3);

  Color get surface => isDark
      ? const Color(0xFF141312)
      : const Color(0xFFFCF8F1);

  Color get text => isDark
      ? Colors.white
      : const Color(0xFF17130C);

  Color get muted => isDark
      ? const Color(0xFF8E8B85)
      : const Color(0xFF736B5F);

  Color get goldText => isDark
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get amber => isDark
      ? const Color(0xFFFFC96B)
      : const Color(0xFFB88922);

  Color get border => goldText.withOpacity(isDark ? 0.16 : 0.22);

  Color get sheet => isDark
      ? Colors.black.withOpacity(0.88)
      : const Color(0xFFFFFBF3).withOpacity(0.94);

  List<Color> get gradient => [bg, bg2, bg];
}

// ==============================================
// BACKGROUND
// ==============================================

class _ChatLuxuryBackground extends StatelessWidget {
  const _ChatLuxuryBackground({
    required this.colors,
  });

  final _ChatColors colors;

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
                    colors.isDark ? 0.10 : 0.14,
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
// USER MESSAGE
// ==============================================

class _UserPlainMessage extends StatelessWidget {
  const _UserPlainMessage({
    required this.text,
    required this.colors,
  });

  final String text;
  final _ChatColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(42, 10, 2, 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: colors.text.withOpacity(0.92),
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

// ==============================================
// CHAT HISTORY ITEM
// ==============================================

class _ChatHistoryItem extends StatelessWidget {
  const _ChatHistoryItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final _ChatColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
          width: 0.7,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.only(
          left: 16,
          right: 6,
          top: 4,
          bottom: 4,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: colors.goldText.withOpacity(0.92),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: colors.muted,
            fontSize: 12.5,
            fontFamily: 'Inter',
          ),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: colors.muted,
            size: 20,
          ),
        ),
      ),
    );
  }
}