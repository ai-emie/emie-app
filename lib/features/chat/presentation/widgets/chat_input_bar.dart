// ===============================================
// Emie • Chat Input Bar (Text-Only)
// Pfad: lib/features/chat/presentation/widgets/chat_input_bar.dart
// ===============================================

import 'package:flutter/material.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onSnack,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.bg,
    required this.hintText,
    this.attachHintText = 'Anhänge sind aktuell nicht verfügbar.',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(String msg) onSnack;

  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color bg;

  /// Placeholder im Input (lokalisiert)
  final String hintText;

  /// Text für Attach-Button Hinweis (lokalisiert möglich)
  final String attachHintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onSnack(attachHintText),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surface,
                border: Border.all(color: border.withOpacity(0.7), width: 1),
              ),
              child: Icon(
                Icons.attach_file_rounded,
                color: textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: surface,
                border: Border.all(color: border.withOpacity(0.7), width: 1),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textPrimary,
              ),
              child: Icon(Icons.send_rounded, size: 18, color: bg),
            ),
          ),
        ],
      ),
    );
  }
}
