// ===============================================
// Emie • Projects Screen (Stub / Beta v1)
// Pfad: lib/features/projects/presentation/screens/projects_screen.dart
// ===============================================

import 'package:flutter/material.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E0E) : const Color(0xFFFFFFFF);
    final textSecondary = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF5A5A5A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Projekte'),
      ),
      body: Center(
        child: Text(
          'Projekte kommen in Beta v1.\nHier entstehen Workspaces für Ziele & Langzeitpläne.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, height: 1.4),
        ),
      ),
    );
  }
}
