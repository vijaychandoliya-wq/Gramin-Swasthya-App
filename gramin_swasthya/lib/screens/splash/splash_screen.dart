import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final String? language = prefs.getString('language');

    if (language != null && language.isNotEmpty) {
      context.go('/home');
    } else {
      context.go('/language');
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
                    // Simulated Logo (fallback since asset might not exist yet)
                    const Icon(
                      Icons.medical_services,
                      size: 120,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Gramin Swasthya',
                      style: textTheme.displaySmall?.copyWith( // Adjusted from displayLarge for better mobile fit
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
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
