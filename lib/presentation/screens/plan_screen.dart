import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive.dart';
import '../../domain/entities/training_plan.dart';
import '../providers/training_plan_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/scale_on_press.dart';
import '../widgets/workout_type_badge.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(trainingPlanProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            color: AppColors.brandOrange,
            tooltip: 'How your plan works',
            onPressed: () => _showInfoSheet(context),
          ),
        ],
      ),
      body: ConstrainedContent(
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _PlanErrorView(),
          data: (plan) => _PlanDataView(plan: plan),
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceTertiaryDark
                          : AppColors.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandOrange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: AppColors.brandOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'How Your Plan Works',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: Icons.history_rounded,
                  iconColor: AppColors.brandOrange,
                  title: 'Workout History Sync',
                  text:
                      'Your training plan is dynamically calibrated from your actual Strava running history and physical stats.',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.success,
                  title: 'Adaptive Calibration',
                  text:
                      'The plan updates automatically after each run you complete, adjusting targets based on your pace and heart rate.',
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  iconColor: AppColors.info,
                  title: 'Projected Schedules',
                  text:
                      'Your next workout is locked in based on current recovery. Future days are projections that refine as you train.',
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fade(duration: 250.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.gray700,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanErrorView extends StatelessWidget {
  const _PlanErrorView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Could not generate your training plan.\nPlease track some runs or review your settings.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PlanDataView extends StatelessWidget {
  final TrainingPlan plan;
  const _PlanDataView({required this.plan});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlanHeader(plan: plan),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: plan.days.length,
            itemBuilder: (context, i) {
              final isFirst = i == 0;
              final card = _PlanDayCard(day: plan.days[i], isFirst: isFirst);

              if (isFirst) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Next Workout',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.brandOrange,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    card,
                    if (plan.days.length > 1) ...[
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Upcoming',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Opacity(opacity: 0.65, child: card);
            },
          ),
        ),
      ],
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final TrainingPlan plan;

  const _PlanHeader({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phaseName = plan.cyclePhase.name;
    final formattedPhase =
        '${phaseName[0].toUpperCase()}${phaseName.substring(1).replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')} Phase';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.brandOrange, AppColors.brandOrangeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandOrange.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.track_changes_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        formattedPhase,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (plan.weekInCycle > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Week ${plan.weekInCycle}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Current Goal',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.goal,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDayCard extends StatelessWidget {
  final TrainingDay day;
  final bool isFirst;

  const _PlanDayCard({required this.day, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    final isRest = day.type == WorkoutType.rest;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isFirst
        ? AppColors.brandOrange
        : (isDark ? AppColors.surfaceTertiaryDark : AppColors.gray200);

    final cardWidget = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isFirst ? 1.5 : 1.0),
        boxShadow: isFirst
            ? [
                BoxShadow(
                  color: AppColors.brandOrange.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isFirst ? 12 : 8,
        ),
        leading: _DayIcon(type: day.type),
        title: _DayTitle(day: day, isFirst: isFirst),
        subtitle: _DaySubtitle(day: day, isRest: isRest),
        trailing: isRest ? null : const Icon(Icons.chevron_right),
      ),
    );

    if (isRest) {
      return cardWidget;
    }

    return ScaleOnPress(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/run-session', extra: day);
      },
      child: cardWidget,
    );
  }
}

class _DayIcon extends StatelessWidget {
  final WorkoutType type;
  const _DayIcon({required this.type});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: workoutTypeColor(type).withValues(alpha: 0.15),
      child: Icon(workoutTypeIcon(type), color: workoutTypeColor(type)),
    );
  }
}

class _DayTitle extends StatelessWidget {
  final TrainingDay day;
  final bool isFirst;
  const _DayTitle({required this.day, this.isFirst = false});
  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final label = days[day.date.weekday - 1];
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        WorkoutTypeBadge(type: day.type),
        if (!isFirst) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.gray300.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Projected',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.gray500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DaySubtitle extends StatelessWidget {
  final TrainingDay day;
  final bool isRest;
  const _DaySubtitle({required this.day, required this.isRest});

  @override
  Widget build(BuildContext context) {
    final paceTarget = day.paceTarget;
    final hrTarget = day.heartRateTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        if (!isRest && day.targetMinutes != null)
          Text(_buildDurationString(day)),
        if (paceTarget != null)
          Text(
            '${_paceStr(paceTarget.fastestPace)} - ${_paceStr(paceTarget.slowestPace)} /km',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        if (hrTarget != null)
          Text('♡ ${hrTarget.minBpm}-${hrTarget.maxBpm} bpm'),
        const SizedBox(height: 4),
        Text(day.description, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  String _buildDurationString(TrainingDay day) {
    if (day.warmUpMinutes == null || day.warmUpMinutes == 0) {
      return '${day.targetMinutes} min';
    }

    final warmup = '${day.warmUpMinutes}m warmup';
    final cooldown = '${day.coolDownMinutes ?? 0}m cooldown';

    String core;
    if (day.type == WorkoutType.intervals &&
        day.intervals != null &&
        day.intervals!.isNotEmpty) {
      final workDur = day.intervals!
          .firstWhere((i) => i.type == IntervalPhaseType.work)
          .duration;
      final recDur = day.intervals!
          .firstWhere((i) => i.type == IntervalPhaseType.recovery)
          .duration;
      final reps = day.intervals!.length ~/ 2;

      final workStr = workDur.inSeconds >= 60 && workDur.inSeconds % 60 == 0
          ? '${workDur.inMinutes}m'
          : '${workDur.inSeconds}s';
      final recStr = recDur.inSeconds >= 60 && recDur.inSeconds % 60 == 0
          ? '${recDur.inMinutes}m'
          : '${recDur.inSeconds}s';

      core = '${reps}x($workStr run / $recStr jog)';
    } else if (day.runWalkPhase != null && !day.runWalkPhase!.isContinuous) {
      final rwp = day.runWalkPhase!;
      final workStr = rwp.runSeconds >= 60 && rwp.runSeconds % 60 == 0
          ? '${rwp.runSeconds ~/ 60}m'
          : '${rwp.runSeconds}s';
      final walkStr = rwp.walkSeconds >= 60 && rwp.walkSeconds % 60 == 0
          ? '${rwp.walkSeconds ~/ 60}m'
          : '${rwp.walkSeconds}s';

      final workSec = (day.workMinutes ?? 0) * 60;
      final cycleSec = rwp.runSeconds + rwp.walkSeconds;
      if (cycleSec > 0) {
        final reps = (workSec - rwp.runSeconds) ~/ cycleSec;
        if (reps > 0) {
          core = '${reps}x($workStr run / $walkStr walk) + $workStr run';
        } else {
          core = '${day.workMinutes}m run';
        }
      } else {
        core = '${day.workMinutes}m run';
      }
    } else {
      core = '${day.workMinutes}m run';
    }

    return '$warmup + $core + $cooldown';
  }

  String _paceStr(Duration pace) {
    final m = pace.inSeconds ~/ 60;
    final s = pace.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
