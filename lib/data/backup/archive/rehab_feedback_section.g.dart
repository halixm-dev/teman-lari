// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rehab_feedback_section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RehabFeedbackArchive _$RehabFeedbackArchiveFromJson(
  Map<String, dynamic> json,
) => RehabFeedbackArchive(
  records: (json['records'] as List<dynamic>)
      .map((e) => RehabFeedback.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RehabFeedbackArchiveToJson(
  RehabFeedbackArchive instance,
) => <String, dynamic>{
  'records': instance.records.map((e) => e.toJson()).toList(),
};
