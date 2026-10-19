import '../entities/rehab_feedback.dart';
import '../entities/rehab_program.dart';
import '../entities/rehab_progress.dart';
import '../entities/run_walk_phase.dart';
import '../entities/training_plan.dart';

class RehabWeekPlanner {
  List<TrainingDay> build({
    required RehabProgress progress,
    required double weeklyMinutes,
    required DateTime startDate,
    required List<WorkoutType> sequence,
    required PaceZone pace,
    required HrZone heartRate,
  }) {
    final types = List.generate(
      7,
      (i) => _type(sequence[i], startDate.add(Duration(days: i)), progress),
    );
    final runs = types.where((t) => t == WorkoutType.easy).length;
    final minutes = runs == 0 ? 0 : (weeklyMinutes / runs).floor();
    return List.generate(
      7,
      (i) => _day(
        date: startDate.add(Duration(days: i)),
        type: types[i],
        minutes: minutes,
        progress: progress,
        pace: pace,
        heartRate: heartRate,
      ),
    );
  }

  WorkoutType _type(
    WorkoutType scheduled,
    DateTime date,
    RehabProgress progress,
  ) {
    final until = progress.recoveryUntil;
    if (until != null && date.isBefore(until)) {
      return progress.recoveryStatus == RehabStatus.flareUp
          ? WorkoutType.crossTraining
          : WorkoutType.rest;
    }
    return switch (scheduled) {
      WorkoutType.rest || WorkoutType.crossTraining => scheduled,
      _ => WorkoutType.easy,
    };
  }

  TrainingDay _day({
    required DateTime date,
    required WorkoutType type,
    required int minutes,
    required RehabProgress progress,
    required PaceZone pace,
    required HrZone heartRate,
  }) {
    if (type != WorkoutType.easy || minutes == 0) {
      return TrainingDay(
        date: date,
        type: minutes == 0 && type == WorkoutType.easy
            ? WorkoutType.rest
            : type,
        description: type == WorkoutType.crossTraining
            ? 'No running. Rest or choose non-impact cross-training.'
            : 'Recovery day. Repeat your current stage when recovery is complete.',
      );
    }
    final phase = progress.program.mode == ReturnModality.walkRun
        ? _phase(
            progress.stage.clamp(0, progress.program.rampWeeks - 1),
            minutes,
          )
        : null;
    return TrainingDay(
      date: date,
      type: WorkoutType.easy,
      targetMinutes: minutes,
      paceTarget: pace,
      heartRateTarget: heartRate,
      estimatedDuration: Duration(minutes: minutes),
      runWalkPhase: phase,
      description:
          phase?.label ??
          'Continuous easy return run. Keep the effort comfortable.',
    );
  }

  RunWalkPhase _phase(int stage, int minutes) {
    final base = RunWalkPhase.fromStats(stage * 3, stage * 7);
    return RunWalkPhase(
      type: base.type,
      runSeconds: base.runSeconds,
      walkSeconds: base.walkSeconds,
      totalDurationMinutes: minutes,
      label:
          'Run ${base.runSeconds ~/ 60} min, walk ${base.walkSeconds ~/ 60} min',
    );
  }
}
