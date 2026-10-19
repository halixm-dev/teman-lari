import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup_normal_edit_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({'athlete_name': 'Before'});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'normal edits remain durable while a tracked workout is active',
    () async {
      final original = await service.readLocalState();
      service.coordinator.beginWorkout();
      await service.transformLocalState((state) => renamed(state, 'After'));
      await check(service.prepareExport()).throws<StateError>();
      service.coordinator.endWorkout();
      await check(
        service.applyLocalState(original, expectedRevision: original.revision),
      ).throws<StateError>();
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check(
        (await service.readLocalState()).stores['preferences']?['athlete_name'],
      ).equals('After');
    },
  );
  test('stale normal edits do not overwrite later changes', () async {
    final original = await service.readLocalState();
    await service.transformLocalState((state) => renamed(state, 'First'));
    await check(
      service.transformLocalState(
        (state) => renamed(state, 'Stale'),
        expectedRevision: original.revision,
      ),
    ).throws<StateError>();
    check(
      (await service.readLocalState()).stores['preferences']?['athlete_name'],
    ).equals('First');
  });
}

LocalSnapshot renamed(LocalSnapshot state, String name) => LocalSnapshot(
  revision: state.revision,
  stores: {
    ...state.stores,
    'preferences': {'athlete_name': name},
  },
);
