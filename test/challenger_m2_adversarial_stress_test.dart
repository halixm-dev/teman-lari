import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/core/errors/exceptions.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/strava_activity_datasource.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/models/activity_model.dart';
import 'package:teman_lari/data/models/activity_streams.dart';
import 'package:teman_lari/data/models/athlete_model.dart';
import 'package:teman_lari/data/repositories/activity_repository_impl.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/entities/running_stats.dart';
import 'package:teman_lari/domain/usecases/analyze_runs_usecase.dart';
import 'package:teman_lari/domain/usecases/generate_plan_usecase.dart';
import 'package:teman_lari/domain/usecases/hr_zone_calculator.dart';
import 'package:teman_lari/domain/usecases/training_load_calculator.dart';
import 'package:teman_lari/main.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/providers/preferences_provider.dart';
import 'package:teman_lari/presentation/providers/training_plan_provider.dart';
import 'package:teman_lari/presentation/screens/dashboard_screen.dart';
import 'package:teman_lari/presentation/screens/plan_screen.dart';
import 'package:teman_lari/presentation/screens/settings_screen.dart';

class ThrowingRemoteDataSource implements StravaActivityDataSource {
  @override
  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async {
    throw UnauthenticatedException();
  }

  @override
  Future<ActivityStreams> getActivityStreams(int activityId) async {
    throw UnauthenticatedException();
  }

  @override
  Future<AthleteModel> getAthlete() async {
    throw UnauthenticatedException();
  }

  @override
  Future<ActivityModel> createActivity({
    required String name,
    required String type,
    required String startDateLocal,
    required int elapsedTime,
    double? distance,
    String? description,
  }) async {
    throw UnauthenticatedException();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalActivityDataSource localDataSource;
  late ActivityRepositoryImpl repository;
  late PreferencesStorage preferencesStorage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('challenger_m2_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('activities_box');
    await Hive.openBox('hr_streams_box');

    SharedPreferences.setMockInitialValues({});
    preferencesStorage = PreferencesStorage();

    localDataSource = LocalActivityDataSource();

    repository = ActivityRepositoryImpl(
      remoteDataSource: ThrowingRemoteDataSource(),
      localDataSource: localDataSource,
      preferencesStorage: preferencesStorage,
      tokenStorage: TokenStorage(),
    );
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Adversarial Group 1: Demographic Baselines & Physiological Boundaries', () {
    test(
      'HrPreferences restingHr boundary values: 30, 60, 120, out of bounds',
      () {
        const p30 = HrPreferences(restingHr: 30);
        check(p30.restingHr).equals(30);

        const p60 = HrPreferences(restingHr: 60);
        check(p60.restingHr).equals(60);

        const p120 = HrPreferences(restingHr: 120);
        check(p120.restingHr).equals(120);

        // Default restingHr must be 60
        const pDef = HrPreferences();
        check(pDef.restingHr).equals(60);

        // Boundary / extreme values
        const pNegative = HrPreferences(restingHr: -10);
        check(pNegative.restingHr).equals(-10);

        const pZero = HrPreferences(restingHr: 0);
        check(pZero.restingHr).equals(0);

        const pExtreme = HrPreferences(restingHr: 220);
        check(pExtreme.restingHr).equals(220);
      },
    );

    test(
      'HrPreferences maxHr boundaries (100, 250) and age calculations (220 - age vs fallback 190)',
      () {
        // 1. Explicit maxHr takes highest precedence
        const pMax100 = HrPreferences(maxHr: 100, age: 30);
        check(pMax100.effectiveMaxHr).equals(100);

        const pMax250 = HrPreferences(maxHr: 250, age: 30);
        check(pMax250.effectiveMaxHr).equals(250);

        // 2. Age-based calculation (220 - age) when maxHr is null
        const pAge20 = HrPreferences(maxHr: null, age: 20);
        check(pAge20.effectiveMaxHr).equals(200);

        const pAge30 = HrPreferences(maxHr: null, age: 30);
        check(pAge30.effectiveMaxHr).equals(190);

        const pAge50 = HrPreferences(maxHr: null, age: 50);
        check(pAge50.effectiveMaxHr).equals(170);

        const pAge75 = HrPreferences(maxHr: null, age: 75);
        check(pAge75.effectiveMaxHr).equals(145);

        // 3. Fallback to 190 when both maxHr and age are null
        const pFallback = HrPreferences(maxHr: null, age: null);
        check(pFallback.effectiveMaxHr).equals(190);

        // 4. Extreme age values
        const pAgeZero = HrPreferences(maxHr: null, age: 0);
        check(pAgeZero.effectiveMaxHr).equals(220);

        const pAge150 = HrPreferences(maxHr: null, age: 150);
        check(pAge150.effectiveMaxHr).equals(70);
      },
    );

    test(
      'HrZoneCalculator boundary behavior with restingHr (30, 60, 120) and maxHr (100, 250)',
      () {
        // RestingHr 30, maxHr 200: note HrZoneCalculator has _minRestingHr = 35
        final zones30 = HrZoneCalculator.fromActivities(
          [],
          restingHr: 30,
          maxHr: 200,
        );
        check(zones30.length).equals(5);
        // Min resting hr in HrZoneCalculator is clamped to 35
        check(zones30[0].minBpm).equals(35);
        check(zones30[4].maxBpm).equals(200);

        // Standard restingHr 60, maxHr 190
        final zonesStandard = HrZoneCalculator.fromActivities(
          [],
          restingHr: 60,
          maxHr: 190,
        );
        check(zonesStandard[0].minBpm).equals(60);
        check(zonesStandard[4].maxBpm).equals(190);

        // RestingHr 120, maxHr 100: inverted restingHr > maxHr!
        // In HrZoneCalculator: actualMax = 100. clamp(_minRestingHr, actualMax - 20) -> clamped to 80!
        final zonesInverted = HrZoneCalculator.fromActivities(
          [],
          restingHr: 120,
          maxHr: 100,
        );
        check(zonesInverted.length).equals(5);
        check(zonesInverted[0].minBpm).equals(80);
        check(zonesInverted[4].maxBpm).equals(100);
        // Ensure monotonic zone ordering even under inverted inputs
        for (int i = 0; i < 4; i++) {
          check(
            zonesInverted[i].minBpm,
          ).isLessThan(zonesInverted[i + 1].minBpm);
          check(
            zonesInverted[i].maxBpm,
          ).isLessThan(zonesInverted[i + 1].maxBpm);
        }

        // MaxHr 250 clamped to _maxHrCap = 230
        final zones250 = HrZoneCalculator.fromActivities(
          [],
          restingHr: 60,
          maxHr: 250,
        );
        check(zones250[4].maxBpm).equals(230);
      },
    );

    test(
      'PreferencesStorage persistence roundtrip for all demographic baselines',
      () async {
        check(await preferencesStorage.getRestingHr()).equals(60);
        check(await preferencesStorage.getMaxHr()).isNull();
        check(await preferencesStorage.getThresholdPace()).isNull();

        await preferencesStorage.saveRestingHr(45);
        await preferencesStorage.saveMaxHr(182);
        await preferencesStorage.saveThresholdPace(295);

        check(await preferencesStorage.getRestingHr()).equals(45);
        check(await preferencesStorage.getMaxHr()).equals(182);
        check(await preferencesStorage.getThresholdPace()).equals(295);

        final prefs = await preferencesStorage.getPreferences();
        check(prefs.restingHr).equals(45);
        check(prefs.maxHr).equals(182);
        check(prefs.thresholdPaceSeconds).equals(295);
        check(prefs.thresholdPace).equals(const Duration(seconds: 295));

        await preferencesStorage.clearRestingHr();
        await preferencesStorage.clearMaxHr();
        await preferencesStorage.clearThresholdPace();

        check(await preferencesStorage.getRestingHr()).equals(60);
        check(await preferencesStorage.getMaxHr()).isNull();
        check(await preferencesStorage.getThresholdPace()).isNull();
      },
    );

    test(
      'PreferencesStorage age calculation handles malformed, future, and leap-year birthdates',
      () async {
        await preferencesStorage.saveDateOfBirth('invalid-date');
        var prefs = await preferencesStorage.getPreferences();
        check(prefs.age).isNull();
        check(prefs.effectiveMaxHr).equals(190);

        await preferencesStorage.saveDateOfBirth('2000-02-29'); // Leap year
        prefs = await preferencesStorage.getPreferences();
        check(prefs.age).isNotNull();
        final expectedAge =
            DateTime.now().year -
            2000 -
            (DateTime.now().month < 2 ||
                    (DateTime.now().month == 2 && DateTime.now().day < 29)
                ? 1
                : 0);
        check(prefs.age).equals(expectedAge);
        check(prefs.effectiveMaxHr).equals(220 - expectedAge);
      },
    );
  });

  group(
    'Adversarial Group 2: Autonomous Training Load & Plan Generation with Empty Activities',
    () {
      test(
        'AnalyzeRunsUseCase.compute on empty activities returns RunningStats.empty() without throwing',
        () {
          final useCase = AnalyzeRunsUseCase();
          final stats = useCase.compute(
            [],
            userMaxHr: 190,
            userRestingHr: 60,
            userThresholdPace: const Duration(seconds: 300),
          );

          check(stats.totalRuns).equals(0);
          check(stats.totalDistanceKm).equals(0.0);
          check(stats.fitnessScore).equals(0.0);
          check(stats.fatigueScore).equals(0.0);
          check(stats.formScore).equals(0.0);
          check(stats.acwr).equals(1.0);
          check(stats.averagePace).equals(Duration.zero);
          check(stats.heartRateZones).isEmpty();
          check(stats.trainingLoadHistory).isEmpty();
          check(stats.recommendedPhase).equals(CyclePhase.beginner);
        },
      );

      test(
        'GeneratePlanUseCase.generate on empty activities returns TrainingPlan.empty() with decoupled message',
        () {
          final useCase = GeneratePlanUseCase();
          final plan = useCase.generate(
            [],
            weekInCycle: 0,
            userMaxHr: 190,
            userRestingHr: 60,
            userThresholdPaceSeconds: 300,
          );

          check(plan.goal).equals('No data available');
          check(plan.description).equals(
            'Track or log runs to generate your personalized training plan.',
          );
          check(plan.cyclePhase).equals(CyclePhase.beginner);
          check(plan.days).isEmpty();
          check(plan.weekInCycle).equals(-1);
        },
      );

      test(
        'GeneratePlanUseCase.generate with empty activities survives extreme HR combinations',
        () {
          final useCase = GeneratePlanUseCase();

          // Extreme restingHr 30, maxHr 250
          final plan1 = useCase.generate([], userMaxHr: 250, userRestingHr: 30);
          check(plan1.days).isEmpty();

          // Inverted restingHr 120, maxHr 100
          final plan2 = useCase.generate(
            [],
            userMaxHr: 100,
            userRestingHr: 120,
          );
          check(plan2.days).isEmpty();

          // Equal restingHr and maxHr
          final plan3 = useCase.generate(
            [],
            userMaxHr: 100,
            userRestingHr: 100,
          );
          check(plan3.days).isEmpty();

          // Threshold pace boundary values: 150 s/km, 1200 s/km, 0 s/km, negative
          final planFast = useCase.generate([], userThresholdPaceSeconds: 150);
          check(planFast.days).isEmpty();

          final planSlow = useCase.generate([], userThresholdPaceSeconds: 1200);
          check(planSlow.days).isEmpty();

          final planZero = useCase.generate([], userThresholdPaceSeconds: 0);
          check(planZero.days).isEmpty();
        },
      );
    },
  );

  group(
    'Adversarial Group 3: Training Load & Plan Generation with Custom Threshold Pace & Activities',
    () {
      final List<Activity> sampleRuns = [
        Activity(
          id: -1,
          name: 'Local Run 1',
          date: DateTime.now().subtract(const Duration(days: 3)),
          type: ActivityType.run,
          distanceKm: 5.0,
          movingTime: const Duration(minutes: 25),
          pace: const Duration(seconds: 300),
          elevationGainM: 10,
          trainingLoad: TrainingLoad.moderate,
          avgHeartRate: 150.0,
          maxHeartRate: 175.0,
        ),
        Activity(
          id: -2,
          name: 'Local Run 2',
          date: DateTime.now().subtract(const Duration(days: 1)),
          type: ActivityType.run,
          distanceKm: 8.0,
          movingTime: const Duration(minutes: 40),
          pace: const Duration(seconds: 300),
          elevationGainM: 20,
          trainingLoad: TrainingLoad.moderate,
          avgHeartRate: 155.0,
          maxHeartRate: 180.0,
        ),
      ];

      test(
        'Custom user threshold pace overrides activity pace estimation in AnalyzeRunsUseCase and GeneratePlanUseCase',
        () {
          final analyzeUseCase = AnalyzeRunsUseCase();
          final statsCustomPace = analyzeUseCase.compute(
            sampleRuns,
            userThresholdPace: const Duration(
              seconds: 240,
            ), // 4:00/km (much faster than runs' 5:00/km)
          );

          final statsSlowThreshold = analyzeUseCase.compute(
            sampleRuns,
            userThresholdPace: const Duration(
              seconds: 320,
            ), // 5:20/km (slower than runs' 5:00/km)
          );

          check(statsCustomPace.analyzedActivities.isNotEmpty).isTrue();
          check(statsSlowThreshold.analyzedActivities.isNotEmpty).isTrue();

          final generateUseCase = GeneratePlanUseCase();
          final plan = generateUseCase.generate(
            sampleRuns,
            userThresholdPaceSeconds: 270,
            userMaxHr: 185,
            userRestingHr: 55,
          );

          check(plan.days.length).equals(7);
          check(plan.cyclePhase).equals(CyclePhase.baseBuilding);
        },
      );

      test(
        'TrainingLoadCalculator handles boundary and inverted HR without throwing or producing NaN',
        () {
          final calc = TrainingLoadCalculator();

          // Normal
          final historyNormal = calc.computeLoadHistory(
            sampleRuns,
            maxHr: 190,
            restingHr: 60,
          );
          check(historyNormal.isNotEmpty).isTrue();
          check(historyNormal.last.fitness.isNaN).isFalse();
          check(historyNormal.last.fatigue.isNaN).isFalse();

          // Inverted restingHr 120, maxHr 100
          final historyInverted = calc.computeLoadHistory(
            sampleRuns,
            maxHr: 100,
            restingHr: 120,
          );
          check(historyInverted.isNotEmpty).isTrue();

          // Equal maxHr and restingHr (division by zero risk!)
          final historyEqual = calc.computeLoadHistory(
            sampleRuns,
            maxHr: 100,
            restingHr: 100,
          );
          check(historyEqual.isNotEmpty).isTrue();
        },
      );
    },
  );

  group(
    'Adversarial Group 4: Provider Wiring & effectiveMaxHr / Demographics Inspection',
    () {
      test(
        'Audit trainingPlanProvider and runningStatsProvider maxHr propagation with age-only profile',
        () async {
          // Setup preferences with age = 50 (born 1976), but maxHr = null
          await preferencesStorage.saveDateOfBirth('1976-01-01');
          final prefs = await preferencesStorage.getPreferences();
          check(prefs.maxHr).isNull();
          check(prefs.age).isNotNull();
          final expectedAgeMaxHr = 220 - prefs.age!;
          check(prefs.effectiveMaxHr).equals(expectedAgeMaxHr); // e.g. 170

          final container = ProviderContainer(
            overrides: [
              preferencesStorageProvider.overrideWithValue(preferencesStorage),
              activityRepositoryProvider.overrideWithValue(repository),
            ],
          );
          addTearDown(container.dispose);

          // Keep subscriptions active to prevent premature auto-disposal across async gaps
          container.listen(activitiesProvider, (_, _) {});
          container.listen(hrPreferencesProvider, (_, _) {});
          container.listen(runningStatsProvider, (_, _) {});
          container.listen(trainingPlanProvider, (_, _) {});

          // Verify hrPreferencesProvider returns expected age and effectiveMaxHr
          final fetchedPrefs = await container.read(
            hrPreferencesProvider.future,
          );
          check(fetchedPrefs.maxHr).isNull();
          check(fetchedPrefs.effectiveMaxHr).equals(expectedAgeMaxHr);

          // Verify runningStatsProvider completes in unauthenticated guest mode without throwing
          final stats = await container.read(runningStatsProvider.future);
          check(stats).isNotNull();
          check(stats!.totalRuns).equals(0);

          // Verify trainingPlanProvider completes in unauthenticated guest mode without throwing
          final plan = await container.read(trainingPlanProvider.future);
          check(plan.goal).equals('No data available');
          check(plan.days).isEmpty();
        },
      );

      test(
        'Zero UnauthenticatedException across all core providers in guest mode',
        () async {
          final container = ProviderContainer(
            overrides: [
              preferencesStorageProvider.overrideWithValue(preferencesStorage),
              activityRepositoryProvider.overrideWithValue(repository),
            ],
          );
          addTearDown(container.dispose);

          // Keep subscriptions active
          container.listen(activitiesProvider, (_, _) {});
          container.listen(runningStatsProvider, (_, _) {});
          container.listen(trainingPlanProvider, (_, _) {});
          container.listen(athleteNameProvider, (_, _) {});
          container.listen(weekInCycleProvider, (_, _) {});
          container.listen(cycleStartDateProvider, (_, _) {});

          // 1. activitiesProvider
          final activities = await container.read(activitiesProvider.future);
          check(activities).isEmpty();

          // 2. runningStatsProvider
          final stats = await container.read(runningStatsProvider.future);
          check(stats).isNotNull();

          // 3. trainingPlanProvider
          final plan = await container.read(trainingPlanProvider.future);
          check(plan.goal).equals('No data available');

          // 4. athleteNameProvider
          final name = await container.read(athleteNameProvider.future);
          check(name).isNull();

          // 5. weekInCycleProvider
          final week = await container.read(weekInCycleProvider.future);
          check(week).equals(0);

          // 6. cycleStartDateProvider
          final cycleStart = await container.read(
            cycleStartDateProvider.future,
          );
          check(cycleStart.year).equals(DateTime.now().year);
        },
      );
    },
  );

  group('Adversarial Group 5: Presentation Guest Mode Rendering & Navigation', () {
    testWidgets(
      'DashboardScreen renders cleanly in guest mode with zero activities without errors',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            preferencesStorageProvider.overrideWithValue(preferencesStorage),
            activityRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PlanScreen renders empty plan cleanly in guest mode without errors',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            preferencesStorageProvider.overrideWithValue(preferencesStorage),
            activityRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: PlanScreen())),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(PlanScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SettingsScreen renders disconnected state in guest mode without errors',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            preferencesStorageProvider.overrideWithValue(preferencesStorage),
            activityRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'MainNavigationScreen tabs switch between Dashboard, Plan, and Settings in guest mode',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            preferencesStorageProvider.overrideWithValue(preferencesStorage),
            activityRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MainNavigationScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch to Plan tab (destination index 2)
        await tester.tap(find.byIcon(Icons.calendar_today));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(PlanScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch to Settings tab (destination index 3)
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
