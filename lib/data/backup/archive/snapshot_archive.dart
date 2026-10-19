import 'package:json_annotation/json_annotation.dart';
import 'archive_profile.dart';
import 'equipment_section.dart';
import 'rehab_feedback_section.dart';
import 'training_plan_section.dart';

part 'snapshot_archive.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class SnapshotArchive {
  static const originalSchema = 1;
  static const nullableElevationSchema = 2;
  final String product;
  final int schemaVersion;
  final String snapshotId;
  final DateTime createdAt;
  final String appVersion;
  final Map<String, int> counts;
  final SnapshotArchiveData data;
  const SnapshotArchive({
    this.product = 'teman_lari',
    this.schemaVersion = SnapshotArchive.originalSchema,
    required this.snapshotId,
    required this.createdAt,
    required this.appVersion,
    required this.counts,
    required this.data,
  });
  factory SnapshotArchive.fromJson(Map<String, dynamic> json) =>
      _$SnapshotArchiveFromJson(json);
  Map<String, dynamic> toJson() => _$SnapshotArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class SnapshotArchiveData {
  final ArchiveProfile profile;
  final List<ArchiveActivity> activities;
  final List<ArchiveHeartRateStream> heartRateStreams;
  final TrainingPlanArchive trainingPlanState;
  final EquipmentArchive equipment;
  final RehabFeedbackArchive rehabFeedback;
  const SnapshotArchiveData({
    required this.profile,
    required this.activities,
    required this.heartRateStreams,
    required this.trainingPlanState,
    required this.equipment,
    required this.rehabFeedback,
  });
  factory SnapshotArchiveData.fromJson(Map<String, dynamic> json) =>
      _$SnapshotArchiveDataFromJson(json);
  Map<String, dynamic> toJson() => _$SnapshotArchiveDataToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ArchiveActivity {
  final String id;
  final String name;
  final String type;
  final double distance;
  final int movingTime;
  final int elapsedTime;
  final double? totalElevationGain;
  final String startDate;
  final double averageSpeed;
  final double maxSpeed;
  final double? averageHeartrate;
  final double? maxHeartrate;
  final double? averageCadence;
  final int? sufferScore;
  final bool hasHeartrate;
  final int? workoutType;
  final double? perceivedExertion;
  final bool isLocal;
  final List<Map<String, dynamic>> identityAliases;
  const ArchiveActivity({
    required this.id,
    required this.name,
    required this.type,
    required this.distance,
    required this.movingTime,
    required this.elapsedTime,
    required this.totalElevationGain,
    required this.startDate,
    required this.averageSpeed,
    required this.maxSpeed,
    this.averageHeartrate,
    this.maxHeartrate,
    this.averageCadence,
    this.sufferScore,
    required this.hasHeartrate,
    this.workoutType,
    this.perceivedExertion,
    required this.isLocal,
    this.identityAliases = const [],
  });
  factory ArchiveActivity.fromJson(Map<String, dynamic> json) =>
      _$ArchiveActivityFromJson(json);
  Map<String, dynamic> toJson() => _$ArchiveActivityToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ArchiveHeartRateStream {
  final String activityId;
  final List<double> samples;
  const ArchiveHeartRateStream({
    required this.activityId,
    required this.samples,
  });
  factory ArchiveHeartRateStream.fromJson(Map<String, dynamic> json) =>
      _$ArchiveHeartRateStreamFromJson(json);
  Map<String, dynamic> toJson() => _$ArchiveHeartRateStreamToJson(this);
}
