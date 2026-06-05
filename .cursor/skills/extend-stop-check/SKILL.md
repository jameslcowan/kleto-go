---
name: extend-stop-check
description: >-
  Add a machine-checkable policy to the unified stop hook. Use when adding a new
  enforceable rule, verify command, or check_* function to kleto-go reinforcement.
---
# Extend stop check

Add **one** objective check to the existing stop loop — never a second `stop` hook.

## When to use

- New always-on rule that can be tested (lint, lockfile, schema, custom script)
- User asks to enforce a policy via hooks
- After adding app stack tests to `verify.json`

## Steps (do all; micro-commit when done)

### 1. Choose tier

| Tier | Where | Example |
|------|-------|---------|
| **A — verify.json** | `.cursor/verify.json` | `go test`, `./scripts/check-data-model.sh` |
| **A — checks.sh** | `hooks/lib/checks.sh` | `check_git_clean`, `check_data_first` |
| **C — rule only** | `.cursor/rules/*.mdc` + footer line | Naming, architecture |

Prefer `verify.json` for stack commands; `checks.sh` for repo/git policy.

### 2a. verify.json entry

```json
{
  "name": "my-check",
  "run": "./scripts/my-check.sh",
  "timeout": 60,
  "optional": false
}
```

Script must exit 0 on pass, non-zero on fail with stderr message.

### 2b. checks.sh function

```bash
check_my_policy() {
  local out
  out=$(./scripts/my-check.sh 2>&1) || {
    _issue "MY_POLICY" "Short title" "Action for agent" "$out"
  }
}
```

Wire in `verify-stop.sh` after existing checks (keep order: attribution → data-first → git → verify).

### 3. Footer reminder

Add one line to `rule_reinforcement_footer()` in `hooks/lib/checks.sh` if always-on rule.

### 4. Document

- One row in README rules/hooks table if user-facing
- `docs/hooks-roadmap.md` if from backlog

### 5. Verify yourself

```bash
./scripts/my-check.sh
# trigger stop loop or run verify-stop checks manually
```

## Do not

- Add another entry under `hooks.json` → `stop`
- Ask the user to run verification scripts (`agent-executes`)
- Skip `chmod +x` on new hook/check scripts

## Reference

- `rule-reinforcement.mdc` — tier A/B/C
- `verify-before-done.mdc` — verify.json schema
- Existing examples: `check-data-model.sh`, `test-shell-guard.sh`
