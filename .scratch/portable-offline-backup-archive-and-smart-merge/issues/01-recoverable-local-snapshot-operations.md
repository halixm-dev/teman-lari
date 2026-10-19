# 01: Make local snapshot operations strict and recoverable

Status: resolved

**What to build:** Prepare the existing Local SSOT so a backup can read a consistent state and a failed or interrupted restore can recover without losing athlete data. This is the single prerequisite prefactor; it adds no import UI.

**Blocked by:** None (can start immediately).

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Expose strict local snapshot reads and writes behind the Snapshot Backup service; propagate storage failures rather than returning empty history or reporting false success. Do not fetch remote data or impose the activity list's history window.
- [x] Coordinate all existing activity saves, Strava reconciliation/upload identity changes, profile saves, and cycle/plan changes with a shared local revision and exclusive snapshot operations. Extend the same registration to later equipment and feedback stores.
- [x] Refuse snapshot operations during an active tracked workout; protect readers from partially restored data and prevent overlapping backup operations.
- [x] Support staged next state, a durable before-image covering every affected Hive store and allowlisted preference, and a durable commit marker. Preserve credentials, onboarding, unrelated preferences, and recovery metadata outside archive data.
- [x] Recover before normal application providers initialize: roll back interruption before a durable commit marker; retain committed data and finish cleanup after it. Retain recovery material and show a retryable recovery state if rollback fails.
- [x] Make no live change if reading, validation, staging, or available-space checks fail. Report success only after durable writes; clean staging only after durable commit or rollback.
- [x] Verify behavior through the approved Snapshot Backup service boundary using temporary Hive, controlled preferences, and injected failures. Reopen stores to verify rollback and use a disposable process to verify initialization recovery across commit phases.
- [x] Keep current app behavior and existing tests passing; this prerequisite establishes recoverable operations without enabling destructive import.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

## Answer

Implemented the strict Snapshot Backup service boundary in `lib/data/backup/snapshot_backup_service.dart`:

- `initialize()` recovers all registered stores before providers start and retries failed recovery. `readLocalState()` reads complete local history; `applyLocalState(next, expectedRevision:)` stages, validates, applies, flushes, and durably commits or rolls back.
- Shared coordination covers normal Activity/HR writes and Strava identity changes, profile setters, and aggregate Settings saves. Default registry includes `activities`, `hr_streams`, `training_plans`, `equipment`, `rehab_feedback`, and allowlisted `preferences`; later stores use the same coordinator. The legacy shared queue activates during startup recovery; explicit injected coordinators are active immediately.
- Durable Hive before/next images, quota reservation, commit and rollback-settled markers protect interrupted operations. Recovery blocks normal access after a failed rollback and retains its material. A Hive preference checkpoint makes allowlisted preference durability independent of the platform cache; startup restores its SharedPreferences mirror. Credentials, onboarding, unrelated preferences, and journal/checkpoint metadata stay outside archive state.
- The application initializes recovery before constructing ProviderScope, with an error/retry gate. Tracked workout routes hold a lease through pause and unsaved session lifetime, refusing snapshots until the route closes.
- Normal preference edits write per-field UTC modification times; untouched legacy fields retain unknown recency. Empty normal ingestion batches avoid unnecessary writes and flushes.

Validation: 430 full-suite tests passed; zero analyzer issues; `dart format .` unchanged; standards guardrail passed against integration base `4c7ba19`; Flutter web build and Wasm dry run passed. New service tests use real temporary Hive, controlled preferences, storage/space failures, reopen checks, concurrency, stale revisions, delayed writer leases, and disposable native processes interrupted before/after the durable commit marker. The process launcher selects Windows or Unix Dart names.

Evidence: `test/data/backup/snapshot_backup_service_test.dart`, `test/data/backup/snapshot_backup_failures_test.dart`, and `test/data/backup/fixtures/recovery_worker.dart`. Process-interruption evidence was executed on the Windows host; physical Android/iOS termination and browser runtime testing remain platform acceptance work for the complete feature. No import/export UI is enabled by this prerequisite.
