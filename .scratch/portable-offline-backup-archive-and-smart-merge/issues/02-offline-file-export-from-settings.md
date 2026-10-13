# 02: Export an offline backup from Settings

Status: ready-for-agent

**What to build:** Let a guest athlete export currently persisted Local Profile, complete Activity history, and stored heart rate streams through Settings on Android, iOS, and web. Establish the shared version 1 archive contract for subsequent coverage slices.

**Blocked by:** 01 — Make local snapshot operations strict and recoverable.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [ ] Add Export Backup through Riverpod and the Snapshot Backup service, with native save/share and browser download adapters. Do not require authentication or issue remote requests.
- [ ] Write dated .tlbackup UTF-8 JSON with snake_case keys and the version 1 product marker, schema version, snapshot ID, UTC creation time, app version, section counts, and all six required data sections.
- [ ] Export all stored Activity types and history, negative local IDs, large remote IDs, original measurements, local status, annotations, and linked heart rate samples. Encode IDs and references as decimal strings without rounding.
- [ ] Export allowlisted profile settings with explicit unset/null semantics and per-field modification times. Track ordinary profile/cycle edits and clears; keep legacy unknown recency unknown rather than using export time or synced_at.
- [ ] Use the coordinated strict local snapshot, not repository methods that can fetch remote activities or suppress errors. Do not export derived Running Stats, credentials, onboarding state, arbitrary settings, or recovery material.
- [ ] Define Training Plan, equipment, and Rehab Feedback sections in the shared contract. Empty sections are valid only when genuinely empty; fail clearly if populated stored data is not supported. Tickets 03–05 complete required coverage before full feature acceptance.
- [ ] Enforce the 50 MiB actual UTF-8 byte limit without truncating history. Show a readable-personal-data notice, accurate progress, cancellation, failure, and native save/share versus browser download outcomes.
- [ ] At the service boundary, verify populated and empty exports, ancient history, identity precision, no network access, token sentinels in web/native storage, size boundaries, and strict storage failure behavior.
- [ ] Add focused Settings tests for cancellation, progress, duplicate-action prevention, active-workout refusal, error handling, and credential independence. Check native platform adapters and web compilation.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

