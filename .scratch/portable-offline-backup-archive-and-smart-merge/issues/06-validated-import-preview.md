# 06: Preview a validated backup before importing

Status: claimed

**What to build:** Let an athlete select a .tlbackup file on mobile or web, inspect its full contents and intended import mode, and cancel without changing local data.

**Blocked by:** 03 — Preserve Training Plans across restart and backup; 04 — Preserve shoe equipment and Activity assignments; 05 — Preserve Rehab Feedback in offline backups.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [ ] Add Import Backup and native/browser file selection through the existing service and platform adapters. File selection, validation, and preview must make no live writes or remote requests.
- [ ] Validate product marker, supported schema and record variants, all six required sections, section counts, identifiers, dates, finite measurements, per-section unique IDs, and required cross-references.
- [ ] Bound input to 50 MiB actual bytes before parsing and JSON nesting to 64 levels. Distinguish missing sections, empty collections, explicit nulls, unknown optional fields, and unsupported required data.
- [ ] Check archive identities can be represented exactly on the active platform; reject precision loss before allowing apply.
- [ ] Show UTC-derived creation information, app/schema version, section counts, and local/archived counts. Default to Smart Merge and explain local preservation; show Replace All Local Data as a distinct mode.
- [ ] Bind the preview to archive identity and local state revision. Subsequent apply tickets must reject stale previews, recompute changes, and obtain renewed confirmation.
- [ ] Keep apply unavailable until its matching implementation is present; do not simulate import success. Tickets 07–09 add actual merge/replacement changes to this preview.
- [ ] Test malformed/truncated JSON, unsupported formats, boundary sizes/nesting, historical but valid records, missing sections, bad counts, bad references, and non-representable IDs through the service.
- [ ] Test picker cancellation, invalid-file errors, progress, mode defaults, preview cancellation, active-workout refusal, semantic labels, and text scaling through focused Settings tests.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.


