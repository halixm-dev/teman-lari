import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'snapshot_archive_export_test.dart' show activity;
import 'package:teman_lari/data/backup/archive/snapshot_archive.dart';
import 'package:teman_lari/data/datasources/local_rehab_feedback_datasource.dart';
import 'package:teman_lari/domain/entities/rehab_feedback.dart';
import 'package:teman_lari/domain/entities/shoe_equipment.dart';
import 'package:teman_lari/data/datasources/local_equipment_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup_rehab_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
    await LocalActivityDataSource(
      coordinator: service.coordinator,
    ).saveActivity(activity(-7, 'Run').copyWith(workoutType: 3));
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('dual-window feedback survives export and durable reopening', () async {
    final before = await service.readLocalState();
    final expected = feedback();
    final populated = LocalSnapshot(
      revision: before.revision,
      stores: {
        ...before.stores,
        'rehab_feedback': {'feedback-1': expected},
      },
    );
    await service.applyLocalState(populated, expectedRevision: before.revision);
    final json =
        jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
    check((json['counts'] as Map)['rehab_feedback']).equals(1);
    final data = json['data'] as Map;
    check(
      ((data['rehab_feedback'] as Map)['records'] as List).single as Map,
    ).deepEquals(expected);
    await Hive.close();
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
    check(
      (await service.readLocalState()).stores['rehab_feedback']?['feedback-1']
          as Map,
    ).deepEquals(expected);
  });
  test(
    'invalid feedback references are rejected before changing local data',
    () async {
      final before = await service.readLocalState();
      final bad = LocalSnapshot(
        revision: before.revision,
        stores: {
          ...before.stores,
          'rehab_feedback': {
            'feedback-1': {...feedback(), 'activity_id': '999'},
          },
        },
      );
      await check(
        service.applyLocalState(bad, expectedRevision: before.revision),
      ).throws<FormatException>();
      check(
        (await service.readLocalState()).stores['rehab_feedback'],
      ).isNotNull().which((it) => it.isEmpty());
    },
  );
  test(
    'upload identity migration preserves both feedback windows and streams',
    () async {
      await LocalEquipmentDataSource(coordinator: service.coordinator).save(
        const ShoeEquipment(
          id: 'pair',
          name: 'Pair',
          category: ShoeCategory.dailyTrainer,
        ),
      );
      final assignmentTime = DateTime.utc(2026, 2, 1);
      final local = LocalActivityDataSource(
        coordinator: service.coordinator,
        clock: () => assignmentTime,
      );
      await local.updateActivity(
        activity(-7, 'Run').copyWith(workoutType: 3, shoeId: 'pair'),
      );
      final before = await service.readLocalState();
      await service.applyLocalState(
        LocalSnapshot(
          revision: before.revision,
          stores: {
            ...before.stores,
            'rehab_feedback': {'feedback-1': feedback()},
          },
        ),
        expectedRevision: before.revision,
      );

      await local.saveHeartRateStream(-7, [120.0, 125.0]);
      service.coordinator.beginWorkout();
      await local.updateLocalActivityId(
        -7,
        activity(701, 'Run').copyWith(perceivedExertion: null),
      );
      service.coordinator.endWorkout();
      final state = await service.readLocalState();
      check(
        state.stores['activities']?.keys,
      ).isNotNull().which((it) => it.unorderedEquals(['701']));
      check(
        state.stores['hr_streams']?.keys,
      ).isNotNull().which((it) => it.unorderedEquals(['701']));
      check(
        state.stores['rehab_feedback']?['feedback-1'] as Map,
      ).deepEquals({...feedback(), 'activity_id': '701'});
      final archive =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final run =
          ((archive['data'] as Map)['activities'] as List).single as Map;
      check(run['perceived_exertion']).equals(4.5);
      check(run['workout_type']).equals(3);
      final assignment =
          (((archive['data'] as Map)['equipment']
                          as Map)['activity_assignments']
                      as List)
                  .single
              as Map;
      check(assignment['activity_id']).equals('701');
      check(assignment['shoe_id']).equals('pair');
      check(assignment['modified_at']).equals('2026-02-01T00:00:00.000Z');
    },
  );
  test(
    'normal edits stamp the clock while imports and unknown recency survive',
    () async {
      final before = await service.readLocalState();
      await service.applyLocalState(
        LocalSnapshot(
          revision: before.revision,
          stores: {
            ...before.stores,
            'rehab_feedback': {
              'feedback-1': {...feedback(), 'modified_at': null},
            },
          },
        ),
        expectedRevision: before.revision,
      );
      final legacy = SnapshotArchive.fromJson(
        jsonDecode(utf8.decode((await service.prepareExport()).bytes))
            as Map<String, dynamic>,
      );
      check(legacy.data.rehabFeedback.records.single.modifiedAt).isNull();
      final local = LocalRehabFeedbackDataSource(
        service: service,
        clock: () => DateTime.utc(2026, 3, 1),
      );
      await local.save(
        RehabFeedback.fromJson({...feedback(), 'morning_after_pain': 3.0}),
      );
      final edited = SnapshotArchive.fromJson(
        jsonDecode(utf8.decode((await service.prepareExport()).bytes))
            as Map<String, dynamic>,
      );
      check(
        edited.data.rehabFeedback.records.single.modifiedAt,
      ).equals(DateTime.utc(2026, 3, 1));
      check(
        edited.data.rehabFeedback.records.single.morningAfterPain,
      ).equals(3.0);
      await check(
        local.save(
          RehabFeedback.fromJson({...feedback(), 'injury_site': 'knee'}),
        ),
      ).throws<FormatException>();
    },
  );
  test('invalid feedback records cannot mutate the snapshot', () async {
    final before = await service.readLocalState();
    for (final change in <Map<String, Object?>>[
      {'post_run_pain': 10.1},
      {'morning_after_pain': -1.0},
      {'injury_site': 'unsupported'},
      {'post_run_recorded_at': null},
      {'morning_after_recorded_at': '2026-02-30T08:00:00Z'},
      {'modified_at': '2026-01-01'},
      {'modified_at': '2026-01-01T08:00:00+99:99'},
      {'activity_id': '-07'},
      {'id': 'other'},
    ]) {
      final next = LocalSnapshot(
        revision: before.revision,
        stores: {
          ...before.stores,
          'rehab_feedback': {
            'feedback-1': {...feedback(), ...change},
          },
        },
      );
      await check(
        service.applyLocalState(next, expectedRevision: before.revision),
      ).throws<Exception>();
      check(
        (await service.readLocalState()).stores['rehab_feedback'],
      ).isNotNull().which((it) => it.isEmpty());
    }
  });
  test(
    'failed identity migration restores linked negative IDs after reopen',
    () async {
      final before = await service.readLocalState();
      await service.applyLocalState(
        LocalSnapshot(
          revision: before.revision,
          stores: {
            ...before.stores,
            'rehab_feedback': {'feedback-1': feedback()},
          },
        ),
        expectedRevision: before.revision,
      );
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveHeartRateStream(-7, [120.0]);
      var fail = true;
      final failing = SnapshotBackupService(
        coordinator: service.coordinator,
        onPhase: (phase, store) async {
          if (fail &&
              phase == SnapshotPhase.storeWritten &&
              store == 'activities') {
            fail = false;
            throw StateError('Injected storage failure');
          }
        },
      );
      final upload = LocalActivityDataSource(backupService: failing);
      await check(
        upload.updateLocalActivityId(-7, activity(701, 'Run')),
      ).throws<StateError>();
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final recovered = await service.readLocalState();
      check(
        recovered.stores['activities']?.keys,
      ).isNotNull().which((it) => it.unorderedEquals(['-7']));
      check(
        recovered.stores['hr_streams']?.keys,
      ).isNotNull().which((it) => it.unorderedEquals(['-7']));
      check(
        recovered.stores['rehab_feedback']?['feedback-1'] as Map,
      ).deepEquals(feedback());
    },
  );
}

Map<String, Object?> feedback() => {
  'id': 'feedback-1',
  'activity_id': '-7',
  'injury_site': 'achilles',
  'post_run_pain': 2.5,
  'post_run_recorded_at': '2026-01-01T09:00:00.000Z',
  'morning_after_pain': 1.0,
  'morning_stiffness': false,
  'morning_after_recorded_at': '2026-01-02T08:00:00.000Z',
  'modified_at': '2026-01-02T08:01:00.000Z',
};
