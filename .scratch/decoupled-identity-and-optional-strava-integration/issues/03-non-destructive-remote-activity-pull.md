# 03: Non-Destructive Remote Activity Pull (Smart Merge)

**What to build:** An additive Smart Merge synchronization process that imports remote Strava activities into the permanent on-device Hive storage without overwriting or erasing local-only workouts (such as runs recorded offline via GPS/pedometer or entered manually). Athletes can manually refresh activities from the dashboard or settings, receiving progress feedback while ensuring their full local training history remains intact.

**Blocked by:** 01: Un-gated App Launch and Local Profile Guest Mode, 02: Relocate Strava Integration to Settings

**Status:** closed

- [x] Smart Merge reconciliation imports remote Strava activities by matching unique identifiers, adding new remote workouts to the local database without clobbering existing records
- [x] Local-only activities (identified by local timestamp/negative IDs) are preserved intact across all remote sync and refresh operations
- [x] Profile sync from Strava (e.g. maximum heart rate, birth date) additively updates athlete preferences without overwriting explicitly modified local parameters
- [x] Manual refresh triggers on the dashboard and settings provide clear progress and completion indicators
- [x] Network failures or Strava API issues during sync surface non-blocking notifications without clearing or corrupting cached local data
- [x] Tests verify that running a sync on a database containing local-only workouts results in an additive union containing both local and remote activities
