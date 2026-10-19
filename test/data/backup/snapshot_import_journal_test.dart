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
  late FaultJournal journal;
  var failStage = false;
  SnapshotPhase? cleanupFaultPhase;
  var failCleanupFlush = false;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('merge_journal_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({'athlete_name': 'Before'});
    journal = FaultJournal(await Hive.openBox('snapshot_recovery'));
    failStage = false;
    failCleanupFlush = false;
    cleanupFaultPhase = null;
    service = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      journalFactory: () async => journal,
      onPhase: (phase, _) async {
        if (phase == SnapshotPhase.committed && failCleanupFlush) {
          journal.failFlushes = 2;
        }
        if (phase == cleanupFaultPhase) journal.failClears = 1;
        if (phase == SnapshotPhase.staged && failStage) {
          failStage = false;
          cleanupFaultPhase = null;
          throw const FileSystemException('staging fault');
        }
      },
    );
    await service.initialize();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'uncertain staging cleanup blocks writes until recovery restores the previous state',
    () async {
      final before = await service.readLocalState();
      final preview = await service.prepareImport(await incoming());
      failStage = true;
      cleanupFaultPhase = SnapshotPhase.staged;
      await check(
        service.applyImport(preview),
      ).throws<SnapshotRecoveryException>();
      check(service.coordinator.recoveryRequired).isTrue();
      await check(service.readLocalState()).throws<StateError>();
      await check(service.coordinator.write(() async {})).throws<StateError>();
      await service.initialize();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );
  test(
    'failed cleanup after durable commit gates access then retains committed state on retry',
    () async {
      final preview = await service.prepareImport(await incoming());
      cleanupFaultPhase = SnapshotPhase.committed;
      await check(
        service.applyImport(preview),
      ).throws<SnapshotRecoveryException>();
      check(service.coordinator.recoveryRequired).isTrue();
      await check(service.readLocalState()).throws<StateError>();
      await service.initialize();
      check(
        (await service.readLocalState()).stores['preferences']?['max_hr'],
      ).equals(150);
    },
  );
  test(
    'empty in-memory journal still retries its uncertain cleanup flush',
    () async {
      final preview = await service.prepareImport(await incoming());
      failCleanupFlush = true;
      await check(
        service.applyImport(preview),
      ).throws<SnapshotRecoveryException>();
      check(journal.isNotEmpty).isFalse();
      await check(service.initialize()).throws<SnapshotRecoveryException>();
      check(service.coordinator.recoveryRequired).isTrue();
      await service.initialize();
      check(
        (await service.readLocalState()).stores['preferences']?['max_hr'],
      ).equals(150);
    },
  );
  test(
    'incomplete staging can recover unchanged live data even without a complete before image',
    () async {
      final before = await service.readLocalState();
      final preview = await service.prepareImport(await incoming());
      journal.failStagingWrites = 1;
      journal.failClears = 1;
      try {
        await service.applyImport(preview);
        fail('Expected an uncertain staging failure');
      } on SnapshotRecoveryException catch (error) {
        check(error.originalCause.toString()).contains('staging write fault');
      }
      check(service.coordinator.recoveryRequired).isTrue();
      await service.initialize();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );
}

Future<Uint8List> incoming() async {
  final archive =
      jsonDecode(
            await File(
              'test/fixtures/offline-backup-v1-empty.tlbackup',
            ).readAsString(),
          )
          as Map;
  ((archive['data'] as Map)['profile'] as Map)['max_hr'] = {
    'value': 150,
    'modified_at': '2025-02-01T00:00:00Z',
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(archive)));
}

class FaultJournal implements Box<dynamic> {
  final Box<dynamic> delegate;
  int failClears = 0;
  int failFlushes = 0;
  int failStagingWrites = 0;
  FaultJournal(this.delegate);
  @override
  bool get isNotEmpty => delegate.isNotEmpty;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) => delegate.put(key, value);
  @override
  Future<void> putAll(Map<dynamic, dynamic> values) async {
    if (failStagingWrites > 0) {
      failStagingWrites--;
      await delegate.put('partial', true);
      throw const FileSystemException('staging write fault');
    }
    await delegate.putAll(values);
  }

  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  Future<void> compact() => delegate.compact();
  @override
  Future<void> flush() async {
    if (failFlushes > 0) {
      failFlushes--;
      throw const FileSystemException('cleanup flush fault');
    }
    await delegate.flush();
  }

  @override
  Future<int> clear() {
    if (failClears > 0) {
      failClears--;
      throw const FileSystemException('cleanup fault');
    }
    return delegate.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
