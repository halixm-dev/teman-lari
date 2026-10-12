import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/strava_activity_datasource.dart';
import 'package:teman_lari/data/datasources/strava_auth_datasource.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/models/activity_model.dart';
import 'package:teman_lari/data/models/activity_streams.dart';
import 'package:teman_lari/data/models/athlete_model.dart';
import 'package:teman_lari/data/models/strava_tokens.dart';
import 'package:teman_lari/data/repositories/activity_repository_impl.dart';
import 'package:teman_lari/domain/entities/training_plan.dart';
import 'package:teman_lari/domain/usecases/generate_plan_usecase.dart';
import 'package:teman_lari/domain/usecases/strava_auth_usecase.dart';
import 'package:teman_lari/main.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/providers/preferences_provider.dart';
import 'package:teman_lari/presentation/screens/login_screen.dart';
import 'package:teman_lari/presentation/screens/settings_screen.dart';
import 'package:teman_lari/presentation/widgets/settings/strava_integration_card.dart';

class FakeTokenStorage extends TokenStorage {
  StravaTokens? _tokens;
  int clearTokensCallCount = 0;
  int saveTokensCallCount = 0;

  @override
  Future<StravaTokens?> getTokens() async => _tokens;

  @override
  Future<void> saveTokens(StravaTokens tokens) async {
    _tokens = tokens;
    saveTokensCallCount++;
  }

  @override
  Future<void> clearTokens() async {
    _tokens = null;
    clearTokensCallCount++;
  }

  void seedTokens(StravaTokens tokens) => _tokens = tokens;
}

class FakeStravaAuthDataSource implements StravaAuthDataSource {
  bool authenticateCalled = false;
  bool refreshTokenCalled = false;

  @override
  Future<StravaTokens> authenticate() async {
    authenticateCalled = true;
    return StravaTokens(
      accessToken: 'fresh_access_token_789',
      refreshToken: 'fresh_refresh_token_012',
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    );
  }

  @override
  Future<StravaTokens> refreshToken(String refreshToken) async {
    refreshTokenCalled = true;
    return StravaTokens(
      accessToken: 'refreshed_access_token_345',
      refreshToken: 'refreshed_refresh_token_678',
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    );
  }
}

class FakeStravaActivityDataSource implements StravaActivityDataSource {
  @override
  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async =>
      [];

  @override
  Future<ActivityStreams> getActivityStreams(int activityId) async =>
      const ActivityStreams();

  @override
  Future<AthleteModel> getAthlete() async => const AthleteModel(
    id: 88888,
    firstName: 'Adversarial',
    lastName: 'Athlete',
    maxHeartrate: 192.0,
    dateOfBirth: '1992-06-15',
  );

  @override
  Future<ActivityModel> createActivity({
    required String name,
    required String type,
    required String startDateLocal,
    required int elapsedTime,
    double? distance,
    String? description,
  }) async => ActivityModel(
    id: 99999,
    name: name,
    type: type,
    distance: distance ?? 0.0,
    movingTime: elapsedTime,
    elapsedTime: elapsedTime,
    totalElevationGain: 0.0,
    startDate: startDateLocal,
    averageSpeed: 0.0,
    maxSpeed: 0.0,
  );
}

ActivityModel createTestModel({
  required int id,
  required String name,
  required double distance,
  required int movingTime,
  required String startDate,
  double avgHr = 145.0,
  int sufferScore = 25,
}) {
  return ActivityModel(
    id: id,
    name: name,
    type: 'Run',
    distance: distance,
    movingTime: movingTime,
    elapsedTime: movingTime + 120,
    totalElevationGain: 35.0,
    startDate: startDate,
    averageSpeed: distance / movingTime,
    maxSpeed: (distance / movingTime) * 1.3,
    averageHeartrate: avgHr,
    maxHeartrate: avgHr + 20,
    averageCadence: 86.0,
    sufferScore: sufferScore,
    hasHeartrate: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalActivityDataSource localDataSource;
  late PreferencesStorage preferencesStorage;
  late FakeTokenStorage fakeTokenStorage;
  late FakeStravaAuthDataSource fakeAuthDataSource;
  late FakeStravaActivityDataSource fakeActivityDataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'challenger_m3_disconnect_',
    );
    Hive.init(tempDir.path);
    await Hive.openBox('activities');
    await Hive.openBox('hr_streams');

    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    preferencesStorage = PreferencesStorage();
    fakeTokenStorage = FakeTokenStorage();
    fakeAuthDataSource = FakeStravaAuthDataSource();
    fakeActivityDataSource = FakeStravaActivityDataSource();
    localDataSource = LocalActivityDataSource();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group(
    'Challenger M3 Suite 1: Hive Storage & Data Immutability Under Disconnect',
    () {
      test(
        'DISCONNECT_DATA_01: Disconnecting Strava clears tokens but retains 100% of Hive activities & HR streams',
        () async {
          // Step 1: Seed Hive with 5 local workouts (id < 0) and 5 remote workouts (id > 0)
          final localWorkouts = [
            createTestModel(
              id: -101,
              name: 'Morning Track Interval',
              distance: 6000,
              movingTime: 1800,
              startDate: '2026-05-01T06:00:00Z',
            ),
            createTestModel(
              id: -102,
              name: 'Hill Repeats Session',
              distance: 8000,
              movingTime: 2500,
              startDate: '2026-05-03T07:00:00Z',
            ),
            createTestModel(
              id: -103,
              name: 'Recovery Jog Local',
              distance: 4000,
              movingTime: 1400,
              startDate: '2026-05-05T06:30:00Z',
            ),
            createTestModel(
              id: -104,
              name: 'Tempo Run 5k',
              distance: 5000,
              movingTime: 1350,
              startDate: '2026-05-07T06:15:00Z',
            ),
            createTestModel(
              id: -105,
              name: 'Long Weekend LSD',
              distance: 18000,
              movingTime: 5800,
              startDate: '2026-05-10T05:30:00Z',
            ),
          ];

          final remoteWorkouts = [
            createTestModel(
              id: 9001,
              name: 'Strava Half Marathon',
              distance: 21100,
              movingTime: 6500,
              startDate: '2026-04-15T06:00:00Z',
            ),
            createTestModel(
              id: 9002,
              name: 'Strava Easy 10k',
              distance: 10000,
              movingTime: 3300,
              startDate: '2026-04-18T07:00:00Z',
            ),
            createTestModel(
              id: 9003,
              name: 'Strava Sunset Run',
              distance: 7500,
              movingTime: 2400,
              startDate: '2026-04-20T17:30:00Z',
            ),
            createTestModel(
              id: 9004,
              name: 'Strava City Circuit',
              distance: 9000,
              movingTime: 2900,
              startDate: '2026-04-25T06:45:00Z',
            ),
            createTestModel(
              id: 9005,
              name: 'Strava Parkrun 5k',
              distance: 5000,
              movingTime: 1250,
              startDate: '2026-04-28T08:00:00Z',
            ),
          ];

          final allSeeded = [...localWorkouts, ...remoteWorkouts];
          await localDataSource.saveActivities(allSeeded);

          // Seed HR streams for one local and one remote run
          final localHrStream = [135.0, 142.0, 155.0, 168.0, 172.0];
          final remoteHrStream = [128.0, 134.0, 148.0, 159.0, 162.0];
          await localDataSource.saveHeartRateStream(-101, localHrStream);
          await localDataSource.saveHeartRateStream(9001, remoteHrStream);

          // Step 2: Seed Demographics & Preferences
          await preferencesStorage.saveRestingHr(48);
          await preferencesStorage.saveMaxHr(195);
          await preferencesStorage.saveThresholdPace(280); // 4:40 /km
          await preferencesStorage.saveAthleteName('Adversarial Athlete');
          await preferencesStorage.saveDateOfBirth('1990-08-20');
          final cycleStart = DateTime(2026, 4, 1, 8, 0);
          await preferencesStorage.setCycleStartDate(cycleStart);
          await preferencesStorage.setWeekInCycle(2);

          // Step 3: Seed Strava Tokens (Active Connection)
          fakeTokenStorage.seedTokens(
            StravaTokens(
              accessToken: 'token_to_purge_xyz',
              refreshToken: 'refresh_to_purge_abc',
              expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 7200,
            ),
          );
          check(await fakeTokenStorage.getTokens()).isNotNull();

          // Step 4: Execute Disconnect via StravaAuthUseCase
          final authUseCase = StravaAuthUseCase(
            authDataSource: fakeAuthDataSource,
            tokenStorage: fakeTokenStorage,
          );
          await authUseCase.logout();

          // Step 5: Assert Remote Tokens are Cleared
          check(await fakeTokenStorage.getTokens()).isNull();
          check(fakeTokenStorage.clearTokensCallCount).equals(1);

          // Step 6: Assert Hive Box has 100% of Activities Unmutated
          final actBox = await localDataSource.activitiesBox;
          check(actBox.length).equals(10);

          final storedActivities = await localDataSource.getAllActivities();
          check(storedActivities.length).equals(10);

          // Verify every seeded activity exists with identical attributes
          for (final original in allSeeded) {
            final found = storedActivities.firstWhere(
              (a) => a.id == original.id,
              orElse: () => throw Exception('Missing activity ${original.id}'),
            );
            check(found.name).equals(original.name);
            check(found.distance).equals(original.distance);
            check(found.movingTime).equals(original.movingTime);
            check(found.startDate).equals(original.startDate);
            check(found.averageHeartrate).equals(original.averageHeartrate);
            check(found.sufferScore).equals(original.sufferScore);
          }

          // Verify HR streams remain completely intact
          final hrBox = await localDataSource.hrStreamsBox;
          check(hrBox.get((-101).toString())).isNotNull();
          check(hrBox.get(9001)).isNotNull();

          // Step 7: Assert Demographic Preferences Remain 100% Intact
          final prefs = await preferencesStorage.getPreferences();
          check(prefs.restingHr).equals(48);
          check(prefs.maxHr).equals(195);
          check(prefs.thresholdPaceSeconds).equals(280);
          check(
            await preferencesStorage.getAthleteName(),
          ).equals('Adversarial Athlete');
          check(
            await preferencesStorage.getCycleStartDate(),
          ).equals(cycleStart);
          check(await preferencesStorage.getWeekInCycle()).equals(2);
        },
      );
    },
  );

  group(
    'Challenger M3 Suite 2: Dynamic Training Plan Preservation Across Disconnect',
    () {
      test(
        'DISCONNECT_PLAN_02: Training Plan generated before disconnect is 100% identical after disconnect',
        () async {
          // Seed runs with various intensities over the last 4 weeks
          final runs = List.generate(14, (i) {
            final date = DateTime.now().subtract(Duration(days: (13 - i) * 2));
            return createTestModel(
              id: -(i + 1),
              name: 'Run ${i + 1}',
              distance: 5000.0 + (i % 4) * 2000.0,
              movingTime: 1500 + (i % 4) * 600,
              startDate: date.toIso8601String(),
              avgHr: 140.0 + (i % 4) * 8.0,
              sufferScore: 20 + i * 2,
            );
          });
          await localDataSource.saveActivities(runs);

          await preferencesStorage.saveRestingHr(50);
          await preferencesStorage.saveMaxHr(190);
          await preferencesStorage.saveThresholdPace(300); // 5:00 /km

          final repo = ActivityRepositoryImpl(
            remoteDataSource: fakeActivityDataSource,
            localDataSource: localDataSource,
            preferencesStorage: preferencesStorage,
            tokenStorage: fakeTokenStorage,
          );

          final activities = await repo.getAllActivities();

          final planUseCase = GeneratePlanUseCase();
          final preDisconnectPlan = planUseCase.generate(
            activities,
            weekInCycle: 1,
            userMaxHr: 190,
            userRestingHr: 50,
            userThresholdPaceSeconds: 300,
          );

          check(preDisconnectPlan.days.length).equals(7);
          check(
            preDisconnectPlan.days.any((d) => d.type != WorkoutType.rest),
          ).isTrue();

          // Connect Strava
          fakeTokenStorage.seedTokens(
            StravaTokens(
              accessToken: 'active_access_111',
              refreshToken: 'active_refresh_222',
              expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            ),
          );

          // Disconnect Strava
          final authUseCase = StravaAuthUseCase(
            authDataSource: fakeAuthDataSource,
            tokenStorage: fakeTokenStorage,
          );
          await authUseCase.logout();

          // Generate Plan again with the post-disconnect state
          final postDisconnectActivities = await repo.getAllActivities();
          final postPrefs = await preferencesStorage.getPreferences();

          final postDisconnectPlan = planUseCase.generate(
            postDisconnectActivities,
            weekInCycle: 1,
            userMaxHr: postPrefs.maxHr,
            userRestingHr: postPrefs.restingHr,
            userThresholdPaceSeconds: postPrefs.thresholdPaceSeconds,
          );

          // Assert 100% identical training plan across all 7 days
          check(
            postDisconnectPlan.days.length,
          ).equals(preDisconnectPlan.days.length);
          check(postDisconnectPlan.goal).equals(preDisconnectPlan.goal);
          check(
            postDisconnectPlan.description,
          ).equals(preDisconnectPlan.description);
          check(
            postDisconnectPlan.weekInCycle,
          ).equals(preDisconnectPlan.weekInCycle);
          check(
            postDisconnectPlan.cyclePhase,
          ).equals(preDisconnectPlan.cyclePhase);

          for (int i = 0; i < postDisconnectPlan.days.length; i++) {
            final preDay = preDisconnectPlan.days[i];
            final postDay = postDisconnectPlan.days[i];

            check(postDay.date.year).equals(preDay.date.year);
            check(postDay.date.month).equals(preDay.date.month);
            check(postDay.date.day).equals(preDay.date.day);
            check(postDay.type).equals(preDay.type);
            check(postDay.description).equals(preDay.description);
            check(postDay.targetMinutes).equals(preDay.targetMinutes);
            check(postDay.warmUpMinutes).equals(preDay.warmUpMinutes);
            check(postDay.coolDownMinutes).equals(preDay.coolDownMinutes);
            check(postDay.estimatedDuration).equals(preDay.estimatedDuration);
            if (preDay.paceTarget != null) {
              check(postDay.paceTarget!.label).equals(preDay.paceTarget!.label);
              check(
                postDay.paceTarget!.slowestPace,
              ).equals(preDay.paceTarget!.slowestPace);
              check(
                postDay.paceTarget!.fastestPace,
              ).equals(preDay.paceTarget!.fastestPace);
            }
            if (preDay.heartRateTarget != null) {
              check(
                postDay.heartRateTarget!.label,
              ).equals(preDay.heartRateTarget!.label);
              check(
                postDay.heartRateTarget!.zoneNumber,
              ).equals(preDay.heartRateTarget!.zoneNumber);
              check(
                postDay.heartRateTarget!.minBpm,
              ).equals(preDay.heartRateTarget!.minBpm);
              check(
                postDay.heartRateTarget!.maxBpm,
              ).equals(preDay.heartRateTarget!.maxBpm);
            }
          }
        },
      );
    },
  );

  group('Challenger M3 Suite 3: SettingsScreen UI Disconnect Flow & App Continuity', () {
    testWidgets(
      'DISCONNECT_UI_03: Disconnect modal confirms safety, clears tokens in-place, and NEVER evicts runner',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.runAsync(() async {
          await localDataSource.saveActivities([
            createTestModel(
              id: -10,
              name: 'Local Run 1',
              distance: 5000,
              movingTime: 1500,
              startDate: '2026-05-01T06:00:00Z',
            ),
            createTestModel(
              id: 200,
              name: 'Strava Run 2',
              distance: 10000,
              movingTime: 3000,
              startDate: '2026-05-02T06:00:00Z',
            ),
          ]);
        });

        await preferencesStorage.saveRestingHr(54);
        await preferencesStorage.saveMaxHr(186);
        await preferencesStorage.saveThresholdPace(310);
        await preferencesStorage.saveAthleteName('Maya Runner');

        fakeTokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'token_connected_123',
            refreshToken: 'refresh_connected_456',
            expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          ),
        );

        final repo = ActivityRepositoryImpl(
          remoteDataSource: fakeActivityDataSource,
          localDataSource: localDataSource,
          preferencesStorage: preferencesStorage,
          tokenStorage: fakeTokenStorage,
        );

        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
              preferencesStorageProvider.overrideWithValue(preferencesStorage),
              stravaAuthDataSourceProvider.overrideWithValue(
                fakeAuthDataSource,
              ),
              stravaActivityDataSourceProvider.overrideWithValue(
                fakeActivityDataSource,
              ),
              activityRepositoryProvider.overrideWithValue(repo),
              athleteNameProvider.overrideWith(
                (ref) => Future.value('Maya Runner'),
              ),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 1. Initial State: StravaIntegrationCard in Connected state
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(StravaIntegrationCard), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Maya Runner'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('disconnect_strava_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('connect_strava_button')),
          findsNothing,
        );

        // 2. Tap Disconnect -> Opens Bottom Sheet
        await tester.tap(
          find.byKey(const ValueKey('disconnect_strava_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Disconnect Strava?'), findsOneWidget);
        expect(
          find.text('Your local data is completely safe.'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'All your recorded running activities, active training plans, and demographic settings will remain intact on your device.',
          ),
          findsOneWidget,
        );

        // 3. Test "Keep Connected" cancels without side effects
        await tester.tap(find.text('Keep Connected'));
        await tester.pumpAndSettle();

        // Modal closed, still connected, tokens intact
        expect(find.text('Disconnect Strava?'), findsNothing);
        expect(find.text('Connected'), findsOneWidget);
        expect(await fakeTokenStorage.getTokens(), isNotNull);
        expect(fakeTokenStorage.clearTokensCallCount, equals(0));

        // 4. Re-open Disconnect Modal and Confirm
        await tester.tap(
          find.byKey(const ValueKey('disconnect_strava_button')),
        );
        await tester.pumpAndSettle();

        final confirmButton = find.byKey(
          const ValueKey('confirm_disconnect_button'),
        );
        expect(confirmButton, findsOneWidget);

        await tester.tap(confirmButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // 5. Assert: Modal dismissed, Athlete STILL ON SettingsScreen (No redirect/kickout!)
        expect(find.text('Disconnect Strava?'), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);

        // 6. Assert: Reassurance SnackBar is presented
        expect(
          find.text(
            'Strava disconnected. Local activities and plans preserved.',
          ),
          findsOneWidget,
        );

        // 7. Assert: Tokens cleared
        expect(await fakeTokenStorage.getTokens(), isNull);
        expect(fakeTokenStorage.clearTokensCallCount, equals(1));

        // 8. Assert: Card reactive transition to Disconnected state
        expect(
          find.byKey(const ValueKey('connect_strava_button')),
          findsOneWidget,
        );
        expect(find.text('Connect with Strava'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('disconnect_strava_button')),
          findsNothing,
        );

        // 9. Assert: 100% of Hive Activities still exist
        final remainingActivities = await tester.runAsync(
          () => localDataSource.getAllActivities(),
        );
        check(remainingActivities!.length).equals(2);
        check(remainingActivities[0].id).equals(200);
        check(remainingActivities[1].id).equals(-10);

        // 10. Assert: Demographic fields intact in UI controllers and store
        expect(find.text('54'), findsOneWidget); // resting HR
        expect(find.text('186'), findsOneWidget); // max HR
        expect(find.text('5:10'), findsOneWidget); // threshold pace 310s = 5:10
        final prefs = await preferencesStorage.getPreferences();
        check(prefs.restingHr).equals(54);
        check(prefs.maxHr).equals(186);
        check(prefs.thresholdPaceSeconds).equals(310);
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'DISCONNECT_UI_04: Full App Shell Navigation continuity - Athlete navigates tabs after disconnect without route eviction',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await preferencesStorage.saveRestingHr(60);
        await preferencesStorage.saveMaxHr(190);
        fakeTokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'token_shell_test',
            refreshToken: 'refresh_shell_test',
            expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          ),
        );

        final repo = ActivityRepositoryImpl(
          remoteDataSource: fakeActivityDataSource,
          localDataSource: localDataSource,
          preferencesStorage: preferencesStorage,
          tokenStorage: fakeTokenStorage,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
              preferencesStorageProvider.overrideWithValue(preferencesStorage),
              stravaAuthDataSourceProvider.overrideWithValue(
                fakeAuthDataSource,
              ),
              stravaActivityDataSourceProvider.overrideWithValue(
                fakeActivityDataSource,
              ),
              activityRepositoryProvider.overrideWithValue(repo),
              athleteNameProvider.overrideWith(
                (ref) => Future.value('Shell Athlete'),
              ),
            ],
            child: const TemanLariApp(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 500));

        // Starts on MainNavigationScreen
        expect(find.byType(MainNavigationScreen), findsOneWidget);

        // Navigate to Settings (4th destination in NavigationRail / BottomNavigationBar)
        final settingsIcon = find.byIcon(Icons.settings);
        expect(settingsIcon, findsWidgets);
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);

        // Trigger Disconnect
        await tester.tap(
          find.byKey(const ValueKey('disconnect_strava_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('confirm_disconnect_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // Still in MainNavigationScreen & SettingsScreen
        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);

        // Athlete navigates to Dashboard tab
        final dashboardIcon = find.byIcon(Icons.dashboard);
        expect(dashboardIcon, findsWidgets);
        await tester.tap(dashboardIcon.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 500));

        // Dashboard is reachable with zero auth errors or kickouts
        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );
  });

  group('Challenger M3 Suite 4: Stress, Concurrency & Reconnection Scenarios', () {
    test(
      'DISCONNECT_STRESS_05: Concurrent repository activity insertion during disconnect does not lock or drop records',
      () async {
        fakeTokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'stress_access_tok',
            refreshToken: 'stress_refresh_tok',
            expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          ),
        );

        final authUseCase = StravaAuthUseCase(
          authDataSource: fakeAuthDataSource,
          tokenStorage: fakeTokenStorage,
        );

        // Concurrently run disconnect and 20 rapid Hive insertions
        final futures = <Future>[];
        futures.add(authUseCase.logout());

        for (int i = 0; i < 20; i++) {
          futures.add(
            localDataSource.saveActivity(
              createTestModel(
                id: -(1000 + i),
                name: 'Concurrent Workout $i',
                distance: 5000 + i * 100.0,
                movingTime: 1500,
                startDate: '2026-05-10T08:00:00Z',
              ),
            ),
          );
        }

        await Future.wait(futures);

        // Assert tokens cleared
        check(await fakeTokenStorage.getTokens()).isNull();

        // Assert all 20 concurrent activities persisted without lock errors
        final stored = await localDataSource.getAllActivities();
        check(stored.length).equals(20);
      },
    );

    test(
      'DISCONNECT_STRESS_06: Repeated / Idempotent logout calls do not throw or mutate storage',
      () async {
        await localDataSource.saveActivity(
          createTestModel(
            id: -99,
            name: 'Immortal Workout',
            distance: 10000,
            movingTime: 3000,
            startDate: '2026-05-10T08:00:00Z',
          ),
        );

        final authUseCase = StravaAuthUseCase(
          authDataSource: fakeAuthDataSource,
          tokenStorage: fakeTokenStorage,
        );

        // Call logout 5 times consecutively when already unauthenticated
        for (int i = 0; i < 5; i++) {
          await authUseCase.logout();
        }

        check(await fakeTokenStorage.getTokens()).isNull();
        check(fakeTokenStorage.clearTokensCallCount).equals(5);

        final acts = await localDataSource.getAllActivities();
        check(acts.length).equals(1);
        check(acts.first.name).equals('Immortal Workout');
      },
    );

    test(
      'DISCONNECT_STRESS_07: Multi-cycle Connect -> Disconnect -> Reconnect -> Disconnect preserves data invariants',
      () async {
        await localDataSource.saveActivity(
          createTestModel(
            id: -555,
            name: 'Persistent Local Run',
            distance: 12000,
            movingTime: 3600,
            startDate: '2026-05-11T09:00:00Z',
          ),
        );

        final authUseCase = StravaAuthUseCase(
          authDataSource: fakeAuthDataSource,
          tokenStorage: fakeTokenStorage,
        );

        for (int cycle = 1; cycle <= 3; cycle++) {
          // Connect
          await authUseCase.authenticate();
          check(await fakeTokenStorage.getTokens()).isNotNull();

          // Add a new activity while connected
          await localDataSource.saveActivity(
            createTestModel(
              id: 7000 + cycle,
              name: 'Connected Cycle Run $cycle',
              distance: 8000,
              movingTime: 2400,
              startDate: '2026-05-11T1$cycle:00:00Z',
            ),
          );

          // Disconnect
          await authUseCase.logout();
          check(await fakeTokenStorage.getTokens()).isNull();

          // Verify all activities up to this cycle are strictly preserved
          final currentActs = await localDataSource.getAllActivities();
          check(currentActs.length).equals(1 + cycle);
        }
      },
    );
  });
}
