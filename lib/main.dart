// ===============================================
// Emie • main.dart
// Pfad: lib/main.dart
// ===============================================

import 'package:flutter/material.dart';

import 'app.dart';
import 'state/session_store.dart';
import 'core/config/env.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.localRequested && !kDebugMode) {
    throw StateError('EMIE_LOCAL requires a debug build.');
  }

  await SessionStore.instance.loadPreferences();

  runApp(const EmieApp());
}
