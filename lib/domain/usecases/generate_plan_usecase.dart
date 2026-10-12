import '../entities/return_context.dart';
import '../entities/activity.dart';
import '../entities/running_stats.dart';
import '../entities/training_plan.dart';
import 'segment_strategies/segment_plan_strategy.dart';
import 'segment_strategies/beginner_plan_strategy.dart';
import 'segment_strategies/intermediate_plan_strategy.dart';
import 'segment_strategies/advanced_plan_strategy.dart';
import 'segment_strategies/return_plan_strategy.dart';
import 'analyze_runs_usecase.dart';
import 'hr_zone_calculator.dart';
import 'pace_zone_calculator.dart';
import 'training_plan_config.dart';
import 'workout_descriptions.dart';
import 'workout_sequence_strategy.dart';

class GeneratePlanUseCase {
  final AnalyzeRunsUseCase _analyzeRuns;
  final TrainingPlanConfig config;
  final WorkoutSequenceStrategy sequenceStrategy;
  final WorkoutDescriptions descriptions;

  GeneratePlanUseCase({
    AnalyzeRunsUseCase? analyzeRuns,
    TrainingPlanConfig? config,
    WorkoutSequenceStrategy? sequenceStrategy,
    WorkoutDescriptions? descriptions,
  }) : _analyzeRuns = analyzeRuns ?? AnalyzeRunsUseCase(),
       config = config ?? TrainingPlanConfig.defaultConfig,
       sequenceStrategy =
           sequenceStrategy ?? const DynamicWorkoutSequenceStrategy(),
       descriptions = descriptions ?? const WorkoutDescriptions();

  TrainingPlan generate(
    List<Activity> activities, {
    int weekInCycle = -1,
    int? userMaxHr,
    int? userRestingHr,
    int? userThresholdPaceSeconds,
  }) {
    if (activities.isEmpty) return TrainingPlan.empty();

    final stats = _analyzeRuns.compute(
      activities,
      userMaxHr: userMaxHr,
      userRestingHr: userRestingHr,
      userThresholdPace: userThresholdPaceSeconds != null
          ? Duration(seconds: userThresholdPaceSeconds)
          : null,
      config: config,
    );
    final thresholdPace =
        userThresholdPaceSeconds ??
        PaceZoneCalculator.estimateThresholdPace(activities);
    final paceZones = PaceZoneCalculator.fromThresholdPace(thresholdPace);
    final hrZones = HrZoneCalculator.fromActivities(
      activities,
      restingHr: userRestingHr,
      maxHr: userMaxHr,
    );

    int effectiveWeekInCycle = weekInCycle;
    if (weekInCycle >= 0) {
      if (stats.recommendedPhase == CyclePhase.intermediate) {
        effectiveWeekInCycle = weekInCycle % 3;
      } else if (stats.recommendedPhase == CyclePhase.advanced) {
        effectiveWeekInCycle = weekInCycle % 4;
      }
    }

    SegmentPlanStrategy strategy;
    if (stats.returnContext != null && stats.returnContext!.isReturning) {
      if (stats.returnContext!.category == GapCategory.extended) {
        strategy = BeginnerPlanStrategy();
      } else {
        strategy = ReturnPlanStrategy();
      }
    } else if (stats.recommendedPhase == CyclePhase.beginner ||
        stats.recommendedPhase == CyclePhase.baseBuilding) {
      strategy = BeginnerPlanStrategy();
    } else if (stats.recommendedPhase == CyclePhase.intermediate) {
      strategy = IntermediatePlanStrategy();
    } else {
      strategy = AdvancedPlanStrategy();
    }

    double weeklyMinutesTarget = strategy.calculateTargetWeeklyMinutes(
      stats,
      effectiveWeekInCycle,
      config,
    );

    // 1. ACWR cap (<= 1.3 approx). Using 1.3x recent average.
    final maxWeeklyByAcwr = stats.recentWeeklyAvgMinutes * 1.3;
    if (maxWeeklyByAcwr > 0 && weeklyMinutesTarget > maxWeeklyByAcwr) {
      weeklyMinutesTarget = maxWeeklyByAcwr;
    }

    // 2. Weekly volume cap (+15%)
    final maxWeeklyByCap = stats.recentWeeklyAvgMinutes * 1.15;
    if (maxWeeklyByCap > 0 && weeklyMinutesTarget > maxWeeklyByCap) {
      weeklyMinutesTarget = maxWeeklyByCap;
    }

    // 3. Long run cap (+10%)
    double longRunTarget = weeklyMinutesTarget * config.longRunFraction;
    final maxLongRunByCap = stats.longestRecentRunMinutes * 1.10;
    if (maxLongRunByCap > 0 && longRunTarget > maxLongRunByCap) {
      longRunTarget = maxLongRunByCap;
    }

    // 4. Long run allocation (25-35% of final weekly total)
    if (weeklyMinutesTarget > 0) {
      final fraction = longRunTarget / weeklyMinutesTarget;
      if (fraction < 0.25) {
        longRunTarget = weeklyMinutesTarget * 0.25;
      } else if (fraction > 0.35) {
        longRunTarget = weeklyMinutesTarget * 0.35;
      }
    }

    final startDate = _startDate(activities);

    final sortedActivities = [...activities]
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentNonRest = sortedActivities
        .where((a) => a.movingTime.inMinutes >= config.minRunDuration)
        .toList();

    return TrainingPlan(
      startDate: startDate,
      goal: descriptions.goal(stats, weekInCycle: effectiveWeekInCycle),
      description: descriptions.planDescription(
        stats,
        weekInCycle: effectiveWeekInCycle,
      ),
      weekInCycle: effectiveWeekInCycle,
      cyclePhase: stats.recommendedPhase,
      days: strategy.buildWeek(
        finalWeeklyMinutes: weeklyMinutesTarget,
        longRunMinTarget: longRunTarget,
        startDate: startDate,
        stats: stats,
        recentActivities: recentNonRest,
        paceZones: paceZones,
        hrZones: hrZones,
        thresholdPace: thresholdPace,
        config: config,
        weekInCycle: effectiveWeekInCycle,
        descriptions: descriptions,
        sequenceStrategy: sequenceStrategy,
      ),
    );
  }

  DateTime _startDate(List<Activity> activities) {
    final today = DateTime.now();
    final hasRunToday = activities.any(
      (a) =>
          a.date.year == today.year &&
          a.date.month == today.month &&
          a.date.day == today.day,
    );
    if (!hasRunToday) return today;
    return today.add(const Duration(days: 1));
  }
}
