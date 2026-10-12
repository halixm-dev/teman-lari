import 'dart:isolate';

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
  final weekInCycle = await ref.watch(weekInCycleProvider.future);
  final prefs = await ref.watch(hrPreferencesProvider.future);
  final generateUseCase = ref.read(generatePlanUseCaseProvider);

  return kIsWeb
      ? generateUseCase.generate(
          activities,
          weekInCycle: weekInCycle,
          userMaxHr: prefs.maxHr,
          userRestingHr: prefs.restingHr,
          userThresholdPaceSeconds: prefs.thresholdPaceSeconds,
        )
      : await Isolate.run(
          () => generateUseCase.generate(
            activities,
            weekInCycle: weekInCycle,
            userMaxHr: prefs.maxHr,
            userRestingHr: prefs.restingHr,
            userThresholdPaceSeconds: prefs.thresholdPaceSeconds,
          ),
        );
}

@riverpod
class WeekInCycleNotifier extends _$WeekInCycleNotifier {
  @override
  Future<int> build() async {
    final prefs = ref.read(preferencesStorageProvider);
    final cycleStart = await prefs.getCycleStartDate();
    final daysSinceStart = DateTime.now().difference(cycleStart).inDays;

    if (daysSinceStart < 0) {
      await prefs.setCycleStartDate(DateTime.now());
      return 0;
    }
    return daysSinceStart ~/ 7;
  }

  Future<void> advanceWeek() async {
    // This is no longer needed since it's computed dynamically from date,
    // but kept for API compatibility. It could artificially bump the start date if desired.
    // Best practice is to just let time pass.
  }

  Future<void> resetCycle() async {
    final prefs = ref.read(preferencesStorageProvider);
    await prefs.setCycleStartDate(DateTime.now());
    ref.invalidateSelf();
  }
}

@riverpod
Future<DateTime> cycleStartDate(Ref ref) async {
  final prefs = ref.read(preferencesStorageProvider);
  return prefs.getCycleStartDate();
}
