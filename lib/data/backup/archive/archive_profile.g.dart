// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArchivePreference _$ArchivePreferenceFromJson(Map<String, dynamic> json) =>
    ArchivePreference(
      value: json['value'],
      modifiedAt: json['modified_at'] == null
          ? null
          : DateTime.parse(json['modified_at'] as String),
    );

Map<String, dynamic> _$ArchivePreferenceToJson(ArchivePreference instance) =>
    <String, dynamic>{
      'value': instance.value,
      'modified_at': instance.modifiedAt?.toIso8601String(),
    };

ArchiveProfile _$ArchiveProfileFromJson(Map<String, dynamic> json) =>
    ArchiveProfile(
      athleteName: ArchivePreference.fromJson(
        json['athlete_name'] as Map<String, dynamic>,
      ),
      dateOfBirth: ArchivePreference.fromJson(
        json['date_of_birth'] as Map<String, dynamic>,
      ),
      restingHr: ArchivePreference.fromJson(
        json['resting_hr'] as Map<String, dynamic>,
      ),
      maxHr: ArchivePreference.fromJson(json['max_hr'] as Map<String, dynamic>),
      thresholdPaceSec: ArchivePreference.fromJson(
        json['threshold_pace_sec'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$ArchiveProfileToJson(ArchiveProfile instance) =>
    <String, dynamic>{
      'athlete_name': instance.athleteName.toJson(),
      'date_of_birth': instance.dateOfBirth.toJson(),
      'resting_hr': instance.restingHr.toJson(),
      'max_hr': instance.maxHr.toJson(),
      'threshold_pace_sec': instance.thresholdPaceSec.toJson(),
    };
