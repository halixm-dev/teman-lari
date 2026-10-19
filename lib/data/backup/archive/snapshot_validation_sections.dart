import '../activity_identity_aliases.dart';
import 'snapshot_validation_values.dart';
import 'snapshot_validation_plan.dart';

void validateArchiveSections(
  Map<String, dynamic> data, {
  bool nullableElevation = false,
  bool rehabilitation = false,
}) {
  _profile(data['profile']);
  archiveList(
    (value) => _activity(value, nullableElevation: nullableElevation),
  )(data['activities']);
  validateArchiveAliasOwnership(data['activities'] as List);
  archiveList(_stream)(data['heart_rate_streams']);
  validateArchivePlan(
    data['training_plan_state'],
    rehabilitation: rehabilitation,
  );
  archiveShape(data['equipment'], {
    'shoes': archiveList(_shoe),
    'activity_assignments': archiveList(_assignment),
  });
  archiveShape(data['rehab_feedback'], {
    'records': archiveList((v) => _feedback(v, rehabilitation: rehabilitation)),
  });
}

void _profile(Object? value) {
  archiveShape(value, {
    'athlete_name': (v) => archivePreference(v, archiveString),
    'date_of_birth': (v) => archivePreference(v, archiveDate),
    'resting_hr': (v) => archivePreference(v, archiveNonnegativeInteger),
    'max_hr': (v) => archivePreference(v, archiveNonnegativeInteger),
    'threshold_pace_sec': (v) =>
        archivePreference(v, archiveNonnegativeInteger),
  });
}

void _activity(Object? value, {required bool nullableElevation}) {
  final row = archiveShape(value, {
    'id': archiveIdentity,
    'name': archiveString,
    'type': archiveNonempty,
    'distance': archiveNonnegative,
    'moving_time': archiveNonnegativeInteger,
    'elapsed_time': archiveNonnegativeInteger,
    'total_elevation_gain': nullableElevation
        ? archiveNullable(archiveNumber)
        : archiveNumber,
    'start_date': archiveInstant,
    'average_speed': archiveNumber,
    'max_speed': archiveNumber,
    'average_heartrate': archiveNullable(archiveNumber),
    'max_heartrate': archiveNullable(archiveNumber),
    'average_cadence': archiveNullable(archiveNumber),
    'suffer_score': archiveNullable(archiveInteger),
    'has_heartrate': archiveBool,
    'workout_type': archiveNullable(archiveInteger),
    'perceived_exertion': archiveNullable(archiveNumber),
    'is_local': archiveBool,
  });
  if (row.containsKey('identity_aliases')) {
    if (row['identity_aliases'] == null) {
      throw FormatException('Invalid Activity aliases.');
    }
    validatedActivityAliases(row['identity_aliases'], owner: row);
  }
  if (row['is_local'] != (BigInt.parse(row['id'] as String) < BigInt.zero)) {
    throw FormatException('Activity local marker disagrees with identity.');
  }
}

void _stream(Object? value) {
  archiveShape(value, {
    'activity_id': archiveIdentity,
    'samples': archiveList(archiveNumber),
  });
}

void _shoe(Object? value) {
  archiveShape(value, {
    'id': archiveNonempty,
    'name': archiveNonempty,
    'category': archiveString,
    'foam_chemistry': archiveNullable(archiveString),
    'lifecycle_target_meters': archiveNullable(archiveNumber),
    'performance_target_meters': archiveNullable(archiveNumber),
    'created_at': archiveNullable(archiveInstant),
    'modified_at': archiveNullable(archiveInstant),
  });
}

void _assignment(Object? value) {
  final row = archiveShape(value, {
    'activity_id': archiveIdentity,
    'shoe_id': archiveNullable(archiveNonempty),
    'modified_at': archiveNullable(archiveInstant),
  });
  if (row['shoe_id'] == null && row['modified_at'] == null) {
    throw FormatException('Empty shoe assignment has no clear timestamp.');
  }
}

void _feedback(Object? value, {required bool rehabilitation}) {
  final row = archiveShape(value, {
    'id': archiveNonempty,
    'activity_id': archiveIdentity,
    'injury_site': archiveString,
    'post_run_pain': archiveNullable(archiveNumber),
    'post_run_recorded_at': archiveNullable(archiveInstant),
    'morning_after_pain': archiveNullable(archiveNumber),
    'morning_stiffness': archiveNullable(archiveBool),
    'morning_after_recorded_at': archiveNullable(archiveInstant),
    'modified_at': archiveNullable(archiveInstant),
  });
  for (final key in ['acute_sharp_pain', 'morning_baseline_cleared']) {
    if (row[key] != null && !rehabilitation) {
      throw const FormatException(
        'Rehab observations require backup schema 3.',
      );
    }
    if (row.containsKey(key)) archiveNullable(archiveBool)(row[key]);
  }
}
