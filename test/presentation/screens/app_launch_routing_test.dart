import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/main.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/screens/dashboard_screen.dart';
import 'package:teman_lari/presentation/screens/login_screen.dart';
import 'package:teman_lari/presentation/screens/onboarding_screen.dart';

import '../../e2e/e2e_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('First-Launch Routing and Onboarding Shell (Ticket 01, F01, ADR 0009)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('routing_test_');
      Hive.init(tempDir.path);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    testWidgets(
      'Clean install routes directly to /onboarding and renders OnboardingScreen',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        // Verifies OnboardingScreen renders on first launch
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.text('Welcome to Teman Lari'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('skip_onboarding_button')),
          findsOneWidget,
        );

        // Verifies MainNavigationScreen and LoginScreen are NEVER rendered on first launch
        expect(find.byType(MainNavigationScreen), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      'Tapping Skip on OnboardingScreen writes has_completed_onboarding: true and navigates to /dashboard',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Tap Skip
        await tester.tap(find.byKey(const ValueKey('skip_onboarding_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        // Verifies storage flag was set to true
        final storage = PreferencesStorage();
        expect(await storage.hasCompletedOnboarding(), isTrue);

        // Verifies transition to MainNavigationScreen and DashboardScreen
        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);

        // Verifies fallback greeting in guest mode
        expect(find.textContaining('Runner'), findsOneWidget);
      },
    );

    testWidgets(
      'Advancing through OnboardingScreen and completing setup writes has_completed_onboarding: true and navigates to /dashboard',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Tap Get Started to advance from Step 1 to Step 2
        await tester.tap(find.byKey(const ValueKey('get_started_button')));
        await tester.pumpAndSettle();

        // Tap Complete Setup on Step 2
        await tester.tap(
          find.byKey(const ValueKey('complete_onboarding_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        final storage = PreferencesStorage();
        expect(await storage.hasCompletedOnboarding(), isTrue);

        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'Navigating to root path / redirects to /onboarding when onboarding is uncompleted',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        final BuildContext context = tester.element(
          find.byType(Scaffold).first,
        );
        GoRouter.of(context).go('/');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(MainNavigationScreen), findsNothing);
      },
    );
  });

  group('Returning Athlete Launch and Secondary Routing', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'routing_returning_test_',
      );
      Hive.init(tempDir.path);
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding': true,
      });
    });

    tearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    testWidgets(
      'Returning launch (has_completed_onboarding: true) boots directly to MainNavigationScreen and DashboardScreen',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.textContaining('Runner'), findsOneWidget);
      },
    );

    testWidgets(
      'Returning launch: navigating to root path / redirects immediately to /dashboard',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        final BuildContext context = tester.element(
          find.byType(Scaffold).first,
        );
        GoRouter.of(context).go('/');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      'Returning launch: navigating to /onboarding redirects back to /dashboard',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        final BuildContext context = tester.element(
          find.byType(Scaffold).first,
        );
        GoRouter.of(context).go('/onboarding');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      'Explicit navigation to /login route renders LoginScreen for secondary access',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: const TemanLariApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final BuildContext context = tester.element(
          find.byType(MainNavigationScreen),
        );
        GoRouter.of(context).go('/login');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Connect with Strava'), findsOneWidget);
      },
    );

    testWidgets(
      'SplashScreen navigates unauthenticated guest to /dashboard instead of gating to /login',
      (WidgetTester tester) async {
        final fakeTokenStorage = FakeTokenStorage();
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
                  const Scaffold(body: Text('Dashboard Target Screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(fakeTokenStorage),
            ],
            child: MaterialApp.router(routerConfig: testRouter),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dashboard Target Screen'), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
      },
    );

    testWidgets('TemanLariApp accepts optional routerConfig parameter', (
      WidgetTester tester,
    ) async {
      final customRouter = GoRouter(
        initialLocation: '/custom',
        routes: [
          GoRoute(
            path: '/custom',
            builder: (context, state) =>
                const Scaffold(body: Text('Custom Injected Route')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(child: TemanLariApp(routerConfig: customRouter)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Injected Route'), findsOneWidget);
    });
  });
}
