# Project: Teman Lari — Decoupled Identity Model & Optional Strava Integration

## Architecture
Teman Lari is architected as a local-first runner application by default (`Local Profile / Guest Mode`).
- **Data Layer**: Hive database acts as the permanent Single Source of Truth (SSOT) with zero-TTL (ADR 0007). `ActivityRepository` serves local data when unauthenticated without attempting cloud calls or throwing `UnauthenticatedException`.
- **Identity & Navigation Layer**: Startup routes directly to `MainNavigationScreen` / `DashboardScreen` without mandatory Strava OAuth gating (ADR 0008). Demographic baselines are persisted in `PreferencesStorage`.
- **Integration Hub**: Strava is relocated to an optional Integrations section in `SettingsScreen`. Disconnecting is non-destructive (clears tokens only, retaining all local Hive activities, training plans, and preferences).
- **Ingestion & Sync**: Additive Smart Merge pulls remote Strava activities into Hive matching on unique IDs, strictly preserving local-only activities (negative integer IDs).
- **Selective Push**: Local activities display visual differentiation ("Local" badge). When Strava is connected, athletes can manually trigger "Upload to Strava", which posts to `POST /api/v3/activities`, captures the remote ID, and marks the activity synced without automated background uploads.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F01 | Un-gated Boot to Dashboard | App startup sequence bypasses mandatory OAuth gating and navigates directly to MainNavigationScreen / DashboardScreen | M2 | Survey / spec.md US1 |
| F02 | Local Profile / Guest Mode Default | Athlete operates in guest mode by default; biometrics and logs remain strictly on-device | M2 | Survey / spec.md US4 |
| F03 | Local Demographic Preference Store | Persists resting HR (30–120 bpm), max HR (100–250 bpm), and threshold pace (sec/km) in SharedPreferences | M2 | Survey / spec.md US5 |
| F04 | Zero-TTL Permanent Local SSOT | Eliminates 1-hour expiration on local Hive database, keeping records indefinitely | M1 | Survey / ADR 0007 |
| F05 | Unauthenticated Activity Retrieval | ActivityRepository.getAllActivities() serves local Hive activities without throwing exceptions or making network calls when unauthenticated | M1 | Survey / ORIGINAL_REQUEST R1 |
| F06 | Autonomous On-Device Training Load | Calculates ATL, CTL, TSB on-device in background isolate without remote API calls | M2 | Survey / spec.md US6 |
| F07 | Offline Dynamic Plan Generation | Generates 7-day periodized training plan adapted to runner phase using local run history | M2 | Survey / spec.md US7 |
| F08 | Offline GPS & Sensor Workout Session | Tracks live run session via RunSessionScreen without internet access | M2 | Survey / spec.md US2 |
| F09 | In-App Workout Auto-Save | Synthesizes completed live sessions into Activity entities with negative timestamp IDs and commits to Hive | M1 | Survey / ADR 0007 |
| F10 | Dedicated Integrations Section | Introduces an Integrations section within SettingsScreen housing the peripheral Strava integration card | M3 | Survey / ORIGINAL_REQUEST R2 |
| F11 | Disconnected Integration Card State | Displays "Connect with Strava" button and value proposition summary in Settings | M3 | Survey / spec.md US9 |
| F12 | On-Demand Strava OAuth Trigger | Initiates Strava OAuth flow when athlete explicitly taps "Connect with Strava" in Settings | M3 | Survey / spec.md US10 |
| F13 | Connected Integration Card State | Displays connected athlete name, profile details, sync status, manual sync trigger, and disconnect button | M3 | Survey / spec.md US19 |
| F14 | Non-Destructive Disconnect Action | Safely unlinks Strava by clearing tokens without wiping local Hive activities, deleting plans, or evicting runner | M3 | Survey / ORIGINAL_REQUEST R2 |
| F15 | Graceful Token Expiration & Revocation | Handles HTTP 401/403 by clearing tokens and marking integration disconnected without crashes | M3 | Survey / spec.md US23 |
| F16 | Legacy Token Recognition | Automatically recognizes pre-existing Strava tokens in TokenStorage as an active connected integration | M3 | Survey / spec.md § Notes |
| F17 | Smart Merge Activity Ingestion | Additively imports remote Strava activities into Hive by matching unique IDs, without deleting or modifying local-only runs | M4 | Survey / ORIGINAL_REQUEST R3 |
| F18 | Local-Only Run Protection | Preserves workouts with negative integer IDs across all remote sync, pull, or refresh operations | M4 | Survey / spec.md US11 |
| F19 | Additive Athlete Profile Parameter Sync | Syncs remote Strava profile metrics to local preferences only if local values were not manually customized | M3 | Survey / spec.md US12 |
| F20 | Multi-Surface Manual Sync Trigger | Allows athlete to trigger manual synchronization from Dashboard and Settings | M4 | Survey / spec.md § Decisions |
| F21 | Non-Blocking Remote Sync Resilience | Surfaces network errors or Strava 5xx downtime during sync as temporary SnackBars without breaking UI | M4 | Survey / ORIGINAL_REQUEST R3 |
| F22 | Sync Status Metadata & Differentiation | Tracks whether each activity is local-only (negative ID / unsynced) or synced with remote Strava ID | M5 | Survey / ORIGINAL_REQUEST R4 |
| F23 | Activity Card Sync Status Indicator | Displays visual indicator ("Local" vs "Synced" badge) on CompactActivityCard and activity details | M5 | Survey / ORIGINAL_REQUEST R4 |
| F24 | User-Initiated "Upload to Strava" Action | Exposes explicit "Upload to Strava" button on unsynced activities when Strava is connected | M5 | Survey / ORIGINAL_REQUEST R4 |
| F25 | Strava Activity Creation Endpoint | Formats activity payload and executes POST /api/v3/activities | M5 | Survey / spec.md § Decisions |
| F26 | Remote ID Association & Deduplication | Updates local Hive record with returned remote Strava ID and marks activity synced upon successful upload | M5 | Survey / ORIGINAL_REQUEST R4 |
| F27 | Strava Rate Limit (HTTP 429) Handling | Catches HTTP 429, displaying user-friendly feedback with retry advice without corrupting local data | M5 | Survey / ORIGINAL_REQUEST R4 |
| F28 | Automated Background Upload Prohibition | Strictly avoids automatic background uploading of runs upon session completion | M5 | Survey / ORIGINAL_REQUEST R4 |
| F29 | Additive Reconnection Reconciliation | Reconnecting Strava resumes additive Smart Merge without duplicating already-imported workouts | M4 | Survey / spec.md US24 |
| F30 | Instant Time-to-First-Interaction | App boots instantly into dashboard on subsequent launches without splash screen network polling stalls | M2 | Survey / spec.md US25 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Local SSOT Storage & Decoupled Repository | Zero-TTL Hive storage, unauthenticated ActivityRepository safe fallback, single activity CRUD in LocalActivityDataSource (F04, F05, F09) | none | DONE |
| M2 | Un-gated App Launch, Guest Mode & Routing | Startup routing directly to /dashboard, Local Profile defaults, autonomous on-device plan generation & analytics (F01, F02, F03, F06, F07, F08, F30) | M1 | PLANNED |
| M3 | Settings Strava Hub & Non-Destructive Disconnect | Dedicated Integrations section in Settings, adaptive StravaIntegrationCard (Connect/Disconnect), non-destructive unlinking, threshold pace input (F10, F11, F12, F13, F14, F15, F16, F19) | M1, M2 | PLANNED |
| M4 | Non-Destructive Remote Activity Pull (Smart Merge) | Additive Smart Merge in LocalActivityDataSource, negative ID protection, multi-surface sync triggers, non-blocking error handling (F17, F18, F20, F21, F29) | M1 | PLANNED |
| M5 | Selective Push Upload & Sync Badging | POST /api/v3/activities in StravaApiClient, write scope, uploadActivity in repo, visual badges & upload button on cards, HTTP 429 handling, background upload prohibition (F22, F23, F24, F25, F26, F27, F28) | M1, M3, M4 | PLANNED |
| M6 | Final Milestone: E2E Test Suite Pass & Adversarial Hardening | Phase 1: 100% pass of E2E test suite (Tiers 1-4). Phase 2: Adversarial coverage hardening (Tier 5). Static analysis (0 errors, 0 warnings, formatting clean) | M1, M2, M3, M4, M5, TEST_READY.md | PLANNED |

## Interface Contracts

### M1 (Storage & Repo) ↔ Consumer Layers (M2, M3, M4, M5)
- `LocalActivityDataSource`:
  - `Future<List<Map<dynamic, dynamic>>?> getCachedActivities({bool checkTtl = true});` (Preserved for backwards compatibility with existing unit tests).
  - `Future<List<Map<dynamic, dynamic>>> getAllActivities();` (Zero-TTL permanent local SSOT).
  - `Future<void> saveActivity(ActivityModel model);`
  - `Future<void> updateActivity(ActivityModel model);`
  - `Future<void> smartMergeActivities(List<ActivityModel> remoteActivities);`
  - `Future<void> updateLocalActivityId(int oldLocalId, ActivityModel updatedModel);`
- `ActivityRepository`:
  - `Future<List<Activity>> getAllActivities({int monthsBack = 12});` (Never throws UnauthenticatedException; returns local data when unauthenticated).
  - `Future<void> refreshActivities({int monthsBack = 12});`
  - `Future<Activity> uploadActivity(int localActivityId);`

### M2 (Routing & Guest Mode) ↔ Navigation & Presentation
- `lib/main.dart`:
  - `GoRouter`: Initial location is `/dashboard`.
  - Unauthenticated athletes immediately access `MainNavigationScreen` and `DashboardScreen`.
- `PreferencesStorage`:
  - Default resting HR: 60 bpm.
  - Default max HR: 190 bpm (or 220 - age).
  - Threshold pace (sec/km): getter, setter, default null/fallback.

### M3 (Settings Integration Hub) ↔ Auth & Token Storage
- `TokenStorage`:
  - `Future<void> clearTokens();` clears Strava credentials only. Must never clear Hive storage.
- `AuthNotifier`:
  - `login()`: initiates OAuth flow with scopes `activity:read,activity:read_all,activity:write`.
  - `logout()`: clears tokens; transitions to unauthenticated state without navigating away from Settings.
- `StravaIntegrationCard`:
  - Disconnected: displays benefits and "Connect with Strava" button.
  - Connected: displays athlete identity, connected badge, manual sync action, and "Disconnect Strava" button with confirmation modal reassuring no data loss.

### M4 (Smart Merge) ↔ Sync Triggers
- Additive union rule:
  - If existing item has `id < 0`: retain unconditionally.
  - If remote item has `id > 0`: insert or update by matching `id`.
  - Never purge local-only items during remote sync.

### M5 (Selective Push) ↔ Remote Strava API
- `StravaApiClient`:
  - `Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body});`
  - Throws `StravaApiException(429, ...)` on HTTP 429.
- `Activity`:
  - `bool get isLocalOnly => id < 0;` (or explicit `bool isSynced`).
  - Remote Strava ID associated upon successful response.

## Code Layout
- `lib/core/network/`: `strava_api_client.dart`
- `lib/data/datasources/`: `local_activity_datasource.dart`, `strava_activity_datasource.dart`, `strava_auth_datasource.dart`, `preferences_storage.dart`, `token_storage.dart`
- `lib/data/models/`: `activity_model.dart`
- `lib/data/repositories/`: `activity_repository_impl.dart`
- `lib/domain/entities/`: `activity.dart`
- `lib/domain/repositories/`: `activity_repository.dart`
- `lib/presentation/providers/`: `auth_provider.dart`, `activities_provider.dart`
- `lib/presentation/screens/`: `dashboard_screen.dart`, `settings_screen.dart`, `main_navigation_screen.dart`
- `lib/presentation/widgets/settings/`: `strava_integration_card.dart`
- `lib/presentation/widgets/`: `compact_activity_card.dart`
- `test/`: Existing test suites preserved; new unit, widget, and E2E test suites created.
