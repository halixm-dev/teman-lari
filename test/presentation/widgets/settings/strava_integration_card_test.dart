import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/presentation/providers/activities_provider.dart';
import 'package:teman_lari/presentation/providers/auth_provider.dart';
import 'package:teman_lari/presentation/providers/preferences_provider.dart';
import 'package:teman_lari/presentation/widgets/settings/strava_integration_card.dart';

class TestAuthNotifier extends AuthNotifier {
  final AuthState initialAuthState;
  bool loginCalled = false;
  bool logoutCalled = false;

  TestAuthNotifier({required this.initialAuthState});

  @override
  AuthState build() => initialAuthState;

  @override
  Future<void> login() async {
    loginCalled = true;
    state = const AuthState.authenticated();
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    state = const AuthState.unauthenticated();
  }
}

class ActivitiesTracker {
  bool refreshCalled = false;
}

class TestActivitiesNotifier extends ActivitiesNotifier {
  final ActivitiesTracker tracker;

  TestActivitiesNotifier(this.tracker);

  @override
  Future<List<Activity>> build() async => [];

  @override
  Future<void> refresh() async {
    tracker.refreshCalled = true;
  }

  @override
  Future<void> syncWithStrava() async {
    tracker.refreshCalled = true;
  }
}

void main() {
  group('StravaIntegrationCard Component Tests', () {
    testWidgets(
      'CARD_W01: Disconnected state renders value propositions and Connect CTA',
      (tester) async {
        final authNotifier = TestAuthNotifier(
          initialAuthState: const AuthState.unauthenticated(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => authNotifier)],
            child: const MaterialApp(
              home: Scaffold(body: StravaIntegrationCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Branding and Titles
        expect(find.text('Strava Integration'), findsOneWidget);
        expect(find.text('Optional cloud connection'), findsOneWidget);
        expect(find.text('Not Connected'), findsOneWidget);

        // 2. Value Proposition Highlights
        expect(
          find.text('Connect your Strava account to unlock:'),
          findsOneWidget,
        );
        expect(find.text('Import Activity History'), findsOneWidget);
        expect(find.text('Profile & Zones Sync'), findsOneWidget);
        expect(find.text('Selective Push Upload'), findsOneWidget);

        // 3. Connect CTA Button
        final connectBtnFinder = find.byKey(
          const ValueKey('connect_strava_button'),
        );
        expect(connectBtnFinder, findsOneWidget);
        expect(find.text('Connect with Strava'), findsOneWidget);

        // 4. Connected elements should not be visible
        expect(find.text('Connected'), findsNothing);
        expect(
          find.byKey(const ValueKey('disconnect_strava_button')),
          findsNothing,
        );

        // 5. Tapping Connect calls login
        await tester.tap(connectBtnFinder);
        await tester.pump();
        expect(authNotifier.loginCalled, isTrue);
      },
    );

    testWidgets(
      'CARD_W02: Connected state renders athlete name, Connected badge, and action buttons',
      (tester) async {
        final authNotifier = TestAuthNotifier(
          initialAuthState: const AuthState.authenticated(),
        );
        final tracker = ActivitiesTracker();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => authNotifier),
              athleteNameProvider.overrideWith(
                (ref) => Future.value('Budi Santoso'),
              ),
              activitiesProvider.overrideWith(
                () => TestActivitiesNotifier(tracker),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: StravaIntegrationCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Header & Badge
        expect(find.text('Strava Integration'), findsOneWidget);
        expect(find.text('Active cloud connection'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);

        // 2. Athlete Name
        final athleteNameFinder = find.byKey(
          const ValueKey('connected_athlete_name'),
        );
        expect(athleteNameFinder, findsOneWidget);
        expect(find.text('Budi Santoso'), findsOneWidget);
        expect(find.text('Linked via Strava OAuth'), findsOneWidget);

        // 3. Action Buttons
        final syncBtnFinder = find.byKey(const ValueKey('sync_strava_button'));
        final disconnectBtnFinder = find.byKey(
          const ValueKey('disconnect_strava_button'),
        );
        expect(syncBtnFinder, findsOneWidget);
        expect(disconnectBtnFinder, findsOneWidget);
        expect(find.text('Sync Now'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);

        // 4. Tapping Sync Now calls refresh
        await tester.tap(syncBtnFinder);
        await tester.pumpAndSettle();
        expect(tracker.refreshCalled, isTrue);
        expect(find.text('Activities synced successfully.'), findsOneWidget);
      },
    );

    testWidgets(
      'CARD_W03: Disconnect modal flow shows non-destructive reassurance and allows cancel/confirm',
      (tester) async {
        final authNotifier = TestAuthNotifier(
          initialAuthState: const AuthState.authenticated(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => authNotifier),
              athleteNameProvider.overrideWith(
                (ref) => Future.value('Budi Santoso'),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: StravaIntegrationCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: Tap Disconnect to open modal
        final disconnectBtn = find.byKey(
          const ValueKey('disconnect_strava_button'),
        );
        await tester.tap(disconnectBtn);
        await tester.pumpAndSettle();

        // Step 2: Verify modal title and reassurance copy
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

        // Step 3: Test Keep Connected cancels modal
        expect(find.text('Keep Connected'), findsOneWidget);
        await tester.tap(find.text('Keep Connected'));
        await tester.pumpAndSettle();

        // Modal dismissed, logout was not called
        expect(find.text('Disconnect Strava?'), findsNothing);
        expect(authNotifier.logoutCalled, isFalse);

        // Step 4: Re-open modal and confirm disconnect
        await tester.tap(disconnectBtn);
        await tester.pumpAndSettle();

        final confirmBtn = find.byKey(
          const ValueKey('confirm_disconnect_button'),
        );
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Logout called and SnackBar displayed
        expect(authNotifier.logoutCalled, isTrue);
        expect(
          find.text(
            'Strava disconnected. Local activities and plans preserved.',
          ),
          findsOneWidget,
        );

        // In-place transition to Disconnected state
        expect(find.text('Connect with Strava'), findsOneWidget);
      },
    );

    testWidgets(
      'CARD_W04: Loading state displays spinner and disables button',
      (tester) async {
        final authNotifier = TestAuthNotifier(
          initialAuthState: const AuthState.loading(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => authNotifier)],
            child: const MaterialApp(
              home: Scaffold(body: StravaIntegrationCard()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Connecting to Strava...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final btn = tester.widget<FilledButton>(
          find.byKey(const ValueKey('connect_strava_button')),
        );
        expect(btn.onPressed, isNull); // Disabled while loading
      },
    );

    testWidgets('CARD_W05: Error state displays inline error chip', (
      tester,
    ) async {
      final authNotifier = TestAuthNotifier(
        initialAuthState: const AuthState.error('Network timeout during OAuth'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => authNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: StravaIntegrationCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network timeout during OAuth'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
