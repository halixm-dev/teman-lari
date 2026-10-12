import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/core/errors/exceptions.dart';
import 'package:teman_lari/core/errors/failures.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/strava_activity_datasource.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/models/activity_model.dart';
import 'package:teman_lari/data/models/activity_streams.dart';
import 'package:teman_lari/data/models/athlete_model.dart';
import 'package:teman_lari/data/models/strava_tokens.dart';
import 'package:teman_lari/data/repositories/activity_repository_impl.dart';
import 'package:teman_lari/domain/entities/activity.dart';

class FakeStravaActivityDataSource implements StravaActivityDataSource {
  int getAllActivitiesCallCount = 0;
  List<ActivityModel> remoteActivities = [];
  Exception? errorToThrow;

  @override
  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async {
    getAllActivitiesCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return remoteActivities;
  }

  @override
  Future<ActivityStreams> getActivityStreams(int activityId) async {
    return const ActivityStreams();
  }

  @override
  Future<AthleteModel> getAthlete() async {
    return const AthleteModel(id: 1, firstName: 'Test');
  }

  int createActivityCallCount = 0;
  ActivityModel? createdActivityToReturn;

  @override
  Future<ActivityModel> createActivity({
    required String name,
    required String type,
    required String startDateLocal,
    required int elapsedTime,
    double? distance,
    String? description,
  }) async {
    createActivityCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return createdActivityToReturn ??
        ActivityModel(
          id: 8888,
          name: name,
          type: type,
          distance: distance ?? 0.0,
          movingTime: elapsedTime,
          elapsedTime: elapsedTime,
          totalElevationGain: 0.0,
          startDate: startDateLocal,
          averageSpeed: (distance != null && elapsedTime > 0)
              ? distance / elapsedTime
              : 0.0,
          maxSpeed: 0.0,
        );
  }
}

class FakeLocalActivityDataSource extends LocalActivityDataSource {
  List<ActivityModel> storedActivities = [];
  Map<int, List<double>> storedStreams = {};
  int getAllActivitiesCallCount = 0;
  int saveActivitiesCallCount = 0;
  int saveActivityCallCount = 0;
  int updateActivityCallCount = 0;
  int smartMergeCallCount = 0;
  int updateLocalActivityIdCallCount = 0;
  int saveHeartRateStreamCallCount = 0;

  @override
  Future<List<ActivityModel>> getAllActivities() async {
    getAllActivitiesCallCount++;
    return List.from(storedActivities);
  }

  @override
  Future<List<ActivityModel>?> getCachedActivities({
    bool checkTtl = true,
  }) async {
    return storedActivities.isEmpty ? null : List.from(storedActivities);
  }

  @override
  Future<void> saveActivities(List<ActivityModel> activities) async {
    saveActivitiesCallCount++;
    storedActivities.addAll(activities);
  }

  @override
  Future<void> smartMergeActivities(List<ActivityModel> activities) async {
    smartMergeCallCount++;
    saveActivitiesCallCount++;
    storedActivities.addAll(activities);
  }

  @override
  Future<void> saveActivity(ActivityModel model) async {
    saveActivityCallCount++;
    storedActivities.add(model);
  }

  @override
  Future<void> updateActivity(ActivityModel model) async {
    updateActivityCallCount++;
    final index = storedActivities.indexWhere((a) => a.id == model.id);
    if (index != -1) {
      storedActivities[index] = model;
    } else {
      storedActivities.add(model);
    }
  }

  @override
  Future<void> updateLocalActivityId(
    int oldLocalId,
    ActivityModel updatedModel,
  ) async {
    updateLocalActivityIdCallCount++;
    storedActivities.removeWhere((a) => a.id == oldLocalId);
    storedActivities.add(updatedModel);
  }

  @override
  Future<void> saveHeartRateStream(int activityId, List<double> data) async {
    saveHeartRateStreamCallCount++;
    storedStreams[activityId] = List.from(data);
  }

  @override
  Future<Map<int, List<double>>> getCachedHeartRateStreams({
    bool checkTtl = true,
  }) async {
    return Map.from(storedStreams);
  }

  @override
  Future<Map<int, List<double>>> getAllHeartRateStreams() async {
    return Map.from(storedStreams);
  }

  @override
  Future<void> clearCache() async {
    storedActivities.clear();
    storedStreams.clear();
  }
}

class FakePreferencesStorage extends PreferencesStorage {
  HrPreferences preferences = const HrPreferences(maxHr: 190, restingHr: 60);

  @override
  Future<HrPreferences> getPreferences() async => preferences;
}

class FakeTokenStorage extends TokenStorage {
  StravaTokens? tokens;
  int getTokensCallCount = 0;

  @override
  Future<StravaTokens?> getTokens() async {
    getTokensCallCount++;
    return tokens;
  }

  @override
  Future<void> saveTokens(StravaTokens tokens) async {
    this.tokens = tokens;
  }

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }
}

void main() {
  group('ActivityRepositoryImpl - Unauthenticated Safe Behavior', () {
    late FakeStravaActivityDataSource fakeRemote;
    late FakeLocalActivityDataSource fakeLocal;
    late FakePreferencesStorage fakePrefs;
    late FakeTokenStorage fakeTokens;
    late ActivityRepositoryImpl repository;

    setUp(() {
      fakeRemote = FakeStravaActivityDataSource();
      fakeLocal = FakeLocalActivityDataSource();
      fakePrefs = FakePreferencesStorage();
      fakeTokens = FakeTokenStorage();

      repository = ActivityRepositoryImpl(
        remoteDataSource: fakeRemote,
        localDataSource: fakeLocal,
        preferencesStorage: fakePrefs,
        tokenStorage: fakeTokens,
      );
    });

    // Test T-REPO-01
    test(
      'getAllActivities returns [] when unauthenticated and local store is empty',
      () async {
        fakeTokens.tokens = null; // Unauthenticated
        fakeLocal.storedActivities = [];

        final result = await repository.getAllActivities();

        check(result).isNotNull();
        check(result).isEmpty();
        check(
          fakeRemote.getAllActivitiesCallCount,
        ).equals(0); // ZERO cloud calls!
        check(fakeLocal.getAllActivitiesCallCount).equals(1);
      },
    );

    // Test T-REPO-02
    test(
      'getAllActivities returns local activities when unauthenticated without remote call',
      () async {
        fakeTokens.tokens = null; // Unauthenticated
        fakeLocal.storedActivities = [
          const ActivityModel(
            id: 101,
            name: 'Local Run 1',
            type: 'Run',
            distance: 5000.0,
            movingTime: 1500,
            elapsedTime: 1600,
            totalElevationGain: 20.0,
            startDate: '2026-05-20T08:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.2,
          ),
          const ActivityModel(
            id: 102,
            name: 'Local Run 2',
            type: 'Run',
            distance: 8000.0,
            movingTime: 2400,
            elapsedTime: 2500,
            totalElevationGain: 50.0,
            startDate: '2026-05-21T08:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.5,
          ),
        ];

        final result = await repository.getAllActivities();

        check(result).length.equals(2);
        check(result[0].id).equals(101);
        check(result[1].id).equals(102);
        check(
          fakeRemote.getAllActivitiesCallCount,
        ).equals(0); // ZERO cloud calls!
      },
    );

    // Test T-REPO-03
    test(
      'getAllActivities preserves negative-ID offline workouts in unauthenticated mode',
      () async {
        fakeTokens.tokens = null;
        fakeLocal.storedActivities = [
          const ActivityModel(
            id: -1001, // Negative ID: Offline in-app run
            name: 'Track Session Offline',
            type: 'Run',
            distance: 6000.0,
            movingTime: 1800,
            elapsedTime: 1850,
            totalElevationGain: 15.0,
            startDate: '2026-05-22T07:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.0,
          ),
        ];

        final result = await repository.getAllActivities();

        check(result).length.equals(1);
        check(result.first.id).equals(-1001);
        check(result.first.name).equals('Track Session Offline');
        check(fakeRemote.getAllActivitiesCallCount).equals(0);
      },
    );

    // Test T-REPO-04
    test(
      'getAllActivities shields against UnauthenticatedException and returns local data safely',
      () async {
        // Edge case: tokens existed or remote call triggered, but remote threw UnauthenticatedException
        fakeTokens.tokens = const StravaTokens(
          accessToken: 'expired_token',
          refreshToken: 'expired_refresh',
          expiresAt: 0,
        );
        fakeRemote.errorToThrow = UnauthenticatedException();
        fakeLocal.storedActivities = [
          const ActivityModel(
            id: 101,
            name: 'Saved Run',
            type: 'Run',
            distance: 5000.0,
            movingTime: 1500,
            elapsedTime: 1600,
            totalElevationGain: 10.0,
            startDate: '2026-05-20T08:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.0,
          ),
        ];

        // Calling getAllActivities must NOT throw UnauthenticatedException
        final result = await repository.getAllActivities();

        check(result).length.equals(1);
        check(result.first.id).equals(101);
      },
    );

    // Test T-REPO-05
    test(
      'refreshActivities does not make remote calls or throw when unauthenticated',
      () async {
        fakeTokens.tokens = null; // Unauthenticated

        await repository.refreshActivities();

        check(fakeRemote.getAllActivitiesCallCount).equals(0);
      },
    );
  });

  group('ActivityRepositoryImpl - Entity Mapping Accuracy', () {
    late FakeStravaActivityDataSource fakeRemote;
    late FakeLocalActivityDataSource fakeLocal;
    late FakePreferencesStorage fakePrefs;
    late FakeTokenStorage fakeTokens;
    late ActivityRepositoryImpl repository;

    setUp(() {
      fakeRemote = FakeStravaActivityDataSource();
      fakeLocal = FakeLocalActivityDataSource();
      fakePrefs = FakePreferencesStorage();
      fakeTokens = FakeTokenStorage();

      repository = ActivityRepositoryImpl(
        remoteDataSource: fakeRemote,
        localDataSource: fakeLocal,
        preferencesStorage: fakePrefs,
        tokenStorage: fakeTokens,
      );
    });

    // Test T-REPO-06
    test(
      'correctly converts distance, duration, pace and paceString',
      () async {
        fakeTokens.tokens = null;
        fakeLocal.storedActivities = [
          const ActivityModel(
            id: 201,
            name: '10K Tempo',
            type: 'Run',
            distance: 10000.0, // 10 km
            movingTime: 3000, // 50 minutes = 300 sec/km (5:00 /km)
            elapsedTime: 3050,
            totalElevationGain: 45.0,
            startDate: '2026-05-23T07:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.2,
          ),
        ];

        final activities = await repository.getAllActivities();
        final activity = activities.first;

        check(activity.distanceKm).equals(10.0);
        check(activity.movingTime).equals(const Duration(seconds: 3000));
        check(activity.pace).equals(const Duration(seconds: 300));
        check(activity.paceString).equals('5:00 /km');
        check(activity.elevationGainM).equals(45.0);
        check(activity.type).equals(ActivityType.run);
      },
    );

    // Test T-REPO-07
    test('computes training load based on max HR ratio', () async {
      fakeTokens.tokens = null;
      fakePrefs.preferences = const HrPreferences(maxHr: 200, restingHr: 60);

      // easy: < 70% (e.g. 130 bpm -> 65%)
      // moderate: 70-79% (e.g. 150 bpm -> 75%)
      // hard: 80-89% (e.g. 170 bpm -> 85%)
      // veryHard: >= 90% (e.g. 190 bpm -> 95%)
      fakeLocal.storedActivities = [
        const ActivityModel(
          id: 1,
          name: 'Easy',
          type: 'Run',
          distance: 5000,
          movingTime: 1500,
          elapsedTime: 1500,
          totalElevationGain: 0,
          startDate: '2026-05-01T00:00:00Z',
          averageSpeed: 3.3,
          maxSpeed: 4.0,
          averageHeartrate: 130.0,
        ),
        const ActivityModel(
          id: 2,
          name: 'Moderate',
          type: 'Run',
          distance: 5000,
          movingTime: 1500,
          elapsedTime: 1500,
          totalElevationGain: 0,
          startDate: '2026-05-02T00:00:00Z',
          averageSpeed: 3.3,
          maxSpeed: 4.0,
          averageHeartrate: 150.0,
        ),
        const ActivityModel(
          id: 3,
          name: 'Hard',
          type: 'Run',
          distance: 5000,
          movingTime: 1500,
          elapsedTime: 1500,
          totalElevationGain: 0,
          startDate: '2026-05-03T00:00:00Z',
          averageSpeed: 3.3,
          maxSpeed: 4.0,
          averageHeartrate: 170.0,
        ),
        const ActivityModel(
          id: 4,
          name: 'Very Hard',
          type: 'Run',
          distance: 5000,
          movingTime: 1500,
          elapsedTime: 1500,
          totalElevationGain: 0,
          startDate: '2026-05-04T00:00:00Z',
          averageSpeed: 3.3,
          maxSpeed: 4.0,
          averageHeartrate: 190.0,
        ),
      ];

      final activities = await repository.getAllActivities();

      check(
        activities.firstWhere((a) => a.id == 1).trainingLoad,
      ).equals(TrainingLoad.easy);
      check(
        activities.firstWhere((a) => a.id == 2).trainingLoad,
      ).equals(TrainingLoad.moderate);
      check(
        activities.firstWhere((a) => a.id == 3).trainingLoad,
      ).equals(TrainingLoad.hard);
      check(
        activities.firstWhere((a) => a.id == 4).trainingLoad,
      ).equals(TrainingLoad.veryHard);
    });

    test(
      'maps perceivedExertion from ActivityModel to Activity entity',
      () async {
        fakeTokens.tokens = null;
        fakeLocal.storedActivities = [
          const ActivityModel(
            id: 99,
            name: 'Manual RPE Run',
            type: 'Run',
            distance: 5000.0,
            movingTime: 1500,
            elapsedTime: 1500,
            totalElevationGain: 10.0,
            startDate: '2026-05-15T08:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.0,
            perceivedExertion: 7.5,
          ),
        ];

        final activities = await repository.getAllActivities();
        check(activities.first.perceivedExertion).equals(7.5);
      },
    );
  });

  group('ActivityRepositoryImpl - Authenticated Flow & Remote Errors', () {
    late FakeStravaActivityDataSource fakeRemote;
    late FakeLocalActivityDataSource fakeLocal;
    late FakePreferencesStorage fakePrefs;
    late FakeTokenStorage fakeTokens;
    late ActivityRepositoryImpl repository;

    setUp(() {
      fakeRemote = FakeStravaActivityDataSource();
      fakeLocal = FakeLocalActivityDataSource();
      fakePrefs = FakePreferencesStorage();
      fakeTokens = FakeTokenStorage();

      repository = ActivityRepositoryImpl(
        remoteDataSource: fakeRemote,
        localDataSource: fakeLocal,
        preferencesStorage: fakePrefs,
        tokenStorage: fakeTokens,
      );
    });

    // Test T-REPO-08
    test(
      'getAllActivities fetches and caches remote data when authenticated and local store is empty',
      () async {
        fakeTokens.tokens = const StravaTokens(
          accessToken: 'valid_access',
          refreshToken: 'valid_refresh',
          expiresAt: 9999999999,
        );
        fakeLocal.storedActivities = [];
        fakeRemote.remoteActivities = [
          const ActivityModel(
            id: 501,
            name: 'Remote Cloud Run',
            type: 'Run',
            distance: 7000.0,
            movingTime: 2100,
            elapsedTime: 2200,
            totalElevationGain: 35.0,
            startDate: '2026-05-24T06:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.1,
          ),
        ];

        final result = await repository.getAllActivities();

        check(fakeRemote.getAllActivitiesCallCount).equals(1);
        check(fakeLocal.saveActivitiesCallCount).equals(1);
        check(result).length.equals(1);
        check(result.first.id).equals(501);
      },
    );

    // Test T-REPO-09
    test(
      'getAllActivities wraps StravaApiException into ServerFailure when authenticated',
      () async {
        fakeTokens.tokens = const StravaTokens(
          accessToken: 'valid_access',
          refreshToken: 'valid_refresh',
          expiresAt: 9999999999,
        );
        fakeLocal.storedActivities = [];
        fakeRemote.errorToThrow = StravaApiException(
          500,
          'Internal Server Error',
        );

        await check(repository.getAllActivities()).throws<ServerFailure>();
      },
    );

    group('uploadActivity (Milestone 5: Selective Push Upload)', () {
      test(
        'uploadActivity pushes local activity (id < 0) to Strava, updates local ID to remote ID, and preserves local attributes',
        () async {
          fakeTokens.tokens = const StravaTokens(
            accessToken: 'valid_access',
            refreshToken: 'valid_refresh',
            expiresAt: 9999999999,
          );
          fakeLocal.storedActivities = [
            const ActivityModel(
              id: -42,
              name: 'My Morning Jog',
              type: 'Run',
              distance: 5200.0,
              movingTime: 1600,
              elapsedTime: 1700,
              totalElevationGain: 25.0,
              startDate: '2026-05-25T07:00:00Z',
              averageSpeed: 3.25,
              maxSpeed: 4.2,
              perceivedExertion: 6,
            ),
          ];
          fakeRemote.createdActivityToReturn = const ActivityModel(
            id: 998877,
            name: 'My Morning Jog',
            type: 'Run',
            distance: 5200.0,
            movingTime: 1600,
            elapsedTime: 1700,
            totalElevationGain: 25.0,
            startDate: '2026-05-25T07:00:00Z',
            averageSpeed: 3.25,
            maxSpeed: 4.2,
          );

          final result = await repository.uploadActivity(-42);

          check(fakeRemote.createActivityCallCount).equals(1);
          check(fakeLocal.updateLocalActivityIdCallCount).equals(1);
          check(result.id).equals(998877);
          check(result.isLocal).isFalse();
          check(result.name).equals('My Morning Jog');

          // Local storage updated: old negative ID removed, new remote ID stored
          check(fakeLocal.storedActivities.any((a) => a.id == -42)).isFalse();
          check(fakeLocal.storedActivities.any((a) => a.id == 998877)).isTrue();
          final stored = fakeLocal.storedActivities.firstWhere(
            (a) => a.id == 998877,
          );
          check(stored.perceivedExertion).equals(6);
        },
      );

      test(
        'uploadActivity prevents duplicate upload if activity ID is already non-negative',
        () async {
          fakeTokens.tokens = const StravaTokens(
            accessToken: 'valid_access',
            refreshToken: 'valid_refresh',
            expiresAt: 9999999999,
          );
          fakeLocal.storedActivities = [
            const ActivityModel(
              id: 5001,
              name: 'Already Synced Run',
              type: 'Run',
              distance: 10000.0,
              movingTime: 3000,
              elapsedTime: 3100,
              totalElevationGain: 50.0,
              startDate: '2026-05-25T07:00:00Z',
              averageSpeed: 3.33,
              maxSpeed: 4.5,
            ),
          ];

          final result = await repository.uploadActivity(5001);

          // Does NOT call remote createActivity
          check(fakeRemote.createActivityCallCount).equals(0);
          check(fakeLocal.updateLocalActivityIdCallCount).equals(0);
          check(result.id).equals(5001);
          check(result.isLocal).isFalse();
        },
      );

      test(
        'uploadActivity throws AuthenticationFailure when unauthenticated',
        () async {
          fakeTokens.tokens = null;
          fakeLocal.storedActivities = [
            const ActivityModel(
              id: -10,
              name: 'Offline Run',
              type: 'Run',
              distance: 5000.0,
              movingTime: 1500,
              elapsedTime: 1600,
              totalElevationGain: 20.0,
              startDate: '2026-05-25T07:00:00Z',
              averageSpeed: 3.33,
              maxSpeed: 4.0,
            ),
          ];

          await check(
            repository.uploadActivity(-10),
          ).throws<UnauthenticatedException>();
          check(fakeRemote.createActivityCallCount).equals(0);
        },
      );

      test(
        'uploadActivity throws ServerFailure on HTTP 429 rate limit without mutating local store',
        () async {
          fakeTokens.tokens = const StravaTokens(
            accessToken: 'valid_access',
            refreshToken: 'valid_refresh',
            expiresAt: 9999999999,
          );
          fakeLocal.storedActivities = [
            const ActivityModel(
              id: -55,
              name: 'Local Run Before Rate Limit',
              type: 'Run',
              distance: 5000.0,
              movingTime: 1500,
              elapsedTime: 1600,
              totalElevationGain: 20.0,
              startDate: '2026-05-25T07:00:00Z',
              averageSpeed: 3.33,
              maxSpeed: 4.0,
            ),
          ];
          fakeRemote.errorToThrow = StravaApiException(
            429,
            'Rate Limit Exceeded',
          );

          await check(repository.uploadActivity(-55)).throws<ServerFailure>();
          check(fakeRemote.createActivityCallCount).equals(1);
          check(fakeLocal.updateLocalActivityIdCallCount).equals(0);

          // Local activity is preserved safe and intact
          check(fakeLocal.storedActivities.any((a) => a.id == -55)).isTrue();
        },
      );
    });
  });

  group('ActivityRepositoryImpl - Zero-TTL SSOT & saveActivity (Ticket 01)', () {
    late FakeStravaActivityDataSource fakeRemote;
    late FakeLocalActivityDataSource fakeLocal;
    late FakePreferencesStorage fakePrefs;
    late FakeTokenStorage fakeTokens;
    late ActivityRepositoryImpl repository;

    setUp(() {
      fakeRemote = FakeStravaActivityDataSource();
      fakeLocal = FakeLocalActivityDataSource();
      fakePrefs = FakePreferencesStorage();
      fakeTokens = FakeTokenStorage();

      repository = ActivityRepositoryImpl(
        remoteDataSource: fakeRemote,
        localDataSource: fakeLocal,
        preferencesStorage: fakePrefs,
        tokenStorage: fakeTokens,
      );
    });

    test(
      'saveActivity maps domain Activity to ActivityModel and commits to local store with negative ID preserved',
      () async {
        final activity = Activity(
          id: -12345678,
          name: 'Track Workout',
          date: DateTime.utc(2026, 5, 20, 6, 30),
          type: ActivityType.run,
          distanceKm: 6.0,
          movingTime: const Duration(minutes: 30),
          pace: const Duration(minutes: 5),
          elevationGainM: 15.0,
          trainingLoad: TrainingLoad.moderate,
          avgHeartRate: 155.0,
          maxHeartRate: 175.0,
          avgCadence: 86.0,
          sufferScore: 35,
          perceivedExertion: 8.0,
        );

        await repository.saveActivity(activity);

        check(fakeLocal.saveActivityCallCount).equals(1);
        check(fakeLocal.storedActivities.length).equals(1);

        final saved = fakeLocal.storedActivities.first;
        check(saved.id).equals(-12345678);
        check(saved.name).equals('Track Workout');
        check(saved.type).equals('Run');
        check(saved.distance).equals(6000.0);
        check(saved.movingTime).equals(1800);
        check(saved.elapsedTime).equals(1800);
        check(saved.totalElevationGain).equals(15.0);
        check(
          saved.startDate,
        ).equals(DateTime.utc(2026, 5, 20, 6, 30).toIso8601String());
        check(saved.averageSpeed).equals(6000.0 / 1800);
        check(saved.averageHeartrate).equals(155.0);
        check(saved.maxHeartrate).equals(175.0);
        check(saved.averageCadence).equals(86.0);
        check(saved.sufferScore).equals(35);
        check(saved.perceivedExertion).equals(8.0);
        check(saved.hasHeartrate).isTrue();
      },
    );

    test(
      'saveActivity persists heartRateData stream to local store when present',
      () async {
        final activity = Activity(
          id: -999,
          name: 'Heart Rate Session',
          date: DateTime.utc(2026, 5, 21, 7, 0),
          type: ActivityType.run,
          distanceKm: 5.0,
          movingTime: const Duration(minutes: 25),
          pace: const Duration(minutes: 5),
          elevationGainM: 0.0,
          trainingLoad: TrainingLoad.easy,
          heartRateData: [130.0, 135.0, 140.0, 145.0],
        );

        await repository.saveActivity(activity);

        check(fakeLocal.saveHeartRateStreamCallCount).equals(1);
        check(fakeLocal.storedStreams).containsKey(-999);
        check(
          fakeLocal.storedStreams[-999]!,
        ).deepEquals([130.0, 135.0, 140.0, 145.0]);
      },
    );

    test(
      'saveActivity does not call saveHeartRateStream when heartRateData is null or empty',
      () async {
        final activity = Activity(
          id: -888,
          name: 'No HR Session',
          date: DateTime.utc(2026, 5, 21, 7, 0),
          type: ActivityType.run,
          distanceKm: 4.0,
          movingTime: const Duration(minutes: 20),
          pace: const Duration(minutes: 5),
          elevationGainM: 0.0,
          trainingLoad: TrainingLoad.easy,
          heartRateData: null,
        );

        await repository.saveActivity(activity);

        check(fakeLocal.saveActivityCallCount).equals(1);
        check(fakeLocal.saveHeartRateStreamCallCount).equals(0);
      },
    );

    test(
      'getAllActivities returns activities saved days/weeks ago without outbound remote calls when unauthenticated (Zero-TTL)',
      () async {
        fakeTokens.tokens = null; // Unauthenticated / guest / offline
        fakeLocal.storedActivities = [
          const ActivityModel(
            id: 10,
            name: 'Historical Run',
            type: 'Run',
            distance: 5000.0,
            movingTime: 1500,
            elapsedTime: 1500,
            totalElevationGain: 10.0,
            startDate: '2026-04-01T08:00:00Z',
            averageSpeed: 3.33,
            maxSpeed: 4.0,
          ),
        ];

        final result = await repository.getAllActivities();

        check(result.length).equals(1);
        check(result.first.id).equals(10);
        check(result.first.name).equals('Historical Run');
        check(fakeRemote.getAllActivitiesCallCount).equals(0);
      },
    );

    test(
      'getAllActivities derives TrainingLoad from RPE when averageHeartrate is null',
      () async {
        fakeTokens.tokens = null;
        fakeLocal.storedActivities = [
          const ActivityModel(
            id: 1,
            name: 'Easy RPE Run',
            type: 'Run',
            distance: 3000.0,
            movingTime: 1800,
            elapsedTime: 1800,
            totalElevationGain: 0.0,
            startDate: '2026-04-01T08:00:00Z',
            averageSpeed: 1.67,
            maxSpeed: 2.0,
            perceivedExertion: 4.0,
          ),
          const ActivityModel(
            id: 2,
            name: 'Moderate RPE Run',
            type: 'Run',
            distance: 6000.0,
            movingTime: 3600,
            elapsedTime: 3600,
            totalElevationGain: 0.0,
            startDate: '2026-04-02T08:00:00Z',
            averageSpeed: 1.67,
            maxSpeed: 2.0,
            perceivedExertion: 7.0,
          ),
          const ActivityModel(
            id: 3,
            name: 'Hard RPE Run',
            type: 'Run',
            distance: 8000.0,
            movingTime: 3600,
            elapsedTime: 3600,
            totalElevationGain: 0.0,
            startDate: '2026-04-03T08:00:00Z',
            averageSpeed: 2.22,
            maxSpeed: 2.5,
            perceivedExertion: 9.0,
          ),
          const ActivityModel(
            id: 4,
            name: 'Very Hard RPE Run',
            type: 'Run',
            distance: 12000.0,
            movingTime: 5400,
            elapsedTime: 5400,
            totalElevationGain: 0.0,
            startDate: '2026-04-04T08:00:00Z',
            averageSpeed: 2.22,
            maxSpeed: 2.5,
            perceivedExertion: 9.0,
          ),
        ];

        final result = await repository.getAllActivities();

        check(result.length).equals(4);
        check(result[0].trainingLoad).equals(TrainingLoad.easy);
        check(result[1].trainingLoad).equals(TrainingLoad.moderate);
        check(result[2].trainingLoad).equals(TrainingLoad.hard);
        check(result[3].trainingLoad).equals(TrainingLoad.veryHard);
      },
    );
  });
}
