import 'package:flutter/material.dart';
import 'package:swara/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

// Storage key marking that onboarding was completed or skipped.
const String kOnboardingDoneKey = 'onboarding_done';

// Simple data holder for one onboarding page.
class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

// First launch onboarding with 3 swipeable pages.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  // Blocks double taps on Skip and Get Started while finishing.
  bool _finishing = false;

  // Pages are built per locale so titles follow the selected language.
  static const int _pageCount = 3;

  static List<_OnboardingPageData> _pagesOf(AppLocalizations l10n) => [
        _OnboardingPageData(
          icon: Icons.library_music_outlined,
          title: l10n.onboardTitle1,
          description: l10n.onboardDesc1,
        ),
        _OnboardingPageData(
          icon: Icons.auto_awesome_outlined,
          title: l10n.onboardTitle2,
          description: l10n.onboardDesc2,
        ),
        _OnboardingPageData(
          icon: Icons.play_circle_outline,
          title: l10n.onboardTitle3,
          description: l10n.onboardDesc3,
        ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Mark onboarding as done then open the home screen.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingDoneKey, true);
    } catch (e) {
      // Ignore persistence errors so the user can still enter the app.
      debugPrint('Failed to save onboarding flag: $e');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _next() {
    if (_index < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = _pagesOf(l10n);
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _index == pages.length - 1;

    // Back press exits without persisting, by design.
    return PopScope(
      canPop: true,
      child: Scaffold(
      appBar: AppBar(
        actions: [
          // Skip stays visible on every page except the last one.
          if (!isLast)
            TextButton(
              onPressed: _finish,
              child: Text(l10n.onboardSkip),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 56,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Page indicator dots.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _index == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _index == i
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child:
                      Text(isLast ? l10n.onboardGetStarted : l10n.onboardNext),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }
}
