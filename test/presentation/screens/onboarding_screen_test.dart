import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/core/utils/responsive.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/models/strava_tokens.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/screens/dashboard_screen.dart';
import 'package:teman_lari/presentation/screens/onboarding_screen.dart';
import 'package:teman_lari/presentation/screens/settings_screen.dart';

class FakeTokenStorage extends TokenStorage {
  StravaTokens? _tokens;
  @override
  Future<StravaTokens?> getTokens() async => _tokens;
  @override
  Future<void> saveTokens(StravaTokens tokens) async => _tokens = tokens;
  @override
  Future<void> clearTokens() async => _tokens = null;
}

class FakeActivitiesNotifier extends ActivitiesNotifier {
  @override
  Future<List<Activity>> build() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableOnboardingScreen({
    ThemeData? theme,
    PreferencesStorage? storage,
    Widget? dashboardTarget,
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
              dashboardTarget ??
              const Scaffold(body: Text('Dashboard Target Screen')),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        preferencesStorageProvider.overrideWithValue(preferencesStorage),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        activitiesProvider.overrideWith(() => FakeActivitiesNotifier()),
        runningStatsProvider.overrideWith((ref) => Future.value(null)),
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
          find.textContaining('TSB (Form)', findRichText: true),
          findsOneWidget,
        );

        // Card 3: Adaptive Plan Generation
        expect(find.text('Adaptive Plan Generation'), findsOneWidget);
        expect(
          find.textContaining('Dynamic periodized', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders progress indicator at Step 1 of 2', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('step_indicator_dots')), findsOneWidget);
    });

    testWidgets('tapping Get Started advances to Step 2 (Demographic Setup)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      final getStartedBtn = find.byKey(const ValueKey('get_started_button'));
      expect(getStartedBtn, findsOneWidget);

      await tester.tap(getStartedBtn);
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.text('Athlete Profile Setup'), findsOneWidget);
    });

    testWidgets('omits complex settings from onboarding sequence', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableOnboardingScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Resting HR (bpm)'), findsNothing);
      expect(find.textContaining('Strava'), findsNothing);
      expect(find.textContaining('Menstrual'), findsNothing);
      expect(find.textContaining('Shoe'), findsNothing);
    });

    testWidgets(
      'renders within constrained responsive container (max-width 600)',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableOnboardingScreen());
        await tester.pumpAndSettle();

        final constrainedFinder = find.byType(ConstrainedContent);
        expect(constrainedFinder, findsOneWidget);
        final constrainedContent = tester.widget<ConstrainedContent>(
          constrainedFinder,
        );
        check(constrainedContent.maxWidth).equals(600);
      },
    );

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
      'AppBar does not have Skip button on Step 1 per Spec User Story 12 & 87',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableOnboardingScreen());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('skip_onboarding_button')),
          findsNothing,
        );
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

        // Enter valid birth date
        await tester.enterText(
          find.byKey(const ValueKey('dob_input')),
          '1996-05-15',
        );
        await tester.pumpAndSettle();

        // Tap Complete Setup
        final completeBtn = find.byKey(
          const ValueKey('complete_onboarding_button'),
        );
        expect(completeBtn, findsOneWidget);
        await tester.tap(completeBtn);
        await tester.pumpAndSettle();

        check(await storage.hasCompletedOnboarding()).isTrue();
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

  group(
    'OnboardingScreen Step 2 - Demographic Setup & Tanaka Persistence (Ticket 03)',
    () {
      testWidgets(
        'Step 2 renders Athlete Name, Date of Birth inputs, Tanaka preview card, and caption',
        (WidgetTester tester) async {
          await tester.pumpWidget(buildTestableOnboardingScreen());
          await tester.pumpAndSettle();

          // Navigate to Step 2
          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          expect(find.text('Athlete Profile Setup'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('athlete_name_input')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('dob_input')), findsOneWidget);
          expect(find.byKey(const ValueKey('age_input')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('dob_picker_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('tanaka_preview_card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('tanaka_max_hr_text')),
            findsOneWidget,
          );
          expect(find.text('-- bpm'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('resting_hr_caption')),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'Resting HR (defaults to 60 bpm)',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('onboarding_back_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('footer_skip_button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('complete_onboarding_button')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'tapping date picker button opens calendar date picker dialog',
        (WidgetTester tester) async {
          await tester.pumpWidget(buildTestableOnboardingScreen());
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Tap calendar icon button
          await tester.tap(find.byKey(const ValueKey('dob_picker_button')));
          await tester.pumpAndSettle();

          // Verify DatePickerDialog appears
          expect(find.byType(DatePickerDialog), findsOneWidget);

          // Dismiss dialog
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();

          expect(find.byType(DatePickerDialog), findsNothing);
        },
      );

      testWidgets(
        'dynamic Tanaka Max HR estimation calculates in real time for benchmark ages',
        (WidgetTester tester) async {
          await tester.pumpWidget(buildTestableOnboardingScreen());
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Age 20: 2006-05-15 -> 208 - (0.7 * 20) = 194 bpm
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '2006-05-15',
          );
          await tester.pumpAndSettle();
          expect(find.text('194 bpm'), findsOneWidget);
          expect(find.textContaining('Age 20'), findsOneWidget);

          // Age 30: 1996-05-15 -> 208 - (0.7 * 30) = 187 bpm
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '1996-05-15',
          );
          await tester.pumpAndSettle();
          expect(find.text('187 bpm'), findsOneWidget);
          expect(find.textContaining('Age 30'), findsOneWidget);

          // Age 45: 1981-05-15 -> 208 - (0.7 * 45) = 177 bpm
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '1981-05-15',
          );
          await tester.pumpAndSettle();
          expect(find.text('177 bpm'), findsOneWidget);
          expect(find.textContaining('Age 45'), findsOneWidget);
        },
      );

      testWidgets(
        'direct age input updates dynamic Tanaka Max HR estimation in real time (US 10 & 55)',
        (WidgetTester tester) async {
          await tester.pumpWidget(buildTestableOnboardingScreen());
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Direct Age 25 -> 208 - (0.7 * 25) = 190.5 -> 191 bpm
          await tester.enterText(find.byKey(const ValueKey('age_input')), '25');
          await tester.pumpAndSettle();
          expect(find.text('191 bpm'), findsOneWidget);
          expect(find.textContaining('Age 25'), findsOneWidget);

          // Direct Age 40 -> 208 - (0.7 * 40) = 180 bpm
          await tester.enterText(find.byKey(const ValueKey('age_input')), '40');
          await tester.pumpAndSettle();
          expect(find.text('180 bpm'), findsOneWidget);
          expect(find.textContaining('Age 40'), findsOneWidget);
        },
      );

      testWidgets(
        'validates date input and rejects future dates and impossible ages with clear inline feedback',
        (WidgetTester tester) async {
          await tester.pumpWidget(buildTestableOnboardingScreen());
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Future date
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '2099-01-01',
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Birth date cannot be in the future'),
            findsOneWidget,
          );
          expect(find.text('-- bpm'), findsOneWidget);

          // Tapping Complete Setup when invalid shows error instead of silently aborting
          await tester.tap(
            find.byKey(const ValueKey('complete_onboarding_button')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Athlete Profile Setup'), findsOneWidget);

          // Age < 5
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '2025-01-01',
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Age must be between 5 and 120 years'),
            findsOneWidget,
          );

          // Age > 120
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '1890-01-01',
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Age must be between 5 and 120 years'),
            findsOneWidget,
          );

          // Empty DOB validation on submit gives clear feedback
          await tester.enterText(find.byKey(const ValueKey('dob_input')), '');
          await tester.enterText(find.byKey(const ValueKey('age_input')), '');
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('complete_onboarding_button')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Please enter or select your birth date'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Back button preserves form inputs and Tanaka preview between steps',
        (WidgetTester tester) async {
          await tester.pumpWidget(buildTestableOnboardingScreen());
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Enter athlete name and DOB
          await tester.enterText(
            find.byKey(const ValueKey('athlete_name_input')),
            'Budi Santoso',
          );
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '1996-05-15',
          );
          await tester.pumpAndSettle();
          expect(find.text('187 bpm'), findsOneWidget);

          // Tap Back button
          await tester.tap(
            find.byKey(const ValueKey('onboarding_back_button')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Welcome to Teman Lari'), findsOneWidget);

          // Return to Step 2
          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Verify form state is preserved
          expect(find.text('Budi Santoso'), findsOneWidget);
          expect(find.text('1996-05-15'), findsOneWidget);
          expect(find.text('187 bpm'), findsOneWidget);
        },
      );

      testWidgets(
        'Complete Setup persists demographics and shows reactive greeting on Dashboard',
        (WidgetTester tester) async {
          final storage = PreferencesStorage();
          await tester.pumpWidget(
            buildTestableOnboardingScreen(
              storage: storage,
              dashboardTarget: const DashboardScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const ValueKey('athlete_name_input')),
            'Budi',
          );
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '1996-05-15',
          );
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(const ValueKey('complete_onboarding_button')),
          );
          await tester.pumpAndSettle();

          // Verifies storage persistence using package:checks
          check(await storage.getAthleteName()).equals('Budi');
          check(await storage.getDateOfBirth()).equals('1996-05-15');
          check(await storage.getMaxHr()).equals(187);
          check(await storage.hasCompletedOnboarding()).isTrue();

          // Verifies dashboard greeting formats as "Hello, Budi!"
          expect(find.text('Hello, Budi!'), findsOneWidget);
        },
      );

      testWidgets(
        'Complete Setup falls back to "Runner" when name is omitted',
        (WidgetTester tester) async {
          final storage = PreferencesStorage();
          await tester.pumpWidget(
            buildTestableOnboardingScreen(
              storage: storage,
              dashboardTarget: const DashboardScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Leave name empty, only enter DOB
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '1996-05-15',
          );
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(const ValueKey('complete_onboarding_button')),
          );
          await tester.pumpAndSettle();

          check(await storage.getAthleteName()).equals('Runner');
          check(await storage.getDateOfBirth()).equals('1996-05-15');
          check(await storage.getMaxHr()).equals(187);
          check(await storage.hasCompletedOnboarding()).isTrue();

          expect(find.text('Hello, Runner!'), findsOneWidget);
        },
      );

      testWidgets(
        'footer Skip button marks onboarding complete and keeps guest mode',
        (WidgetTester tester) async {
          final storage = PreferencesStorage();
          await tester.pumpWidget(
            buildTestableOnboardingScreen(
              storage: storage,
              dashboardTarget: const DashboardScreen(),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          // Tap Skip in footer
          await tester.tap(find.byKey(const ValueKey('footer_skip_button')));
          await tester.pumpAndSettle();

          check(await storage.hasCompletedOnboarding()).isTrue();
          check(await storage.getAthleteName()).isNull();
          check(await storage.getMaxHr()).isNull();

          expect(find.text('Hello, Runner!'), findsOneWidget);
        },
      );

      testWidgets(
        'Settings screen reflects persisted athlete name and calculated max HR',
        (WidgetTester tester) async {
          final storage = PreferencesStorage();
          await tester.pumpWidget(
            buildTestableOnboardingScreen(storage: storage),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('get_started_button')));
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const ValueKey('athlete_name_input')),
            'Budi',
          );
          await tester.enterText(
            find.byKey(const ValueKey('dob_input')),
            '1996-05-15',
          );
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(const ValueKey('complete_onboarding_button')),
          );
          await tester.pumpAndSettle();

          // Navigate to /settings
          final context = tester.element(find.byType(Scaffold).first);
          GoRouter.of(context).go('/settings');
          await tester.pumpAndSettle();

          // Verify Max HR is populated with Tanaka calculated value (187)
          expect(find.widgetWithText(TextField, '187'), findsWidgets);
          // Verify athlete name is populated in storage and Settings field
          check(await storage.getAthleteName()).equals('Budi');
          check(await storage.getMaxHr()).equals(187);
          expect(
            find.byKey(const ValueKey('settings_athlete_name_input')),
            findsOneWidget,
          );
          expect(find.widgetWithText(TextField, 'Budi'), findsWidgets);
        },
      );
    },
  );
}
