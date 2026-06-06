// ==============================================
// Emie • Main Shell
// Theme-aware + Language-aware Floating Navigation
// Pfad: lib/features/main/presentation/screens/main_shell.dart
// ==============================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../state/session_store.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../memory/presentation/screens/memory_screen.dart';
import '../../../projects/presentation/screens/project_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() =>
      _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ChatScreen(),
    MemoryScreen(),
    ProjectScreen(),
    ProfileScreen(),
  ];

  void _onTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final c = _ShellColors(isDark: isDark);
    final t = _ShellText(session.language);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 24,
            child: _LuxuryBottomNav(
              selectedIndex: _selectedIndex,
              onTap: _onTap,
              colors: c,
              text: t,
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

class _ShellColors {
  const _ShellColors({
    required this.isDark,
  });

  final bool isDark;

  Color get bg => isDark
      ? const Color(0xFF050307)
      : const Color(0xFFF4F1EA);

  Color get navBg => isDark
      ? Colors.black.withOpacity(0.68)
      : const Color(0xFFFFFBF3).withOpacity(0.78);

  Color get gold => isDark
      ? const Color(0xFFBF953F)
      : const Color(0xFFB88922);

  Color get goldText => isDark
      ? const Color(0xFFFCF6BA)
      : const Color(0xFF8A6117);

  Color get inactive => isDark
      ? Colors.white38
      : const Color(0xFF736B5F).withOpacity(0.72);

  Color get shadow => isDark
      ? Colors.black.withOpacity(0.35)
      : Colors.black.withOpacity(0.10);

  Color get border => gold.withOpacity(isDark ? 0.12 : 0.20);

  Color get activeFill => gold.withOpacity(isDark ? 0.10 : 0.08);
}

// ==============================================
// TEXT
// ==============================================

class _ShellText {
  _ShellText(String code) : isDe = code == 'de';

  final bool isDe;

  String get overview => isDe ? 'Übersicht' : 'Overview';
  String get chat => 'Chat';
  String get memory => isDe ? 'Erinnerung' : 'Memory';
  String get projects => isDe ? 'Projekte' : 'Projects';
  String get profile => isDe ? 'Profil' : 'Profile';
}

// ==============================================
// LUXURY BOTTOM NAV
// ==============================================

class _LuxuryBottomNav extends StatelessWidget {
  const _LuxuryBottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.colors,
    required this.text,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final _ShellColors colors;
  final _ShellText text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: colors.navBg,
            border: Border.all(
              color: colors.border,
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 30,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: text.overview,
                active: selectedIndex == 0,
                colors: colors,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: text.chat,
                active: selectedIndex == 1,
                colors: colors,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.psychology_alt_outlined,
                label: text.memory,
                active: selectedIndex == 2,
                colors: colors,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.folder_outlined,
                label: text.projects,
                active: selectedIndex == 3,
                colors: colors,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: text.profile,
                active: selectedIndex == 4,
                colors: colors,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================
// NAV ITEM
// ==============================================

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final _ShellColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 64,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: active
              ? colors.activeFill
              : Colors.transparent,
          border: active
              ? Border.all(
                  color: colors.goldText.withOpacity(0.22),
                  width: 0.7,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.02 : 1,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: active
                    ? colors.goldText
                    : colors.inactive,
                size: 21,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active
                    ? colors.goldText
                    : colors.inactive,
                fontSize: 10.5,
                fontWeight:
                    active ? FontWeight.w500 : FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}