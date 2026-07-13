import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Trigger fade-in animation slightly after build
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // Wait for the animation to be enjoyable
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final language = prefs.getString('language');
    final user = await AuthService.instance.restoredUser();
    if (!mounted) return;

    if (!onboardingDone) {
      context.go('/onboarding');
    } else if (language == null || language.isEmpty) {
      context.go('/language');
    } else if (user == null ||
        prefs.getString('account_setup_complete_uid') != user.uid) {
      context.go('/google-sign-in');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _opacity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Actual Brand Logo
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      height: 120,
                      width: 120,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 24),
                    LocalizedText(
                      'Gramin Swasthya',
                      style: textTheme.displaySmall?.copyWith(
                        // Adjusted from displayLarge for better mobile fit
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    LocalizedText(
                      'ग्रामीण स्वास्थ्य',
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 32,
              left: 32,
              right: 32,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _opacity,
                child: LinearProgressIndicator(
                  color: colorScheme.onPrimary,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
