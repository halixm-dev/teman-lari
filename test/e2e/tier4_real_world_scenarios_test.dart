import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_test_fixtures.dart';

void main() {
  group('E2E Tier 4: Real-World Application Scenarios', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test(
      'Scenario 1: Complete Guest Runner Journey - offline startup, session recording, on-device load, and plan generation',
      () async {
        // [Source: TEST_INFRA.md Scenario 1; F01, F02, F03, F04, F05, F06, F07, F08, F09, F30]
        // 1. Initial Launch: Athlete boots app without account or internet connection
        check(await harness.tokenStorage.getTokens()).isNull();

        // Athlete operates in Guest Mode with default greeting fallback
        final initialName = await harness.preferencesStorage.getAthleteName();
        check(initialName).isNull(); // Resolves to 'Runner' fallback in UI

        // 2. Physiological Customization: Athlete navigates to Settings and customizes parameters
        await harness.preferencesStorage.saveRestingHr(54);
        await harness.preferencesStorage.saveMaxHr(186);
        await harness.preferencesStorage.saveThresholdPace(315); // 5:15 min/km

        final savedPrefs = await harness.preferencesStorage.getPreferences();
        check(savedPrefs.restingHr).equals(54);
        check(savedPrefs.maxHr).equals(186);
        check(savedPrefs.thresholdPaceSeconds).equals(315);

        // 3. Live Workout Tracking: Athlete completes 3 running sessions offline over several days
        final now = DateTime.now();
        final sessions = [
          harness.createLocalActivityModel(
            id: -DateTime.now()
                .subtract(const Duration(days: 4))
                .millisecondsSinceEpoch,
            name: 'Morning Park Run',
            date: now.subtract(const Duration(days: 4)),
            distance: 5200.0,
            movingTime: 1600,
            averageHeartrate: 148.0,
          ),
          harness.createLocalActivityModel(
            id: -DateTime.now()
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch,
            name: 'Tempo Interval Session',
            date: now.subtract(const Duration(days: 2)),
            distance: 6500.0,
            movingTime: 1950,
            averageHeartrate: 162.0,
          ),
          harness.createLocalActivityModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            name: 'Weekend Easy Recovery',
            date: now,
            distance: 4000.0,
            movingTime: 1300,
            averageHeartrate: 138.0,
          ),
        ];

        // 4. In-App Workout Auto-Save: Sessions committed to local Hive SSOT
        await harness.saveActivities(sessions);

        // 5. Unauthenticated Activity Retrieval (Zero-TTL): All 3 runs loaded locally
        final loadedActivities = await harness.getAllStoredActivities();
        check(loadedActivities.length).equals(3);
        for (final run in loadedActivities) {
          check(run.id).isLessThan(0); // All have negative local IDs
        }

        // 6. Autonomous On-Device Training Load Calculation
        final domainActivities = loadedActivities
            .map((m) => harness.modelToEntity(m, maxHr: savedPrefs.maxHr!))
            .toList();

        final loadHistory = harness.trainingLoadCalculator.computeLoadHistory(
          domainActivities,
          maxHr: savedPrefs.maxHr!,
          restingHr: savedPrefs.restingHr,
        );
        check(loadHistory).isNotEmpty();
        final latestLoad = loadHistory.last;
        check(latestLoad.fitness).isGreaterThan(0.0);
        check(latestLoad.fatigue).isGreaterThan(0.0);

        // 7. Dynamic Plan Generation: Generates 7-day periodized schedule adapted to runner
        final plan = harness.generatePlanUseCase.generate(
          domainActivities,
          userMaxHr: savedPrefs.maxHr!,
          userRestingHr: savedPrefs.restingHr,
        );
        check(plan.days.length).equals(7);
        check(plan.goal).isNotEmpty();
        check(plan.description).isNotEmpty();

        // 8. Zero Network Invocations: Complete guest runner journey executed without cloud dependencies
        check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
      },
    );

    test(
      'Scenario 2: Strava Linking & Additive Smart Merge - connects Strava, ingests remote runs, preserves local runs',
      () async {
        // [Source: TEST_INFRA.md Scenario 2; F10, F11, F12, F13, F17, F18, F19, F20, F29]
        // 1. Pre-condition: Athlete has 2 local-only workouts (-101, -102) recorded offline
        final local1 = harness.createLocalActivityModel(
          id: -101,
          name: 'Local Trail Run',
          distance: 5000.0,
        );
        final local2 = harness.createLocalActivityModel(
          id: -102,
          name: 'Local Speedwork',
          distance: 4000.0,
        );
        await harness.saveActivities([local1, local2]);
        check((await harness.getAllStoredActivities()).length).equals(2);

        // 2. Settings Discovery: Strava integration card displays disconnected state
        check(await harness.tokenStorage.getTokens()).isNull();

        // 3. Initiate Connection: Athlete connects Strava account
        final sampleTokens = harness.createSampleTokens();
        await harness.tokenStorage.saveTokens(sampleTokens);
        check(await harness.tokenStorage.getTokens()).isNotNull();

        // 4. Initial Sync: Pulls 5 remote Strava activities
        final remoteActivities = List.generate(
          5,
          (i) => harness.createRemoteActivityModel(
            id: 8001 + i,
            name: 'Historical Strava Run $i',
            distance: 6000.0 + i * 500,
          ),
        );

        // 5. Additive Smart Merge Ingestion
        await harness.executeSmartMerge(remoteActivities);

        // 6. Verification: 7 total activities in Hive (2 local preserved + 5 remote ingested)
        final mergedActivities = await harness.getAllStoredActivities();
        check(mergedActivities.length).equals(7);
        check(mergedActivities.any((a) => a.id == -101)).isTrue();
        check(mergedActivities.any((a) => a.id == -102)).isTrue();
        for (var i = 0; i < 5; i++) {
          check(mergedActivities.any((a) => a.id == 8001 + i)).isTrue();
        }

        // 7. Additive Profile Baseline Sync: Ingests athlete name from Strava
        await harness.preferencesStorage.updateFromStrava(
          athleteName: 'Budi Runner',
          athleteMaxHr: 185.0,
        );
        final athleteName = await harness.preferencesStorage.getAthleteName();
        check(athleteName).equals('Budi Runner');
      },
    );

    test(
      'Scenario 3: Selective Push Upload Flow - user-initiated upload, remote ID linking, and sync badging',
      () async {
        // [Source: TEST_INFRA.md Scenario 3; F22, F23, F24, F25, F26, F28]
        // 1. Setup: Strava connected, athlete records an offline workout (-888)
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final offlineRun = harness.createLocalActivityModel(
          id: -888,
          name: 'Marathon Simulation Run',
          distance: 21097.0,
          movingTime: 6600,
          elapsedTime: 6650,
        );
        await harness.saveActivities([offlineRun]);

        // 2. Differentiation: Evaluates activity as local-only (id < 0)
        final preUpload = (await harness.getAllStoredActivities()).first;
        check(
          preUpload.id < 0,
        ).isTrue(); // Denotes 'Local' badge on activity card

        // Verify background auto-upload was NOT performed
        check(harness.fakeStravaApiClient.recordedRequests).isEmpty();

        // 3. User-Initiated Upload: Athlete taps "Upload to Strava" button
        const assignedRemoteId = 771239;
        final uploadResponse = await harness.fakeStravaApiClient.postActivity({
          'name': offlineRun.name,
          'sport_type': 'Run',
          'start_date_local': offlineRun.startDate,
          'elapsed_time': offlineRun.elapsedTime,
          'distance': offlineRun.distance,
        });

        check(uploadResponse['id']).isNotNull();
        check(harness.fakeStravaApiClient.recordedRequests.length).equals(1);

        // 4. Remote ID Association: Local Hive record updated with remote ID
        final updatedRun = offlineRun.copyWith(id: assignedRemoteId);
        await harness.associateRemoteId(
          oldLocalId: -888,
          remoteId: assignedRemoteId,
          updatedModel: updatedRun,
        );

        // 5. Verification: Negative ID is cleared, positive remote ID persisted
        final box = await harness.localDataSource.activitiesBox;
        check(box.containsKey('-888')).isFalse();
        check(box.containsKey(assignedRemoteId.toString())).isTrue();

        final postUpload = (await harness.getAllStoredActivities()).first;
        check(postUpload.id).equals(assignedRemoteId);
        check(
          postUpload.id > 0,
        ).isTrue(); // Switches badge from 'Local' to 'Synced'
      },
    );

    test(
      'Scenario 4: Non-Destructive Disconnect Resilience - unlinking preserves all local activities, metrics, and plan',
      () async {
        // [Source: TEST_INFRA.md Scenario 4; F10, F13, F14, F15, F04, F05]
        // 1. Setup: Connected athlete with 5 remote runs and 3 local runs
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final remoteRuns = List.generate(
          5,
          (i) => harness.createRemoteActivityModel(
            id: 6001 + i,
            name: 'Remote $i',
          ),
        );
        final localRuns = List.generate(
          3,
          (i) => harness.createLocalActivityModel(
            id: -(401 + i),
            name: 'Local $i',
          ),
        );
        await harness.executeSmartMerge(remoteRuns);
        await harness.saveActivities(localRuns);

        // Custom demographic parameters set
        await harness.preferencesStorage.saveRestingHr(52);
        await harness.preferencesStorage.saveMaxHr(184);

        // 8 total activities in storage
        check((await harness.getAllStoredActivities()).length).equals(8);

        // 2. Athlete navigates to Settings and initiates Disconnect
        await harness.tokenStorage.clearTokens();

        // 3. Verification: Tokens purged
        check(await harness.tokenStorage.getTokens()).isNull();

        // 4. Verification: All 8 activities remain completely safe in Hive
        final storedAfterDisconnect = await harness.getAllStoredActivities();
        check(storedAfterDisconnect.length).equals(8);
        check(storedAfterDisconnect.where((a) => a.id < 0).length).equals(3);
        check(storedAfterDisconnect.where((a) => a.id > 0).length).equals(5);

        // 5. Verification: Demographic preferences remain completely intact
        final prefs = await harness.preferencesStorage.getPreferences();
        check(prefs.restingHr).equals(52);
        check(prefs.maxHr).equals(184);

        // 6. Verification: Training plan recalculates from all stored runs without error
        final entities = storedAfterDisconnect
            .map((m) => harness.modelToEntity(m, maxHr: prefs.maxHr!))
            .toList();
        final plan = harness.generatePlanUseCase.generate(
          entities,
          userMaxHr: prefs.maxHr!,
          userRestingHr: prefs.restingHr,
        );
        check(plan.days.length).equals(7);
      },
    );

    test(
      'Scenario 5: Resilience Under Error - network failure and rate limits handled safely with retryable data',
      () async {
        // [Source: TEST_INFRA.md Scenario 5; F15, F21, F27]
        // 1. Setup: Connected athlete with 1 local workout (-999)
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final localRun = harness.createLocalActivityModel(
          id: -999,
          name: 'Important Workout Session',
        );
        await harness.saveActivities([localRun]);

        // 2. Upload Attempt 1 encounters Network Outage (SocketException)
        harness.fakeStravaApiClient.simulateNetworkError = true;
        SocketException? networkErr;
        try {
          await harness.fakeStravaApiClient.postActivity({
            'name': localRun.name,
          });
        } on SocketException catch (e) {
          networkErr = e;
        }

        check(networkErr).isNotNull();
        // Activity remains safely in local Hive with negative ID
        var stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(-999);

        // 3. Upload Attempt 2 encounters Strava Rate Limit (HTTP 429)
        harness.fakeStravaApiClient.simulateNetworkError = false;
        harness.fakeStravaApiClient.simulateRateLimit429 = true;
        HttpException? rateLimitErr;
        try {
          await harness.fakeStravaApiClient.postActivity({
            'name': localRun.name,
          });
        } on HttpException catch (e) {
          rateLimitErr = e;
        }

        check(rateLimitErr).isNotNull();
        check(rateLimitErr!.message).contains('Rate limit reached');
        // Activity still remains safely in local Hive with negative ID
        stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(-999);

        // 4. Upload Attempt 3: Network and rate limit recovered -> upload succeeds
        harness.fakeStravaApiClient.simulateRateLimit429 = false;
        final successResponse = await harness.fakeStravaApiClient.postActivity({
          'name': localRun.name,
        });
        final remoteId = successResponse['id'] as int;
        check(remoteId).isGreaterThan(0);

        await harness.associateRemoteId(
          oldLocalId: -999,
          remoteId: remoteId,
          updatedModel: localRun.copyWith(id: remoteId),
        );

        // 5. Verification: Record cleanly transitioned to remote ID
        stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(remoteId);
      },
    );
  });
}
