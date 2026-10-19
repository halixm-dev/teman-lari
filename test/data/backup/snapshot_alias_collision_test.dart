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
    directory = await Directory.systemTemp.createTemp(
      'backup_alias_collision_',
    );
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
    'separate archives cannot assign one saved identity to two remote workouts',
    () async {
      final first = await service.prepareImport(
        await archiveBytes([_remote('100')]),
      );
      await service.applyImport(first);
      final before = await service.readLocalState();
      final second = await service.prepareImport(
        await archiveBytes([_remote('101')]),
      );
      check(second.mergeError).isNotNull();
      await check(service.applyImport(second)).throws<BackupMergeConflict>();
      check((await service.readLocalState()).encode()).equals(before.encode());
      final exported = await service.prepareExport();
      check(
        (await service.prepareImport(
          exported.bytes,
        )).archiveCounts['activities'],
      ).equals(1);
    },
  );
}

Map<String, dynamic> _remote(String id) =>
    activity(id, '2025-01-01T00:00:00Z')
      ..['identity_aliases'] = [
        {
          'source_id': '-1',
          'type': 'Run',
          'start_date': '2025-01-01T00:00:00Z',
          'distance_meters': '1000',
        },
      ];
