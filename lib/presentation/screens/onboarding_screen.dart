import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive.dart';
import '../../data/datasources/preferences_storage.dart';
import '../providers/core_provider.dart';
import '../providers/preferences_provider.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String? _dobError;
  int? _estimatedAge;
  int? _estimatedMaxHr;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _dobController.addListener(_onDobChanged);
  }

  @override
  void dispose() {
    _dobController.removeListener(_onDobChanged);
    _nameController.dispose();
    _dobController.dispose();
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

  void _onDobChanged() {
    final text = _dobController.text.trim();
    if (text.isEmpty) {
      if (_dobError != null ||
          _estimatedMaxHr != null ||
          _estimatedAge != null) {
        setState(() {
          _dobError = null;
          _estimatedAge = null;
          _estimatedMaxHr = null;
        });
      }
      return;
    }

    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(text);
    if (match == null) {
      if (text.length >= 10 || !text.contains(RegExp(r'^[0-9\-]+$'))) {
        setState(() {
          _dobError = 'Enter birth date as YYYY-MM-DD';
          _estimatedAge = null;
          _estimatedMaxHr = null;
        });
      }
      return;
    }

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null ||
        month == null ||
        day == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      setState(() {
        _dobError = 'Enter a valid calendar date';
        _estimatedAge = null;
        _estimatedMaxHr = null;
      });
      return;
    }

    DateTime birthDate;
    try {
      birthDate = DateTime(year, month, day);
      if (birthDate.year != year ||
          birthDate.month != month ||
          birthDate.day != day) {
        setState(() {
          _dobError = 'Enter a valid calendar date';
          _estimatedAge = null;
          _estimatedMaxHr = null;
        });
        return;
      }
    } catch (_) {
      setState(() {
        _dobError = 'Enter a valid calendar date';
        _estimatedAge = null;
        _estimatedMaxHr = null;
      });
      return;
    }

    final now = DateTime.now();
    if (birthDate.isAfter(now)) {
      setState(() {
        _dobError = 'Birth date cannot be in the future';
        _estimatedAge = null;
        _estimatedMaxHr = null;
      });
      return;
    }

    final age = PreferencesStorage.calculateAge(birthDate, now);
    if (age < 5 || age > 120) {
      setState(() {
        _dobError = 'Age must be between 5 and 120 years';
        _estimatedAge = null;
        _estimatedMaxHr = null;
      });
      return;
    }

    final maxHr = PreferencesStorage.calculateTanakaMaxHr(age);
    setState(() {
      _dobError = null;
      _estimatedAge = age;
      _estimatedMaxHr = maxHr;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _estimatedAge != null
        ? DateTime(now.year - _estimatedAge!, now.month, now.day)
        : DateTime(now.year - 25, 1, 1);
    final firstDate = DateTime(now.year - 120, 1, 1);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _dobController.text = formatted;
    }
  }

  Future<void> _skipOnboarding() async {
    final storage = ref.read(preferencesStorageProvider);
    await storage.setCompletedOnboarding(true);

    ref.invalidate(athleteNameProvider);
    ref.invalidate(hrPreferencesNotifierProvider);
    ref.invalidate(hrPreferencesProvider);

    if (mounted) {
      context.go('/dashboard');
    }
  }

  Future<void> _completeSetup() async {
    final dobText = _dobController.text.trim();
    if (dobText.isEmpty) {
      setState(() {
        _dobError = 'Please enter or select your birth date';
      });
      return;
    }

    _onDobChanged();
    if (_dobError != null || _estimatedMaxHr == null) {
      return;
    }

    final rawName = _nameController.text.trim();
    final athleteName = rawName.isNotEmpty ? rawName : 'Runner';
    final maxHr = _estimatedMaxHr!;

    final storage = ref.read(preferencesStorageProvider);
    await storage.saveAthleteName(athleteName);
    await storage.saveDateOfBirth(dobText);
    await storage.saveMaxHr(maxHr);
    await storage.setCompletedOnboarding(true);

    ref.invalidate(athleteNameProvider);
    ref.invalidate(hrPreferencesNotifierProvider);
    ref.invalidate(hrPreferencesProvider);

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
            onPressed: _skipOnboarding,
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
                    _StepTwoDemographicView(
                      isDark: isDark,
                      nameController: _nameController,
                      dobController: _dobController,
                      dobError: _dobError,
                      estimatedAge: _estimatedAge,
                      estimatedMaxHr: _estimatedMaxHr,
                      onPickDate: () => _pickDate(context),
                      onBack: () => _goToStep(0),
                      onSkip: _skipOnboarding,
                      onComplete: _completeSetup,
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

/// Step 2: Demographic Setup view capturing Athlete Name and Birth Date,
/// previewing Tanaka Max HR in real time, and persisting physiological baselines.
class _StepTwoDemographicView extends StatelessWidget {
  final bool isDark;
  final TextEditingController nameController;
  final TextEditingController dobController;
  final String? dobError;
  final int? estimatedAge;
  final int? estimatedMaxHr;
  final VoidCallback onPickDate;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onComplete;

  const _StepTwoDemographicView({
    required this.isDark,
    required this.nameController,
    required this.dobController,
    required this.dobError,
    required this.estimatedAge,
    required this.estimatedMaxHr,
    required this.onPickDate,
    required this.onBack,
    required this.onSkip,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      key: const ValueKey('onboarding_step_2_content'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  key: const ValueKey('onboarding_step_2_placeholder'),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColors.brandOrange.withValues(alpha: 0.15)
                          : AppColors.brandOrangeTint,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 36,
                      color: AppColors.brandOrange,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'Athlete Profile Setup',
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
                  'Personalize your baseline profile to calculate your estimated maximum heart rate and target training zones.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.gray700,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space4),
                // Athlete Name Field
                TextField(
                  key: const ValueKey('athlete_name_input'),
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Athlete Name',
                    hintText: 'e.g. Alex, Budi',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                // Date of Birth Field with Date Picker
                TextField(
                  key: const ValueKey('dob_input'),
                  controller: dobController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: IconButton(
                      key: const ValueKey('dob_picker_button'),
                      icon: const Icon(Icons.calendar_month_rounded),
                      tooltip: 'Select birth date',
                      onPressed: onPickDate,
                    ),
                    errorText: dobError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                // Dynamic Tanaka Max HR Preview Card
                _TanakaMaxHrPreviewCard(
                  isDark: isDark,
                  estimatedAge: estimatedAge,
                  estimatedMaxHr: estimatedMaxHr,
                ),
                const SizedBox(height: AppSpacing.space2),
                // Informational Caption for Deferred Resting HR & Zones
                Container(
                  key: const ValueKey('resting_hr_caption'),
                  padding: const EdgeInsets.all(AppSpacing.space2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceTertiaryDark.withValues(alpha: 0.5)
                        : AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.gray700,
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: Text(
                          'Resting HR (defaults to 60 bpm) and custom heart rate zones are deferred to Settings to keep onboarding fast.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.gray700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Action Bar (Back, Skip, Complete Setup)
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
                  minimumSize: const Size(90, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              TextButton(
                key: const ValueKey('footer_skip_button'),
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
              const SizedBox(width: AppSpacing.space2),
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
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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

/// Dynamic Tanaka Max HR estimation card widget.
class _TanakaMaxHrPreviewCard extends StatelessWidget {
  final bool isDark;
  final int? estimatedAge;
  final int? estimatedMaxHr;

  const _TanakaMaxHrPreviewCard({
    required this.isDark,
    required this.estimatedAge,
    required this.estimatedMaxHr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('tanaka_preview_card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(
          color: isDark
              ? AppColors.brandOrange.withValues(alpha: 0.3)
              : AppColors.brandOrange.withValues(alpha: 0.25),
        ),
      ),
      color: isDark
          ? AppColors.brandOrange.withValues(alpha: 0.08)
          : AppColors.brandOrangeTint.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.brandOrange.withValues(alpha: 0.2)
                    : AppColors.brandOrangeTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.brandOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Max Heart Rate',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (estimatedMaxHr != null && estimatedAge != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$estimatedMaxHr bpm',
                          key: const ValueKey('tanaka_max_hr_text'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandOrange,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          '(Age $estimatedAge)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tanaka formula: 208 - (0.7 × $estimatedAge) = $estimatedMaxHr bpm',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.gray700,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '-- bpm',
                      key: const ValueKey('tanaka_max_hr_text'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.gray700,
                      ),
                    ),
                    Text(
                      'Enter birth date to estimate Max HR via Tanaka formula',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.gray700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
