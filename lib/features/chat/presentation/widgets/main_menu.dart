// ===============================================
// Emie • Main Menu (ChatGPT-like History Sidebar • Clean)
// Pfad: lib/features/chat/presentation/widgets/main_menu.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../controller/chat_controller.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({
    super.key,
    required this.onClose,
    required this.onOpenSettings,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chat = context.watch<ChatController>();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);
    final surface = isDark ? const Color(0xFF151515) : const Color(0xFFF4F4F4);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0E0E0E);
    final textSecondary = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF5A5A5A);
    final divider = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);
    final activeBg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);

    final q = _search.text.trim().toLowerCase();
    final list = chat.sessions.where((s) {
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q);
    }).toList();

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            // =========================================
            // Header (ChatGPT-like)
            // =========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
              child: Row(
                children: [
                  Text(
                    l10n.appName,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close_rounded, color: textPrimary),
                  ),
                ],
              ),
            ),

            // =========================================
            // New Chat (simple row, not a big button)
            // =========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (chat.isSending) return;
                    chat.newChat();
                    widget.onClose();
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, color: textPrimary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          l10n.newChat,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // =========================================
            // Search (clean)
            // =========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: divider),
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: _t(context, de: 'Chats suchen…', en: 'Search chats…'),
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13.5),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // =========================================
            // Section label
            // =========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _t(context, de: 'Deine Chats', en: 'Your chats'),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            // =========================================
            // History list (compact)
            // =========================================
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final s = list[i];
                  final isActive = s.id == chat.chatSessionId;

                  // ✅ "New chat" lokalisiert anzeigen (Controller ist context-free)
                  final title = (s.title.trim() == 'New chat')
                      ? l10n.newChat
                      : s.title.trim();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isActive ? activeBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (chat.isSending) return;
                          chat.openChat(s.id);
                          widget.onClose();
                        },
                        onLongPress: () {
                          if (chat.isSending) return;
                          _confirmDelete(context, s.id, title);
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18,
                                color: isActive ? textPrimary : textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Divider(height: 1, color: divider),

            // =========================================
            // Bottom profile/settings
            // =========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: surface,
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08),
                  child: Text('E', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800)),
                ),
                title: Text('emiso.emie', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800)),
                subtitle: Text(l10n.profileSettings, style: TextStyle(color: textSecondary, fontSize: 12)),
                onTap: () {
                  widget.onClose();
                  widget.onOpenSettings();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.read<ChatController>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0E0E0E) : Colors.white,
          title: Text(_t(context, de: 'Chat löschen?', en: 'Delete chat?')),
          content: Text(_t(context, de: '„$title“ wird entfernt.', en: '“$title” will be removed.')),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t(context, de: 'Abbrechen', en: 'Cancel'))),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_t(context, de: 'Löschen', en: 'Delete'))),
          ],
        );
      },
    );

    if (ok == true) {
      chat.deleteChat(id);
    }
  }

  String _t(BuildContext context, {required String de, required String en}) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'de' ? de : en;
  }
}
