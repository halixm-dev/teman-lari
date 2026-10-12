import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/main.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/screens/dashboard_screen.dart';
import 'package:teman_lari/presentation/screens/login_screen.dart';

import '../../e2e/e2e_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Un-gated App Launch and Routing (F01, F02, F30)', () {
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
      'App launches in unauthenticated guest state directly to MainNavigationScreen and DashboardScreen without redirecting to LoginScreen',
      (WidgetTester tester) async {
        final fakeTokenStorage =
            FakeTokenStorage(); // Unauthenticated / no tokens

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

        // Verifies MainNavigationScreen and DashboardScreen render immediately
        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsOneWidget);

        // Verifies LoginScreen is NEVER rendered on launch
        expect(find.byType(LoginScreen), findsNothing);

        // Verifies greeting in Guest Mode displays "Runner"
        expect(find.textContaining('Runner'), findsOneWidget);
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

        // Navigate to /login
        final BuildContext context = tester.element(
          find.byType(MainNavigationScreen),
        );
        GoRouter.of(context).go('/login');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verifies LoginScreen renders on explicit navigation
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Connect with Strava'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigating to root path / redirects immediately to /dashboard',
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
        expect(find.byType(LoginScreen), findsNothing);
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
