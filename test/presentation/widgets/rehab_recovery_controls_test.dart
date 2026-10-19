import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/presentation/providers/training_plan_provider.dart';
import 'package:teman_lari/presentation/widgets/today_workout_card.dart';

void main() {
  testWidgets('non-impact recovery cannot launch the running recorder', (
    tester,
  ) async {
    final today = DateTime.now();
    final plan = TrainingPlan(
      startDate: today,
      goal: 'Recovery',
      description: '',
      days: [
        TrainingDay(
          date: today,
          type: WorkoutType.crossTraining,
          description: 'No running. Non-impact recovery.',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [trainingPlanProvider.overrideWith((ref) async => plan)],
        child: const MaterialApp(home: Scaffold(body: TodayWorkoutCard())),
      ),
    );
    await tester.pumpAndSettle();

    check(find.text('Start Workout').evaluate()).isEmpty();
  });
}
