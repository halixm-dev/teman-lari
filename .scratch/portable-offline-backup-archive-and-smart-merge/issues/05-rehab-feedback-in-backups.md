# 05: Preserve Rehab Feedback in offline backups

Status: ready-for-agent

**What to build:** Include stored dual-window Rehab Feedback in the shared Snapshot Backup so a returning runner's recorded check-ins survive moving installations.

**Blocked by:** 02 — Export an offline backup from Settings.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [ ] Add minimal durable Rehab Feedback records for supported post-run and morning-after check-ins, pain/stiffness information, Injury Site, stable IDs, related Activity identifiers, and meaningful timestamps consistent with the rehabilitation ADR.
- [ ] Add strict serialization and validation to the version 1 Rehab Feedback section, with explicit modification times and registration in shared snapshot coordination/recovery.
- [ ] Populate nonempty feedback in service exports and show its count in the existing Settings backup summary; empty sections must mean no stored feedback.
- [ ] Support valid imported feedback without needing a new check-in screen or clinical engine; persistence and faithful archive transport are the scope.
- [ ] Test populated dual-window feedback through export, decode, durable application, and reopening stores. Verify both windows and linked identities survive.
- [ ] Reject invalid required references and incompatible stable-ID identities before mutation; propagate storage/serialization failures rather than silently dropping feedback.
- [ ] Verify normal record updates advance their modification time while imported timestamps and legacy unknown recency remain truthful.
- [ ] Do not change rehabilitation thresholds, progression rules, or readiness prompts.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

