import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/models/activity_model.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/archive/snapshot_archive_codec.dart';
import 'package:teman_lari/data/backup/transport/backup_file_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('archive_export_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({
      'athlete_name': 'Guest',
      'access_token': 'WEB_TOKEN_SENTINEL',
      'refresh_token': 'REFRESH_TOKEN_SENTINEL',
      'has_completed_onboarding': true,
    });
    service = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      clock: () => DateTime.utc(2026, 10, 14),
      snapshotId: () => 'fixture',
      appVersion: '1.0.0+1',
    );
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'guest exports a complete empty archive without installation secrets',
    () async {
      final file = await service.prepareExport();
      final text = utf8.decode(file.bytes);
      final archive = jsonDecode(text) as Map<String, dynamic>;
      final fixture =
          jsonDecode(
                await File(
                  'test/fixtures/offline-backup-v1-empty.tlbackup',
                ).readAsString(),
              )
              as Map;
      check(archive).deepEquals(fixture);
      check(archive['product']).equals('teman_lari');
      check(archive['schema_version']).equals(1);
      final data = archive['data'] as Map<String, dynamic>;
      check(data.keys).unorderedEquals({
        'profile',
        'activities',
        'heart_rate_streams',
        'training_plan_state',
        'equipment',
        'rehab_feedback',
      });
      check(data['activities'] as List).isEmpty();
      check(text.contains('WEB_TOKEN_SENTINEL')).isFalse();
      check(text.contains('REFRESH_TOKEN_SENTINEL')).isFalse();
      check(text.contains('has_completed_onboarding')).isFalse();
      check(text.contains('snapshot_recovery')).isFalse();
      check(file.filename.endsWith('.tlbackup')).isTrue();
    },
  );
  test(
    'export preserves ancient mixed history, exact identities and stored samples',
    () async {
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveActivities([
        activity(-7, 'Run'),
        activity(9007199254740993, 'Ride'),
      ]);
      await local.saveHeartRateStream(-7, [130.25, 131.75]);
      final archive =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final data = archive['data'] as Map;
      final activities = data['activities'] as List;
      check(activities.length).equals(2);
      final run = activities.cast<Map>().singleWhere(
        (row) => row['id'] == '-7',
      );
      final ride = activities.cast<Map>().singleWhere(
        (row) => row['type'] == 'Ride',
      );
      check(ride['id']).equals('9007199254740993');
      check(run['is_local']).equals(true);
      check(run['distance']).equals(1234.567);
      check(run['perceived_exertion']).equals(4.5);
      check(run['start_date']).equals('1990-01-02T03:04:05.000Z');
      final streams = data['heart_rate_streams'] as List;
      check((streams.single as Map)['activity_id']).equals('-7');
      check(
        (streams.single as Map)['samples'] as List,
      ).deepEquals([130.25, 131.75]);
      check(
        utf8
            .decode((await service.prepareExport()).bytes)
            .contains('synced_at'),
      ).isFalse();
    },
  );
  test(
    'profile clears keep their edit time without inventing legacy timestamps',
    () async {
      final prefs = PreferencesStorage(
        coordinator: service.coordinator,
        clock: () => DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      await prefs.clearMaxHr();
      await prefs.saveDateOfBirth('1990-02-03');
      await prefs.setWeekInCycle(3);
      final archive =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final data = archive['data'] as Map;
      final profile = data['profile'] as Map;
      check(
        profile['max_hr'] as Map,
      ).deepEquals({'value': null, 'modified_at': '2026-01-02T03:04:05.000Z'});
      check(
        profile['athlete_name'] as Map,
      ).deepEquals({'value': 'Guest', 'modified_at': null});
      check((profile['date_of_birth'] as Map)['value']).equals('1990-02-03');
      check(
        profile['resting_hr'] as Map,
      ).deepEquals({'value': null, 'modified_at': null});
      final plan = data['training_plan_state'] as Map;
      check((plan['week_in_cycle'] as Map)['value']).equals(3);
      check((plan['cycle_start_date'] as Map)['value']).isNull();
    },
  );
  test(
    'unsupported populated sections fail rather than disappearing',
    () async {
      for (final name in ['training_plans', 'equipment', 'rehab_feedback']) {
        final box = await Hive.openBox(name);
        await box.put('legacy', {'id': 'must-survive'});
        if (name == 'rehab_feedback') {
          await check(service.prepareExport()).throws<FormatException>();
        } else {
          await check(service.prepareExport()).throws<StateError>();
        }
        await box.clear();
      }
    },
  );
  test(
    'strict corruption and dangling streams fail the whole export',
    () async {
      final box = await Hive.openBox('activities');
      await box.put('-7', {'id': -7, 'data': 'not json'});
      await check(service.prepareExport()).throws<FormatException>();
      await box.clear();
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveHeartRateStream(-999, [120.5]);
      await check(service.prepareExport()).throws<StateError>();
    },
  );
  test('invalid profile values cannot produce a successful archive', () async {
    final state = await service.readLocalState();
    state.stores['preferences']?['resting_hr'] = 'broken';
    await service.applyLocalState(state, expectedRevision: state.revision);
    await check(service.prepareExport()).throws<StateError>();
  });

  test(
    'actual UTF-8 bytes allow exactly 50 MiB and refuse an extra byte',
    () async {
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveActivities([activity(-7, 'Run').copyWith(name: '')]);
      final overhead = (await service.prepareExport()).bytes.length;
      final remaining = SnapshotArchiveLimits.maxBytes - overhead;
      final name =
          '${List.filled(remaining ~/ 2, 'é').join()}${remaining.isOdd ? 'x' : ''}';
      await local.saveActivities([activity(-7, 'Run').copyWith(name: name)]);
      check((await service.prepareExport()).bytes.length).equals(52428800);
      await local.saveActivities([
        activity(-7, 'Run').copyWith(name: '${name}x'),
      ]);
      await check(service.prepareExport()).throws<StateError>();
    },
  );
  test(
    'storage and payload identities must agree without exporting raw extras',
    () async {
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveActivities([activity(-7, 'Run')]);
      final box = await Hive.openBox('activities');
      final row = Map<String, dynamic>.from(box.get('-7') as Map);
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      data['account_secret'] = 'ACTIVITY_SECRET_SENTINEL';
      row['data'] = jsonEncode(data);
      await box.put('-7', row);
      check(
        utf8
            .decode((await service.prepareExport()).bytes)
            .contains('ACTIVITY_SECRET_SENTINEL'),
      ).isFalse();
      row['id'] = -8;
      await box.put('-7', row);
      await check(service.prepareExport()).throws<StateError>();
    },
  );
  test('guest export completes with network access disabled', () async {
    final file = await HttpOverrides.runZoned(
      service.prepareExport,
      createHttpClient: (_) => throw StateError('Network is unavailable'),
    );
    check(file.bytes).isNotEmpty();
  });
  test(
    'native delivery never invents success after provider failure',
    () async {
      const channel = MethodChannel('dev.halixm.temanlari/backup');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      final transport = PlatformBackupFileTransport();
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(
          code: 'backup_failed',
          message: 'A partial file may remain. Try another folder.',
        ),
      );
      await check(
        service.exportBackup(transport),
      ).throws<BackupFileException>();
      check(service.exportPhase.value).equals(BackupExportPhase.idle);
      check(service.coordinator.snapshotBusy).isFalse();
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      await check(
        service.exportBackup(transport),
      ).throws<BackupFileException>();
      messenger.setMockMethodCallHandler(channel, (_) async => 'cancelled');
      check(
        await service.exportBackup(transport),
      ).equals(BackupDelivery.cancelled);
      messenger.setMockMethodCallHandler(channel, (_) async => 'saved');
      check(await service.exportBackup(transport)).equals(BackupDelivery.saved);
    },
  );
  test(
    'export records originating version metadata supplied by the build',
    () async {
      final versioned = SnapshotBackupService(
        coordinator: service.coordinator,
        versionReader: () async => '2.3.4+55',
      );
      final archive =
          jsonDecode(utf8.decode((await versioned.prepareExport()).bytes))
              as Map;
      check(archive['app_version']).equals('2.3.4+55');
    },
  );
}

ActivityModel activity(int id, String type) => ActivityModel(
  id: id,
  name: 'Historical workout',
  type: type,
  distance: 1234.567,
  movingTime: 500,
  elapsedTime: 510,
  totalElevationGain: 12.75,
  startDate: '1990-01-02T03:04:05Z',
  averageSpeed: 2.47,
  maxSpeed: 4.123,
  perceivedExertion: 4.5,
);
