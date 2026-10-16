import 'dart:async';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/snapshot_store_adapters.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';

void main() {
  late Directory directory;
  late SnapshotBackupService service;
  late LocalSnapshot before;
  late FailingHiveStore equipment;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('snapshot_failures_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({'athlete_name': 'Before'});
    equipment = FailingHiveStore('equipment');
    service = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      stores: SnapshotBackupService.defaultStores().map(
        (store) => store.name == 'equipment' ? equipment : store,
      ),
    );
    await service.initialize();
    before = await service.readLocalState();
    await service.applyLocalState(
      LocalSnapshot(
        revision: before.revision,
        stores: {
          ...before.stores,
          'training_plans': {'plan': 'Before'},
        },
      ),
      expectedRevision: before.revision,
    );
    before = await service.readLocalState();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  LocalSnapshot changed() => LocalSnapshot(
    revision: before.revision,
    stores: {
      ...before.stores,
      'training_plans': {'plan': 'After'},
      'equipment': {
        'shoe': {'id': 'shoe', 'name': 'After', 'category': 'daily_trainer'},
      },
      'preferences': {'athlete_name': 'After'},
    },
  );

  for (final flushFailure in [false, true]) {
    test(
      'failed ${flushFailure ? 'flush' : 'write'} rolls back every store',
      () async {
        equipment.failWrites = flushFailure ? 0 : 1;
        equipment.failFlushes = flushFailure ? 1 : 0;
        await check(
          service.applyLocalState(changed(), expectedRevision: before.revision),
        ).throws<FileSystemException>();
        await Hive.close();
        service = SnapshotBackupService(coordinator: LocalDataCoordinator());
        await service.initialize();
        check(
          (await service.readLocalState()).encode(),
        ).equals(before.encode());
      },
    );
  }

  test(
    'failed rollback blocks readers and keeps material for startup retry',
    () async {
      equipment.failWrites = 2;
      await check(
        service.applyLocalState(changed(), expectedRevision: before.revision),
      ).throws<SnapshotRecoveryException>();
      await check(service.readLocalState()).throws<StateError>();
      final prefs = PreferencesStorage(coordinator: service.coordinator);
      await check(prefs.getAthleteName()).throws<StateError>();
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );

  test('available-space refusal leaves live data unchanged', () async {
    service = SnapshotBackupService(
      coordinator: service.coordinator,
      checkAvailableSpace: (_) async => false,
    );
    await check(
      service.applyLocalState(changed(), expectedRevision: before.revision),
    ).throws<StateError>();
    check((await service.readLocalState()).encode()).equals(before.encode());
  });

  test('staging failure leaves live data unchanged', () async {
    service = SnapshotBackupService(
      coordinator: service.coordinator,
      onPhase: (phase, _) async {
        if (phase == SnapshotPhase.staged) {
          throw const FileSystemException('full');
        }
      },
    );
    await check(
      service.applyLocalState(changed(), expectedRevision: before.revision),
    ).throws<FileSystemException>();
    check((await service.readLocalState()).encode()).equals(before.encode());
  });

  test('invalid next state changes no live data', () async {
    final invalid = LocalSnapshot(
      revision: before.revision,
      stores: {
        ...before.stores,
        'preferences': {'access_token': 'forbidden'},
      },
    );
    await check(
      service.applyLocalState(invalid, expectedRevision: before.revision),
    ).throws<ArgumentError>();
    check((await service.readLocalState()).encode()).equals(before.encode());
  });

  test('active tracked workouts refuse snapshots until finished', () async {
    service.coordinator.beginWorkout();
    await check(service.readLocalState()).throws<StateError>();
    await check(
      service.applyLocalState(changed(), expectedRevision: before.revision),
    ).throws<StateError>();
    service.coordinator.endWorkout();
    check((await service.readLocalState()).encode()).equals(before.encode());
  });

  test(
    'readers and normal writes wait while restore owns all stores',
    () async {
      final staged = Completer<void>();
      final proceed = Completer<void>();
      service = SnapshotBackupService(
        coordinator: service.coordinator,
        onPhase: (phase, _) async {
          if (phase == SnapshotPhase.staged) {
            staged.complete();
            await proceed.future;
          }
        },
      );
      final apply = service.applyLocalState(
        changed(),
        expectedRevision: before.revision,
      );
      await staged.future;
      final prefs = PreferencesStorage(coordinator: service.coordinator);
      var readFinished = false;
      final read = prefs.getAthleteName().then((value) {
        readFinished = true;
        return value;
      });
      final write = prefs.saveAthleteName('Newest');
      await check(service.readLocalState()).throws<StateError>();
      check(readFinished).isFalse();
      check(() => service.coordinator.beginWorkout()).throws<StateError>();
      proceed.complete();
      await apply;
      check(await read).equals('After');
      await write;
      check(
        (await service.readLocalState()).stores['preferences']?['athlete_name'],
      ).equals('Newest');
    },
  );
  test(
    'a delayed descendant writer cannot reuse an expired operation lease',
    () async {
      final delayed = Completer<void>();
      late Future<void> descendant;
      final prefs = PreferencesStorage(coordinator: service.coordinator);
      await service.coordinator.write(() async {
        descendant = delayed.future.then(
          (_) => prefs.saveAthleteName('Delayed'),
        );
      });
      before = await service.readLocalState();
      final staged = Completer<void>();
      final proceed = Completer<void>();
      service = SnapshotBackupService(
        coordinator: service.coordinator,
        onPhase: (phase, _) async {
          if (phase == SnapshotPhase.staged) {
            staged.complete();
            await proceed.future;
          }
        },
      );
      final apply = service.applyLocalState(
        changed(),
        expectedRevision: before.revision,
      );
      await staged.future;
      var descendantFinished = false;
      descendant.then((_) => descendantFinished = true);
      delayed.complete();
      await Future<void>.delayed(Duration.zero);
      check(descendantFinished).isFalse();
      proceed.complete();
      await apply;
      await descendant;
      check(
        (await service.readLocalState()).stores['preferences']?['athlete_name'],
      ).equals('Delayed');
    },
  );
  test(
    'strict read failure aborts replacement before any live write',
    () async {
      equipment.failReads = 1;
      await check(
        service.applyLocalState(changed(), expectedRevision: before.revision),
      ).throws<FileSystemException>();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );

  test(
    'preference write failure rolls back Hive and profile together',
    () async {
      late FailingPreferenceStore preferences;
      service = SnapshotBackupService(
        coordinator: service.coordinator,
        stores: SnapshotBackupService.defaultStores().map((store) {
          if (store is PreferenceSnapshotStore) {
            preferences = FailingPreferenceStore(store.keys);
            return preferences;
          }
          return store;
        }),
      );
      preferences.failWrites = 1;
      await check(
        service.applyLocalState(changed(), expectedRevision: before.revision),
      ).throws<FileSystemException>();
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );
}

class FailingHiveStore extends HiveSnapshotStore {
  int failReads = 0;
  int failWrites = 0;
  int failFlushes = 0;
  FailingHiveStore(super.name);

  @override
  Future<Map<String, Object?>> read() async {
    if (failReads > 0) {
      failReads--;
      throw const FileSystemException('read failure');
    }
    return super.read();
  }

  @override
  Future<void> replace(Map<String, Object?> records) async {
    await super.replace(records);
    if (failWrites > 0) {
      failWrites--;
      throw const FileSystemException('write failure');
    }
  }

  @override
  Future<void> flush() async {
    await super.flush();
    if (failFlushes > 0) {
      failFlushes--;
      throw const FileSystemException('flush failure');
    }
  }
}

class FailingPreferenceStore extends PreferenceSnapshotStore {
  int failWrites = 0;
  FailingPreferenceStore(super.keys);

  @override
  Future<void> replace(Map<String, Object?> records) async {
    await super.replace(records);
    if (failWrites > 0) {
      failWrites--;
      throw const FileSystemException('preference write failure');
    }
  }
}
