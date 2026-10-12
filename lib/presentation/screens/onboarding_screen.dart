import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive.dart';
import '../providers/core_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Two-step onboarding flow screen shown exclusively on first launch.
///
/// Step 1: Welcome & Value Orientation (Offline-First Tracking, Autonomous Analytics, Adaptive Plans).
/// Step 2: Demographic Setup (Name, Age, Tanaka Max HR Estimation).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await ref.read(preferencesStorageProvider).setCompletedOnboarding(true);
    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teman Lari'),
        leading: _currentStep > 0
            ? IconButton(
                key: const ValueKey('onboarding_appbar_back_button'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goToStep(_currentStep - 1),
              )
            : null,
        actions: [
          TextButton(
            key: const ValueKey('skip_onboarding_button'),
            onPressed: _completeOnboarding,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedContent(
          maxWidth: 600,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space6,
                  vertical: AppSpacing.space2,
                ),
                child: _StepProgressIndicator(
                  currentStep: _currentStep,
                  totalSteps: 2,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentStep = page),
                  children: [
                    _StepOneWelcomeView(
                      isDark: isDark,
                      onGetStarted: () => _goToStep(1),
                    ),
                    _StepTwoPlaceholderView(
                      isDark: isDark,
                      onBack: () => _goToStep(0),
                      onComplete: _completeOnboarding,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visual step progress indicator with animated dots and step text.
class _StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isDark;

  const _StepProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          key: const ValueKey('step_indicator_dots'),
          children: List.generate(totalSteps, (index) {
            final isActive = index == currentStep;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
              width: isActive ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.brandOrange
                    : (isDark
                          ? AppColors.surfaceTertiaryDark
                          : AppColors.gray300),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          'Step ${currentStep + 1} of $totalSteps',
          key: const ValueKey('step_indicator_text'),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Step 1: Welcome & Value Orientation view presenting the core value cards.
class _StepOneWelcomeView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onGetStarted;

  const _StepOneWelcomeView({required this.isDark, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppColors.brandOrange.withValues(alpha: 0.15)
                        : AppColors.brandOrangeTint,
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    size: 38,
                    color: AppColors.brandOrange,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                Text(
                  'Welcome to Teman Lari',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.gray900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'Your offline-first running companion built for movement, data-driven insights, and personal growth.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.gray700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space4),
                const _ValuePropositionCard(
                  key: ValueKey('value_card_offline_tracking'),
                  icon: Icons.sensors_rounded,
                  title: 'Offline-First Tracking',
                  description:
                      'Permanent zero-TTL local database. Track runs anywhere with GPS and sensors without internet connectivity.',
                ),
                const SizedBox(height: AppSpacing.space2),
                const _ValuePropositionCard(
                  key: ValueKey('value_card_analytics'),
                  icon: Icons.insights_rounded,
                  title: 'Autonomous On-Device Analytics',
                  description:
                      'On-device physiological engine computing ATL (Fatigue), CTL (Fitness), and TSB (Form) kept 100% private.',
                ),
                const SizedBox(height: AppSpacing.space2),
                const _ValuePropositionCard(
                  key: ValueKey('value_card_plans'),
                  icon: Icons.calendar_month_rounded,
                  title: 'Adaptive Plan Generation',
                  description:
                      'Dynamic periodized training schedules that adjust directly to runner workload and fitness level.',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space6,
            vertical: AppSpacing.space3,
          ),
          child: FilledButton.icon(
            key: const ValueKey('get_started_button'),
            onPressed: onGetStarted,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Get Started'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card component presenting a single core value proposition.
class _ValuePropositionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ValuePropositionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(
          color: isDark
              ? AppColors.dividerDark
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: isDark ? AppColors.surfaceSecondaryDark : AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.brandOrange.withValues(alpha: 0.15)
                    : AppColors.brandOrangeTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: AppColors.brandOrange, size: 22),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.gray700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder view for Step 2 (Demographic Setup).
class _StepTwoPlaceholderView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const _StepTwoPlaceholderView({
    required this.isDark,
    required this.onBack,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('onboarding_step_2_placeholder'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppColors.brandOrange.withValues(alpha: 0.15)
                        : AppColors.brandOrangeTint,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 38,
                    color: AppColors.brandOrange,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                Text(
                  'Athlete Profile Setup',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.gray900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'Personalize your baseline profile to calculate your estimated maximum heart rate and target training zones.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.gray700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space6,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('onboarding_back_button'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('complete_onboarding_button'),
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Complete Setup'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
