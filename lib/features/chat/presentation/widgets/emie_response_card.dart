// ===============================================
// Emie • Response Block
// Theme-aware Luxury Minimal Assistant Response
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
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final gold = isDark
        ? const Color(0xFFFCF6BA)
        : const Color(0xFF8F6A18);

    final mutedGold = isDark
        ? const Color(0xFFBF953F)
        : const Color(0xFFB88922);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        2,
        18,
        2,
        14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ======================================
          // LABEL ROW
          // ======================================

          Row(
            children: [
              Image.asset(
                'assets/images/emiso.logo.transparent.png',
                height: 18,
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) => Icon(
                  Icons.auto_awesome_rounded,
                  color:
                      gold.withOpacity(0.78),
                  size: 16,
                ),
              ),

              const SizedBox(width: 8),

              Text(
                'emie',
                style: TextStyle(
                  color:
                      gold.withOpacity(0.84),
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w400,
                  letterSpacing: 1.4,
                  fontFamily: 'Inter',
                ),
              ),

              const Spacer(),

              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: markdown,
                    ),
                  );
                },
                behavior:
                    HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    6,
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: textSecondary
                        .withOpacity(0.70),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ======================================
          // ANSWER TEXT
          // ======================================

          ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 720,
            ),
            child: MarkdownBody(
              data: markdown,
              selectable: true,
              styleSheet:
                  MarkdownStyleSheet(
                p: TextStyle(
                  color: textPrimary
                      .withOpacity(0.95),
                  fontSize: 15,
                  height: 1.62,
                  fontWeight:
                      FontWeight.w400,
                  fontFamily: 'Inter',
                ),

                // ===============================
                // HEADINGS
                // ===============================

                h1: TextStyle(
                  color:
                      gold.withOpacity(0.96),
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w500,
                  height: 1.25,
                  fontFamily: 'Inter',
                ),

                h2: TextStyle(
                  color:
                      gold.withOpacity(0.94),
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w500,
                  height: 1.3,
                  fontFamily: 'Inter',
                ),

                h3: TextStyle(
                  color:
                      gold.withOpacity(0.92),
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w500,
                  height: 1.3,
                  fontFamily: 'Inter',
                ),

                // ===============================
                // EMPHASIS
                // ===============================

                strong: TextStyle(
                  color:
                      gold.withOpacity(0.94),
                  fontWeight:
                      FontWeight.w600,
                  fontFamily: 'Inter',
                ),

                em: TextStyle(
                  color: textPrimary
                      .withOpacity(0.88),
                  fontStyle:
                      FontStyle.italic,
                  fontFamily: 'Inter',
                ),

                // ===============================
                // LISTS
                // ===============================

                listBullet: TextStyle(
                  color: mutedGold
                      .withOpacity(0.90),
                  fontSize: 15,
                  height: 1.45,
                  fontFamily: 'Inter',
                ),

                // ===============================
                // BLOCKQUOTE
                // ===============================

                blockquote: TextStyle(
                  color: textSecondary
                      .withOpacity(0.92),
                  height: 1.55,
                  fontSize: 14.5,
                  fontFamily: 'Inter',
                ),

                // ===============================
                // INLINE CODE
                // ===============================

                code: TextStyle(
                  color:
                      gold.withOpacity(0.92),
                  fontFamily:
                      'monospace',
                  fontSize: 13,
                ),

                // ===============================
                // CODE BLOCK
                // ===============================

                codeblockPadding:
                    const EdgeInsets.all(
                  14,
                ),

                codeblockDecoration:
                    BoxDecoration(
                  color: surface
                      .withOpacity(0.68),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  border: Border.all(
                    color: border
                        .withOpacity(0.75),
                    width: 0.7,
                  ),
                ),

                // ===============================
                // HORIZONTAL RULE
                // ===============================

                horizontalRuleDecoration:
                    BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: border
                          .withOpacity(
                        0.45,
                      ),
                      width: 0.7,
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