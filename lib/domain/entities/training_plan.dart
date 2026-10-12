import 'run_walk_phase.dart';
import 'running_stats.dart';
import 'workout_type.dart';
export 'workout_type.dart';

class TrainingDay {
  final DateTime date;
  final WorkoutType type;
  final int? targetMinutes;
  final int? warmUpMinutes;
  final int? coolDownMinutes;
  final PaceZone? paceTarget;
  final HrZone? heartRateTarget;
  final String description;
  final Duration? estimatedDuration;
  final List<IntervalPhase>? intervals;
  final RunWalkPhase? runWalkPhase;

  const TrainingDay({
    required this.date,
    required this.type,
    required this.description,
    this.targetMinutes,
    this.warmUpMinutes,
    this.coolDownMinutes,
    this.paceTarget,
    this.heartRateTarget,
    this.estimatedDuration,
    this.intervals,
    this.runWalkPhase,
  });

  int? get workMinutes {
    final target = targetMinutes;
    if (target == null) return null;
    var work = target;
    work -= warmUpMinutes ?? 0;
    work -= coolDownMinutes ?? 0;
    return work;
  }
}

class TrainingPlan {
  final DateTime startDate;
  final List<TrainingDay> days;
  final String goal;
  final String description;
  final int weekInCycle;
  final CyclePhase cyclePhase;

  const TrainingPlan({
    required this.startDate,
    required this.days,
    required this.goal,
    required this.description,
    this.weekInCycle = -1,
    this.cyclePhase = CyclePhase.beginner,
  });

  factory TrainingPlan.empty() {
    return TrainingPlan(
      startDate: DateTime.now(),
      days: [],
      goal: 'No data available',
      description:
          'Track or log runs to generate your personalized training plan.',
      weekInCycle: -1,
      cyclePhase: CyclePhase.beginner,
    );
  }
}
