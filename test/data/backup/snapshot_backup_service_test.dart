import 'dart:io';
import 'fixtures/recovery_plan.dart';
import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/models/activity_model.dart';

void main() {
  late Directory directory;
  late SnapshotBackupService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('snapshot_backup_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({
      'athlete_name': 'Before',
      'access_token': 'keep-secret',
      'has_completed_onboarding': true,
    });
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('strict snapshot captures persisted allowlisted state only', () async {
    final snapshot = await service.readLocalState();
    check(snapshot.stores['preferences']?['athlete_name']).equals('Before');
    check(snapshot.stores['preferences']).isNotNull().which((it) {
      check(
        snapshot.stores['preferences']?.containsKey('access_token'),
      ).equals(false);
      check(
        snapshot.stores['preferences']?.containsKey('has_completed_onboarding'),
      ).equals(false);
    });
    check(
      snapshot.stores['activities'],
    ).isNotNull().which((it) => it.isEmpty());
  });
  test(
    'replacement is durable and leaves installation credentials intact',
    () async {
      final before = await service.readLocalState();
      final next = LocalSnapshot(
        revision: before.revision,
        stores: {
          ...before.stores,
          'preferences': {'athlete_name': 'After'},
        },
      );
      await service.applyLocalState(next, expectedRevision: before.revision);
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check(
        (await service.readLocalState()).stores['preferences']?['athlete_name'],
      ).equals('After');
      final prefs = await SharedPreferences.getInstance();
      check(prefs.getString('access_token')).equals('keep-secret');
      check(prefs.getBool('has_completed_onboarding')).equals(true);
    },
  );
  test(
    'normal profile saves invalidate previews and record edit times',
    () async {
      final before = await service.readLocalState();
      final preferences = PreferencesStorage(coordinator: service.coordinator);
      await preferences.saveAthleteName('Edited');
      await check(
        service.applyLocalState(before, expectedRevision: before.revision),
      ).throws<StateError>();
      final edited = await service.readLocalState();
      check(edited.stores['preferences']?['athlete_name']).equals('Edited');
      check(
        edited.stores['preferences']?['athlete_name_modified_at'],
      ).isNotNull();
    },
  );
  test(
    'corrupt persisted history is an error, never an empty backup',
    () async {
      final box = await Hive.openBox('activities');
      await box.put('old', {'data': 'not-json'});
      await check(service.readLocalState()).throws<FormatException>();
    },
  );
  test(
    'initialization rolls back a process interrupted before commit',
    () async {
      final before = await service.readLocalState();
      await service.applyLocalState(
        LocalSnapshot(
          revision: before.revision,
          stores: {...before.stores, 'training_plans': recoveryPlan('Before')},
        ),
        expectedRevision: before.revision,
      );
      await Hive.close();
      await runInterruptedRestore(directory.path, 'before');
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check(
        recoveryPlanGoal(
          (await service.readLocalState()).stores['training_plans'],
        ),
      ).equals('Before');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test('normal activity writes share the snapshot revision', () async {
    final before = await service.readLocalState();
    final local = LocalActivityDataSource(coordinator: service.coordinator);
    await local.saveHeartRateStream(-7, [140.0, 150.0]);
    await check(
      service.applyLocalState(before, expectedRevision: before.revision),
    ).throws<StateError>();
    final after = await service.readLocalState();
    check(after.stores['hr_streams']?['-7']).isNotNull();
  });
  test(
    'committed profile survives loss of the preference platform cache',
    () async {
      final before = await service.readLocalState();
      await service.applyLocalState(
        LocalSnapshot(
          revision: before.revision,
          stores: {
            ...before.stores,
            'preferences': {'athlete_name': 'Durable'},
          },
        ),
        expectedRevision: before.revision,
      );
      await Hive.close();
      SharedPreferences.setMockInitialValues({
        'athlete_name': 'Lost',
        'access_token': 'keep-secret',
        'has_completed_onboarding': true,
      });
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check(
        (await service.readLocalState()).stores['preferences']?['athlete_name'],
      ).equals('Durable');
      check(
        (await SharedPreferences.getInstance()).getString('athlete_name'),
      ).equals('Durable');
    },
  );
  test(
    'restored positive identities remain writable without duplicate keys',
    () async {
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      await local.saveHeartRateStream(101, [140.0]);
      final before = await service.readLocalState();
      await service.applyLocalState(before, expectedRevision: before.revision);
      await local.saveHeartRateStream(101, [150.0]);
      final after = await service.readLocalState();
      check(after.stores['hr_streams']?.length).equals(1);
      check(
        (await local.getAllHeartRateStreams())[101],
      ).isNotNull().deepEquals([150.0]);
    },
  );

  test(
    'initialization retains a process-interrupted durable commit',
    () async {
      final before = await service.readLocalState();
      await service.applyLocalState(
        LocalSnapshot(
          revision: before.revision,
          stores: {...before.stores, 'training_plans': recoveryPlan('Before')},
        ),
        expectedRevision: before.revision,
      );
      await Hive.close();
      await runInterruptedRestore(directory.path, 'after');
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check(
        recoveryPlanGoal(
          (await service.readLocalState()).stores['training_plans'],
        ),
      ).equals('After');
      // A second startup proves committed journal cleanup is idempotent.
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check(
        recoveryPlanGoal(
          (await service.readLocalState()).stores['training_plans'],
        ),
      ).equals('After');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'snapshot includes old non-run records and every stored identity',
    () async {
      final local = LocalActivityDataSource(coordinator: service.coordinator);
      const old = ActivityModel(
        id: -5,
        name: 'Old walk',
        type: 'Walk',
        distance: 1000,
        movingTime: 600,
        elapsedTime: 610,
        totalElevationGain: 0,
        startDate: '2010-01-01T00:00:00Z',
        averageSpeed: 1.5,
        maxSpeed: 2,
      );
      await local.saveActivities([old, old.copyWith(id: 9007199254740991)]);
      final state = await service.readLocalState();
      check(
        state.stores['activities']?.keys.toSet(),
      ).isNotNull().deepEquals({'-5', '9007199254740991'});
      check(
        state.stores['preferences']?.containsKey('athlete_name_modified_at'),
      ).equals(false);
    },
  );
}

Future<void> runInterruptedRestore(String path, String phase) async {
  final root = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  final dartName = Platform.isWindows ? 'dart.exe' : 'dart';
  final process = await Process.start(
    '$root/bin/cache/dart-sdk/bin/$dartName',
    [
      '--packages=$root/packages/flutter_tools/.dart_tool/package_config.json',
      '$root/bin/cache/flutter_tools.snapshot',
      'test',
      '--no-pub',
      'test/data/backup/fixtures/recovery_worker.dart',
    ],
    environment: {
      'BACKUP_RECOVERY_DIRECTORY': path,
      'BACKUP_CRASH_PHASE': phase,
    },
  );
  // Drain diagnostics without waiting for inherited Windows pipe handles to
  // close: the worker's durable phase sentinel proves the injected exit ran.
  final output = process.stdout.listen((_) {});
  final errors = process.stderr.listen((_) {});
  try {
    final code = await process.exitCode.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        process.kill();
        throw TimeoutException('Disposable restore process did not exit.');
      },
    );
    check(code).not((it) => it.equals(0));
    check(await File('$path/interrupted_at').readAsString()).equals(phase);
  } finally {
    await output.cancel();
    await errors.cancel();
  }
}
