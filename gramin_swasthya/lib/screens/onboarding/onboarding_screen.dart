import 'package:flutter/material.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage && mounted) {
        setState(() {
          _currentPage = page;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      context.go('/language');
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Remove the onboarding subtree before routing so its PageView/text cannot
    // paint through a destination during the transition animation.
    if (_isCompleting) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _pageController,
            itemCount: 3,
            itemBuilder: (context, index) {
              return _OnboardingPage(
                pageData: _pages[index],
              );
            },
          ),

          // Skip Button
          if (_currentPage < 2)
            Positioned(
              top: 48,
              right: 16,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const LocalizedText('छोड़ें / Skip',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SmoothPageIndicator(
                  controller: _pageController,
                  count: 3,
                  effect: WormEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    dotColor: colorScheme.outline.withOpacity(0.5),
                    activeDotColor: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _currentPage < 2 ? _nextPage : _completeOnboarding,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: LocalizedText(_currentPage < 2
                      ? 'आगे / Next'
                      : 'शुरू करें / Get Started'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final List<_PageData> _pages = const [
    _PageData(
      gradientColors: [Color(0xFFE8D5FF), Color(0xFFF3EEFF)],
      title: 'परिवार का स्वास्थ्य रिकॉर्ड',
      body: 'एक ही जगह सभी मेडिकल जानकारी',
      imagePath: 'assets/images/onboarding_family.png',
    ),
    _PageData(
      gradientColors: [Color(0xFFD5EEE0), Color(0xFFEFF8F3)],
      title: 'रोज़ाना BP और शुगर ट्रैक करें',
      body: 'ग्राफ देखें, ट्रेंड समझें',
      imagePath: 'assets/images/onboarding_health.png',
    ),
    _PageData(
      gradientColors: [Color(0xFFD5E5FF), Color(0xFFEEF3FF)],
      title: 'Google से एक बार साइन इन करें',
      body: 'आपकी पहली प्रोफ़ाइल अपने आप बनेगी और यह फ़ोन आपका खाता याद रखेगा',
      imagePath: 'assets/images/onboarding_doctor.png',
    ),
  ];
}

class _PageData {
  final List<Color> gradientColors;
  final String title;
  final String body;
  final String imagePath;

  const _PageData({
    required this.gradientColors,
    required this.title,
    required this.body,
    required this.imagePath,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _PageData pageData;

  const _OnboardingPage({required this.pageData});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: pageData.gradientColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use an errorBuilder so it doesn't crash if files are empty placeholders
              Image.asset(
                pageData.imagePath,
                height: 300,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Icon(Icons.image,
                          size: 64, color: colorScheme.primary),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              LocalizedText(
                pageData.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LocalizedText(
                pageData.body,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 100), // Space for bottom controls
            ],
          ),
        ),
      ),
    );
  }
}
