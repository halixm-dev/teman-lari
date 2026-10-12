import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/core_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    await ref.read(preferencesStorageProvider).setCompletedOnboarding(true);
    if (context.mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teman Lari'),
        actions: [
          TextButton(
            key: const ValueKey('skip_onboarding_button'),
            onPressed: () => _completeOnboarding(context, ref),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_run_rounded,
                    size: 72,
                    color: AppColors.brandOrange,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'Welcome to Teman Lari',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    'Your offline-first running companion with autonomous training load analytics and adaptive plan generation.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  FilledButton.icon(
                    key: const ValueKey('complete_onboarding_button'),
                    onPressed: () => _completeOnboarding(context, ref),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Get Started'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
