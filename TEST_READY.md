# TEST_READY: Teman Lari Decoupled Identity & Optional Strava Integration

**Status**: READY  
**Test Suite Path**: `test/e2e/`  
**Master Entrypoint**: `test/e2e/e2e_suite_test.dart`  
**Quality Gate**: 100% PASS (`flutter test`), 0 warnings (`dart analyze`), 100% clean formatting (`dart format`)  
**Timestamp**: 2026-10-11T17:18:00Z  

---

## 1. Test Suite Architecture

The comprehensive, opaque-box E2E test suite is implemented according to `TEST_INFRA.md`, `PROJECT.md`, `ORIGINAL_REQUEST.md`, and `spec.md` across 4 rigorous tiers:

| Tier | Test File | Test Count | Scope & Focus | Status |
|---|---|:---:|---|:---:|
| Shared Harness | `test/e2e/e2e_test_fixtures.dart` | — | Isolated Hive temp sandboxing, FakeTokenStorage, FakeStravaApiClient, Smart Merge runner, model & entity fixture factories | READY |
| Tier 1 | `test/e2e/tier1_feature_coverage_test.dart` | 26 | Complete feature coverage for F01 through F30 (Startup, Guest Mode, SSOT, Repository, Demographics, Analytics, Integrations, Smart Merge, Selective Push) | PASS (26/26) |
| Tier 2 | `test/e2e/tier2_boundary_corner_test.dart` | 17 | Boundary value analysis (BVA) & Corner cases E01–E18 (empty stores, zero-TTL 45-day retention, negative IDs, HR validation bounds, rate limits 429, token 401 revocation, duplicate prevention, payload validation) | PASS (17/17) |
| Tier 3 | `test/e2e/tier3_cross_feature_test.dart` | 6 | Pairwise cross-feature combinations (Smart Merge + Disconnect, Selective Push + Additive Merge, Demographic Customization + Profile Sync, Guest Mode Live Session Tracking, Multi-surface token revocation, Disconnect -> Offline logging -> Reconnect) | PASS (6/6) |
| Tier 4 | `test/e2e/tier4_real_world_scenarios_test.dart` | 5 | End-to-end athlete journeys: 1. Complete Guest Runner Journey; 2. Strava Linking & Additive Smart Merge; 3. Selective Push Upload Flow; 4. Non-Destructive Disconnect Resilience; 5. Resilience Under Error (HTTP 429 & network outage) | PASS (5/5) |
| Master Runner | `test/e2e/e2e_suite_test.dart` | 54 | Unified master test runner executing Tiers 1–4 sequentially | PASS (54/54) |

---

## 2. Feature Traceability & Coverage Matrix

| Feature | Description | Covered In |
|---|---|---|
| F01 | Un-gated Boot to Dashboard | Tier 1 (Group 1), Tier 2 (E01), Tier 4 (Scenario 1) |
| F02 | Local Profile / Guest Mode Default | Tier 1 (Group 1), Tier 4 (Scenario 1) |
| F03 | Local Demographic Preference Store | Tier 1 (Group 1), Tier 2 (E04, E05), Tier 3 (Comb 3), Tier 4 (Scenario 1) |
| F04 | Zero-TTL Permanent Local SSOT | Tier 1 (Group 2), Tier 2 (E03), Tier 4 (Scenario 1, Scenario 4) |
| F05 | Unauthenticated Activity Retrieval | Tier 1 (Group 2), Tier 2 (E01, E02), Tier 4 (Scenario 1, Scenario 4) |
| F06 | Autonomous On-Device Training Load | Tier 1 (Group 3), Tier 3 (Comb 4), Tier 4 (Scenario 1) |
| F07 | Offline Dynamic Plan Generation | Tier 1 (Group 3), Tier 2 (E17), Tier 3 (Comb 1, Comb 4), Tier 4 (Scenario 1, Scenario 4) |
| F08 | Offline GPS & Sensor Workout Session | Tier 1 (Group 3), Tier 4 (Scenario 1) |
| F09 | In-App Workout Auto-Save | Tier 1 (Group 2), Tier 4 (Scenario 1) |
| F10 | Dedicated Integrations Section in Settings | Tier 1 (Group 4), Tier 4 (Scenario 2, Scenario 4) |
| F11 | Disconnected Integration Card State | Tier 1 (Group 4), Tier 4 (Scenario 2) |
| F12 | On-Demand Strava OAuth Trigger | Tier 1 (Group 4), Tier 4 (Scenario 2) |
| F13 | Connected Integration Card State | Tier 1 (Group 4), Tier 4 (Scenario 2, Scenario 4) |
| F14 | Non-Destructive Disconnect Action | Tier 1 (Group 4), Tier 2 (E06), Tier 3 (Comb 1), Tier 4 (Scenario 4) |
| F15 | Graceful Token Expiration & Revocation | Tier 1 (Group 4), Tier 2 (E07), Tier 3 (Comb 5), Tier 4 (Scenario 5) |
| F16 | Legacy Token Recognition | Tier 1 (Group 4) |
| F17 | Smart Merge Activity Ingestion | Tier 1 (Group 5), Tier 2 (E08, E09), Tier 3 (Comb 1, Comb 2), Tier 4 (Scenario 2) |
| F18 | Local-Only Run Protection (Negative IDs) | Tier 1 (Group 5), Tier 2 (E08), Tier 3 (Comb 1, Comb 6), Tier 4 (Scenario 2) |
| F19 | Additive Athlete Profile Parameter Sync | Tier 1 (Group 5), Tier 2 (E10), Tier 3 (Comb 3), Tier 4 (Scenario 2) |
| F20 | Multi-Surface Manual Sync Trigger | Tier 1 (Group 5), Tier 3 (Comb 5), Tier 4 (Scenario 2) |
| F21 | Non-Blocking Remote Sync Resilience | Tier 1 (Group 5), Tier 3 (Comb 5), Tier 4 (Scenario 5) |
| F22 | Sync Status Metadata & Differentiation | Tier 1 (Group 6), Tier 4 (Scenario 3) |
| F23 | Activity Card Sync Status Indicator | Tier 1 (Group 6), Tier 4 (Scenario 3) |
| F24 | User-Initiated "Upload to Strava" Action | Tier 1 (Group 6), Tier 3 (Comb 2), Tier 4 (Scenario 3) |
| F25 | Strava Activity Creation Endpoint | Tier 1 (Group 6), Tier 3 (Comb 2), Tier 4 (Scenario 3) |
| F26 | Remote ID Association & Deduplication | Tier 1 (Group 6), Tier 2 (E13), Tier 3 (Comb 2), Tier 4 (Scenario 3) |
| F27 | Strava Rate Limit (HTTP 429) Handling | Tier 1 (Group 6), Tier 2 (E12), Tier 4 (Scenario 5) |
| F28 | Automated Background Upload Prohibition | Tier 1 (Group 6), Tier 4 (Scenario 3) |
| F29 | Additive Reconnection Reconciliation | Tier 1 (Group 5), Tier 2 (E16), Tier 3 (Comb 6) |
| F30 | Instant Time-to-First-Interaction | Tier 1 (Group 1), Tier 4 (Scenario 1) |

---

## 3. How to Run the Tests

```bash
# Run the Master E2E Suite (Tiers 1–4)
flutter test test/e2e/e2e_suite_test.dart

# Run individual tiers
flutter test test/e2e/tier1_feature_coverage_test.dart
flutter test test/e2e/tier2_boundary_corner_test.dart
flutter test test/e2e/tier3_cross_feature_test.dart
flutter test test/e2e/tier4_real_world_scenarios_test.dart

# Run full project test suite (E2E + Unit + Widget)
flutter test

# Verify static analysis & formatting
dart analyze
dart format --output=none --set-exit-if-changed .
```

---

## 4. Verification Results

- `flutter test test/e2e/e2e_suite_test.dart`: **54/54 PASS** (0 failures, exit code 0)
- `flutter test` (entire repository): **183/183 PASS** (0 failures, exit code 0)
- `dart analyze`: **0 errors, 0 warnings**
- `dart format --output=none --set-exit-if-changed .`: **0 violations**

---

## 5. Implementation Defect Escrow & Architectural Alert

### Critical Hive Integer Key Limitation
- **Defect Discovered**: In Hive (`Frame.assertKey`), integer keys are strictly constrained: `0 <= key <= 0xFFFFFFFF`. Negative integer keys (e.g. `activity.id = -1716200000000`) throw `HiveError: Integer keys need to be in the range 0 - 0xFFFFFFFF`.
- **Impact on Implementation**: In `LocalActivityDataSource.saveActivities`:
  ```dart
  entries[activity.id] = { ... };
  await box.putAll(entries);
  ```
  Passing negative integer keys throws `HiveError`. Because `saveActivities` wraps this in `try { ... } catch (_) {}`, the error is silently swallowed and local workouts with negative IDs fail to be saved to Hive!
- **Mandatory Resolution for Implementer Agents**: In `LocalActivityDataSource`, box entries must use String keys (`activity.id.toString()`) or unsigned integer mapping. Hive fully supports arbitrary String keys without range limitations.
