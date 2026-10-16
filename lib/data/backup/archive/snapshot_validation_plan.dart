import '../../../domain/usecases/training_plan_config.dart';
import 'snapshot_validation_values.dart';
import 'training_plan_config_archive.dart';

void validateArchivePlan(Object? value) {
  archiveShape(value, {
    'plans': archiveList(_planRecord),
    'active_plan_id': archiveNullable(archiveNonempty),
    'configuration': archiveNullable(_configuration),
    'week_in_cycle': (v) => archivePreference(v, archiveNonnegativeInteger),
    'cycle_start_date': (v) => archivePreference(v, archiveInstant),
    'modified_at': archiveNullable(archiveInstant),
  });
  archiveUnique(archiveObject(value)['plans'] as List, 'id');
}

void _configuration(Object? value) {
  final template = TrainingPlanConfigArchive.fromDomain(
    TrainingPlanConfig.defaultConfig,
  ).toJson();
  archiveShape(value, {
    for (final entry in template.entries)
      entry.key: entry.value is int ? archiveInteger : archiveNumber,
  });
}

void _planRecord(Object? value) {
  archiveShape(value, {'id': archiveNonempty, 'plan': _plan});
}

void _plan(Object? value) {
  archiveShape(value, {
    'start_date': archiveDate,
    'days': archiveList(_day),
    'goal': archiveString,
    'description': archiveString,
    'week_in_cycle': archiveInteger,
    'cycle_phase': archiveString,
  });
}

void _day(Object? value) {
  archiveShape(value, {
    'date': archiveDate,
    'type': archiveString,
    'description': archiveString,
    'target_minutes': archiveNullable(archiveNonnegativeInteger),
    'warm_up_minutes': archiveNullable(archiveNonnegativeInteger),
    'cool_down_minutes': archiveNullable(archiveNonnegativeInteger),
    'pace_target': archiveNullable(_pace),
    'heart_rate_target': archiveNullable(_heartRate),
    'estimated_duration': archiveNullable(archiveDuration),
    'intervals': archiveNullable(archiveList(_interval)),
    'run_walk_phase': archiveNullable(_runWalk),
  });
}

void _pace(Object? value) {
  archiveShape(value, {
    'slowest_pace': archiveDuration,
    'fastest_pace': archiveDuration,
    'label': archiveString,
  });
}

void _heartRate(Object? value) {
  archiveShape(value, {
    'min_bpm': archiveNonnegativeInteger,
    'max_bpm': archiveNonnegativeInteger,
    'zone_number': archiveNonnegativeInteger,
    'label': archiveString,
  });
}

void _interval(Object? value) {
  archiveShape(value, {'type': archiveString, 'duration': archiveDuration});
}

void _runWalk(Object? value) {
  archiveShape(value, {
    'type': archiveString,
    'run_seconds': archiveNonnegativeInteger,
    'walk_seconds': archiveNonnegativeInteger,
    'total_duration_minutes': archiveNonnegativeInteger,
    'label': archiveString,
  });
}
