import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_language.dart';
import 'router.dart';
import 'theme.dart';
import 'widgets/connectivity_wrapper.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Uncaught platform error: $error\n$stackTrace');
    return true;
  };
  await AppLanguage.initialize();

  // AlarmManager must be ready before any reminders are restored/scheduled.
  try {
    await AndroidAlarmManager.initialize();
  } catch (e, stackTrace) {
    debugPrint("AndroidAlarmManager initialization failed: $e\n$stackTrace");
  }

  // Do not crash the whole offline-first app if Firebase is unavailable or a
  // device has an incomplete Google Play Services installation.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stackTrace) {
    debugPrint("Firebase initialization failed: $e\n$stackTrace");
  }

  // Initialize Notification Service
  try {
    await NotificationService.init();
    await NotificationService.restoreActiveReminders();
  } catch (e) {
    debugPrint("NotificationService initialization skipped: $e");
  }

  runApp(
    const ProviderScope(
      child: GraminSwasthyaApp(),
    ),
  );
}

class GraminSwasthyaApp extends ConsumerWidget {
  const GraminSwasthyaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.current,
      builder: (context, languageCode, _) => MaterialApp.router(
        title: 'Gramin Swasthya',
        locale: AppLanguage.materialLocaleFor(languageCode),
        supportedLocales: AppLanguage.materialSupportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: GraminSwasthyaTheme.lightTheme,
        routerConfig: appRouter,
        builder: (context, child) {
          return ConnectivityWrapper(
            key: const ValueKey('connectivity_wrapper'),
            child: child ?? const SizedBox.shrink(),
          );
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
