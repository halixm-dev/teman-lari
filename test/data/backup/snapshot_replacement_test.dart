import 'dart:convert';
import 'dart:io';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/backup/archive/snapshot_archive.dart';
import 'fixtures/linked_record_fixtures.dart';
import 'fixtures/faulting_snapshot_store.dart';
import 'fixtures/interrupted_process.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  late Map<String, FaultingSnapshotStore> faults;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('replacement_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({
      'athlete_name': 'Newer local name',
      'athlete_name_modified_at': '2030-01-01T00:00:00.000Z',
      'access_token': 'native-secret',
      'strava_refresh_token': 'web-secret',
      'has_completed_onboarding': true,
      'unrelated': 'keep',
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
  test(
    'replacement installs the complete archive and removes absent local data after reopen',
    () async {
      await seed(service, [activity('-77', '2025-02-01T00:00:00Z')]);
      final bytes = await File(
        'test/fixtures/offline-backup-v1-populated.tlbackup',
      ).readAsBytes();
      final preview = await service.prepareImport(bytes);
      check(preview.replacementSummary.changedPreferences).equals(2);
      final result = await service.applyImport(
        preview,
        mode: BackupImportMode.replaceAll,
      );
      check(result.changedPreferences).equals(2);
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final expected = SnapshotArchive.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      ).data.toJson();
      final actual =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes))['data']
              as Map;
      for (final data in [actual, expected]) {
        for (final row in data['activities'] as List) {
          row['start_date'] = DateTime.parse(
            row['start_date'] as String,
          ).toUtc().toIso8601String();
        }
        (data['activities'] as List).sort(
          (a, b) => (a['id'] as String).compareTo(b['id'] as String),
        );
      }
      check(actual).deepEquals(expected);
      final prefs = await SharedPreferences.getInstance();
      check(prefs.getString('access_token')).equals('native-secret');
      check(prefs.getString('strava_refresh_token')).equals('web-secret');
      check(prefs.getBool('has_completed_onboarding')).equals(true);
      check(prefs.getString('unrelated')).equals('keep');
    },
  );
  test(
    'empty replacement clears all owned values and explicit nulls retain their modification time',
    () async {
      await service.applyImport(
        await service.prepareImport(
          await File(
            'test/fixtures/offline-backup-v1-populated.tlbackup',
          ).readAsBytes(),
        ),
        mode: BackupImportMode.replaceAll,
      );
      final bytes = await archiveBytes(
        [],
        change: (archive) {
          ((archive['data'] as Map)['profile'] as Map)['athlete_name'] = {
            'value': null,
            'modified_at': '2025-01-01T00:00:00.000Z',
          };
        },
      );
      await service.applyImport(
        await service.prepareImport(bytes),
        mode: BackupImportMode.replaceAll,
      );
      await Hive.close();
      service = SnapshotBackupService(coordinator: LocalDataCoordinator());
      await service.initialize();
      final state = await service.readLocalState();
      for (final name in [
        'activities',
        'hr_streams',
        'equipment',
        'rehab_feedback',
      ]) {
        check(state.stores[name]).isNotNull().isEmpty();
      }
      final data =
          jsonDecode(utf8.decode((await service.prepareExport()).bytes))['data']
              as Map;
      check(((data['training_plan_state'] as Map)['plans'] as List)).isEmpty();
      check(
        ((data['profile'] as Map)['athlete_name'] as Map<String, dynamic>),
      ).deepEquals({'value': null, 'modified_at': '2025-01-01T00:00:00.000Z'});
      check(state.stores['preferences']?['athlete_name']).isNull();
      final prefs = await SharedPreferences.getInstance();
      check(prefs.getString('access_token')).equals('native-secret');
      check(prefs.getString('unrelated')).equals('keep');
    },
  );
  test(
    'replacement refuses stale confirmation without clearing current data',
    () async {
      final preview = await service.prepareImport(await archiveBytes([]));
      await PreferencesStorage(
        coordinator: service.coordinator,
      ).saveAthleteName('Changed while preview was open');
      final before = await service.readLocalState();
      await check(
        service.applyImport(preview, mode: BackupImportMode.replaceAll),
      ).throws<SnapshotImportPreviewStale>();
      check((await service.readLocalState()).encode()).equals(before.encode());
    },
  );
  for (final name in [
    'activities',
    'hr_streams',
    'training_plans',
    'equipment',
    'rehab_feedback',
    'preferences',
  ]) {
    for (final flush in [false, true]) {
      test(
        'replacement restores all stores after $name ${flush ? 'flush' : 'clear/write'} failure',
        () async {
          await service.applyImport(
            await service.prepareImport(
              await File(
                'test/fixtures/offline-backup-v1-populated.tlbackup',
              ).readAsBytes(),
            ),
            mode: BackupImportMode.replaceAll,
          );
          final before = await service.readLocalState();
          final preview = await service.prepareImport(await archiveBytes([]));
          final fault = faults[name];
          if (fault == null) fail('Missing failure adapter');
          if (flush) {
            fault.failFlushes = 1;
          } else {
            fault.failWrites = 1;
          }
          await check(
            service.applyImport(preview, mode: BackupImportMode.replaceAll),
          ).throws<FileSystemException>();
          await Hive.close();
          service = SnapshotBackupService(coordinator: LocalDataCoordinator());
          await service.initialize();
          check(
            (await service.readLocalState()).encode(),
          ).equals(before.encode());
          check(
            (await SharedPreferences.getInstance()).getString('access_token'),
          ).equals('native-secret');
        },
      );
    }
  }
  for (final phase in ['before', 'after']) {
    test(
      'replacement process interruption $phase commit recovers all sections',
      () async {
        await service.applyImport(
          await service.prepareImport(
            await File(
              'test/fixtures/offline-backup-v1-populated.tlbackup',
            ).readAsBytes(),
          ),
          mode: BackupImportMode.replaceAll,
        );
        final before = await service.readLocalState();
        final bytes = await archiveBytes([]);
        await service.applyImport(
          await service.prepareImport(bytes),
          mode: BackupImportMode.replaceAll,
        );
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
          environment: {
            'BACKUP_ARCHIVE_PATH': archive.path,
            'BACKUP_IMPORT_MODE': 'replace',
          },
        );
        service = SnapshotBackupService(coordinator: LocalDataCoordinator());
        await service.initialize();
        check(
          (await service.readLocalState()).encode(),
        ).equals((phase == 'before' ? before : committed).encode());
        check(
          (await SharedPreferences.getInstance()).getString('access_token'),
        ).equals('native-secret');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}
