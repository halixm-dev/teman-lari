# AGENTS.md

## Tooling

- Codegen: `dart run build_runner build --delete-conflicting-outputs`
- Formatting: ALWAYS run `dart format .` before committing code.

## Non-Obvious Rules

- `invalid_annotation_target: ignore` in `analysis_options.yaml`
- Web build: Strava env vars via `--dart-define` (see `build.sh`)

## Domain-Specific Docs

- Design tokens: `docs/design.md`
- Training plan architecture: `docs/training_plan_architecture.md`
- Flutter rules: `docs/flutter_rules.md`
- Issue tracker: `docs/agents/issue_tracker.md`
- Triage labels: `docs/agents/triage_labels.md`
- Domain docs: `CONTEXT.md` and `docs/adr/`

## GitHub Automation

- `/git-commit`: Use to ensure Conventional Commits and atomic scopes.
- `/github-pr`: Use to automate Pull Request creation via `gh` CLI.
- `/github-actions`: PR pipeline requires 0 warnings, formatting, and passing tests before merge.
