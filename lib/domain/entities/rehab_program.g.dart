// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rehab_program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RehabProgram _$RehabProgramFromJson(Map<String, dynamic> json) => RehabProgram(
  startedAt: requiredRehabInstant(json['started_at'] as String),
  injurySite: $enumDecode(_$InjurySiteEnumMap, json['injury_site']),
  mode: $enumDecode(_$ReturnModalityEnumMap, json['mode']),
  initialWeeklyMinutes: (json['initial_weekly_minutes'] as num).toDouble(),
  rampWeeks: (json['ramp_weeks'] as num).toInt(),
  graduatedAt: feedbackInstant(json['graduated_at'] as String?),
);

Map<String, dynamic> _$RehabProgramToJson(RehabProgram instance) =>
    <String, dynamic>{
      'started_at': feedbackInstantJson(instance.startedAt),
      'injury_site': _$InjurySiteEnumMap[instance.injurySite]!,
      'mode': _$ReturnModalityEnumMap[instance.mode]!,
      'initial_weekly_minutes': instance.initialWeeklyMinutes,
      'ramp_weeks': instance.rampWeeks,
      'graduated_at': feedbackInstantJson(instance.graduatedAt),
    };

const _$InjurySiteEnumMap = {
  InjurySite.achilles: 'achilles',
  InjurySite.knee: 'knee',
  InjurySite.shin: 'shin',
  InjurySite.plantarFascia: 'plantarFascia',
  InjurySite.hamstring: 'hamstring',
};

const _$ReturnModalityEnumMap = {
  ReturnModality.walkRun: 'walkRun',
  ReturnModality.continuous: 'continuous',
};
