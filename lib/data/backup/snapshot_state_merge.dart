import 'dart:convert';
import 'archive/training_plan_section.dart';
import 'snapshot_store.dart';

bool importedStateIsNewer(Object? local, Object? incoming) =>
    local is String &&
    incoming is String &&
    DateTime.parse(incoming).isAfter(DateTime.parse(local));

(int changed, int conflicts) mergeProfileState(
  LocalSnapshot next,
  Map incoming,
) {
  final preferences = next.stores['preferences'] ?? <String, Object?>{};
  var changed = 0;
  var conflicts = 0;
  for (final key in const [
    'athlete_name',
    'date_of_birth',
    'resting_hr',
    'max_hr',
    'threshold_pace_sec',
  ]) {
    final field = incoming[key] as Map;
    final value = field['value'];
    final modified = field['modified_at'];
    if (value == null && modified == null) continue;
    final oldValue = preferences[key];
    final oldModified = preferences['${key}_modified_at'];
    if (oldValue == null && oldModified == null ||
        importedStateIsNewer(oldModified, modified)) {
      preferences.remove(key);
      preferences.remove('${key}_modified_at');
      if (value != null) preferences[key] = value;
      if (modified != null) {
        preferences['${key}_modified_at'] = DateTime.parse(
          modified as String,
        ).toUtc().toIso8601String();
      }
      changed++;
    } else if (oldValue != value) {
      conflicts++;
    }
  }
  next.stores['preferences'] = preferences;
  return (changed, conflicts);
}

(bool changed, int conflicts) mergeTrainingPlanState(
  LocalSnapshot next,
  Map incoming,
) {
  const codec = TrainingPlanSectionCodec();
  final local = codec.encode(next).toJson();
  final imported = TrainingPlanArchive.fromJson(
    Map<String, dynamic>.from(incoming),
  );
  final offered = imported.toJson();
  if (!_hasPlanState(offered)) return (false, 0);
  if (!_hasPlanState(local) ||
      importedStateIsNewer(local['modified_at'], offered['modified_at'])) {
    next.stores['training_plans'] = codec.decode(imported);
    final preferences = next.stores['preferences'] ?? <String, Object?>{};
    for (final key in ['week_in_cycle', 'cycle_start_date']) {
      preferences.remove(key);
      preferences.remove('${key}_modified_at');
    }
    preferences.addAll(codec.cyclePreferences(imported));
    next.stores['preferences'] = preferences;
    return (true, 0);
  }
  return (
    false,
    jsonEncode(_unitValues(local)) == jsonEncode(_unitValues(offered)) ? 0 : 1,
  );
}

bool _hasPlanState(Map state) =>
    (state['plans'] as List).isNotEmpty ||
    state['configuration'] != null ||
    state['active_plan_id'] != null ||
    state['modified_at'] != null ||
    ['week_in_cycle', 'cycle_start_date'].any((key) {
      final preference = state[key] as Map;
      return preference['value'] != null || preference['modified_at'] != null;
    });

Map<String, dynamic> _unitValues(Map<String, dynamic> state) {
  final values = {...state}..remove('modified_at');
  for (final key in ['week_in_cycle', 'cycle_start_date']) {
    values[key] = Map<String, dynamic>.from(values[key] as Map)
      ..remove('modified_at');
  }
  return values;
}
