# kleto-go

Cursor app template — reusable starting point for new projects. Always-on rules plus **stop-hook reinforcement loops** so agents micro-commit, run with full access, and pass verification without asking.

## What's included

| Rule / config | Purpose |
|---------------|---------|
| `micro-commits` | Auto-commit each step; one concern; small diffs |
| `git-safety` | Safe git; micro-commit always; push only when asked |
| `project-full-access` | Every `Shell` uses `required_permissions: ["all"]`; never ask |
| `agent-workflow` | Template rules override conflicting global user rules |
| `coding-principles` | Small diffs, match conventions |
| `verify-before-done` | Run `.cursor/verify.json` commands before claiming done |
| `rule-reinforcement` | How stop-hook loops enforce all template rules |
| `.cursor/cli.json` | CLI: sandbox off, broad tool allowlist |
| `.cursor/verify.json` | Project test/lint commands for the stop hook |
| `.cursor/hooks/verify-stop.sh` | Unified reinforcement loop (git, secrets, verify) |

Rules: [`.cursor/rules/`](.cursor/rules/) (`.mdc`, `alwaysApply: true`).

## Reinforcement architecture

```mermaid
flowchart LR
  A[Agent turn ends] --> B[verify-stop.sh]
  B --> C{Checks}
  C -->|dirty git| D[followup_message]
  C -->|staged secrets| D
  C -->|verify.json fail| D
  C -->|all pass| E["{}" stop loop]
  D --> F[Auto user message]
  F --> A
```

| Check | Enforces |
|-------|----------|
| Git clean | `micro-commits`, `git-safety` |
| Staged secrets scan | `git-safety` |
| `verify.json` commands | `verify-before-done`, `coding-principles` (via tests/lint) |
| Footer checklist | `project-full-access`, all always-on rules |

Rules teach behavior; hooks **prove** it. Add testable policies as verify commands; add subjective policies as rules plus footer reminders.

## Configure verification

Edit `.cursor/verify.json` when you add a stack:

```json
{
  "commands": [
    { "name": "test", "run": "go test ./...", "timeout": 120 },
    { "name": "lint", "run": "npm run lint", "optional": true }
  ]
}
```

## IDE setup (one-time)

1. **Trust this workspace** — project hooks require it.
2. **Auto-run / Run everything** — reduces approval prompts (with `.cursor/cli.json` for CLI).

Reload hooks: save `hooks.json` or restart Cursor.

## Recommended rules to add per app

| When | Rule idea | Loop pairing |
|------|-----------|----------------|
| Go / TS / Python app | `globs: **/*.{go,ts}` stack standards | `go test`, `eslint`, `ruff` in `verify.json` |
| API service | `api-conventions.mdc` | contract tests or `curl` smoke in verify |
| UI app | `ui-patterns.mdc` | `npm run build` + optional e2e |
| Team handoff | `session-handoff.mdc` (alwaysApply) | optional: stop hook reminder if transcript incomplete — subjective only |
| PR flow | `pr-checklist.mdc` (not alwaysApply) | user-triggered; `gh pr checks` in verify when opening PRs |
| Dependencies | `deps-bump.mdc` | lockfile + test command in verify |

Keep each rule file under ~50 lines, one concern. Update `rule_reinforcement_footer` in `hooks/lib/checks.sh` when you add a new **always-on** rule worth repeating in every loop.

## Use as a GitHub template

1. Create a repo from this template.
2. Add app code and fill `.cursor/verify.json`.
3. Add stack-specific rules with `globs` where needed.
4. Keep autonomy + reinforcement hooks unless you intentionally relax them.

## License

Add a license when you publish (e.g. MIT).
