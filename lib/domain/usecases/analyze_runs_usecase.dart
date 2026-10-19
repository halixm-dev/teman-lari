import '../entities/analyzed_activity.dart';
import '../entities/return_context.dart';
import '../entities/activity.dart';
import '../entities/running_stats.dart';
import '../entities/workout_type.dart';
import 'pace_zone_calculator.dart';
import 'return_context_detector.dart';
import 'training_load_calculator.dart';
import 'training_plan_config.dart';

class AnalyzeRunsUseCase {
  final TrainingLoadCalculator _loadCalculator;
  final ReturnContextDetector _returnDetector;

  AnalyzeRunsUseCase({
    TrainingLoadCalculator? loadCalculator,
    ReturnContextDetector? returnDetector,
  }) : _loadCalculator = loadCalculator ?? TrainingLoadCalculator(),
       _returnDetector = returnDetector ?? ReturnContextDetector();

  RunningStats compute(
    List<Activity> activities, {
    int? userMaxHr,
    int? userRestingHr,
    Duration? userThresholdPace,
    TrainingPlanConfig? config,
    ReturnContext? returnContextOverride,
  }) {
    if (activities.isEmpty) {
      final empty = RunningStats.empty();
      return returnContextOverride == null
          ? empty
          : empty.withReturnContext(returnContextOverride);
    }

    final runningActivities = activities
        .where((a) => a.type == ActivityType.run)
        .toList();

    final relevantActivities = activities
        .where((a) => a.type == ActivityType.run || a.type == ActivityType.walk)
        .toList();

    final sortedByDate = [...relevantActivities]
      ..sort((a, b) => a.date.compareTo(b.date));

    final sortedRunning = [...runningActivities]
      ..sort((a, b) => a.date.compareTo(b.date));

    final actualMaxHr = _resolveMaxHr(activities, userValue: userMaxHr) ?? 190;
    final actualRestingHr =
        _resolveRestingHr(activities, userValue: userRestingHr) ?? 60;

    final loadHistory = _loadCalculator.computeLoadHistory(
      sortedByDate,
      maxHr: actualMaxHr,
      restingHr: actualRestingHr,
      thresholdPace: userThresholdPace,
    );

    final cfg = config ?? TrainingPlanConfig.defaultConfig;

    final returnCtx =
        returnContextOverride ?? _returnDetector.detect(sortedRunning, cfg);

    final thresholdPace =
        userThresholdPace?.inSeconds ??
        PaceZoneCalculator.estimateThresholdPace(runningActivities);
    final easyLike =
        sortedRunning
            .where(
              (a) =>
                  a.trainingLoad != TrainingLoad.hard &&
                  a.trainingLoad != TrainingLoad.veryHard &&
                  a.movingTime.inMinutes >= cfg.minRunDuration,
            )
            .map((a) => a.movingTime.inMinutes)
            .toList()
          ..sort();
    final easyMedian = easyLike.isNotEmpty
        ? easyLike[easyLike.length ~/ 2]
        : 30;
    final longRunMinDuration = (easyMedian * cfg.longRunMultiplier)
        .round()
        .clamp(cfg.longRunMinCap, cfg.longRunMaxCap);

    final analyzedActivities = relevantActivities.map((a) {
      return AnalyzedActivity(
        activity: a,
        type: _classifyActivity(
          a,
          thresholdPaceSecPerKm: thresholdPace,
          longRunMinDuration: longRunMinDuration,
          maxHr: actualMaxHr,
          restingHr: actualRestingHr,
        ),
      );
    }).toList();

    final acwr = _loadCalculator.computeAcwr(
      sortedByDate,
      maxHr: actualMaxHr,
      restingHr: actualRestingHr,
      thresholdPace: userThresholdPace,
      minAcwrDays: cfg.minAcwrDays,
    );

    final now = DateTime.now();
    int longestRecentRunMin = 0;
    for (final a in sortedRunning.reversed) {
      if (now.difference(a.date).inDays > 14) break;
      if (a.movingTime.inMinutes > longestRecentRunMin) {
        longestRecentRunMin = a.movingTime.inMinutes;
      }
    }

    return RunningStats(
      totalRuns: runningActivities.length,
      totalDistanceKm: _totalDistance(runningActivities),
      weeklyVolume: _weeklyVolume(runningActivities),
      weeklyMinutes: _weeklyMinutes(runningActivities),
      averagePace: _averagePace(runningActivities),
      paceProgression: _paceProgression(sortedRunning),
      heartRateZones: _hrZoneDistribution(
        runningActivities,
        maxHr: actualMaxHr,
        restingHr: actualRestingHr,
      ),
      trainingLoadHistory: loadHistory,
      vo2MaxEstimate: _estimateVo2Max(runningActivities),
      fitnessScore: loadHistory.isNotEmpty ? loadHistory.last.fitness : 0.0,
      fatigueScore: loadHistory.isNotEmpty ? loadHistory.last.fatigue : 0.0,
      formScore: loadHistory.isNotEmpty ? loadHistory.last.form : 0.0,
      returnContext: returnCtx,
      recommendedPhase: _determinePhase(
        returnCtx,
        totalRuns: runningActivities.length,
        recentWeeklyAvgKm: sortedRunning.isNotEmpty
            ? _recentWeeklyAvg(sortedRunning, byDistance: true)
            : 0,
        config: cfg,
      ),
      analyzedActivities: analyzedActivities,
      firstActivityDate: sortedRunning.isNotEmpty
          ? sortedRunning.first.date
          : null,
      longestRecentRunMinutes: longestRecentRunMin,
      acwr: acwr,
    );
  }

  CyclePhase _determinePhase(
    ReturnContext? returnCtx, {
    required int totalRuns,
    required double recentWeeklyAvgKm,
    required TrainingPlanConfig config,
  }) {
    if (returnCtx != null && returnCtx.isReturning) {
      return CyclePhase.returning;
    }
    if (totalRuns < config.baseBuildingRunCount) {
      return CyclePhase.baseBuilding;
    }
    if (totalRuns < config.intermediateRunCount) {
      return CyclePhase.beginner;
    }
    if (totalRuns >= config.advancedRunCount &&
        recentWeeklyAvgKm >= config.advancedWeeklyKm) {
      return CyclePhase.advanced;
    }
    return CyclePhase.intermediate;
  }

  double _recentWeeklyAvg(
    List<Activity> activities, {
    required bool byDistance,
  }) {
    if (activities.isEmpty) return 0;
    final weekly = <String, double>{};
    for (final activity in activities) {
      final weekKey = _weekCommencingKey(activity.date);
      weekly[weekKey] =
          (weekly[weekKey] ?? 0) +
          (byDistance
              ? activity.distanceKm
              : activity.movingTime.inMinutes.toDouble());
    }
    final values = weekly.values.toList();
    final recentCount = values.length > 4 ? 4 : values.length;
    final recent = values.sublist(values.length - recentCount);
    return recent.reduce((a, b) => a + b) / recentCount;
  }

  List<PaceDataPoint> _paceProgression(List<Activity> sorted) {
    return sorted
        .where((a) => a.distanceKm > 3)
        .map(
          (a) => PaceDataPoint(
            date: a.date,
            paceSecondsPerKm: a.pace.inSeconds,
            distanceKm: a.distanceKm,
          ),
        )
        .toList();
  }

  Map<int, double> _hrZoneDistribution(
    List<Activity> activities, {
    required int maxHr,
    required int restingHr,
  }) {
    final withHr = activities.where((a) => a.avgHeartRate != null);
    if (withHr.isEmpty) return {};

    final zoneSeconds = <int, double>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double totalSeconds = 0;

    for (final activity in withHr) {
      final stream = activity.heartRateData;
      if (stream != null && stream.isNotEmpty) {
        final secondsPerPoint = activity.movingTime.inSeconds / stream.length;
        for (final hr in stream) {
          final zone = _loadCalculator.hrToZone(
            hr,
            maxHr: maxHr,
            restingHr: restingHr,
          );
          zoneSeconds[zone] = (zoneSeconds[zone] ?? 0) + secondsPerPoint;
        }
        totalSeconds += activity.movingTime.inSeconds.toDouble();
      } else {
        final avg = activity.avgHeartRate;
        if (avg != null) {
          final zone = _loadCalculator.hrToZone(
            avg,
            maxHr: maxHr,
            restingHr: restingHr,
          );
          final seconds = activity.movingTime.inSeconds.toDouble();
          zoneSeconds[zone] = (zoneSeconds[zone] ?? 0) + seconds;
          totalSeconds += seconds;
        }
      }
    }

    if (totalSeconds <= 0) return {};
    return zoneSeconds.map((k, v) => MapEntry(k, v / totalSeconds));
  }

  int? _resolveMaxHr(List<Activity> activities, {int? userValue}) {
    if (userValue != null) return userValue;
    final values = activities.map((a) => a.maxHeartRate).whereType<double>();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b).round();
  }

  int? _resolveRestingHr(List<Activity> activities, {int? userValue}) {
    if (userValue != null) return userValue;
    return null;
  }

  double? _estimateVo2Max(List<Activity> activities) {
    final candidates = activities
        .where((a) => a.movingTime.inMinutes >= 12)
        .toList();
    if (candidates.isEmpty) return null;

    final best = candidates.reduce(
      (a, b) => a.pace.inSeconds < b.pace.inSeconds ? a : b,
    );

    final paceMinKm = best.pace.inSeconds / 60.0;
    return 29.54 +
        (5.000663 / paceMinKm) +
        (0.007546 / (paceMinKm * paceMinKm));
  }

  Map<String, double> _weeklyVolume(List<Activity> activities) {
    final weekly = <String, double>{};
    for (final activity in activities) {
      final weekKey = _weekCommencingKey(activity.date);
      weekly[weekKey] = (weekly[weekKey] ?? 0) + activity.distanceKm;
    }
    return weekly;
  }

  Map<String, double> _weeklyMinutes(List<Activity> activities) {
    final weekly = <String, double>{};
    for (final activity in activities) {
      final weekKey = _weekCommencingKey(activity.date);
      weekly[weekKey] =
          (weekly[weekKey] ?? 0) + activity.movingTime.inMinutes.toDouble();
    }
    return weekly;
  }

  String _weekCommencingKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  double _totalDistance(List<Activity> activities) =>
      activities.fold(0, (sum, a) => sum + a.distanceKm);

  Duration _averagePace(List<Activity> activities) {
    final totalDistance = activities.fold<double>(
      0,
      (sum, a) => sum + a.distanceKm,
    );
    if (totalDistance == 0) return Duration.zero;
    final totalSeconds = activities.fold<int>(
      0,
      (sum, a) => sum + a.movingTime.inSeconds,
    );
    return Duration(seconds: (totalSeconds / totalDistance).round());
  }

  WorkoutType _classifyActivity(
    Activity activity, {
    required int thresholdPaceSecPerKm,
    required int longRunMinDuration,
    required int maxHr,
    required int restingHr,
  }) {
    if (activity.type != ActivityType.run) {
      if (activity.type == ActivityType.walk) return WorkoutType.walk;
      return WorkoutType.crossTraining;
    }

    final pace = activity.pace.inSeconds;
    final durationMin = activity.movingTime.inMinutes;

    // 1. Check HR if available
    if (activity.avgHeartRate != null) {
      final avgZone = _loadCalculator.hrToZone(
        activity.avgHeartRate!,
        maxHr: maxHr,
        restingHr: restingHr,
      );
      final maxZone = activity.maxHeartRate != null
          ? _loadCalculator.hrToZone(
              activity.maxHeartRate!,
              maxHr: maxHr,
              restingHr: restingHr,
            )
          : avgZone;

      if (maxZone >= 4 || activity.trainingLoad == TrainingLoad.veryHard) {
        if (avgZone <= 3 || activity.trainingLoad == TrainingLoad.veryHard) {
          return WorkoutType.intervals;
        }
        if (avgZone >= 4) return WorkoutType.tempo;
      }

      if (avgZone == 3) return WorkoutType.tempo;

      if (avgZone <= 2) {
        if (durationMin >= longRunMinDuration) return WorkoutType.longRun;
        return WorkoutType.easy;
      }
    }

    // 2. Pace fallback
    if (durationMin >= longRunMinDuration &&
        pace > (thresholdPaceSecPerKm * 1.05).round()) {
      return WorkoutType.longRun;
    }

    if (pace <= (thresholdPaceSecPerKm * 1.05).round()) {
      if (pace < (thresholdPaceSecPerKm * 0.98).round() ||
          activity.trainingLoad == TrainingLoad.veryHard) {
        return WorkoutType.intervals;
      }
      return WorkoutType.tempo;
    }

    return WorkoutType.easy;
  }
}
