import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/entities/running_stats.dart';
import 'package:teman_lari/domain/entities/return_context.dart';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/domain/usecases/analyze_runs_usecase.dart';
import 'package:teman_lari/domain/usecases/generate_plan_usecase.dart';
import 'package:teman_lari/domain/usecases/pace_zone_calculator.dart';
import 'package:teman_lari/domain/usecases/schedule_constraints.dart';
import 'package:teman_lari/domain/usecases/training_plan_config.dart';
import 'package:teman_lari/domain/usecases/workout_descriptions.dart';
import 'package:teman_lari/domain/usecases/workout_sequence_strategy.dart';

class _CustomDescriptions extends WorkoutDescriptions {
  const _CustomDescriptions();

  @override
  String easy() => 'Custom easy run';

  @override
  String longRun(int durationMinutes) => 'Custom long run';

  @override
  String rest() => 'Custom rest';
}

class _AllEasyStrategy implements WorkoutSequenceStrategy {
  const _AllEasyStrategy();

  @override
  List<WorkoutType> determineSequence({
    required ScheduleConstraints constraints,
    required RunningStats stats,
    required TrainingPlanConfig config,
    required List<Activity> recentActivities,
    required int weekInCycle,
  }) => List.filled(7, WorkoutType.easy);
}

class _MockAnalyzeRuns extends AnalyzeRunsUseCase {
  RunningStats? stats;

  @override
  RunningStats compute(
    List<Activity> activities, {
    int? userMaxHr,
    int? userRestingHr,
    Duration? userThresholdPace,
    TrainingPlanConfig? config,
    ReturnContext? returnContextOverride,
  }) {
    return stats ??
        super.compute(activities, returnContextOverride: returnContextOverride);
  }
}

RunningStats _stats({
  int totalRuns = 0,
  double totalDistanceKm = 0,
  Map<String, double> weeklyVolume = const {},
  Map<String, double> weeklyMinutes = const {},
  double fitnessScore = 0,
  double fatigueScore = 0,
  double formScore = 0,
  CyclePhase recommendedPhase = CyclePhase.intermediate,
}) {
  return RunningStats(
    totalRuns: totalRuns,
    totalDistanceKm: totalDistanceKm,
    weeklyVolume: weeklyVolume,
    weeklyMinutes: weeklyMinutes,
    averagePace: Duration.zero,
    paceProgression: [],
    heartRateZones: {},
    trainingLoadHistory: [],
    vo2MaxEstimate: null,
    fitnessScore: fitnessScore,
    fatigueScore: fatigueScore,
    formScore: formScore,
    recommendedPhase: recommendedPhase,
  );
}

Activity _activity({
  int daysAgo = 1,
  int minutes = 30,
  int paceSecPerKm = 300,
  double? avgHr,
  double? maxHr,
  int id = 0,
  TrainingLoad load = TrainingLoad.easy,
}) {
  return Activity(
    type: ActivityType.run,
    id: id,
    name: 'Run $id',
    date: DateTime.now().subtract(Duration(days: daysAgo)),
    distanceKm: minutes * 60.0 / paceSecPerKm,
    movingTime: Duration(minutes: minutes),
    pace: Duration(seconds: paceSecPerKm),
    elevationGainM: 0,
    trainingLoad: load,
    avgHeartRate: avgHr,
    maxHeartRate: maxHr,
  );
}

void main() {
  late _MockAnalyzeRuns mockAnalyze;
  late GeneratePlanUseCase useCase;

  setUp(() {
    mockAnalyze = _MockAnalyzeRuns();
    useCase = GeneratePlanUseCase(analyzeRuns: mockAnalyze);
  });

  group('empty activities', () {
    test('returns TrainingPlan.empty()', () {
      final plan = useCase.generate([]);
      check(plan.days).isEmpty();
      expect(plan.goal, 'No data available');
      expect(
        plan.description,
        'Track or log runs to generate your personalized training plan.',
      );
    });
  });

  group('generate() with mocked stats', () {
    setUp(() {
      mockAnalyze.stats = _stats(
        totalRuns: 25,
        totalDistanceKm: 120,
        weeklyVolume: {'2026-01-01': 30, '2026-01-05': 35},
        weeklyMinutes: {'2026-01-01': 240, '2026-01-05': 280},
        fitnessScore: 35,
        fatigueScore: 25,
        formScore: 10,
      );
    });

    test('returns 7-day plan', () {
      final activities = [_activity(daysAgo: 1)];
      final plan = useCase.generate(activities);
      check(plan.days.length).equals(7);
    });

    test('each day has sequential dates', () {
      final activities = [_activity(daysAgo: 1)];
      final plan = useCase.generate(activities);
      for (int i = 0; i < 7; i++) {
        check(plan.days[i].date.difference(plan.startDate).inDays).equals(i);
      }
    });

    test('non-rest days have pace, HR targets and duration', () {
      final activities = [_activity(daysAgo: 1)];
      final plan = useCase.generate(activities);
      for (final day in plan.days) {
        if (day.type != WorkoutType.rest &&
            day.type != WorkoutType.crossTraining) {
          expect(
            day.paceTarget,
            isNotNull,
            reason: '${day.type} should have pace target',
          );
          expect(
            day.heartRateTarget,
            isNotNull,
            reason: '${day.type} should have HR target',
          );
          expect(
            day.targetMinutes,
            isNotNull,
            reason: '${day.type} should have target minutes',
          );
          expect(
            day.estimatedDuration,
            isNotNull,
            reason: '${day.type} should have estimated duration',
          );
        }
      }
    });
  });

  group('goal determination', () {
    test('"Build a consistent running base" when totalRuns < 10', () {
      mockAnalyze.stats = _stats(totalRuns: 5, fitnessScore: 20);
      final plan = useCase.generate([_activity()]);
      expect(plan.goal, 'Build a consistent running base');
    });

    test('"Develop aerobic fitness" when fitnessScore < 30 and runs >= 10', () {
      mockAnalyze.stats = _stats(
        totalRuns: 10,
        fitnessScore: 25,
        recommendedPhase: CyclePhase.baseBuilding,
      );
      final plan = useCase.generate([_activity()]);
      expect(plan.goal, 'Increase aerobic capacity & volume');
    });

    test('"Recovery & consolidation week" when formScore < -10', () {
      mockAnalyze.stats = _stats(
        totalRuns: 15,
        fitnessScore: 35,
        formScore: -15,
      );
      final plan = useCase.generate([_activity()]);
      expect(plan.goal, 'Recovery & consolidation week');
    });

    test('"Improve threshold pace" when fit and fresh', () {
      mockAnalyze.stats = _stats(totalRuns: 15, fitnessScore: 35, formScore: 0);
      final plan = useCase.generate([_activity()]);
      expect(plan.goal, 'Improve threshold pace & endurance');
    });
  });

  group('plan description', () {
    test('fatigue description when formScore < -10', () {
      mockAnalyze.stats = _stats(
        totalRuns: 10,
        formScore: -20,
        weeklyVolume: {'W1': 20},
        weeklyMinutes: {'W1': 160},
      );
      final plan = useCase.generate([_activity()]);
      check(plan.description).contains("Fatigued");
    });

    test('fresh description when formScore > 10', () {
      mockAnalyze.stats = _stats(
        totalRuns: 10,
        formScore: 15,
        weeklyVolume: {'W1': 20},
        weeklyMinutes: {'W1': 160},
      );
      final plan = useCase.generate([_activity()]);
      check(plan.description).contains("Fresh");
    });

    test('balanced description otherwise', () {
      mockAnalyze.stats = _stats(
        totalRuns: 10,
        formScore: 0,
        weeklyVolume: {'W1': 20},
        weeklyMinutes: {'W1': 160},
      );
      final plan = useCase.generate([_activity()]);
      check(plan.description).contains("balanced");
    });
  });

  group('target weekly minutes', () {
    test('clamps easy run to minEasyRunMinutes when no recent weekly data', () {
      mockAnalyze.stats = _stats();
      final plan = useCase.generate([_activity()]);
      final totalTarget = plan.days.fold<int>(
        0,
        (s, d) => s + (d.targetMinutes ?? 0),
      );
      check(totalTarget).isGreaterThan(0);
    });

    test('scales down when formScore < -15', () {
      mockAnalyze.stats = _stats(
        weeklyVolume: {'W1': 20, 'W2': 25, 'W3': 22, 'W4': 28},
        weeklyMinutes: {'W1': 160, 'W2': 190, 'W3': 175, 'W4': 210},
        formScore: -16,
      );
      final plan = useCase.generate([_activity()]);
      final totalTarget = plan.days.fold<int>(
        0,
        (s, d) => s + (d.targetMinutes ?? 0),
      );
      // With formScore -16 (fatigued), multiplier is 0.85.
      // Average is (175 + 160 + 190 + 210) / 4 = 183.75.
      // 183.75 * 0.85 = 156.
      // The scheduled workouts will be roughly 156 mins.
      check(totalTarget).isLessThan(190);
    });

    test('scales up when formScore >= -5', () {
      mockAnalyze.stats = _stats(
        weeklyVolume: {'W1': 20, 'W2': 25, 'W3': 22, 'W4': 28},
        weeklyMinutes: {'W1': 160, 'W2': 190, 'W3': 175, 'W4': 210},
        formScore: 0,
      );
      final plan = useCase.generate([_activity()]);
      final totalTarget = plan.days.fold<int>(
        0,
        (s, d) => s + (d.targetMinutes ?? 0),
      );
      check(totalTarget).isGreaterThan(0);
      final restDays = plan.days
          .where((d) => d.type == WorkoutType.rest)
          .length;
      check(restDays).isLessThan(7);
    });
  });

  group('HR zones', () {
    test('uses default zones when no HR data in activities', () {
      final activities = [_activity(avgHr: null, maxHr: null)];
      mockAnalyze.stats = _stats(totalRuns: 1);
      final plan = useCase.generate(activities);
      final nonRest = plan.days.where(
        (d) =>
            d.type != WorkoutType.rest && d.type != WorkoutType.crossTraining,
      );
      for (final day in nonRest) {
        check(day.heartRateTarget).isNotNull();
        check(day.heartRateTarget!.zoneNumber)
          ..isGreaterOrEqual(1)
          ..isLessOrEqual(5);
      }
    });

    test('uses actual max HR from activities', () {
      final activities = [_activity(daysAgo: 3, avgHr: 140, maxHr: 195)];
      mockAnalyze.stats = _stats(totalRuns: 1);
      final plan = useCase.generate(activities);
      final zones = plan.days
          .where((d) => d.heartRateTarget != null)
          .map((d) => d.heartRateTarget!);
      for (final z in zones) {
        check(z.minBpm).isGreaterOrEqual(35);
        check(z.maxBpm).isLessOrEqual(195);
      }
    });
  });

  group('start date', () {
    test('returns today when no run today', () {
      final activities = [_activity(daysAgo: 1)];
      mockAnalyze.stats = _stats(totalRuns: 1);
      final plan = useCase.generate(activities);
      final today = DateTime.now();
      expect(plan.startDate.year, today.year);
      expect(plan.startDate.month, today.month);
      expect(plan.startDate.day, today.day);
    });

    test('returns tomorrow when run today', () {
      final activities = [_activity(daysAgo: 0)];
      mockAnalyze.stats = _stats(totalRuns: 1);
      final plan = useCase.generate(activities);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(plan.startDate.year, tomorrow.year);
      expect(plan.startDate.month, tomorrow.month);
      expect(plan.startDate.day, tomorrow.day);
    });
  });

  group('sequence selection', () {
    test('return sequence when last run > 3 days ago', () {
      final activities = [
        _activity(daysAgo: 5, minutes: 40, paceSecPerKm: 340),
      ];
      mockAnalyze.stats = _stats(totalRuns: 20, formScore: 0);
      final plan = useCase.generate(activities);
      check(plan.days.length).equals(7);
      // After 5+ rest days, non-beginner should start with a run
      expect(plan.days[0].type, isNot(WorkoutType.rest));
      // Verify hard workouts are followed by rest or easy
      for (int i = 0; i < plan.days.length - 1; i++) {
        final current = plan.days[i].type;
        final next = plan.days[i + 1].type;
        final isHard =
            current == WorkoutType.intervals ||
            current == WorkoutType.tempo ||
            current == WorkoutType.longRun;
        if (isHard) {
          expect(
            next,
            anyOf(WorkoutType.rest, WorkoutType.easy),
            reason: 'day $i ($current) must be followed by rest or easy',
          );
        }
      }
    });

    test('recovery after hard workout', () {
      final activities = [
        _activity(daysAgo: 1, minutes: 40, paceSecPerKm: 360, id: 1),
        _activity(daysAgo: 3, minutes: 40, paceSecPerKm: 280, id: 2),
        _activity(daysAgo: 5, minutes: 50, paceSecPerKm: 360, id: 3),
        _activity(daysAgo: 7, minutes: 40, paceSecPerKm: 280, id: 4),
        _activity(daysAgo: 9, minutes: 50, paceSecPerKm: 360, id: 5),
      ];
      mockAnalyze.stats = _stats(totalRuns: 10);
      final plan = useCase.generate(activities);
      check(plan.days.length).equals(7);
      for (int i = 0; i < plan.days.length - 1; i++) {
        final current = plan.days[i].type;
        final next = plan.days[i + 1].type;
        final isHard =
            current == WorkoutType.intervals ||
            current == WorkoutType.tempo ||
            current == WorkoutType.longRun;
        if (isHard) {
          expect(
            next,
            anyOf(WorkoutType.rest, WorkoutType.easy),
            reason: 'day $i ($current) must be followed by rest or easy',
          );
        }
      }
    });

    test('easy/rest alternation when beginner', () {
      final activities = [
        _activity(daysAgo: 1, minutes: 30, paceSecPerKm: 360, id: 1),
      ];
      mockAnalyze.stats = _stats(
        totalRuns: 3,
        recommendedPhase: CyclePhase.beginner,
      );
      final plan = useCase.generate(activities);
      expect(plan.days[0].type, WorkoutType.easy);
      expect(plan.days[1].type, WorkoutType.rest);
      expect(plan.days[2].type, WorkoutType.easy);
    });
  });

  group('TrainingDay.workMinutes', () {
    test('subtracts warm-up and cool-down from target minutes', () {
      final day = TrainingDay(
        date: DateTime.now(),
        type: WorkoutType.tempo,
        targetMinutes: 45,
        warmUpMinutes: 10,
        coolDownMinutes: 10,
        description: 'test',
      );
      check(day.workMinutes).equals(25);
    });

    test('returns null when targetMinutes is null', () {
      final day = TrainingDay(
        date: DateTime.now(),
        type: WorkoutType.rest,
        description: 'rest',
      );
      check(day.workMinutes).isNull();
    });
  });

  group('TrainingPlan.empty()', () {
    test('creates plan with empty days and no-data message', () {
      final empty = TrainingPlan.empty();
      check(empty.days).isEmpty();
      expect(empty.goal, 'No data available');
    });
  });

  group('PaceZoneCalculator', () {
    test('fromThresholdPace returns 5 zones', () {
      final zones = PaceZoneCalculator.fromThresholdPace(300);
      check(zones.length).equals(5);
      check(zones[0].label).contains('Zone 1');
      check(zones[4].label).contains('Zone 5');
    });

    test('zones have increasing speed (decreasing seconds)', () {
      final zones = PaceZoneCalculator.fromThresholdPace(300);
      for (int i = 0; i < zones.length - 1; i++) {
        expect(
          zones[i].fastestPace.inSeconds,
          greaterThanOrEqualTo(zones[i + 1].fastestPace.inSeconds),
        );
      }
    });
  });

  group('TrainingPlanConfig', () {
    test('default config matches original hardcoded values', () {
      const cfg = TrainingPlanConfig.defaultConfig;
      expect(cfg.longRunFraction, 0.30);
      expect(cfg.easyFraction, 0.20);
      expect(cfg.tempoFraction, 0.15);
      check(cfg.minRunDuration).equals(10);
      expect(cfg.longRunMultiplier, 1.5);
      check(cfg.longRunMinCap).equals(20);
      check(cfg.longRunMaxCap).equals(120);
      check(cfg.minEasyRunMinutes).equals(20);
      expect(cfg.minWeeklyMinutes, 60.0);
      expect(cfg.maxWeeklyMinutes, 600.0);
      expect(cfg.maxWeeklyMinutesScaleUp, 900.0);
      expect(cfg.fatiguedTsbThreshold, -15.0);
      expect(cfg.tiredTsbThreshold, -10.0);
      check(cfg.beginnerRunCount).equals(15);
      expect(cfg.beginnerWeeklyKm, 20.0);
      check(cfg.advancedRunCount).equals(50);
      expect(cfg.advancedWeeklyKm, 50.0);
      check(cfg.beginnerIntervalMin).equals(30);
      check(cfg.intermediateIntervalMin).equals(36);
      check(cfg.advancedIntervalMin).equals(42);
      check(cfg.baseBuildingRunCount).equals(10);
      expect(cfg.aerobicFitnessScore, 30.0);
      expect(cfg.freshFormScore, 10.0);
      check(cfg.returnGapDays).equals(3);
      check(cfg.cycleLengthWeeks).equals(4);
      expect(cfg.deloadVolumeFraction, 0.50);
      expect(cfg.buildWeekVolumeIncrement, 0.10);
      expect(cfg.deloadLongRunFraction, 0.50);
      check(cfg.beginnerMaxRunsPerWeek).equals(3);
      check(cfg.beginnerMinEasyMinutes).equals(10);
      check(cfg.beginnerWeeklyMinTarget).equals(45);
      check(cfg.continuousRunThreshold).equals(15);
      check(cfg.shortGapDays).equals(3);
      check(cfg.longGapDays).equals(7);
      check(cfg.injuryGapDays).equals(14);
      check(cfg.staleActivityDays).equals(90);
      expect(cfg.returnStartFraction, 0.55);
      expect(cfg.returnWeeklyIncreaseCap, 0.10);
      check(cfg.returnEasyOnlyWeeks).equals(1);
      check(cfg.returnRampWeeks).equals(3);
    });

    test('custom config changes volume fractions', () {
      const customConfig = TrainingPlanConfig(
        longRunFraction: 0.40,
        easyFraction: 0.25,
        tempoFraction: 0.10,
      );
      final customUseCase = GeneratePlanUseCase(
        analyzeRuns: mockAnalyze,
        config: customConfig,
      );
      mockAnalyze.stats = _stats(
        totalRuns: 25,
        weeklyVolume: {'W1': 30},
        weeklyMinutes: {'W1': 240},
        fitnessScore: 35,
        formScore: 0,
      );
      final plan = customUseCase.generate([_activity(daysAgo: 1)]);
      check(plan.days.length).equals(7);
    });
  });

  group('WorkoutDescriptions', () {
    test('custom descriptions are used in plan', () {
      final customUseCase = GeneratePlanUseCase(
        analyzeRuns: mockAnalyze,
        descriptions: const _CustomDescriptions(),
      );
      mockAnalyze.stats = _stats(
        totalRuns: 25,
        weeklyVolume: {'W1': 30},
        weeklyMinutes: {'W1': 240},
        fitnessScore: 35,
        formScore: 0,
      );
      final plan = customUseCase.generate([_activity(daysAgo: 1)]);
      final easyDays = plan.days.where((d) => d.type == WorkoutType.easy);
      for (final d in easyDays) {
        expect(d.description, 'Custom easy run');
      }
      final restDays = plan.days.where((d) => d.type == WorkoutType.rest);
      for (final d in restDays) {
        expect(d.description, 'Custom rest');
      }
    });
  });

  group('WorkoutSequenceStrategy', () {
    test('custom strategy overrides sequence', () {
      final customUseCase = GeneratePlanUseCase(
        analyzeRuns: mockAnalyze,
        sequenceStrategy: const _AllEasyStrategy(),
      );
      mockAnalyze.stats = _stats(
        totalRuns: 25,
        weeklyVolume: {'W1': 30},
        weeklyMinutes: {'W1': 240},
        fitnessScore: 35,
        formScore: 0,
      );
      final plan = customUseCase.generate([_activity(daysAgo: 1)]);
      check(plan.days.length).equals(7);
      for (final d in plan.days) {
        expect(d.type, WorkoutType.easy);
      }
    });
  });
}
