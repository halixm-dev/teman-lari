# 01: Make local snapshot operations strict and recoverable

Status: ready-for-agent

**What to build:** Prepare the existing Local SSOT so a backup can read a consistent state and a failed or interrupted restore can recover without losing athlete data. This is the single prerequisite prefactor; it adds no import UI.

**Blocked by:** None (can start immediately).

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [ ] Expose strict local snapshot reads and writes behind the Snapshot Backup service; propagate storage failures rather than returning empty history or reporting false success. Do not fetch remote data or impose the activity list's history window.
- [ ] Coordinate all existing activity saves, Strava reconciliation/upload identity changes, profile saves, and cycle/plan changes with a shared local revision and exclusive snapshot operations. Extend the same registration to later equipment and feedback stores.
- [ ] Refuse snapshot operations during an active tracked workout; protect readers from partially restored data and prevent overlapping backup operations.
- [ ] Support staged next state, a durable before-image covering every affected Hive store and allowlisted preference, and a durable commit marker. Preserve credentials, onboarding, unrelated preferences, and recovery metadata outside archive data.
- [ ] Recover before normal application providers initialize: roll back interruption before a durable commit marker; retain committed data and finish cleanup after it. Retain recovery material and show a retryable recovery state if rollback fails.
- [ ] Make no live change if reading, validation, staging, or available-space checks fail. Report success only after durable writes; clean staging only after durable commit or rollback.
- [ ] Verify behavior through the approved Snapshot Backup service boundary using temporary Hive, controlled preferences, and injected failures. Reopen stores to verify rollback and use a disposable process to verify initialization recovery across commit phases.
- [ ] Keep current app behavior and existing tests passing; this prerequisite establishes recoverable operations without enabling destructive import.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

