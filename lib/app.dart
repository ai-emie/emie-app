// ===============================================
// Emie • Root App Widget
// Pfad: lib/app.dart
// ===============================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

// ===============================================
// INTERNAL IMPORTS
// ===============================================

import 'state/session_store.dart';

import 'features/auth/controller/auth_controller.dart';
import 'features/auth/presentation/screens/auth_screen.dart';

import 'features/chat/controller/chat_controller.dart';

import 'features/main/presentation/screens/main_shell.dart';

import 'core/localization/app_localizations.dart';

// ===============================================
// APP
// ===============================================

class EmieApp extends StatelessWidget {
  const EmieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [

        // =====================================
        // SESSION STORE
        // =====================================

        ChangeNotifierProvider<SessionStore>.value(
          value: SessionStore.instance,
        ),

        // =====================================
        // AUTH
        // =====================================

        ChangeNotifierProvider<AuthController>(
          lazy: false,
          create: (_) {
            final controller = AuthController();

            Future.microtask(
              controller.bootstrapSession,
            );

            return controller;
          },
        ),

        // =====================================
        // CHAT
        // =====================================

        ChangeNotifierProvider<ChatController>(
          create: (_) => ChatController(),
        ),
      ],

      child: Consumer<SessionStore>(
        builder: (context, session, _) {
          return MaterialApp(
            title: 'Emie',

            debugShowCheckedModeBanner: false,

            // =================================
            // LOCALIZATION
            // =================================

            locale: session.locale,

            supportedLocales:
                AppLocalizations.supportedLocales,

            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // =================================
            // THEME MODE
            // =================================

            themeMode: session.flutterThemeMode,

            // =================================
            // LIGHT THEME
            // =================================

            theme: ThemeData(
              brightness: Brightness.light,

              useMaterial3: true,

              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFD37F),
                brightness: Brightness.light,
              ),

              scaffoldBackgroundColor:
                  const Color(0xFFF4F4F7),

              appBarTheme: const AppBarTheme(
                backgroundColor:
                    Color(0xFFF4F4F7),

                elevation: 0,
              ),
            ),

            // =================================
            // DARK THEME
            // =================================

            darkTheme: ThemeData(
              brightness: Brightness.dark,

              useMaterial3: true,

              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFD37F),
                brightness: Brightness.dark,
              ),

              scaffoldBackgroundColor:
                  const Color(0xFF050307),

              appBarTheme: const AppBarTheme(
                backgroundColor:
                    Color(0xFF050307),

                elevation: 0,
              ),
            ),

            // =================================
            // START SCREEN
            // =================================

            home: session.isBootstrapping
                ? const _BootstrapScreen()
                : session.isAuthenticated &&
                        session.user != null
                    ? const MainShell()
                    : const AuthScreen(),
          );
        },
      ),
    );
  }
}

// ===============================================
// BOOTSTRAP / LOADING SCREEN
// ===============================================

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}