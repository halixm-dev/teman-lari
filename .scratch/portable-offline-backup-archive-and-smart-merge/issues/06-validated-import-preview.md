# 06: Preview a validated backup before importing

Status: resolved

**What to build:** Let an athlete select a .tlbackup file on mobile or web, inspect its full contents and intended import mode, and cancel without changing local data.

**Blocked by:** 03 — Preserve Training Plans across restart and backup; 04 — Preserve shoe equipment and Activity assignments; 05 — Preserve Rehab Feedback in offline backups.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Add Import Backup and native/browser file selection through the existing service and platform adapters. File selection, validation, and preview must make no live writes or remote requests.
- [x] Validate product marker, supported schema and record variants, all six required sections, section counts, identifiers, dates, finite measurements, per-section unique IDs, and required cross-references.
- [x] Bound input to 50 MiB actual bytes before parsing and JSON nesting to 64 levels. Distinguish missing sections, empty collections, explicit nulls, unknown optional fields, and unsupported required data.
- [x] Check archive identities can be represented exactly on the active platform; reject precision loss before allowing apply.
- [x] Show UTC-derived creation information, app/schema version, section counts, and local/archived counts. Default to Smart Merge and explain local preservation; show Replace All Local Data as a distinct mode.
- [x] Bind the preview to archive identity and local state revision. Subsequent apply tickets must reject stale previews, recompute changes, and obtain renewed confirmation.
- [x] Keep apply unavailable until its matching implementation is present; do not simulate import success. Tickets 07–09 add actual merge/replacement changes to this preview.
- [x] Test malformed/truncated JSON, unsupported formats, boundary sizes/nesting, historical but valid records, missing sections, bad counts, bad references, and non-representable IDs through the service.
- [x] Test picker cancellation, invalid-file errors, progress, mode defaults, preview cancellation, active-workout refusal, semantic labels, and text scaling through focused Settings tests.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

## Answer

Implemented read-only file selection and strict validated previews through
`SnapshotBackupService.prepareImport` / `importBackup`. All six sections require
explicit fields, supported variants, exact identities, consistent counts and
references. Actual-byte and nesting limits are checked before parsing. Preview
content is immutable and bound to the captured local revision; rendering uses
cached UTC metadata and counts. Settings defaults to Smart Merge, separates
replacement, supports cancellation and progress, and keeps apply unavailable
until tickets 07-09 provide confirmed application.

Added a populated six-section fixture for subsequent native/browser acceptance.
Original invalid Activity timestamps are rejected before export normalization.

Validation: 71 focused tests and all 538 Flutter tests passed; `dart format .`,
standards guardrail, zero-warning analysis, release web build and Wasm dry run
passed. Native/browser interaction acceptance remains part of final platform QA.
