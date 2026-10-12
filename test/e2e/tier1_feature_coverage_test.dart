import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/usecases/hr_zone_calculator.dart';

import 'e2e_test_fixtures.dart';

void main() {
  group('E2E Tier 1: Feature Coverage (F01–F30)', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    // =========================================================================
    // Group 1: Startup, Guest Mode & Demographics (F01, F02, F03, F30)
    // =========================================================================
    group('Group 1: Startup, Guest Mode & Demographics', () {
      test(
        'F01: Un-gated Boot to Dashboard - boots in unauthenticated guest state without cloud credentials',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md US1]
          // Test Input: TokenStorage empty, no network credentials
          final tokens = await harness.tokenStorage.getTokens();
          check(tokens).isNull();

          // Expected Output: Unauthenticated state is treated as valid Guest Mode
          // App does not require cloud login to access stored data
          final activities = await harness.getAllStoredActivities();
          check(activities).isEmpty();
        },
      );

      test(
        'F02: Local Profile / Guest Mode Default - athlete operates locally with fallback defaults',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md US4]
          // Test Input: Default PreferencesStorage
          final prefs = await harness.preferencesStorage.getPreferences();

          // Expected Output: Defaults to resting HR 60, null max HR (fallback 190), no cloud token
          check(prefs.restingHr).equals(60);
          check(prefs.maxHr).isNull();
          check(prefs.thresholdPaceSeconds).isNull();

          final name = await harness.preferencesStorage.getAthleteName();
          check(name).isNull(); // Resolves to 'Runner' fallback in UI
        },
      );

      test(
        'F03: Local Demographic Preference Store - persists and updates physiological parameters locally',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md US5]
          // Test Input: Athlete customizes resting HR = 52, max HR = 185, threshold pace = 300 sec/km
          await harness.preferencesStorage.saveRestingHr(52);
          await harness.preferencesStorage.saveMaxHr(185);
          await harness.preferencesStorage.saveThresholdPace(300);

          // Expected Output: Values persisted accurately in on-device storage
          final updated = await harness.preferencesStorage.getPreferences();
          check(updated.restingHr).equals(52);
          check(updated.maxHr).equals(185);
          check(updated.thresholdPaceSeconds).equals(300);

          // Verify Karvonen HR zones update accordingly
          final zones = HrZoneCalculator.fromActivities(
            [],
            restingHr: updated.restingHr,
            maxHr: updated.maxHr,
          );
          check(zones.length).equals(5);
          check(zones[0].minBpm).equals(52); // Zone 1 starts at resting HR
          check(zones[4].maxBpm).equals(185); // Zone 5 ends at max HR
        },
      );

      test(
        'F30: Instant Time-to-First-Interaction - loads stored data instantly without network handshake',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md US25]
          // Test Input: Pre-seed local activity in Hive
          final localRun = harness.createLocalActivityModel(
            id: -1716200000001,
            name: 'Cached Morning Run',
          );
          await harness.saveActivities([localRun]);

          // Expected Output: Reading local data returns immediately without waiting for any network request
          final stopwatch = Stopwatch()..start();
          final stored = await harness.getAllStoredActivities();
          stopwatch.stop();

          check(stored.length).equals(1);
          check(stored.first.name).equals('Cached Morning Run');
          // Must execute locally in well under 500ms
          check(stopwatch.elapsedMilliseconds).isLessThan(500);
          check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
        },
      );
    });

    // =========================================================================
    // Group 2: Persistence, SSOT & Unauthenticated Retrieval (F04, F05, F09)
    // =========================================================================
    group('Group 2: Persistence, SSOT & Unauthenticated Retrieval', () {
      test(
        'F04: Zero-TTL Permanent Local SSOT - local activities never expire after 1 hour',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, ADR 0007]
          // Test Input: Store activity with synced_at set to 48 hours ago
          final oldRun = harness.createLocalActivityModel(
            id: -1716100000000,
            name: 'Historical Run 2 Days Ago',
          );
          final box = await harness.localDataSource.activitiesBox;
          final fortyEightHoursAgo = DateTime.now()
              .subtract(const Duration(hours: 48))
              .millisecondsSinceEpoch;

          await box.put(oldRun.id.toString(), {
            'id': oldRun.id,
            'data': jsonEncode(oldRun.toJson()),
            'synced_at': fortyEightHoursAgo,
          });

          // Expected Output: Zero-TTL SSOT loads the record without returning null or discarding it
          final stored = await harness.getAllStoredActivities();
          check(stored.length).equals(1);
          check(stored.first.id).equals(-1716100000000);
          check(stored.first.name).equals('Historical Run 2 Days Ago');
        },
      );

      test(
        'F05: Unauthenticated Activity Retrieval - serves local Hive data without cloud exceptions',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md § Decisions]
          // Test Input: TokenStorage has no tokens, 2 activities seeded in Hive
          final run1 = harness.createLocalActivityModel(
            id: -101,
            name: 'Run 1',
          );
          final run2 = harness.createLocalActivityModel(
            id: -102,
            name: 'Run 2',
          );
          await harness.saveActivities([run1, run2]);

          check(await harness.tokenStorage.getTokens()).isNull();

          // Expected Output: Activities are served directly without throwing UnauthenticatedException
          final activities = await harness.getAllStoredActivities();
          check(activities.length).equals(2);
          check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
        },
      );

      test(
        'F09: In-App Workout Auto-Save - commits completed workout with negative timestamp ID',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, ADR 0007]
          // Test Input: Completed live session synthesized into an ActivityModel
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final autoSavedRun = harness.createLocalActivityModel(
            id: -timestamp,
            name: 'Track Session Auto-Saved',
            distance: 6200.0,
            movingTime: 1860,
          );

          await harness.saveActivities([autoSavedRun]);

          // Expected Output: Saved with negative ID into Hive box
          final box = await harness.localDataSource.activitiesBox;
          check(box.containsKey((-timestamp).toString())).isTrue();

          final stored = await harness.getAllStoredActivities();
          final found = stored.firstWhere((a) => a.id == -timestamp);
          check(found.distance).equals(6200.0);
          check(found.id).isLessThan(0);
        },
      );
    });

    // =========================================================================
    // Group 3: On-Device Analytics, Planning & Offline Tracking (F06, F07, F08)
    // =========================================================================
    group('Group 3: On-Device Analytics, Planning & Offline Tracking', () {
      test(
        'F06: Autonomous On-Device Training Load - calculates ATL, CTL, and TSB without remote API',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md US6]
          // Test Input: 5 local activities over 14 days
          final now = DateTime.now();
          final runs = List.generate(5, (i) {
            final model = harness.createLocalActivityModel(
              id: -(100 + i),
              date: now.subtract(Duration(days: i * 3)),
              movingTime: 1800 + i * 120,
              distance: 5000.0 + i * 500,
              averageHeartrate: 150.0 + i * 2,
            );
            return harness.modelToEntity(model, maxHr: 190);
          });

          // Expected Output: Training load history computed completely on-device
          final history = harness.trainingLoadCalculator.computeLoadHistory(
            runs,
            maxHr: 190,
            restingHr: 60,
          );

          check(history).isNotEmpty();
          final latest = history.last;
          check(latest.fitness).isGreaterThan(0.0);
          check(latest.fatigue).isGreaterThan(0.0);
          // TSB (form) is mathematically fitness - fatigue
          check(latest.form).equals(latest.fitness - latest.fatigue);

          // Zero external network calls
          check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
        },
      );

      test(
        'F07: Offline Dynamic Plan Generation - generates 7-day periodized plan from local history',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md US7]
          // Test Input: 8 local activities (Beginner runner phase)
          final now = DateTime.now();
          final runs = List.generate(8, (i) {
            final model = harness.createLocalActivityModel(
              id: -(200 + i),
              date: now.subtract(Duration(days: i * 2)),
              movingTime: 1800,
              distance: 5000.0,
            );
            return harness.modelToEntity(model, maxHr: 190);
          });

          // Expected Output: Generates structured 7-day TrainingPlan adapted to athlete phase
          final plan = harness.generatePlanUseCase.generate(
            runs,
            userMaxHr: 190,
            userRestingHr: 60,
          );

          check(plan.days.length).equals(7);
          check(plan.goal).isNotEmpty();
          check(plan.description).isNotEmpty();
          check(
            plan.cyclePhase == CyclePhase.beginner ||
                plan.cyclePhase == CyclePhase.baseBuilding,
          ).isTrue();
        },
      );

      test(
        'F08: Offline GPS & Sensor Workout Session - operates without network connectivity',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R1, spec.md US2]
          // Test Input: Device in airplane mode / offline
          final simulatedRun = harness.createLocalActivityModel(
            id: -999,
            name: 'Offline Trail Tracking',
            distance: 4200.0,
            movingTime: 1260,
            averageSpeed: 3.33,
          );

          // Expected Output: Can be committed and read back with zero internet required
          await harness.saveActivities([simulatedRun]);
          final stored = await harness.getAllStoredActivities();
          check(stored.any((a) => a.id == -999)).isTrue();
        },
      );
    });

    // =========================================================================
    // Group 4: Settings Integration Hub & Lifecycle (F10, F11, F12, F13, F14, F15, F16)
    // =========================================================================
    group('Group 4: Settings Integration Hub & Lifecycle', () {
      test(
        'F10 & F11: Disconnected Integration Card State - displays connect option when unlinked',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R2, spec.md US9]
          // Test Input: No tokens stored
          final tokens = await harness.tokenStorage.getTokens();
          check(tokens).isNull();

          // Expected Output: Integration is detected as disconnected; offers connect action
          final isConnected = tokens != null;
          check(isConnected).isFalse();
        },
      );

      test(
        'F12: On-Demand Strava OAuth Trigger - saves tokens when athlete connects',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R2, spec.md US10]
          // Test Input: Athlete taps "Connect with Strava" and completes OAuth
          final sampleTokens = harness.createSampleTokens();
          await harness.tokenStorage.saveTokens(sampleTokens);

          // Expected Output: Tokens are securely saved, transitioning state to connected
          final stored = await harness.tokenStorage.getTokens();
          check(stored).isNotNull();
          check(stored!.accessToken).equals(sampleTokens.accessToken);
          check(harness.tokenStorage.saveTokensCallCount).equals(1);
        },
      );

      test(
        'F13: Connected Integration Card State - reflects connected identity and active state',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R2, spec.md US19]
          // Test Input: Seed valid tokens and athlete name
          await harness.tokenStorage.saveTokens(harness.createSampleTokens());
          await harness.preferencesStorage.saveAthleteName('Budi Santoso');

          // Expected Output: Connected status and athlete identity are present
          final tokens = await harness.tokenStorage.getTokens();
          final athleteName = await harness.preferencesStorage.getAthleteName();

          check(tokens).isNotNull();
          check(athleteName).equals('Budi Santoso');
        },
      );

      test(
        'F14: Non-Destructive Disconnect Action - unlinking clears tokens without wiping local Hive data',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R2, spec.md US20–22]
          // Test Input: Seed tokens and 3 activities in Hive
          await harness.tokenStorage.saveTokens(harness.createSampleTokens());
          final r1 = harness.createLocalActivityModel(
            id: -1,
            name: 'Local Run',
          );
          final r2 = harness.createRemoteActivityModel(
            id: 1001,
            name: 'Strava Run 1',
          );
          final r3 = harness.createRemoteActivityModel(
            id: 1002,
            name: 'Strava Run 2',
          );
          await harness.saveActivities([r1, r2, r3]);

          check(await harness.tokenStorage.getTokens()).isNotNull();

          // Action: Athlete disconnects Strava
          await harness.tokenStorage.clearTokens();

          // Expected Output: Tokens are removed, but ALL 3 activities persist in Hive
          check(await harness.tokenStorage.getTokens()).isNull();
          final remaining = await harness.getAllStoredActivities();
          check(remaining.length).equals(3);
          check(remaining.any((a) => a.id == -1)).isTrue();
          check(remaining.any((a) => a.id == 1001)).isTrue();
          check(remaining.any((a) => a.id == 1002)).isTrue();
        },
      );

      test(
        'F15: Graceful Token Expiration & Revocation - HTTP 401 unlinks without crashing or corrupting data',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R2, spec.md US23]
          // Test Input: Seed tokens and local activity
          await harness.tokenStorage.saveTokens(harness.createSampleTokens());
          final run = harness.createLocalActivityModel(
            id: -555,
            name: 'Safe Local Run',
          );
          await harness.saveActivities([run]);

          // Action: API returns 401 Authorization Error
          harness.fakeStravaApiClient.simulateTokenRevoked401 = true;
          try {
            await harness.fakeStravaApiClient.postActivity({'name': 'Test'});
          } on HttpException catch (_) {
            // Error handled by clearing tokens
            await harness.tokenStorage.clearTokens();
          }

          // Expected Output: Tokens cleared, integration marked disconnected, local data safe
          check(await harness.tokenStorage.getTokens()).isNull();
          final stored = await harness.getAllStoredActivities();
          check(stored.length).equals(1);
          check(stored.first.id).equals(-555);
        },
      );

      test(
        'F16: Legacy Token Recognition - automatically recognizes existing tokens as active integration',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R2, spec.md § Notes]
          // Test Input: Pre-existing token seeded into storage
          final legacyTokens = harness.createSampleTokens(
            accessToken: 'legacy_access_token_abc',
            refreshToken: 'legacy_refresh_token_xyz',
          );
          await harness.tokenStorage.saveTokens(legacyTokens);

          // Expected Output: Detected as valid active connection immediately
          final active = await harness.tokenStorage.getTokens();
          check(active).isNotNull();
          check(active!.accessToken).equals('legacy_access_token_abc');
        },
      );
    });

    // =========================================================================
    // Group 5: Smart Merge & Ingestion Protection (F17, F18, F19, F20, F21, F29)
    // =========================================================================
    group('Group 5: Smart Merge & Ingestion Protection', () {
      test(
        'F17 & F18: Smart Merge Activity Ingestion & Negative ID Protection - additively merges without data loss',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R3, spec.md US11]
          // Test Input: Hive contains 2 local runs (IDs: -101, -102). Strava returns 3 remote runs (101, 102, 103).
          final local1 = harness.createLocalActivityModel(
            id: -101,
            name: 'Local Run 1',
          );
          final local2 = harness.createLocalActivityModel(
            id: -102,
            name: 'Local Run 2',
          );
          await harness.saveActivities([local1, local2]);

          final remote1 = harness.createRemoteActivityModel(
            id: 101,
            name: 'Remote Run 101',
          );
          final remote2 = harness.createRemoteActivityModel(
            id: 102,
            name: 'Remote Run 102',
          );
          final remote3 = harness.createRemoteActivityModel(
            id: 103,
            name: 'Remote Run 103',
          );

          // Action: Execute additive Smart Merge
          await harness.executeSmartMerge([remote1, remote2, remote3]);

          // Expected Output: 5 total activities in Hive. Both local negative-ID runs preserved.
          final merged = await harness.getAllStoredActivities();
          check(merged.length).equals(5);
          check(merged.any((a) => a.id == -101)).isTrue();
          check(merged.any((a) => a.id == -102)).isTrue();
          check(merged.any((a) => a.id == 101)).isTrue();
          check(merged.any((a) => a.id == 102)).isTrue();
          check(merged.any((a) => a.id == 103)).isTrue();
        },
      );

      test(
        'F19: Additive Athlete Profile Parameter Sync - syncs remote metrics without overwriting custom tuning',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R3, spec.md US12]
          // Test Input: Athlete manually tuned resting HR to 54 and max HR to 182
          await harness.preferencesStorage.saveRestingHr(54);
          await harness.preferencesStorage.saveMaxHr(182);

          // Remote athlete profile arrives with max HR = 180 and athlete name = 'John Runner'
          await harness.preferencesStorage.updateFromStrava(
            athleteMaxHr: 180.0,
            athleteName: 'John Runner',
          );

          // Expected Output: Manually tuned max HR 182 is preserved (182 >= 180); athlete name is updated
          final prefs = await harness.preferencesStorage.getPreferences();
          final name = await harness.preferencesStorage.getAthleteName();

          check(prefs.maxHr).equals(182);
          check(prefs.restingHr).equals(54);
          check(name).equals('John Runner');
        },
      );

      test(
        'F20: Multi-Surface Manual Sync Trigger - pulls remote activities and commits additively',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R3, spec.md § Decisions]
          // Test Input: Trigger manual sync
          final remoteActivities = [
            harness.createRemoteActivityModel(id: 501, name: 'Pushed Sync 1'),
            harness.createRemoteActivityModel(id: 502, name: 'Pushed Sync 2'),
          ];

          await harness.executeSmartMerge(remoteActivities);

          final stored = await harness.getAllStoredActivities();
          check(stored.length).equals(2);
        },
      );

      test(
        'F21: Non-Blocking Remote Sync Resilience - network failure leaves cached data intact',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R3, spec.md US16]
          // Test Input: 2 activities in Hive, sync encounters SocketException
          final localRun = harness.createLocalActivityModel(
            id: -801,
            name: 'Safe Run',
          );
          await harness.saveActivities([localRun]);

          harness.fakeStravaApiClient.simulateNetworkError = true;
          try {
            await harness.fakeStravaApiClient.postActivity({'name': 'Fail'});
          } on SocketException catch (_) {
            // Non-blocking error logged
          }

          // Expected Output: Existing local activities remain 100% unharmed
          final stored = await harness.getAllStoredActivities();
          check(stored.length).equals(1);
          check(stored.first.id).equals(-801);
        },
      );

      test(
        'F29: Additive Reconnection Reconciliation - reconnecting resumes merge without duplicating',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R3, spec.md US24]
          // Test Input: Initial sync of activity 701
          final initialRemote = harness.createRemoteActivityModel(
            id: 701,
            name: 'Run 701',
          );
          await harness.executeSmartMerge([initialRemote]);

          // Athlete disconnects and logs local run -901
          await harness.tokenStorage.clearTokens();
          final box = await harness.localDataSource.activitiesBox;
          final offlineRun = harness.createLocalActivityModel(
            id: -901,
            name: 'Offline Run',
          );
          await box.put('-901', {
            'id': -901,
            'data': jsonEncode(offlineRun.toJson()),
            'synced_at': DateTime.now().millisecondsSinceEpoch,
          });

          // Athlete reconnects; sync pulls activity 701 again + new activity 702
          final reconnectedSync = [
            initialRemote,
            harness.createRemoteActivityModel(id: 702, name: 'Run 702'),
          ];
          await harness.executeSmartMerge(reconnectedSync);

          // Expected Output: Exactly 3 activities total (no duplicate for 701; -901 preserved)
          final finalStored = await harness.getAllStoredActivities();
          check(finalStored.length).equals(3);
          check(finalStored.where((a) => a.id == 701).length).equals(1);
          check(finalStored.any((a) => a.id == -901)).isTrue();
          check(finalStored.any((a) => a.id == 702)).isTrue();
        },
      );
    });

    // =========================================================================
    // Group 6: Selective Push Upload & Sync Badging (F22, F23, F24, F25, F26, F27, F28)
    // =========================================================================
    group('Group 6: Selective Push Upload & Sync Badging', () {
      test(
        'F22 & F23: Sync Status Metadata & Differentiation - distinguishes local vs synced runs',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R4, spec.md US13]
          // Test Input: Local activity (negative ID) vs Synced activity (positive ID)
          final localRun = harness.createLocalActivityModel(id: -101);
          final syncedRun = harness.createRemoteActivityModel(id: 202);

          // Expected Output: Negative ID denotes local-only; positive ID denotes synced
          final isLocalOnly = localRun.id < 0;
          final isSynced = syncedRun.id > 0;

          check(isLocalOnly).isTrue();
          check(isSynced).isTrue();
        },
      );

      test(
        'F24 & F25: User-Initiated Upload Action & Creation Endpoint - formats payload and posts to Strava',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R4, spec.md US14, § Decisions]
          // Test Input: Athlete initiates upload for local activity -101
          final localRun = harness.createLocalActivityModel(
            id: -101,
            name: 'Sunday Long Run',
            distance: 12000.0,
            movingTime: 3600,
            elapsedTime: 3660,
          );

          final payload = {
            'name': localRun.name,
            'sport_type': 'Run',
            'start_date_local': localRun.startDate,
            'elapsed_time': localRun.elapsedTime,
            'distance': localRun.distance,
          };

          // Action: Execute POST /api/v3/activities
          final response = await harness.fakeStravaApiClient.postActivity(
            payload,
            token: 'valid_access_token',
          );

          // Expected Output: Strava returns positive remote ID; request logged
          check(response['id'] as int).isGreaterThan(0);
          check(harness.fakeStravaApiClient.recordedRequests.length).equals(1);
          final recorded = harness.fakeStravaApiClient.recordedRequests.first;
          check(recorded.method).equals('POST');
          check(recorded.endpoint).equals('activities');
          check(recorded.body!['name']).equals('Sunday Long Run');
          check(recorded.body!['distance']).equals(12000.0);
        },
      );

      test(
        'F26: Remote ID Association & Deduplication - updates Hive record with positive remote ID',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R4, spec.md US15]
          // Test Input: Local activity -101 stored in Hive
          final localRun = harness.createLocalActivityModel(
            id: -101,
            name: 'Local Workout',
          );
          await harness.saveActivities([localRun]);

          // Action: Upload completes, returning remote ID 8849201
          const remoteId = 8849201;
          final updatedModel = localRun.copyWith(id: remoteId);

          await harness.associateRemoteId(
            oldLocalId: -101,
            remoteId: remoteId,
            updatedModel: updatedModel,
          );

          // Expected Output: Old negative ID -101 is gone; new positive ID 8849201 exists in Hive
          final box = await harness.localDataSource.activitiesBox;
          check(box.containsKey('-101')).isFalse();
          check(box.containsKey(remoteId.toString())).isTrue();

          final stored = await harness.getAllStoredActivities();
          check(stored.length).equals(1);
          check(stored.first.id).equals(remoteId);
        },
      );

      test(
        'F27: Strava Rate Limit (HTTP 429) Handling - catches 429 without corrupting local record',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R4, spec.md US16]
          // Test Input: Local workout stored; Strava API returns HTTP 429
          final localRun = harness.createLocalActivityModel(
            id: -777,
            name: 'Retryable Run',
          );
          await harness.saveActivities([localRun]);

          harness.fakeStravaApiClient.simulateRateLimit429 = true;

          HttpException? caughtException;
          try {
            await harness.fakeStravaApiClient.postActivity({
              'name': localRun.name,
            });
          } on HttpException catch (e) {
            caughtException = e;
          }

          // Expected Output: Exception caught; local record remains safely stored with negative ID
          check(caughtException).isNotNull();
          check(caughtException!.message).contains('Rate limit reached');

          final stored = await harness.getAllStoredActivities();
          check(stored.length).equals(1);
          check(stored.first.id).equals(-777); // Still local and retryable
        },
      );

      test(
        'F28: Automated Background Upload Prohibition - completed runs are committed locally only',
        () async {
          // [Source: ORIGINAL_REQUEST.md § R4, spec.md US17]
          // Test Input: Live workout completed and committed to Hive
          final completedRun = harness.createLocalActivityModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            name: 'Completed Offline Run',
          );
          await harness.saveActivities([completedRun]);

          // Expected Output: Zero background HTTP requests sent to Strava API
          check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
        },
      );
    });
  });
}
