import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/training_plan.dart';
import '../../../domain/entities/running_stats.dart';
import '../../../domain/entities/run_walk_phase.dart';
import 'training_plan_validation.dart';
part 'training_plan_content_archive.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class PaceZoneArchive {
  @PlanDurationConverter()
  final Duration slowestPace;
  @PlanDurationConverter()
  final Duration fastestPace;
  final String label;
  const PaceZoneArchive({
    required this.slowestPace,
    required this.fastestPace,
    required this.label,
  });
  factory PaceZoneArchive.fromDomain(PaceZone value) => PaceZoneArchive(
    slowestPace: value.slowestPace,
    fastestPace: value.fastestPace,
    label: value.label,
  );
  PaceZone toDomain() => PaceZone(
    slowestPace: slowestPace,
    fastestPace: fastestPace,
    label: label,
  );
  factory PaceZoneArchive.fromJson(Map<String, dynamic> json) {
    validatePlanRecord(json);
    return _$PaceZoneArchiveFromJson(json);
  }
  Map<String, dynamic> toJson() => _$PaceZoneArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class HrZoneArchive {
  final int minBpm;
  final int maxBpm;
  final int zoneNumber;
  final String label;
  const HrZoneArchive({
    required this.minBpm,
    required this.maxBpm,
    required this.zoneNumber,
    required this.label,
  });
  factory HrZoneArchive.fromDomain(HrZone value) => HrZoneArchive(
    minBpm: value.minBpm,
    maxBpm: value.maxBpm,
    zoneNumber: value.zoneNumber,
    label: value.label,
  );
  HrZone toDomain() => HrZone(
    minBpm: minBpm,
    maxBpm: maxBpm,
    zoneNumber: zoneNumber,
    label: label,
  );
  factory HrZoneArchive.fromJson(Map<String, dynamic> json) {
    validatePlanRecord(json);
    return _$HrZoneArchiveFromJson(json);
  }
  Map<String, dynamic> toJson() => _$HrZoneArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class IntervalPhaseArchive {
  final IntervalPhaseType type;
  @PlanDurationConverter()
  final Duration duration;
  const IntervalPhaseArchive({required this.type, required this.duration});
  factory IntervalPhaseArchive.fromDomain(IntervalPhase value) =>
      IntervalPhaseArchive(type: value.type, duration: value.duration);
  IntervalPhase toDomain() => IntervalPhase(type: type, duration: duration);
  factory IntervalPhaseArchive.fromJson(Map<String, dynamic> json) {
    validatePlanRecord(json);
    return _$IntervalPhaseArchiveFromJson(json);
  }
  Map<String, dynamic> toJson() => _$IntervalPhaseArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class RunWalkPhaseArchive {
  final RunWalkPhaseType type;
  final int runSeconds;
  final int walkSeconds;
  final int totalDurationMinutes;
  final String label;
  const RunWalkPhaseArchive({
    required this.type,
    required this.runSeconds,
    required this.walkSeconds,
    required this.totalDurationMinutes,
    required this.label,
  });
  factory RunWalkPhaseArchive.fromDomain(RunWalkPhase value) =>
      RunWalkPhaseArchive(
        type: value.type,
        runSeconds: value.runSeconds,
        walkSeconds: value.walkSeconds,
        totalDurationMinutes: value.totalDurationMinutes,
        label: value.label,
      );
  RunWalkPhase toDomain() => RunWalkPhase(
    type: type,
    runSeconds: runSeconds,
    walkSeconds: walkSeconds,
    totalDurationMinutes: totalDurationMinutes,
    label: label,
  );
  factory RunWalkPhaseArchive.fromJson(Map<String, dynamic> json) {
    validatePlanRecord(json);
    return _$RunWalkPhaseArchiveFromJson(json);
  }
  Map<String, dynamic> toJson() => _$RunWalkPhaseArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class TrainingDayArchive {
  @PlanDateConverter()
  final DateTime date;
  final WorkoutType type;
  final String description;
  final int? targetMinutes;
  final int? warmUpMinutes;
  final int? coolDownMinutes;
  final PaceZoneArchive? paceTarget;
  final HrZoneArchive? heartRateTarget;
  @PlanDurationConverter()
  final Duration? estimatedDuration;
  final List<IntervalPhaseArchive>? intervals;
  final RunWalkPhaseArchive? runWalkPhase;
  const TrainingDayArchive({
    required this.date,
    required this.type,
    required this.description,
    required this.targetMinutes,
    required this.warmUpMinutes,
    required this.coolDownMinutes,
    required this.paceTarget,
    required this.heartRateTarget,
    required this.estimatedDuration,
    required this.intervals,
    required this.runWalkPhase,
  });
  factory TrainingDayArchive.fromDomain(
    TrainingDay value,
  ) => TrainingDayArchive(
    date: value.date,
    type: value.type,
    description: value.description,
    targetMinutes: value.targetMinutes,
    warmUpMinutes: value.warmUpMinutes,
    coolDownMinutes: value.coolDownMinutes,
    paceTarget: value.paceTarget == null
        ? null
        : PaceZoneArchive.fromDomain(value.paceTarget as PaceZone),
    heartRateTarget: value.heartRateTarget == null
        ? null
        : HrZoneArchive.fromDomain(value.heartRateTarget as HrZone),
    estimatedDuration: value.estimatedDuration,
    intervals: value.intervals?.map(IntervalPhaseArchive.fromDomain).toList(),
    runWalkPhase: value.runWalkPhase == null
        ? null
        : RunWalkPhaseArchive.fromDomain(value.runWalkPhase as RunWalkPhase),
  );
  TrainingDay toDomain() => TrainingDay(
    date: date,
    type: type,
    description: description,
    targetMinutes: targetMinutes,
    warmUpMinutes: warmUpMinutes,
    coolDownMinutes: coolDownMinutes,
    paceTarget: paceTarget?.toDomain(),
    heartRateTarget: heartRateTarget?.toDomain(),
    estimatedDuration: estimatedDuration,
    intervals: intervals?.map((value) => value.toDomain()).toList(),
    runWalkPhase: runWalkPhase?.toDomain(),
  );
  factory TrainingDayArchive.fromJson(Map<String, dynamic> json) {
    validatePlanRecord(json);
    return _$TrainingDayArchiveFromJson(json);
  }
  Map<String, dynamic> toJson() => _$TrainingDayArchiveToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class TrainingPlanContentArchive {
  @PlanDateConverter()
  final DateTime startDate;
  final List<TrainingDayArchive> days;
  final String goal;
  final String description;
  final int weekInCycle;
  final CyclePhase cyclePhase;
  const TrainingPlanContentArchive({
    required this.startDate,
    required this.days,
    required this.goal,
    required this.description,
    required this.weekInCycle,
    required this.cyclePhase,
  });
  factory TrainingPlanContentArchive.fromDomain(TrainingPlan value) =>
      TrainingPlanContentArchive(
        startDate: value.startDate,
        days: value.days.map(TrainingDayArchive.fromDomain).toList(),
        goal: value.goal,
        description: value.description,
        weekInCycle: value.weekInCycle,
        cyclePhase: value.cyclePhase,
      );
  TrainingPlan toDomain() => TrainingPlan(
    startDate: startDate,
    days: days.map((value) => value.toDomain()).toList(),
    goal: goal,
    description: description,
    weekInCycle: weekInCycle,
    cyclePhase: cyclePhase,
  );
  factory TrainingPlanContentArchive.fromJson(Map<String, dynamic> json) {
    validatePlanRecord(json);
    return _$TrainingPlanContentArchiveFromJson(json);
  }
  Map<String, dynamic> toJson() => _$TrainingPlanContentArchiveToJson(this);
}
