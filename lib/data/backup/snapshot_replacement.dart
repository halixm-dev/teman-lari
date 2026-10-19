import 'dart:convert';
import 'archive/training_plan_section.dart';
import 'archive/archive_profile.dart';
import 'import_summary.dart';
import 'snapshot_smart_merge.dart';
import 'snapshot_store.dart';

SnapshotMergePlan planReplacement(
  Map<String, dynamic> archive,
  LocalSnapshot local,
) {
  final data = archive['data'] as Map;
  final activities = _replacementActivities(data);
  final plan = TrainingPlanArchive.fromJson(
    Map<String, dynamic>.from(data['training_plan_state'] as Map),
  );
  const codec = TrainingPlanSectionCodec();
  final preferences = _replacementPreferences(data['profile'] as Map)
    ..addAll(codec.cyclePreferences(plan));
  final equipment = data['equipment'] as Map;
  final feedback = (data['rehab_feedback'] as Map)['records'] as List;
  final next = LocalSnapshot(
    revision: local.revision,
    stores: {
      'activities': activities,
      'hr_streams': {
        for (final stream in data['heart_rate_streams'] as List)
          stream['activity_id'] as String: {
            'activity_id': int.parse(stream['activity_id'] as String),
            'data': jsonEncode(stream['samples']),
            'synced_at': 0,
          },
      },
      'training_plans': codec.decode(plan),
      'equipment': {
        for (final shoe in equipment['shoes'] as List)
          shoe['id'] as String: shoe,
      },
      'rehab_feedback': {
        for (final record in feedback) record['id'] as String: record,
      },
      'preferences': preferences,
    },
  );
  return SnapshotMergePlan(next, summarizeReplacement(archive, local));
}

BackupImportSummary summarizeReplacement(
  Map<String, dynamic> archive,
  LocalSnapshot local,
) {
  final data = archive['data'] as Map;
  final equipment = data['equipment'] as Map;
  final plan = TrainingPlanArchive.fromJson(
    Map<String, dynamic>.from(data['training_plan_state'] as Map),
  );
  const codec = TrainingPlanSectionCodec();
  final preferences = _replacementPreferences(data['profile'] as Map)
    ..addAll(codec.cyclePreferences(plan));
  return BackupImportSummary(
    replacedAllData: true,
    addedActivities: (data['activities'] as List).length,
    changedPreferences: _changedPreferences(
      local.stores['preferences'] ?? {},
      preferences,
      _profileFields(data['profile'] as Map).keys,
    ),
    changedTrainingPlan:
        jsonEncode(codec.encode(local).toJson()) != jsonEncode(plan.toJson()),
    addedShoes: (equipment['shoes'] as List).length,
    changedAssignments: (equipment['activity_assignments'] as List).length,
    addedFeedback: ((data['rehab_feedback'] as Map)['records'] as List).length,
    warnings: [
      'Replacement deletes local records absent from this file and restores all backup-owned settings.',
      if (!_hasReplacementValues(archive))
        'This file contains no saved data. Replacement clears your local backup data.',
    ],
  );
}

bool _hasReplacementValues(Map archive) {
  final data = archive['data'] as Map;
  final counts = archive['counts'] as Map;
  if ([
    'activities',
    'heart_rate_streams',
    'training_plan_state',
    'equipment',
    'rehab_feedback',
  ].any((key) => (counts[key] as int) > 0)) {
    return true;
  }
  if (_profileFields(
    data['profile'] as Map,
  ).values.any((field) => (field as Map)['value'] != null)) {
    return true;
  }
  final plan = data['training_plan_state'] as Map;
  return plan['configuration'] != null ||
      (plan['week_in_cycle'] as Map)['value'] != null ||
      (plan['cycle_start_date'] as Map)['value'] != null;
}

Map<String, Object?> _replacementActivities(Map data) {
  final assignments = {
    for (final row
        in (data['equipment'] as Map)['activity_assignments'] as List)
      row['activity_id'] as String: row as Map,
  };
  return {
    for (final input in data['activities'] as List)
      input['id'] as String: _replacementActivity(
        input as Map,
        assignments[input['id']],
      ),
  };
}

Map<String, Object?> _replacementActivity(Map input, Map? assignment) {
  final id = int.parse(input['id'] as String);
  final data = Map<String, dynamic>.from(input)
    ..['id'] = id
    ..remove('is_local')
    ..remove('identity_aliases');
  if (assignment != null) {
    data['shoe_id'] = assignment['shoe_id'];
    data['shoe_assignment_modified_at'] = assignment['modified_at'];
  }
  return {
    'id': id,
    'data': jsonEncode(data),
    'synced_at': 0,
    if (input['identity_aliases'] case final List aliases
        when aliases.isNotEmpty)
      'identity_aliases': aliases,
  };
}

Map<String, Object?> _replacementPreferences(Map profile) {
  final preferences = <String, Object?>{};
  for (final entry in _profileFields(profile).entries) {
    final field = entry.value as Map;
    if (field['value'] case final value?) {
      preferences[entry.key] = value;
    }
    if (field['modified_at'] case final String time) {
      preferences['${entry.key}_modified_at'] = DateTime.parse(
        time,
      ).toUtc().toIso8601String();
    }
  }
  return preferences;
}

int _changedPreferences(Map before, Map after, Iterable keys) =>
    keys.where((key) => before[key] != after[key]).length;

Map<String, dynamic> _profileFields(Map profile) =>
    ArchiveProfile.fromJson(Map<String, dynamic>.from(profile)).toJson();
