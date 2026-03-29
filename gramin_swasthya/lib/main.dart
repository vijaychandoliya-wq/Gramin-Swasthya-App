import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';
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
    return MaterialApp.router(
      title: 'Gramin Swasthya',
      theme: GraminSwasthyaTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
