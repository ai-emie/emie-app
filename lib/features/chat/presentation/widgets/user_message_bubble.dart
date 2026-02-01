// ===============================================
// Emie • User Message Bubble (ChatGPT-like)
// Pfad: lib/features/chat/presentation/widgets/user_message_bubble.dart
// ===============================================

import 'package:flutter/material.dart';

class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({
    super.key,
    required this.text,
    required this.surface,
    required this.border,
    required this.textPrimary,
  });

  final String text;
  final Color surface;
  final Color border;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        // ChatGPT-like: mehr Luft links, damit User-Bubble nicht full-width wird
        padding: const EdgeInsets.only(left: 64, right: 0, bottom: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border.withOpacity(0.55), width: 1),
            ),
            child: SelectableText(
              text,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
