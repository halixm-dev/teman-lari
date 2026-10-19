import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/models/activity_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalActivityDataSource dataSource;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Create a temporary directory for Hive testing
    tempDir = await Directory.systemTemp.createTemp('hive_test_dir');
    Hive.init(tempDir.path);
    dataSource = LocalActivityDataSource();
  });

  tearDown(() async {
    // Close all boxes and delete the directory
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final mockActivities = [
    const ActivityModel(
      id: 101,
      name: 'Morning Run',
      type: 'Run',
      distance: 5000.0,
      movingTime: 1500,
      elapsedTime: 1600,
      totalElevationGain: 50.0,
      startDate: '2026-05-20T08:00:00Z',
      averageSpeed: 3.33,
      maxSpeed: 4.5,
      averageHeartrate: 150.0,
      maxHeartrate: 170.0,
      averageCadence: 85.0,
      sufferScore: 25,
      hasHeartrate: true,
    ),
    const ActivityModel(
      id: 102,
      name: 'Evening Jog',
      type: 'Run',
      distance: 8000.0,
      movingTime: 2400,
      elapsedTime: 2500,
      totalElevationGain: 80.0,
      startDate: '2026-05-20T18:00:00Z',
      averageSpeed: 3.33,
      maxSpeed: 4.2,
      averageHeartrate: 145.0,
      maxHeartrate: 165.0,
      averageCadence: 82.0,
      sufferScore: 30,
      hasHeartrate: true,
    ),
  ];

  group('LocalActivityDataSource - Hive Refactor Tests', () {
    test('unknown elevation survives closing and reopening storage', () async {
      final activity = mockActivities.first.copyWith(totalElevationGain: null);
      await dataSource.saveActivity(activity);
      await Hive.close();

      final restored = await LocalActivityDataSource().getAllActivities();
      check(restored).length.equals(1);
      check(restored.single.totalElevationGain).isNull();
      check(restored.single.startDate).equals('2026-05-20T08:00:00Z');
    });

    test(
      'saveActivities and getCachedActivities returns activities in descending ID order',
      () async {
        await dataSource.saveActivities(mockActivities);

        final cached = await dataSource.getCachedActivities();
        check(cached).isNotNull();
        check(cached!.length).equals(2);
        // Should be sorted by ID DESC: 102 first, then 101
        check(cached[0].id).equals(102);
        check(cached[1].id).equals(101);
      },
    );

    test(
      'getCachedActivities returns null if cache is older than 1 hour',
      () async {
        // Open the box directly to inject a stale entry
        final box = await dataSource.activitiesBox;
        final oneHourAndFiveMinutesAgo = DateTime.now()
            .subtract(const Duration(minutes: 65))
            .millisecondsSinceEpoch;

        await box.put(101, {
          'id': 101,
          'data': jsonEncode(mockActivities[0].toJson()),
          'synced_at': oneHourAndFiveMinutesAgo,
        });

        final cached = await dataSource.getCachedActivities();
        check(cached).isNull();
      },
    );

    test(
      'saveHeartRateStream and getCachedHeartRateStreams caches and retrieves streams',
      () async {
        final streamData = [140.0, 142.0, 145.0, 148.0, 150.0];
        await dataSource.saveHeartRateStream(101, streamData);

        final cached = await dataSource.getCachedHeartRateStreams();
        check(cached).containsKey(101);
        check(cached[101]!).deepEquals(streamData);
      },
    );

    test(
      'getCachedHeartRateStreams filters out streams older than 1 hour',
      () async {
        final box = await dataSource.hrStreamsBox;
        final oneHourAndFiveMinutesAgo = DateTime.now()
            .subtract(const Duration(minutes: 65))
            .millisecondsSinceEpoch;

        final streamData = [140.0, 142.0, 145.0, 148.0, 150.0];
        await box.put(101, {
          'activity_id': 101,
          'data': jsonEncode(streamData),
          'synced_at': oneHourAndFiveMinutesAgo,
        });

        final cached = await dataSource.getCachedHeartRateStreams();
        check(cached).not((it) => it.containsKey(101));
      },
    );

    test('clearCache removes all cached data', () async {
      await dataSource.saveActivities(mockActivities);
      await dataSource.saveHeartRateStream(101, [140.0, 142.0]);

      await dataSource.clearCache();

      // Check boxes directly or via dataSource
      final cachedActivities = await dataSource.getCachedActivities();
      check(cachedActivities).isNull();

      final cachedStreams = await dataSource.getCachedHeartRateStreams();
      check(cachedStreams).isEmpty();
    });
  });

  group('LocalActivityDataSource - Zero-TTL Permanent SSOT (getAllActivities)', () {
    test('getAllActivities returns empty list when box is empty', () async {
      final activities = await dataSource.getAllActivities();
      check(activities).isNotNull();
      check(activities).isEmpty();
    });

    test(
      'getAllActivities returns activities indefinitely even when cache is older than 1 hour (Zero-TTL)',
      () async {
        final box = await dataSource.activitiesBox;
        final twoDaysAgo = DateTime.now()
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch;

        await box.put(101, {
          'id': 101,
          'data': jsonEncode(mockActivities[0].toJson()),
          'synced_at': twoDaysAgo,
        });

        // Verification of TTL contrast:
        final cached = await dataSource.getCachedActivities();
        check(cached).isNull();

        // Zero-TTL permanent SSOT retrieves the record:
        final allActivities = await dataSource.getAllActivities();
        check(allActivities).length.equals(1);
        check(allActivities.first.id).equals(101);
        check(allActivities.first.name).equals('Morning Run');
      },
    );

    test(
      'getAllActivities returns activities sorted in descending ID order',
      () async {
        await dataSource.saveActivities(mockActivities); // IDs: 101, 102

        final activities = await dataSource.getAllActivities();
        check(activities).length.equals(2);
        check(activities[0].id).equals(102);
        check(activities[1].id).equals(101);
      },
    );

    test(
      'getAllActivities preserves negative local IDs alongside positive remote IDs',
      () async {
        const localActivity = ActivityModel(
          id: -1001,
          name: 'Local Offline Run',
          type: 'Run',
          distance: 6000.0,
          movingTime: 1800,
          elapsedTime: 1850,
          totalElevationGain: 30.0,
          startDate: '2026-05-19T07:00:00Z',
          averageSpeed: 3.33,
          maxSpeed: 4.0,
        );

        await dataSource.saveActivities([...mockActivities, localActivity]);

        final activities = await dataSource.getAllActivities();
        check(activities).length.equals(3);
        check(
          activities.map((a) => a.id).toList(),
        ).deepEquals([102, 101, -1001]);
      },
    );

    test(
      'getAllActivities returns activities saved weeks and months ago intact and chronologically sorted (Zero-TTL)',
      () async {
        final box = await dataSource.activitiesBox;
        final thirtyDaysAgoSync = DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch;
        final sevenDaysAgoSync = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;

        const oldRun = ActivityModel(
          id: 50,
          name: 'Month Old Run',
          type: 'Run',
          distance: 10000.0,
          movingTime: 3000,
          elapsedTime: 3100,
          totalElevationGain: 40.0,
          startDate: '2026-04-15T07:00:00Z',
          averageSpeed: 3.33,
          maxSpeed: 4.2,
        );

        const recentRun = ActivityModel(
          id: 51,
          name: 'Week Old Run',
          type: 'Run',
          distance: 5000.0,
          movingTime: 1500,
          elapsedTime: 1550,
          totalElevationGain: 20.0,
          startDate: '2026-05-10T07:00:00Z',
          averageSpeed: 3.33,
          maxSpeed: 4.0,
        );

        await box.put(50, {
          'id': 50,
          'data': jsonEncode(oldRun.toJson()),
          'synced_at': thirtyDaysAgoSync,
        });

        await box.put(51, {
          'id': 51,
          'data': jsonEncode(recentRun.toJson()),
          'synced_at': sevenDaysAgoSync,
        });

        // Stale cache returns null under 1-hour TTL
        final cached = await dataSource.getCachedActivities();
        check(cached).isNull();

        // Zero-TTL permanent SSOT retrieves all activities sorted chronologically descending
        final allActivities = await dataSource.getAllActivities();
        check(allActivities).length.equals(2);
        check(
          allActivities[0].id,
        ).equals(51); // 2026-05-10 is newer than 2026-04-15
        check(allActivities[1].id).equals(50);
      },
    );

    test(
      'getAllHeartRateStreams returns heart rate streams saved weeks ago without TTL eviction',
      () async {
        final box = await dataSource.hrStreamsBox;
        final fourteenDaysAgoSync = DateTime.now()
            .subtract(const Duration(days: 14))
            .millisecondsSinceEpoch;
        final streamData = [135.0, 145.0, 155.0, 165.0];

        await box.put(101, {
          'activity_id': 101,
          'data': jsonEncode(streamData),
          'synced_at': fourteenDaysAgoSync,
        });

        // 1-hour TTL check filters it out:
        final cachedTtl = await dataSource.getCachedHeartRateStreams(
          checkTtl: true,
        );
        check(cachedTtl).not((it) => it.containsKey(101));

        // Permanent Zero-TTL retrieval preserves stream indefinitely:
        final allStreams = await dataSource.getAllHeartRateStreams();
        check(allStreams).containsKey(101);
        check(allStreams[101]!).deepEquals(streamData);
      },
    );
  });

  group('LocalActivityDataSource - Single Activity Operations', () {
    test('saveActivity successfully stores a single activity', () async {
      const single = ActivityModel(
        id: -2001,
        name: 'Solo Treadmill Run',
        type: 'Run',
        distance: 4000.0,
        movingTime: 1200,
        elapsedTime: 1200,
        totalElevationGain: 0.0,
        startDate: '2026-05-22T06:00:00Z',
        averageSpeed: 3.33,
        maxSpeed: 3.8,
      );

      await dataSource.saveActivity(single);

      final activities = await dataSource.getAllActivities();
      check(activities).length.equals(1);
      check(activities.first.id).equals(-2001);
      check(activities.first.name).equals('Solo Treadmill Run');
      check(activities.first.distance).equals(4000.0);
    });

    test(
      'saveActivity does not overwrite other activities in the box',
      () async {
        await dataSource.saveActivities(mockActivities);

        const single = ActivityModel(
          id: -2002,
          name: 'Track Intervals',
          type: 'Run',
          distance: 5000.0,
          movingTime: 1300,
          elapsedTime: 1400,
          totalElevationGain: 10.0,
          startDate: '2026-05-22T08:00:00Z',
          averageSpeed: 3.85,
          maxSpeed: 5.2,
        );

        await dataSource.saveActivity(single);

        final activities = await dataSource.getAllActivities();
        check(activities).length.equals(3);
        check(activities.any((a) => a.id == 101)).isTrue();
        check(activities.any((a) => a.id == 102)).isTrue();
        check(activities.any((a) => a.id == -2002)).isTrue();
      },
    );

    test(
      'updateActivity updates existing activity data while preserving its ID',
      () async {
        await dataSource.saveActivity(mockActivities[0]); // ID 101

        final updated = mockActivities[0].copyWith(
          name: 'Morning Run (Calibrated)',
          distance: 5200.0,
          sufferScore: 40,
        );

        await dataSource.updateActivity(updated);

        final activities = await dataSource.getAllActivities();
        check(activities).length.equals(1);
        check(activities.first.id).equals(101);
        check(activities.first.name).equals('Morning Run (Calibrated)');
        check(activities.first.distance).equals(5200.0);
        check(activities.first.sufferScore).equals(40);
      },
    );

    test(
      'updateActivity does not modify other activities in the box',
      () async {
        await dataSource.saveActivities(mockActivities); // 101, 102

        final updated101 = mockActivities[0].copyWith(name: 'Updated 101');

        await dataSource.updateActivity(updated101);

        final activities = await dataSource.getAllActivities();
        check(activities).length.equals(2);

        final a101 = activities.firstWhere((a) => a.id == 101);
        check(a101.name).equals('Updated 101');

        final a102 = activities.firstWhere((a) => a.id == 102);
        check(a102.name).equals('Evening Jog');
      },
    );

    test(
      'updateActivity upserts activity when not previously present',
      () async {
        const unrecorded = ActivityModel(
          id: 303,
          name: 'Spontaneous Run',
          type: 'Run',
          distance: 7000.0,
          movingTime: 2100,
          elapsedTime: 2200,
          totalElevationGain: 40.0,
          startDate: '2026-05-23T10:00:00Z',
          averageSpeed: 3.33,
          maxSpeed: 4.1,
        );

        await dataSource.updateActivity(unrecorded);

        final activities = await dataSource.getAllActivities();
        check(activities).length.equals(1);
        check(activities.first.id).equals(303);
        check(activities.first.name).equals('Spontaneous Run');
      },
    );

    test(
      'updateLocalActivityId replaces negative local ID with remote ID and preserves heart rate stream',
      () async {
        const local = ActivityModel(
          id: -100,
          name: 'Offline Run',
          type: 'Run',
          distance: 5000.0,
          movingTime: 1500,
          elapsedTime: 1550,
          totalElevationGain: 20.0,
          startDate: '2026-05-20T08:00:00Z',
          averageSpeed: 3.33,
          maxSpeed: 4.0,
        );
        await dataSource.saveActivity(local);
        await dataSource.saveHeartRateStream(-100, [140.0, 150.0]);

        final updated = local.copyWith(id: 500, name: 'Uploaded Run');
        await dataSource.updateLocalActivityId(-100, updated);

        final all = await dataSource.getAllActivities();
        check(all.length).equals(1);
        check(all.first.id).equals(500);
        check(all.first.name).equals('Uploaded Run');

        final streams = await dataSource.getAllHeartRateStreams();
        check(streams).containsKey(500);
        check(streams[500]!).deepEquals([140.0, 150.0]);
        check(streams).not((it) => it.containsKey(-100));
      },
    );

    test(
      'smartMergeActivities additively retains local-only runs across remote sync',
      () async {
        const local = ActivityModel(
          id: -101,
          name: 'Unsynced Local Run',
          type: 'Run',
          distance: 4000.0,
          movingTime: 1200,
          elapsedTime: 1250,
          totalElevationGain: 10.0,
          startDate: '2026-05-22T08:00:00Z',
          averageSpeed: 3.33,
          maxSpeed: 4.0,
        );
        await dataSource.saveActivity(local);

        await dataSource.smartMergeActivities(mockActivities);

        final all = await dataSource.getAllActivities();
        check(all.length).equals(3);
        check(all.any((a) => a.id == -101)).isTrue();
        check(all.any((a) => a.id == 101)).isTrue();
        check(all.any((a) => a.id == 102)).isTrue();
      },
    );
  });
}
