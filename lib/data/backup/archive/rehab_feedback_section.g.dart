// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rehab_feedback_section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RehabFeedbackArchive _$RehabFeedbackArchiveFromJson(
  Map<String, dynamic> json,
) => RehabFeedbackArchive(
  records: (json['records'] as List<dynamic>)
      .map(
        (e) => RehabFeedbackArchiveRecord.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$RehabFeedbackArchiveToJson(
  RehabFeedbackArchive instance,
) => <String, dynamic>{
  'records': instance.records.map((e) => e.toJson()).toList(),
};

RehabFeedbackArchiveRecord _$RehabFeedbackArchiveRecordFromJson(
  Map<String, dynamic> json,
) => RehabFeedbackArchiveRecord(id: json['id'] as String);

Map<String, dynamic> _$RehabFeedbackArchiveRecordToJson(
  RehabFeedbackArchiveRecord instance,
) => <String, dynamic>{'id': instance.id};
