import '../entities/activity.dart';
import '../entities/rehab_feedback.dart';
import '../entities/rehab_program.dart';
import '../entities/rehab_progress.dart';
import 'rehab_feedback_assessment.dart';
import 'training_plan_config.dart';

/// Replays each run once, so rebuilds and retries cannot multiply reductions.
class RehabProgression {
  RehabProgress assess({
    required RehabProgram program,
    required List<Activity> activities,
    required List<RehabFeedback> feedback,
    required DateTime now,
    TrainingPlanConfig config = TrainingPlanConfig.defaultConfig,
  }) {
    program.validate();
    final ramp = _Ramp(program, config);
    final runs = _runs(activities, program, now);
    final seen = <int>{};
    final pending = <Activity>[];
    var lastRunRecovered = true;
    for (final run in runs) {
      if (!seen.add(run.id)) continue;
      final record = _record(run, program, feedback, now);
      final instant =
          record?.morningAfterRecordedAt ??
          record?.postRunRecordedAt ??
          run.date;
      final status = RehabFeedbackAssessment().assess(record);
      if (!RehabFeedbackAssessment().isComplete(record)) pending.add(run);
      final until = ramp.recovery;
      lastRunRecovered = until == null || !run.date.isBefore(until);
      ramp.observe(
        status,
        instant,
        allowProgress: pending.isEmpty && lastRunRecovered,
      );
    }
    return RehabProgress(
      program: program,
      stage: ramp.stage,
      weeklyMinutes: ramp.minutes,
      status: ramp.status == RehabStatus.pass && pending.isNotEmpty
          ? RehabStatus.pending
          : ramp.status,
      recoveryUntil: ramp.recovery,
      recoveryStatus: ramp.recoveryStatus,
      pendingActivities: List.unmodifiable(pending),
      readyToGraduate:
          ramp.stage == program.rampWeeks &&
          ramp.status == RehabStatus.pass &&
          pending.isEmpty &&
          lastRunRecovered &&
          !(ramp.recovery?.isAfter(now) ?? false),
    );
  }

  List<Activity> _runs(
    List<Activity> activities,
    RehabProgram program,
    DateTime now,
  ) {
    return activities
        .where(
          (activity) =>
              activity.type == ActivityType.run &&
              !activity.date.isBefore(program.startedAt) &&
              !activity.date.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  RehabFeedback? _record(
    Activity run,
    RehabProgram program,
    List<RehabFeedback> feedback,
    DateTime now,
  ) {
    final records = feedback
        .where(
          (record) =>
              record.activityId == run.id &&
              record.injurySite == program.injurySite,
        )
        .map((record) => _observed(record, run, now))
        .whereType<RehabFeedback>();
    return records.isEmpty
        ? null
        : records.reduce(
            (a, b) =>
                RehabFeedbackAssessment().assess(a).index >=
                    RehabFeedbackAssessment().assess(b).index
                ? a
                : b,
          );
  }

  RehabFeedback? _observed(RehabFeedback record, Activity run, DateTime now) {
    bool available(DateTime? time) =>
        time != null && !time.isBefore(run.date) && !time.isAfter(now);
    final date = run.date.toLocal();
    final nextDay = DateTime(date.year, date.month, date.day + 1);
    final post = available(record.postRunRecordedAt);
    final morning =
        available(record.morningAfterRecordedAt) &&
        !(record.morningAfterRecordedAt?.toLocal().isBefore(nextDay) ?? true);
    if (!post && !morning) return null;
    return RehabFeedback(
      id: record.id,
      activityId: record.activityId,
      injurySite: record.injurySite,
      postRunPain: post ? record.postRunPain : null,
      acuteSharpPain: post ? record.acuteSharpPain : null,
      postRunRecordedAt: post ? record.postRunRecordedAt : null,
      morningAfterPain: morning ? record.morningAfterPain : null,
      morningStiffness: morning ? record.morningStiffness : null,
      morningBaselineCleared: morning ? record.morningBaselineCleared : null,
      morningAfterRecordedAt: morning ? record.morningAfterRecordedAt : null,
      modifiedAt: record.modifiedAt,
    );
  }
}

class _Ramp {
  final RehabProgram program;
  final TrainingPlanConfig config;
  double minutes;
  int stage = 0;
  DateTime stageStarted;
  DateTime? recovery;
  RehabStatus? recoveryStatus;
  RehabStatus status = RehabStatus.pending;

  _Ramp(this.program, this.config)
    : minutes = program.initialWeeklyMinutes,
      stageStarted = program.startedAt;

  void observe(
    RehabStatus observation,
    DateTime instant, {
    required bool allowProgress,
  }) {
    status = observation;
    if (status == RehabStatus.flareUp) {
      stage = (stage - 1).clamp(0, program.rampWeeks);
      minutes *= 0.7;
      hold(instant, const Duration(hours: 72), RehabStatus.flareUp);
    } else if (status == RehabStatus.warning) {
      hold(instant, const Duration(hours: 48), RehabStatus.warning);
    } else if (status == RehabStatus.pass &&
        allowProgress &&
        stage < program.rampWeeks &&
        instant.difference(stageStarted) >= const Duration(days: 7)) {
      stage++;
      if (stage < program.rampWeeks) {
        minutes *= 1 + config.returnWeeklyIncreaseCap;
      }
      stageStarted = instant;
    }
  }

  void hold(DateTime instant, Duration duration, RehabStatus severity) {
    if (instant.isAfter(stageStarted)) stageStarted = instant;
    final until = instant.add(duration);
    if (recovery == null || until.isAfter(recovery ?? until)) {
      recovery = until;
      recoveryStatus = severity;
    } else if (severity == RehabStatus.flareUp) {
      recoveryStatus = severity;
    }
  }
}
