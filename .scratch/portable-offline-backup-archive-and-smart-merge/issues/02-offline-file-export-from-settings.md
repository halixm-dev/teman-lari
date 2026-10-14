# 02: Export an offline backup from Settings

Status: resolved

**What to build:** Let a guest athlete export currently persisted Local Profile, complete Activity history, and stored heart rate streams through Settings on Android, iOS, and web. Establish the shared version 1 archive contract for subsequent coverage slices.

**Blocked by:** 01 — Make local snapshot operations strict and recoverable.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Add Export Backup through Riverpod and the Snapshot Backup service, with native save/share and browser download adapters. Do not require authentication or issue remote requests.
- [x] Write dated .tlbackup UTF-8 JSON with snake_case keys and the version 1 product marker, schema version, snapshot ID, UTC creation time, app version, section counts, and all six required data sections.
- [x] Export all stored Activity types and history, negative local IDs, large remote IDs, original measurements, local status, annotations, and linked heart rate samples. Encode IDs and references as decimal strings without rounding.
- [x] Export allowlisted profile settings with explicit unset/null semantics and per-field modification times. Track ordinary profile/cycle edits and clears; keep legacy unknown recency unknown rather than using export time or synced_at.
- [x] Use the coordinated strict local snapshot, not repository methods that can fetch remote activities or suppress errors. Do not export derived Running Stats, credentials, onboarding state, arbitrary settings, or recovery material.
- [x] Define Training Plan, equipment, and Rehab Feedback sections in the shared contract. Empty sections are valid only when genuinely empty; fail clearly if populated stored data is not supported. Tickets 03–05 complete required coverage before full feature acceptance.
- [x] Enforce the 50 MiB actual UTF-8 byte limit without truncating history. Show a readable-personal-data notice, accurate progress, cancellation, failure, and native save/share versus browser download outcomes.
- [x] At the service boundary, verify populated and empty exports, ancient history, identity precision, no network access, token sentinels in web/native storage, size boundaries, and strict storage failure behavior.
- [x] Add focused Settings tests for cancellation, progress, duplicate-action prevention, active-workout refusal, error handling, and credential independence. Check native platform adapters and web compilation.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.


## Answer

Implemented offline export through the existing `SnapshotBackupService` and an
injectable Riverpod Settings card. `prepareExport()` returns a complete archive;
`exportBackup(transport)` holds the shared operation lease through actual delivery
or cancellation and exposes preparing/saving phases. Settings building never
activates recovery or starts background work.

Version 1 uses generated snake_case DTOs with all six mandatory sections, exact
decimal-string identities, UTC metadata, calendar birth dates, explicit null/edit
semantics, counts, all persisted Activity types/history and fractional streams.
Only domain allowlists are encoded. Unsupported populated plan/equipment/feedback
stores fail clearly until tickets 03-05 extend their separate section modules.
Native application version comes from local packaged metadata; production web
builds inject pubspec's APP_VERSION without requesting version.json.

The platform adapter uses file_picker 10.3.10 for bounded future import reads and
supported save/download targets. Android uses an app-owned document channel that
requires write, flush and close before success, detects missing streams/URIs,
and attempts cleanup of only the newly created failed document. iOS removes only
its unique task-owned Documents staging file. The UI distinguishes cancellation,
save, download initiation, and share handoff, and explains readable personal data.

Validation: 448 full-suite tests passed, including 18 new tests at the approved
service and Settings seams. Coverage includes exact 50 MiB actual UTF-8 acceptance
and one extra byte refusal, ancient mixed history, native IDs above 2^53, decimal
precision, network-disabled export, secret sentinels, strict corruption failures,
unsupported sections, ordinary nullable clears and unknown legacy recency,
native platform-channel failure/cancel/success, duplicate operations, active
workouts, retry, accurate outcomes, dark theme and 200% text scaling. Formatting,
standards guardrail against e214b98 and zero-warning analysis passed. Web release
build with APP_VERSION and Wasm dry run passed.

Native limitation: Android compile attempts stopped because host C: ran out of
space after resource exhaustion; no successful native compile or document-provider
smoke test is claimed. Root owns serialized native QA as a final full-feature gate.
iOS save/cancel cleanup and real device accessibility also require platform QA.
This resolves the export slice, not full backup acceptance or populated coverage.

Contract: `docs/offline-backup-format.md` and
`test/fixtures/offline-backup-v1-empty.tlbackup`. Evidence:
`test/data/backup/snapshot_archive_export_test.dart` and
`test/presentation/widgets/backup_card_test.dart`.
