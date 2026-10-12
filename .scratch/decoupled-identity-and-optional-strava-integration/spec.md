# Spec: Decoupled Identity Model and Optional Strava Integration

Status: completed

## Problem Statement

As a runner using Teman Lari, I am currently forced to authenticate with Strava via OAuth before I can use any part of the application. If I open the app without an internet connection, if I do not own a Strava account, or if Strava's servers experience downtime or rate limiting, I am locked out on a login screen and unable to access my training dashboard, plan my upcoming workouts, or track a run.

Furthermore, if I disconnect my Strava account, the app threatens to wipe or disable my training plan and real-time performance analytics, ejecting me back to the login screen. Any workouts I track or manual entries I log are tethered to cloud authentication, and there is no way for me to selectively decide which of my offline runs get uploaded to Strava versus kept private or local-only.

## Solution

Teman Lari adopts a local-first runner identity model by default (`Local Profile / Guest Mode`). All athletes can immediately access the dashboard, training load analytics, training plan generation, and live workout tracking upon launching the app, without requiring any account creation, login, or cloud network connectivity. Baseline demographic parameters (resting heart rate, maximum heart rate, threshold pace) are stored and managed entirely on-device.

Strava is repositioned as an optional peripheral integration located in the Settings screen. Athletes can connect or disconnect their Strava account at any time without impacting the availability of local data, schedules, or tracking features. When connected, remote activities are imported into the local database non-destructively through Smart Merge, preserving local-only runs. Workouts recorded offline or entered manually feature an explicit, user-initiated "Upload to Strava" action (Selective Push), preventing rate-limit saturation and unintended duplicate uploads while giving athletes full autonomy over external publication.

## User Stories

1. As a new runner, I want to open the app and immediately view my training dashboard without being forced to log into Strava, so that I can use the app friction-free.
2. As an offline runner, I want to record a live running session using GPS and pedometer sensors without internet access, so that my training is never interrupted by connectivity loss.
3. As an offline runner, I want my completed running sessions to be saved directly to the local database, so that my workout history is safely preserved regardless of network availability.
4. As a privacy-conscious athlete, I want to use Teman Lari entirely in Local Profile / Guest Mode without ever linking a third-party account, so that my biometric and location data remains strictly on my device.
5. As a runner, I want to configure my resting heart rate, maximum heart rate, and threshold pace in Settings while offline, so that my heart rate zones and training load metrics reflect my personal physiology.
6. As a runner without a Strava account, I want to view my acute training load (ATL), chronic training load (CTL), and training stress balance (TSB) computed on-device, so that I understand my fitness and fatigue levels without cloud processing.
7. As a runner, I want to generate a multi-week periodized training plan based on my local running history, so that I can prepare for races even if I never connect to Strava.
8. As a runner, I want to manually log a workout completed without mobile tracking, so that my training log accounts for treadmill and watch-tracked sessions.
9. As a runner, I want to discover Strava as an optional integration inside the Settings screen under an Integrations section, so that I understand what benefits connecting Strava provides before deciding to authenticate.
10. As a runner, I want to initiate Strava OAuth from the Settings screen when I choose to, so that I can link my account on my own terms.
11. As a runner connecting Strava for the first time, I want my historical Strava activities to be pulled additively into my local database without overwriting or deleting any runs I recorded offline, so that my local training history remains complete.
12. As a runner connecting Strava, I want my Strava profile parameters (e.g., maximum heart rate and athlete name) to sync additively to my local preferences if local values have not been explicitly overridden, so that setup effort is minimized.
13. As a runner with both local runs and Strava-synced runs, I want to see a clear visual indicator on each activity showing whether it is local-only or synced with Strava, so that I know the cloud status of my data.
14. As a runner with local-only workouts, I want an explicit "Upload to Strava" action on each local activity, so that I can selectively publish specific workouts to my Strava profile.
15. As a runner tapping "Upload to Strava", I want the app to send the activity details to Strava's API and update the local activity record with the resulting Strava activity identifier, so that future duplicates are prevented.
16. As a runner uploading a workout to Strava, I want immediate visual feedback if Strava rate limits are reached or network errors occur, so that I understand why the upload did not complete and can retry later.
17. As a runner, I want the app to never upload local workouts to Strava automatically in the background without my explicit command, so that I avoid exceeding Strava API rate limits and keep full control over external sharing.
18. As a runner, I want pulling new activities from Strava to use Smart Merge reconciliation, so that existing local notes, shoe assignments, and rehab feedback are not wiped out by remote data pulls.
19. As a connected runner, I want to see my connected Strava athlete profile and status clearly displayed in the Integrations section of Settings, so that I know which account is active.
20. As a connected runner, I want to disconnect my Strava account from Settings at any time, so that I can unlink my account whenever I wish.
21. As a runner disconnecting Strava, I want all my existing local activities, training plans, and physiological metrics to remain completely intact on my device, so that unlinking does not cause data loss.
22. As a runner disconnecting Strava, I want to remain on the Settings screen or return to the Dashboard without being redirected to a blocking login screen, so that my app experience is uninterrupted.
23. As a runner whose Strava authorization tokens expire or are revoked externally, I want the app to transition the Strava integration to a disconnected state gracefully without crashing or blocking local features, so that I can continue training offline.
24. As a runner who previously disconnected Strava, I want to be able to reconnect Strava later and have the sync resume additively without creating duplicate entries for already-imported workouts, so that my activity log stays clean.
25. As a runner launching the app on subsequent days, I want the app to start immediately into the main navigation without splash screen auth polling delays, so that time-to-first-interaction is instantaneous.

## Implementation Decisions

- **Local Profile / Guest Mode as Default Identity State**:
  - The application startup sequence removes the mandatory Strava OAuth gating check.
  - The initial launch route directs athletes immediately to the main navigation (or first-launch demographic onboarding when not yet completed), initializing a local athlete profile with default or stored baseline parameters.
  - The standalone login screen is eliminated from the required application launch path, demoting Strava authentication from an access gatekeeper to a secondary settings feature.

- **Strava Repositioned to Settings under Integrations**:
  - The Settings screen introduces a dedicated Integrations section housing the Strava connection card.
  - When disconnected, the card presents a "Connect with Strava" action highlighting the value proposition (importing activity history, syncing profile metrics, selective upload of offline runs).
  - When connected, the card displays the connected athlete name, account status, a manual sync trigger, and a benign "Disconnect Strava" action.
  - Disconnecting Strava clears stored OAuth tokens and resets the integration status without clearing local activities, local profile preferences, active training plans, or cached sensor streams.

- **Single Source of Truth (SSOT) Local Store Decoupling**:
  - The local database (Hive) serves as the permanent, un-expiring SSOT for all activities and stream data.
  - The activity repository resolves requests for activity lists directly from the local store first.
  - If Strava is not connected, repository methods return local activities without initiating outbound network requests and without raising authentication errors.
  - Network failures or authorization errors from Strava do not propagate as fatal errors to the presentation layer; they are surfaced as non-blocking integration notices.

- **Non-Destructive Pull (Smart Merge Ingestion)**:
  - When Strava is connected and a sync/refresh is triggered, remote activities are retrieved and merged additively into the local database.
  - Smart Merge matches activities on their unique identifiers (remote Strava ID vs. local timestamp ID).
  - Local-only activities (identified by negative integer IDs or local creation flags) are never deleted, overwritten, or excluded during remote sync operations.
  - Profile parameter sync from Strava (e.g., maximum heart rate, date of birth) updates local preferences only if local values have not been customized, preventing remote overwrites of manual athlete tuning.

- **Selective Push (User-Initiated Upload Action)**:
  - Activities recorded locally or created manually are marked with an unsynced/local-only status.
  - An explicit "Upload to Strava" action is exposed on activity detail and summary views for unsynced activities when Strava is connected.
  - The upload process posts the activity payload to Strava's `POST /api/v3/activities` endpoint, captures the returned remote ID, updates the local entity to associate the remote Strava ID, and marks the record as synced.
  - Automated background uploads are strictly avoided to respect Strava 15-minute and daily rate limits and to honor athlete data publishing sovereignty.
  - If an upload attempt encounters an HTTP 429 rate limit or network exception, the activity remains safely in its local-only state and displays a retryable prompt.

- **Graceful Token Lifecycle Management**:
  - When Strava API returns HTTP 401/403 with invalid or revoked token responses during integration calls, the app clears the invalid tokens and updates the integration status to disconnected without clearing any local activity data or blocking local UI features.

## Testing Decisions

- **What makes a good test**:
  - Tests must verify external observable behavior across the module interface, not internal implementation mechanics or private helper states.
  - Tests verify that athletes can access and manipulate their data completely in disconnected/guest mode without exceptions.
  - Tests verify that connecting Strava additively pulls activities without erasing local-only items.
  - Tests verify that selective push successfully updates the sync status of a local run without triggering side-effects on other records.
  - Tests verify that disconnecting Strava leaves all local records untouched and keeps the dashboard and settings functional.

- **Modules and Seams to Test**:
  - *Primary External Seam: The Activity Repository & Integration Provider Seam (`ActivityRepository` and `AuthNotifier`/`StravaAuthUseCase`)*:
    - Test fetching activities when Strava tokens are absent: returns all local activities without throwing `UnauthenticatedException` or `ServerFailure`.
    - Test non-destructive pull: Given a local database with local-only activities (e.g., negative ID workouts) and incoming remote Strava activities, verify that the resulting database contains both local and remote workouts without data loss.
    - Test selective push: Given an unsynced local activity, calling upload dispatches the remote create request and updates the local record with the remote Strava ID.
    - Test disconnect: Disconnecting Strava clears stored credentials while preserving all local activities and demographic preferences.
  - *Presentation / Widget Seam (`SettingsScreen` & `MainNavigationScreen`)*:
    - Test that launching the application without stored Strava tokens loads the `MainNavigationScreen` and `DashboardScreen` directly in guest mode rather than redirecting to `LoginScreen`.
    - Test that `SettingsScreen` displays "Connect with Strava" when unlinked, and "Disconnect Strava" with athlete information when linked.
    - Test that triggering disconnect from `SettingsScreen` remains on the screen and transitions the card state without routing to login.

- **Prior Art**:
  - `test/data/datasources/local_activity_datasource_test.dart`: Hive persistence testing using temporary directory sandboxing.
  - `test/presentation/widgets/run_session/run_session_state_test.dart`: State transition and sensor metric computation testing.
  - `test/widget_test.dart`: Top-level widget pumping with `ProviderScope`.

## Out of Scope

- Two-way conflict resolution / bidirectional sync (e.g., propagating changes made on Strava web back to overwrite custom local metrics or manual notes).
- Full portable backup archiving (importing/exporting JSON/ZIP database bundles), which is governed by ADR 0011.
- Google Account and Firebase cloud snapshot backups, which are governed by ADR 0010.
- First-launch welcome onboarding carousel and demographic baseline questionnaire UI, which is governed by ADR 0009.
- Automatic background polling or background uploads of runs upon session completion.
- Deletion propagation (deleting an activity locally does not delete it from Strava, and deleting on Strava does not purge the local SSOT record).

## Further Notes

- Seamless backward compatibility must be maintained for existing users who already have Strava tokens stored in SharedPreferences/SecureStorage; their tokens will be recognized as an active Strava integration in Settings.
- Adheres strictly to ADR 0007 by utilizing the local Hive store as the permanent SSOT with zero-TTL expiration.
- Adheres to domain terminology from `GLOSSARY.md` (`Local Profile / Guest Mode`, `Single Source of Truth (SSOT) Local Store`, `Manual Activity`, `Selective Push`, `Smart Merge`).
