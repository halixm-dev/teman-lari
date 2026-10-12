# E2E Test Infra: Teman Lari Decoupled Identity & Optional Strava Integration

## Test Philosophy
- Opaque-box, requirement-driven derived from `ORIGINAL_REQUEST.md` and `spec.md`. No dependency on implementation design.
- Methodology: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| F01 | Un-gated Boot to Dashboard | ORIGINAL_REQUEST § R1, spec.md US1 | 5 | 5 | ✓ |
| F02 | Local Profile / Guest Mode Default | ORIGINAL_REQUEST § R1, spec.md US4 | 5 | 5 | ✓ |
| F03 | Local Demographic Preference Store | ORIGINAL_REQUEST § R1, spec.md US5 | 5 | 5 | ✓ |
| F04 | Zero-TTL Permanent Local SSOT | ORIGINAL_REQUEST § R1, ADR 0007 | 5 | 5 | ✓ |
| F05 | Unauthenticated Activity Retrieval | ORIGINAL_REQUEST § R1, spec.md § Decisions | 5 | 5 | ✓ |
| F06 | Autonomous On-Device Training Load | ORIGINAL_REQUEST § R1, spec.md US6 | 5 | 5 | ✓ |
| F07 | Offline Dynamic Plan Generation | ORIGINAL_REQUEST § R1, spec.md US7 | 5 | 5 | ✓ |
| F08 | Offline GPS & Sensor Workout Session | ORIGINAL_REQUEST § R1, spec.md US2 | 5 | 5 | ✓ |
| F09 | In-App Workout Auto-Save | ORIGINAL_REQUEST § R1, ADR 0007 | 5 | 5 | ✓ |
| F10 | Dedicated Integrations Section in Settings | ORIGINAL_REQUEST § R2, spec.md US9 | 5 | 5 | ✓ |
| F11 | Disconnected Integration Card State | ORIGINAL_REQUEST § R2, spec.md US9 | 5 | 5 | ✓ |
| F12 | On-Demand Strava OAuth Trigger | ORIGINAL_REQUEST § R2, spec.md US10 | 5 | 5 | ✓ |
| F13 | Connected Integration Card State | ORIGINAL_REQUEST § R2, spec.md US19 | 5 | 5 | ✓ |
| F14 | Non-Destructive Disconnect Action | ORIGINAL_REQUEST § R2, spec.md US20–22 | 5 | 5 | ✓ |
| F15 | Graceful Token Expiration & Revocation | ORIGINAL_REQUEST § R2, spec.md US23 | 5 | 5 | ✓ |
| F16 | Legacy Token Recognition | ORIGINAL_REQUEST § R2, spec.md § Notes | 5 | 5 | ✓ |
| F17 | Smart Merge Activity Ingestion | ORIGINAL_REQUEST § R3, spec.md US11 | 5 | 5 | ✓ |
| F18 | Local-Only Run Protection (Negative IDs) | ORIGINAL_REQUEST § R3, spec.md US11 | 5 | 5 | ✓ |
| F19 | Additive Athlete Profile Parameter Sync | ORIGINAL_REQUEST § R3, spec.md US12 | 5 | 5 | ✓ |
| F20 | Multi-Surface Manual Sync Trigger | ORIGINAL_REQUEST § R3, spec.md § Decisions | 5 | 5 | ✓ |
| F21 | Non-Blocking Remote Sync Resilience | ORIGINAL_REQUEST § R3, spec.md US16 | 5 | 5 | ✓ |
| F22 | Sync Status Metadata & Differentiation | ORIGINAL_REQUEST § R4, spec.md US13 | 5 | 5 | ✓ |
| F23 | Activity Card Sync Status Indicator | ORIGINAL_REQUEST § R4, spec.md US13 | 5 | 5 | ✓ |
| F24 | User-Initiated "Upload to Strava" Action | ORIGINAL_REQUEST § R4, spec.md US14 | 5 | 5 | ✓ |
| F25 | Strava Activity Creation Endpoint | ORIGINAL_REQUEST § R4, spec.md § Decisions | 5 | 5 | ✓ |
| F26 | Remote ID Association & Deduplication | ORIGINAL_REQUEST § R4, spec.md US15 | 5 | 5 | ✓ |
| F27 | Strava Rate Limit (HTTP 429) Handling | ORIGINAL_REQUEST § R4, spec.md US16 | 5 | 5 | ✓ |
| F28 | Automated Background Upload Prohibition | ORIGINAL_REQUEST § R4, spec.md US17 | 5 | 5 | ✓ |
| F29 | Additive Reconnection Reconciliation | ORIGINAL_REQUEST § R3, spec.md US24 | 5 | 5 | ✓ |
| F30 | Instant Time-to-First-Interaction | ORIGINAL_REQUEST § R1, spec.md US25 | 5 | 5 | ✓ |

## Test Architecture
- Test runner: `flutter test test/e2e/e2e_suite_test.dart` or individual test targets in `test/e2e/`
- Integration with existing tests: All 55 baseline tests in `test/` remain intact and passing.
- Test files layout:
  - `test/e2e/tier1_feature_coverage_test.dart` (Feature coverage happy paths)
  - `test/e2e/tier2_boundary_corner_test.dart` (BVA and edge cases: empty stores, rate limits, 401s, negative IDs)
  - `test/e2e/tier3_cross_feature_test.dart` (Interactions between Smart Merge, Disconnect, Selective Push, Settings)
  - `test/e2e/tier4_real_world_scenarios_test.dart` (End-to-end athlete journeys: guest mode training, linking Strava, uploading runs, disconnecting without loss)

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Complete Guest Runner Journey: Launch offline, record local run, calculate training load, generate 7-day plan, verify zero crashes | F01, F02, F03, F04, F05, F06, F07, F08, F09, F30 | High |
| 2 | Strava Linking & Additive Smart Merge: Connect Strava from Settings, ingest remote history, preserve existing local negative-ID runs, update profile baselines | F10, F11, F12, F13, F17, F18, F19, F20, F29 | High |
| 3 | Selective Push Upload Flow: View local activity with "Local" badge, trigger upload to Strava, handle mock Strava response, verify remote ID association and "Synced" badge | F22, F23, F24, F25, F26, F28 | High |
| 4 | Non-Destructive Disconnect Resilience: Disconnect Strava from Settings, verify tokens cleared, verify local Hive activities, plan, and demographic settings persist intact | F10, F13, F14, F15, F04, F05 | Medium |
| 5 | Resilience Under Error: Trigger sync with network failure and rate limit (HTTP 429), verify non-blocking UI notifications, verify data remains safe and retryable | F15, F21, F27 | Medium |

## Coverage Thresholds
- Tier 1: Feature coverage (representative inputs for all features)
- Tier 2: Boundary value analysis (limits, zeros, negative IDs, expired tokens, rate limits)
- Tier 3: Pairwise combinations of major feature interactions
- Tier 4: Realistic end-to-end athlete journeys
- Acceptance: 100% of tests must pass cleanly with exit code 0
