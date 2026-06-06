// ===============================================
// Emie • Chat Input Bar
// Theme-aware Luxury Minimal Chat Input
// Pfad: lib/features/chat/presentation/widgets/chat_input_bar.dart
// ===============================================

import 'dart:ui';

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
    this.attachHintText =
        'Anhänge sind aktuell nicht verfügbar.',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(String msg) onSnack;

  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color bg;

  final String hintText;
  final String attachHintText;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final gold = isDark
        ? const Color(0xFFFCF6BA)
        : const Color(0xFF8F6A18);

    final amber = isDark
        ? const Color(0xFFFFC96B)
        : const Color(0xFFB88922);

    final overlay = isDark
        ? Colors.black.withOpacity(0.52)
        : const Color(0xFFFFFBF3).withOpacity(0.72);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            14,
            10,
            14,
            10,
          ),
          decoration: BoxDecoration(
            color: overlay,
            border: Border(
              top: BorderSide(
                color: gold.withOpacity(
                  isDark ? 0.10 : 0.18,
                ),
                width: 0.7,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              // =================================
              // ATTACH BUTTON
              // =================================

              GestureDetector(
                onTap: () =>
                    onSnack(attachHintText),
                behavior:
                    HitTestBehavior.opaque,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        surface.withOpacity(0.96),
                    border: Border.all(
                      color: gold.withOpacity(
                        isDark ? 0.12 : 0.18,
                      ),
                      width: 0.7,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color:
                        textSecondary.withOpacity(
                      0.92,
                    ),
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // =================================
              // TEXT FIELD
              // =================================

              Expanded(
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minHeight: 42,
                  ),
                  decoration: BoxDecoration(
                    color:
                        surface.withOpacity(0.98),
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    border: Border.all(
                      color: gold.withOpacity(
                        isDark ? 0.12 : 0.18,
                      ),
                      width: 0.7,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType:
                        TextInputType.multiline,
                    textInputAction:
                        TextInputAction.newline,
                    style: TextStyle(
                      color:
                          textPrimary.withOpacity(
                        0.96,
                      ),
                      fontSize: 14.5,
                      height: 1.35,
                      fontFamily: 'Inter',
                    ),
                    decoration:
                        InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color:
                            textSecondary
                                .withOpacity(
                          0.72,
                        ),
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.fromLTRB(
                        15,
                        13,
                        15,
                        12,
                      ),
                    ),
                    onSubmitted: (_) =>
                        onSend(),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // =================================
              // SEND BUTTON
              // =================================

              GestureDetector(
                onTap: onSend,
                behavior:
                    HitTestBehavior.opaque,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        gold.withOpacity(0.90),
                    boxShadow: [
                      BoxShadow(
                        color: amber.withOpacity(
                          isDark ? 0.14 : 0.12,
                        ),
                        blurRadius: 22,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: isDark
                        ? Colors.black
                        : Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}