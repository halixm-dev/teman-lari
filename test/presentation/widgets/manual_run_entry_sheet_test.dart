import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/repositories/activity_repository.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/screens/dashboard_screen.dart';
import 'package:teman_lari/presentation/widgets/manual_run_entry_sheet.dart';
import 'package:teman_lari/presentation/widgets/recent_activities_list.dart';

class FakeActivityRepository implements ActivityRepository {
  final List<Activity> activities = [];
  bool saveActivityCalled = false;
  Activity? lastSavedActivity;

  @override
  Future<List<Activity>> getAllActivities({int monthsBack = 12}) async {
    return List.from(activities);
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
    saveActivityCalled = true;
    lastSavedActivity = activity;
    activities.add(activity);
  }
}

void main() {
  group('ManualRunEntrySheet Unit Calculations', () {
    test('calculatePaceString formats pace correctly', () {
      expect(
        ManualRunEntrySheet.calculatePaceString(
          10.0,
          const Duration(minutes: 50),
        ),
        equals('5:00 /km'),
      );
      expect(
        ManualRunEntrySheet.calculatePaceString(
          5.0,
          const Duration(minutes: 26, seconds: 40),
        ),
        equals('5:20 /km'),
      );
      expect(
        ManualRunEntrySheet.calculatePaceString(
          0.0,
          const Duration(minutes: 30),
        ),
        equals('--:-- /km'),
      );
      expect(
        ManualRunEntrySheet.calculatePaceString(5.0, Duration.zero),
        equals('--:-- /km'),
      );
    });

    test('getRpeLabel returns descriptive qualitative effort anchors', () {
      expect(ManualRunEntrySheet.getRpeLabel(1), contains('Very Light'));
      expect(ManualRunEntrySheet.getRpeLabel(2), contains('Very Light'));
      expect(ManualRunEntrySheet.getRpeLabel(3), contains('Light'));
      expect(ManualRunEntrySheet.getRpeLabel(4), contains('Light'));
      expect(ManualRunEntrySheet.getRpeLabel(5), contains('Moderate'));
      expect(ManualRunEntrySheet.getRpeLabel(6), contains('Moderate'));
      expect(ManualRunEntrySheet.getRpeLabel(7), contains('Hard'));
      expect(ManualRunEntrySheet.getRpeLabel(8), contains('Hard'));
      expect(ManualRunEntrySheet.getRpeLabel(9), contains('Max Effort'));
      expect(ManualRunEntrySheet.getRpeLabel(10), contains('Max Effort'));
    });
  });

  group('ManualRunEntrySheet Widget & Ingestion Tests', () {
    late FakeActivityRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeActivityRepository();
    });

    Widget createTestApp({Widget? child, DateTime? initialDateTime}) {
      return ProviderScope(
        overrides: [
          activityRepositoryProvider.overrideWithValue(fakeRepo),
          runningStatsProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body:
                child ?? ManualRunEntrySheet(initialDateTime: initialDateTime),
          ),
        ),
      );
    }

    testWidgets('renders all required manual run entry input elements', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('Log Manual Run'), findsOneWidget);
      expect(find.byKey(const Key('manual_run_name_input')), findsOneWidget);
      expect(
        find.byKey(const Key('manual_run_date_picker_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('manual_run_time_picker_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('manual_run_distance_input')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('manual_run_hours_input')), findsOneWidget);
      expect(find.byKey(const Key('manual_run_minutes_input')), findsOneWidget);
      expect(find.byKey(const Key('manual_run_seconds_input')), findsOneWidget);
      expect(find.byKey(const Key('manual_run_pace_display')), findsOneWidget);
      expect(find.byKey(const Key('manual_run_rpe_slider')), findsOneWidget);
      expect(find.byKey(const Key('manual_run_shoe_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('manual_run_submit_button')), findsOneWidget);
    });

    testWidgets(
      'dynamically calculates and updates average pace in real-time',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp());
        await tester.pump();

        // Initially '--:-- /km'
        expect(find.text('--:-- /km'), findsOneWidget);

        // Enter distance: 5 km
        await tester.enterText(
          find.byKey(const Key('manual_run_distance_input')),
          '5.0',
        );
        await tester.pump();
        expect(find.text('--:-- /km'), findsOneWidget);

        // Enter duration: 25 minutes
        await tester.enterText(
          find.byKey(const Key('manual_run_minutes_input')),
          '25',
        );
        await tester.pump();

        // 25 mins for 5 km = 5:00 /km
        expect(find.text('5:00 /km'), findsOneWidget);

        // Adjust duration: 26 mins 40 secs -> 5:20 /km
        await tester.enterText(
          find.byKey(const Key('manual_run_minutes_input')),
          '26',
        );
        await tester.enterText(
          find.byKey(const Key('manual_run_seconds_input')),
          '40',
        );
        await tester.pump();

        expect(find.text('5:20 /km'), findsOneWidget);
      },
    );

    testWidgets('validates distance > 0 and duration > 0 on submit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Tap submit with empty inputs
      await tester.ensureVisible(
        find.byKey(const Key('manual_run_submit_button')),
      );
      await tester.tap(find.byKey(const Key('manual_run_submit_button')));
      await tester.pump();

      expect(find.text('Please enter a distance'), findsOneWidget);
      expect(find.text('Duration must be greater than 0'), findsOneWidget);
      expect(fakeRepo.saveActivityCalled, isFalse);

      // Enter zero distance
      await tester.enterText(
        find.byKey(const Key('manual_run_distance_input')),
        '0',
      );
      await tester.enterText(
        find.byKey(const Key('manual_run_minutes_input')),
        '30',
      );
      await tester.ensureVisible(
        find.byKey(const Key('manual_run_submit_button')),
      );
      await tester.tap(find.byKey(const Key('manual_run_submit_button')));
      await tester.pump();

      expect(find.text('Distance must be greater than 0 km'), findsOneWidget);
      expect(fakeRepo.saveActivityCalled, isFalse);
    });

    testWidgets('prohibits future workout date/time on submit', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await tester.pumpWidget(createTestApp(initialDateTime: tomorrow));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('manual_run_distance_input')),
        '5.0',
      );
      await tester.enterText(
        find.byKey(const Key('manual_run_minutes_input')),
        '25',
      );

      await tester.ensureVisible(
        find.byKey(const Key('manual_run_submit_button')),
      );
      await tester.tap(find.byKey(const Key('manual_run_submit_button')));
      await tester.pump();

      expect(
        find.text('Workout date/time cannot be in the future'),
        findsOneWidget,
      );
      expect(fakeRepo.saveActivityCalled, isFalse);
    });

    testWidgets(
      'successful submission creates negative timestamp ID, persists to store, and updates state',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final pastDate = DateTime(2026, 10, 10, 7, 0);
        await tester.pumpWidget(createTestApp(initialDateTime: pastDate));
        await tester.pump();

        // Fill out form
        await tester.enterText(
          find.byKey(const Key('manual_run_name_input')),
          'Morning Treadmill Run',
        );
        await tester.enterText(
          find.byKey(const Key('manual_run_distance_input')),
          '8.0',
        );
        await tester.enterText(
          find.byKey(const Key('manual_run_hours_input')),
          '0',
        );
        await tester.enterText(
          find.byKey(const Key('manual_run_minutes_input')),
          '40',
        );
        await tester.enterText(
          find.byKey(const Key('manual_run_seconds_input')),
          '0',
        );

        // Submit form
        await tester.ensureVisible(
          find.byKey(const Key('manual_run_submit_button')),
        );
        await tester.tap(find.byKey(const Key('manual_run_submit_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(fakeRepo.saveActivityCalled, isTrue);
        final saved = fakeRepo.lastSavedActivity;
        expect(saved, isNotNull);
        expect(saved!.name, equals('Morning Treadmill Run'));
        expect(saved.id, isNegative);
        expect(saved.isLocal, isTrue);
        expect(saved.date, equals(pastDate));
        expect(saved.distanceKm, equals(8.0));
        expect(saved.movingTime, equals(const Duration(minutes: 40)));
        expect(saved.pace, equals(const Duration(seconds: 300))); // 5:00 /km
        expect(saved.perceivedExertion, equals(5.0)); // Default RPE 5.0
        expect(saved.trainingLoad, equals(TrainingLoad.easy));
      },
    );

    testWidgets('DashboardScreen exposes Log Manual Run FAB and button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(child: const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify FAB and AppBar button are present
      expect(
        find.byKey(const Key('dashboard_log_manual_run_fab')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dashboard_log_manual_run_button')),
        findsOneWidget,
      );

      // Tap FAB to open sheet
      await tester.tap(find.byKey(const Key('dashboard_log_manual_run_fab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ManualRunEntrySheet), findsOneWidget);
    });

    testWidgets('RecentActivitiesList exposes Log Manual Run action button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(child: const RecentActivitiesList()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final buttonFinder = find.byKey(
        const Key('recent_activities_log_manual_run_button'),
      );
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ManualRunEntrySheet), findsOneWidget);
    });
  });
}
