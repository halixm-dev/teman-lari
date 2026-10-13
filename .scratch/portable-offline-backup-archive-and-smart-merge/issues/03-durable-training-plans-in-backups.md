# 03: Preserve Training Plans across restart and backup

Status: ready-for-agent

**What to build:** Keep an athlete's Training Plan and cycle state after reopening the app, and include that coherent state in the exported file and Settings backup summary.

**Blocked by:** 02 — Export an offline backup from Settings.

**Source:** Portable Offline Backup Archive and Smart Merge spec (ADR 0011; shared schema from ADR 0010).

- [ ] Persist complete supported Training Plan content, days, workout targets/phases, progress/configuration, and cycle state rather than relying exclusively on regeneration from current inputs.
- [ ] Serialize the plan with an explicit modification time as one coherent state unit. Register ordinary plan/cycle changes with the shared revision and recoverable snapshot operations.
- [ ] Load a saved or restored plan on initialization instead of immediately discarding it through automatic regeneration. Preserve existing generation behavior when there is no saved plan and when a legitimate plan change is requested.
- [ ] Populate the version 1 Training Plan section and its preview/export counts. Preserve meaningful date and duration semantics and distinguish absent plan state from an empty plan.
- [ ] Provide strict decode/encode and record validation through the existing Snapshot Backup service, without adding a second public merge boundary.
- [ ] Test a populated plan with nested workout details through export, decode, durable state application, and reopen; verify the app displays the restored plan/cycle and ordinary edits advance only the appropriate modification time.
- [ ] Keep plan generation, physiological rules, and coaching UX otherwise within existing domain decisions; do not build a new plan engine.
- [ ] Add focused provider/Settings coverage proving saved state and exported plan counts are visible after reopening.

**Validation:** Use the approved Snapshot Backup service boundary plus focused Settings widget tests where applicable. New assertions use package:checks. Run targeted tests while implementing; before committing code, run dart format ., the standards guardrail, zero-warning analysis, and the full Flutter test suite. Check web compilation for platform-sensitive changes.

