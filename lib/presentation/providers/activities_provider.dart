import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/local_activity_datasource.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/running_stats.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/usecases/analyze_runs_usecase.dart';
import 'core_provider.dart';
import 'preferences_provider.dart';

part 'activities_provider.g.dart';

@Riverpod(keepAlive: true)
LocalActivityDataSource localActivityDataSource(Ref ref) {
  return LocalActivityDataSource();
}

@Riverpod(keepAlive: true)
ActivityRepository activityRepository(Ref ref) {
  return ActivityRepositoryImpl(
    remoteDataSource: ref.read(stravaActivityDataSourceProvider),
    localDataSource: ref.read(localActivityDataSourceProvider),
    preferencesStorage: ref.read(preferencesStorageProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
}

@Riverpod(keepAlive: true)
AnalyzeRunsUseCase analyzeRunsUseCase(Ref ref) {
  return AnalyzeRunsUseCase();
}

@Riverpod(keepAlive: true)
class ActivitiesNotifier extends _$ActivitiesNotifier {
  @override
  Future<List<Activity>> build() async {
    return ref
        .read(activityRepositoryProvider)
        .getAllActivities(monthsBack: 12);
  }

  Future<void> refresh() async {
    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.refreshActivities(monthsBack: 12);
    } catch (_) {
      // Non-blocking: remote failures or rate limits must not corrupt or block local SSOT
    }
    if (!ref.mounted) return;
    state = await AsyncValue.guard(() => repo.getAllActivities(monthsBack: 12));
  }

  Future<void> syncWithStrava() async {
    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.refreshActivities(monthsBack: 12);
    } finally {
      if (ref.mounted) {
        state = await AsyncValue.guard(
          () => repo.getAllActivities(monthsBack: 12),
        );
      }
    }
  }

  Future<Activity> uploadActivity(int localId) async {
    final repo = ref.read(activityRepositoryProvider);
    final uploaded = await repo.uploadActivity(localId);
    if (ref.mounted) {
      state = await AsyncValue.guard(
        () => repo.getAllActivities(monthsBack: 12),
      );
    }
    return uploaded;
  }
}

@riverpod
Future<RunningStats?> runningStats(Ref ref) async {
  final activities = await ref.watch(activitiesProvider.future);
  final prefs = await ref.watch(hrPreferencesProvider.future);
  final repo = ref.read(activityRepositoryProvider);
  final sortedActivities = [...activities]
    ..sort((a, b) => b.date.compareTo(a.date));
  final withHrIds = sortedActivities
      .where((a) => a.avgHeartRate != null)
      .map((a) => a.id)
      .take(50)
      .toList();

  List<Activity> target;
  if (withHrIds.isNotEmpty) {
    final streams = await repo.getHeartRateStreams(withHrIds);
    target = activities.map<Activity>((a) {
      if (a.avgHeartRate == null) return a;
      final hrData = streams[a.id];
      if (hrData == null) return a;
      return Activity(
        id: a.id,
        name: a.name,
        date: a.date,
        type: a.type,
        distanceKm: a.distanceKm,
        movingTime: a.movingTime,
        pace: a.pace,
        elevationGainM: a.elevationGainM,
        trainingLoad: a.trainingLoad,
        avgHeartRate: a.avgHeartRate,
        maxHeartRate: a.maxHeartRate,
        avgCadence: a.avgCadence,
        sufferScore: a.sufferScore,
        heartRateData: hrData,
      );
    }).toList();
  } else {
    target = activities;
  }

  final useCase = ref.read(analyzeRunsUseCaseProvider);
  final userThresholdPace = prefs.thresholdPaceSeconds != null
      ? Duration(seconds: prefs.thresholdPaceSeconds!)
      : null;

  final stats = kIsWeb
      ? useCase.compute(
          target,
          userMaxHr: prefs.maxHr,
          userRestingHr: prefs.restingHr,
          userThresholdPace: userThresholdPace,
        )
      : await Isolate.run(
          () => useCase.compute(
            target,
            userMaxHr: prefs.maxHr,
            userRestingHr: prefs.restingHr,
            userThresholdPace: userThresholdPace,
          ),
        );

  final activityMaxHr = target
      .map((a) => a.maxHeartRate)
      .whereType<double>()
      .fold<double?>(
        null,
        (max, hr) => max == null ? hr : (hr > max ? hr : max),
      );

  if (activityMaxHr != null) {
    await ref
        .read(hrPreferencesProvider.notifier)
        .updateFromStrava(activityMaxHr: activityMaxHr.round());
  }

  return stats;
}
