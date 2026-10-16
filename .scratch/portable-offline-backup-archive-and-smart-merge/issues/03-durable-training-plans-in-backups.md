# 03: Preserve Training Plans across restart and backup

Status: resolved

**What to build:** Keep an athlete's Training Plan and cycle state after reopening the app, and include that coherent state in the exported file and Settings backup summary.

**Blocked by:** 02 — Export an offline backup from Settings.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [x] Persist complete supported Training Plan content, days, workout targets/phases, progress/configuration, and cycle state rather than relying exclusively on regeneration from current inputs.
- [x] Serialize the plan with an explicit modification time as one coherent state unit. Register ordinary plan/cycle changes with the shared revision and recoverable snapshot operations.
- [x] Load a saved or restored plan on initialization instead of immediately discarding it through automatic regeneration. Preserve existing generation behavior when there is no saved plan and when a legitimate plan change is requested.
- [x] Populate the version 1 Training Plan section and its preview/export counts. Preserve meaningful date and duration semantics and distinguish absent plan state from an empty plan.
- [x] Provide strict decode/encode and record validation through the existing Snapshot Backup service, without adding a second public merge boundary.
- [x] Test a populated plan with nested workout details through export, decode, durable state application, and reopen; verify the app displays the restored plan/cycle and ordinary edits advance only the appropriate modification time.
- [x] Keep plan generation, physiological rules, and coaching UX otherwise within existing domain decisions; do not build a new plan engine.
- [x] Add focused provider/Settings coverage proving saved state and exported plan counts are visible after reopening.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.
## Answer

Implemented the complete typed Training Plan unit in `training_plans/active_state`: ordered days, targets, phases, progress, configuration, cycle preferences, and UTC modification time. Saved/restored plans load before generation; later input changes use the existing engine. New generation establishes only genuinely absent cycle fields, preserving legacy values and timestamped clears. Generation cannot overwrite concurrent restores or retry permanent storage failures indefinitely.

Plan schedules preserve civil dates; durations preserve supported fractional seconds and null versus empty collections. The Snapshot Backup service strictly validates every plan store before durable mutation. Settings displays saved plan, combined shoe/assignment, and feedback counts, refreshing them when returning to Settings. Recovery fixtures now contain valid typed plans.

Validation: code generation and `dart format .` completed; standards guardrail passed; analysis reported zero issues; the full Flutter suite passed 478 tests. The final parsed-export-to-apply/reopen service tests passed 11 tests and the final Settings tests passed 9 tests. Web release compilation and Wasm dry run passed with `APP_VERSION=1.0.0+1`. Native build/smoke validation remains the integration-level gate owned by the parent task.
