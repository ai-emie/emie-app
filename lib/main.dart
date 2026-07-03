// ===============================================
// Emie • main.dart
// Pfad: lib/main.dart
// ===============================================

import 'package:flutter/material.dart';

import 'app.dart';
import 'state/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SessionStore.instance.restoreSession();

  runApp(const EmieApp());
}