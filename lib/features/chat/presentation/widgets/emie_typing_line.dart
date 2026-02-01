// ===============================================
// Emie • Typing Line (ChatGPT-like minimal)
// Pfad: lib/features/chat/presentation/widgets/emie_typing_line.dart
// ===============================================

import 'package:flutter/material.dart';

class EmieTypingLine extends StatelessWidget {
  const EmieTypingLine({
    super.key,
    required this.surface,
    required this.border,
    required this.textSecondary,
  });

  final Color surface;
  final Color border;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Separator wie bei den Emie Turns
          Container(
            height: 1,
            color: border.withOpacity(0.30),
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: textSecondary.withOpacity(0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Emie schreibt…',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
