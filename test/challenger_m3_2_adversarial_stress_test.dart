import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/strava_activity_datasource.dart';
import 'package:teman_lari/data/datasources/strava_auth_datasource.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/models/activity_model.dart';
import 'package:teman_lari/data/models/activity_streams.dart';
import 'package:teman_lari/data/models/athlete_model.dart';
import 'package:teman_lari/data/models/strava_tokens.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/usecases/strava_auth_usecase.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/core_provider.dart';
import 'package:teman_lari/presentation/providers/preferences_provider.dart';
import 'package:teman_lari/presentation/screens/settings_screen.dart';
import 'package:teman_lari/presentation/widgets/settings/heart_rate_card.dart';

// ============================================================================
// Adversarial Fakes & Mocks
// ============================================================================

class HostileTokenStorage extends TokenStorage {
  StravaTokens? _tokens;
  int clearTokensCallCount = 0;
  int saveTokensCallCount = 0;
  int getTokensCallCount = 0;
  bool throwOnGet = false;

  void seedTokens(StravaTokens tokens) => _tokens = tokens;

  @override
  Future<StravaTokens?> getTokens() async {
    getTokensCallCount++;
    if (throwOnGet) {
      throw const FileSystemException('Corrupted secure storage sector');
    }
    return _tokens;
  }

  @override
  Future<void> saveTokens(StravaTokens tokens) async {
    saveTokensCallCount++;
    _tokens = tokens;
  }

  @override
  Future<void> clearTokens() async {
    clearTokensCallCount++;
    _tokens = null;
  }
}

class HostileStravaAuthDataSource extends StravaAuthDataSource {
  int authenticateCallCount = 0;
  int refreshTokenCallCount = 0;
  bool isNetworkOffline = false;
  Completer<StravaTokens>? pendingAuthCompleter;

  HostileStravaAuthDataSource() : super(http.Client());

  @override
  Future<StravaTokens> authenticate() async {
    authenticateCallCount++;
    if (isNetworkOffline) {
      throw const SocketException('Network unreachable');
    }
    if (pendingAuthCompleter != null) {
      return await pendingAuthCompleter!.future;
    }
    return StravaTokens(
      accessToken: 'adversarial_access_token',
      refreshToken: 'adversarial_refresh_token',
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 21600,
    );
  }

  @override
  Future<StravaTokens> refreshToken(String refreshToken) async {
    refreshTokenCallCount++;
    if (isNetworkOffline) {
      throw const SocketException('Network unreachable');
    }
    return StravaTokens(
      accessToken: 'refreshed_access_token',
      refreshToken: 'refreshed_refresh_token',
      expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 21600,
    );
  }
}

class FakeStravaActivityDataSource implements StravaActivityDataSource {
  @override
  Future<AthleteModel> getAthlete() async {
    return const AthleteModel(
      id: 999999,
      firstName: 'Adversarial',
      lastName: 'Runner',
    );
  }

  @override
  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async =>
      [];

  @override
  Future<ActivityStreams> getActivityStreams(int activityId) async =>
      const ActivityStreams();

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

class MockActivitiesNotifier extends ActivitiesNotifier {
  int refreshCallCount = 0;

  @override
  Future<List<Activity>> build() async => [];

  @override
  Future<void> refresh() async {
    refreshCallCount++;
  }
}

// ============================================================================
// Main Adversarial Test Suite
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // --------------------------------------------------------------------------
  // Group 1: Malformed and Edge-case Threshold Pace Input Matrix
  // --------------------------------------------------------------------------
  group('ADV-PACE-01: Malformed Threshold Pace String Matrix', () {
    test('Strict null return on malformed strings in parsePace', () {
      final malformedInputs = <String>[
        'abc',
        '99:99',
        '-5:00',
        ':',
        '::',
        '5:',
        ':30',
        '5:60',
        '5:-10',
        '-0:30',
        '5:00:00',
        '5.30',
        '5,30',
        'null',
        'undefined',
        'NaN',
        'five:thirty',
      ];

      for (final input in malformedInputs) {
        final parsed = ThresholdPaceUtils.parsePace(input);
        expect(
          parsed,
          isNull,
          reason: 'Expected parsePace("$input") to be null, got $parsed',
        );
      }
    });

    test('Strict empty and whitespace handling (allowed for clearing)', () {
      expect(ThresholdPaceUtils.parsePace(''), isNull);
      expect(ThresholdPaceUtils.parsePace('   '), isNull);
      expect(ThresholdPaceUtils.parsePace('\t\n'), isNull);

      // validatePaceString allows empty/blank so runner can clear threshold pace
      expect(ThresholdPaceUtils.validatePaceString(''), isNull);
      expect(ThresholdPaceUtils.validatePaceString('   '), isNull);
      expect(ThresholdPaceUtils.validatePaceString('\t\n'), isNull);
    });

    test(
      'Validation message accuracy across invalid format vs out-of-bounds',
      () {
        // Format syntax errors -> suggest format "(e.g. 5:00)"
        expect(
          ThresholdPaceUtils.validatePaceString('abc'),
          equals('Enter pace between 2:30–12:00 /km (e.g. 5:00)'),
        );
        expect(
          ThresholdPaceUtils.validatePaceString('99:99'),
          equals('Enter pace between 2:30–12:00 /km (e.g. 5:00)'),
        );
        expect(
          ThresholdPaceUtils.validatePaceString('-5:00'),
          equals('Enter pace between 2:30–12:00 /km (e.g. 5:00)'),
        );

        // Valid syntax but out of physiological range (150s - 720s)
        expect(
          ThresholdPaceUtils.validatePaceString('0:00'),
          equals('Enter pace between 2:30–12:00 /km'),
        );
        expect(
          ThresholdPaceUtils.validatePaceString('1:30'),
          equals('Enter pace between 2:30–12:00 /km'),
        );
        expect(
          ThresholdPaceUtils.validatePaceString('2:29'),
          equals('Enter pace between 2:30–12:00 /km'),
        );
        expect(
          ThresholdPaceUtils.validatePaceString('12:01'),
          equals('Enter pace between 2:30–12:00 /km'),
        );
        expect(
          ThresholdPaceUtils.validatePaceString('15:00'),
          equals('Enter pace between 2:30–12:00 /km'),
        );
        expect(
          ThresholdPaceUtils.validatePaceString('99:00'),
          equals('Enter pace between 2:30–12:00 /km'),
        );
      },
    );
  });

  // --------------------------------------------------------------------------
  // Group 2: Boundary Value Exact Precision & Round-Trip Fuzzing
  // --------------------------------------------------------------------------
  group('ADV-PACE-02: Boundary Values & Round-Trip Formatting Stability', () {
    test('Lower boundary: 2:30 = exactly 150 seconds', () {
      final parsed = ThresholdPaceUtils.parsePace('2:30');
      expect(parsed, equals(150));
      expect(ThresholdPaceUtils.isValidPaceSeconds(150), isTrue);
      expect(ThresholdPaceUtils.isValidPaceSeconds(149), isFalse);
      expect(ThresholdPaceUtils.formatPace(150), equals('2:30'));
      expect(ThresholdPaceUtils.validatePaceString('2:30'), isNull);
    });

    test('Upper boundary: 12:00 = exactly 720 seconds', () {
      final parsed = ThresholdPaceUtils.parsePace('12:00');
      expect(parsed, equals(720));
      expect(ThresholdPaceUtils.isValidPaceSeconds(720), isTrue);
      expect(ThresholdPaceUtils.isValidPaceSeconds(721), isFalse);
      expect(ThresholdPaceUtils.formatPace(720), equals('12:00'));
      expect(ThresholdPaceUtils.validatePaceString('12:00'), isNull);
    });

    test('Fuzzing all 571 discrete seconds in [150, 720] for bijection', () {
      for (int sec = 150; sec <= 720; sec++) {
        final formatted = ThresholdPaceUtils.formatPace(sec);
        final roundTripped = ThresholdPaceUtils.parsePace(formatted);
        expect(
          roundTripped,
          equals(sec),
          reason:
              'Roundtrip failed for $sec s -> $formatted -> $roundTripped s',
        );
        expect(ThresholdPaceUtils.isValidPaceSeconds(roundTripped!), isTrue);
        expect(ThresholdPaceUtils.validatePaceString(formatted), isNull);
      }
    });

    testWidgets(
      'SettingsScreen persists boundary values 150s (2:30) and 720s (12:00)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        SharedPreferences.setMockInitialValues({});
        final prefsStorage = PreferencesStorage();
        final tokenStorage = HostileTokenStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesStorageProvider.overrideWithValue(prefsStorage),
              tokenStorageProvider.overrideWithValue(tokenStorage),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final paceInput = find.byKey(const ValueKey('threshold_pace_input'));
        final saveBtn = find.text('Save Changes');

        // Test 1: Enter lower boundary 2:30
        await tester.enterText(paceInput, '2:30');
        await tester.pump();
        expect(find.textContaining('Enter pace between'), findsNothing);
        await tester.tap(saveBtn);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(await prefsStorage.getThresholdPace(), equals(150));

        // Test 2: Enter upper boundary 12:00
        await tester.enterText(paceInput, '12:00');
        await tester.pump();
        expect(find.textContaining('Enter pace between'), findsNothing);
        await tester.tap(saveBtn);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(await prefsStorage.getThresholdPace(), equals(720));

        // Test 3: Clear pace input completely -> null in storage
        await tester.enterText(paceInput, '');
        await tester.pump();
        await tester.tap(saveBtn);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        expect(await prefsStorage.getThresholdPace(), isNull);
      },
    );
  });

  // --------------------------------------------------------------------------
  // Group 3: Rapid State Thrashing & Disconnect Modal Stress
  // --------------------------------------------------------------------------
  group('ADV-MODAL-03: Rapid Modal Toggling & State Thrashing', () {
    testWidgets(
      'Rapidly opening and dismissing disconnect modal 5 times does not leak state or trigger logout',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final tokenStorage = HostileTokenStorage();
        tokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'valid_tok',
            refreshToken: 'valid_ref',
            expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          ),
        );
        final prefsStorage = PreferencesStorage();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStorageProvider.overrideWithValue(tokenStorage),
              preferencesStorageProvider.overrideWithValue(prefsStorage),
              athleteNameProvider.overrideWith(
                (ref) => Future.value('Fast Runner'),
              ),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final disconnectBtn = find.byKey(
          const ValueKey('disconnect_strava_button'),
        );
        expect(disconnectBtn, findsOneWidget);

        // Thrash modal 5 times: open, tap Keep Connected, repeat
        for (int i = 0; i < 5; i++) {
          await tester.tap(disconnectBtn);
          await tester.pumpAndSettle();

          expect(find.text('Disconnect Strava?'), findsOneWidget);
          expect(
            find.text('Your local data is completely safe.'),
            findsOneWidget,
          );

          final keepConnectedBtn = find.text('Keep Connected');
          expect(keepConnectedBtn, findsOneWidget);
          await tester.tap(keepConnectedBtn);
          await tester.pumpAndSettle();

          expect(find.text('Disconnect Strava?'), findsNothing);
          expect(tokenStorage.clearTokensCallCount, equals(0));
        }

        // Connection is completely intact
        expect(find.text('Connected'), findsOneWidget);
      },
    );

    testWidgets(
      'Connect button is disabled and shows loading indicator while authentication is in-flight',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authDataSource = HostileStravaAuthDataSource();
        final completer = Completer<StravaTokens>();
        authDataSource.pendingAuthCompleter = completer;

        final tokenStorage = HostileTokenStorage();
        final prefsStorage = PreferencesStorage();

        final container = ProviderContainer(
          overrides: [
            stravaAuthDataSourceProvider.overrideWithValue(authDataSource),
            tokenStorageProvider.overrideWithValue(tokenStorage),
            preferencesStorageProvider.overrideWithValue(prefsStorage),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final connectBtnFinder = find.byKey(
          const ValueKey('connect_strava_button'),
        );
        expect(connectBtnFinder, findsOneWidget);

        // Tap once to trigger login
        await tester.tap(connectBtnFinder);
        await tester.pump(); // Enter loading state

        // In-flight: Button is disabled and shows loading text
        expect(find.text('Connecting to Strava...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final btnWidget = tester.widget<FilledButton>(connectBtnFinder);
        expect(btnWidget.onPressed, isNull);

        // Complete the in-flight authentication
        completer.complete(
          StravaTokens(
            accessToken: 'delayed_access_token',
            refreshToken: 'delayed_refresh_token',
            expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 21600,
          ),
        );
        await tester.pumpAndSettle();

        // Exactly 1 authenticate call was made, transitioned to Connected state
        expect(authDataSource.authenticateCallCount, equals(1));
        expect(find.text('Connected'), findsOneWidget);
      },
    );

    testWidgets(
      'Non-destructive disconnect followed immediately by reconnect transitions cleanly in-place',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final authDataSource = HostileStravaAuthDataSource();
        final tokenStorage = HostileTokenStorage();
        tokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'initial_tok',
            refreshToken: 'initial_ref',
            expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          ),
        );
        final prefsStorage = PreferencesStorage();
        await prefsStorage.saveThresholdPace(300);

        final container = ProviderContainer(
          overrides: [
            stravaAuthDataSourceProvider.overrideWithValue(authDataSource),
            tokenStorageProvider.overrideWithValue(tokenStorage),
            preferencesStorageProvider.overrideWithValue(prefsStorage),
            stravaActivityDataSourceProvider.overrideWithValue(
              FakeStravaActivityDataSource(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial Connected State
        expect(find.text('Connected'), findsOneWidget);

        // 2. Disconnect
        await tester.tap(
          find.byKey(const ValueKey('disconnect_strava_button')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('confirm_disconnect_button')),
        );
        await tester.pumpAndSettle();

        // Transitioned to Disconnected in-place
        expect(find.text('Connect with Strava'), findsOneWidget);
        expect(tokenStorage.clearTokensCallCount, equals(1));
        // Demographic setting remains completely intact!
        expect(await prefsStorage.getThresholdPace(), equals(300));

        // 3. Immediately Reconnect
        await tester.tap(find.byKey(const ValueKey('connect_strava_button')));
        await tester.pumpAndSettle();

        // Transitioned back to Connected in-place
        expect(find.text('Connected'), findsOneWidget);
        expect(tokenStorage.saveTokensCallCount, equals(1));
      },
    );
  });

  // --------------------------------------------------------------------------
  // Group 4: Legacy Token Detection on Cold Launch Without Network Access
  // --------------------------------------------------------------------------
  group('ADV-TOKEN-04: Legacy Token Cold Launch Without Network Access', () {
    test(
      'Valid unexpired legacy token: boots into authenticated state with 0 outbound network calls',
      () async {
        final tokenStorage = HostileTokenStorage();
        final authDataSource = HostileStravaAuthDataSource();
        authDataSource.isNetworkOffline = true; // Complete network disconnect

        final futureExpiry =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 7200;
        tokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'legacy_access_valid',
            refreshToken: 'legacy_refresh_valid',
            expiresAt: futureExpiry,
          ),
        );

        final useCase = StravaAuthUseCase(
          authDataSource: authDataSource,
          tokenStorage: tokenStorage,
        );

        final isAuth = await useCase.checkAuthStatus();

        expect(isAuth, isTrue);
        // Zero network calls made when unexpired legacy token exists
        expect(authDataSource.refreshTokenCallCount, equals(0));
        expect(authDataSource.authenticateCallCount, equals(0));
      },
    );

    test(
      'Expired legacy token with offline network: safely degrades to unauthenticated without crash',
      () async {
        final tokenStorage = HostileTokenStorage();
        final authDataSource = HostileStravaAuthDataSource();
        authDataSource.isNetworkOffline = true; // Complete network disconnect

        final pastExpiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
        tokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'legacy_access_expired',
            refreshToken: 'legacy_refresh_expired',
            expiresAt: pastExpiry,
          ),
        );

        final useCase = StravaAuthUseCase(
          authDataSource: authDataSource,
          tokenStorage: tokenStorage,
        );

        // Does NOT throw SocketException or crash
        final isAuth = await useCase.checkAuthStatus();

        expect(isAuth, isFalse);
        expect(authDataSource.refreshTokenCallCount, equals(1));
      },
    );

    testWidgets(
      'Cold launch with valid legacy token displays Connected state in UI offline',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final tokenStorage = HostileTokenStorage();
        final authDataSource = HostileStravaAuthDataSource();
        authDataSource.isNetworkOffline = true;

        final futureExpiry =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 7200;
        tokenStorage.seedTokens(
          StravaTokens(
            accessToken: 'legacy_saved_token',
            refreshToken: 'legacy_saved_refresh',
            expiresAt: futureExpiry,
          ),
        );

        final prefsStorage = PreferencesStorage();
        await prefsStorage.saveAthleteName('Legacy Olympian');

        final container = ProviderContainer(
          overrides: [
            tokenStorageProvider.overrideWithValue(tokenStorage),
            stravaAuthDataSourceProvider.overrideWithValue(authDataSource),
            preferencesStorageProvider.overrideWithValue(prefsStorage),
            athleteNameProvider.overrideWith(
              (ref) => Future.value('Legacy Olympian'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Legacy Olympian'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('disconnect_strava_button')),
          findsOneWidget,
        );
        expect(find.text('Connect with Strava'), findsNothing);
      },
    );

    test(
      'EMPIRICAL FINDING: Unhandled storage exception in checkAuthStatus propagates when TokenStorage throws',
      () async {
        final tokenStorage = HostileTokenStorage();
        tokenStorage.throwOnGet = true; // Simulates corrupted storage read

        final authDataSource = HostileStravaAuthDataSource();

        final useCase = StravaAuthUseCase(
          authDataSource: authDataSource,
          tokenStorage: tokenStorage,
        );

        // Proves empirically that checkAuthStatus does not catch tokenStorage errors
        expect(
          () => useCase.checkAuthStatus(),
          throwsA(isA<FileSystemException>()),
        );
      },
    );
  });
}
