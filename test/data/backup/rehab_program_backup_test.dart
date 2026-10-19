import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/backup/local_data_coordinator.dart';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/repositories/local_rehab_repository.dart';
import 'package:teman_lari/domain/entities/rehab_program.dart';
import '../../domain/usecases/rehab_progression_test.dart'
    show rehabProgram, clearedFeedback;
import 'snapshot_archive_export_test.dart' show activity;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SnapshotBackupService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rehab_program_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({});
    service = SnapshotBackupService(
      coordinator: LocalDataCoordinator(),
      clock: () => DateTime.utc(2026, 10, 30),
    );
    await service.initialize();
    await LocalActivityDataSource(
      coordinator: service.coordinator,
    ).saveActivity(
      activity(-1, 'Run').copyWith(startDate: '2026-10-02T08:00:00Z'),
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'episode and new observations survive reopening and backup restore',
    () async {
      final repository = LocalRehabRepository(service: service);
      await repository.start(rehabProgram());
      await repository.saveFeedback(clearedFeedback(-1, 2, pain: 6));
      final file = await service.prepareExport();
      check(
        (jsonDecode(utf8.decode(file.bytes)) as Map)['schema_version'],
      ).equals(3);
      await repository.changeMode(ReturnModality.continuous);
      final preview = await service.prepareImport(file.bytes);
      await service.applyImport(preview, mode: BackupImportMode.replaceAll);
      await Hive.close();
      final reopened = SnapshotBackupService(
        coordinator: LocalDataCoordinator(),
      );
      await reopened.initialize();
      final restored = await LocalRehabRepository(service: reopened).read();

      check(restored.program?.mode).equals(ReturnModality.walkRun);
      check(restored.program?.graduatedAt).isNull();
      check(restored.feedback.single.acuteSharpPain).equals(false);
      check(restored.feedback.single.morningBaselineCleared).equals(true);
      check(restored.feedback.single.postRunPain).equals(6);
    },
  );

  test('smart merge retains episode and explicit observations', () async {
    final repository = LocalRehabRepository(service: service);
    await repository.start(rehabProgram());
    await repository.saveFeedback(clearedFeedback(-1, 2, pain: 6));
    final file = await service.prepareExport();
    final preview = await service.prepareImport(file.bytes);
    await service.applyImport(preview, mode: BackupImportMode.smartMerge);
    final journal = await repository.read();
    check(journal.program?.startedAt).equals(rehabProgram().startedAt);
    check(journal.feedback.single.postRunPain).equals(6);
    check(journal.feedback.single.acuteSharpPain).equals(false);
    check(journal.feedback.single.morningBaselineCleared).equals(true);
  });

  test('rehab payload cannot masquerade as an older backup schema', () async {
    final repository = LocalRehabRepository(service: service);
    await repository.start(rehabProgram());
    await repository.saveFeedback(clearedFeedback(-1, 2));
    final file = await service.prepareExport();
    final archive = jsonDecode(utf8.decode(file.bytes)) as Map<String, dynamic>;
    archive['schema_version'] = 2;
    await check(
      service.prepareImport(
        Uint8List.fromList(utf8.encode(jsonEncode(archive))),
      ),
    ).throws<FormatException>();
    check((await repository.read()).feedback.single.postRunPain).equals(2);
  });

  test('graduation requires cleared weeks and explicit confirmation', () async {
    final repository = LocalRehabRepository(service: service);
    await repository.start(rehabProgram());
    await check(repository.graduate()).throws<StateError>();
    await repository.saveFeedback(clearedFeedback(-1, 2));
    for (final entry in {-2: 7, -3: 14, -4: 21}.entries) {
      await LocalActivityDataSource(
        coordinator: service.coordinator,
      ).saveActivity(
        activity(entry.key, 'Run').copyWith(
          startDate: DateTime.utc(2026, 10, entry.value, 8).toIso8601String(),
        ),
      );
      await repository.saveFeedback(clearedFeedback(entry.key, entry.value));
    }
    check((await repository.read()).program?.graduatedAt).isNull();
    await repository.graduate();
    check(
      (await repository.read()).program?.graduatedAt,
    ).equals(DateTime.utc(2026, 10, 30));
  });
}
