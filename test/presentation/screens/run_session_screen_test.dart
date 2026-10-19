import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:teman_lari/core/services/voice_coach_service.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/domain/repositories/activity_repository.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/screens/run_session_screen.dart';
import 'package:teman_lari/presentation/widgets/run_session/run_session_state.dart';

class FakeActivityRepository implements ActivityRepository {
  final List<Activity> activities = [];
  bool failSave = false;
  Completer<void>? pendingSave;
  bool failAfterWrite = false;

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
    await pendingSave?.future;
    if (failSave) throw StateError('Disk write failed');
    activities.removeWhere((existing) => existing.id == activity.id);
    activities.add(activity);
    if (failAfterWrite) throw StateError('Flush failed');
  }
}

class FakeVoiceCoachService implements VoiceCoachService {
  int completions = 0;
  @override
  Future<void> announcePhaseChange(WorkoutPhase phase) async {}

  @override
  Future<void> announceMidpoint() async {}

  @override
  Future<void> announceWorkoutComplete() async {
    completions++;
  }

  @override
  void dispose() {}
}

class FakeGeolocator extends GeolocatorPlatform {
  final positions = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      positions.stream;
}

Position gpsPosition(double altitude, DateTime timestamp) => Position(
  longitude: 106.8,
  latitude: -6.2,
  timestamp: timestamp,
  accuracy: 5,
  altitude: altitude,
  altitudeAccuracy: 2,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

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
    FakeVoiceCoachService? voiceCoach,
    bool routed = false,
  }) {
    return ProviderScope(
      overrides: [
        activityRepositoryProvider.overrideWithValue(fakeRepo),
        voiceCoachProvider.overrideWithValue(
          voiceCoach ?? FakeVoiceCoachService(),
        ),
      ],
      child: routed
          ? MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/dashboard/run',
                routes: [
                  GoRoute(
                    path: '/dashboard',
                    builder: (_, _) => const Scaffold(body: Text('Dashboard')),
                    routes: [
                      GoRoute(
                        path: 'run',
                        builder: (_, _) => RunSessionScreen(day: day),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : MaterialApp(home: RunSessionScreen(day: day)),
    );
  }

  group('RunSessionScreen auto-save on completion and exit (Ticket 02)', () {
    testWidgets('measured elevation survives completion and save retry', (
      tester,
    ) async {
      final previousGps = GeolocatorPlatform.instance;
      final gps = FakeGeolocator();
      GeolocatorPlatform.instance = gps;
      addTearDown(() async {
        GeolocatorPlatform.instance = previousGps;
        await gps.positions.close();
      });
      final repo = FakeActivityRepository()..failSave = true;
      final day = TrainingDay(
        date: DateTime(2026, 10, 12),
        type: WorkoutType.intervals,
        description: 'Measured climb',
        intervals: const [
          IntervalPhase(
            type: IntervalPhaseType.work,
            duration: Duration(seconds: 2),
          ),
        ],
      );
      await tester.pumpWidget(buildTestableScreen(day: day, fakeRepo: repo));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_arrow));
      final now = DateTime.now();
      gps.positions.add(gpsPosition(100, now));
      await tester.pump();
      gps.positions.add(gpsPosition(112, now.add(const Duration(seconds: 1))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      gps.positions.add(gpsPosition(900, now.add(const Duration(seconds: 3))));
      await tester.pump();
      repo.failSave = false;
      await tester.tap(find.text('Retry Save'));
      await tester.pumpAndSettle();

      check(repo.activities.single.elevationGainM).equals(12);
    });

    testWidgets(
      'saved workout uses its start time instead of completion time',
      (tester) async {
        final repo = FakeActivityRepository();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.intervals,
          description: 'Recorded start',
          intervals: const [
            IntervalPhase(
              type: IntervalPhaseType.work,
              duration: Duration(seconds: 2),
            ),
          ],
        );
        await tester.pumpWidget(buildTestableScreen(day: day, fakeRepo: repo));
        await tester.pump();
        final beforeStart = DateTime.now();
        await tester.tap(find.byIcon(Icons.play_arrow));
        final afterStart = DateTime.now();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        final saved = repo.activities.single;
        check(saved.date.isBefore(beforeStart)).isFalse();
        check(saved.date.isAfter(afterStart)).isFalse();
        check(saved.elevationGainM).isNull();
      },
    );

    testWidgets('failed completion can be retried without losing the run', (
      tester,
    ) async {
      final repo = FakeActivityRepository()..failSave = true;
      final day = TrainingDay(
        date: DateTime(2026, 10, 12),
        type: WorkoutType.intervals,
        description: 'Retry save',
        intervals: const [
          IntervalPhase(
            type: IntervalPhaseType.work,
            duration: Duration(seconds: 1),
          ),
        ],
      );
      await tester.pumpWidget(
        buildTestableScreen(day: day, fakeRepo: repo, routed: true),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      check(
        find.text('Could not save your run. Tap Retry Save.').evaluate(),
      ).has((widgets) => widgets.length, 'count').equals(1);
      check(repo.activities).isEmpty();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      check(find.byType(RunSessionScreen).evaluate()).isNotEmpty();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      check(find.byType(RunSessionScreen).evaluate()).isNotEmpty();

      repo.failSave = false;
      await tester.tap(find.text('Retry Save'));
      await tester.pumpAndSettle();
      check(repo.activities).length.equals(1);
      check(repo.activities.single.movingTime.inSeconds).equals(1);
      check(find.text('Run saved').evaluate()).isNotEmpty();
      await tester.tap(find.text('Return to Dashboard'));
      await tester.pumpAndSettle();
      check(find.text('Dashboard').evaluate()).isNotEmpty();
    });

    testWidgets('early exit stays on the run when saving fails', (
      tester,
    ) async {
      final repo = FakeActivityRepository()..failSave = true;
      final day = TrainingDay(
        date: DateTime(2026, 10, 12),
        type: WorkoutType.easy,
        targetMinutes: 10,
        description: 'Early exit retry',
      );
      await tester.pumpWidget(
        buildTestableScreen(day: day, fakeRepo: repo, routed: true),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Workout'));
      await tester.pumpAndSettle();
      check(find.text('Retry Save').evaluate()).isNotEmpty();
      check(find.byType(RunSessionScreen).evaluate()).isNotEmpty();
      repo.failSave = false;
      await tester.tap(find.text('Retry Save'));
      await tester.pumpAndSettle();
      check(repo.activities).length.equals(1);
    });

    testWidgets('successful early exit returns to the dashboard', (
      tester,
    ) async {
      final repo = FakeActivityRepository();
      final day = TrainingDay(
        date: DateTime(2026, 10, 12),
        type: WorkoutType.easy,
        targetMinutes: 10,
        description: 'Early exit',
      );
      await tester.pumpWidget(
        buildTestableScreen(day: day, fakeRepo: repo, routed: true),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Workout'));
      await tester.pumpAndSettle();
      check(repo.activities).length.equals(1);
      check(find.byType(RunSessionScreen).evaluate()).isEmpty();
      check(find.text('Dashboard').evaluate()).isNotEmpty();
    });

    testWidgets(
      'saving blocks exit and announces completion only after success',
      (tester) async {
        final gate = Completer<void>();
        final repo = FakeActivityRepository()..pendingSave = gate;
        final voice = FakeVoiceCoachService();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.intervals,
          description: 'Slow save',
          intervals: const [
            IntervalPhase(
              type: IntervalPhaseType.work,
              duration: Duration(seconds: 1),
            ),
          ],
        );
        await tester.pumpWidget(
          buildTestableScreen(
            day: day,
            fakeRepo: repo,
            voiceCoach: voice,
            routed: true,
          ),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        check(find.text('Saving your run…').evaluate()).isNotEmpty();
        check(voice.completions).equals(0);
        final button = tester.widget<FilledButton>(
          find.byKey(const Key('returnToDashboardButton')),
        );
        check(button.onPressed).isNull();
        await tester.tap(find.byIcon(Icons.close));
        await tester.binding.handlePopRoute();
        await tester.pump();
        check(find.byType(RunSessionScreen).evaluate()).isNotEmpty();
        gate.complete();
        await tester.pumpAndSettle();
        check(voice.completions).equals(1);
        check(repo.activities).length.equals(1);
        check(find.text('Run saved').evaluate()).isNotEmpty();
      },
    );

    testWidgets('retry keeps the same run after an uncertain write', (
      tester,
    ) async {
      final repo = FakeActivityRepository()..failAfterWrite = true;
      final day = TrainingDay(
        date: DateTime(2026, 10, 12),
        type: WorkoutType.intervals,
        description: 'Flush retry',
        intervals: const [
          IntervalPhase(
            type: IntervalPhaseType.work,
            duration: Duration(seconds: 1),
          ),
        ],
      );
      await tester.pumpWidget(buildTestableScreen(day: day, fakeRepo: repo));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final recorded = repo.activities.single;
      check(find.text('Retry Save').evaluate()).isNotEmpty();
      repo.failAfterWrite = false;
      await tester.tap(find.text('Retry Save'));
      await tester.pumpAndSettle();
      check(repo.activities).length.equals(1);
      check(repo.activities.single.id).equals(recorded.id);
      check(repo.activities.single.date).equals(recorded.date);
      check(find.text('Run saved').evaluate()).isNotEmpty();
    });

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
        expect(saved.name, equals('Tempo Run'));
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

    testWidgets(
      'completing all intervals naturally triggers heavy haptic feedback and assigns non-redundant name',
      (WidgetTester tester) async {
        final List<String> hapticCalls = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (
              MethodCall methodCall,
            ) async {
              if (methodCall.method == 'HapticFeedback.vibrate') {
                hapticCalls.add(methodCall.arguments as String);
              }
              return null;
            });

        final fakeRepo = FakeActivityRepository();
        final day = TrainingDay(
          date: DateTime(2026, 10, 12),
          type: WorkoutType.intervals,
          description: 'Natural complete test',
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

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
        expect(fakeRepo.activities, hasLength(1));
        expect(fakeRepo.activities.first.name, equals('Interval Training Run'));
      },
    );
  });
}
