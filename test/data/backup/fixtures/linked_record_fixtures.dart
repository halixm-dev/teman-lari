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

Future<Uint8List> linkedArchive(
  String owner,
  String shoeId,
  String feedbackId,
) => archiveBytes(
  [activity(owner, '2025-01-01T00:00:00Z')],
  change: (archive) {
    final data = archive['data'] as Map;
    data['heart_rate_streams'] = [
      {
        'activity_id': owner,
        'samples': [150.0],
      },
    ];
    data['equipment'] = {
      'shoes': [shoe(shoeId, shoeId)],
      'activity_assignments': [
        {
          'activity_id': owner,
          'shoe_id': shoeId,
          'modified_at': '2025-02-01T00:00:00Z',
        },
      ],
    };
    data['rehab_feedback'] = {
      'records': [
        {
          'id': feedbackId,
          'activity_id': owner,
          'injury_site': 'knee',
          'post_run_pain': 2.5,
          'post_run_recorded_at': '2025-01-01T01:00:00Z',
          'morning_after_pain': null,
          'morning_stiffness': null,
          'morning_after_recorded_at': null,
          'modified_at': '2025-02-01T00:00:00Z',
        },
      ],
    };
    (archive['counts'] as Map<String, dynamic>).addAll({
      'heart_rate_streams': 1,
      'equipment': 2,
      'rehab_feedback': 1,
    });
  },
);
