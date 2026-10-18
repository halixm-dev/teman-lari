# 07: Import with safe additive Smart Merge

Status: resolved

**What to build:** Let an athlete confirm a Smart Merge that adds missing records, reconciles matching identities, retains unrelated local data, and restores the previous state after a failed or interrupted import.

**Blocked by:** 06 — Preview a validated backup before importing.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Enable Import with Smart Merge through Settings and the approved Snapshot Backup service, using ticket 01's recoverable apply and startup recovery for every affected store.
- [x] Reconcile matching positive Activity IDs; reject incompatible Activity type/start identity before mutation. Preserve unrelated local records and evaluate incoming records against both current and already accepted incoming state.
- [x] Preserve distinct colliding negative-ID workouts by assigning unused negative identities and rewriting imported streams, feedback, and shoe assignments consistently. Persist aliases needed to recognize repeat imports.
- [x] For confirmed duplicates, keep non-null local measurements/annotations and existing nonempty heart rate streams; fill missing fields and absent/empty streams only.
- [x] Union equipment and Rehab Feedback by stable IDs; accept mutable changes only when strictly newer, retain local values on ties/unknown recency, and reject incompatible immutable identities.
- [x] Merge preferences per field and Training Plan/progress/cycle state as a unit using strictly newer modification times or genuinely absent local state. Support timestamped nullable clears without treating omitted data as a deletion.
- [x] Preserve imported timestamps. Do not infer edit time from synced_at or archive creation; retain existing local values when recency is unknown and expose retained conflicts.
- [x] Extend preview and result summaries with additions, ID matches, retained conflicts, and state changes. Recompute and reconfirm if local revision changed; disable duplicate apply actions.
- [x] Refresh activities, profile, Settings form values, cycle, plan, and Running Stats after durable commit without remote refresh, authentication changes, cloud upload, or Selective Push.
- [x] Until ticket 08, keep differing-ID signature candidates distinct and label that matching limitation; never guess a duplicate or silently discard a workout.
- [x] Test additive preservation, known/unknown recency, reference rewriting, same-identity repeat imports, staging/write/flush failures, recovery failures, process interruption, stale previews, and concurrent writes through the service.
- [x] Add Settings confirmation, cancellation, summary, retry, and refreshed-value tests. Verify credentials, onboarding, unrelated preferences, and local-only status survive.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.


## Answer

Implemented confirmed additive imports through SnapshotBackupService with deterministic identity/alias handling, linked-record reconciliation, profile and plan recency, stale preview reconfirmation, and local-only UI refresh. Interrupted or failed writes recover all owned stores; uncertain cleanup blocks normal access until recovery succeeds.

Validation: 614 full Flutter tests passed, zero-warning analysis, formatter and standards passed, web release and Wasm dry run passed. Focused service tests exercise every store write/flush failure, before/after-commit process interruption, alias ownership, repeat imports, and Settings confirmation/retry/recovery behavior. Differing-ID signature matching and replacement remain tickets08/09.
