import 'dart:convert';
import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'fixtures/linked_record_fixtures.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('signature_merge_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({'access_token': 'secret'});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final boundary in [
    (
      name: 'equivalent UTC offset',
      start: '2025-01-01T07:00:00+07:00',
      distance: 1000.0,
      type: 'Run',
      matches: 1,
    ),
    (
      name: 'one microsecond later',
      start: '2025-01-01T00:00:00.000001Z',
      distance: 1000.0,
      type: 'Run',
      matches: 0,
    ),
    (
      name: 'different activity type',
      start: '2025-01-01T00:00:00Z',
      distance: 1000.0,
      type: 'Ride',
      matches: 0,
    ),
    (
      name: 'below half meter',
      start: '2025-01-01T00:00:00Z',
      distance: 1000.49,
      type: 'Run',
      matches: 1,
    ),
    (
      name: 'at half meter',
      start: '2025-01-01T00:00:00Z',
      distance: 1000.5,
      type: 'Run',
      matches: 0,
    ),
  ]) {
    test('signature boundary: ${boundary.name}', () async {
      await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
      final incoming = activity(
        '100',
        boundary.start,
        distance: boundary.distance,
      )..['type'] = boundary.type;
      final preview = await service.prepareImport(
        await archiveBytes([incoming]),
      );
      check(preview.mergeError).isNull();
      check(preview.summary.signatureMatches).equals(boundary.matches);
      await service.applyImport(preview);
      final data =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes))['data']
              as Map;
      check((data['activities'] as List).length).equals(2 - boundary.matches);
    });
  }
  for (final distances in [
    (0.0, 0.0, 0),
    (0.0, 0.1, 0),
    (0.1, 0.2, 1),
    (1e30, 1e30, 1),
    (1e30, 2e30, 0),
  ]) {
    test('distance safety: ${distances.$1} and ${distances.$2}', () async {
      await seed(service, [
        activity('-1', '2025-01-01T00:00:00Z', distance: distances.$1),
      ]);
      final bytes = await archiveBytes([
        activity('100', '2025-01-01T00:00:00Z', distance: distances.$2),
      ]);
      final preview = await service.prepareImport(bytes);
      check(preview.mergeError).isNull();
      check(preview.summary.signatureMatches).equals(distances.$3);
      await service.applyImport(preview);
      check(
        (await service.prepareImport(bytes)).summary.addedActivities,
      ).equals(0);
    });
  }
  test('different positive IDs stay distinct and report uncertainty', () async {
    await seed(service, [activity('100', '2025-01-01T00:00:00Z')]);
    final preview = await service.prepareImport(
      await archiveBytes([activity('101', '2025-01-01T00:00:00Z')]),
    );
    check(preview.summary.signatureMatches).equals(0);
    check(preview.summary.ambiguousSignatures).equals(1);
    check(preview.summary.addedActivities).equals(1);
    await service.applyImport(preview);
    final rows = await LocalActivityDataSource(
      backupService: service,
    ).getAllActivities();
    check(rows.map((row) => row.id).toSet()).deepEquals({100, 101});
  });
  test(
    'same-ID import does not deduplicate two pre-existing local records',
    () async {
      await seed(service, [
        activity('-1', '2025-01-01T00:00:00Z'),
        activity('100', '2025-01-01T00:00:00Z'),
      ]);
      final preview = await service.prepareImport(
        await archiveBytes([activity('100', '2025-01-01T00:00:00Z')]),
      );
      check(preview.summary.signatureMatches).equals(0);
      await service.applyImport(preview);
      check(
        (await LocalActivityDataSource(
          backupService: service,
        ).getAllActivities()).length,
      ).equals(2);
    },
  );

  test(
    'a unique remote copy keeps the local workout and stream under its positive ID',
    () async {
      final local = activity('-1', '2025-01-01T00:00:00.123456Z', effort: 7)
        ..['has_heartrate'] = true;
      await seed(service, [local]);
      await changeStores(service, {
        'hr_streams': {
          '-1': {'activity_id': -1, 'data': '[150.0]', 'synced_at': 0},
        },
      });
      final preview = await service.prepareImport(
        await archiveBytes([
          activity('100', '2025-01-01T00:00:00.123456Z', effort: 4),
        ]),
      );
      check(preview.summary.addedActivities).equals(0);
      check(preview.summary.matchedActivities).equals(1);
      await service.applyImport(preview);
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final archive =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final data = archive['data'] as Map;
      final merged = (data['activities'] as List).single as Map;
      check(merged['id']).equals('100');
      check(merged['perceived_exertion']).equals(7.0);
      final stream = (data['heart_rate_streams'] as List).single as Map;
      check(stream['activity_id']).equals('100');
      check(stream['samples'] as List).deepEquals([150.0]);
      check(
        (await SharedPreferences.getInstance()).getString('access_token'),
      ).equals('secret');
    },
  );
  test(
    'signature preview reports canonical changes and rewrites every linked owner',
    () async {
      final original = await linkedArchive(
        '-1',
        'local-shoe',
        'local-feedback',
      );
      await service.applyImport(await service.prepareImport(original));
      final incoming = await linkedArchive(
        '100',
        'remote-shoe',
        'remote-feedback',
      );
      final preview = await service.prepareImport(incoming);
      check(preview.summary.signatureMatches).equals(1);
      check(preview.summary.canonicalIdentityChanges).equals(1);
      final result = await service.applyImport(preview);
      check(result.signatureMatches).equals(1);
      check(result.canonicalIdentityChanges).equals(1);
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final before =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final data = before['data'] as Map;
      check((data['activities'] as List).length).equals(1);
      final equipment = data['equipment'] as Map;
      check((equipment['shoes'] as List).length).equals(2);
      final assignment =
          (equipment['activity_assignments'] as List).single as Map;
      check(assignment['activity_id']).equals('100');
      check(assignment['shoe_id']).equals('local-shoe');
      final feedback = ((data['rehab_feedback'] as Map)['records'] as List)
          .cast<Map>();
      check(
        feedback.map((row) => row['id']).toSet(),
      ).deepEquals({'local-feedback', 'remote-feedback'});
      check(
        feedback.map((row) => row['activity_id']).toList(),
      ).deepEquals(['100', '100']);
      final again = await service.prepareImport(original);
      check(again.summary.signatureMatches).equals(0);
      check(again.summary.canonicalIdentityChanges).equals(0);
      check(again.summary.addedActivities).equals(0);
      await service.applyImport(again);
      final after =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      check(after['data'] as Map).deepEquals(data);
    },
  );

  test(
    'a full three-way signature group stays separate regardless of archive order',
    () async {
      final results = <String>[];
      for (final reverse in [false, true]) {
        await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
        final incoming = [
          activity('100', '2025-01-01T00:00:00Z'),
          activity('101', '2025-01-01T00:00:00Z'),
        ];
        final bytes = await archiveBytes(
          reverse ? incoming.reversed.toList() : incoming,
        );
        final preview = await service.prepareImport(bytes);
        check(preview.summary.signatureMatches).equals(0);
        check(preview.summary.canonicalIdentityChanges).equals(0);
        check(preview.summary.ambiguousSignatures).equals(1);
        check(preview.summary.warnings.join(' ')).contains('ambiguous');
        await service.applyImport(preview);
        final archive =
            jsonDecode(utf8.decode((await service.prepareExport()).bytes))
                as Map;
        final data = archive['data'] as Map;
        check(
          (data['activities'] as List)
              .cast<Map>()
              .map((row) => row['id'])
              .toSet(),
        ).deepEquals({'-1', '100', '101'});
        results.add(jsonEncode(data));
      }
      check(results[0]).equals(results[1]);
    },
  );

  test(
    'a unique local copy keeps the existing negative ID and both historical identities',
    () async {
      await seed(service, [activity('-5', '2025-01-01T00:00:00Z', effort: 7)]);
      final original = (await service.prepareExport()).bytes;
      final incoming = await archiveBytes([
        activity('-7', '2025-01-01T00:00:00Z', effort: 4),
      ]);
      final preview = await service.prepareImport(incoming);
      check(preview.summary.addedActivities).equals(0);
      check(preview.summary.signatureMatches).equals(1);
      check(preview.summary.canonicalIdentityChanges).equals(0);
      await service.applyImport(preview);
      final source = LocalActivityDataSource(backupService: service);
      final saved = (await source.getAllActivities()).single;
      check(saved.id).equals(-5);
      check(saved.perceivedExertion).equals(7.0);
      await source.updateActivity(saved.copyWith(distance: 1200));
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      for (final bytes in [original, incoming]) {
        final again = await service.prepareImport(bytes);
        check(again.summary.addedActivities).equals(0);
        await service.applyImport(again);
      }
      final rows = await LocalActivityDataSource(
        backupService: service,
      ).getAllActivities();
      check(rows.length).equals(1);
      check(rows.single.id).equals(-5);
      check(rows.single.distance).equals(1200);
    },
  );

  test(
    'incoming-only local copies receive an unused identity when their preferred ID is occupied',
    () async {
      final results = <String>[];
      for (final reverse in [false, true]) {
        await seed(service, [
          activity('-2', '2025-01-01T00:00:00Z', effort: 9),
        ]);
        final incoming = [
          activity('-2', '2025-01-02T00:00:00Z', effort: 8),
          activity('-1', '2025-01-02T00:00:00Z', effort: 3),
        ];
        final bytes = await archiveBytes(
          reverse ? incoming.reversed.toList() : incoming,
        );
        final preview = await service.prepareImport(bytes);
        check(preview.mergeError).isNull();
        check(preview.summary.signatureMatches).equals(1);
        check(preview.summary.canonicalIdentityChanges).equals(0);
        check(preview.summary.addedActivities).equals(1);
        await service.applyImport(preview);
        final archive =
            jsonDecode(utf8.decode((await service.prepareExport()).bytes))
                as Map;
        final data = archive['data'] as Map;
        final rows = (data['activities'] as List).cast<Map>();
        check(rows.map((row) => row['id']).toSet()).deepEquals({'-2', '-3'});
        check(
          rows.singleWhere((row) => row['id'] == '-3')['perceived_exertion'],
        ).equals(8.0);
        final again = await service.prepareImport(bytes);
        check(again.summary.signatureMatches).equals(0);
        check(again.summary.addedActivities).equals(0);
        await service.applyImport(again);
        final repeated =
            jsonDecode(utf8.decode((await service.prepareExport()).bytes))
                as Map;
        check(repeated['data'] as Map).deepEquals(data);
        results.add(jsonEncode(data));
      }
      check(results[0]).equals(results[1]);
    },
  );

  test(
    'known incoming aliases count as one identity before signature ambiguity is decided',
    () async {
      final alias = {
        'source_id': '-2',
        'type': 'Run',
        'start_date': '2025-01-01T00:00:00Z',
        'distance_meters': '1000',
      };
      final bytes = await archiveBytes(
        [
          activity('-2', '2025-01-01T00:00:00Z', effort: 7),
          activity('-1', '2025-01-01T00:00:00Z', effort: 4)
            ..['identity_aliases'] = [alias],
          activity('100', '2025-01-01T00:00:00Z', effort: 2),
        ],
        change: (archive) {
          (archive['data'] as Map)['heart_rate_streams'] = [
            {
              'activity_id': '100',
              'samples': [140.0, 145.0],
            },
            {
              'activity_id': '-2',
              'samples': [150.0],
            },
          ];
          (archive['counts'] as Map)['heart_rate_streams'] = 2;
        },
      );
      final preview = await service.prepareImport(bytes);
      check(preview.summary.ambiguousSignatures).equals(0);
      check(preview.summary.signatureMatches).equals(1);
      check(preview.summary.addedActivities).equals(1);
      await service.applyImport(preview);
      final archive =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final data = archive['data'] as Map;
      final row = (data['activities'] as List).single as Map;
      check(row['id']).equals('100');
      check(row['perceived_exertion']).equals(7.0);
      final stream = (data['heart_rate_streams'] as List).single as Map;
      check(stream['activity_id']).equals('100');
      check(stream['samples'] as List).deepEquals([150.0]);
      final again = await service.prepareImport(bytes);
      check(again.summary.signatureMatches).equals(0);
      check(again.summary.addedActivities).equals(0);
    },
  );

  test(
    'a saved alias canonicalizes a zero-distance workout without guessing a signature',
    () async {
      final original = await archiveBytes(
        [activity('-1', '2025-01-01T00:00:00Z', distance: 0, effort: 7)],
        change: (archive) {
          (archive['data'] as Map)['heart_rate_streams'] = [
            {
              'activity_id': '-1',
              'samples': [150.0],
            },
          ];
          (archive['counts'] as Map)['heart_rate_streams'] = 1;
        },
      );
      await service.applyImport(await service.prepareImport(original));
      final remote =
          activity('100', '2025-01-01T00:00:00Z', distance: 0, effort: 4)
            ..['identity_aliases'] = [
              {
                'source_id': '-1',
                'type': 'Run',
                'start_date': '2025-01-01T00:00:00Z',
                'distance_meters': '0',
              },
            ];
      final preview = await service.prepareImport(await archiveBytes([remote]));
      check(preview.mergeError).isNull();
      check(preview.summary.signatureMatches).equals(0);
      check(preview.summary.canonicalIdentityChanges).equals(1);
      check(preview.summary.addedActivities).equals(0);
      await service.applyImport(preview);
      final source = LocalActivityDataSource(backupService: service);
      final saved = (await source.getAllActivities()).single;
      check(saved.id).equals(100);
      check(saved.perceivedExertion).equals(7.0);
      await source.updateActivity(saved.copyWith(distance: 1200));
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      await service.applyImport(await service.prepareImport(original));
      final rows = await LocalActivityDataSource(
        backupService: service,
      ).getAllActivities();
      check(rows.length).equals(1);
      check(rows.single.id).equals(100);
      check(rows.single.distance).equals(1200);
      final data =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes))['data']
              as Map;
      check(
        ((data['heart_rate_streams'] as List).single as Map)['activity_id'],
      ).equals('100');
    },
  );

  test(
    'an incoming alias joins a new local copy to its already stored remote identity',
    () async {
      await service.applyImport(
        await service.prepareImport(
          await archiveBytes(
            [activity('100', '2025-01-01T00:00:00Z', distance: 0, effort: 7)],
            change: (archive) {
              (archive['data'] as Map)['heart_rate_streams'] = [
                {
                  'activity_id': '100',
                  'samples': [150.0],
                },
              ];
              (archive['counts'] as Map)['heart_rate_streams'] = 1;
            },
          ),
        ),
      );
      final remote =
          activity('100', '2025-01-01T00:00:00Z', distance: 0, effort: 2)
            ..['identity_aliases'] = [
              {
                'source_id': '-1',
                'type': 'Run',
                'start_date': '2025-01-01T00:00:00Z',
                'distance_meters': '0',
              },
            ];
      final bytes = await archiveBytes([
        activity('-1', '2025-01-01T00:00:00Z', distance: 0, effort: 4),
        remote,
      ]);
      final preview = await service.prepareImport(bytes);
      check(preview.mergeError).isNull();
      check(preview.summary.signatureMatches).equals(0);
      check(preview.summary.canonicalIdentityChanges).equals(0);
      check(preview.summary.addedActivities).equals(0);
      await service.applyImport(preview);
      final data =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes))['data']
              as Map;
      final row = (data['activities'] as List).single as Map;
      check(row['id']).equals('100');
      check(row['perceived_exertion']).equals(7.0);
      check(
        ((data['heart_rate_streams'] as List).single as Map)['samples'] as List,
      ).deepEquals([150.0]);
      check(
        (await service.prepareImport(bytes)).summary.addedActivities,
      ).equals(0);
    },
  );
}
