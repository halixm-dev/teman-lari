import 'package:json_annotation/json_annotation.dart';
import '../../../domain/usecases/training_plan_config.dart';
part 'training_plan_config_archive.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class TrainingPlanConfigArchive {
  final double longRunFraction;
  final double easyFraction;
  final double tempoFraction;
  final int minRunDuration;
  final int minEasyRunMinutes;
  final double longRunMultiplier;
  final int longRunMinCap;
  final int longRunMaxCap;
  final double minWeeklyMinutes;
  final double maxWeeklyMinutes;
  final double maxWeeklyMinutesScaleUp;
  final double dangerTsbThreshold;
  final double fatiguedTsbThreshold;
  final double tiredTsbThreshold;
  final double optimalTsbThreshold;
  final int minAcwrDays;
  final int beginnerRunCount;
  final int intermediateRunCount;
  final double beginnerWeeklyKm;
  final int advancedRunCount;
  final double advancedWeeklyKm;
  final int beginnerIntervalMin;
  final int intermediateIntervalMin;
  final int advancedIntervalMin;
  final int baseBuildingRunCount;
  final double aerobicFitnessScore;
  final double freshFormScore;
  final int returnGapDays;
  final int cycleLengthWeeks;
  final double deloadVolumeFraction;
  final double buildWeekVolumeIncrement;
  final double deloadLongRunFraction;
  final int beginnerMaxRunsPerWeek;
  final int beginnerMinEasyMinutes;
  final int beginnerWeeklyMinTarget;
  final int continuousRunThreshold;
  final int shortGapDays;
  final int longGapDays;
  final int injuryGapDays;
  final int staleActivityDays;
  final double returnStartFraction;
  final double returnWeeklyIncreaseCap;
  final int returnEasyOnlyWeeks;
  final int returnRampWeeks;
  const TrainingPlanConfigArchive({
    required this.longRunFraction,
    required this.easyFraction,
    required this.tempoFraction,
    required this.minRunDuration,
    required this.minEasyRunMinutes,
    required this.longRunMultiplier,
    required this.longRunMinCap,
    required this.longRunMaxCap,
    required this.minWeeklyMinutes,
    required this.maxWeeklyMinutes,
    required this.maxWeeklyMinutesScaleUp,
    required this.dangerTsbThreshold,
    required this.fatiguedTsbThreshold,
    required this.tiredTsbThreshold,
    required this.optimalTsbThreshold,
    required this.minAcwrDays,
    required this.beginnerRunCount,
    required this.intermediateRunCount,
    required this.beginnerWeeklyKm,
    required this.advancedRunCount,
    required this.advancedWeeklyKm,
    required this.beginnerIntervalMin,
    required this.intermediateIntervalMin,
    required this.advancedIntervalMin,
    required this.baseBuildingRunCount,
    required this.aerobicFitnessScore,
    required this.freshFormScore,
    required this.returnGapDays,
    required this.cycleLengthWeeks,
    required this.deloadVolumeFraction,
    required this.buildWeekVolumeIncrement,
    required this.deloadLongRunFraction,
    required this.beginnerMaxRunsPerWeek,
    required this.beginnerMinEasyMinutes,
    required this.beginnerWeeklyMinTarget,
    required this.continuousRunThreshold,
    required this.shortGapDays,
    required this.longGapDays,
    required this.injuryGapDays,
    required this.staleActivityDays,
    required this.returnStartFraction,
    required this.returnWeeklyIncreaseCap,
    required this.returnEasyOnlyWeeks,
    required this.returnRampWeeks,
  });
  factory TrainingPlanConfigArchive.fromDomain(TrainingPlanConfig value) =>
      TrainingPlanConfigArchive(
        longRunFraction: value.longRunFraction,
        easyFraction: value.easyFraction,
        tempoFraction: value.tempoFraction,
        minRunDuration: value.minRunDuration,
        minEasyRunMinutes: value.minEasyRunMinutes,
        longRunMultiplier: value.longRunMultiplier,
        longRunMinCap: value.longRunMinCap,
        longRunMaxCap: value.longRunMaxCap,
        minWeeklyMinutes: value.minWeeklyMinutes,
        maxWeeklyMinutes: value.maxWeeklyMinutes,
        maxWeeklyMinutesScaleUp: value.maxWeeklyMinutesScaleUp,
        dangerTsbThreshold: value.dangerTsbThreshold,
        fatiguedTsbThreshold: value.fatiguedTsbThreshold,
        tiredTsbThreshold: value.tiredTsbThreshold,
        optimalTsbThreshold: value.optimalTsbThreshold,
        minAcwrDays: value.minAcwrDays,
        beginnerRunCount: value.beginnerRunCount,
        intermediateRunCount: value.intermediateRunCount,
        beginnerWeeklyKm: value.beginnerWeeklyKm,
        advancedRunCount: value.advancedRunCount,
        advancedWeeklyKm: value.advancedWeeklyKm,
        beginnerIntervalMin: value.beginnerIntervalMin,
        intermediateIntervalMin: value.intermediateIntervalMin,
        advancedIntervalMin: value.advancedIntervalMin,
        baseBuildingRunCount: value.baseBuildingRunCount,
        aerobicFitnessScore: value.aerobicFitnessScore,
        freshFormScore: value.freshFormScore,
        returnGapDays: value.returnGapDays,
        cycleLengthWeeks: value.cycleLengthWeeks,
        deloadVolumeFraction: value.deloadVolumeFraction,
        buildWeekVolumeIncrement: value.buildWeekVolumeIncrement,
        deloadLongRunFraction: value.deloadLongRunFraction,
        beginnerMaxRunsPerWeek: value.beginnerMaxRunsPerWeek,
        beginnerMinEasyMinutes: value.beginnerMinEasyMinutes,
        beginnerWeeklyMinTarget: value.beginnerWeeklyMinTarget,
        continuousRunThreshold: value.continuousRunThreshold,
        shortGapDays: value.shortGapDays,
        longGapDays: value.longGapDays,
        injuryGapDays: value.injuryGapDays,
        staleActivityDays: value.staleActivityDays,
        returnStartFraction: value.returnStartFraction,
        returnWeeklyIncreaseCap: value.returnWeeklyIncreaseCap,
        returnEasyOnlyWeeks: value.returnEasyOnlyWeeks,
        returnRampWeeks: value.returnRampWeeks,
      );
  TrainingPlanConfig toDomain() => TrainingPlanConfig(
    longRunFraction: longRunFraction,
    easyFraction: easyFraction,
    tempoFraction: tempoFraction,
    minRunDuration: minRunDuration,
    minEasyRunMinutes: minEasyRunMinutes,
    longRunMultiplier: longRunMultiplier,
    longRunMinCap: longRunMinCap,
    longRunMaxCap: longRunMaxCap,
    minWeeklyMinutes: minWeeklyMinutes,
    maxWeeklyMinutes: maxWeeklyMinutes,
    maxWeeklyMinutesScaleUp: maxWeeklyMinutesScaleUp,
    dangerTsbThreshold: dangerTsbThreshold,
    fatiguedTsbThreshold: fatiguedTsbThreshold,
    tiredTsbThreshold: tiredTsbThreshold,
    optimalTsbThreshold: optimalTsbThreshold,
    minAcwrDays: minAcwrDays,
    beginnerRunCount: beginnerRunCount,
    intermediateRunCount: intermediateRunCount,
    beginnerWeeklyKm: beginnerWeeklyKm,
    advancedRunCount: advancedRunCount,
    advancedWeeklyKm: advancedWeeklyKm,
    beginnerIntervalMin: beginnerIntervalMin,
    intermediateIntervalMin: intermediateIntervalMin,
    advancedIntervalMin: advancedIntervalMin,
    baseBuildingRunCount: baseBuildingRunCount,
    aerobicFitnessScore: aerobicFitnessScore,
    freshFormScore: freshFormScore,
    returnGapDays: returnGapDays,
    cycleLengthWeeks: cycleLengthWeeks,
    deloadVolumeFraction: deloadVolumeFraction,
    buildWeekVolumeIncrement: buildWeekVolumeIncrement,
    deloadLongRunFraction: deloadLongRunFraction,
    beginnerMaxRunsPerWeek: beginnerMaxRunsPerWeek,
    beginnerMinEasyMinutes: beginnerMinEasyMinutes,
    beginnerWeeklyMinTarget: beginnerWeeklyMinTarget,
    continuousRunThreshold: continuousRunThreshold,
    shortGapDays: shortGapDays,
    longGapDays: longGapDays,
    injuryGapDays: injuryGapDays,
    staleActivityDays: staleActivityDays,
    returnStartFraction: returnStartFraction,
    returnWeeklyIncreaseCap: returnWeeklyIncreaseCap,
    returnEasyOnlyWeeks: returnEasyOnlyWeeks,
    returnRampWeeks: returnRampWeeks,
  );
  factory TrainingPlanConfigArchive.fromJson(Map<String, dynamic> json) {
    validateConfiguration(json);
    return _$TrainingPlanConfigArchiveFromJson(json);
  }
  Map<String, dynamic> toJson() => _$TrainingPlanConfigArchiveToJson(this);
}

void validateConfiguration(Map<String, dynamic> json) {
  for (final entry in json.entries) {
    if (!_configurationKeys.contains(entry.key)) continue;
    final value = entry.value;
    if (value is! num ||
        !value.isFinite ||
        _integerKeys.contains(entry.key) && value is! int) {
      throw StateError('Invalid Training Plan configuration.');
    }
    if (!entry.key.contains('tsb') && value < 0) {
      throw StateError('Invalid negative Training Plan configuration.');
    }
  }
}

const _integerKeys = {
  'min_run_duration',
  'min_easy_run_minutes',
  'long_run_min_cap',
  'long_run_max_cap',
  'min_acwr_days',
  'beginner_run_count',
  'intermediate_run_count',
  'advanced_run_count',
  'beginner_interval_min',
  'intermediate_interval_min',
  'advanced_interval_min',
  'base_building_run_count',
  'return_gap_days',
  'cycle_length_weeks',
  'beginner_max_runs_per_week',
  'beginner_min_easy_minutes',
  'beginner_weekly_min_target',
  'continuous_run_threshold',
  'short_gap_days',
  'long_gap_days',
  'injury_gap_days',
  'stale_activity_days',
  'return_easy_only_weeks',
  'return_ramp_weeks',
};

const _configurationKeys = {
  'long_run_fraction',
  'easy_fraction',
  'tempo_fraction',
  'min_run_duration',
  'min_easy_run_minutes',
  'long_run_multiplier',
  'long_run_min_cap',
  'long_run_max_cap',
  'min_weekly_minutes',
  'max_weekly_minutes',
  'max_weekly_minutes_scale_up',
  'danger_tsb_threshold',
  'fatigued_tsb_threshold',
  'tired_tsb_threshold',
  'optimal_tsb_threshold',
  'min_acwr_days',
  'beginner_run_count',
  'intermediate_run_count',
  'beginner_weekly_km',
  'advanced_run_count',
  'advanced_weekly_km',
  'beginner_interval_min',
  'intermediate_interval_min',
  'advanced_interval_min',
  'base_building_run_count',
  'aerobic_fitness_score',
  'fresh_form_score',
  'return_gap_days',
  'cycle_length_weeks',
  'deload_volume_fraction',
  'build_week_volume_increment',
  'deload_long_run_fraction',
  'beginner_max_runs_per_week',
  'beginner_min_easy_minutes',
  'beginner_weekly_min_target',
  'continuous_run_threshold',
  'short_gap_days',
  'long_gap_days',
  'injury_gap_days',
  'stale_activity_days',
  'return_start_fraction',
  'return_weekly_increase_cap',
  'return_easy_only_weeks',
  'return_ramp_weeks',
};
