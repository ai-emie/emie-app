// ===============================================
// Emie • Typing Line
// Theme-aware Luxury Minimal Typing Indicator
// Pfad: lib/features/chat/presentation/widgets/emie_typing_line.dart
// ===============================================

import 'package:flutter/material.dart';

class EmieTypingLine extends StatefulWidget {
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
  State<EmieTypingLine> createState() =>
      _EmieTypingLineState();
}

class _EmieTypingLineState
    extends State<EmieTypingLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _gold(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return isDark
        ? const Color(0xFFFCF6BA)
        : const Color(0xFF8F6A18);
  }

  @override
  Widget build(BuildContext context) {
    final gold = _gold(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        2,
        18,
        2,
        18,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/emiso.logo.transparent.png',
            height: 16,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return Icon(
                Icons.auto_awesome_rounded,
                color: gold.withOpacity(0.72),
                size: 15,
              );
            },
          ),

          const SizedBox(width: 8),

          Text(
            'emie',
            style: TextStyle(
              color: gold.withOpacity(0.80),
              fontSize: 12.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
            ),
          ),

          const SizedBox(width: 12),

          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity:
                    0.35 +
                    (_controller.value * 0.65),
                child: Row(
                  children: [
                    _dot(gold, 0),
                    const SizedBox(width: 4),
                    _dot(gold, 1),
                    const SizedBox(width: 4),
                    _dot(gold, 2),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 10),

          Text(
            'schreibt...',
            style: TextStyle(
              color:
                  widget.textSecondary.withOpacity(
                0.72,
              ),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color gold, int index) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gold.withOpacity(
          0.45 + (index * 0.15),
        ),
      ),
    );
  }
}