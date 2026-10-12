import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/entities/analyzed_activity.dart';
import 'package:teman_lari/domain/entities/workout_type.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/auth_provider.dart';
import 'package:teman_lari/presentation/widgets/compact_activity_card.dart';

class UploadTracker {
  int uploadCalledCount = 0;
  int? lastUploadedId;
  final Future<Activity> Function(int localId)? onUpload;

  UploadTracker({this.onUpload});
}

class MockActivitiesNotifier extends ActivitiesNotifier {
  final UploadTracker tracker;

  MockActivitiesNotifier(this.tracker);

  @override
  Future<List<Activity>> build() async => [];

  @override
  Future<Activity> uploadActivity(int localId) async {
    tracker.uploadCalledCount++;
    tracker.lastUploadedId = localId;
    if (tracker.onUpload != null) {
      return await tracker.onUpload!(localId);
    }
    return Activity(
      id: 99999,
      name: 'Uploaded',
      date: DateTime.now(),
      type: ActivityType.run,
      distanceKm: 5.0,
      movingTime: const Duration(minutes: 25),
      pace: const Duration(minutes: 5),
      elevationGainM: 10.0,
      trainingLoad: TrainingLoad.moderate,
    );
  }
}

class TestAuthNotifier extends AuthNotifier {
  final AuthState initialAuthState;

  TestAuthNotifier(this.initialAuthState);

  @override
  AuthState build() => initialAuthState;
}

AnalyzedActivity createTestAnalyzedRun({
  required int id,
  required String name,
  bool isLocal = false,
}) {
  final activity = Activity(
    id: id,
    name: name,
    date: DateTime(2026, 5, 20, 7, 30),
    type: ActivityType.run,
    distanceKm: 5.2,
    movingTime: const Duration(minutes: 26, seconds: 30),
    pace: const Duration(minutes: 5, seconds: 5),
    elevationGainM: 25.0,
    trainingLoad: TrainingLoad.moderate,
    avgHeartRate: 152.0,
  );

  return AnalyzedActivity(activity: activity, type: WorkoutType.easy);
}

void main() {
  group('CompactActivityCard (Milestone 5: Visual Sync Status & Selective Push)', () {
    testWidgets(
      'Displays Local badge and Upload to Strava button when activity is local and authenticated',
      (WidgetTester tester) async {
        final localRun = createTestAnalyzedRun(
          id: -42,
          name: 'Morning Offline Jog',
          isLocal: true,
        );
        final tracker = UploadTracker();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => TestAuthNotifier(
                  const AuthState(isAuthenticated: true, isLoading: false),
                ),
              ),
              activitiesProvider.overrideWith(
                () => MockActivitiesNotifier(tracker),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: CompactActivityCard(analyzedRun: localRun)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Local Sync Badge
        expect(
          find.byKey(const ValueKey('sync_badge_local_-42')),
          findsOneWidget,
        );
        expect(find.text('Local'), findsOneWidget);
        expect(find.text('Strava'), findsNothing);

        // 2. Verify Upload Button is present
        final uploadButton = find.byKey(
          const ValueKey('upload_strava_button_-42'),
        );
        expect(uploadButton, findsOneWidget);
        expect(find.text('Upload to Strava'), findsOneWidget);

        // 3. Tap Upload Button -> Calls uploadActivity and shows SnackBar
        await tester.tap(uploadButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tracker.uploadCalledCount, equals(1));
        expect(tracker.lastUploadedId, equals(-42));
        expect(
          find.text('Uploaded "Morning Offline Jog" to Strava successfully.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Displays Strava badge and HIDES Upload button when activity is already synced to Strava',
      (WidgetTester tester) async {
        final syncedRun = createTestAnalyzedRun(
          id: 778899,
          name: 'Cloud Synced Marathon',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => TestAuthNotifier(
                  const AuthState(isAuthenticated: true, isLoading: false),
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: CompactActivityCard(analyzedRun: syncedRun)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Strava Sync Badge
        expect(
          find.byKey(const ValueKey('sync_badge_strava_778899')),
          findsOneWidget,
        );
        expect(find.text('Strava'), findsOneWidget);
        expect(find.text('Local'), findsNothing);

        // 2. Upload Button must be absent
        expect(
          find.byKey(const ValueKey('upload_strava_button_778899')),
          findsNothing,
        );
        expect(find.text('Upload to Strava'), findsNothing);
      },
    );

    testWidgets(
      'HIDES Upload button for local activities when unauthenticated (Guest mode)',
      (WidgetTester tester) async {
        final localRun = createTestAnalyzedRun(
          id: -10,
          name: 'Guest Run',
          isLocal: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => TestAuthNotifier(const AuthState.unauthenticated()),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: CompactActivityCard(analyzedRun: localRun)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Displays Local Badge
        expect(
          find.byKey(const ValueKey('sync_badge_local_-10')),
          findsOneWidget,
        );
        expect(find.text('Local'), findsOneWidget);

        // 2. Upload button must NOT be visible when not connected
        expect(
          find.byKey(const ValueKey('upload_strava_button_-10')),
          findsNothing,
        );
        expect(find.text('Upload to Strava'), findsNothing);
      },
    );

    testWidgets('Shows error SnackBar with Retry action when upload fails', (
      WidgetTester tester,
    ) async {
      final localRun = createTestAnalyzedRun(
        id: -77,
        name: 'Flaky Network Run',
        isLocal: true,
      );

      int callAttempt = 0;
      final tracker = UploadTracker(
        onUpload: (id) async {
          callAttempt++;
          if (callAttempt == 1) {
            throw Exception('Rate Limit 429');
          }
          return Activity(
            id: 8888,
            name: 'Flaky Network Run',
            date: DateTime.now(),
            type: ActivityType.run,
            distanceKm: 5.0,
            movingTime: const Duration(minutes: 25),
            pace: const Duration(minutes: 5),
            elevationGainM: 10.0,
            trainingLoad: TrainingLoad.moderate,
          );
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => TestAuthNotifier(
                const AuthState(isAuthenticated: true, isLoading: false),
              ),
            ),
            activitiesProvider.overrideWith(
              () => MockActivitiesNotifier(tracker),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: CompactActivityCard(analyzedRun: localRun)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadButton = find.byKey(
        const ValueKey('upload_strava_button_-77'),
      );
      await tester.tap(uploadButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Error SnackBar with Retry action
      expect(find.textContaining('Upload failed'), findsOneWidget);
      final retryAction = find.widgetWithText(SnackBarAction, 'Retry');
      expect(retryAction, findsOneWidget);

      // Tap Retry -> Attempts again successfully
      await tester.tap(retryAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tracker.uploadCalledCount, equals(2));
      expect(
        find.text('Uploaded "Flaky Network Run" to Strava successfully.'),
        findsOneWidget,
      );
    });
  });
}
