// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_plan_content_archive.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaceZoneArchive _$PaceZoneArchiveFromJson(Map<String, dynamic> json) =>
    PaceZoneArchive(
      slowestPace: const PlanDurationConverter().fromJson(
        json['slowest_pace'] as num,
      ),
      fastestPace: const PlanDurationConverter().fromJson(
        json['fastest_pace'] as num,
      ),
      label: json['label'] as String,
    );

Map<String, dynamic> _$PaceZoneArchiveToJson(
  PaceZoneArchive instance,
) => <String, dynamic>{
  'slowest_pace': const PlanDurationConverter().toJson(instance.slowestPace),
  'fastest_pace': const PlanDurationConverter().toJson(instance.fastestPace),
  'label': instance.label,
};

HrZoneArchive _$HrZoneArchiveFromJson(Map<String, dynamic> json) =>
    HrZoneArchive(
      minBpm: (json['min_bpm'] as num).toInt(),
      maxBpm: (json['max_bpm'] as num).toInt(),
      zoneNumber: (json['zone_number'] as num).toInt(),
      label: json['label'] as String,
    );

Map<String, dynamic> _$HrZoneArchiveToJson(HrZoneArchive instance) =>
    <String, dynamic>{
      'min_bpm': instance.minBpm,
      'max_bpm': instance.maxBpm,
      'zone_number': instance.zoneNumber,
      'label': instance.label,
    };

IntervalPhaseArchive _$IntervalPhaseArchiveFromJson(
  Map<String, dynamic> json,
) => IntervalPhaseArchive(
  type: $enumDecode(_$IntervalPhaseTypeEnumMap, json['type']),
  duration: const PlanDurationConverter().fromJson(json['duration'] as num),
);

Map<String, dynamic> _$IntervalPhaseArchiveToJson(
  IntervalPhaseArchive instance,
) => <String, dynamic>{
  'type': _$IntervalPhaseTypeEnumMap[instance.type]!,
  'duration': const PlanDurationConverter().toJson(instance.duration),
};

const _$IntervalPhaseTypeEnumMap = {
  IntervalPhaseType.work: 'work',
  IntervalPhaseType.recovery: 'recovery',
};

RunWalkPhaseArchive _$RunWalkPhaseArchiveFromJson(Map<String, dynamic> json) =>
    RunWalkPhaseArchive(
      type: $enumDecode(_$RunWalkPhaseTypeEnumMap, json['type']),
      runSeconds: (json['run_seconds'] as num).toInt(),
      walkSeconds: (json['walk_seconds'] as num).toInt(),
      totalDurationMinutes: (json['total_duration_minutes'] as num).toInt(),
      label: json['label'] as String,
    );

Map<String, dynamic> _$RunWalkPhaseArchiveToJson(
  RunWalkPhaseArchive instance,
) => <String, dynamic>{
  'type': _$RunWalkPhaseTypeEnumMap[instance.type]!,
  'run_seconds': instance.runSeconds,
  'walk_seconds': instance.walkSeconds,
  'total_duration_minutes': instance.totalDurationMinutes,
  'label': instance.label,
};

const _$RunWalkPhaseTypeEnumMap = {
  RunWalkPhaseType.phase1: 'phase1',
  RunWalkPhaseType.phase2: 'phase2',
  RunWalkPhaseType.phase3: 'phase3',
  RunWalkPhaseType.phase4: 'phase4',
  RunWalkPhaseType.phase5: 'phase5',
  RunWalkPhaseType.phase6: 'phase6',
  RunWalkPhaseType.continuous: 'continuous',
};

TrainingDayArchive _$TrainingDayArchiveFromJson(Map<String, dynamic> json) =>
    TrainingDayArchive(
      date: const PlanDateConverter().fromJson(json['date'] as String),
      type: $enumDecode(_$WorkoutTypeEnumMap, json['type']),
      description: json['description'] as String,
      targetMinutes: (json['target_minutes'] as num?)?.toInt(),
      warmUpMinutes: (json['warm_up_minutes'] as num?)?.toInt(),
      coolDownMinutes: (json['cool_down_minutes'] as num?)?.toInt(),
      paceTarget: json['pace_target'] == null
          ? null
          : PaceZoneArchive.fromJson(
              json['pace_target'] as Map<String, dynamic>,
            ),
      heartRateTarget: json['heart_rate_target'] == null
          ? null
          : HrZoneArchive.fromJson(
              json['heart_rate_target'] as Map<String, dynamic>,
            ),
      estimatedDuration: _$JsonConverterFromJson<num, Duration>(
        json['estimated_duration'],
        const PlanDurationConverter().fromJson,
      ),
      intervals: (json['intervals'] as List<dynamic>?)
          ?.map((e) => IntervalPhaseArchive.fromJson(e as Map<String, dynamic>))
          .toList(),
      runWalkPhase: json['run_walk_phase'] == null
          ? null
          : RunWalkPhaseArchive.fromJson(
              json['run_walk_phase'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$TrainingDayArchiveToJson(TrainingDayArchive instance) =>
    <String, dynamic>{
      'date': const PlanDateConverter().toJson(instance.date),
      'type': _$WorkoutTypeEnumMap[instance.type]!,
      'description': instance.description,
      'target_minutes': instance.targetMinutes,
      'warm_up_minutes': instance.warmUpMinutes,
      'cool_down_minutes': instance.coolDownMinutes,
      'pace_target': instance.paceTarget?.toJson(),
      'heart_rate_target': instance.heartRateTarget?.toJson(),
      'estimated_duration': _$JsonConverterToJson<num, Duration>(
        instance.estimatedDuration,
        const PlanDurationConverter().toJson,
      ),
      'intervals': instance.intervals?.map((e) => e.toJson()).toList(),
      'run_walk_phase': instance.runWalkPhase?.toJson(),
    };

const _$WorkoutTypeEnumMap = {
  WorkoutType.easy: 'easy',
  WorkoutType.tempo: 'tempo',
  WorkoutType.intervals: 'intervals',
  WorkoutType.longRun: 'longRun',
  WorkoutType.rest: 'rest',
  WorkoutType.crossTraining: 'crossTraining',
  WorkoutType.walk: 'walk',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

TrainingPlanContentArchive _$TrainingPlanContentArchiveFromJson(
  Map<String, dynamic> json,
) => TrainingPlanContentArchive(
  startDate: const PlanDateConverter().fromJson(json['start_date'] as String),
  days: (json['days'] as List<dynamic>)
      .map((e) => TrainingDayArchive.fromJson(e as Map<String, dynamic>))
      .toList(),
  goal: json['goal'] as String,
  description: json['description'] as String,
  weekInCycle: (json['week_in_cycle'] as num).toInt(),
  cyclePhase: $enumDecode(_$CyclePhaseEnumMap, json['cycle_phase']),
);

Map<String, dynamic> _$TrainingPlanContentArchiveToJson(
  TrainingPlanContentArchive instance,
) => <String, dynamic>{
  'start_date': const PlanDateConverter().toJson(instance.startDate),
  'days': instance.days.map((e) => e.toJson()).toList(),
  'goal': instance.goal,
  'description': instance.description,
  'week_in_cycle': instance.weekInCycle,
  'cycle_phase': _$CyclePhaseEnumMap[instance.cyclePhase]!,
};

const _$CyclePhaseEnumMap = {
  CyclePhase.beginner: 'beginner',
  CyclePhase.baseBuilding: 'baseBuilding',
  CyclePhase.intermediate: 'intermediate',
  CyclePhase.advanced: 'advanced',
  CyclePhase.returning: 'returning',
};
