// ===============================================
// Emie • Root App Widget
// Pfad: lib/app.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/session_store.dart';
import 'features/auth/controller/auth_controller.dart';
import 'features/auth/presentation/screens/auth_screen.dart';
import 'features/chat/controller/chat_controller.dart';

import 'core/localization/app_localizations.dart';

class EmieApp extends StatelessWidget {
  const EmieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SessionStore.instance),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ChatController()),
      ],
      child: Consumer<SessionStore>(
        builder: (context, session, _) {
          return MaterialApp(
            title: 'Emie',
            debugShowCheckedModeBanner: false,

            // ============================
            // Theme
            // ============================
            themeMode: session.flutterThemeMode,

            // ============================
            // Localization (Sprache)
            // ============================
            locale: session.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // ============================
            // Light Theme
            // ============================
            theme: ThemeData(
              brightness: Brightness.light,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFD37F),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF4F4F7),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF4F4F7),
                elevation: 0,
              ),
            ),

            // ============================
            // Dark Theme (Emie Black/Gold)
            // ============================
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFD37F),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF050307),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF050307),
                elevation: 0,
              ),
            ),

            home: const AuthScreen(),
          );
        },
      ),
    );
  }
}
