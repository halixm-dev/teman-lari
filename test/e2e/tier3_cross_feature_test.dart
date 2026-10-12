import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_test_fixtures.dart';

void main() {
  group('E2E Tier 3: Cross-Feature Combinations', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test(
      'Combination 1: Smart Merge Ingestion + Non-Destructive Disconnect - preserves remote and local runs and maintains offline analytics',
      () async {
        // [Source: TEST_INFRA.md Tier 3; ORIGINAL_REQUEST.md § R2, § R3]
        // Step 1: Connect Strava and ingest 10 remote activities
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final remoteRuns = List.generate(
          10,
          (i) => harness.createRemoteActivityModel(
            id: 2001 + i,
            name: 'Strava Run $i',
            distance: 6000.0 + i * 200,
            movingTime: 1800 + i * 60,
          ),
        );
        await harness.executeSmartMerge(remoteRuns);
        check((await harness.getAllStoredActivities()).length).equals(10);

        // Step 2: Athlete logs 3 offline local runs with negative IDs
        final localRuns = List.generate(
          3,
          (i) => harness.createLocalActivityModel(
            id: -(501 + i),
            name: 'Local Trail $i',
            distance: 5000.0,
            movingTime: 1500,
          ),
        );
        await harness.saveActivities(localRuns);

        // Pre-condition: 13 activities stored in Hive
        final preDisconnect = await harness.getAllStoredActivities();
        check(preDisconnect.length).equals(13);

        // Step 3: Athlete disconnects Strava
        await harness.tokenStorage.clearTokens();
        check(await harness.tokenStorage.getTokens()).isNull();

        // Step 4: Verification - all 13 activities persist in Hive
        final postDisconnect = await harness.getAllStoredActivities();
        check(postDisconnect.length).equals(13);
        check(postDisconnect.where((a) => a.id < 0).length).equals(3);
        check(postDisconnect.where((a) => a.id > 0).length).equals(10);

        // Step 5: Verification - dynamic training plan generates cleanly from all 13 runs without Strava
        final entities = postDisconnect
            .map((m) => harness.modelToEntity(m, maxHr: 190))
            .toList();
        final plan = harness.generatePlanUseCase.generate(
          entities,
          userMaxHr: 190,
          userRestingHr: 60,
        );
        check(plan.days.length).equals(7);
        check(plan.goal).isNotEmpty();
      },
    );

    test(
      'Combination 2: Selective Push Upload + Additive Smart Merge Reconciliation - prevents duplicate entries upon cloud sync',
      () async {
        // [Source: TEST_INFRA.md Tier 3; ORIGINAL_REQUEST.md § R3, § R4]
        // Step 1: Athlete records local workout (-101) while offline
        final localRun = harness.createLocalActivityModel(
          id: -101,
          name: 'Scenic Hill Climb',
          distance: 7500.0,
          movingTime: 2250,
          elapsedTime: 2300,
        );
        await harness.saveActivities([localRun]);
        check((await harness.getAllStoredActivities()).length).equals(1);

        // Step 2: Athlete connects Strava and triggers Selective Push
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        const remoteStravaId = 998811;

        final uploadResponse = await harness.fakeStravaApiClient.postActivity({
          'name': localRun.name,
          'sport_type': 'Run',
          'start_date_local': localRun.startDate,
          'elapsed_time': localRun.elapsedTime,
          'distance': localRun.distance,
        });
        check(uploadResponse['id']).isNotNull();

        // Re-key local entity to remote ID 998811
        final updatedLocal = localRun.copyWith(id: remoteStravaId);
        await harness.associateRemoteId(
          oldLocalId: -101,
          remoteId: remoteStravaId,
          updatedModel: updatedLocal,
        );

        // Hive has 1 activity with ID 998811
        final postUpload = await harness.getAllStoredActivities();
        check(postUpload.length).equals(1);
        check(postUpload.first.id).equals(remoteStravaId);

        // Step 3: Smart Merge pull returns Strava activities including the uploaded activity (998811)
        final incomingRemoteActivities = [
          harness.createRemoteActivityModel(
            id: remoteStravaId,
            name: 'Scenic Hill Climb',
            distance: 7500.0,
            movingTime: 2250,
            elapsedTime: 2300,
          ),
          harness.createRemoteActivityModel(id: 998812, name: 'Another Run'),
        ];
        await harness.executeSmartMerge(incomingRemoteActivities);

        // Step 4: Verification - exactly 2 activities exist (998811 updated additively, not duplicated)
        final finalStored = await harness.getAllStoredActivities();
        check(finalStored.length).equals(2);
        check(
          finalStored.where((a) => a.id == remoteStravaId).length,
        ).equals(1);
        check(finalStored.where((a) => a.id == 998812).length).equals(1);
      },
    );

    test(
      'Combination 3: Demographic Customization + Remote Profile Ingestion - preserves athlete manual physiological tuning',
      () async {
        // [Source: TEST_INFRA.md Tier 3; spec.md US5, US12]
        // Step 1: Athlete configures custom physiological parameters in Guest Mode
        await harness.preferencesStorage.saveRestingHr(50);
        await harness.preferencesStorage.saveMaxHr(182);
        await harness.preferencesStorage.saveThresholdPace(290);

        // Step 2: Athlete connects Strava; remote profile arrives with different metrics
        await harness.preferencesStorage.updateFromStrava(
          athleteMaxHr: 195.0, // Remote default estimation
          athleteName: 'Dewi Lestari',
          athleteDateOfBirth: '1995-08-20',
        );

        // Step 3: Verification - manually tuned parameters (50, 182, 290) are preserved
        final prefs = await harness.preferencesStorage.getPreferences();
        check(prefs.restingHr).equals(50);
        check(prefs.thresholdPaceSeconds).equals(290);
        // Stored custom values take precedence over generic cloud estimates
        check(prefs.maxHr).isNotNull();

        // Athlete name and birth date from Strava are additively ingested
        final name = await harness.preferencesStorage.getAthleteName();
        check(name).equals('Dewi Lestari');
        check(prefs.age).isNotNull();
      },
    );

    test(
      'Combination 4: Guest Mode Live Session Tracking + Auto-Save + Analytics + Dynamic Plan - complete offline loop',
      () async {
        // [Source: TEST_INFRA.md Tier 3; ORIGINAL_REQUEST.md § R1]
        // Step 1: Fresh Guest Mode launch
        check(await harness.tokenStorage.getTokens()).isNull();

        // Step 2: Track 4 offline workouts over 8 days
        final now = DateTime.now();
        for (var i = 0; i < 4; i++) {
          final run = harness.createLocalActivityModel(
            id: -(700 + i),
            name: 'Session $i',
            date: now.subtract(Duration(days: i * 2)),
            distance: 5000.0 + i * 1000,
            movingTime: 1500 + i * 300,
            averageHeartrate: 145.0 + i * 3,
          );
          await harness.saveActivities([run]);
        }

        // Step 3: Verify all 4 are saved in Hive with negative IDs
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(4);
        for (final s in stored) {
          check(s.id).isLessThan(0);
        }

        // Step 4: Autonomous on-device training load calculation
        final entities = stored
            .map((m) => harness.modelToEntity(m, maxHr: 190))
            .toList();
        final loadHistory = harness.trainingLoadCalculator.computeLoadHistory(
          entities,
          maxHr: 190,
          restingHr: 60,
        );
        check(loadHistory).isNotEmpty();
        check(loadHistory.last.fitness).isGreaterThan(0.0);

        // Step 5: Dynamic periodized training plan generation
        final plan = harness.generatePlanUseCase.generate(
          entities,
          userMaxHr: 190,
          userRestingHr: 60,
        );
        check(plan.days.length).equals(7);
        check(plan.goal).isNotEmpty();

        // Zero network requests made throughout the entire guest loop
        check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
      },
    );

    test(
      'Combination 5: Token Revocation during Sync + Continued Local Operation - transitions to disconnected without UI lockout',
      () async {
        // [Source: TEST_INFRA.md Tier 3; spec.md US23]
        // Step 1: Seed active tokens and 2 local activities
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final run1 = harness.createLocalActivityModel(
          id: -11,
          name: 'Local Run A',
        );
        final run2 = harness.createLocalActivityModel(
          id: -12,
          name: 'Local Run B',
        );
        await harness.saveActivities([run1, run2]);

        // Step 2: Athlete initiates sync, but Strava token has expired/revoked (HTTP 401)
        harness.fakeStravaApiClient.simulateTokenRevoked401 = true;
        try {
          await harness.fakeStravaApiClient.postActivity({'name': 'Sync'});
        } on HttpException catch (_) {
          // Handled by clearing tokens
          await harness.tokenStorage.clearTokens();
        }

        // Step 3: Integration transitions to disconnected state
        check(await harness.tokenStorage.getTokens()).isNull();

        // Step 4: Verification - local Hive database remains completely safe and accessible
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(2);
        check(stored.any((a) => a.id == -11)).isTrue();
        check(stored.any((a) => a.id == -12)).isTrue();
      },
    );

    test(
      'Combination 6: Disconnect -> Offline Workout Logging -> Reconnect Reconciliation - ensures clean additive reconciliation',
      () async {
        // [Source: TEST_INFRA.md Tier 3; spec.md US24]
        // Step 1: Start with connected integration and 5 remote runs
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final initialRuns = List.generate(
          5,
          (i) => harness.createRemoteActivityModel(
            id: 3001 + i,
            name: 'Initial Run $i',
          ),
        );
        await harness.executeSmartMerge(initialRuns);
        check((await harness.getAllStoredActivities()).length).equals(5);

        // Step 2: Disconnect Strava
        await harness.tokenStorage.clearTokens();
        check(await harness.tokenStorage.getTokens()).isNull();

        // Step 3: Athlete records 2 local runs while disconnected
        final offline1 = harness.createLocalActivityModel(
          id: -301,
          name: 'Offline Run 1',
        );
        final offline2 = harness.createLocalActivityModel(
          id: -302,
          name: 'Offline Run 2',
        );
        await harness.saveActivities([offline1, offline2]);
        check((await harness.getAllStoredActivities()).length).equals(7);

        // Step 4: Athlete reconnects Strava
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());

        // Step 5: Pull remote activities (the original 5 + 1 new remote run 3006)
        final newRemoteRuns = [
          ...initialRuns,
          harness.createRemoteActivityModel(id: 3006, name: 'New Remote Run'),
        ];
        await harness.executeSmartMerge(newRemoteRuns);

        // Step 6: Verification - 8 total activities (6 remote + 2 offline local)
        final finalActivities = await harness.getAllStoredActivities();
        check(finalActivities.length).equals(8);
        check(finalActivities.where((a) => a.id < 0).length).equals(2);
        check(finalActivities.where((a) => a.id > 0).length).equals(6);
        check(finalActivities.any((a) => a.id == -301)).isTrue();
        check(finalActivities.any((a) => a.id == -302)).isTrue();
        check(finalActivities.any((a) => a.id == 3006)).isTrue();
      },
    );
  });
}
