import 'dart:convert';
import 'dart:async';
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
  test(
    'queued preview owns selected bytes and binds changed local revision',
    () async {
      final bytes = Uint8List.fromList(
        await File(
          'test/fixtures/offline-backup-v1-empty.tlbackup',
        ).readAsBytes(),
      );
      final initial = await service.readLocalState();
      final release = Completer<void>();
      final write = service.coordinator.write(() => release.future);
      final pending = service.prepareImport(bytes);
      bytes.fillRange(0, bytes.length, 0);
      release.complete();
      await write;
      final preview = await pending;
      check(preview.snapshotId).equals('fixture');
      check(preview.localRevision).equals(initial.revision + 1);
      check(
        () => preview.localCounts['activities'] = 999,
      ).throws<UnsupportedError>();
      check(
        () => (preview.archiveJson['data'] as Map)['activities'] = [],
      ).throws<UnsupportedError>();
    },
  );

  test(
    'reused snapshot identity cannot hide different selected contents',
    () async {
      final bytes = await File(
        'test/fixtures/offline-backup-v1-empty.tlbackup',
      ).readAsBytes();
      final first = await service.prepareImport(bytes);
      final modified = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      modified['app_version'] = '2.0.0+2';
      final second = await service.prepareImport(
        Uint8List.fromList(utf8.encode(jsonEncode(modified))),
      );
      check(second.snapshotId).equals(first.snapshotId);
      check(second.archiveBinding == first.archiveBinding).isFalse();
      check(first.appVersion).equals('1.0.0+1');
    },
  );
}
