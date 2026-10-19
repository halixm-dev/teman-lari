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
  late Map<String, dynamic> archive;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('import_validation_');
    Hive.init(directory.path);
    SharedPreferences.setMockInitialValues({'athlete_name': 'Local athlete'});
    service = SnapshotBackupService(coordinator: LocalDataCoordinator());
    await service.initialize();
    archive =
        jsonDecode(
              await File(
                'test/fixtures/offline-backup-v1-empty.tlbackup',
              ).readAsString(),
            )
            as Map<String, dynamic>;
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  for (final entry in <String, Object?>{
    'schema_version': 1.5,
    'snapshot_id': '',
    'created_at': '2026-02-30T00:00:00Z',
    'app_version': 4,
    'counts': {'profile': 5},
  }.entries) {
    test('invalid ${entry.key} cannot acquire a preview', () async {
      archive[entry.key] = entry.value;
      await check(service.prepareImport(bytes(archive))).throws<Object>();
    });
  }
  test('populated historical fixture previews every section', () async {
    final populated = await populatedArchive();
    final preview = await service.prepareImport(bytes(populated));
    check(preview.archiveCounts).deepEquals({
      'profile': 5,
      'activities': 2,
      'heart_rate_streams': 1,
      'training_plan_state': 1,
      'equipment': 2,
      'rehab_feedback': 1,
    });
  });
  for (final path in [
    'data.profile.athlete_name.value',
    'data.activities.0.average_heartrate',
    'data.training_plan_state.active_plan_id',
    'data.training_plan_state.configuration.return_ramp_weeks',
    'data.training_plan_state.plans.0.plan.days.0.intervals',
    'data.equipment.shoes.0.foam_chemistry',
    'data.equipment.activity_assignments.0.modified_at',
    'data.rehab_feedback.records.0.morning_stiffness',
  ]) {
    test('missing required $path is not silently defaulted', () async {
      final populated = await populatedArchive();
      removeAt(populated, path);
      await check(service.prepareImport(bytes(populated))).throws<Object>();
    });
  }
  for (final entry in <String, Object?>{
    'data.heart_rate_streams.0.activity_id': '999',
    'data.equipment.activity_assignments.0.activity_id': '999',
    'data.equipment.activity_assignments.0.shoe_id': 'missing',
    'data.rehab_feedback.records.0.activity_id': '999',
  }.entries) {
    test('dangling ${entry.key} blocks preview', () async {
      final populated = await populatedArchive();
      setAt(populated, entry.key, entry.value);
      await check(service.prepareImport(bytes(populated))).throws<Object>();
    });
  }
  for (final path in [
    'data.activities',
    'data.heart_rate_streams',
    'data.equipment.shoes',
    'data.equipment.activity_assignments',
    'data.rehab_feedback.records',
  ]) {
    test('duplicate identity in $path blocks preview', () async {
      final populated = await populatedArchive();
      final list = at(populated, path) as List;
      list.add(list.first);
      final section = path.split('.')[1];
      final counts = populated['counts'] as Map;
      counts[section] = (counts[section] as int) + 1;
      await check(service.prepareImport(bytes(populated))).throws<Object>();
    });
  }
  for (final entry in <String, Object?>{
    'data.activities.0.id': '9223372036854775808',
    'data.activities.1.id': '-9223372036854775809',
    'data.activities.0.moving_time': 12.5,
    'data.activities.0.start_date': '2026-02-30T00:00:00Z',
    'data.activities.1.start_date': '2026-10-14T24:00:00Z',
    'data.activities.0.workout_type': 1.25,
    'data.activities.0.is_local': false,
    'data.profile.date_of_birth.value': '1941-02-29',
    'data.profile.max_hr.value': 180.5,
    'data.profile.athlete_name.modified_at': '2026-10-14T00:00:00',
    'data.equipment.shoes.0.created_at': '2026-10-14T00:00:00+24:00',
    'data.equipment.shoes.0.category': 'future_shoe',
    'data.rehab_feedback.records.0.injury_site': 'future_injury',
    'data.training_plan_state.plans.0.plan.days.0.type': 'future_workout',
    'data.training_plan_state.plans.0.plan.days.0.estimated_duration':
        0.0000001,
  }.entries) {
    test('invalid supported record ${entry.key} blocks preview', () async {
      final populated = await populatedArchive();
      setAt(populated, entry.key, entry.value);
      final before = await service.readLocalState();
      await check(service.prepareImport(bytes(populated))).throws<Object>();
      check((await service.readLocalState()).stores).deepEquals(before.stores);
    });
  }
  for (final id in ['9223372036854775807', '-9223372036854775808']) {
    test('native exact signed boundary $id survives preview', () async {
      final populated = await populatedArchive();
      setAt(populated, 'data.activities.1.id', id);
      setAt(populated, 'data.activities.1.is_local', id.startsWith('-'));
      final preview = await service.prepareImport(bytes(populated));
      check(preview.archive.data.activities.last.id).equals(id);
    });
  }
  test(
    'unknown optional metadata and escaped brackets survive preview and replacement',
    () async {
      archive['optional'] = {'future': r'[[[[[\"}}}}}' * 80};
      (archive['data'] as Map)['profile']['optional'] = 'ignored';
      for (final name in ['Guest', null]) {
        ((archive['data'] as Map)['profile']['athlete_name'] as Map)['value'] =
            name;
        final preview = await service.prepareImport(bytes(archive));
        check(preview.archive.snapshotId).equals('fixture');
        check(preview.archiveJson.containsKey('optional')).isTrue();
        await service.applyImport(preview, mode: BackupImportMode.replaceAll);
        final state = await service.readLocalState();
        check(
          state.stores['preferences']?.containsKey('optional'),
        ).equals(false);
        check(state.stores['preferences']?['athlete_name']).equals(name);
      }
    },
  );
  test('unknown required section cannot silently disappear', () async {
    (archive['data'] as Map)['future_required'] = [];
    await check(service.prepareImport(bytes(archive))).throws<Object>();
  });
  for (final depth in [63, 64]) {
    test('nesting at ${depth + 1} levels is bounded before parsing', () async {
      Object? nested;
      for (var i = 0; i < depth; i++) {
        nested = [nested];
      }
      archive['optional'] = nested;
      final result = service.prepareImport(bytes(archive));
      if (depth == 63) {
        check((await result).archive.snapshotId).equals('fixture');
      } else {
        await check(result).throws<Object>();
      }
    });
  }
  test('exact 50 MiB bytes accepted and one extra byte rejected', () async {
    final source = bytes(archive);
    final bounded = Uint8List(50 * 1024 * 1024)
      ..fillRange(0, 50 * 1024 * 1024, 32);
    bounded.setRange(0, source.length, source);
    check(
      (await service.prepareImport(bounded)).archive.snapshotId,
    ).equals('fixture');
    final oversized = Uint8List(bounded.length + 1);
    await check(service.prepareImport(oversized)).throws<Object>();
  });
  for (final malformed in ['{', '[]', '{"product":"teman_lari",}', 'null']) {
    test('malformed archive $malformed cannot preview', () async {
      await check(
        service.prepareImport(Uint8List.fromList(utf8.encode(malformed))),
      ).throws<Object>();
    });
  }
  test('invalid UTF8 and overflowing measurements cannot preview', () async {
    await check(
      service.prepareImport(Uint8List.fromList([255])),
    ).throws<Object>();
    final populated = await populatedArchive();
    final encoded = utf8
        .decode(bytes(populated))
        .replaceFirst('1234.567', '1e999');
    await check(
      service.prepareImport(Uint8List.fromList(utf8.encode(encoded))),
    ).throws<Object>();
  });
  test('missing product cannot acquire a validated preview', () async {
    archive.remove('product');
    final before = await service.readLocalState();
    await check(service.prepareImport(bytes(archive))).throws<Object>();
    check((await service.readLocalState()).stores).deepEquals(before.stores);
  });
}

Uint8List bytes(Map<String, dynamic> archive) =>
    Uint8List.fromList(utf8.encode(jsonEncode(archive)));

Future<Map<String, dynamic>> populatedArchive() async =>
    jsonDecode(
          await File(
            'test/fixtures/offline-backup-v1-populated.tlbackup',
          ).readAsString(),
        )
        as Map<String, dynamic>;

void removeAt(Map<String, dynamic> object, String path) {
  final parts = path.split('.');
  dynamic current = object;
  for (final part in parts.take(parts.length - 1)) {
    current = current is List ? current[int.parse(part)] : current[part];
  }
  (current as Map).remove(parts.last);
}

dynamic at(Map<String, dynamic> object, String path) {
  dynamic current = object;
  for (final part in path.split('.')) {
    current = current is List ? current[int.parse(part)] : current[part];
  }
  return current;
}

void setAt(Map<String, dynamic> object, String path, Object? value) {
  final parts = path.split('.');
  final parent = at(object, parts.take(parts.length - 1).join('.'));
  if (parent is List) {
    parent[int.parse(parts.last)] = value;
  } else {
    (parent as Map)[parts.last] = value;
  }
}
