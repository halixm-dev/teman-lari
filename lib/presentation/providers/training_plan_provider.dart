import 'dart:convert';
import '../../data/backup/snapshot_backup_service.dart';
import '../../data/backup/archive/training_plan_config_archive.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/rehab_progress.dart';
import 'rehab_provider.dart';
import 'backup_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/training_plan.dart';
import '../../domain/usecases/generate_plan_usecase.dart';
import '../../domain/usecases/training_plan_config.dart';
import '../../domain/usecases/workout_descriptions.dart';
import '../../domain/usecases/workout_sequence_strategy.dart';
import 'activities_provider.dart';
import 'core_provider.dart';
import 'preferences_provider.dart';

part 'training_plan_provider.g.dart';

@Riverpod(keepAlive: true)
TrainingPlanConfig trainingPlanConfig(Ref ref) {
  return TrainingPlanConfig.defaultConfig;
}

@Riverpod(keepAlive: true)
WorkoutSequenceStrategy workoutSequenceStrategy(Ref ref) {
  return const DynamicWorkoutSequenceStrategy();
}

@Riverpod(keepAlive: true)
WorkoutDescriptions workoutDescriptions(Ref ref) {
  return const WorkoutDescriptions();
}

@Riverpod(keepAlive: true)
GeneratePlanUseCase generatePlanUseCase(Ref ref) {
  return GeneratePlanUseCase(
    analyzeRuns: ref.read(analyzeRunsUseCaseProvider),
    config: ref.read(trainingPlanConfigProvider),
    sequenceStrategy: ref.read(workoutSequenceStrategyProvider),
    descriptions: ref.read(workoutDescriptionsProvider),
  );
}

@riverpod
Future<TrainingPlan> trainingPlan(Ref ref) async {
  final activities = await ref.watch(activitiesProvider.future);
  final week = await ref.watch(weekInCycleProvider.future);
  final prefs = await ref.watch(hrPreferencesProvider.future);
  final config = ref.watch(trainingPlanConfigProvider);
  final base = ref.read(generatePlanUseCaseProvider);
  final service = ref.read(snapshotBackupServiceProvider);
  final journal = await ref.watch(rehabJournalProvider.future);
  final rehabilitation = await ref.watch(rehabProgressProvider.future);
  final program = journal.program;
  final now = _planTime(ref, program != null);
  final inputs = jsonEncode([
    activities.map(_planActivityInputs).toList(),
    week,
    prefs.maxHr,
    prefs.restingHr,
    prefs.thresholdPaceSeconds,
    TrainingPlanConfigArchive.fromDomain(config).toJson(),
    if (program != null)
      [
        program.toJson(),
        journal.feedback.map((f) => f.toJson()).toList(),
        now?.toIso8601String().substring(0, 10),
        rehabilitation?.stage,
        now?.isBefore(rehabilitation?.recoveryUntil ?? now),
      ],
  ]);
  return service.resolveTrainingPlan(
    inputs: inputs,
    configuration: config,
    requireFreshInputs: program != null,
    generate: (effectiveConfig) async {
      final useCase = _configuredUseCase(ref, base, effectiveConfig);
      final plan = await compute(_generatePlan, (
        useCase,
        activities,
        week,
        prefs.maxHr,
        prefs.restingHr,
        prefs.thresholdPaceSeconds,
        rehabilitation,
        program?.graduatedAt,
        now,
      ));
      if (!ref.mounted) throw StateError('Training Plan inputs changed.');
      return plan;
    },
  );
}

DateTime? _planTime(Ref ref, bool hasProgram) =>
    hasProgram ? ref.watch(rehabTimeProvider).value ?? DateTime.now() : null;

GeneratePlanUseCase _configuredUseCase(
  Ref ref,
  GeneratePlanUseCase base,
  TrainingPlanConfig config,
) => GeneratePlanUseCase(
  analyzeRuns: ref.read(analyzeRunsUseCaseProvider),
  config: config,
  sequenceStrategy: base.sequenceStrategy,
  descriptions: base.descriptions,
);

TrainingPlan _generatePlan(
  (
    GeneratePlanUseCase,
    List<Activity>,
    int,
    int?,
    int?,
    int?,
    RehabProgress?,
    DateTime?,
    DateTime?,
  )
  inputs,
) => inputs.$1.generate(
  inputs.$2,
  weekInCycle: inputs.$3,
  userMaxHr: inputs.$4,
  userRestingHr: inputs.$5,
  userThresholdPaceSeconds: inputs.$6,
  rehabilitation: inputs.$7,
  rehabilitationGraduatedAt: inputs.$8,
  now: inputs.$9,
);

List<Object?> _planActivityInputs(Activity activity) => [
  activity.id,
  activity.type.name,
  activity.date.toUtc().toIso8601String(),
  activity.distanceKm,
  activity.movingTime.inMicroseconds,
  activity.pace.inMicroseconds,
  activity.avgHeartRate,
  activity.maxHeartRate,
  activity.elevationGainM,
  activity.avgCadence,
  activity.sufferScore,
  activity.trainingLoad.name,
  activity.heartRateData,
  activity.perceivedExertion,
];

@riverpod
class WeekInCycleNotifier extends _$WeekInCycleNotifier {
  @override
  Future<int> build() async {
    final prefs = ref.read(preferencesStorageProvider);
    final cycleStart = await prefs.getCycleStartDate();
    final daysSinceStart = DateTime.now().difference(cycleStart).inDays;

    // A future imported cycle is still saved state; reads never reset it.
    if (daysSinceStart < 0) return 0;
    return daysSinceStart ~/ 7;
  }

  Future<void> advanceWeek() async {
    // This is no longer needed since it's computed dynamically from date,
    // but kept for API compatibility. It could artificially bump the start date if desired.
    // Best practice is to just let time pass.
  }

  Future<void> resetCycle() async {
    await ref
        .read(snapshotBackupServiceProvider)
        .resetTrainingCycle(DateTime.now());
    ref.invalidate(cycleStartDateProvider);
    ref.invalidate(trainingPlanProvider);
    ref.invalidateSelf();
  }
}

@riverpod
Future<DateTime> cycleStartDate(Ref ref) async {
  final prefs = ref.read(preferencesStorageProvider);
  return prefs.getCycleStartDate();
}
