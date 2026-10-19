import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/domain/entities/running_stats.dart';
import 'package:teman_lari/domain/usecases/generate_plan_usecase.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/entities/return_context.dart';
import 'package:teman_lari/domain/usecases/analyze_runs_usecase.dart';
import 'package:teman_lari/domain/usecases/training_plan_config.dart';
import 'package:teman_lari/domain/usecases/rehab_progression.dart';
import 'rehab_progression_test.dart'
    show rehabProgram, rehabRun, clearedFeedback;

class CapturingAnalysis extends AnalyzeRunsUseCase {
  ReturnContext? capturedContext;
  @override
  RunningStats compute(
    List<Activity> activities, {
    int? userMaxHr,
    int? userRestingHr,
    Duration? userThresholdPace,
    TrainingPlanConfig? config,
    ReturnContext? returnContextOverride,
  }) {
    capturedContext = returnContextOverride;
    return super.compute(
      activities,
      userMaxHr: userMaxHr,
      userRestingHr: userRestingHr,
      userThresholdPace: userThresholdPace,
      config: config,
      returnContextOverride: returnContextOverride,
    );
  }
}

void main() {
  test(
    'graduation releases this episode without disabling future gap detection',
    () {
      final analysis = CapturingAnalysis();
      final generator = GeneratePlanUseCase(analyzeRuns: analysis);
      final graduated = DateTime.utc(2026, 10, 3);
      generator.generate(
        [rehabRun(-1, 2)],
        rehabilitationGraduatedAt: graduated,
        now: graduated,
      );
      check(analysis.capturedContext?.isReturning).equals(false);
      generator.generate(
        [rehabRun(-1, 2)],
        rehabilitationGraduatedAt: graduated,
        now: graduated.add(const Duration(days: 40)),
      );
      check(analysis.capturedContext).isNull();
    },
  );
  test(
    'active rehab survives gap clearance and schedules non-impact recovery',
    () {
      final activities = [rehabRun(-1, 2)];
      final now = DateTime.utc(2026, 10, 3, 9);
      final progress = RehabProgression().assess(
        program: rehabProgram(),
        activities: activities,
        feedback: [clearedFeedback(-1, 2, pain: 6)],
        now: now,
      );
      final plan = GeneratePlanUseCase().generate(
        activities,
        rehabilitation: progress,
        now: now,
      );

      check(plan.cyclePhase).equals(CyclePhase.returning);
      check(
        plan.days.take(3).every((d) => d.type == WorkoutType.crossTraining),
      ).isTrue();
      final runs = plan.days.where((d) => d.type == WorkoutType.easy);
      check(runs).isNotEmpty();
      check(runs.every((d) => d.runWalkPhase != null)).isTrue();
      check(
        runs.fold(0, (sum, d) => sum + (d.targetMinutes ?? 0)) <= 70,
      ).isTrue();
    },
  );
}
