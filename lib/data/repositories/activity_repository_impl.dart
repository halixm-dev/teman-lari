import 'dart:async';
import 'dart:developer';

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
    if (tokenStorage == null) return false;
    try {
      final tokens = await tokenStorage!.getTokens();
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

      await localDataSource.updateLocalActivityId(localId, mergedModel);

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
    String typeString;
    switch (activity.type) {
      case ActivityType.run:
        typeString = 'Run';
        break;
      case ActivityType.ride:
        typeString = 'Ride';
        break;
      case ActivityType.swim:
        typeString = 'Swim';
        break;
      case ActivityType.workout:
        typeString = 'Workout';
        break;
      case ActivityType.walk:
        typeString = 'Walk';
        break;
      case ActivityType.other:
        typeString = 'Other';
        break;
    }

    final distanceMeters = activity.distanceKm * 1000.0;
    final movingSeconds = activity.movingTime.inSeconds;
    final avgSpeed = movingSeconds > 0 ? distanceMeters / movingSeconds : 0.0;

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
          (activity.heartRateData != null &&
              activity.heartRateData!.isNotEmpty),
      perceivedExertion: activity.perceivedExertion,
    );

    await localDataSource.saveActivity(model);

    if (activity.heartRateData != null && activity.heartRateData!.isNotEmpty) {
      await localDataSource.saveHeartRateStream(
        activity.id,
        activity.heartRateData!,
      );
    }
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
    return models.map((model) {
      final date = DateTime.parse(model.startDate).toLocal();
      final distanceKm = model.distance / 1000.0;
      final movingTimeSeconds = model.movingTime;
      final paceSecondsPerKm =
          movingTimeSeconds / (distanceKm > 0 ? distanceKm : 1);

      TrainingLoad load;
      if (model.averageHeartrate != null) {
        final hrPercent = model.averageHeartrate! / maxHr;
        if (hrPercent < 0.70) {
          load = TrainingLoad.easy;
        } else if (hrPercent < 0.80) {
          load = TrainingLoad.moderate;
        } else if (hrPercent < 0.90) {
          load = TrainingLoad.hard;
        } else {
          load = TrainingLoad.veryHard;
        }
      } else {
        load = TrainingLoad.moderate;
      }

      ActivityType parsedType;
      switch (model.type) {
        case 'Run':
          parsedType = ActivityType.run;
          break;
        case 'Ride':
        case 'VirtualRide':
          parsedType = ActivityType.ride;
          break;
        case 'Swim':
          parsedType = ActivityType.swim;
          break;
        case 'WeightTraining':
        case 'Workout':
        case 'Crossfit':
          parsedType = ActivityType.workout;
          break;
        case 'Walk':
          parsedType = ActivityType.walk;
          break;
        default:
          parsedType = ActivityType.other;
      }

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
    }).toList();
  }
}
