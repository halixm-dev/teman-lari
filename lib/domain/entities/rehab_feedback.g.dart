// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rehab_feedback.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RehabFeedback _$RehabFeedbackFromJson(Map<String, dynamic> json) =>
    RehabFeedback(
      id: json['id'] as String,
      activityId: feedbackActivityId(json['activity_id'] as String),
      injurySite: $enumDecode(_$InjurySiteEnumMap, json['injury_site']),
      postRunPain: (json['post_run_pain'] as num?)?.toDouble(),
      acuteSharpPain: json['acute_sharp_pain'] as bool?,
      postRunRecordedAt: feedbackInstant(
        json['post_run_recorded_at'] as String?,
      ),
      morningAfterPain: (json['morning_after_pain'] as num?)?.toDouble(),
      morningStiffness: json['morning_stiffness'] as bool?,
      morningBaselineCleared: json['morning_baseline_cleared'] as bool?,
      morningAfterRecordedAt: feedbackInstant(
        json['morning_after_recorded_at'] as String?,
      ),
      modifiedAt: feedbackInstant(json['modified_at'] as String?),
    );

Map<String, dynamic> _$RehabFeedbackToJson(RehabFeedback instance) =>
    <String, dynamic>{
      'id': instance.id,
      'activity_id': feedbackActivityIdJson(instance.activityId),
      'injury_site': _$InjurySiteEnumMap[instance.injurySite]!,
      'post_run_pain': instance.postRunPain,
      'acute_sharp_pain': ?instance.acuteSharpPain,
      'post_run_recorded_at': feedbackInstantJson(instance.postRunRecordedAt),
      'morning_after_pain': instance.morningAfterPain,
      'morning_stiffness': instance.morningStiffness,
      'morning_baseline_cleared': ?instance.morningBaselineCleared,
      'morning_after_recorded_at': feedbackInstantJson(
        instance.morningAfterRecordedAt,
      ),
      'modified_at': feedbackInstantJson(instance.modifiedAt),
    };

const _$InjurySiteEnumMap = {
  InjurySite.achilles: 'achilles',
  InjurySite.knee: 'knee',
  InjurySite.shin: 'shin',
  InjurySite.plantarFascia: 'plantarFascia',
  InjurySite.hamstring: 'hamstring',
};
