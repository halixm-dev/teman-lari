import 'dart:async';
import 'dart:developer';
import 'dart:math' show pow;

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/local_activity_datasource.dart';
import '../datasources/preferences_storage.dart';
import '../datasources/strava_activity_datasource.dart';
import '../datasources/token_storage.dart';
import '../models/activity_model.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final StravaActivityDataSource remoteDataSource;
  final LocalActivityDataSource localDataSource;
  final PreferencesStorage preferencesStorage;
  final TokenStorage? tokenStorage;

  ActivityRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.preferencesStorage,
    this.tokenStorage,
  });

  Future<bool> _isAuthenticated() async {
    final storage = tokenStorage;
    if (storage == null) return false;
    try {
      final tokens = await storage.getTokens();
      if (tokens == null) return false;
      return tokens.accessToken.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<ActivityModel>> _getLocalActivities() async {
    try {
      return await localDataSource.getAllActivities();
    } on NoSuchMethodError {
      final cached = await localDataSource.getCachedActivities();
      return cached ?? [];
    } catch (_) {
      try {
        final cached = await localDataSource.getCachedActivities();
        return cached ?? [];
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<List<Activity>> getAllActivities({int monthsBack = 12}) async {
    final prefs = await preferencesStorage.getPreferences();
    final maxHr = prefs.maxHr ?? 190;

    final isAuth = await _isAuthenticated();
    if (!isAuth) {
      log(
        'Athlete is unauthenticated. Serving local SSOT activities.',
        name: 'ActivityRepo',
      );
      final local = await _getLocalActivities();
      return _mapModelsToEntities(local, maxHr: maxHr);
    }

    // Authenticated flow: check if local SSOT already has activities
    final localActivities = await _getLocalActivities();
    if (localActivities.isNotEmpty) {
      log(
        'Fetched ${localActivities.length} activities from local SSOT',
        name: 'ActivityRepo',
      );
      return _mapModelsToEntities(localActivities, maxHr: maxHr);
    }

    return _fetchInitialActivities(monthsBack, maxHr);
  }

  Future<List<Activity>> _fetchInitialActivities(
    int monthsBack,
    int maxHr,
  ) async {
    // Local store is empty and athlete is authenticated: fetch initial data from remote
    try {
      final remoteActivities = await remoteDataSource.getAllActivities(
        monthsBack: monthsBack,
      );
      log(
        'Fetched ${remoteActivities.length} activities from remote',
        name: 'ActivityRepo',
      );
      await localDataSource.smartMergeActivities(remoteActivities);
      return _mapModelsToEntities(remoteActivities, maxHr: maxHr);
    } on UnauthenticatedException catch (e, stack) {
      log(
        'Unauthenticated or revoked credentials during remote fetch. Falling back to local SSOT.',
        name: 'ActivityRepo',
        error: e,
        stackTrace: stack,
      );
      final local = await _getLocalActivities();
      return _mapModelsToEntities(local, maxHr: maxHr);
    } on StravaApiException catch (e, stack) {
      log(
        'Failed to fetch from remote',
        name: 'ActivityRepo',
        error: e,
        stackTrace: stack,
      );
      final local = await _getLocalActivities();
      if (local.isNotEmpty) {
        return _mapModelsToEntities(local, maxHr: maxHr);
      }
      throw ServerFailure(e.message, e.statusCode);
    }
  }

  @override
  Future<void> refreshActivities({int monthsBack = 12}) async {
    if (!await _isAuthenticated()) {
      log('Skipping refresh: athlete is unauthenticated', name: 'ActivityRepo');
      return;
    }

    try {
      final remoteActivities = await remoteDataSource.getAllActivities(
        monthsBack: monthsBack,
      );
      await localDataSource.smartMergeActivities(remoteActivities);
    } on UnauthenticatedException catch (e, stack) {
      log(
        'Athlete unauthenticated during refresh',
        name: 'ActivityRepo',
        error: e,
        stackTrace: stack,
      );
    } on StravaApiException catch (e, stack) {
      log(
        'Failed to refresh activities from remote',
        name: 'ActivityRepo',
        error: e,
        stackTrace: stack,
      );
      throw ServerFailure(e.message, e.statusCode);
    }
  }

  @override
  Future<Activity> uploadActivity(int localId) async {
    final isAuth = await _isAuthenticated();
    if (!isAuth) {
      throw UnauthenticatedException();
    }

    final localActivities = await _getLocalActivities();
    final localModel = localActivities.cast<ActivityModel?>().firstWhere(
      (a) => a?.id == localId,
      orElse: () => null,
    );

    if (localModel == null) {
      throw ArgumentError('Activity with ID $localId not found in local store');
    }

    // Duplicate submission protection: if already synced (> 0), don't re-upload
    if (localModel.id >= 0) {
      final prefs = await preferencesStorage.getPreferences();
      return _mapModelsToEntities([
        localModel,
      ], maxHr: prefs.maxHr ?? 190).first;
    }

    return _uploadLocalModel(localModel);
  }

  Future<Activity> _uploadLocalModel(ActivityModel localModel) async {
    try {
      final remoteModel = await remoteDataSource.createActivity(
        name: localModel.name,
        type: localModel.type,
        startDateLocal: localModel.startDate,
        elapsedTime: localModel.elapsedTime,
        distance: localModel.distance,
      );

      // Preserve any local-only metadata
      final mergedModel = remoteModel.copyWith(
        perceivedExertion:
            localModel.perceivedExertion ?? remoteModel.perceivedExertion,
        workoutType: localModel.workoutType ?? remoteModel.workoutType,
      );

      await localDataSource.updateLocalActivityId(localModel.id, mergedModel);

      final prefs = await preferencesStorage.getPreferences();
      return _mapModelsToEntities([
        mergedModel,
      ], maxHr: prefs.maxHr ?? 190).first;
    } on StravaApiException catch (e, stack) {
      log(
        'Strava API error during selective push upload',
        name: 'ActivityRepo',
        error: e,
        stackTrace: stack,
      );
      throw ServerFailure(e.message, e.statusCode);
    }
  }

  @override
  Future<void> saveActivity(Activity activity) async {
    final typeString = switch (activity.type) {
      ActivityType.run => 'Run',
      ActivityType.ride => 'Ride',
      ActivityType.swim => 'Swim',
      ActivityType.workout => 'Workout',
      ActivityType.walk => 'Walk',
      ActivityType.other => 'Other',
    };

    final distanceMeters = activity.distanceKm * 1000.0;
    final movingSeconds = activity.movingTime.inSeconds;
    final avgSpeed = movingSeconds > 0 ? distanceMeters / movingSeconds : 0.0;
    final hrData = activity.heartRateData;

    final model = ActivityModel(
      id: activity.id,
      name: activity.name,
      type: typeString,
      distance: distanceMeters,
      movingTime: movingSeconds,
      elapsedTime: movingSeconds,
      totalElevationGain: activity.elevationGainM,
      startDate: activity.date.toUtc().toIso8601String(),
      averageSpeed: avgSpeed,
      maxSpeed: avgSpeed,
      averageHeartrate: activity.avgHeartRate,
      maxHeartrate: activity.maxHeartRate,
      averageCadence: activity.avgCadence,
      sufferScore: activity.sufferScore,
      hasHeartrate:
          activity.avgHeartRate != null ||
          (hrData != null && hrData.isNotEmpty),
      perceivedExertion: activity.perceivedExertion,
    );

    await localDataSource.coordinator.write(() async {
      await localDataSource.saveActivity(model);
      if (hrData != null && hrData.isNotEmpty) {
        await localDataSource.saveHeartRateStream(activity.id, hrData);
      }
    });
  }

  @override
  Future<Map<int, List<double>>> getHeartRateStreams(
    List<int> activityIds,
  ) async {
    if (activityIds.isEmpty) return {};

    final cached = await localDataSource.getCachedHeartRateStreams(
      checkTtl: false,
    );
    final result = Map<int, List<double>>.from(cached);
    final uncached = activityIds
        .where((id) => !result.containsKey(id))
        .toList();

    if (uncached.isEmpty) return result;

    if (!await _isAuthenticated()) {
      return result;
    }

    const batchSize = 10;
    for (var i = 0; i < uncached.length; i += batchSize) {
      final batch = uncached.sublist(
        i,
        (i + batchSize > uncached.length) ? uncached.length : i + batchSize,
      );
      final futures = batch.map((id) async {
        try {
          final streams = await remoteDataSource.getActivityStreams(id);
          final data = streams.heartrate?.data;
          if (data != null && data.isNotEmpty) {
            await localDataSource.saveHeartRateStream(id, data);
            return MapEntry(id, data);
          }
        } on UnauthenticatedException {
          // Non-blocking for streams
        } catch (_) {}
        return null;
      });
      final entries = await Future.wait(futures);
      for (final entry in entries) {
        if (entry != null) {
          result[entry.key] = entry.value;
        }
      }
    }

    return result;
  }

  List<Activity> _mapModelsToEntities(
    List<ActivityModel> models, {
    int maxHr = 190,
  }) {
    return models.map((model) => _mapModelToEntity(model, maxHr)).toList();
  }

  Activity _mapModelToEntity(ActivityModel model, int maxHr) {
    final date = DateTime.parse(model.startDate).toLocal();
    final distanceKm = model.distance / 1000.0;
    final movingTimeSeconds = model.movingTime;
    final paceSecondsPerKm =
        movingTimeSeconds / (distanceKm > 0 ? distanceKm : 1);

    final load = _trainingLoad(model, maxHr);

    final parsedType = switch (model.type) {
      'Run' => ActivityType.run,
      'Ride' || 'VirtualRide' => ActivityType.ride,
      'Swim' => ActivityType.swim,
      'WeightTraining' || 'Workout' || 'Crossfit' => ActivityType.workout,
      'Walk' => ActivityType.walk,
      _ => ActivityType.other,
    };

    return Activity(
      id: model.id,
      name: model.name,
      date: date,
      type: parsedType,
      distanceKm: distanceKm,
      movingTime: Duration(seconds: movingTimeSeconds),
      pace: Duration(seconds: paceSecondsPerKm.round()),
      elevationGainM: model.totalElevationGain,
      trainingLoad: load,
      avgHeartRate: model.averageHeartrate,
      maxHeartRate: model.maxHeartrate,
      avgCadence: model.averageCadence,
      sufferScore: model.sufferScore,
      perceivedExertion: model.perceivedExertion,
    );
  }

  TrainingLoad _trainingLoad(ActivityModel model, int maxHr) {
    TrainingLoad load;
    final avgHr = model.averageHeartrate;
    final rpe = model.perceivedExertion;
    if (avgHr != null) {
      final hrPercent = avgHr / maxHr;
      if (hrPercent < 0.70) {
        load = TrainingLoad.easy;
      } else if (hrPercent < 0.80) {
        load = TrainingLoad.moderate;
      } else if (hrPercent < 0.90) {
        load = TrainingLoad.hard;
      } else {
        load = TrainingLoad.veryHard;
      }
    } else if (rpe != null) {
      final tss = (model.movingTime / 3600.0) * pow(rpe / 10.0, 2) * 100.0;
      if (tss < 30) {
        load = TrainingLoad.easy;
      } else if (tss < 60) {
        load = TrainingLoad.moderate;
      } else if (tss < 90) {
        load = TrainingLoad.hard;
      } else {
        load = TrainingLoad.veryHard;
      }
    } else {
      load = TrainingLoad.moderate;
    }

    return load;
  }
}
