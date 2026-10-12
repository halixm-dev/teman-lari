import 'dart:convert';
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

class FailingStravaDataSource implements StravaActivityDataSource {
  int callCount = 0;
  Exception? exceptionToThrow;

  @override
  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async {
    callCount++;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    throw UnauthenticatedException();
  }

  @override
  Future<ActivityStreams> getActivityStreams(int activityId) async {
    callCount++;
    throw UnauthenticatedException();
  }

  @override
  Future<AthleteModel> getAthlete() async {
    throw UnauthenticatedException();
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
    callCount++;
    if (exceptionToThrow != null) throw exceptionToThrow!;
    throw UnauthenticatedException();
  }
}

class TestTokenStorage extends TokenStorage {
  StravaTokens? tokens;

  @override
  Future<StravaTokens?> getTokens() async => tokens;

  @override
  Future<void> saveTokens(StravaTokens tokens) async {
    this.tokens = tokens;
  }

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }
}

class TestPreferencesStorage extends PreferencesStorage {
  @override
  Future<HrPreferences> getPreferences() async =>
      const HrPreferences(maxHr: 190, restingHr: 60);
}

ActivityModel makeTestModel({
  required int id,
  String name = 'Test Run',
  String startDate = '2026-05-20T08:00:00Z',
  double distance = 5000.0,
}) {
  return ActivityModel(
    id: id,
    name: name,
    type: 'Run',
    distance: distance,
    movingTime: 1500,
    elapsedTime: 1550,
    totalElevationGain: 30.0,
    startDate: startDate,
    averageSpeed: 3.33,
    maxSpeed: 4.2,
    averageHeartrate: 145.0,
    maxHeartrate: 165.0,
    averageCadence: 84.0,
    sufferScore: 20,
    hasHeartrate: true,
  );
}

void main() {
  late Directory tempDir;
  late LocalActivityDataSource dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('m1_empirical_stress_');
    Hive.init(tempDir.path);
    dataSource = LocalActivityDataSource();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Group 1: Hive Key Boundary & Extreme Integer IDs', () {
    test('Stores and retrieves 0 (min unsigned 32-bit key)', () async {
      final model = makeTestModel(id: 0, name: 'Zero ID Run');
      await dataSource.saveActivity(model);

      final all = await dataSource.getAllActivities();
      check(all).length.equals(1);
      check(all.first.id).equals(0);

      final box = await dataSource.activitiesBox;
      check(box.containsKey(0)).isTrue();
      check(box.get(0)).isNotNull();
    });

    test(
      'Stores and retrieves 0xFFFFFFFF (4294967295, max unsigned 32-bit key)',
      () async {
        const id = 4294967295;
        final model = makeTestModel(id: id, name: 'Max 32-bit ID');
        await dataSource.saveActivity(model);

        final all = await dataSource.getAllActivities();
        check(all).length.equals(1);
        check(all.first.id).equals(id);

        final box = await dataSource.activitiesBox;
        check(box.containsKey(id)).isTrue();
        check(box.get(id)).isNotNull();
      },
    );

    test(
      'Stores and retrieves 0x100000000 (4294967296, first 33-bit key outside Hive int range)',
      () async {
        const id = 4294967296;
        final model = makeTestModel(id: id, name: 'First 33-bit ID');
        await dataSource.saveActivity(model);

        final all = await dataSource.getAllActivities();
        check(all).length.equals(1);
        check(all.first.id).equals(id);

        final box = await dataSource.activitiesBox;
        check(box.containsKey(id)).isTrue();
        check(box.containsKey(id.toString())).isTrue();
        check(box.get(id)).isNotNull();
        check(box.get(id.toString())).isNotNull();
      },
    );

    test('Stores and retrieves typical 41-bit Strava remote ID', () async {
      // Typical Strava IDs in 2026 are 11-12 digits, e.g., 14_892_104_992
      const id = 14892104992;
      final model = makeTestModel(id: id, name: 'Realistic Strava ID');
      await dataSource.saveActivity(model);

      final all = await dataSource.getAllActivities();
      check(all).length.equals(1);
      check(all.first.id).equals(id);

      final box = await dataSource.activitiesBox;
      check(box.containsKey(id)).isTrue();
      check(box.get(id)).isNotNull();
    });

    test(
      'Stores and retrieves 2^53 - 1 (9007199254740991, JS safe int limit)',
      () async {
        const id = 9007199254740991;
        final model = makeTestModel(id: id, name: 'JS Safe Int Max');
        await dataSource.saveActivity(model);

        final all = await dataSource.getAllActivities();
        check(all).length.equals(1);
        check(all.first.id).equals(id);

        final box = await dataSource.activitiesBox;
        check(box.containsKey(id)).isTrue();
        check(box.get(id)).isNotNull();
      },
    );

    test(
      'Stores and retrieves 2^63 - 1 (9223372036854775807, max signed 64-bit int)',
      () async {
        const id = 9223372036854775807;
        final model = makeTestModel(id: id, name: 'Max 64-bit signed ID');
        await dataSource.saveActivity(model);

        final all = await dataSource.getAllActivities();
        check(all).length.equals(1);
        check(all.first.id).equals(id);

        final box = await dataSource.activitiesBox;
        check(box.containsKey(id)).isTrue();
        check(box.get(id)).isNotNull();
      },
    );

    test('Stores and retrieves -1 (boundary negative integer)', () async {
      const id = -1;
      final model = makeTestModel(id: id, name: 'Minus 1 Run');
      await dataSource.saveActivity(model);

      final all = await dataSource.getAllActivities();
      check(all).length.equals(1);
      check(all.first.id).equals(id);

      final box = await dataSource.activitiesBox;
      check(box.containsKey(id)).isTrue();
      check(box.containsKey('-1')).isTrue();
      check(box.get(id)).isNotNull();
    });

    test(
      'Stores and retrieves realistic negative timestamp ID (-1773300000000)',
      () async {
        const id = -1773300000000;
        final model = makeTestModel(id: id, name: 'Offline Timestamp Run');
        await dataSource.saveActivity(model);

        final all = await dataSource.getAllActivities();
        check(all).length.equals(1);
        check(all.first.id).equals(id);

        final box = await dataSource.activitiesBox;
        check(box.containsKey(id)).isTrue();
        check(box.get(id)).isNotNull();
        check(box.get(id.toString())).isNotNull();
      },
    );

    test(
      'Stores and retrieves -2^63 (-9223372036854775808, min signed 64-bit int)',
      () async {
        final id = -9223372036854775807 - 1;
        final model = makeTestModel(id: id, name: 'Min 64-bit signed ID');
        await dataSource.saveActivity(model);

        final all = await dataSource.getAllActivities();
        check(all).length.equals(1);
        check(all.first.id).equals(id);

        final box = await dataSource.activitiesBox;
        check(box.containsKey(id)).isTrue();
        check(box.get(id)).isNotNull();
      },
    );
  });

  group('Group 2: SafeBox Direct Operations & Key Type Coercion Parity', () {
    test(
      'SafeBox.keys denormalizes negative and 64-bit string keys back to int',
      () async {
        final box = await dataSource.activitiesBox;
        await box.put(100, {'id': 100});
        await box.put(-500, {'id': -500});
        await box.put(5000000000, {'id': 5000000000});

        final keys = box.keys.toList();
        check(keys.length).equals(3);

        check(keys.every((k) => k is int)).isTrue();
        check(keys).contains(100);
        check(keys).contains(-500);
        check(keys).contains(5000000000);
      },
    );

    test('SafeBox.toMap() denormalizes keys to int', () async {
      final box = await dataSource.activitiesBox;
      await box.put(-999, {'name': 'Test'});
      await box.put(4294967297, {'name': 'Big'});

      final map = box.toMap();
      check(map.containsKey(-999)).isTrue();
      check(map.containsKey(4294967297)).isTrue();
      check(map[-999]!['name']).equals('Test');
      check(map[4294967297]!['name']).equals('Big');
    });

    test(
      'SafeBox.get and containsKey work interchangeably with int and String',
      () async {
        final box = await dataSource.activitiesBox;
        await box.put(-42, {'val': 1});
        await box.put(99, {'val': 2});

        check(box.containsKey(-42)).isTrue();
        check(box.containsKey('-42')).isTrue();
        check(box.get(-42)).isNotNull();
        check(box.get('-42')).isNotNull();

        check(box.containsKey(99)).isTrue();
        check(box.containsKey('99')).isTrue();
        check(box.get(99)).isNotNull();
        check(box.get('99')).isNotNull();
      },
    );

    test(
      'SafeBox.delete safely handles int and String keys without Frame.assertKey error',
      () async {
        final box = await dataSource.activitiesBox;
        await box.put(-777, {'data': 'offline'});
        check(box.containsKey(-777)).isTrue();

        await box.delete(-777);
        check(box.containsKey(-777)).isFalse();
        check(box.containsKey('-777')).isFalse();

        await box.put(-777, {'data': 'offline2'});
        check(box.containsKey(-777)).isTrue();

        await box.delete('-777');
        check(box.containsKey(-777)).isFalse();
        check(box.containsKey('-777')).isFalse();
      },
    );

    test('SafeBox.deleteAll safely deletes mixed keys', () async {
      final box = await dataSource.activitiesBox;
      await box.put(1, {'a': 1});
      await box.put(-10, {'b': 2});
      await box.put(8000000000, {'c': 3});

      check(box.length).equals(3);

      await box.deleteAll([1, -10, 8000000000]);
      check(box.length).equals(0);
      check(box.isEmpty).isTrue();
    });

    test(
      'SafeBox query on non-existent keys returns defaultValue or null without throwing',
      () async {
        final box = await dataSource.activitiesBox;
        check(box.get(-99999)).isNull();
        check(box.get('-99999')).isNull();
        check(box.get(99999999999)).isNull();
        check(box.get(-99999, defaultValue: 'fallback')).equals('fallback');
        check(box.containsKey(-99999)).isFalse();
        check(box.containsKey('-99999')).isFalse();
      },
    );

    test('SafeBox index operations (keyAt, getAt, putAt, deleteAt)', () async {
      final box = await dataSource.activitiesBox;
      await box.put(-300, {'name': 'Run A'});
      await box.put(6000000000, {'name': 'Run B'});

      check(box.length).equals(2);

      final key0 = box.keyAt(0);
      final key1 = box.keyAt(1);
      check(key0 is int).isTrue();
      check(key1 is int).isTrue();

      final val0 = box.getAt(0) as Map;
      check(val0).isNotNull();

      await box.putAt(0, {'name': 'Run A (Updated)'});
      final updated0 = box.getAt(0) as Map;
      check(updated0['name']).equals('Run A (Updated)');

      await box.deleteAt(1);
      check(box.length).equals(1);
    });
  });

  group(
    'Group 3: Zero-TTL Permanent SSOT Multi-Timeframe Retention & getCachedActivities Backwards Compatibility',
    () {
      test(
        'Zero-TTL retains activities across 1h, 24h, 30d, 365d, and 10yr timeframes',
        () async {
          final box = await dataSource.activitiesBox;
          final now = DateTime.now().millisecondsSinceEpoch;

          final ages = [
            Duration(hours: 1, minutes: 1),
            Duration(hours: 24),
            Duration(days: 30),
            Duration(days: 365),
            Duration(days: 3650),
          ];

          final models = <ActivityModel>[];
          for (var i = 0; i < ages.length; i++) {
            final model = makeTestModel(
              id: 1000 + i,
              name: 'Historical Run $i',
              startDate: DateTime.now().subtract(ages[i]).toIso8601String(),
            );
            models.add(model);
            await box.put(model.id, {
              'id': model.id,
              'data': jsonEncode(model.toJson()),
              'synced_at': now - ages[i].inMilliseconds,
            });
          }

          final cachedTtl = await dataSource.getCachedActivities(
            checkTtl: true,
          );
          check(cachedTtl).isNull();

          final cachedNoTtl = await dataSource.getCachedActivities(
            checkTtl: false,
          );
          check(cachedNoTtl).isNotNull();
          check(cachedNoTtl!.length).equals(5);

          final all = await dataSource.getAllActivities();
          check(all.length).equals(5);

          for (var i = 0; i < all.length - 1; i++) {
            final dateA = DateTime.parse(all[i].startDate);
            final dateB = DateTime.parse(all[i + 1].startDate);
            check(
              dateA.isAfter(dateB) || dateA.isAtSameMomentAs(dateB),
            ).isTrue();
          }
        },
      );

      test(
        'Zero-TTL retains heart rate streams older than 1 hour when checkTtl: false',
        () async {
          final box = await dataSource.hrStreamsBox;
          final twoDaysAgo = DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch;

          await box.put(501, {
            'activity_id': 501,
            'data': jsonEncode([130.0, 140.0, 150.0]),
            'synced_at': twoDaysAgo,
          });

          final cachedWithTtl = await dataSource.getCachedHeartRateStreams(
            checkTtl: true,
          );
          check(cachedWithTtl).isEmpty();

          final allStreams = await dataSource.getAllHeartRateStreams();
          check(allStreams).containsKey(501);
          check(allStreams[501]!).length.equals(3);
        },
      );
    },
  );

  group('Group 4: Atomic Re-keying & Heart Rate Stream Migration', () {
    test(
      'updateLocalActivityId seamlessly transitions extreme negative timestamp ID to 64-bit remote ID',
      () async {
        const localId = -1716200000000;
        const remoteId = 14892104992;

        final localRun = makeTestModel(
          id: localId,
          name: 'Offline Morning Run',
        );
        await dataSource.saveActivity(localRun);
        await dataSource.saveHeartRateStream(localId, [145.0, 155.0, 160.0]);

        final uploadedModel = localRun.copyWith(
          id: remoteId,
          name: 'Synced Morning Run',
        );
        await dataSource.updateLocalActivityId(localId, uploadedModel);

        final allActivities = await dataSource.getAllActivities();
        check(allActivities).length.equals(1);
        check(allActivities.first.id).equals(remoteId);
        check(allActivities.first.name).equals('Synced Morning Run');

        final actBox = await dataSource.activitiesBox;
        check(actBox.containsKey(localId)).isFalse();
        check(actBox.containsKey(localId.toString())).isFalse();
        check(actBox.containsKey(remoteId)).isTrue();

        final allStreams = await dataSource.getAllHeartRateStreams();
        check(allStreams).containsKey(remoteId);
        check(allStreams).not((it) => it.containsKey(localId));
        check(allStreams[remoteId]!).deepEquals([145.0, 155.0, 160.0]);
      },
    );

    test('updateLocalActivityId works without associated HR stream', () async {
      const localId = -500;
      const remoteId = 88888;
      final localRun = makeTestModel(id: localId, name: 'Run without HR');
      await dataSource.saveActivity(localRun);

      await dataSource.updateLocalActivityId(
        localId,
        localRun.copyWith(id: remoteId),
      );

      final all = await dataSource.getAllActivities();
      check(all).length.equals(1);
      check(all.first.id).equals(remoteId);
    });
  });

  group('Group 5: High-Volume Stress & Mixed ID Coexistence', () {
    test(
      'Correctly stores, sorts, and queries 500 mixed activities (negative IDs, 32-bit, 64-bit)',
      () async {
        final activities = <ActivityModel>[];
        final baseTime = DateTime.parse('2026-01-01T00:00:00Z');

        for (var i = 0; i < 500; i++) {
          int id;
          if (i % 3 == 0) {
            id = -(1700000000000 + i);
          } else if (i % 3 == 1) {
            id = 1000 + i;
          } else {
            id = 10000000000 + i;
          }

          activities.add(
            makeTestModel(
              id: id,
              name: 'Workout $i',
              startDate: baseTime.add(Duration(hours: i)).toIso8601String(),
              distance: 5000.0 + i,
            ),
          );
        }

        await dataSource.saveActivities(activities);

        final retrieved = await dataSource.getAllActivities();
        check(retrieved.length).equals(500);

        check(retrieved.first.id).equals(activities.last.id);
        check(retrieved.last.id).equals(activities.first.id);

        final box = await dataSource.activitiesBox;
        check(box.length).equals(500);

        check(box.containsKey(activities[0].id)).isTrue();
        check(box.containsKey(activities[250].id)).isTrue();
        check(box.containsKey(activities[499].id)).isTrue();
      },
    );
  });

  group('Group 6: ActivityRepositoryImpl Decoupled Unauthenticated Immunity', () {
    test(
      'Repository serves local data and NEVER calls remote when unauthenticated, even if remote throws',
      () async {
        final fakeRemote = FailingStravaDataSource();
        final fakeTokens = TestTokenStorage();
        final fakePrefs = TestPreferencesStorage();

        final repo = ActivityRepositoryImpl(
          remoteDataSource: fakeRemote,
          localDataSource: dataSource,
          preferencesStorage: fakePrefs,
          tokenStorage: fakeTokens,
        );

        await dataSource.saveActivity(
          makeTestModel(id: -100, name: 'Offline Run'),
        );
        await dataSource.saveActivity(
          makeTestModel(id: 200, name: 'Strava Run'),
        );

        final result = await repo.getAllActivities();
        check(result.length).equals(2);
        check(fakeRemote.callCount).equals(0);

        await repo.refreshActivities();
        check(fakeRemote.callCount).equals(0);

        await dataSource.saveHeartRateStream(-100, [150.0, 160.0]);
        final hrResult = await repo.getHeartRateStreams([-100, 999]);
        check(hrResult).containsKey(-100);
        check(hrResult[-100]!).deepEquals([150.0, 160.0]);
        check(fakeRemote.callCount).equals(0);
      },
    );
  });

  group('Group 7: Persistence Roundtrip & Disk Restart Simulation', () {
    test(
      'Data with mixed negative and 64-bit IDs persists across box close and reload',
      () async {
        final modelNeg = makeTestModel(id: -1773300000000, name: 'Offline Run');
        final model64 = makeTestModel(
          id: 14892104992,
          name: 'Strava 64-bit Run',
        );
        final model32 = makeTestModel(id: 101, name: 'Standard Run');

        await dataSource.saveActivity(modelNeg);
        await dataSource.saveActivity(model64);
        await dataSource.saveActivity(model32);
        await dataSource.saveHeartRateStream(modelNeg.id, [140.0, 150.0]);

        // Simulate full app shutdown: close Hive completely
        await Hive.close();

        // Simulate app restart: re-initialize Hive in same directory
        Hive.init(tempDir.path);
        final newDataSource = LocalActivityDataSource();

        final reloaded = await newDataSource.getAllActivities();
        check(reloaded.length).equals(3);
        check(reloaded.any((a) => a.id == -1773300000000)).isTrue();
        check(reloaded.any((a) => a.id == 14892104992)).isTrue();
        check(reloaded.any((a) => a.id == 101)).isTrue();

        final box = await newDataSource.activitiesBox;
        check(box.containsKey(-1773300000000)).isTrue();
        check(box.containsKey(14892104992)).isTrue();
        check(box.containsKey(101)).isTrue();

        final hrStreams = await newDataSource.getAllHeartRateStreams();
        check(hrStreams).containsKey(-1773300000000);
        check(hrStreams[-1773300000000]!).deepEquals([140.0, 150.0]);
      },
    );

    test('Special characters, emojis, and unicode preserved intact', () async {
      const specialName =
          '🏃‍♂️ Pagi Lari di GBK Senayan 🇮🇩 — 10K PB! "Quote" & <Special>';
      final model = makeTestModel(id: -999, name: specialName);

      await dataSource.saveActivity(model);

      final retrieved = await dataSource.getAllActivities();
      check(retrieved.length).equals(1);
      check(retrieved.first.name).equals(specialName);
    });

    test(
      'Tie-breaker chronological sorting with identical start times',
      () async {
        const sameTime = '2026-06-01T10:00:00Z';
        final model1 = makeTestModel(
          id: 100,
          name: 'Run 100',
          startDate: sameTime,
        );
        final model2 = makeTestModel(
          id: 200,
          name: 'Run 200',
          startDate: sameTime,
        );
        final model3 = makeTestModel(
          id: -300,
          name: 'Run -300',
          startDate: sameTime,
        );

        await dataSource.saveActivities([model1, model3, model2]);

        final all = await dataSource.getAllActivities();
        check(all.length).equals(3);
        // Tie breaker is b.id.compareTo(a.id), so 200 > 100 > -300
        check(all[0].id).equals(200);
        check(all[1].id).equals(100);
        check(all[2].id).equals(-300);
      },
    );

    test(
      'smartMergeActivities preserves local negative runs when merging remote runs',
      () async {
        final localRun = makeTestModel(id: -1001, name: 'Local Only');
        await dataSource.saveActivity(localRun);

        final remoteBatch = [
          makeTestModel(id: 501, name: 'Remote 501'),
          makeTestModel(id: 502, name: 'Remote 502'),
        ];

        await dataSource.smartMergeActivities(remoteBatch);

        final all = await dataSource.getAllActivities();
        check(all.length).equals(3);
        check(all.any((a) => a.id == -1001)).isTrue();
        check(all.any((a) => a.id == 501)).isTrue();
        check(all.any((a) => a.id == 502)).isTrue();
      },
    );
  });
}
