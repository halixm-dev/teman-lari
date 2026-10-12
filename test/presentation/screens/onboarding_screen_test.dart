import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/core/utils/responsive.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableOnboardingScreen({
    ThemeData? theme,
    PreferencesStorage? storage,
  }) {
    final preferencesStorage = storage ?? PreferencesStorage();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) =>
              const Scaffold(body: Text('Dashboard Target Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        preferencesStorageProvider.overrideWithValue(preferencesStorage),
      ],
      child: MaterialApp.router(
        theme: theme ?? ThemeData.light(useMaterial3: true),
        routerConfig: router,
      ),
    );
  }

  group('OnboardingScreen Step 1 - Welcome & Value Orientation (Ticket 02)', () {
    testWidgets('renders welcoming hero typography and brand icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      // Hero typography
      expect(find.text('Welcome to Teman Lari'), findsOneWidget);
      expect(
        find.textContaining('running companion', findRichText: true),
        findsOneWidget,
      );

      // Hero runner icon
      expect(find.byIcon(Icons.directions_run_rounded), findsWidgets);
    });

    testWidgets(
      'renders all three core value proposition cards with descriptions',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableOnboardingScreen());
        await tester.pumpAndSettle();

        // Card 1: Offline-First Tracking
        expect(find.text('Offline-First Tracking'), findsOneWidget);
        expect(
          find.textContaining('zero-TTL', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('GPS and sensors', findRichText: true),
          findsOneWidget,
        );

        // Card 2: Autonomous On-Device Analytics
        expect(find.text('Autonomous On-Device Analytics'), findsOneWidget);
        expect(
          find.textContaining('ATL (Fatigue)', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('CTL (Fitness)', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('TSB (Form)', findRichText: true),
          findsOneWidget,
        );

        // Card 3: Adaptive Plan Generation
        expect(find.text('Adaptive Plan Generation'), findsOneWidget);
        expect(
          find.textContaining('periodized', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders step indicator reflecting Step 1 of 2', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('step_indicator_dots')), findsOneWidget);
    });

    testWidgets(
      'advances to Step 2 when tapping Get Started and can navigate Back',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableOnboardingScreen());
        await tester.pumpAndSettle();

        // Initial state is Step 1
        expect(find.text('Step 1 of 2'), findsOneWidget);
        expect(find.text('Welcome to Teman Lari'), findsOneWidget);

        // Tap Get Started button
        final getStartedBtn = find.byKey(const ValueKey('get_started_button'));
        expect(getStartedBtn, findsOneWidget);
        await tester.tap(getStartedBtn);
        await tester.pumpAndSettle();

        // Now on Step 2
        expect(find.text('Step 2 of 2'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('onboarding_step_2_placeholder')),
          findsOneWidget,
        );

        // Tap Back button to return to Step 1
        final backBtn = find.byKey(const ValueKey('onboarding_back_button'));
        expect(backBtn, findsOneWidget);
        await tester.tap(backBtn);
        await tester.pumpAndSettle();

        // Back on Step 1
        expect(find.text('Step 1 of 2'), findsOneWidget);
        expect(find.text('Welcome to Teman Lari'), findsOneWidget);
      },
    );

    testWidgets('enforces max-width constraints on tablet/desktop screens', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      // Verify ConstrainedContent applies maxWidth 600
      final constrainedContentFinder = find.byType(ConstrainedContent);
      expect(constrainedContentFinder, findsWidgets);

      final constrainedContent = tester.widget<ConstrainedContent>(
        constrainedContentFinder.first,
      );
      expect(constrainedContent.maxWidth, 600);
    });

    testWidgets('renders cleanly in dark theme with proper styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableOnboardingScreen(
          theme: ThemeData.dark(useMaterial3: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Teman Lari'), findsOneWidget);
      expect(find.text('Offline-First Tracking'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets(
      'tapping Skip in AppBar marks onboarding complete and navigates to /dashboard',
      (WidgetTester tester) async {
        final storage = PreferencesStorage();
        await tester.pumpWidget(
          buildTestableOnboardingScreen(storage: storage),
        );
        await tester.pumpAndSettle();

        final skipBtn = find.byKey(const ValueKey('skip_onboarding_button'));
        expect(skipBtn, findsOneWidget);
        await tester.tap(skipBtn);
        await tester.pumpAndSettle();

        expect(await storage.hasCompletedOnboarding(), isTrue);
        expect(find.text('Dashboard Target Screen'), findsOneWidget);
      },
    );

    testWidgets('can navigate back using the AppBar back button from Step 2', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.byKey(const ValueKey('get_started_button')));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 2'), findsOneWidget);

      // Tap AppBar back button
      final appbarBackBtn = find.byKey(
        const ValueKey('onboarding_appbar_back_button'),
      );
      expect(appbarBackBtn, findsOneWidget);
      await tester.tap(appbarBackBtn);
      await tester.pumpAndSettle();

      // Returned to Step 1
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Welcome to Teman Lari'), findsOneWidget);
    });

    testWidgets(
      'completing Step 2 marks onboarding complete and navigates to /dashboard',
      (WidgetTester tester) async {
        final storage = PreferencesStorage();
        await tester.pumpWidget(
          buildTestableOnboardingScreen(storage: storage),
        );
        await tester.pumpAndSettle();

        // Advance to Step 2
        await tester.tap(find.byKey(const ValueKey('get_started_button')));
        await tester.pumpAndSettle();

        // Tap Complete Setup
        final completeBtn = find.byKey(
          const ValueKey('complete_onboarding_button'),
        );
        expect(completeBtn, findsOneWidget);
        await tester.tap(completeBtn);
        await tester.pumpAndSettle();

        expect(await storage.hasCompletedOnboarding(), isTrue);
        expect(find.text('Dashboard Target Screen'), findsOneWidget);
      },
    );

    testWidgets('verifies distinct value card keys are present on Step 1', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('value_card_offline_tracking')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('value_card_analytics')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('value_card_plans')), findsOneWidget);
    });
  });
}
