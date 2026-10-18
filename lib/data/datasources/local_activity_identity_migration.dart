import 'dart:convert';
import '../backup/activity_identity_aliases.dart';
import '../backup/snapshot_backup_service.dart';
import '../models/activity_model.dart';

Future<void> migrateLocalActivityIdentity(
  SnapshotBackupService service,
  int oldId,
  ActivityModel uploaded,
) => service.transformLocalState((state) {
  if (oldId == uploaded.id) return state;
  final activities = {...?state.stores['activities']};
  final old = activities.remove('$oldId');
  if (old is! Map || activities.containsKey('${uploaded.id}')) {
    throw StateError(
      'Activity identity changed or destination already exists.',
    );
  }
  activities['${uploaded.id}'] = _uploadedRow(old, uploaded);
  final streams = _remapStream(
    state.stores['hr_streams'] ?? {},
    oldId,
    uploaded.id,
  );
  final feedback = (state.stores['rehab_feedback'] ?? {}).map((key, value) {
    final row = Map<String, Object?>.from(value as Map);
    if (row['activity_id'] == '$oldId') row['activity_id'] = '${uploaded.id}';
    return MapEntry(key, row);
  });
  return LocalSnapshot(
    revision: state.revision,
    stores: {
      ...state.stores,
      'activities': activities,
      'hr_streams': streams,
      'rehab_feedback': feedback,
    },
  );
});

Map<String, Object?> _remapStream(
  Map<String, Object?> records,
  int oldId,
  int newId,
) {
  final streams = {...records};
  final old = streams.remove('$oldId');
  if (old != null) {
    if (streams.containsKey('$newId')) {
      throw StateError('Destination stream already exists.');
    }
    streams['$newId'] = {
      ...Map<String, Object?>.from(old as Map),
      'activity_id': newId,
    };
  }
  return streams;
}

Map<String, Object?> _uploadedRow(Map old, ActivityModel uploaded) {
  final current = jsonDecode(old['data'] as String) as Map<String, dynamic>;
  final updated = uploaded.toJson();
  for (final key in [
    'perceived_exertion',
    'workout_type',
    'shoe_id',
    'shoe_assignment_modified_at',
  ]) {
    if (current.containsKey(key)) updated[key] = current[key];
  }
  final aliases = {
    for (final alias in validatedActivityAliases(
      old['identity_aliases'],
      owner: current,
    ))
      activityAliasKey(alias): alias,
    if ((current['id'] as int) < 0)
      activityAliasKey(activityIdentityContext(current)):
          activityIdentityContext(current),
  };
  return {
    ...Map<String, Object?>.from(old),
    if (aliases.isNotEmpty) 'identity_aliases': aliases.values.toList(),
    'id': uploaded.id,
    'data': jsonEncode(updated),
  };
}
