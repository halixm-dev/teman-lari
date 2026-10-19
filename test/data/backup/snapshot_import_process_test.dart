import 'dart:io';
import 'dart:typed_data';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'fixtures/interrupted_process.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final phase in ['before', 'after']) {
    test(
      'confirmed import process interruption $phase durable commit recovers exact state',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'confirmed_import_',
        );
        Hive.init(directory.path);
        SharedPreferences.setMockInitialValues({
          'athlete_name': 'Before',
          'access_token': 'secret',
          'has_completed_onboarding': true,
        });
        var service = SnapshotBackupService(
          coordinator: LocalDataCoordinator(),
        );
        await service.initialize();
        final before = await service.readLocalState();
        final bytes = Uint8List.fromList(
          await File(
            'test/fixtures/offline-backup-v1-populated.tlbackup',
          ).readAsBytes(),
        );
        await service.applyImport(await service.prepareImport(bytes));
        final committed = await service.readLocalState();
        await service.applyLocalState(
          before,
          expectedRevision: service.coordinator.revision,
        );
        await Hive.close();
        await runInterruptedBackupWorker(
          worker: 'test/data/backup/fixtures/import_worker.dart',
          directory: directory.path,
          phase: phase,
        );
        service = SnapshotBackupService(coordinator: LocalDataCoordinator());
        await service.initialize();
        final expected = phase == 'before' ? before : committed;
        check(
          (await service.readLocalState()).encode(),
        ).equals(expected.encode());
        final preferences = await SharedPreferences.getInstance();
        check(preferences.getString('access_token')).equals('secret');
        check(preferences.getBool('has_completed_onboarding')).equals(true);
        await Hive.close();
        service = SnapshotBackupService(coordinator: LocalDataCoordinator());
        await service.initialize();
        check(
          (await service.readLocalState()).encode(),
        ).equals(expected.encode());
        await Hive.close();
        await directory.delete(recursive: true);
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}
