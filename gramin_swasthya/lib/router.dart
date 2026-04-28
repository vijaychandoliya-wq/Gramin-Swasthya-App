import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gramin_swasthya/screens/medicines/add_medicine_screen.dart';
import 'package:gramin_swasthya/screens/reports/add_report_screen.dart';
import 'package:gramin_swasthya/screens/reports/report_viewer_screen.dart';

import 'screens/home/home_screen.dart';
import 'screens/health/health_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/medicines/medicines_screen.dart';
import 'screens/settings/settings_screen.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/language_select_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/pin_login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/health/add_bp_screen.dart';
import 'screens/health/add_sugar_screen.dart';
import 'screens/health/add_weight_screen.dart';
import 'screens/sharing/share_screen.dart';
import 'screens/sharing/qr_screen.dart';
import 'screens/emergency/emergency_card_screen.dart';
import 'screens/family/family_screen.dart';
import 'screens/family/add_member_screen.dart';
import 'providers/reports_provider.dart';
import 'providers/medicines_provider.dart';
import 'providers/family_provider.dart';

// Root Navigator Key
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/health',
          builder: (context, state) => const HealthScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/medicines',
          builder: (context, state) => const MedicinesScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    // Auth Routes
    GoRoute(
      path: '/splash',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/language',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LanguageSelectScreen(),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RegistrationScreen(),
    ),
    GoRoute(
      path: '/pin-setup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PinLoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Modal Routes (Outside Shell for full screen or bottom sheets)
    GoRoute(
      path: '/add-bp',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddBpScreen(),
    ),
    GoRoute(
      path: '/add-sugar',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddSugarScreen(),
    ),
    GoRoute(
      path: '/add-weight',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddWeightScreen(),
    ),
    GoRoute(
      path: '/reports/add',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddReportScreen(),
    ),
    GoRoute(
      path: '/reports/view/:reportId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        // We'll pass the report object via extra for now,
        // but the path reflects the hierarchy.
        final report = state.extra as MedicalReport;
        return ReportViewerScreen(report: report);
      },
    ),
    GoRoute(
      path: '/add-medicine',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final medicine = state.extra as Medicine?;
        return AddMedicineScreen(medicine: medicine);
      },
    ),
    // Emergency & Sharing Routes
    GoRoute(
      path: '/doctor-sharing',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ShareScreen(),
    ),
    GoRoute(
      path: '/share/qr',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final tokenId = state.extra as String;
        return QRScreen(tokenId: tokenId);
      },
    ),
    GoRoute(
      path: '/emergency-card',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EmergencyCardScreen(),
    ),
    GoRoute(
      path: '/family',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FamilyScreen(),
    ),
    GoRoute(
      path: '/add-family-member',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final member = state.extra as FamilyMember?;
        return AddMemberScreen(member: member);
      },
    ),
  ],
);

// Helper for the persistent NavigationBar
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (int idx) => _onItemTapped(idx, context),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'Health'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'Meds'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/health')) return 1;
    if (location.startsWith('/reports')) return 2;
    if (location.startsWith('/medicines')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/health');
        break;
      case 2:
        context.go('/reports');
        break;
      case 3:
        context.go('/medicines');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }
}

// Temporary Placeholder
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Placeholder for $title')),
    );
  }
}
