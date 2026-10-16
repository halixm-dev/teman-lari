// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shoe_equipment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShoeEquipment _$ShoeEquipmentFromJson(Map<String, dynamic> json) =>
    ShoeEquipment(
      id: json['id'] as String,
      name: json['name'] as String,
      category: $enumDecode(_$ShoeCategoryEnumMap, json['category']),
      foamChemistry: $enumDecodeNullable(
        _$FoamChemistryEnumMap,
        json['foam_chemistry'],
      ),
      lifecycleTargetMeters: (json['lifecycle_target_meters'] as num?)
          ?.toDouble(),
      performanceTargetMeters: (json['performance_target_meters'] as num?)
          ?.toDouble(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      modifiedAt: json['modified_at'] == null
          ? null
          : DateTime.parse(json['modified_at'] as String),
    );

Map<String, dynamic> _$ShoeEquipmentToJson(ShoeEquipment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': _$ShoeCategoryEnumMap[instance.category]!,
      'foam_chemistry': _$FoamChemistryEnumMap[instance.foamChemistry],
      'lifecycle_target_meters': instance.lifecycleTargetMeters,
      'performance_target_meters': instance.performanceTargetMeters,
      'created_at': instance.createdAt?.toIso8601String(),
      'modified_at': instance.modifiedAt?.toIso8601String(),
    };

const _$ShoeCategoryEnumMap = {
  ShoeCategory.dailyTrainer: 'daily_trainer',
  ShoeCategory.maxCushionRecovery: 'max_cushion_recovery',
  ShoeCategory.tempoWorkout: 'tempo_workout',
  ShoeCategory.raceDayPlated: 'race_day_plated',
};

const _$FoamChemistryEnumMap = {
  FoamChemistry.supercriticalPebaTpu: 'supercritical_peba_tpu',
  FoamChemistry.traditionalEva: 'traditional_eva',
};
