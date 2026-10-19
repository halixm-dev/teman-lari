import '../entities/rehab_feedback.dart';
import '../entities/rehab_program.dart';
import '../entities/running_stats.dart';
import 'training_plan_config.dart';

/// Reuses existing return-volume and beginner baselines; captures them once.
RehabProgram startRehabProgram({
  required RunningStats stats,
  required InjurySite injurySite,
  required ReturnModality mode,
  required DateTime now,
  TrainingPlanConfig config = TrainingPlanConfig.defaultConfig,
}) {
  final context = stats.returnContext;
  final preGap = context?.preGapAvgMin ?? 0;
  final baseline = preGap > 0
      ? preGap * (context?.startVolumeFraction ?? config.returnStartFraction)
      : stats.recentWeeklyAvgMinutes * config.returnStartFraction;
  final weeks = context?.rampWeeks ?? 0;
  return RehabProgram(
    startedAt: now.toUtc(),
    injurySite: injurySite,
    mode: mode,
    initialWeeklyMinutes: baseline > 0
        ? baseline
        : config.beginnerWeeklyMinTarget.toDouble(),
    rampWeeks: weeks > 0 ? weeks : config.returnRampWeeks,
  );
}
