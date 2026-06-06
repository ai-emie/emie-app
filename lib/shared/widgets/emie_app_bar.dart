// ==============================================
// Emie • Shared App Bar
// Theme-aware Luxury Minimal Header
// Pfad: lib/shared/widgets/emie_app_bar.dart
// ==============================================

import 'package:flutter/material.dart';

class EmieAppBar extends StatelessWidget {
  const EmieAppBar({
    super.key,
    required this.section,
    required this.icon,
    required this.onIconTap,
    this.badgeText,
  });

  final String section;
  final IconData icon;
  final VoidCallback onIconTap;
  final String? badgeText;

  static const String _logoAsset =
      'assets/images/emiso.logo.transparent.png';

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final c = _AppBarColors(isDark: isDark);

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Image.asset(
            _logoAsset,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.auto_awesome_rounded,
              color: c.gold.withOpacity(0.82),
              size: 22,
            ),
          ),

          const SizedBox(width: 10),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'emie',
                style: TextStyle(
                  color: c.gold.withOpacity(0.94),
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.2,
                  fontFamily: 'Inter',
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section,
                style: TextStyle(
                  color: c.muted.withOpacity(0.88),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.2,
                  fontFamily: 'Inter',
                  height: 1.0,
                ),
              ),
            ],
          ),

          const Spacer(),

          GestureDetector(
            onTap: onIconTap,
            behavior: HitTestBehavior.opaque,
            child: badgeText == null
                ? _IconAction(
                    icon: icon,
                    colors: c,
                  )
                : _BadgeAction(
                    text: badgeText!,
                    colors: c,
                  ),
          ),
        ],
      ),
    );
  }
}

// ==============================================
// COLORS
// ==============================================

class _AppBarColors {
  const _AppBarColors({
    required this.isDark,
  });

  final bool isDark;

  Color get gold => isDark
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get goldSoft => isDark
      ? const Color(0xFFBF953F)
      : const Color(0xFFB88922);

  Color get muted => isDark
      ? const Color(0xFF8E8B85)
      : const Color(0xFF736B5F);

  Color get actionFill => isDark
      ? Colors.white.withOpacity(0.025)
      : Colors.white.withOpacity(0.48);

  Color get actionBorder => gold.withOpacity(
        isDark ? 0.18 : 0.24,
      );
}

// ==============================================
// ICON ACTION
// ==============================================

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.colors,
  });

  final IconData icon;
  final _AppBarColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.actionFill,
        border: Border.all(
          color: colors.actionBorder,
          width: 0.7,
        ),
      ),
      child: Icon(
        icon,
        color: colors.gold.withOpacity(0.78),
        size: 20,
      ),
    );
  }
}

// ==============================================
// BADGE ACTION
// ==============================================

class _BadgeAction extends StatelessWidget {
  const _BadgeAction({
    required this.text,
    required this.colors,
  });

  final String text;
  final _AppBarColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.goldSoft.withOpacity(
          colors.isDark ? 0.10 : 0.08,
        ),
        border: Border.all(
          color: colors.actionBorder,
          width: 0.7,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: colors.gold.withOpacity(0.90),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}