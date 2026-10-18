import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  late Map<String, FaultingSnapshotStore> faults;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('confirmed_merge_fault_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({
      'athlete_name': 'Before',
      'athlete_name_modified_at': '2025-01-01T00:00:00Z',
      'onboarding_complete': true,
      'access_token': 'untouched',
    });
    faults = {
      for (final store in SnapshotBackupService.defaultStores())
        store.name: FaultingSnapshotStore(store),
    };
    service = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      stores: faults.values,
    );
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final name in [
    'activities',
    'hr_streams',
    'training_plans',
    'equipment',
    'rehab_feedback',
    'preferences',
  ]) {
    for (final duringFlush in [false, true]) {
      test(
        'confirmed import recovers every store after $name ${duringFlush ? 'flush' : 'write'} failure',
        () async {
          final before = await service.readLocalState();
          final preview = await service.prepareImport(
            await File(
              'test/fixtures/offline-backup-v1-populated.tlbackup',
            ).readAsBytes(),
          );
          final fault = faults[name];
          if (fault == null) fail('Missing fault adapter');
          if (duringFlush) {
            fault.failFlushes = 1;
          } else {
            fault.failWrites = 1;
          }
          await check(
            service.applyImport(preview),
          ).throws<FileSystemException>();
          await Hive.close();
          service = SnapshotBackupService(coordinator: LocalDataCoordinator());
          await service.initialize();
          check(
            (await service.readLocalState()).encode(),
          ).equals(before.encode());
          final preferences = await SharedPreferences.getInstance();
          check(preferences.getString('access_token')).equals('untouched');
          check(preferences.getBool('onboarding_complete')).equals(true);
        },
      );
    }
  }
  test(
    'confirmed merge rollback failure blocks normal edits until a successful recovery retry',
    () async {
      final before = await service.readLocalState();
      final preview = await service.prepareImport(
        await File(
          'test/fixtures/offline-backup-v1-populated.tlbackup',
        ).readAsBytes(),
      );
      final equipment = faults['equipment'];
      if (equipment == null) fail('Missing equipment fault');
      equipment.failWrites = 2;
      await check(
        service.applyImport(preview),
      ).throws<SnapshotRecoveryException>();
      final preferences = PreferencesStorage(coordinator: service.coordinator);
      await check(preferences.saveAthleteName('Blocked')).throws<StateError>();
      await service.initialize();
      check((await service.readLocalState()).encode()).equals(before.encode());
      await preferences.saveAthleteName('Newest');
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      check(
        (await service.readLocalState()).stores['preferences']?['athlete_name'],
      ).equals('Newest');
    },
  );
}

class FaultingSnapshotStore extends SnapshotStore {
  final SnapshotStore delegate;
  int failWrites = 0;
  int failFlushes = 0;
  FaultingSnapshotStore(this.delegate);
  @override
  String get name => delegate.name;
  @override
  Future<Map<String, Object?>> read() => delegate.read();
  @override
  void validate(Map<String, Object?> records) => delegate.validate(records);
  @override
  Future<void> replace(Map<String, Object?> records) async {
    await delegate.replace(records);
    if (failWrites > 0) {
      failWrites--;
      throw const FileSystemException('injected store write failure');
    }
  }

  @override
  Future<void> flush() async {
    await delegate.flush();
    if (failFlushes > 0) {
      failFlushes--;
      throw const FileSystemException('injected store flush failure');
    }
  }
}
