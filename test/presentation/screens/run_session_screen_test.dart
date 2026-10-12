import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/core/services/voice_coach_service.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/domain/repositories/activity_repository.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/screens/run_session_screen.dart';
import 'package:teman_lari/presentation/widgets/run_session/run_session_state.dart';

class FakeActivityRepository implements ActivityRepository {
  final List<Activity> activities = [];

  @override
  Future<List<Activity>> getAllActivities({int monthsBack = 12}) async {
    return List.unmodifiable(activities);
  }

  @override
  Future<void> refreshActivities({int monthsBack = 12}) async {}

  @override
  Future<Map<int, List<double>>> getHeartRateStreams(
    List<int> activityIds,
  ) async {
    return {};
  }

  @override
  Future<Activity> uploadActivity(int localId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> saveActivity(Activity activity) async {
    activities.add(activity);
  }
}

class FakeVoiceCoachService implements VoiceCoachService {
  @override
  Future<void> announcePhaseChange(WorkoutPhase phase) async {}

  @override
  Future<void> announceMidpoint() async {}

  @override
  Future<void> announceWorkoutComplete() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isLocationServiceEnabled') return false;
            if (methodCall.method == 'checkPermission') return 0;
            if (methodCall.method == 'requestPermission') return 0;
            return null;
          },
        );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (MethodCall methodCall) async => 1,
        );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('step_detection'),
          (MethodCall methodCall) async => null,
        );
  });

  Widget buildTestableScreen({
    required TrainingDay day,
    required FakeActivityRepository fakeRepo,
  }) {
    return ProviderScope(
      overrides: [
        activityRepositoryProvider.overrideWithValue(fakeRepo),
        voiceCoachProvider.overrideWithValue(FakeVoiceCoachService()),
      ],
      child: MaterialApp(home: RunSessionScreen(day: day)),
    );
  }

  group('RunSessionScreen auto-save on completion and exit (Ticket 02)', () {
    testWidgets(
      'completing all intervals auto-saves activity to repository with negative timestamp ID and updates activitiesProvider',
      (WidgetTester tester) async {
        final fakeRepo = FakeActivityRepository();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.intervals,
          description: 'Quick Interval Test',
          intervals: const [
            IntervalPhase(
              type: IntervalPhaseType.work,
              duration: Duration(seconds: 2),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestableScreen(day: day, fakeRepo: fakeRepo),
        );
        await tester.pump();

        // Start workout
        final playButton = find.byIcon(Icons.play_arrow);
        expect(playButton, findsOneWidget);
        await tester.tap(playButton);
        await tester.pump();

        // Advance 1 second
        await tester.pump(const Duration(seconds: 1));
        expect(fakeRepo.activities, isEmpty);

        // Advance 1 more second to reach completion (total 2s)
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Verifications
        expect(fakeRepo.activities, hasLength(1));
        final saved = fakeRepo.activities.first;
        expect(saved.id, isNegative);
        expect(saved.name, equals('Interval Training Run'));
        expect(saved.type, equals(ActivityType.run));
        expect(saved.isLocal, isTrue);
        expect(saved.movingTime.inSeconds, equals(2));
        expect(saved.trainingLoad, equals(TrainingLoad.moderate));

        // Screen shows completion state and Return to Dashboard button
        expect(find.text('Workout Complete!'), findsOneWidget);
        expect(
          find.byKey(const Key('returnToDashboardButton')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'confirming "End Workout" in exit sheet saves active session data up to that moment with negative ID',
      (WidgetTester tester) async {
        final fakeRepo = FakeActivityRepository();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.tempo,
          targetMinutes: 20,
          description: 'Tempo run with early exit',
        );

        await tester.pumpWidget(
          buildTestableScreen(day: day, fakeRepo: fakeRepo),
        );
        await tester.pump();

        // Start workout
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();

        // Advance 4 seconds
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(fakeRepo.activities, isEmpty);

        // Open exit sheet via close icon
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('End Workout Early?'), findsOneWidget);
        expect(find.text('End Workout'), findsOneWidget);

        // Tap End Workout in modal
        await tester.tap(find.text('End Workout'));
        await tester.pumpAndSettle();

        // Verifications
        expect(fakeRepo.activities, hasLength(1));
        final saved = fakeRepo.activities.first;
        expect(saved.id, isNegative);
        expect(saved.name, equals('Tempo Run Run'));
        expect(saved.type, equals(ActivityType.run));
        expect(saved.isLocal, isTrue);
        expect(saved.movingTime.inSeconds, equals(4));
        expect(saved.trainingLoad, equals(TrainingLoad.moderate));
      },
    );

    testWidgets(
      'guards against double-saving when workout is already completed or ended',
      (WidgetTester tester) async {
        final fakeRepo = FakeActivityRepository();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.intervals,
          description: 'Single interval',
          intervals: const [
            IntervalPhase(
              type: IntervalPhaseType.work,
              duration: Duration(seconds: 1),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestableScreen(day: day, fakeRepo: fakeRepo),
        );
        await tester.pump();

        // Start workout and tick to finish
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(fakeRepo.activities, hasLength(1));

        // Tap Return to Dashboard button
        final returnBtn = find.byKey(const Key('returnToDashboardButton'));
        expect(returnBtn, findsOneWidget);
        await tester.tap(returnBtn);
        await tester.pumpAndSettle();

        // Should still only be 1 saved activity (no duplicate save)
        expect(fakeRepo.activities, hasLength(1));
      },
    );

    testWidgets(
      'tapping header close icon when workout is finished exits directly without opening confirmation sheet',
      (WidgetTester tester) async {
        final fakeRepo = FakeActivityRepository();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.intervals,
          description: 'Quick finish test',
          intervals: const [
            IntervalPhase(
              type: IntervalPhaseType.work,
              duration: Duration(seconds: 1),
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestableScreen(day: day, fakeRepo: fakeRepo),
        );
        await tester.pump();

        // Start workout and complete it
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(fakeRepo.activities, hasLength(1));

        // Tap header close button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Confirmation sheet should NOT be opened
        expect(find.text('End Workout Early?'), findsNothing);
      },
    );

    testWidgets(
      'tapping Resume in early exit sheet closes modal without saving activity',
      (WidgetTester tester) async {
        final fakeRepo = FakeActivityRepository();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.tempo,
          targetMinutes: 10,
          description: 'Resume test',
        );

        await tester.pumpWidget(
          buildTestableScreen(day: day, fakeRepo: fakeRepo),
        );
        await tester.pump();

        // Open exit sheet
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('End Workout Early?'), findsOneWidget);

        // Tap Resume
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();

        // Sheet closed and no activity was saved
        expect(find.text('End Workout Early?'), findsNothing);
        expect(fakeRepo.activities, isEmpty);
      },
    );
  });
}
