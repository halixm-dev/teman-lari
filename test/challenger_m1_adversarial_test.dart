import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:teman_lari/core/errors/exceptions.dart';
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

/// Spy/Mock remote data source that tracks every single invocation and allows injecting delays or errors.
class SpyStravaActivityDataSource implements StravaActivityDataSource {
  int getAllActivitiesCalls = 0;
  int getActivityStreamsCalls = 0;
  int getAthleteCalls = 0;

  List<ActivityModel> activitiesToReturn = [];
  Exception? exceptionToThrow;
  Duration simulatedDelay = Duration.zero;

  @override
  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async {
    getAllActivitiesCalls++;
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return activitiesToReturn;
  }

  @override
  Future<ActivityStreams> getActivityStreams(int activityId) async {
    getActivityStreamsCalls++;
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return const ActivityStreams();
  }

  @override
  Future<AthleteModel> getAthlete() async {
    getAthleteCalls++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return const AthleteModel(id: 1, firstName: 'SpyAthlete');
  }

  @override
  Future<ActivityModel> createActivity({
    required String name,
    required String type,
    required String startDateLocal,
    required int elapsedTime,
    double? distance,
    String? description,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return ActivityModel(
      id: 99999,
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

/// Hostile token storage configurable to return null, empty tokens, valid tokens, or throw arbitrary exceptions.
class HostileTokenStorage extends TokenStorage {
  StravaTokens? currentTokens;
  Exception? exceptionToThrow;

  @override
  Future<StravaTokens?> getTokens() async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return currentTokens;
  }

  @override
  Future<void> saveTokens(StravaTokens tokens) async {
    currentTokens = tokens;
  }

  @override
  Future<void> clearTokens() async {
    currentTokens = null;
  }
}

class StaticPreferencesStorage extends PreferencesStorage {
  final HrPreferences prefs;
  StaticPreferencesStorage([
    this.prefs = const HrPreferences(maxHr: 190, restingHr: 60),
  ]);

  @override
  Future<HrPreferences> getPreferences() async => prefs;
}

ActivityModel createSampleModel(
  int id, {
  String name = 'Run',
  String startDate = '2026-05-20T08:00:00Z',
}) {
  return ActivityModel(
    id: id,
    name: name,
    type: 'Run',
    distance: 5000.0,
    movingTime: 1500,
    elapsedTime: 1600,
    totalElevationGain: 25.0,
    startDate: startDate,
    averageSpeed: 3.33,
    maxSpeed: 4.2,
    averageHeartrate: 150.0,
    maxHeartrate: 170.0,
    averageCadence: 84.0,
    sufferScore: 20,
    hasHeartrate: true,
  );
}

void main() {
  late Directory tempDir;
  late LocalActivityDataSource localDataSource;
  late SpyStravaActivityDataSource spyRemote;
  late HostileTokenStorage hostileTokens;
  late StaticPreferencesStorage preferencesStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('challenger_stress_');
    Hive.init(tempDir.path);
    localDataSource = LocalActivityDataSource();
    spyRemote = SpyStravaActivityDataSource();
    hostileTokens = HostileTokenStorage();
    preferencesStorage = StaticPreferencesStorage();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ActivityRepositoryImpl buildRepo({TokenStorage? customTokenStorage}) {
    return ActivityRepositoryImpl(
      remoteDataSource: spyRemote,
      localDataSource: localDataSource,
      preferencesStorage: preferencesStorage,
      tokenStorage: customTokenStorage ?? hostileTokens,
    );
  }

  group('Adversarial Challenge 1: Zero Outbound Cloud Calls When Unauthenticated', () {
    test(
      'TokenStorage is null: 0 outbound cloud calls across all repo operations',
      () async {
        final repo = buildRepo(customTokenStorage: null);

        // 1. getAllActivities on empty store
        final result1 = await repo.getAllActivities();
        check(result1).isEmpty();
        check(spyRemote.getAllActivitiesCalls).equals(0);

        // 2. refreshActivities
        await repo.refreshActivities();
        check(spyRemote.getAllActivitiesCalls).equals(0);

        // 3. getHeartRateStreams
        final hrStreams = await repo.getHeartRateStreams([101, 102, 103]);
        check(hrStreams).isEmpty();
        check(spyRemote.getActivityStreamsCalls).equals(0);
      },
    );

    test(
      'TokenStorage returns null: exactly 0 remote calls even when requested repeatedly',
      () async {
        hostileTokens.currentTokens = null;
        final repo = buildRepo();

        for (var i = 0; i < 5; i++) {
          final activities = await repo.getAllActivities();
          check(activities).isEmpty();
        }
        await repo.refreshActivities();
        await repo.getHeartRateStreams([1, 2, 3]);

        check(spyRemote.getAllActivitiesCalls).equals(0);
        check(spyRemote.getActivityStreamsCalls).equals(0);
        check(spyRemote.getAthleteCalls).equals(0);
      },
    );

    test(
      'TokenStorage returns empty accessToken (""): treated strictly as unauthenticated',
      () async {
        hostileTokens.currentTokens = const StravaTokens(
          accessToken: '',
          refreshToken: 'refresh_only',
          expiresAt: 9999999999,
        );
        final repo = buildRepo();

        final activities = await repo.getAllActivities();
        check(activities).isEmpty();
        await repo.refreshActivities();
        await repo.getHeartRateStreams([99]);

        check(spyRemote.getAllActivitiesCalls).equals(0);
        check(spyRemote.getActivityStreamsCalls).equals(0);
      },
    );

    test(
      'TokenStorage throws unexpected Exception (e.g. disk or keychain error): treated as unauthenticated without crashing',
      () async {
        hostileTokens.exceptionToThrow = const FileSystemException(
          'Secure storage locked / disk IO failure',
        );
        final repo = buildRepo();

        // Must catch gracefully, treat as unauthenticated, make 0 remote calls, and return local data
        final activities = await repo.getAllActivities();
        check(activities).isEmpty();
        check(spyRemote.getAllActivitiesCalls).equals(0);

        await repo.refreshActivities();
        check(spyRemote.getAllActivitiesCalls).equals(0);
      },
    );

    test(
      'Unauthenticated mode returns local cached data while guaranteeing zero network calls',
      () async {
        hostileTokens.currentTokens = null;
        // Pre-populate Hive with local run and offline run
        await localDataSource.saveActivity(
          createSampleModel(-500, name: 'Offline Run'),
        );
        await localDataSource.saveActivity(
          createSampleModel(200, name: 'Pre-existing Run'),
        );
        await localDataSource.saveHeartRateStream(-500, [140.0, 145.0]);

        final repo = buildRepo();

        final activities = await repo.getAllActivities();
        check(activities).length.equals(2);
        check(activities.any((a) => a.id == -500)).isTrue();
        check(activities.any((a) => a.id == 200)).isTrue();
        check(spyRemote.getAllActivitiesCalls).equals(0);

        final streams = await repo.getHeartRateStreams([-500, 999]);
        check(streams).containsKey(-500);
        check(streams).not((it) => it.containsKey(999));
        check(spyRemote.getActivityStreamsCalls).equals(0);
      },
    );
  });

  group('Adversarial Challenge 2: Zero UnauthenticatedException Leaks to Caller', () {
    test(
      'Remote throws UnauthenticatedException during getAllActivities(): 0 leaks, safely returns local fallback',
      () async {
        // Authenticated tokens exist, but token is revoked on remote server
        hostileTokens.currentTokens = const StravaTokens(
          accessToken: 'revoked_token',
          refreshToken: 'refresh',
          expiresAt: 9999999999,
        );
        spyRemote.exceptionToThrow = UnauthenticatedException();

        final repo = buildRepo();

        // Case A: Local store is empty
        final emptyResult = await repo.getAllActivities();
        check(emptyResult).isNotNull();
        check(emptyResult).isEmpty();
        check(spyRemote.getAllActivitiesCalls).equals(1);

        // Case B: Local store has data
        await localDataSource.saveActivity(
          createSampleModel(-101, name: 'Safe Local Run'),
        );
        // Note: If local store has data, getAllActivities serves local first without even calling remote!
        final populatedResult = await repo.getAllActivities();
        check(populatedResult).length.equals(1);
        check(populatedResult.first.id).equals(-101);
      },
    );

    test(
      'Remote throws UnauthenticatedException during refreshActivities(): 0 leaks, completes silently',
      () async {
        hostileTokens.currentTokens = const StravaTokens(
          accessToken: 'expired_token',
          refreshToken: 'refresh',
          expiresAt: 9999999999,
        );
        spyRemote.exceptionToThrow = UnauthenticatedException();

        final repo = buildRepo();

        // Calling refreshActivities must NOT throw UnauthenticatedException to the caller
        await repo.refreshActivities();
        check(spyRemote.getAllActivitiesCalls).equals(1);
      },
    );

    test(
      'Remote throws UnauthenticatedException during getHeartRateStreams(): 0 leaks, non-blocking stream retrieval',
      () async {
        hostileTokens.currentTokens = const StravaTokens(
          accessToken: 'expired_token',
          refreshToken: 'refresh',
          expiresAt: 9999999999,
        );
        spyRemote.exceptionToThrow = UnauthenticatedException();

        final repo = buildRepo();

        // Uncached ID 999 requests stream from remote which throws UnauthenticatedException
        final streams = await repo.getHeartRateStreams([999]);
        check(streams).isEmpty();
        check(spyRemote.getActivityStreamsCalls).equals(1);
      },
    );
  });

  group(
    'Adversarial Challenge 3: Empty Store Invariants & Malformed Resilience',
    () {
      test('Empty store returns [] with exact type List<Activity>', () async {
        hostileTokens.currentTokens = null;
        final repo = buildRepo();

        final result = await repo.getAllActivities();
        check(result).isA<List<Activity>>();
        check(result).isEmpty();
      });

      test(
        'clearCache() resets store, subsequent getAllActivities() returns []',
        () async {
          await localDataSource.saveActivity(createSampleModel(101));
          await localDataSource.saveActivity(createSampleModel(102));

          var activities = await localDataSource.getAllActivities();
          check(activities).length.equals(2);

          await localDataSource.clearCache();

          activities = await localDataSource.getAllActivities();
          check(activities).isEmpty();

          final repo = buildRepo();
          final repoActivities = await repo.getAllActivities();
          check(repoActivities).isEmpty();
        },
      );

      test(
        'Malformed JSON in Hive box does not crash getAllActivities; returns [] safely',
        () async {
          // Inject corrupt entry directly into activities box
          final box = await localDataSource.activitiesBox;
          await box.put(999, {
            'id': 999,
            'data': 'NOT_A_VALID_JSON_STRING{{{corrupted',
            'synced_at': DateTime.now().millisecondsSinceEpoch,
          });

          // LocalActivityDataSource.getAllActivities() catches FormatException and returns []
          final local = await localDataSource.getAllActivities();
          check(local).isEmpty();

          final repo = buildRepo();
          final repoActivities = await repo.getAllActivities();
          check(repoActivities).isEmpty();
        },
      );
    },
  );

  group('Adversarial Challenge 4: Concurrency & Stress Harness', () {
    test(
      '100 concurrent getAllActivities() calls execute without race condition on cold box',
      () async {
        hostileTokens.currentTokens = null;
        final repo = buildRepo();

        // Launch 100 simultaneous calls to getAllActivities() before Hive box is even opened
        final futures = List.generate(100, (_) => repo.getAllActivities());
        final results = await Future.wait(futures);

        check(results.length).equals(100);
        for (final res in results) {
          check(res).isEmpty();
        }
      },
    );

    test(
      '50 concurrent reads interleaved with 20 concurrent writes do not cause deadlock or corruption',
      () async {
        hostileTokens.currentTokens = null;
        final repo = buildRepo();

        // Interleave simultaneous writes and reads
        final writeFutures = List.generate(20, (i) {
          return localDataSource.saveActivity(
            createSampleModel(-1000 - i, name: 'Concurrent Run $i'),
          );
        });

        final readFutures = List.generate(50, (_) => repo.getAllActivities());

        await Future.wait([...writeFutures, ...readFutures]);

        final finalActivities = await repo.getAllActivities();
        check(finalActivities.length).equals(20);
      },
    );

    test(
      '50 concurrent authenticated calls with delayed remote response do not crash',
      () async {
        hostileTokens.currentTokens = const StravaTokens(
          accessToken: 'valid_token',
          refreshToken: 'refresh',
          expiresAt: 9999999999,
        );
        spyRemote.simulatedDelay = const Duration(milliseconds: 50);
        spyRemote.activitiesToReturn = [
          createSampleModel(501, name: 'Fetched Run 1'),
          createSampleModel(502, name: 'Fetched Run 2'),
        ];

        final repo = buildRepo();

        final futures = List.generate(50, (_) => repo.getAllActivities());
        final results = await Future.wait(futures);

        check(results.length).equals(50);
        for (final res in results) {
          check(res).length.equals(2);
        }
      },
    );

    test(
      '10 concurrent updateLocalActivityId operations execute safely',
      () async {
        for (var i = 0; i < 10; i++) {
          await localDataSource.saveActivity(
            createSampleModel(-2000 - i, name: 'Local Workout $i'),
          );
          await localDataSource.saveHeartRateStream(-2000 - i, [
            140.0 + i,
            150.0 + i,
          ]);
        }

        final updateFutures = List.generate(10, (i) {
          final newRemoteModel = createSampleModel(
            8000000000 + i,
            name: 'Uploaded Workout $i',
          );
          return localDataSource.updateLocalActivityId(
            -2000 - i,
            newRemoteModel,
          );
        });

        await Future.wait(updateFutures);

        final all = await localDataSource.getAllActivities();
        check(all.length).equals(10);
        for (var i = 0; i < 10; i++) {
          check(all.any((a) => a.id == 8000000000 + i)).isTrue();
          check(all.any((a) => a.id == -2000 - i)).isFalse();
        }

        final streams = await localDataSource.getAllHeartRateStreams();
        for (var i = 0; i < 10; i++) {
          check(streams).containsKey(8000000000 + i);
          check(streams).not((it) => it.containsKey(-2000 - i));
        }
      },
    );
  });

  group(
    'Adversarial Challenge 5: SafeBox String & Negative Key Edge Cases',
    () {
      test(
        'String and Int representations of negative keys interact seamlessly',
        () async {
          final box = await localDataSource.activitiesBox;

          // Put via int key
          await box.put(-404, {'status': 'offline'});

          check(box.containsKey(-404)).isTrue();
          check(box.containsKey('-404')).isTrue();
          check(box.get(-404)).isNotNull();
          check(box.get('-404')).isNotNull();

          // Put via String key
          await box.put('-505', {'status': 'offline_str'});
          check(box.containsKey(-505)).isTrue();
          check(box.containsKey('-505')).isTrue();
          check(box.get(-505)).isNotNull();
          check(box.get('-505')).isNotNull();

          // Delete via String key
          await box.delete('-404');
          check(box.containsKey(-404)).isFalse();
          check(box.containsKey('-404')).isFalse();

          // Delete via int key
          await box.delete(-505);
          check(box.containsKey(-505)).isFalse();
          check(box.containsKey('-505')).isFalse();
        },
      );

      test(
        'Non-numeric String keys are preserved verbatim and not mangled',
        () async {
          final box = await localDataSource.activitiesBox;

          await box.put('app_setting_sync_mode', {'mode': 'manual'});
          await box.put('user_theme_preference', 'dark');

          check(box.containsKey('app_setting_sync_mode')).isTrue();
          check(box.get('app_setting_sync_mode')).isNotNull();
          check(box.get('user_theme_preference')).equals('dark');

          final keys = box.keys.toList();
          check(keys).contains('app_setting_sync_mode');
          check(keys).contains('user_theme_preference');
        },
      );
    },
  );
}
