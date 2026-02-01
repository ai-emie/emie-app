// ===============================================
// Emie • Response Block (ChatGPT-like)
// Pfad: lib/features/chat/presentation/widgets/emie_response_card.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class EmieResponseCard extends StatelessWidget {
  const EmieResponseCard({
    super.key,
    required this.markdown,
    required this.bg,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String markdown;
  final Color bg;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    // ChatGPT-like spacing: getrennte “Turns”, keine Card über den ganzen Screen.
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // dezenter Separator zwischen Turns
          Container(
            height: 1,
            color: border.withOpacity(0.30),
          ),
          const SizedBox(height: 10),

          // Header row: Emie + Copy
          Row(
            children: [
              Text(
                'Emie',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: markdown));
                  // bewusst kein Snackbar (du willst calm UI)
                },
                icon: Icon(Icons.copy_rounded, size: 18, color: textSecondary),
              ),
            ],
          ),

          // Content with comfortable width
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
                child: MarkdownBody(
                  data: markdown,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: textPrimary,
                      fontSize: 14.5,
                      height: 1.62,
                    ),
                    h1: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    h2: TextStyle(
                      color: textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    h3: TextStyle(
                      color: textPrimary,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    strong: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    listBullet: TextStyle(
                      color: textPrimary,
                      height: 1.35,
                    ),
                    blockquote: TextStyle(
                      color: textSecondary,
                      height: 1.55,
                    ),
                    code: TextStyle(
                      color: textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    codeblockPadding: const EdgeInsets.all(14),
                    codeblockDecoration: BoxDecoration(
                      color: surface.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: border.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: border.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
