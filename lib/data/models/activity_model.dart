import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_model.freezed.dart';
part 'activity_model.g.dart';

@freezed
abstract class ActivityModel with _$ActivityModel {
  const ActivityModel._();

  const factory ActivityModel({
    required int id,
    required String name,
    required String type,
    required double distance,
    required int movingTime,
    required int elapsedTime,
    required double totalElevationGain,
    required String startDate,
    required double averageSpeed,
    required double maxSpeed,
    double? averageHeartrate,
    double? maxHeartrate,
    double? averageCadence,
    int? sufferScore,
    @Default(false) bool hasHeartrate,
    int? workoutType,
    double? perceivedExertion,
    String? shoeId,
    DateTime? shoeAssignmentModifiedAt,
  }) = _ActivityModel;

  factory ActivityModel.fromJson(Map<String, dynamic> json) =>
      _$ActivityModelFromJson(json);
}
