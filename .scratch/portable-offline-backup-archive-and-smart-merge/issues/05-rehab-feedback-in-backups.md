# 05: Preserve Rehab Feedback in offline backups

Status: resolved

**What to build:** Include stored dual-window Rehab Feedback in the shared Snapshot Backup so a returning runner's recorded check-ins survive moving installations.

**Blocked by:** 02 — Export an offline backup from Settings.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Add minimal durable Rehab Feedback records for supported post-run and morning-after check-ins, pain/stiffness information, Injury Site, stable IDs, related Activity identifiers, and meaningful timestamps consistent with the rehabilitation ADR.
- [x] Add strict serialization and validation to the version 1 Rehab Feedback section, with explicit modification times and registration in shared snapshot coordination/recovery.
- [x] Populate nonempty feedback in service exports and show its count in the existing Settings backup summary; empty sections must mean no stored feedback.
- [x] Support valid imported feedback without needing a new check-in screen or clinical engine; persistence and faithful archive transport are the scope.
- [x] Test populated dual-window feedback through export, decode, durable application, and reopening stores. Verify both windows and linked identities survive.
- [x] Reject invalid required references and incompatible stable-ID identities before mutation; propagate storage/serialization failures rather than silently dropping feedback.
- [x] Verify normal record updates advance their modification time while imported timestamps and legacy unknown recency remain truthful.
- [x] Do not change rehabilitation thresholds, progression rules, or readiness prompts.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

## Answer

Implemented typed, durable dual-window Rehab Feedback with strict VAS, window,
calendar/offset, identity, and Activity-reference validation. Exports preserve
both windows and truthful modification metadata; normal saves stamp the clock.
The recoverable normal-write operation also migrates uploaded Activity IDs,
streams, and linked Feedback together while retaining local annotations.

Validation: 465 combined full-suite tests pass, including service-boundary export/apply/
reopen, invalid records, normal edits, upload reconciliation, and rollback. The
combined upload regression also retains the original shoe assignment and its
modification time while remapping its Activity reference.
The annotation regression failed against old camelCase JSON keys and passes
with snake_case preservation. The invalid UTC offset regression also failed
before its fix. Formatting, the standards guardrail, zero-warning analysis,
and release web compilation with Wasm dry run pass on the combined branch.
Shared Settings counts are integrated in ticket 03 commit
`cda97a177713c7578bacaaf5a37ffdb1d81f7041`. Verified that
`SnapshotBackupService.readBackupCounts()` reads the strict Rehab Feedback
section's `recordCount`, `backupCountsProvider` exposes it, and the Settings
backup card renders `Rehab feedback records` from that count. Ticket 03's
combined validation passes all 478 tests plus the 9 focused Settings tests.
This follow-up only closes the ticket; it changes no application code.
