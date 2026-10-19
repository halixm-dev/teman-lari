import 'fixtures/recovery_plan.dart';
import 'dart:async';
import 'package:teman_lari/data/backup/archive/training_plan_section.dart';
import 'package:teman_lari/domain/usecases/training_plan_config.dart';
import 'package:teman_lari/data/datasources/local_activity_identity_migration.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('smart_merge_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'access_token': 'secret',
    });
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'merge fills unknown elevation and keeps an existing measurement',
    () async {
      final local = activity('42', '2025-01-02T00:00:00Z')
        ..['total_elevation_gain'] = null;
      await seed(service, [local]);
      final measured = activity('42', '2025-01-02T00:00:00Z')
        ..['total_elevation_gain'] = 17.0;
      await service.applyImport(
        await service.prepareImport(await archiveBytes([measured])),
      );
      final missing = {...measured, 'total_elevation_gain': null};
      await service.applyImport(
        await service.prepareImport(
          await archiveBytes([missing], change: (a) => a['schema_version'] = 2),
        ),
      );

      final exported =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final runs = (exported['data'] as Map)['activities'] as List;
      check((runs.single as Map)['total_elevation_gain']).equals(17.0);
    },
  );

  test(
    'confirmed merge adds incoming history and retains unrelated local workouts',
    () async {
      await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
      final preview = await service.prepareImport(
        await archiveBytes([activity('42', '2025-01-02T00:00:00Z')]),
      );
      check(preview.summary.addedActivities).equals(1);
      final result = await service.applyImport(preview);
      check(result.addedActivities).equals(1);
      final stored = await service.readLocalState();
      check(
        (stored.stores['activities'] ?? {}).keys.toList()..sort(),
      ).deepEquals(['-1', '42']);
      final exported =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      check((exported['data'] as Map)['activities'] as List).length.equals(2);
      final preferences = await SharedPreferences.getInstance();
      check(preferences.getString('access_token')).equals('secret');
      check(preferences.getBool('onboarding_complete')).equals(true);
    },
  );
  test(
    'matching positive identity fills missing annotations and streams without overwriting local values',
    () async {
      final local = activity('42', '2025-01-02T00:00:00Z', effort: 7);
      await seed(service, [local]);
      final incoming = activity('42', '2025-01-02T00:00:00Z', effort: 4)
        ..['average_heartrate'] = 145.0;
      final preview = await service.prepareImport(
        await archiveBytes(
          [incoming],
          change: (archive) {
            (archive['data'] as Map)['heart_rate_streams'] = [
              {
                'activity_id': '42',
                'samples': [140.0, 145.0],
              },
            ];
            (archive['counts'] as Map)['heart_rate_streams'] = 1;
          },
        ),
      );
      check(preview.summary.matchedActivities).equals(1);
      check(preview.summary.retainedConflicts).equals(1);
      await service.applyImport(preview);
      final exported =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final data = exported['data'] as Map;
      final merged = (data['activities'] as List).single as Map;
      check(merged['perceived_exertion']).equals(7.0);
      check(merged['average_heartrate']).equals(145.0);
      check(merged['has_heartrate']).equals(true);
      check(
        ((data['heart_rate_streams'] as List).single as Map)['samples'] as List,
      ).deepEquals([140.0, 145.0]);
    },
  );
  test(
    'a local identity conflict preserves valid archive preview but blocks Smart Merge',
    () async {
      await seed(service, [activity('42', '2025-01-02T00:00:00Z')]);
      final before = await service.readLocalState();
      final invalid = activity('42', '2025-01-03T00:00:00Z');
      final preview = await service.prepareImport(
        await archiveBytes([invalid]),
      );
      check(preview.mergeError).isNotNull();
      check(preview.archiveCounts['activities']).equals(1);
      await check(service.applyImport(preview)).throws<BackupMergeConflict>();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );
  test(
    'stale confirmation returns a fresh preview without applying until reconfirmed',
    () async {
      final bytes = await archiveBytes([
        activity('42', '2025-01-02T00:00:00Z'),
      ]);
      final preview = await service.prepareImport(bytes);
      await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
      BackupImportPreview? refreshed;
      try {
        await service.applyImport(preview);
        fail('Expected stale confirmation');
      } on SnapshotImportPreviewStale catch (error) {
        refreshed = error.preview;
      }
      check(
        (await service.readLocalState()).stores['activities']?.length,
      ).equals(1);
      check(refreshed.localRevision).equals(service.coordinator.revision);
      check(refreshed.archiveBinding).equals(preview.archiveBinding);
      await service.applyImport(refreshed);
      check(
        (await service.readLocalState()).stores['activities']?.length,
      ).equals(2);
    },
  );
  test(
    'colliding zero-distance local workouts get a fresh identity and remain idempotent after reopen',
    () async {
      await seed(service, [
        activity('-1', '2025-01-01T00:00:00Z', distance: 0),
      ]);
      final bytes = await archiveBytes(
        [activity('-1', '2025-01-02T00:00:00Z', distance: 0)],
        change: (archive) {
          (archive['data'] as Map)['heart_rate_streams'] = [
            {
              'activity_id': '-1',
              'samples': [142.0],
            },
          ];
          (archive['counts'] as Map)['heart_rate_streams'] = 1;
        },
      );
      await service.applyImport(await service.prepareImport(bytes));
      var state = await service.readLocalState();
      check(
        (state.stores['activities'] ?? {}).keys.toList()..sort(),
      ).deepEquals(['-1', '-2']);
      check(state.stores['hr_streams']?.containsKey('-2')).equals(true);
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final repeated = await service.prepareImport(bytes);
      check(repeated.summary.addedActivities).equals(0);
      check(repeated.summary.matchedActivities).equals(1);
      await service.applyImport(repeated);
      state = await service.readLocalState();
      check(state.stores['activities']?.length).equals(2);
    },
  );
  test(
    'collision aliases survive ordinary annotation edits, reopen and portable export',
    () async {
      await seed(service, [
        activity('-1', '2025-01-01T00:00:00Z', distance: 0),
      ]);
      final bytes = await archiveBytes([
        activity('-1', '2025-01-02T00:00:00Z', distance: 0),
      ]);
      await service.applyImport(await service.prepareImport(bytes));
      final source = LocalActivityDataSource(backupService: service);
      final imported = (await source.getAllActivities()).singleWhere(
        (row) => row.id == -2,
      );
      await source.updateActivity(imported.copyWith(perceivedExertion: 6));
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final exported =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes)) as Map;
      final exportedRun = ((exported['data'] as Map)['activities'] as List)
          .cast<Map>()
          .singleWhere((row) => row['id'] == '-2');
      check((exportedRun['identity_aliases'] as List?)?.length).equals(1);
      final repeated = await service.prepareImport(bytes);
      check(repeated.summary.addedActivities).equals(0);
      await service.applyImport(repeated);
      check(
        (await service.readLocalState()).stores['activities']?.length,
      ).equals(2);
    },
  );
  test(
    'first imported negative identity survives ordinary distance edits and reimport',
    () async {
      final bytes = await archiveBytes([
        activity('-7', '2025-01-02T00:00:00Z'),
      ]);
      await service.applyImport(await service.prepareImport(bytes));
      final source = LocalActivityDataSource(backupService: service);
      final saved = (await source.getAllActivities()).single;
      await source.updateActivity(saved.copyWith(distance: 1200));
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      await service.applyImport(await service.prepareImport(bytes));
      final rows = await LocalActivityDataSource(
        backupService: service,
      ).getAllActivities();
      check(rows.length).equals(1);
      check(rows.single.distance).equals(1200);
    },
  );
  test(
    'ordinary upload retains original negative zero-distance identity for reimport',
    () async {
      await seed(service, [
        activity('-7', '2025-01-02T00:00:00Z', distance: 0),
      ]);
      final bytes = (await service.prepareExport()).bytes;
      final saved = (await LocalActivityDataSource(
        backupService: service,
      ).getAllActivities()).single;
      await migrateLocalActivityIdentity(
        service,
        -7,
        saved.copyWith(id: 42, distance: 10),
      );
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      await service.applyImport(await service.prepareImport(bytes));
      final rows = await LocalActivityDataSource(
        backupService: service,
      ).getAllActivities();
      check(rows.length).equals(1);
      check(rows.single.id).equals(42);
      check(rows.single.distance).equals(10);
    },
  );
  test(
    'retained core measurements and nonempty streams count conflicts without replacing local data',
    () async {
      await seed(service, [activity('42', '2025-01-02T00:00:00Z')]);
      final local = LocalActivityDataSource(backupService: service);
      await local.saveHeartRateStream(42, [140.0]);
      final bytes = await archiveBytes(
        [activity('42', '2025-01-02T00:00:00Z', distance: 1200)],
        change: (archive) {
          (archive['data'] as Map)['heart_rate_streams'] = [
            {
              'activity_id': '42',
              'samples': [141.0, 145.0],
            },
          ];
          (archive['counts'] as Map)['heart_rate_streams'] = 1;
        },
      );
      final preview = await service.prepareImport(bytes);
      check(preview.summary.retainedConflicts).equals(2);
      await service.applyImport(preview);
      check((await local.getAllActivities()).single.distance).equals(1000);
      check(
        (await local.getAllHeartRateStreams())[42],
      ).isNotNull().deepEquals([140.0]);
      final identical = await service.prepareImport(
        (await service.prepareExport()).bytes,
      );
      check(identical.summary.retainedConflicts).equals(0);
    },
  );
  test(
    'actual import resets identical plan baseline before changed activity inputs resolve',
    () async {
      final saved = TrainingPlanArchive.fromJson(
        planUnit('Saved', null, 1),
      ).plans.single.plan.toDomain();
      await service.resolveTrainingPlan(
        inputs: 'before',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async => saved,
      );
      await service.applyImport(
        await service.prepareImport(
          await archiveBytes([activity('42', '2025-01-02T00:00:00Z')]),
        ),
      );
      final restored = await service.resolveTrainingPlan(
        inputs: 'after adds activity',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async =>
            throw StateError('Imported plan must stay authoritative'),
      );
      check(restored.goal).equals('Saved');
    },
  );
  test(
    'confirmed import revalidates programmatic previews before staging',
    () async {
      final raw =
          jsonDecode(utf8.decode(await archiveBytes([])))
              as Map<String, dynamic>;
      (raw['data'] as Map)['activities'] = [
        {'id': '42'},
      ];
      final before = await service.readLocalState();
      final forged = BackupImportPreview(
        archiveJson: raw,
        localRevision: before.revision,
        localCounts: {},
      );
      await check(service.applyImport(forged)).throws<FormatException>();
      check((await service.readLocalState()).encode()).equals(before.encode());
      check((await Hive.openBox('snapshot_recovery')).isEmpty).isTrue();
    },
  );
  test(
    'ordinary writes wait for confirmed commit and tracked workouts block backup operations',
    () async {
      final staged = Completer<void>();
      final release = Completer<void>();
      service = SnapshotBackupService(
        coordinator: service.coordinator,
        onPhase: (phase, _) async {
          if (phase == SnapshotPhase.staged) {
            staged.complete();
            await release.future;
          }
        },
      );
      final preview = await service.prepareImport(await archiveBytes([]));
      final apply = service.applyImport(preview);
      await staged.future;
      var ordinaryFinished = false;
      final ordinary = service.coordinator.write(() async {
        ordinaryFinished = true;
      });
      await Future<void>.delayed(Duration.zero);
      check(ordinaryFinished).isFalse();
      await check(service.applyImport(preview)).throws<StateError>();
      release.complete();
      await apply;
      await ordinary;
      check(ordinaryFinished).isTrue();
      service.coordinator.beginWorkout();
      await check(service.prepareExport()).throws<StateError>();
      await check(
        service.prepareImport(await archiveBytes([])),
      ).throws<StateError>();
      await check(service.applyImport(preview)).throws<StateError>();
      service.coordinator.endWorkout();
    },
  );
  test(
    'successful runtime recovery resets plan input baseline before reopening access',
    () async {
      final saved = TrainingPlanArchive.fromJson(
        planUnit('Saved', null, 1),
      ).plans.single.plan.toDomain();
      await service.resolveTrainingPlan(
        inputs: 'before',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async => saved,
      );
      service.coordinator.recoveryRequired = true;
      await service.initialize();
      final restored = await service.resolveTrainingPlan(
        inputs: 'after recovery',
        configuration: TrainingPlanConfig.defaultConfig,
        generate: (_) async =>
            throw StateError('Recovered plan must stay authoritative'),
      );
      check(restored.goal).equals('Saved');
    },
  );
  for (final invalid in [
    {'source_id': '42'},
    {'source_id': '-9223372036854775809'},
    {'start_date': '2025-02-30T00:00:00Z'},
    {'type': 'Ride'},
    {'distance_meters': '01'},
    {'distance_meters': '1.5'},
    {'distance_meters': '9' * 309},
    {'distance_meters': '9007199254740993'},
  ]) {
    test('invalid supported alias is rejected: $invalid', () async {
      final row = activity('42', '2025-01-02T00:00:00Z')
        ..['identity_aliases'] = [
          {
            'source_id': '-7',
            'type': 'Run',
            'start_date': '2025-01-02T00:00:00Z',
            'distance_meters': '1000',
            ...invalid,
          },
        ];
      await check(
        service.prepareImport(await archiveBytes([row])),
      ).throws<FormatException>();
      check(
        (await service.readLocalState()).stores['activities'],
      ).isNotNull().isEmpty();
    });
  }
  test(
    'duplicate alias ownership cannot merge different positive identities',
    () async {
      final alias = {
        'source_id': '-7',
        'type': 'Run',
        'start_date': '2025-01-02T00:00:00Z',
        'distance_meters': '1000',
      };
      final first = activity('42', '2025-01-02T00:00:00Z')
        ..['identity_aliases'] = [alias];
      final second = activity('43', '2025-01-02T00:00:00Z')
        ..['identity_aliases'] = [alias];
      await check(
        service.prepareImport(await archiveBytes([first, second])),
      ).throws<FormatException>();
    },
  );
  test(
    'same-signature different positive IDs stay distinct and explain current matching limit',
    () async {
      await seed(service, [activity('42', '2025-01-02T00:00:00Z')]);
      final preview = await service.prepareImport(
        await archiveBytes([activity('43', '2025-01-02T00:00:00Z')]),
      );
      check(preview.summary.warnings).isNotEmpty();
      await service.applyImport(preview);
      check(
        (await service.readLocalState()).stores['activities']?.length,
      ).equals(2);
    },
  );
  test(
    'alias-collapsed incoming streams use numeric source precedence independent of file order',
    () async {
      await seed(service, [activity('-2', '2025-01-01T00:00:00Z')]);
      final workout = activity('-2', '2025-01-02T00:00:00Z');
      await service.applyImport(
        await service.prepareImport(await archiveBytes([workout])),
      );
      final baseline = await service.readLocalState();
      String? expected;
      for (final reverse in [false, true]) {
        final rows = [workout, activity('-1', '2025-01-02T00:00:00Z')];
        final streams = [
          {
            'activity_id': '-2',
            'samples': [150.0],
          },
          {
            'activity_id': '-1',
            'samples': [140.0],
          },
        ];
        final preview = await service.prepareImport(
          await archiveBytes(
            reverse ? rows.reversed.toList() : rows,
            change: (archive) {
              (archive['data'] as Map)['heart_rate_streams'] = reverse
                  ? streams.reversed.toList()
                  : streams;
              (archive['counts'] as Map)['heart_rate_streams'] = 2;
            },
          ),
        );
        await service.applyImport(preview);
        final after = await service.readLocalState();
        check(
          jsonDecode(
                (after.stores['hr_streams']?['-1'] as Map)['data'] as String,
              )
              as List,
        ).deepEquals([150.0]);
        if (expected != null) check(after.encode()).equals(expected);
        expected = after.encode();
        await service.applyLocalState(
          baseline,
          expectedRevision: service.coordinator.revision,
        );
      }
    },
  );
  for (final scenario in const [
    [
      'newer imported value',
      'Local',
      '2025-01-01T00:00:00Z',
      'Imported',
      '2025-02-01T00:00:00Z',
      'Imported',
      '2025-02-01T00:00:00Z',
    ],
    [
      'equal keeps local',
      'Local',
      '2025-01-01T00:00:00Z',
      'Imported',
      '2025-01-01T00:00:00Z',
      'Local',
      '2025-01-01T00:00:00Z',
    ],
    [
      'unknown local time keeps local',
      'Local',
      null,
      'Imported',
      '2025-02-01T00:00:00Z',
      'Local',
      null,
    ],
    [
      'unknown imported time keeps local',
      'Local',
      '2025-01-01T00:00:00Z',
      'Imported',
      null,
      'Local',
      '2025-01-01T00:00:00Z',
    ],
    [
      'absent local initializes unknown imported value',
      null,
      null,
      'Imported',
      null,
      'Imported',
      null,
    ],
    [
      'newer nullable clear applies',
      'Local',
      '2025-01-01T00:00:00Z',
      null,
      '2025-02-01T00:00:00Z',
      null,
      '2025-02-01T00:00:00Z',
    ],
    [
      'timestamped local clear survives older value',
      null,
      '2025-02-01T00:00:00Z',
      'Imported',
      '2025-01-01T00:00:00Z',
      null,
      '2025-02-01T00:00:00Z',
    ],
  ]) {
    test('profile field recency: ${scenario[0]}', () async {
      await changeStores(service, {
        'preferences': {
          if (scenario[1] != null) 'athlete_name': scenario[1],
          if (scenario[2] != null) 'athlete_name_modified_at': scenario[2],
        },
      });
      final preview = await service.prepareImport(
        await archiveBytes(
          [],
          change: (archive) {
            ((archive['data'] as Map)['profile'] as Map)['athlete_name'] = {
              'value': scenario[3],
              'modified_at': scenario[4],
            };
          },
        ),
      );
      await service.applyImport(preview);
      final preferences =
          (await service.readLocalState()).stores['preferences'] ?? {};
      check(preferences['athlete_name']).equals(scenario[5]);
      final modified = preferences['athlete_name_modified_at'];
      check(
        modified == null
            ? null
            : DateTime.parse(modified as String).toUtc().toIso8601String(),
      ).equals(
        scenario[6] == null
            ? null
            : DateTime.parse(scenario[6] as String).toIso8601String(),
      );
    });
  }
  for (final scenario in const [
    [
      'strictly newer replaces coherent unit',
      '2025-01-01T00:00:00Z',
      '2025-02-01T00:00:00Z',
      'Imported',
      2,
      0.3,
      '2025-02-01T00:00:00.000Z',
    ],
    [
      'unknown local recency retains unit',
      null,
      '2025-02-01T00:00:00Z',
      'Local',
      1,
      0.2,
      '2025-01-01T00:00:00.000Z',
    ],
    [
      'equal recency retains unit',
      '2025-01-01T00:00:00Z',
      '2025-01-01T00:00:00Z',
      'Local',
      1,
      0.2,
      '2025-01-01T00:00:00.000Z',
    ],
  ]) {
    test('Training Plan: ${scenario[0]}', () async {
      await changeStores(service, {
        'training_plans': {
          'active_state': planUnit('Local', scenario[1] as String?, 1),
        },
        'preferences': {
          'week_in_cycle': 1,
          'cycle_start_date': '2025-01-01T00:00:00Z',
        },
      });
      final preview = await service.prepareImport(
        await archiveBytes(
          [],
          change: (archive) {
            (archive['data'] as Map)['training_plan_state'] = planUnit(
              'Imported',
              scenario[2] as String?,
              2,
            );
            (archive['counts'] as Map)['training_plan_state'] = 1;
          },
        ),
      );
      await service.applyImport(preview);
      final state = await service.readLocalState();
      check(
        recoveryPlanGoal(state.stores['training_plans']),
      ).equals(scenario[3]);
      check(state.stores['preferences']?['week_in_cycle']).equals(scenario[4]);
      final unit = state.stores['training_plans']?['active_state'] as Map;
      check(
        (unit['configuration'] as Map)['long_run_fraction'],
      ).equals(scenario[5]);
      check(
        DateTime.parse(
          state.stores['preferences']?['cycle_start_date'] as String,
        ).toUtc().toIso8601String(),
      ).equals(scenario[6] as String);
    });
  }
  test('genuinely absent plan initializes without inventing recency', () async {
    final preview = await service.prepareImport(
      await archiveBytes(
        [],
        change: (archive) {
          (archive['data'] as Map)['training_plan_state'] = planUnit(
            'Imported',
            null,
            2,
          );
          (archive['counts'] as Map)['training_plan_state'] = 1;
        },
      ),
    );
    await service.applyImport(preview);
    final state = await service.readLocalState();
    check(recoveryPlanGoal(state.stores['training_plans'])).equals('Imported');
    check(
      (state.stores['training_plans']?['active_state'] as Map)['modified_at'],
    ).isNull();
    check(state.stores['preferences']?['week_in_cycle']).equals(2);
  });
  test(
    'an alias cannot redirect an unrelated incoming workout onto local history',
    () async {
      await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
      final before = await service.readLocalState();
      final incoming = activity('-7', '2025-01-02T00:00:00Z')
        ..['identity_aliases'] = [
          {
            'source_id': '-1',
            'type': 'Run',
            'start_date': '2025-01-01T00:00:00Z',
            'distance_meters': '1000',
          },
        ];
      await check(
        service.prepareImport(await archiveBytes([incoming])),
      ).throws<FormatException>();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );
  test(
    'equipment union retains local shoes and rewrites imported assignments after ID collision',
    () async {
      await seed(service, [activity('-1', '2025-01-01T00:00:00Z')]);
      await changeStores(service, {
        'equipment': {'local-shoe': shoe('local-shoe', 'Local')},
      });
      final preview = await service.prepareImport(
        await archiveBytes(
          [activity('-1', '2025-01-02T00:00:00Z')],
          change: (archive) {
            (archive['data'] as Map)['equipment'] = {
              'shoes': [shoe('imported-shoe', 'Imported')],
              'activity_assignments': [
                {
                  'activity_id': '-1',
                  'shoe_id': 'imported-shoe',
                  'modified_at': '2025-02-01T00:00:00Z',
                },
              ],
            };
            (archive['counts'] as Map)['equipment'] = 2;
          },
        ),
      );
      await service.applyImport(preview);
      final state = await service.readLocalState();
      check(
        (state.stores['equipment'] ?? {}).keys.toList()..sort(),
      ).deepEquals(['imported-shoe', 'local-shoe']);
      final row = state.stores['activities']?['-2'] as Map;
      final data = jsonDecode(row['data'] as String) as Map;
      check(data['shoe_id']).equals('imported-shoe');
      check(
        data['shoe_assignment_modified_at'],
      ).equals('2025-02-01T00:00:00.000Z');
    },
  );
}

Map<String, dynamic> activity(
  String id,
  String start, {
  double distance = 1000,
  double? effort,
}) => {
  'id': id,
  'name': 'Run $id',
  'type': 'Run',
  'distance': distance,
  'moving_time': 300,
  'elapsed_time': 300,
  'total_elevation_gain': 0.0,
  'start_date': start,
  'average_speed': 3.0,
  'max_speed': 4.0,
  'average_heartrate': null,
  'max_heartrate': null,
  'average_cadence': null,
  'suffer_score': null,
  'has_heartrate': false,
  'workout_type': null,
  'perceived_exertion': effort,
  'is_local': id.startsWith('-'),
};

Future<Uint8List> archiveBytes(
  List<Map<String, dynamic>> activities, {
  void Function(Map<String, dynamic>)? change,
}) async {
  final archive =
      jsonDecode(
            await File(
              'test/fixtures/offline-backup-v1-empty.tlbackup',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  (archive['data'] as Map)['activities'] = activities;
  (archive['counts'] as Map)['activities'] = activities.length;
  change?.call(archive);
  return Uint8List.fromList(utf8.encode(jsonEncode(archive)));
}

Future<void> seed(
  SnapshotBackupService service,
  List<Map<String, dynamic>> activities,
) async {
  final before = await service.readLocalState();
  await service.applyLocalState(
    LocalSnapshot(
      revision: before.revision,
      stores: {
        ...before.stores,
        'activities': {
          for (final input in activities)
            input['id'] as String: {
              'id': int.parse(input['id'] as String),
              'data': jsonEncode(
                {...input, 'id': int.parse(input['id'] as String)}
                  ..remove('is_local'),
              ),
              'synced_at': 0,
            },
        },
      },
    ),
    expectedRevision: before.revision,
  );
}

Future<void> changeStores(
  SnapshotBackupService service,
  Map<String, Map<String, Object?>> changes,
) async {
  final before = await service.readLocalState();
  await service.applyLocalState(
    LocalSnapshot(
      revision: before.revision,
      stores: {...before.stores, ...changes},
    ),
    expectedRevision: before.revision,
  );
}

Map<String, dynamic> planUnit(String goal, String? modified, int week) {
  final state = Map<String, dynamic>.from(
    recoveryPlan(goal)['active_state'] as Map,
  );
  (state['configuration'] as Map)['long_run_fraction'] = goal == 'Imported'
      ? 0.3
      : 0.2;
  state['modified_at'] = modified;
  state['week_in_cycle'] = {'value': week, 'modified_at': modified};
  state['cycle_start_date'] = {
    'value': week == 1 ? '2025-01-01T00:00:00Z' : '2025-02-01T00:00:00Z',
    'modified_at': modified,
  };
  return state;
}

Map<String, dynamic> shoe(
  String id,
  String name, {
  String? modified = '2025-02-01T00:00:00Z',
  String? created = '2024-01-01T00:00:00Z',
}) => {
  'id': id,
  'name': name,
  'category': 'daily_trainer',
  'foam_chemistry': null,
  'lifecycle_target_meters': null,
  'performance_target_meters': null,
  'created_at': created,
  'modified_at': modified,
};
