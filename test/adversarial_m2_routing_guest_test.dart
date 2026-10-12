import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/strava_activity_datasource.dart';
import 'package:teman_lari/data/models/activity_streams.dart';
import 'package:teman_lari/data/repositories/activity_repository_impl.dart';
import 'package:teman_lari/domain/usecases/analyze_runs_usecase.dart';
import 'package:teman_lari/domain/usecases/generate_plan_usecase.dart';
import 'package:teman_lari/main.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/screens/analysis_screen.dart';
import 'package:teman_lari/presentation/screens/dashboard_screen.dart';
import 'package:teman_lari/presentation/screens/login_screen.dart';
import 'package:teman_lari/presentation/screens/plan_screen.dart';
import 'package:teman_lari/presentation/screens/settings_screen.dart';

import 'e2e/e2e_test_fixtures.dart';

/// A hostile remote data source simulating complete network unavailability.
/// Every call throws SocketException to verify that unauthenticated paths never reach the network.
class HostileNetworkActivityDataSource implements StravaActivityDataSource {
  int getAllActivitiesCalls = 0;
  int getActivityStreamsCalls = 0;
  int getAthleteCalls = 0;

  @override
  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async {
    getAllActivitiesCalls++;
    throw const SocketException(
      'Simulated offline: Network is completely unreachable',
    );
  }

  @override
  Future<ActivityStreams> getActivityStreams(int activityId) async {
    getActivityStreamsCalls++;
    throw const SocketException('Simulated offline: No network connection');
  }

  @override
  Future<AthleteModel> getAthlete() async {
    getAthleteCalls++;
    throw const SocketException(
      'Simulated offline: Cannot fetch athlete profile',
    );
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
    throw const SocketException('Simulated offline: Cannot create activity');
  }
}

class FakePreferencesStorage extends PreferencesStorage {
  HrPreferences preferences = const HrPreferences(maxHr: 190, restingHr: 60);

  @override
  Future<HrPreferences> getPreferences() async => preferences;
}

class FakeLocalActivityDataSource extends LocalActivityDataSource {
  final List<ActivityModel> storedActivities = [];

  @override
  Future<List<ActivityModel>> getAllActivities() async {
    return List.from(storedActivities);
  }

  @override
  Future<void> saveActivities(List<ActivityModel> activities) async {
    storedActivities.addAll(activities);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial M2: Un-gated Startup, Guest Mode & Routing', () {
    late Directory tempDir;
    late HostileNetworkActivityDataSource hostileRemoteDataSource;
    late FakeTokenStorage fakeTokenStorage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('adversarial_m2_');
      Hive.init(tempDir.path);
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': true,
      });
      hostileRemoteDataSource = HostileNetworkActivityDataSource();
      fakeTokenStorage = FakeTokenStorage(); // Zero stored tokens
    });

    tearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    // =========================================================================
    // Group 1: Hostile Startup Conditions: Zero Network, Zero Stored Tokens
    // =========================================================================
    group('Group 1: Zero Network & Zero Stored Tokens Startup', () {
      testWidgets(
        'Hostile environment: zero tokens and zero network boots directly into MainNavigationScreen and Dashboard without ever touching LoginScreen',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tokenStorageProvider.overrideWithValue(fakeTokenStorage),
                stravaActivityDataSourceProvider.overrideWithValue(
                  hostileRemoteDataSource,
                ),
              ],
              child: const TemanLariApp(),
            ),
          );

          // Pump initial frame and staggered animations
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(seconds: 1));

          // 1. Must mount MainNavigationScreen and DashboardScreen
          expect(find.byType(MainNavigationScreen), findsOneWidget);
          expect(find.byType(DashboardScreen), findsOneWidget);

          // 2. Must NEVER mount LoginScreen
          expect(find.byType(LoginScreen), findsNothing);

          // 3. Greeting in Guest Mode must display "Runner"
          expect(find.textContaining('Runner'), findsOneWidget);

          // 4. Zero outbound network calls should have been made to Strava
          check(hostileRemoteDataSource.getAllActivitiesCalls).equals(0);
          check(hostileRemoteDataSource.getActivityStreamsCalls).equals(0);
          check(hostileRemoteDataSource.getAthleteCalls).equals(0);
        },
      );

      test(
        'Zero network + local cached runs: ActivityRepository serves local data without remote calls',
        () async {
          final localDataSource = FakeLocalActivityDataSource();
          final now = DateTime.now();
          final run1 = ActivityModel(
            id: -101,
            name: 'Morning Beach Run',
            type: 'Run',
            distance: 5000.0,
            movingTime: 1500,
            elapsedTime: 1550,
            totalElevationGain: 30.0,
            startDate: now
                .subtract(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
            averageSpeed: 3.33,
            maxSpeed: 4.2,
          );
          final run2 = ActivityModel(
            id: -102,
            name: 'Afternoon Tempo Run',
            type: 'Run',
            distance: 8000.0,
            movingTime: 2400,
            elapsedTime: 2500,
            totalElevationGain: 50.0,
            startDate: now
                .subtract(const Duration(days: 2))
                .toUtc()
                .toIso8601String(),
            averageSpeed: 3.33,
            maxSpeed: 4.5,
          );

          await localDataSource.saveActivities([run1, run2]);

          final repo = ActivityRepositoryImpl(
            remoteDataSource: hostileRemoteDataSource,
            localDataSource: localDataSource,
            preferencesStorage: FakePreferencesStorage(),
            tokenStorage: fakeTokenStorage,
          );

          final activities = await repo.getAllActivities();
          check(activities.length).equals(2);
          check(activities.first.name).equals('Morning Beach Run');
          check(hostileRemoteDataSource.getAllActivitiesCalls).equals(0);
        },
      );
    });

    // =========================================================================
    // Group 2: Adversarial Routing Matrix: '/', '/dashboard', '/login'
    // =========================================================================
    group('Group 2: Adversarial Routing Matrix', () {
      testWidgets(
        'Navigating to root "/" redirects immediately to "/dashboard"',
        (WidgetTester tester) async {
          final router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const MainNavigationScreen(),
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tokenStorageProvider.overrideWithValue(fakeTokenStorage),
                stravaActivityDataSourceProvider.overrideWithValue(
                  hostileRemoteDataSource,
                ),
              ],
              child: TemanLariApp(routerConfig: router),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          // Verifies redirect lands on /dashboard
          expect(find.byType(MainNavigationScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);
        },
      );

      testWidgets(
        'Navigating explicitly to "/dashboard" boots directly to MainNavigationScreen',
        (WidgetTester tester) async {
          final router = GoRouter(
            initialLocation: '/dashboard',
            routes: [
              GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const MainNavigationScreen(),
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tokenStorageProvider.overrideWithValue(fakeTokenStorage),
                stravaActivityDataSourceProvider.overrideWithValue(
                  hostileRemoteDataSource,
                ),
              ],
              child: TemanLariApp(routerConfig: router),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(find.byType(MainNavigationScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);
        },
      );

      testWidgets('Navigating explicitly to "/login" renders LoginScreen', (
        WidgetTester tester,
      ) async {
        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const MainNavigationScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
              stravaActivityDataSourceProvider.overrideWithValue(
                hostileRemoteDataSource,
              ),
            ],
            child: TemanLariApp(routerConfig: router),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Connect with Strava'), findsOneWidget);
      });

      testWidgets(
        'Bidirectional navigation: /dashboard -> /login -> /dashboard operates smoothly',
        (WidgetTester tester) async {
          final router = GoRouter(
            initialLocation: '/dashboard',
            routes: [
              GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginScreen(),
              ),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const MainNavigationScreen(),
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tokenStorageProvider.overrideWithValue(fakeTokenStorage),
                stravaActivityDataSourceProvider.overrideWithValue(
                  hostileRemoteDataSource,
                ),
              ],
              child: TemanLariApp(routerConfig: router),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(MainNavigationScreen), findsOneWidget);

          // Navigate to /login
          router.go('/login');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(LoginScreen), findsOneWidget);

          // Navigate back to /dashboard
          router.go('/dashboard');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(MainNavigationScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);

          // Navigate back to / (which redirects to /dashboard)
          router.go('/');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(MainNavigationScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);
        },
      );

      testWidgets(
        'Deep linking with query parameters redirects cleanly without infinite loop',
        (WidgetTester tester) async {
          final router = GoRouter(
            initialLocation: '/?ref=marketing&campaign=summer',
            routes: [
              GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const MainNavigationScreen(),
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tokenStorageProvider.overrideWithValue(fakeTokenStorage),
              ],
              child: TemanLariApp(routerConfig: router),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          expect(find.byType(MainNavigationScreen), findsOneWidget);
        },
      );
    });

    // =========================================================================
    // Group 3: Multi-Tab Navigation in Guest Mode (Offline / Unauthenticated)
    // =========================================================================
    group('Group 3: Guest Mode Tab Switching', () {
      testWidgets(
        'Guest can navigate across all bottom navigation tabs without triggering auth gating',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tokenStorageProvider.overrideWithValue(fakeTokenStorage),
                stravaActivityDataSourceProvider.overrideWithValue(
                  hostileRemoteDataSource,
                ),
              ],
              child: const TemanLariApp(),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(DashboardScreen), findsOneWidget);

          // 1. Switch to Analysis tab (index 1)
          await tester.tap(find.byIcon(Icons.analytics));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(AnalysisScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);

          // 2. Switch to Plan tab (index 2)
          await tester.tap(find.byIcon(Icons.calendar_today));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(PlanScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);

          // 3. Switch to Settings tab (index 3)
          await tester.tap(find.byIcon(Icons.settings));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);

          // 4. Return to Dashboard tab (index 0)
          await tester.tap(find.byIcon(Icons.dashboard));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(DashboardScreen), findsOneWidget);
          expect(find.byType(LoginScreen), findsNothing);
        },
      );
    });

    // =========================================================================
    // Group 4: Asynchronous Auth State Latency & Concurrency Stress
    // =========================================================================
    group(
      'Group 4: Auth Asynchrony & Instant Time-to-First-Interaction (F30)',
      () {
        testWidgets(
          'SplashScreen navigates unauthenticated guest to /dashboard, never gating to /login',
          (WidgetTester tester) async {
            final testRouter = GoRouter(
              initialLocation: '/splash',
              routes: [
                GoRoute(
                  path: '/splash',
                  builder: (context, state) => const SplashScreen(),
                ),
                GoRoute(
                  path: '/dashboard',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Instant Dashboard Mount')),
                ),
              ],
            );

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  tokenStorageProvider.overrideWithValue(fakeTokenStorage),
                  stravaActivityDataSourceProvider.overrideWithValue(
                    hostileRemoteDataSource,
                  ),
                ],
                child: MaterialApp.router(routerConfig: testRouter),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));

            expect(find.text('Instant Dashboard Mount'), findsOneWidget);
            expect(find.byType(SplashScreen), findsNothing);
            expect(find.byType(LoginScreen), findsNothing);
          },
        );
      },
    );

    // =========================================================================
    // Group 5: Demographic Baselines & Physiological Fallbacks (F03)
    // =========================================================================
    group('Group 5: Demographic Baselines & Physiological Fallbacks', () {
      test('effectiveMaxHr physiological formula and fallback hierarchy', () {
        // 1. Both null -> fallback 190
        final prefDefault = HrPreferences(restingHr: 60);
        check(prefDefault.effectiveMaxHr).equals(190);

        // 2. Age specified -> 220 - age
        final prefAge30 = HrPreferences(restingHr: 60, age: 30);
        check(prefAge30.effectiveMaxHr).equals(190);

        final prefAge25 = HrPreferences(restingHr: 60, age: 25);
        check(prefAge25.effectiveMaxHr).equals(195);

        final prefAge50 = HrPreferences(restingHr: 60, age: 50);
        check(prefAge50.effectiveMaxHr).equals(170);

        // Boundary: age 0 -> 220
        final prefAge0 = HrPreferences(restingHr: 60, age: 0);
        check(prefAge0.effectiveMaxHr).equals(220);

        // 3. Custom maxHr overrides age calculation
        final prefCustom = HrPreferences(restingHr: 60, age: 25, maxHr: 182);
        check(prefCustom.effectiveMaxHr).equals(182);
      });

      test('thresholdPace duration conversion and null handling', () {
        final prefNoPace = HrPreferences(restingHr: 60);
        check(prefNoPace.thresholdPace).isNull();

        final prefPace = HrPreferences(
          restingHr: 60,
          thresholdPaceSeconds: 300,
        );
        check(prefPace.thresholdPace).isNotNull();
        check(prefPace.thresholdPace!.inSeconds).equals(300);
        check(prefPace.thresholdPace!.inMinutes).equals(5);
      });

      test('PreferencesStorage default getters and persistence', () async {
        final storage = PreferencesStorage();

        // Check defaults
        final defaultResting = await storage.getRestingHr();
        check(defaultResting).equals(60);

        final defaultMax = await storage.getMaxHr();
        check(defaultMax).isNull();

        final defaultPace = await storage.getThresholdPace();
        check(defaultPace).isNull();

        // Save and verify persistence
        await storage.saveRestingHr(52);
        await storage.saveMaxHr(188);
        await storage.saveThresholdPace(285);

        check(await storage.getRestingHr()).equals(52);
        check(await storage.getMaxHr()).equals(188);
        check(await storage.getThresholdPace()).equals(285);

        // Clear and verify reset to defaults
        await storage.clearRestingHr();
        await storage.clearMaxHr();
        await storage.clearThresholdPace();

        check(await storage.getRestingHr()).equals(60);
        check(await storage.getMaxHr()).isNull();
        check(await storage.getThresholdPace()).isNull();
      });
    });

    // =========================================================================
    // Group 6: Decoupled Plan & Analytics Copy Validation
    // =========================================================================
    group('Group 6: Decoupled Plan & Analytics Copy Validation', () {
      test(
        'TrainingPlan.empty() description is decoupled from Strava gating',
        () {
          final emptyPlan = TrainingPlan.empty();
          check(emptyPlan.description).equals(
            'Track or log runs to generate your personalized training plan.',
          );
          check(emptyPlan.description.contains('Strava')).isFalse();
        },
      );

      test(
        'GeneratePlanUseCase and AnalyzeRunsUseCase accept userThresholdPaceSeconds',
        () {
          final generateUseCase = GeneratePlanUseCase();
          final plan = generateUseCase.generate(
            [],
            userThresholdPaceSeconds: 310,
          );
          check(plan).isNotNull();

          final analyzeUseCase = AnalyzeRunsUseCase();
          final stats = analyzeUseCase.compute(
            [],
            userThresholdPace: const Duration(seconds: 310),
          );
          check(
            stats.totalRuns,
          ).equals(0); // Empty activities returns empty stats safely
        },
      );
    });
  });
}
