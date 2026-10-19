import 'analyzed_activity.dart';
import 'return_context.dart';

enum CyclePhase { beginner, baseBuilding, intermediate, advanced, returning }

class PaceDataPoint {
  final DateTime date;
  final int paceSecondsPerKm;
  final double distanceKm;

  const PaceDataPoint({
    required this.date,
    required this.paceSecondsPerKm,
    required this.distanceKm,
  });
}

class TrainingLoadPoint {
  final DateTime date;
  final double fitness;
  final double fatigue;
  final double form;

  const TrainingLoadPoint({
    required this.date,
    required this.fitness,
    required this.fatigue,
    required this.form,
  });
}

class RunningStats {
  final int totalRuns;
  final double totalDistanceKm;
  final Map<String, double> weeklyVolume;
  final Map<String, double> weeklyMinutes;
  final Duration averagePace;
  final List<PaceDataPoint> paceProgression;
  final Map<int, double> heartRateZones;
  final List<TrainingLoadPoint> trainingLoadHistory;
  final double? vo2MaxEstimate;
  final double fitnessScore;
  final double fatigueScore;
  final double formScore;
  final ReturnContext? returnContext;
  final CyclePhase recommendedPhase;
  final List<AnalyzedActivity> analyzedActivities;
  final DateTime? firstActivityDate;
  final int longestRecentRunMinutes;
  final double acwr;

  const RunningStats({
    required this.totalRuns,
    required this.totalDistanceKm,
    required this.weeklyVolume,
    required this.weeklyMinutes,
    required this.averagePace,
    required this.paceProgression,
    required this.heartRateZones,
    required this.trainingLoadHistory,
    required this.vo2MaxEstimate,
    required this.fitnessScore,
    required this.fatigueScore,
    required this.formScore,
    this.returnContext,
    this.recommendedPhase = CyclePhase.beginner,
    this.analyzedActivities = const [],
    this.firstActivityDate,
    this.longestRecentRunMinutes = 0,
    this.acwr = 1.0,
  });

  factory RunningStats.empty() {
    return RunningStats(
      totalRuns: 0,
      totalDistanceKm: 0,
      weeklyVolume: {},
      weeklyMinutes: {},
      averagePace: Duration.zero,
      paceProgression: [],
      heartRateZones: {},
      trainingLoadHistory: [],
      vo2MaxEstimate: null,
      fitnessScore: 0,
      fatigueScore: 0,
      formScore: 0,
      returnContext: null,
      recommendedPhase: CyclePhase.beginner,
      analyzedActivities: const [],
      firstActivityDate: null,
      longestRecentRunMinutes: 0,
      acwr: 1.0,
    );
  }

  RunningStats withReturnContext(ReturnContext context) => RunningStats(
    totalRuns: totalRuns,
    totalDistanceKm: totalDistanceKm,
    weeklyVolume: weeklyVolume,
    weeklyMinutes: weeklyMinutes,
    averagePace: averagePace,
    paceProgression: paceProgression,
    heartRateZones: heartRateZones,
    trainingLoadHistory: trainingLoadHistory,
    vo2MaxEstimate: vo2MaxEstimate,
    fitnessScore: fitnessScore,
    fatigueScore: fatigueScore,
    formScore: formScore,
    returnContext: context,
    recommendedPhase: context.isReturning
        ? CyclePhase.returning
        : recommendedPhase,
    analyzedActivities: analyzedActivities,
    firstActivityDate: firstActivityDate,
    longestRecentRunMinutes: longestRecentRunMinutes,
    acwr: acwr,
  );

  double get recentWeeklyAvgKm {
    if (weeklyVolume.isEmpty) return 0;
    final values = weeklyVolume.values.toList();
    final recentCount = values.length > 4 ? 4 : values.length;
    final recent = values.sublist(values.length - recentCount);
    return recent.reduce((a, b) => a + b) / recentCount;
  }

  double get recentWeeklyAvgMinutes {
    if (weeklyMinutes.isEmpty) return 0;
    final values = weeklyMinutes.values.toList();
    final recentCount = values.length > 4 ? 4 : values.length;
    final recent = values.sublist(values.length - recentCount);
    return recent.reduce((a, b) => a + b) / recentCount;
  }
}
