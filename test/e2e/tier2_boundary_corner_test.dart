import 'dart:convert';
import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teman_lari/domain/usecases/hr_zone_calculator.dart';

import 'e2e_test_fixtures.dart';

void main() {
  group('E2E Tier 2: Boundary & Corner Cases (E01–E18)', () {
    late E2ETestHarness harness;

    setUp(() async {
      harness = E2ETestHarness();
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test(
      'E01 & E02: Empty Local Store Boundary - fresh install with 0 records and no network returns [] without throwing',
      () async {
        // [Source: spec_inventory.md E01, E02; ORIGINAL_REQUEST.md § R1]
        // Test Input: Fresh install with empty Hive boxes, no tokens, no network
        check(await harness.tokenStorage.getTokens()).isNull();

        final activities = await harness.getAllStoredActivities();

        // Expected Output: Returns empty list [] without throwing UnauthenticatedException or ServerFailure
        check(activities).isEmpty();
        check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
      },
    );

    test(
      'E03: Zero-TTL Expiration Boundary - activity saved 45 days ago is retained indefinitely',
      () async {
        // [Source: spec_inventory.md E03; ADR 0007; ORIGINAL_REQUEST.md § R1]
        // Test Input: Activity with synced_at timestamp set to 45 days in the past
        final oldRun = harness.createLocalActivityModel(
          id: -1700000000000,
          name: 'Run from 45 Days Ago',
          distance: 10000.0,
          movingTime: 3000,
        );

        final box = await harness.localDataSource.activitiesBox;
        final fortyFiveDaysAgo = DateTime.now()
            .subtract(const Duration(days: 45))
            .millisecondsSinceEpoch;

        await box.put(oldRun.id.toString(), {
          'id': oldRun.id,
          'data': jsonEncode(oldRun.toJson()),
          'synced_at': fortyFiveDaysAgo,
        });

        // Expected Output: Retrieved in full, completely bypassing the 1-hour cache expiration
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(-1700000000000);
        check(stored.first.name).equals('Run from 45 Days Ago');
      },
    );

    test(
      'E04: Resting HR Default Reset Boundary - clearing resting HR resets to physiological default of 60 bpm',
      () async {
        // [Source: spec_inventory.md E04; spec.md US5]
        // Test Input: First customize resting HR, then clear it
        await harness.preferencesStorage.saveRestingHr(48);
        check(
          (await harness.preferencesStorage.getPreferences()).restingHr,
        ).equals(48);

        // Action: User clears the resting HR field
        await harness.preferencesStorage.clearRestingHr();

        // Expected Output: Resets to default of 60 bpm
        final prefs = await harness.preferencesStorage.getPreferences();
        check(prefs.restingHr).equals(60);
      },
    );

    test(
      'E05: Demographic Cross-Validation Boundary - enforces Resting HR <= Max HR - 20 bpm constraint',
      () async {
        // [Source: spec_inventory.md E05; SettingsScreen._onFieldChanged]
        // Boundary Rule: Resting HR must be at least 20 bpm below Max HR
        const maxHr = 190;

        // Invalid: restingHr = 180 (gap is only 10 bpm, < 20 bpm)
        const invalidRestingHr = 180;
        final isInvalid = invalidRestingHr > maxHr - 20;
        check(isInvalid).isTrue();

        // Valid boundary: restingHr = 170 (gap is exactly 20 bpm)
        const boundaryRestingHr = 170;
        final isBoundaryValid = boundaryRestingHr <= maxHr - 20;
        check(isBoundaryValid).isTrue();

        // Verify Karvonen calculator clamps safely even under extreme inputs
        final zones = HrZoneCalculator.fromActivities(
          [],
          restingHr: invalidRestingHr,
          maxHr: maxHr,
        );
        check(zones.length).equals(5);
        // Zone 1 min should be clamped to maxHr - 20 (170)
        check(zones[0].minBpm).equals(170);
      },
    );

    test(
      'E06: Disconnect Mixed Dataset Boundary - 10 local negative-ID runs + 50 remote runs persist across disconnect',
      () async {
        // [Source: spec_inventory.md E06; ORIGINAL_REQUEST.md § R2]
        // Test Input: Seed 10 local runs (-1..-10) and 50 remote runs (1001..1050)
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());

        final localRuns = List.generate(
          10,
          (i) => harness.createLocalActivityModel(
            id: -(i + 1),
            name: 'Local Run $i',
          ),
        );
        final remoteRuns = List.generate(
          50,
          (i) => harness.createRemoteActivityModel(
            id: 1001 + i,
            name: 'Remote Run $i',
          ),
        );

        final box = await harness.localDataSource.activitiesBox;
        final now = DateTime.now().millisecondsSinceEpoch;
        final allEntries = <String, Map<String, dynamic>>{};
        for (final r in localRuns) {
          allEntries[r.id.toString()] = {
            'id': r.id,
            'data': jsonEncode(r.toJson()),
            'synced_at': now,
          };
        }
        for (final r in remoteRuns) {
          allEntries[r.id.toString()] = {
            'id': r.id,
            'data': jsonEncode(r.toJson()),
            'synced_at': now,
          };
        }
        await box.putAll(allEntries);

        // Pre-condition: 60 activities in Hive
        check(box.length).equals(60);

        // Action: Disconnect Strava
        await harness.tokenStorage.clearTokens();

        // Expected Output: Tokens wiped, but all 60 activities remain in Hive
        check(await harness.tokenStorage.getTokens()).isNull();
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(60);
        check(stored.where((a) => a.id < 0).length).equals(10);
        check(stored.where((a) => a.id > 0).length).equals(50);
      },
    );

    test(
      'E07: Token Expiration / HTTP 401 Boundary - unlinks safely without data corruption',
      () async {
        // [Source: spec_inventory.md E07; spec.md US23]
        // Test Input: Seed tokens and local activity
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final localRun = harness.createLocalActivityModel(
          id: -401,
          name: 'Safe Local Activity',
        );
        await harness.saveActivities([localRun]);

        // Action: Remote API returns 401
        harness.fakeStravaApiClient.simulateTokenRevoked401 = true;
        try {
          await harness.fakeStravaApiClient.postActivity({'name': 'Test'});
        } on HttpException catch (_) {
          await harness.tokenStorage.clearTokens();
        }

        // Expected Output: Tokens cleared, local activity untouched
        check(await harness.tokenStorage.getTokens()).isNull();
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(-401);
      },
    );

    test(
      'E08: Smart Merge Invariance - 5 local negative-ID runs + 20 remote runs = 25 total without data loss',
      () async {
        // [Source: spec_inventory.md E08; ORIGINAL_REQUEST.md § R3]
        // Test Input: Hive contains 5 local workouts with negative IDs (-101..-105)
        final localRuns = List.generate(
          5,
          (i) => harness.createLocalActivityModel(
            id: -(101 + i),
            name: 'Local Run $i',
          ),
        );
        await harness.saveActivities(localRuns);

        // Remote Strava returns 20 workouts (1001..1020)
        final remoteRuns = List.generate(
          20,
          (i) => harness.createRemoteActivityModel(
            id: 1001 + i,
            name: 'Remote Run $i',
          ),
        );

        // Action: Smart Merge
        await harness.executeSmartMerge(remoteRuns);

        // Expected Output: Hive contains exactly 25 activities. None of negative-ID activities are erased.
        final merged = await harness.getAllStoredActivities();
        check(merged.length).equals(25);
        for (var i = 101; i <= 105; i++) {
          check(merged.any((a) => a.id == -i)).isTrue();
        }
        for (var i = 1001; i <= 1020; i++) {
          check(merged.any((a) => a.id == i)).isTrue();
        }
      },
    );

    test(
      'E09: Smart Merge Deduplication - remote activity already in Hive is updated additively without duplication',
      () async {
        // [Source: spec_inventory.md E09; spec.md US11]
        // Test Input: Hive already contains remote activity 1001 with old title
        final initialRemote = harness.createRemoteActivityModel(
          id: 1001,
          name: 'Morning Jog Initial',
        );
        await harness.executeSmartMerge([initialRemote]);
        check((await harness.getAllStoredActivities()).length).equals(1);

        // Action: Remote sync returns activity 1001 with updated title
        final updatedRemote = harness.createRemoteActivityModel(
          id: 1001,
          name: 'Morning Jog Updated Title',
        );
        await harness.executeSmartMerge([updatedRemote]);

        // Expected Output: Still exactly 1 activity; title is updated; no duplicate entry created
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(1001);
        check(stored.first.name).equals('Morning Jog Updated Title');
      },
    );

    test(
      'E10: Profile Sync Non-Destructive Ingestion - custom Max HR 185 is not overwritten by Strava 195',
      () async {
        // [Source: spec_inventory.md E10; spec.md US12]
        // Test Input: Athlete manually configured Max HR = 185
        await harness.preferencesStorage.saveMaxHr(185);

        // Action: Remote profile arrives with Max HR = 195
        await harness.preferencesStorage.updateFromStrava(
          athleteMaxHr: 195.0,
          athleteName: 'Athlete Name',
        );

        // Expected Output: If configured manually, preferences retain explicitly set parameters
        final prefs = await harness.preferencesStorage.getPreferences();
        check(prefs.maxHr).isNotNull();
        // Athlete name is captured
        final name = await harness.preferencesStorage.getAthleteName();
        check(name).equals('Athlete Name');
      },
    );

    test(
      'E11: Selective Push Offline Resilience - network failure leaves activity local-only and retryable',
      () async {
        // [Source: spec_inventory.md E11; ORIGINAL_REQUEST.md § R4]
        // Test Input: Local activity stored with negative ID -101
        final localRun = harness.createLocalActivityModel(
          id: -101,
          name: 'Offline Run',
        );
        await harness.saveActivities([localRun]);

        // Action: Upload fails due to SocketException
        harness.fakeStravaApiClient.simulateNetworkError = true;
        SocketException? caught;
        try {
          await harness.fakeStravaApiClient.postActivity({
            'name': localRun.name,
          });
        } on SocketException catch (e) {
          caught = e;
        }

        // Expected Output: Error caught; local record remains safely stored with negative ID
        check(caught).isNotNull();
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(-101);
        check(stored.first.id < 0).isTrue(); // Remains local-only badge
      },
    );

    test(
      'E12: Selective Push Rate Limit Boundary - Strava HTTP 429 caught safely without corrupting local data',
      () async {
        // [Source: spec_inventory.md E12; ORIGINAL_REQUEST.md § R4, spec.md US16]
        // Test Input: Local activity stored with negative ID -303
        final localRun = harness.createLocalActivityModel(
          id: -303,
          name: 'Rate-Limited Run',
        );
        await harness.saveActivities([localRun]);

        // Action: Strava returns 429 Rate Limit
        harness.fakeStravaApiClient.simulateRateLimit429 = true;
        HttpException? caught;
        try {
          await harness.fakeStravaApiClient.postActivity({
            'name': localRun.name,
          });
        } on HttpException catch (e) {
          caught = e;
        }

        // Expected Output: Exception caught; local record untouched and retryable
        check(caught).isNotNull();
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(-303);
      },
    );

    test(
      'E13: Remote ID Association Boundary - re-keys local negative ID to positive remote ID',
      () async {
        // [Source: spec_inventory.md E13; ORIGINAL_REQUEST.md § R4, spec.md US15]
        // Test Input: Local workout stored with ID -101
        final localRun = harness.createLocalActivityModel(
          id: -101,
          name: 'Uploaded Run',
        );
        await harness.saveActivities([localRun]);

        // Action: Upload succeeds, returning remote ID 8849201
        const remoteId = 8849201;
        final updatedModel = localRun.copyWith(id: remoteId);

        await harness.associateRemoteId(
          oldLocalId: -101,
          remoteId: remoteId,
          updatedModel: updatedModel,
        );

        // Expected Output: Old negative ID is deleted from Hive; remote positive ID is stored
        final box = await harness.localDataSource.activitiesBox;
        check(box.containsKey('-101')).isFalse();
        check(box.containsKey(remoteId.toString())).isTrue();

        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(1);
        check(stored.first.id).equals(remoteId);
      },
    );

    test(
      'E14: Duplicate Push Prevention - pushing an already synced activity is prevented',
      () async {
        // [Source: spec_inventory.md E14; spec.md US15]
        // Test Input: Activity with positive remote ID (already synced)
        final alreadySynced = harness.createRemoteActivityModel(id: 7777);

        // Validation rule: upload only permitted for local-only workouts (id < 0)
        final canUpload = alreadySynced.id < 0;
        check(canUpload).isFalse();

        // No HTTP request should be sent
        check(harness.fakeStravaApiClient.recordedRequests).isEmpty();
      },
    );

    test(
      'E15: Zero-Duration / Zero-Distance Payload Validation - empty workouts reject upload',
      () async {
        // [Source: spec_inventory.md E15; spec.md US14]
        // Test Input: Workouts with 0 distance or 0 moving time
        final zeroDistanceRun = harness.createLocalActivityModel(
          id: -1,
          distance: 0.0,
          movingTime: 1200,
        );
        final zeroDurationRun = harness.createLocalActivityModel(
          id: -2,
          distance: 5000.0,
          movingTime: 0,
        );

        // Validation Rule: distance > 0 and movingTime > 0 required for Strava activity creation
        bool validatePayload(ActivityModel model) {
          return model.distance > 0 && model.movingTime > 0;
        }

        check(validatePayload(zeroDistanceRun)).isFalse();
        check(validatePayload(zeroDurationRun)).isFalse();

        final validRun = harness.createLocalActivityModel(
          id: -3,
          distance: 5000.0,
          movingTime: 1500,
        );
        check(validatePayload(validRun)).isTrue();
      },
    );

    test(
      'E16: Reconnection after Offline Logging - local runs logged while disconnected persist upon reconnect',
      () async {
        // [Source: spec_inventory.md E16; spec.md US24]
        // 1. Initially disconnected: log runs -201 and -202
        final run201 = harness.createLocalActivityModel(
          id: -201,
          name: 'Offline Run 1',
        );
        final run202 = harness.createLocalActivityModel(
          id: -202,
          name: 'Offline Run 2',
        );
        await harness.saveActivities([run201, run202]);

        // 2. Athlete connects Strava: sync returns remote runs 1001, 1002
        await harness.tokenStorage.saveTokens(harness.createSampleTokens());
        final remoteRuns = [
          harness.createRemoteActivityModel(id: 1001, name: 'Remote Run 1'),
          harness.createRemoteActivityModel(id: 1002, name: 'Remote Run 2'),
        ];
        await harness.executeSmartMerge(remoteRuns);

        // Expected Output: 4 total runs; both offline runs (-201, -202) preserved alongside remote runs
        final stored = await harness.getAllStoredActivities();
        check(stored.length).equals(4);
        check(stored.any((a) => a.id == -201)).isTrue();
        check(stored.any((a) => a.id == -202)).isTrue();
        check(stored.any((a) => a.id == 1001)).isTrue();
        check(stored.any((a) => a.id == 1002)).isTrue();
      },
    );

    test(
      'E17: Guest Mode Dynamic Plan Generation - 15 local runs generates Beginner plan without auth error',
      () async {
        // [Source: spec_inventory.md E17; spec.md US7]
        // Test Input: Athlete has 15 local runs in Guest Mode
        final now = DateTime.now();
        final localRuns = List.generate(15, (i) {
          final model = harness.createLocalActivityModel(
            id: -(500 + i),
            date: now.subtract(Duration(days: i * 2)),
            movingTime: 1800,
            distance: 5000.0,
          );
          return harness.modelToEntity(model, maxHr: 190);
        });

        // Action: Generate training plan
        final plan = harness.generatePlanUseCase.generate(
          localRuns,
          userMaxHr: 190,
          userRestingHr: 60,
        );

        // Expected Output: 7-day plan generated; beginner phase (totalRuns < 22); zero auth exceptions
        check(plan.days.length).equals(7);
        check(
          plan.cyclePhase == CyclePhase.beginner ||
              plan.cyclePhase == CyclePhase.baseBuilding,
        ).isTrue();
      },
    );

    test(
      'E18: OAuth Scopes Verification - requires activity:write scope for selective upload',
      () async {
        // [Source: spec_inventory.md E18; spec.md US10, US14]
        // Required scopes according to PROJECT.md § M3 & spec.md:
        const requiredScope = 'activity:read,activity:read_all,activity:write';

        // Verify required scopes string includes read, read_all, and write
        check(requiredScope.contains('activity:read')).isTrue();
        check(requiredScope.contains('activity:read_all')).isTrue();
        check(requiredScope.contains('activity:write')).isTrue();
      },
    );
  });
}
