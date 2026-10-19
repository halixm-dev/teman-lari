// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_plan_section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrainingPlanArchive _$TrainingPlanArchiveFromJson(
  Map<String, dynamic> json,
) => TrainingPlanArchive(
  plans: (json['plans'] as List<dynamic>)
      .map((e) => TrainingPlanArchiveRecord.fromJson(e as Map<String, dynamic>))
      .toList(),
  activePlanId: json['active_plan_id'] as String?,
  configuration: json['configuration'] == null
      ? null
      : TrainingPlanConfigArchive.fromJson(
          json['configuration'] as Map<String, dynamic>,
        ),
  weekInCycle: ArchivePreference.fromJson(
    json['week_in_cycle'] as Map<String, dynamic>,
  ),
  cycleStartDate: ArchivePreference.fromJson(
    json['cycle_start_date'] as Map<String, dynamic>,
  ),
  modifiedAt: json['modified_at'] == null
      ? null
      : DateTime.parse(json['modified_at'] as String),
  rehabilitation: json['rehabilitation'] == null
      ? null
      : RehabProgram.fromJson(json['rehabilitation'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TrainingPlanArchiveToJson(
  TrainingPlanArchive instance,
) => <String, dynamic>{
  'plans': instance.plans.map((e) => e.toJson()).toList(),
  'active_plan_id': instance.activePlanId,
  'configuration': instance.configuration?.toJson(),
  'week_in_cycle': instance.weekInCycle.toJson(),
  'cycle_start_date': instance.cycleStartDate.toJson(),
  'modified_at': instance.modifiedAt?.toIso8601String(),
  'rehabilitation': ?instance.rehabilitation?.toJson(),
};

TrainingPlanArchiveRecord _$TrainingPlanArchiveRecordFromJson(
  Map<String, dynamic> json,
) => TrainingPlanArchiveRecord(
  id: json['id'] as String,
  plan: TrainingPlanContentArchive.fromJson(
    json['plan'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$TrainingPlanArchiveRecordToJson(
  TrainingPlanArchiveRecord instance,
) => <String, dynamic>{'id': instance.id, 'plan': instance.plan.toJson()};
