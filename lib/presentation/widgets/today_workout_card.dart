import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/training_plan_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'scale_on_press.dart';
import 'workout_type_badge.dart';

class TodayWorkoutCard extends ConsumerWidget {
  const TodayWorkoutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(trainingPlanProvider);

    return planAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (plan) {
        final today = DateTime.now();
        final day = plan.days
            .where(
              (d) =>
                  d.date.year == today.year &&
                  d.date.month == today.month &&
                  d.date.day == today.day,
            )
            .firstOrNull;

        if (day == null) return const SizedBox.shrink();

        final isRest = !day.canRecordRun;

        return ScaleOnPress(
          onTap: isRest
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  context.push('/run-session', extra: day);
                },
          child: Card(
            child: Semantics(
              button: !isRest,
              label: isRest
                  ? 'Rest day. No workout today.'
                  : 'Start today\'s workout: ${workoutTypeLabel(day.type)}',
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          workoutTypeIcon(day.type),
                          color: workoutTypeColor(day.type),
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text("Today's Workout", style: AppTypography.headingLg),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    Row(
                      children: [
                        WorkoutTypeBadge(type: day.type),
                        if (!isRest && day.targetMinutes != null) ...[
                          const SizedBox(width: AppSpacing.space2),
                          Text(
                            '${day.targetMinutes} min',
                            style: AppTypography.statValue.copyWith(
                              fontSize: 18,
                              color: workoutTypeColor(day.type),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (day.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space2),
                      Text(
                        day.description,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (!isRest) ...[
                      const SizedBox(height: AppSpacing.space3),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.push('/run-session', extra: day);
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Workout'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brandOrange,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
