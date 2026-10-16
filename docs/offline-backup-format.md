# Offline backup version 1

The application boundary is `SnapshotBackupService`. `prepareExport()` returns
UTF-8 bytes and a dated `.tlbackup` filename. `exportBackup(transport)` coordinates
capture and delivery as one operation; `exportPhase` announces preparing/saving.
Neither operation reads remote repositories. File adapters only deliver bytes.

The [empty guest fixture](../test/fixtures/offline-backup-v1-empty.tlbackup) is
produced by the service test with a fixed clock and snapshot identity.

| Envelope field | Meaning |
| --- | --- |
| product | `teman_lari` |
| schema_version | `1` |
| snapshot_id | Unique export identity; never an Activity identity |
| created_at | UTC ISO-8601 creation instant; never an edit timestamp |
| app_version | Packaged native version or injected web `APP_VERSION` |
| counts | Counts corresponding to each of the six data sections |
| data | All six sections below are mandatory, including when empty |

| Data section | Export shape | Count |
| --- | --- | --- |
| profile | Five explicit `{value, modified_at}` preferences | Five fields |
| activities | Allowlisted Activity records | Activities |
| heart_rate_streams | `{activity_id, samples}` records | Streams |
| training_plan_state | Plans, cycle preferences, unit modification time | Plans |
| equipment | Shoes and Activity assignments | Shoes plus assignments |
| rehab_feedback | `{records: [...]}` | Feedback records |

Profile fields are `athlete_name`, `date_of_birth`, `resting_hr`, `max_hr`, and
`threshold_pace_sec`. Birth dates remain calendar dates (`YYYY-MM-DD`). Null with
an edit time is an explicit clear; null without a time is unset/unknown legacy
state. Cycle preferences live in `training_plan_state`. Archive creation and
storage synchronization times never supply missing edit metadata.

Activity IDs and all references are signed decimal strings, preserving negative
local identities and native IDs above the web exact-integer range. Web rejects
unsafe IDs instead of claiming rounded values are exact. Activity measurements
and stored heart-rate samples preserve fractions; no missing streams are fetched.
Credentials, onboarding, arbitrary preferences, and recovery metadata are excluded.

Export/import share `SnapshotArchiveLimits`: 50 MiB actual UTF-8 bytes and nesting
64. Oversized exports fail without truncation. Platform save results distinguish
saved, cancelled, browser download initiation, and share handoff.

Durable records in tickets 03-05 extend their independent modules:
`archive/training_plan_section.dart`, `archive/equipment_section.dart`, and
`archive/rehab_feedback_section.dart`. Until each codec supports populated data,
its nonempty store refuses export. Empty placeholders cannot hide existing data.
These additions retain section identities and schema version 1.

Production web builds inject the pubspec version through `build.sh`; ad-hoc web
builds without `APP_VERSION` identify themselves as `development`. Native reads
packaged metadata over the local platform channel, without a network request.

Equipment records use stable string IDs, a name, a functional `category`, nullable
`foam_chemistry`, nullable positive meter overrides `lifecycle_target_meters` and
`performance_target_meters`, and nullable `created_at`/`modified_at` instants.
Categories are `daily_trainer`, `max_cushion_recovery`, `tempo_workout`, and
`race_day_plated`; chemistry is `supercritical_peba_tpu` or `traditional_eva`.
A known creation instant identifies the original pair and cannot be changed by
normal edits. Unknown legacy creation/modification times remain null.
Assignments are `{activity_id, shoe_id, modified_at}` in
`equipment.activity_assignments`; their IDs must resolve to included Activities
and shoes. A null shoe_id with a known modified_at records an explicit cleared assignment; untouched unassigned Activities have no assignment record. Equipment counts include both shoe records and assignments.
Normal shoe/assignment edits receive UTC edit times, while remote refreshes and
identity changes preserve assignment recency. Calendar-invalid timestamps,
unsupported enum variants, nonpositive overrides, inconsistent record keys and
dangling assignments fail safely before applying a snapshot or exporting it.
The Manual Run dropdown lists persisted shoes; it does not invent gear records.

Rehab Feedback uses one stable record per stored dual-window check-in. `id` is a
nonempty string. `activity_id` is an exact nonzero decimal Activity ID and
`injury_site` is one of `achilles`, `knee`, `shin`, `plantarFascia`, `hamstring`.
The pair Activity + Injury Site is immutable for a matching stable feedback ID;
Smart Merge compares it after Activity reference remapping.

| Feedback field | Meaning |
| --- | --- |
| post_run_pain | Nullable finite VAS score from 0 to 10 |
| post_run_recorded_at | Required instant when post-run pain is present |
| morning_after_pain | Nullable finite VAS score from 0 to 10 |
| morning_stiffness | Nullable boolean; absence never means false |
| morning_after_recorded_at | Required instant when morning pain is present |
| modified_at | Actual local edit instant, imported instant, or unknown null |

At least one window is required. A recording instant cannot appear without its
window. Morning stiffness belongs to the morning window; both recording times
must be in chronological order when present. Instants export in UTC. Normal
check-in saves stamp their actual edit time; restoration and pure Activity
identity migration preserve recorded modification times. No rehabilitation
threshold, progression, or readiness behavior is inferred by this storage layer.

`transformLocalState` is the recoverable normal-write operation beneath the
backup boundary. It reads, transforms, validates, journals, and commits under one
coordinator lease, with an optional expected revision. It allows legitimate
normal writes while a tracked workout is active. Public export/import operations
retain the tracked-workout guard. Upload reconciliation uses the normal operation
to re-key Activities, heart rate streams, and Feedback together, preserving local
annotation timestamps and synchronization metadata.

Training Plan state stores a single `active_state` unit: `plans` (zero or one),
`active_plan_id`, full `configuration`, `week_in_cycle`, `cycle_start_date`, and
nullable `modified_at`. Each plan record contains its full ordered schedule,
workout targets, interval phases, and run/walk phases. A saved empty plan counts
as one plan; no saved plan counts as zero. Schedule dates use `YYYY-MM-DD` civil
dates so restoring across time zones keeps the same day. Durations use seconds,
including supported microsecond precision. Cycles, content, and configuration
share one modification time; unknown legacy recency remains null.

Saved or restored plans load before generation. The first read establishes the
current input baseline; subsequent activity/profile/configuration/cycle changes
can regenerate using the existing engine. Generation publishes only against its
captured local revision, so a concurrent restore cannot be overwritten. Cycle
reset is one recoverable state update and retains the saved configuration.
