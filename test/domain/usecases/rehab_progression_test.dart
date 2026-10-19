import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/entities/rehab_feedback.dart';
import 'package:teman_lari/domain/entities/rehab_program.dart';
import 'package:teman_lari/domain/usecases/rehab_progression.dart';

void main() {
  test('later replay cannot shorten recovery from a delayed flare report', () {
    final delayed = RehabFeedback.fromJson({
      ...clearedFeedback(-1, 2, pain: 6).toJson(),
      'morning_after_recorded_at': '2026-10-10T08:00:00Z',
    });
    final progress = RehabProgression().assess(
      program: rehabProgram(),
      activities: [rehabRun(-1, 2), rehabRun(-2, 3)],
      feedback: [delayed, clearedFeedback(-2, 3, pain: 6)],
      now: DateTime.utc(2026, 10, 11),
    );
    check(progress.recoveryUntil).equals(DateTime.utc(2026, 10, 13, 8));
  });

  test('a run inside recovery cannot supply readiness clearance', () {
    final base = rehabProgram();
    final program = RehabProgram(
      startedAt: base.startedAt,
      injurySite: base.injurySite,
      mode: base.mode,
      initialWeeklyMinutes: 100,
      rampWeeks: 1,
    );
    for (final day in [10, 12]) {
      final progress = RehabProgression().assess(
        program: program,
        activities: [rehabRun(-1, 7), rehabRun(-2, 8), rehabRun(-3, 9)],
        feedback: [
          clearedFeedback(-1, 7),
          clearedFeedback(-2, 8, pain: 4),
          clearedFeedback(-3, 9),
        ],
        now: DateTime.utc(2026, 10, day, 9),
      );
      check(progress.readyToGraduate).isFalse();
    }
  });

  test('future morning observations cannot clear the current day', () {
    final progress = RehabProgression().assess(
      program: rehabProgram(),
      activities: [rehabRun(-1, 7)],
      feedback: [clearedFeedback(-1, 7)],
      now: DateTime.utc(2026, 10, 7, 10),
    );
    check(progress.stage).equals(0);
    check(progress.pendingActivities.single.id).equals(-1);
  });

  test(
    'a known flare still needs its missing morning check-in before progress',
    () {
      final partial = RehabFeedback.fromJson({
        ...clearedFeedback(-4, 2, pain: 6).toJson(),
        'morning_after_pain': null,
        'morning_after_recorded_at': null,
        'morning_stiffness': null,
        'morning_baseline_cleared': null,
      });
      final progress = RehabProgression().assess(
        program: rehabProgram(),
        activities: [
          rehabRun(-4, 2),
          rehabRun(-1, 7),
          rehabRun(-2, 14),
          rehabRun(-3, 21),
        ],
        feedback: [
          partial,
          clearedFeedback(-1, 7),
          clearedFeedback(-2, 14),
          clearedFeedback(-3, 21),
        ],
        now: DateTime.utc(2026, 10, 22, 9),
      );
      check(progress.stage).equals(0);
      check(progress.pendingActivities.single.id).equals(-4);
      check(progress.readyToGraduate).isFalse();
    },
  );

  test(
    'warning holds the stage and restarts its week with 48 hours recovery',
    () {
      final progress = RehabProgression().assess(
        program: rehabProgram(),
        activities: [rehabRun(-1, 7), rehabRun(-2, 8), rehabRun(-3, 14)],
        feedback: [
          clearedFeedback(-1, 7),
          clearedFeedback(-2, 8, pain: 4),
          clearedFeedback(-3, 14),
        ],
        now: DateTime.utc(2026, 10, 15, 9),
      );

      check(progress.stage).equals(1);
      check(progress.weeklyMinutes.round()).equals(110);
      check(progress.recoveryUntil).equals(DateTime.utc(2026, 10, 11, 8));
    },
  );

  test('an earlier missing check-in holds later cleared weeks', () {
    final progress = RehabProgression().assess(
      program: rehabProgram(),
      activities: [
        rehabRun(-4, 2),
        rehabRun(-1, 7),
        rehabRun(-2, 14),
        rehabRun(-3, 21),
      ],
      feedback: [
        clearedFeedback(-1, 7),
        clearedFeedback(-2, 14),
        clearedFeedback(-3, 21),
      ],
      now: DateTime.utc(2026, 10, 22, 9),
    );

    check(progress.stage).equals(0);
    check(progress.readyToGraduate).isFalse();
    check(progress.pendingActivities.map((a) => a.id)).deepEquals([-4]);
  });

  test(
    'three cleared weeks offer graduation without automatically graduating',
    () {
      final program = rehabProgram();
      final progress = RehabProgression().assess(
        program: program,
        activities: [rehabRun(-1, 7), rehabRun(-2, 14), rehabRun(-3, 21)],
        feedback: [
          clearedFeedback(-1, 7),
          clearedFeedback(-2, 14),
          clearedFeedback(-3, 21),
        ],
        now: DateTime.utc(2026, 10, 22, 9),
      );

      check(progress.stage).equals(3);
      check(progress.readyToGraduate).isTrue();
      check(program.graduatedAt).isNull();
      check(progress.weeklyMinutes.round()).equals(121);
    },
  );

  test(
    'a flare cuts volume once and requires 72 hours non-impact recovery',
    () {
      final assessor = RehabProgression();
      final program = rehabProgram();
      final run = rehabRun(-1, 2);
      final feedback = clearedFeedback(-1, 2, pain: 6);
      final progress = assessor.assess(
        program: program,
        activities: [run],
        feedback: [feedback, feedback],
        now: DateTime.utc(2026, 10, 3, 9),
      );

      check(progress.stage).equals(0);
      check(progress.weeklyMinutes).equals(70);
      check(progress.recoveryUntil).equals(DateTime.utc(2026, 10, 6, 8));
      check(progress.readyToGraduate).isFalse();
    },
  );

  test('elapsed weeks alone cannot graduate rehabilitation', () {
    final program = rehabProgram();
    final progress = RehabProgression().assess(
      program: program,
      activities: [],
      feedback: [],
      now: DateTime.utc(2026, 11, 1),
    );

    check(progress.stage).equals(0);
    check(progress.readyToGraduate).isFalse();
    check(progress.weeklyMinutes).equals(100);
  });
}

RehabProgram rehabProgram() => RehabProgram(
  startedAt: DateTime.utc(2026, 10, 1),
  injurySite: InjurySite.knee,
  mode: ReturnModality.walkRun,
  initialWeeklyMinutes: 100,
  rampWeeks: 3,
);

Activity rehabRun(int id, int day) => Activity(
  id: id,
  name: 'Rehab run',
  date: DateTime.utc(2026, 10, day, 8),
  type: ActivityType.run,
  distanceKm: 2,
  movingTime: const Duration(minutes: 20),
  pace: const Duration(minutes: 10),
  elevationGainM: null,
  trainingLoad: TrainingLoad.easy,
);

RehabFeedback clearedFeedback(int id, int day, {double pain = 2}) =>
    RehabFeedback(
      id: '$id:knee',
      activityId: id,
      injurySite: InjurySite.knee,
      postRunPain: pain,
      acuteSharpPain: false,
      postRunRecordedAt: DateTime.utc(2026, 10, day, 9),
      morningAfterPain: 2,
      morningAfterRecordedAt: DateTime.utc(2026, 10, day + 1, 8),
      morningStiffness: false,
      morningBaselineCleared: true,
    );
