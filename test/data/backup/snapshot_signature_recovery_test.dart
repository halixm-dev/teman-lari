import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'fixtures/linked_record_fixtures.dart';
import 'fixtures/interrupted_process.dart';
import 'fixtures/faulting_snapshot_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  late Map<String, FaultingSnapshotStore> faults;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('signature_recovery_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({
      'athlete_name': 'Before',
      'access_token': 'secret',
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
    await service.applyImport(
      await service.prepareImport(
        await linkedArchive('-1', 'local-shoe', 'local-feedback'),
      ),
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final store in [
    'activities',
    'hr_streams',
    'rehab_feedback',
    'preferences',
  ]) {
    test(
      'signature remapping rolls every store back after $store fails',
      () async {
        final before = await service.readLocalState();
        final preview = await service.prepareImport(
          await linkedArchive('100', 'remote-shoe', 'remote-feedback'),
        );
        final fault = faults[store];
        if (fault == null) fail('Missing failure adapter');
        fault.failWrites = 1;
        await check(service.applyImport(preview)).throws<FileSystemException>();
        await Hive.close();
        service = SnapshotBackupService(coordinator: LocalDataCoordinator());
        await service.initialize();
        check(
          (await service.readLocalState()).encode(),
        ).equals(before.encode());
        check(
          (await SharedPreferences.getInstance()).getString('access_token'),
        ).equals('secret');
      },
    );
  }
  for (final phase in ['before', 'after']) {
    test(
      'signature references recover together after process interruption $phase commit',
      () async {
        final before = await service.readLocalState();
        final bytes = await linkedArchive(
          '100',
          'remote-shoe',
          'remote-feedback',
        );
        await service.applyImport(await service.prepareImport(bytes));
        final committed = await service.readLocalState();
        await service.applyLocalState(
          before,
          expectedRevision: service.coordinator.revision,
        );
        final archive = File('${directory.path}/incoming.tlbackup');
        await archive.writeAsBytes(bytes, flush: true);
        await Hive.close();
        await runInterruptedBackupWorker(
          worker: 'test/data/backup/fixtures/import_worker.dart',
          directory: directory.path,
          phase: phase,
          environment: {'BACKUP_ARCHIVE_PATH': archive.path},
        );
        service = SnapshotBackupService(coordinator: LocalDataCoordinator());
        await service.initialize();
        check(
          (await service.readLocalState()).encode(),
        ).equals((phase == 'before' ? before : committed).encode());
        check(
          (await SharedPreferences.getInstance()).getString('access_token'),
        ).equals('secret');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}
