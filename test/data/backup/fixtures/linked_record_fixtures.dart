import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:teman_lari/data/backup/snapshot_backup_service.dart';

Map<String, dynamic> activity(
  String id,
  String start, {
  double distance = 1000,
  double? effort,
}) => {
  'id': id,
  'name': 'Run $id',
  'type': 'Run',
  'distance': distance,
  'moving_time': 300,
  'elapsed_time': 300,
  'total_elevation_gain': 0.0,
  'start_date': start,
  'average_speed': 3.0,
  'max_speed': 4.0,
  'average_heartrate': null,
  'max_heartrate': null,
  'average_cadence': null,
  'suffer_score': null,
  'has_heartrate': false,
  'workout_type': null,
  'perceived_exertion': effort,
  'is_local': id.startsWith('-'),
};

Future<Uint8List> archiveBytes(
  List<Map<String, dynamic>> activities, {
  void Function(Map<String, dynamic>)? change,
}) async {
  final archive =
      jsonDecode(
            await File(
              'test/fixtures/offline-backup-v1-empty.tlbackup',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  (archive['data'] as Map)['activities'] = activities;
  (archive['counts'] as Map)['activities'] = activities.length;
  change?.call(archive);
  return Uint8List.fromList(utf8.encode(jsonEncode(archive)));
}

Future<void> seed(
  SnapshotBackupService service,
  List<Map<String, dynamic>> activities,
) async {
  final before = await service.readLocalState();
  await service.applyLocalState(
    LocalSnapshot(
      revision: before.revision,
      stores: {
        ...before.stores,
        'activities': {
          for (final input in activities)
            input['id'] as String: {
              'id': int.parse(input['id'] as String),
              'data': jsonEncode(
                {...input, 'id': int.parse(input['id'] as String)}
                  ..remove('is_local'),
              ),
              'synced_at': 0,
            },
        },
      },
    ),
    expectedRevision: before.revision,
  );
}

Future<void> changeStores(
  SnapshotBackupService service,
  Map<String, Map<String, Object?>> changes,
) async {
  final before = await service.readLocalState();
  await service.applyLocalState(
    LocalSnapshot(
      revision: before.revision,
      stores: {...before.stores, ...changes},
    ),
    expectedRevision: before.revision,
  );
}

Map<String, dynamic> shoe(
  String id,
  String name, {
  String? modified = '2025-02-01T00:00:00Z',
  String? created = '2024-01-01T00:00:00Z',
}) => {
  'id': id,
  'name': name,
  'category': 'daily_trainer',
  'foam_chemistry': null,
  'lifecycle_target_meters': null,
  'performance_target_meters': null,
  'created_at': created,
  'modified_at': modified,
};
