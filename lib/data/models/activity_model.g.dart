// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActivityModel _$ActivityModelFromJson(Map<String, dynamic> json) =>
    _ActivityModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      distance: (json['distance'] as num).toDouble(),
      movingTime: (json['moving_time'] as num).toInt(),
      elapsedTime: (json['elapsed_time'] as num).toInt(),
      totalElevationGain: (json['total_elevation_gain'] as num?)?.toDouble(),
      startDate: json['start_date'] as String,
      averageSpeed: (json['average_speed'] as num).toDouble(),
      maxSpeed: (json['max_speed'] as num).toDouble(),
      averageHeartrate: (json['average_heartrate'] as num?)?.toDouble(),
      maxHeartrate: (json['max_heartrate'] as num?)?.toDouble(),
      averageCadence: (json['average_cadence'] as num?)?.toDouble(),
      sufferScore: (json['suffer_score'] as num?)?.toInt(),
      hasHeartrate: json['has_heartrate'] as bool? ?? false,
      workoutType: (json['workout_type'] as num?)?.toInt(),
      perceivedExertion: (json['perceived_exertion'] as num?)?.toDouble(),
      shoeId: json['shoe_id'] as String?,
      shoeAssignmentModifiedAt: json['shoe_assignment_modified_at'] == null
          ? null
          : DateTime.parse(json['shoe_assignment_modified_at'] as String),
    );

Map<String, dynamic> _$ActivityModelToJson(_ActivityModel instance) =>
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
      'shoe_id': instance.shoeId,
      'shoe_assignment_modified_at': instance.shoeAssignmentModifiedAt
          ?.toIso8601String(),
    };
