import 'package:json_annotation/json_annotation.dart';

/// Calendar dates stay on the same schedule day across device time zones.
class PlanDateConverter implements JsonConverter<DateTime, String> {
  const PlanDateConverter();
  @override
  DateTime fromJson(String json) {
    final date = DateTime.tryParse(json);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(json) ||
        date == null ||
        toJson(date) != json) {
      throw StateError('Invalid Training Plan schedule date.');
    }
    return date;
  }

  @override
  String toJson(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Fractional seconds preserve supported microsecond Duration precision.
class PlanDurationConverter implements JsonConverter<Duration, num> {
  const PlanDurationConverter();
  @override
  Duration fromJson(num value) {
    if (value < 0 || value > 9007199254.740991) {
      throw StateError('Invalid Training Plan duration.');
    }
    if (!value.isFinite || (value * 1000000).round() / 1000000 != value) {
      throw StateError('Invalid Training Plan duration precision.');
    }
    return Duration(microseconds: (value * 1000000).round());
  }

  @override
  num toJson(Duration value) => value.inMicroseconds / 1000000;
}

void validatePlanRecord(Map<String, dynamic> json) {
  const integers = {
    'target_minutes',
    'warm_up_minutes',
    'cool_down_minutes',
    'min_bpm',
    'max_bpm',
    'zone_number',
    'run_seconds',
    'walk_seconds',
    'total_duration_minutes',
    'week_in_cycle',
  };
  for (final key in [
    'duration',
    'slowest_pace',
    'fastest_pace',
    'estimated_duration',
  ]) {
    final value = json[key];
    if (value == null) continue;
    if (value is! num) throw StateError('Invalid duration type.');
    const PlanDurationConverter().fromJson(value);
  }
  for (final key in integers) {
    final value = json[key];
    if (value == null) continue;
    if (value is! int ||
        value < (key == 'week_in_cycle' ? -1 : 0) ||
        value > 9007199254740991) {
      throw StateError('Invalid Training Plan value: $key.');
    }
  }
  if (json['min_bpm'] case final int minimum) {
    final maximum = json['max_bpm'];
    if (maximum is! int || maximum < minimum || maximum > 300) {
      throw StateError('Invalid Training Plan heart rate target.');
    }
  }
  if (json['fastest_pace'] case final num fastest) {
    final slowest = json['slowest_pace'];
    if (slowest is! num || fastest > slowest) {
      throw StateError('Invalid Training Plan pace target.');
    }
  }
}

void validatePlanInstant(Object? value, {bool requireUtc = true}) {
  if (value == null) return;
  if (value is! String || value.length < 19) {
    throw StateError('Invalid Training Plan timestamp.');
  }
  const PlanDateConverter().fromJson(value.substring(0, 10));
  final instant = DateTime.tryParse(value);
  final time = RegExp(
    r'^\d{4}-\d{2}-\d{2}T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-](\d{2}):(\d{2}))?$',
  ).firstMatch(value);
  if (instant == null ||
      time == null ||
      int.parse(time.group(1) ?? '99') > 23 ||
      int.parse(time.group(2) ?? '99') > 59 ||
      int.parse(time.group(3) ?? '99') > 59 ||
      int.parse(time.group(4) ?? '0') > 23 ||
      int.parse(time.group(5) ?? '0') > 59 ||
      requireUtc && !value.endsWith('Z')) {
    throw StateError('Invalid Training Plan timestamp.');
  }
}

void validateTrainingPlanMetadata(Map<String, dynamic> json) {
  validatePlanInstant(json['modified_at']);
  for (final key in ['week_in_cycle', 'cycle_start_date']) {
    final preference = json[key];
    if (preference is! Map) throw StateError('Missing cycle state.');
    validatePlanInstant(preference['modified_at']);
    if (key == 'cycle_start_date') validatePlanInstant(preference['value']);
  }
}
