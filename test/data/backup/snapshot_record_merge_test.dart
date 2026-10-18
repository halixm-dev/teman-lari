import 'dart:convert';
import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'fixtures/linked_record_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('linked_record_merge_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'newer imported shoe edits replace mutable values and retain imported time',
    () async {
      await changeStores(service, {
        'equipment': {
          'shoe': shoe('shoe', 'Local', modified: '2025-01-01T00:00:00Z'),
        },
      });
      final bytes = await archiveBytes(
        [],
        change: (archive) {
          (archive['data'] as Map)['equipment'] = {
            'shoes': [shoe('shoe', 'Imported')],
            'activity_assignments': [],
          };
          (archive['counts'] as Map)['equipment'] = 1;
        },
      );
      await service.applyImport(await service.prepareImport(bytes));
      final stored =
          (await service.readLocalState()).stores['equipment']?['shoe'] as Map;
      check(stored['name']).equals('Imported');
      check(stored['modified_at']).equals('2025-02-01T00:00:00.000Z');
    },
  );
  test(
    'feedback union keeps local check-ins and remaps an imported colliding workout',
    () async {
      await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
      await changeStores(service, {
        'rehab_feedback': {'local': feedback('local', '-1', 2)},
      });
      final bytes = await archiveBytes(
        [activity('-1', '2025-01-02T00:00:00Z')],
        change: (archive) {
          (archive['data'] as Map)['rehab_feedback'] = {
            'records': [feedback('incoming', '-1', 4)],
          };
          (archive['counts'] as Map)['rehab_feedback'] = 1;
        },
      );
      final result = await service.applyImport(
        await service.prepareImport(bytes),
      );
      final records =
          (await service.readLocalState()).stores['rehab_feedback'] ?? {};
      check(records.keys.toList()..sort()).deepEquals(['incoming', 'local']);
      check((records['incoming'] as Map)['activity_id']).equals('-2');
      check((records['local'] as Map)['activity_id']).equals('-1');
      check(result.addedFeedback).equals(1);
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final repeated = await service.prepareImport(bytes);
      check(repeated.summary.addedFeedback).equals(0);
      await service.applyImport(repeated);
      check(
        (await service.readLocalState()).stores['rehab_feedback']?.length,
      ).equals(2);
    },
  );
  test(
    'feedback mutable updates require strictly newer known recency',
    () async {
      await seed(service, [activity('42', '2025-01-01T00:00:00Z')]);
      final local = <String, Object?>{};
      final incoming = <Map<String, dynamic>>[];
      for (final entry in const [
        ('newer', '2025-01-01T00:00:00Z', '2025-02-01T00:00:00Z'),
        ('tie', '2025-02-01T00:00:00Z', '2025-02-01T00:00:00Z'),
        ('older', '2025-03-01T00:00:00Z', '2025-02-01T00:00:00Z'),
        ('local-unknown', null, '2025-02-01T00:00:00Z'),
        ('incoming-unknown', '2025-01-01T00:00:00Z', null),
      ]) {
        local[entry.$1] = feedback(entry.$1, '42', 2, modified: entry.$2);
        incoming.add(feedback(entry.$1, '42', 4, modified: entry.$3));
      }
      await changeStores(service, {'rehab_feedback': local});
      final bytes = await archiveBytes(
        [activity('42', '2025-01-01T00:00:00Z')],
        change: (archive) {
          (archive['data'] as Map)['rehab_feedback'] = {'records': incoming};
          (archive['counts'] as Map)['rehab_feedback'] = 5;
        },
      );
      final result = await service.applyImport(
        await service.prepareImport(bytes),
      );
      final records =
          (await service.readLocalState()).stores['rehab_feedback'] ?? {};
      check((records['newer'] as Map)['post_run_pain']).equals(4.0);
      check(
        (records['newer'] as Map)['modified_at'],
      ).equals('2025-02-01T00:00:00.000Z');
      for (final id in ['tie', 'older', 'local-unknown', 'incoming-unknown']) {
        check((records[id] as Map)['post_run_pain']).equals(2.0);
      }
      check((records['local-unknown'] as Map)['modified_at']).isNull();
      check(result.updatedFeedback).equals(1);
      check(result.retainedConflicts).equals(4);
    },
  );
  test(
    'older tied and unknown shoe edits retain local values and report conflicts',
    () async {
      final local = <String, Object?>{};
      final incoming = <Map<String, dynamic>>[];
      for (final entry in const [
        ('tie', '2025-02-01T00:00:00Z', '2025-02-01T00:00:00Z'),
        ('older', '2025-03-01T00:00:00Z', '2025-02-01T00:00:00Z'),
        ('local-unknown', null, '2025-02-01T00:00:00Z'),
        ('incoming-unknown', '2025-01-01T00:00:00Z', null),
      ]) {
        local[entry.$1] = shoe(entry.$1, 'Local', modified: entry.$2);
        incoming.add(shoe(entry.$1, 'Imported', modified: entry.$3));
      }
      await changeStores(service, {'equipment': local});
      final bytes = await archiveBytes(
        [],
        change: (archive) {
          (archive['data'] as Map)['equipment'] = {
            'shoes': incoming,
            'activity_assignments': [],
          };
          (archive['counts'] as Map)['equipment'] = 4;
        },
      );
      final result = await service.applyImport(
        await service.prepareImport(bytes),
      );
      final records =
          (await service.readLocalState()).stores['equipment'] ?? {};
      for (final id in ['tie', 'older', 'local-unknown', 'incoming-unknown']) {
        check((records[id] as Map)['name']).equals('Local');
      }
      check((records['local-unknown'] as Map)['modified_at']).isNull();
      check(result.updatedShoes).equals(0);
      check(result.retainedConflicts).equals(4);
    },
  );
  test(
    'assignments fill absence while preserving local shoes and explicit clears',
    () async {
      final runs = [
        for (var id = 1; id <= 4; id++)
          activity('$id', '2025-01-0${id}T00:00:00Z'),
      ];
      await seed(service, runs);
      final state = await service.readLocalState();
      final activities = state.stores['activities'] ?? {};
      for (final id in ['1', '2']) {
        final row = activities[id] as Map;
        final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        data['shoe_id'] = id == '1' ? 'local' : null;
        data['shoe_assignment_modified_at'] = id == '2'
            ? '2025-01-01T00:00:00Z'
            : null;
        activities[id] = {...row, 'data': jsonEncode(data)};
      }
      await changeStores(service, {
        'activities': activities,
        'equipment': {'local': shoe('local', 'Local')},
      });
      final bytes = await archiveBytes(
        runs,
        change: (archive) {
          (archive['data'] as Map)['equipment'] = {
            'shoes': [shoe('incoming', 'Imported')],
            'activity_assignments': [
              for (final id in ['1', '2', '3', '4'])
                {
                  'activity_id': id,
                  'shoe_id': id == '3' ? null : 'incoming',
                  'modified_at': '2025-02-01T00:00:00Z',
                },
            ],
          };
          (archive['counts'] as Map)['equipment'] = 5;
        },
      );
      final result = await service.applyImport(
        await service.prepareImport(bytes),
      );
      final stored =
          (await service.readLocalState()).stores['activities'] ?? {};
      Map data(String id) =>
          jsonDecode((stored[id] as Map)['data'] as String) as Map;
      check(data('1')['shoe_id']).equals('local');
      check(data('1')['shoe_assignment_modified_at']).isNull();
      check(data('2')['shoe_id']).isNull();
      check(
        data('2')['shoe_assignment_modified_at'],
      ).equals('2025-01-01T00:00:00Z');
      check(data('3')['shoe_id']).isNull();
      check(
        data('3')['shoe_assignment_modified_at'],
      ).equals('2025-02-01T00:00:00.000Z');
      check(data('4')['shoe_id']).equals('incoming');
      check(result.changedAssignments).equals(2);
      check(result.retainedConflicts).equals(2);
      check(result.addedShoes).equals(1);
    },
  );
  test(
    'conflicting immutable shoe anchors block Smart Merge before any write',
    () async {
      await changeStores(service, {
        'equipment': {'shoe': shoe('shoe', 'Local')},
      });
      final before = (await service.readLocalState()).encode();
      final bytes = await archiveBytes(
        [],
        change: (archive) {
          (archive['data'] as Map)['equipment'] = {
            'shoes': [
              shoe('shoe', 'Imported', created: '2024-02-01T00:00:00Z'),
            ],
            'activity_assignments': [],
          };
          (archive['counts'] as Map)['equipment'] = 1;
        },
      );
      final preview = await service.prepareImport(bytes);
      check(preview.mergeError).isNotNull();
      check(preview.archiveCounts['equipment']).equals(1);
      await check(service.applyImport(preview)).throws<BackupMergeConflict>();
      check((await service.readLocalState()).encode()).equals(before);
    },
  );
  for (final collision in const [
    ('activity', '2', 'knee'),
    ('injury site', '1', 'achilles'),
  ]) {
    test(
      'feedback immutable ${collision.$1} collision blocks Smart Merge before writes',
      () async {
        final runs = [
          activity('1', '2025-01-01T00:00:00Z'),
          activity('2', '2025-01-02T00:00:00Z'),
        ];
        await seed(service, runs);
        await changeStores(service, {
          'rehab_feedback': {'check-in': feedback('check-in', '1', 2)},
        });
        final before = (await service.readLocalState()).encode();
        final bytes = await archiveBytes(
          runs,
          change: (archive) {
            (archive['data'] as Map)['rehab_feedback'] = {
              'records': [
                feedback('check-in', collision.$2, 4, site: collision.$3),
              ],
            };
            (archive['counts'] as Map)['rehab_feedback'] = 1;
          },
        );
        final preview = await service.prepareImport(bytes);
        check(preview.mergeError).isNotNull();
        await check(service.applyImport(preview)).throws<BackupMergeConflict>();
        check((await service.readLocalState()).encode()).equals(before);
      },
    );
  }
  test(
    'newer record revisions preserve nullable clears and known shoe creation identity',
    () async {
      await seed(service, [activity('42', '2025-01-01T00:00:00Z')]);
      final localShoe = shoe('shoe', 'Local', modified: '2025-01-01T00:00:00Z')
        ..['foam_chemistry'] = 'traditional_eva'
        ..['lifecycle_target_meters'] = 600000.0;
      await changeStores(service, {
        'equipment': {'shoe': localShoe},
        'rehab_feedback': {
          'check-in': feedback(
            'check-in',
            '42',
            4,
            modified: '2025-01-01T00:00:00Z',
          ),
        },
      });
      final incomingFeedback = feedback('check-in', '42', 4)
        ..['post_run_pain'] = null
        ..['post_run_recorded_at'] = null
        ..['morning_after_pain'] = 0.0
        ..['morning_stiffness'] = false
        ..['morning_after_recorded_at'] = '2025-01-02T08:00:00Z';
      final bytes = await archiveBytes(
        [activity('42', '2025-01-01T00:00:00Z')],
        change: (archive) {
          (archive['data'] as Map)['equipment'] = {
            'shoes': [shoe('shoe', 'Imported', created: null)],
            'activity_assignments': [],
          };
          (archive['data'] as Map)['rehab_feedback'] = {
            'records': [incomingFeedback],
          };
          (archive['counts'] as Map)['equipment'] = 1;
          (archive['counts'] as Map)['rehab_feedback'] = 1;
        },
      );
      await service.applyImport(await service.prepareImport(bytes));
      final state = await service.readLocalState();
      final storedShoe = state.stores['equipment']?['shoe'] as Map;
      check(storedShoe['foam_chemistry']).isNull();
      check(storedShoe['lifecycle_target_meters']).isNull();
      check(storedShoe['created_at']).equals('2024-01-01T00:00:00.000Z');
      final storedFeedback = state.stores['rehab_feedback']?['check-in'] as Map;
      check(storedFeedback['post_run_pain']).isNull();
      check(storedFeedback['post_run_recorded_at']).isNull();
      check(storedFeedback['morning_after_pain']).equals(0.0);
      check(storedFeedback['morning_stiffness']).equals(false);
      check(storedFeedback['modified_at']).equals('2025-02-01T00:00:00.000Z');
    },
  );
  test(
    'collapsed alias assignments use numeric source precedence regardless of archive order',
    () async {
      final selected = <String?>[];
      for (final reverse in [false, true]) {
        await seed(service, [activity('-2', '2025-01-01T00:00:00Z')]);
        await changeStores(service, {
          'equipment': {},
          'hr_streams': {},
          'rehab_feedback': {},
        });
        await service.applyImport(
          await service.prepareImport(
            await archiveBytes([activity('-2', '2025-01-02T00:00:00Z')]),
          ),
        );
        final assignments = [
          {
            'activity_id': '-1',
            'shoe_id': 'source-one',
            'modified_at': '2025-02-01T00:00:00Z',
          },
          {
            'activity_id': '-2',
            'shoe_id': 'source-two',
            'modified_at': '2025-02-01T00:00:00Z',
          },
        ];
        final bytes = await archiveBytes(
          [
            activity('-1', '2025-01-02T00:00:00Z'),
            activity('-2', '2025-01-02T00:00:00Z'),
          ],
          change: (archive) {
            (archive['data'] as Map)['equipment'] = {
              'shoes': [shoe('source-one', 'One'), shoe('source-two', 'Two')],
              'activity_assignments': reverse
                  ? assignments.reversed.toList()
                  : assignments,
            };
            (archive['counts'] as Map)['equipment'] = 4;
          },
        );
        await service.applyImport(await service.prepareImport(bytes));
        final row =
            (await service.readLocalState()).stores['activities']?['-1'] as Map;
        selected.add(
          (jsonDecode(row['data'] as String) as Map)['shoe_id'] as String?,
        );
      }
      check(selected).deepEquals(['source-two', 'source-two']);
    },
  );
}

Map<String, dynamic> feedback(
  String id,
  String owner,
  double pain, {
  String? modified = '2025-02-01T00:00:00Z',
  String site = 'knee',
}) => {
  'id': id,
  'activity_id': owner,
  'injury_site': site,
  'post_run_pain': pain,
  'post_run_recorded_at': '2025-01-01T01:00:00Z',
  'morning_after_pain': null,
  'morning_stiffness': null,
  'morning_after_recorded_at': null,
  'modified_at': modified,
};
