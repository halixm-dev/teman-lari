// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snapshot_archive.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SnapshotArchive _$SnapshotArchiveFromJson(Map<String, dynamic> json) =>
    SnapshotArchive(
      product: json['product'] as String? ?? 'teman_lari',
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      snapshotId: json['snapshot_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      appVersion: json['app_version'] as String,
      counts: Map<String, int>.from(json['counts'] as Map),
      data: SnapshotArchiveData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SnapshotArchiveToJson(SnapshotArchive instance) =>
    <String, dynamic>{
      'product': instance.product,
      'schema_version': instance.schemaVersion,
      'snapshot_id': instance.snapshotId,
      'created_at': instance.createdAt.toIso8601String(),
      'app_version': instance.appVersion,
      'counts': instance.counts,
      'data': instance.data.toJson(),
    };

SnapshotArchiveData _$SnapshotArchiveDataFromJson(Map<String, dynamic> json) =>
    SnapshotArchiveData(
      profile: ArchiveProfile.fromJson(json['profile'] as Map<String, dynamic>),
      activities: (json['activities'] as List<dynamic>)
          .map((e) => ArchiveActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
      heartRateStreams: (json['heart_rate_streams'] as List<dynamic>)
          .map(
            (e) => ArchiveHeartRateStream.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      trainingPlanState: TrainingPlanArchive.fromJson(
        json['training_plan_state'] as Map<String, dynamic>,
      ),
      equipment: EquipmentArchive.fromJson(
        json['equipment'] as Map<String, dynamic>,
      ),
      rehabFeedback: RehabFeedbackArchive.fromJson(
        json['rehab_feedback'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$SnapshotArchiveDataToJson(
  SnapshotArchiveData instance,
) => <String, dynamic>{
  'profile': instance.profile.toJson(),
  'activities': instance.activities.map((e) => e.toJson()).toList(),
  'heart_rate_streams': instance.heartRateStreams
      .map((e) => e.toJson())
      .toList(),
  'training_plan_state': instance.trainingPlanState.toJson(),
  'equipment': instance.equipment.toJson(),
  'rehab_feedback': instance.rehabFeedback.toJson(),
};

ArchiveActivity _$ArchiveActivityFromJson(Map<String, dynamic> json) =>
    ArchiveActivity(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      distance: (json['distance'] as num).toDouble(),
      movingTime: (json['moving_time'] as num).toInt(),
      elapsedTime: (json['elapsed_time'] as num).toInt(),
      totalElevationGain: (json['total_elevation_gain'] as num).toDouble(),
      startDate: json['start_date'] as String,
      averageSpeed: (json['average_speed'] as num).toDouble(),
      maxSpeed: (json['max_speed'] as num).toDouble(),
      averageHeartrate: (json['average_heartrate'] as num?)?.toDouble(),
      maxHeartrate: (json['max_heartrate'] as num?)?.toDouble(),
      averageCadence: (json['average_cadence'] as num?)?.toDouble(),
      sufferScore: (json['suffer_score'] as num?)?.toInt(),
      hasHeartrate: json['has_heartrate'] as bool,
      workoutType: (json['workout_type'] as num?)?.toInt(),
      perceivedExertion: (json['perceived_exertion'] as num?)?.toDouble(),
      isLocal: json['is_local'] as bool,
      identityAliases:
          (json['identity_aliases'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ArchiveActivityToJson(ArchiveActivity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'distance': instance.distance,
      'moving_time': instance.movingTime,
      'elapsed_time': instance.elapsedTime,
      'total_elevation_gain': instance.totalElevationGain,
      'start_date': instance.startDate,
      'average_speed': instance.averageSpeed,
      'max_speed': instance.maxSpeed,
      'average_heartrate': instance.averageHeartrate,
      'max_heartrate': instance.maxHeartrate,
      'average_cadence': instance.averageCadence,
      'suffer_score': instance.sufferScore,
      'has_heartrate': instance.hasHeartrate,
      'workout_type': instance.workoutType,
      'perceived_exertion': instance.perceivedExertion,
      'is_local': instance.isLocal,
      'identity_aliases': instance.identityAliases,
    };

ArchiveHeartRateStream _$ArchiveHeartRateStreamFromJson(
  Map<String, dynamic> json,
) => ArchiveHeartRateStream(
  activityId: json['activity_id'] as String,
  samples: (json['samples'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
);

Map<String, dynamic> _$ArchiveHeartRateStreamToJson(
  ArchiveHeartRateStream instance,
) => <String, dynamic>{
  'activity_id': instance.activityId,
  'samples': instance.samples,
};
