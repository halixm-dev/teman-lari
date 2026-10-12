import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/models/strava_tokens.dart';
import 'package:teman_lari/presentation/providers/auth_provider.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/providers/preferences_provider.dart';
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

class TestAuthNotifier extends AuthNotifier {
  final AuthState initialAuthState;
  final FakeTokenStorage tokenStorage;
  bool loginCalled = false;
  bool logoutCalled = false;

  TestAuthNotifier({
    required this.initialAuthState,
    required this.tokenStorage,
  });

  @override
  AuthState build() => initialAuthState;

  @override
  Future<void> login() async {
    loginCalled = true;
    await tokenStorage.saveTokens(
      StravaTokens(
        accessToken: 'mock_access_123',
        refreshToken: 'mock_refresh_456',
        expiresAt: 2000000000,
      ),
    );
    state = const AuthState.authenticated();
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    await tokenStorage.clearTokens();
    state = const AuthState.unauthenticated();
  }
}

void main() {
  late FakeTokenStorage fakeTokenStorage;
  late PreferencesStorage preferencesStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'resting_hr': 60,
      'max_hr': 190,
      'threshold_pace_sec': 315, // 5:15 /km
    });
    fakeTokenStorage = FakeTokenStorage();
    preferencesStorage = PreferencesStorage();
  });

  Widget buildSettingsScreen({
    required AuthState initialAuthState,
    String? athleteName = 'Budi Santoso',
  }) {
    final authNotifier = TestAuthNotifier(
      initialAuthState: initialAuthState,
      tokenStorage: fakeTokenStorage,
    );

    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(fakeTokenStorage),
        preferencesStorageProvider.overrideWithValue(preferencesStorage),
        authProvider.overrideWith(() => authNotifier),
        if (athleteName != null)
          athleteNameProvider.overrideWith((ref) => Future.value(athleteName)),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  group('SettingsScreen Integration Tests (Milestone 3)', () {
    testWidgets(
      'F10_S01: Dedicated Integrations Section Header & Card Presence',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildSettingsScreen(
            initialAuthState: const AuthState.unauthenticated(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Integrations'), findsOneWidget);
        expect(find.byType(StravaIntegrationCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('F11_S02: Disconnected State Rendering & Value Proposition', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildSettingsScreen(
          initialAuthState: const AuthState.unauthenticated(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect with Strava'), findsOneWidget);
      expect(find.text('Import Activity History'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('disconnect_strava_button')),
        findsNothing,
      );
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets(
      'F12_S03: Explicit Tap Triggers Connect Flow and Transitions In-Place',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildSettingsScreen(
            initialAuthState: const AuthState.unauthenticated(),
          ),
        );
        await tester.pumpAndSettle();

        final connectBtn = find.byKey(const ValueKey('connect_strava_button'));
        expect(connectBtn, findsOneWidget);

        await tester.tap(connectBtn);
        await tester.pumpAndSettle();

        // Connected badge and athlete details rendered
        expect(find.text('Connected'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('disconnect_strava_button')),
          findsOneWidget,
        );
        // Athlete remains safely on SettingsScreen
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

    testWidgets('F13_S04: Connected State Displays Athlete Details & Status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeTokenStorage.seedTokens(
        StravaTokens(
          accessToken: 'legacy_access',
          refreshToken: 'legacy_refresh',
          expiresAt: 2000000000,
        ),
      );

      await tester.pumpWidget(
        buildSettingsScreen(
          initialAuthState: const AuthState.authenticated(),
          athleteName: 'Budi Santoso',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('disconnect_strava_button')),
        findsOneWidget,
      );
      expect(find.text('Connect with Strava'), findsNothing);
    });

    testWidgets(
      'F14_S05: Non-Destructive Disconnect Modal preserves local settings and clears tokens',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        fakeTokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'token_to_clear',
            refreshToken: 'refresh_to_clear',
            expiresAt: 2000000000,
          ),
        );

        await tester.pumpWidget(
          buildSettingsScreen(
            initialAuthState: const AuthState.authenticated(),
            athleteName: 'Budi Santoso',
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: Tap disconnect button
        await tester.tap(
          find.byKey(const ValueKey('disconnect_strava_button')),
        );
        await tester.pumpAndSettle();

        // Step 2: Verify modal copy
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

        // Step 3: Confirm disconnect
        final confirmBtn = find.byKey(
          const ValueKey('confirm_disconnect_button'),
        );
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Step 4: Token cleared, card transitions in-place
        expect(await fakeTokenStorage.getTokens(), isNull);
        expect(fakeTokenStorage.clearTokensCallCount, equals(1));
        expect(find.text('Connect with Strava'), findsOneWidget);
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Demographic settings safely preserved!
        final prefs = await preferencesStorage.getPreferences();
        expect(prefs.restingHr, equals(60));
        expect(prefs.maxHr, equals(190));
        expect(prefs.thresholdPaceSeconds, equals(315));
      },
    );

    testWidgets('F14_S06: Cancel Disconnect retains active connection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeTokenStorage.seedTokens(
        StravaTokens(
          accessToken: 'active_token',
          refreshToken: 'active_refresh',
          expiresAt: 2000000000,
        ),
      );

      await tester.pumpWidget(
        buildSettingsScreen(initialAuthState: const AuthState.authenticated()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('disconnect_strava_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Connected'));
      await tester.pumpAndSettle();

      expect(await fakeTokenStorage.getTokens(), isNotNull);
      expect(fakeTokenStorage.clearTokensCallCount, equals(0));
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets(
      'PACE_S09: Threshold Pace Input loads stored value in mm:ss format',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildSettingsScreen(
            initialAuthState: const AuthState.unauthenticated(),
          ),
        );
        await tester.pumpAndSettle();

        // 315 seconds -> "5:15"
        final paceInput = find.byKey(const ValueKey('threshold_pace_input'));
        expect(paceInput, findsOneWidget);
        expect(find.text('5:15'), findsOneWidget);
      },
    );

    testWidgets(
      'PACE_S10: Threshold Pace validation rejects out-of-bounds & malformed values',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildSettingsScreen(
            initialAuthState: const AuthState.unauthenticated(),
          ),
        );
        await tester.pumpAndSettle();

        final paceInput = find.byKey(const ValueKey('threshold_pace_input'));

        // Case 1: Too fast (< 2:30 /km)
        await tester.enterText(paceInput, '1:45');
        await tester.pump();
        expect(
          find.textContaining('Enter pace between 2:30–12:00 /km'),
          findsOneWidget,
        );

        // Case 2: Too slow (> 12:00 /km)
        await tester.enterText(paceInput, '14:00');
        await tester.pump();
        expect(
          find.textContaining('Enter pace between 2:30–12:00 /km'),
          findsOneWidget,
        );

        // Case 3: Malformed
        await tester.enterText(paceInput, 'invalid');
        await tester.pump();
        expect(
          find.textContaining('Enter pace between 2:30–12:00 /km'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'PACE_S11: Valid Threshold Pace enables save and persists seconds',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildSettingsScreen(
            initialAuthState: const AuthState.unauthenticated(),
          ),
        );
        await tester.pumpAndSettle();

        final paceInput = find.byKey(const ValueKey('threshold_pace_input'));
        await tester.enterText(paceInput, '4:45');
        await tester.pump();

        final saveBtn = find.text('Save Changes');
        expect(saveBtn, findsOneWidget);

        await tester.tap(saveBtn);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // 4:45 = 4 * 60 + 45 = 285 seconds
        expect(await preferencesStorage.getThresholdPace(), equals(285));
      },
    );

    testWidgets('PACE_S12: Clearing Threshold Pace removes stored value', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildSettingsScreen(
          initialAuthState: const AuthState.unauthenticated(),
        ),
      );
      await tester.pumpAndSettle();

      final paceInput = find.byKey(const ValueKey('threshold_pace_input'));
      await tester.enterText(paceInput, '');
      await tester.pump();

      final saveBtn = find.text('Save Changes');
      expect(saveBtn, findsOneWidget);

      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(await preferencesStorage.getThresholdPace(), isNull);
    });
  });
}
