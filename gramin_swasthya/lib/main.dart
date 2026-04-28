import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';
import 'providers/language_provider.dart';
import 'widgets/connectivity_wrapper.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
    final locale = ref.watch(languageProvider);
    return MaterialApp.router(
      title: 'Gramin Swasthya',
      theme: GraminSwasthyaTheme.lightTheme,
      routerConfig: appRouter,
      locale: locale,
      supportedLocales: const [Locale('hi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
