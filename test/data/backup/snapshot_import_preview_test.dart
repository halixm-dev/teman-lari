import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    directory = await Directory.systemTemp.createTemp('import_preview_');
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
    'preview binds archive contents to the unchanged local revision',
    () async {
      final bytes = Uint8List.fromList(
        await File(
          'test/fixtures/offline-backup-v1-empty.tlbackup',
        ).readAsBytes(),
      );
      final before = await service.readLocalState();
      final preview = await service.prepareImport(bytes);
      check(preview.localRevision).equals(before.revision);
      check(preview.archive.snapshotId).equals('fixture');
      check(preview.archiveCounts['activities']).equals(0);
      check((await service.readLocalState()).encode()).equals(before.encode());
      final archive = preview.archive;
      archive.counts['activities'] = 99;
      check(preview.archiveCounts['activities']).equals(0);
      final selected = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      selected['app_version'] = 'modified';
      check(preview.archive.appVersion).equals('1.0.0+1');
    },
  );
}
