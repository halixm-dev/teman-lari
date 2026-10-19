import '../../entities/activity.dart';
import '../../entities/running_stats.dart';
import '../../entities/training_plan.dart';
import '../training_plan_config.dart';
import '../workout_descriptions.dart';
import '../workout_sequence_strategy.dart';
import '../schedule_constraints.dart';
import '../rehab_week_planner.dart';
import 'segment_plan_strategy.dart';

class ReturnPlanStrategy extends SegmentPlanStrategy {
  @override
  double calculateTargetWeeklyMinutes(
    RunningStats stats,
    int weekInCycle,
    TrainingPlanConfig config,
  ) {
    final returnCtx = stats.returnContext;
    final rehab = returnCtx?.rehabilitation;
    if (rehab != null) return rehab.weeklyMinutes;
    if (returnCtx == null || !returnCtx.isReturning) {
      return config.minWeeklyMinutes; // Fallback
    }

    final volume = returnCtx.startVolumeFraction * returnCtx.preGapAvgMin;
    return volume.clamp(config.minWeeklyMinutes, config.maxWeeklyMinutes);
  }

  @override
  List<TrainingDay> buildWeek({
    required double finalWeeklyMinutes,
    required double longRunMinTarget,
    required DateTime startDate,
    required RunningStats stats,
    required List<Activity> recentActivities,
    required List<PaceZone> paceZones,
    required List<HrZone> hrZones,
    required int thresholdPace,
    required TrainingPlanConfig config,
    required int weekInCycle,
    required WorkoutDescriptions descriptions,
    required WorkoutSequenceStrategy sequenceStrategy,
  }) {
    // Current design always uses rampWeek 1 (easy-only)
    final sequence = sequenceStrategy.determineSequence(
      constraints: ScheduleConstraints.returnRampEasy,
      stats: stats,
      config: config,
      recentActivities: recentActivities,
      weekInCycle: weekInCycle,
    );

    final easyMin = (finalWeeklyMinutes * config.easyFraction).round();
    final rehab = stats.returnContext?.rehabilitation;
    if (rehab != null) {
      return RehabWeekPlanner().build(
        progress: rehab,
        weeklyMinutes: finalWeeklyMinutes,
        startDate: startDate,
        sequence: sequence,
        pace: paceZones[1],
        heartRate: hrZones[1],
      );
    }

    return List.generate(7, (i) {
      final date = startDate.add(Duration(days: i));
      final type = sequence[i];

      switch (type) {
        case WorkoutType.easy:
        case WorkoutType.longRun: // Fallback just in case
        case WorkoutType.intervals:
        case WorkoutType.tempo:
          final effective = easyMin.clamp(config.minEasyRunMinutes, 9999);
          return TrainingDay(
            date: date,
            type: WorkoutType.easy,
            targetMinutes: effective,
            paceTarget: paceZones[1],
            heartRateTarget: hrZones[1],
            estimatedDuration: Duration(minutes: effective),
            description: descriptions.easy(),
          );

        case WorkoutType.rest:
          return TrainingDay(
            date: date,
            type: WorkoutType.rest,
            description: descriptions.rest(),
          );

        case WorkoutType.crossTraining:
          return TrainingDay(
            date: date,
            type: WorkoutType.crossTraining,
            description: descriptions.crossTraining(),
          );

        case WorkoutType.walk:
          return TrainingDay(
            date: date,
            type: WorkoutType.walk,
            description: descriptions.easy(),
          );
      }
    });
  }
}
