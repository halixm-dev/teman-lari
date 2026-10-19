import 'package:json_annotation/json_annotation.dart';

part 'archive_profile.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class ArchivePreference {
  final Object? value;
  final DateTime? modifiedAt;
  const ArchivePreference({required this.value, required this.modifiedAt});
  factory ArchivePreference.fromJson(Map<String, dynamic> json) =>
      _$ArchivePreferenceFromJson(json);
  Map<String, dynamic> toJson() => _$ArchivePreferenceToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class ArchiveProfile {
  final ArchivePreference athleteName;
  final ArchivePreference dateOfBirth;
  final ArchivePreference restingHr;
  final ArchivePreference maxHr;
  final ArchivePreference thresholdPaceSec;
  const ArchiveProfile({
    required this.athleteName,
    required this.dateOfBirth,
    required this.restingHr,
    required this.maxHr,
    required this.thresholdPaceSec,
  });
  factory ArchiveProfile.fromJson(Map<String, dynamic> json) =>
      _$ArchiveProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ArchiveProfileToJson(this);
}

ArchivePreference archivePreference(
  Map<String, Object?> preferences,
  String key,
) {
  final value = preferences[key];
  final valid = switch (key) {
    'athlete_name' => value == null || value is String,
    'date_of_birth' => value == null || _isCalendarDate(value),
    'resting_hr' ||
    'max_hr' ||
    'threshold_pace_sec' ||
    'week_in_cycle' => value == null || value is int && value >= 0,
    'cycle_start_date' =>
      value == null || value is String && DateTime.tryParse(value) != null,
    _ => false,
  };
  if (!valid) throw StateError('Stored preference $key is invalid.');
  final rawTime = preferences['${key}_modified_at'];
  final modified = rawTime == null
      ? null
      : DateTime.tryParse(rawTime as String);
  if (rawTime != null && modified == null) {
    throw StateError('Stored modification time for $key is invalid.');
  }
  final exportedValue = key == 'cycle_start_date' && value is String
      ? DateTime.parse(value).toUtc().toIso8601String()
      : value;
  return ArchivePreference(value: exportedValue, modifiedAt: modified?.toUtc());
}

bool _isCalendarDate(Object value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final date = DateTime.tryParse(value);
  return date != null && date.toIso8601String().substring(0, 10) == value;
}
